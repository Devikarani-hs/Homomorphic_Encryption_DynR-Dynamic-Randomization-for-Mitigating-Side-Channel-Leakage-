import os
import numpy as np

N = 4096
LOG2R = 8
Q = 12289
SEED = 0xDEADBEEF
NUM_ROWS = 128

RESULTS_DIR = "results"
PT_FILE = os.path.join(RESULTS_DIR, "pt_in.txt")
CT_FILE = os.path.join(RESULTS_DIR, "ct_in.txt")
RTL_FILE = os.path.join(RESULTS_DIR, "rtl_out.txt")
GOLDEN_NPY = os.path.join(RESULTS_DIR, "golden_out.npy")
GOLDEN_MEMH = os.path.join(RESULTS_DIR, "golden_expected.memh")

FSM_IDLE = 0
FSM_NTT = 1
FSM_SHUF = 2
FSM_REQROW = 3
FSM_MUL = 4
FSM_WAITMUL = 5
FSM_LOADINT = 6
FSM_LOADINT_WRITE = 7
FSM_INTT = 8
FSM_DONE = 9


def load_hex_vector(path, n):
    vals = []
    with open(path, "r") as f:
        for line in f:
            s = line.strip()
            if s:
                vals.append(int(s, 16) % Q)
    if len(vals) != n:
        raise ValueError(f"{path}: expected {n} entries, got {len(vals)}")
    return vals


def mod_add(a, b, q):
    s = a + b
    return s - q if s >= q else s


class NttInttHybrid:
    def __init__(self, init_mem, modulus):
        self.modulus = modulus
        self.coef_mem = [x % modulus for x in init_mem]
        self.tf_mem = [0] * N

        self.start = 0
        self.coef_in = 0
        self.coef_wa = 0
        self.coef_we = 0
        self.coef_ra = 0
        self.tf_in = 0
        self.tf_wa = 0
        self.tf_we = 0

        self.done = 0
        self.coef_out = 0
        self.probe_a = 0
        self.probe_b = 0

        self.running = 0
        self.running_d1 = 0
        self.idx = 0
        self.idx_d1 = 0
        self.U = 0
        self.V = 0
        self.W = 0

    def tick(self, rst_n=1):
        if not rst_n:
            self.done = 0
            self.running = 0
            self.running_d1 = 0
            self.idx = 0
            self.idx_d1 = 0
            self.U = 0
            self.V = 0
            self.W = 0
            self.coef_out = 0
            return

        old_running = self.running
        old_running_d1 = self.running_d1
        old_idx = self.idx
        old_idx_d1 = self.idx_d1
        old_U = self.U
        old_V = self.V
        old_W = self.W

        if self.coef_we:
            self.coef_mem[self.coef_wa] = self.coef_in % self.modulus
        if self.tf_we:
            self.tf_mem[self.tf_wa] = self.tf_in % self.modulus

        self.coef_out = self.coef_mem[self.coef_ra]

        if old_running_d1:
            prod = (old_W * old_V) % self.modulus
            self.coef_mem[old_idx_d1] = (old_U + prod) % self.modulus
            if old_idx_d1 + 1 < N:
                self.coef_mem[old_idx_d1 + 1] = (old_U - prod + self.modulus) % self.modulus

        fetch_idx = old_idx
        self.U = self.coef_mem[fetch_idx]
        self.V = self.coef_mem[fetch_idx + 1] if fetch_idx + 1 < N else 0
        self.W = self.tf_mem[fetch_idx]
        self.probe_a = self.U
        self.probe_b = self.V

        self.done = 0
        if self.start and not old_running:
            self.running = 1
            self.idx = 0
        elif old_running:
            self.running_d1 = 1
            self.idx_d1 = old_idx
            if old_idx >= N - 2:
                self.running = 0
                self.done = 1
            else:
                self.idx = old_idx + 2
        else:
            self.running_d1 = 0


class ShufflingController:
    def __init__(self, max_rows=128, log2r=8):
        self.max_rows = max_rows
        self.log2r = log2r

        self.load_seed = 0
        self.seed = 0
        self.start_shuffle = 0
        self.num_rows = 0
        self.next_req = 0

        self.row_out = 0
        self.row_valid = 0
        self.shuf_done = 0
        self.rand_vl = 16

        self.lfsr = 0xACE1ACE1
        self.perm = list(range(max_rows))
        self.sp = 0
        self.dp = 0
        self.running = 0
        self.ready = 0

    @staticmethod
    def lfsr_step(x):
        fb = ((x >> 31) ^ (x >> 21) ^ (x >> 1) ^ x) & 1
        return ((x << 1) & 0xFFFFFFFF) | fb

    def tick(self, rst_n=1):
        if not rst_n:
            self.lfsr = 0xACE1ACE1
            self.running = 0
            self.ready = 0
            self.shuf_done = 0
            self.dp = 0
            self.sp = 0
            self.row_valid = 0
            self.row_out = 0
            self.rand_vl = 16
            self.perm = list(range(self.max_rows))
            return

        old_lfsr = self.lfsr
        old_perm = self.perm[:]
        old_sp = self.sp
        old_dp = self.dp
        old_running = self.running
        old_ready = self.ready

        self.row_valid = 0
        self.shuf_done = 0

        if self.load_seed:
            self.lfsr = self.seed ^ 0xA5A5A5A5

        if self.start_shuffle:
            self.perm = list(range(self.max_rows))
            self.sp = 0 if self.num_rows == 0 else self.num_rows - 1
            self.dp = 0
            self.running = 1 if self.num_rows != 0 else 0
            self.ready = 1 if self.num_rows == 0 else 0

        elif old_running:
            self.lfsr = self.lfsr_step(old_lfsr)
            rj = 0 if old_sp == 0 else (old_lfsr & ((1 << self.log2r) - 1)) % (old_sp + 1)
            tmp = old_perm[old_sp]
            self.perm[old_sp] = old_perm[rj]
            self.perm[rj] = tmp
            if old_sp == 0:
                self.running = 0
                self.ready = 1
                self.shuf_done = 1
            else:
                self.sp = old_sp - 1

        if old_ready and self.next_req and (old_dp < self.num_rows):
            self.row_out = old_perm[old_dp]
            self.row_valid = 1
            self.dp = old_dp + 1
            self.rand_vl = 8 + (((old_lfsr >> 2) & 0x3) << 2)


class AcuUnit:
    def __init__(self, modulus):
        self.modulus = modulus
        self.a = 0
        self.b = 0
        self.valid_in = 0
        self.result = 0
        self.valid_out = 0

    def tick(self, rst_n=1):
        if not rst_n:
            self.result = 0
            self.valid_out = 0
            return
        self.valid_out = 1 if self.valid_in else 0
        if self.valid_in:
            self.result = (self.a * self.b) % self.modulus


class SafeTopEmu:
    def __init__(self, pt_vec, ct_vec, modulus=Q, num_rows=NUM_ROWS, shuf_seed=SEED):
        self.modulus = modulus
        self.num_rows = num_rows
        self.shuf_seed = shuf_seed

        self.u_ntt_pt = NttInttHybrid(pt_vec, modulus)
        self.u_ntt_ct = NttInttHybrid(ct_vec, modulus)
        self.u_intt = NttInttHybrid([0] * N, modulus)
        self.u_shuf = ShufflingController(128, LOG2R)
        self.u_acu = AcuUnit(modulus)

        self.accum = [0] * N
        self.prod_mem = [0] * N
        self.accum_rd_data = 0

        self.fsm = FSM_IDLE
        self.pipeline_stage = 0
        self.busy = 0
        self.global_done = 0
        self.ntt_start_pt = 0
        self.ntt_start_ct = 0
        self.intt_start = 0
        self.intt_we = 0
        self.acu_start = 0
        self.shuf_next = 0
        self.shuf_start = 0
        self.coef_cnt = 0
        self.row_cnt = 0
        self.acu_a_r = 0
        self.acu_b_r = 0
        self.intt_din = 0
        self.intt_wa = 0

        self.start = 0
        self.load_seed = 0
        self.result_addr = 0
        self.rst_n = 0

    def tick(self):
        old_fsm = self.fsm
        old_coef_cnt = self.coef_cnt
        old_row_cnt = self.row_cnt
        old_accum_rd_data = self.accum_rd_data

        self.u_ntt_pt.start = self.ntt_start_pt
        self.u_ntt_ct.start = self.ntt_start_ct
        self.u_intt.start = self.intt_start

        self.u_shuf.load_seed = self.load_seed
        self.u_shuf.seed = self.shuf_seed
        self.u_shuf.start_shuffle = self.shuf_start
        self.u_shuf.num_rows = self.num_rows
        self.u_shuf.next_req = self.shuf_next

        self.u_acu.a = self.acu_a_r % self.modulus
        self.u_acu.b = self.acu_b_r % self.modulus
        self.u_acu.valid_in = self.acu_start

        self.u_ntt_pt.coef_ra = self.coef_cnt
        self.u_ntt_ct.coef_ra = self.coef_cnt
        self.u_intt.coef_ra = self.result_addr

        self.u_intt.coef_in = self.intt_din
        self.u_intt.coef_wa = self.intt_wa
        self.u_intt.coef_we = self.intt_we

        self.u_ntt_pt.tick(self.rst_n)
        self.u_ntt_ct.tick(self.rst_n)
        self.u_intt.tick(self.rst_n)
        self.u_shuf.tick(self.rst_n)
        self.u_acu.tick(self.rst_n)

        if self.rst_n:
            if old_fsm == FSM_WAITMUL and self.u_acu.valid_out:
                if old_row_cnt == 1:
                    self.accum[old_coef_cnt] = self.u_acu.result
                else:
                    self.accum[old_coef_cnt] = mod_add(old_accum_rd_data, self.u_acu.result, self.modulus)
                self.prod_mem[old_coef_cnt] = self.u_acu.result

            self.accum_rd_data = self.accum[old_coef_cnt]

        if not self.rst_n:
            self.fsm = FSM_IDLE
            self.pipeline_stage = 0
            self.busy = 0
            self.global_done = 0
            self.ntt_start_pt = 0
            self.ntt_start_ct = 0
            self.intt_start = 0
            self.intt_we = 0
            self.acu_start = 0
            self.shuf_next = 0
            self.shuf_start = 0
            self.coef_cnt = 0
            self.row_cnt = 0
            self.acu_a_r = 0
            self.acu_b_r = 0
            self.intt_din = 0
            self.intt_wa = 0
            return

        self.global_done = 0
        self.ntt_start_pt = 0
        self.ntt_start_ct = 0
        self.intt_start = 0
        self.intt_we = 0
        self.acu_start = 0
        self.shuf_next = 0
        self.shuf_start = 0

        if self.fsm == FSM_IDLE:
            self.pipeline_stage = 0
            self.busy = 0
            self.coef_cnt = 0
            self.row_cnt = 0
            if self.start:
                self.busy = 1
                self.pipeline_stage = 1
                self.ntt_start_pt = 1
                self.ntt_start_ct = 1
                self.shuf_start = 1
                self.fsm = FSM_NTT

        elif self.fsm == FSM_NTT:
            self.pipeline_stage = 2
            if self.u_ntt_pt.done and self.u_ntt_ct.done:
                self.fsm = FSM_SHUF

        elif self.fsm == FSM_SHUF:
            self.pipeline_stage = 3
            self.shuf_next = 1
            self.fsm = FSM_REQROW

        elif self.fsm == FSM_REQROW:
            self.pipeline_stage = 3
            self.coef_cnt = 0
            if self.u_shuf.row_valid:
                self.row_cnt = self.row_cnt + 1
                self.fsm = FSM_MUL

        elif self.fsm == FSM_MUL:
            self.pipeline_stage = 4
            self.acu_a_r = self.u_ntt_pt.coef_out
            self.acu_b_r = self.u_ntt_ct.coef_out + self.u_shuf.row_out
            self.acu_start = 1
            self.fsm = FSM_WAITMUL

        elif self.fsm == FSM_WAITMUL:
            self.pipeline_stage = 5
            if self.u_acu.valid_out:
                if self.coef_cnt == N - 1:
                    if self.row_cnt == self.num_rows:
                        self.coef_cnt = 0
                        self.fsm = FSM_LOADINT
                    else:
                        self.fsm = FSM_SHUF
                else:
                    self.coef_cnt = self.coef_cnt + 1
                    self.fsm = FSM_MUL

        elif self.fsm == FSM_LOADINT:
            self.pipeline_stage = 6
            self.fsm = FSM_LOADINT_WRITE

        elif self.fsm == FSM_LOADINT_WRITE:
            self.pipeline_stage = 6
            self.intt_din = self.accum_rd_data
            self.intt_wa = self.coef_cnt
            self.intt_we = 1
            if self.coef_cnt == N - 1:
                self.coef_cnt = 0
                self.intt_start = 1
                self.fsm = FSM_INTT
            else:
                self.coef_cnt = self.coef_cnt + 1
                self.fsm = FSM_LOADINT

        elif self.fsm == FSM_INTT:
            self.pipeline_stage = 7
            if self.u_intt.done:
                self.fsm = FSM_DONE

        elif self.fsm == FSM_DONE:
            self.pipeline_stage = 8
            self.busy = 0
            self.global_done = 1
            self.fsm = FSM_IDLE

        else:
            self.fsm = FSM_IDLE

    def run(self):
        self.rst_n = 0
        for _ in range(8):
            self.tick()

        self.rst_n = 1
        for _ in range(2):
            self.tick()

        self.load_seed = 1
        self.tick()
        self.load_seed = 0
        self.tick()

        self.start = 1
        self.tick()
        self.start = 0

        watchdog = 0
        while True:
            self.tick()
            watchdog += 1
            if self.global_done:
                break
            if watchdog > 5000000:
                raise RuntimeError("safe_top_engine FSM emulation timeout")

        out = []
        for i in range(N):
            self.result_addr = i
            self.tick()
            out.append(self.u_intt.coef_out % 12289)
        return out


def main():
    os.makedirs(RESULTS_DIR, exist_ok=True)
    pt_in = load_hex_vector(PT_FILE, N)
    ct_in = load_hex_vector(CT_FILE, N)

    emu = SafeTopEmu(pt_in, ct_in, Q, NUM_ROWS, SEED)
    final_result = emu.run()

    np.save(GOLDEN_NPY, np.array(final_result, dtype=np.int64))
    with open(GOLDEN_MEMH, "w") as f:
        for v in final_result:
            f.write(f"{v & 0x1FF_FFFFF:09x}\n")

    print("[OK] Strict FSM golden model generated.")
    print(f"[OK] Saved numpy output : {GOLDEN_NPY}")
    print(f"[OK] Saved memh output  : {GOLDEN_MEMH}")

    if os.path.exists(RTL_FILE):
        with open(RTL_FILE, "r") as f:
            rtl = [int(line.strip(), 16) % Q for line in f if line.strip()]

        if len(rtl) != len(final_result):
            print(f"[FAIL] Length mismatch: golden={len(final_result)} rtl={len(rtl)}")
            return

        mismatches = [(i, g, r) for i, (g, r) in enumerate(zip(final_result, rtl)) if g != r]
        if not mismatches:
            print("[MATCH] RTL output matches golden model exactly.")
        else:
            print(f"[FAIL] Found {len(mismatches)} mismatches.")
            for i, g, r in mismatches[:10]:
                print(f"  idx={i}: golden={g} rtl={r}")


if __name__ == "__main__":
    main()
