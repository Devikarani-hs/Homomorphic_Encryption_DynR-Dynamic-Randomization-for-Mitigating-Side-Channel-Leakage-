`timescale 1ns/1ps
module safe_top_engine #(
    parameter N        = 4096,
    parameter LOG2_N   = 12,
    parameter COEF_W   = 36,
    parameter MOD_W    = 36,
    parameter NBF      = 4,
    parameter MAX_ROWS = 128,
    parameter LOG2R    = 8
)(
    input  wire               clk,
    input  wire               rst_n,
    input  wire               start,
    input  wire [1:0]         hmvp_mode,
    input  wire [LOG2R-1:0]   num_rows,
    input  wire [MOD_W-1:0]   modulus,
    input  wire [31:0]        shuf_seed,
    input  wire               load_seed,
    input  wire [COEF_W-1:0]  pt_coef_in,
    input  wire [LOG2_N-1:0]  pt_addr,
    input  wire               pt_we,
    input  wire [COEF_W-1:0]  ct_coef_in,
    input  wire [LOG2_N-1:0]  ct_addr,
    input  wire               ct_we,
    input  wire [LOG2_N-1:0]  result_addr,
    output wire [COEF_W-1:0]  result_coef,
    output wire               done,
    output reg  [3:0]         pipeline_stage,
    output reg                busy,
    output wire [COEF_W-1:0]  probe_ntt_a,
    output wire [COEF_W-1:0]  probe_ntt_b,
    output wire [COEF_W-1:0]  probe_acu_r
);

localparam FSM_IDLE          = 4'd0;
localparam FSM_NTT           = 4'd1;
localparam FSM_SHUF          = 4'd2;
localparam FSM_REQROW        = 4'd3;
localparam FSM_MUL           = 4'd4;
localparam FSM_MUL_RD        = 4'd5;
localparam FSM_WAITMUL       = 4'd6;
localparam FSM_LOADINT       = 4'd7;
localparam FSM_LOADINT_WRITE = 4'd8;
localparam FSM_INTT          = 4'd9;
localparam FSM_DONE          = 4'd10;

reg [3:0] fsm;
reg global_done;

wire ntt_done_pt, ntt_done_ct, intt_done;
wire [COEF_W-1:0] ntt_out_pt, ntt_out_ct, intt_out_coef;
reg  ntt_start_pt, ntt_start_ct, intt_start;
reg  [COEF_W-1:0] intt_din;
reg  [LOG2_N-1:0] intt_wa;
reg               intt_we;

wire [COEF_W-1:0] acu_res;
wire              acu_vld;
reg               acu_start;
reg  [COEF_W-1:0] acu_a_r, acu_b_r;

wire [LOG2R-1:0] shuf_row;
wire             shuf_valid, shuf_done_sig;
wire [5:0]       rand_vl;
reg              shuf_next, shuf_start;

reg [LOG2_N-1:0] coef_cnt;
reg [LOG2R-1:0]  row_cnt;

(* ram_style = "block" *) reg [COEF_W-1:0] accum [0:N-1];
reg [COEF_W-1:0] accum_rd_data;

assign done        = global_done;
assign probe_acu_r = acu_res;
assign result_coef = (intt_out_coef >= modulus) ? (intt_out_coef - modulus) : intt_out_coef;

function [COEF_W-1:0] mod_add;
    input [COEF_W-1:0] a, b;
    input [MOD_W-1:0]  q;
    reg   [COEF_W:0]   s;
begin
    s = {1'b0,a} + {1'b0,b};
    mod_add = (s >= {1'b0,q}) ? s[COEF_W-1:0] - q[COEF_W-1:0] : s[COEF_W-1:0];
end
endfunction

always @(posedge clk) begin
    if (fsm == FSM_WAITMUL && acu_vld) begin
        if (row_cnt == 1)
            accum[coef_cnt] <= acu_res;
        else
            accum[coef_cnt] <= mod_add(accum_rd_data, acu_res, modulus);
    end
    accum_rd_data <= accum[coef_cnt];
end

ntt_intt_hybrid #(
    .N(N), .LOG2_N(LOG2_N), .COEF_W(COEF_W), .NBF(NBF), .MOD_W(MOD_W), .TF_FILE("tf_ntt.mem")
) u_ntt_pt (
    .clk(clk), .rst_n(rst_n), .start(ntt_start_pt),
    .ntt_sel(1'b0), .modulus(modulus),
    .coef_in(pt_coef_in), .coef_wa(pt_addr), .coef_we(pt_we),
    .coef_ra(coef_cnt), .coef_out(ntt_out_pt),
    .tf_in({COEF_W{1'b0}}), .tf_wa({LOG2_N{1'b0}}), .tf_we(1'b0),
    .done(ntt_done_pt), .probe_a(probe_ntt_a), .probe_b(probe_ntt_b)
);

ntt_intt_hybrid #(
    .N(N), .LOG2_N(LOG2_N), .COEF_W(COEF_W), .NBF(NBF), .MOD_W(MOD_W), .TF_FILE("tf_ntt.mem")
) u_ntt_ct (
    .clk(clk), .rst_n(rst_n), .start(ntt_start_ct),
    .ntt_sel(1'b0), .modulus(modulus),
    .coef_in(ct_coef_in), .coef_wa(ct_addr), .coef_we(ct_we),
    .coef_ra(coef_cnt), .coef_out(ntt_out_ct),
    .tf_in({COEF_W{1'b0}}), .tf_wa({LOG2_N{1'b0}}), .tf_we(1'b0),
    .done(ntt_done_ct), .probe_a(), .probe_b()
);

acu_unit #(.DATA_W(COEF_W), .MOD_W(MOD_W)) u_acu (
    .clk(clk), .rst_n(rst_n), .op(2'b10),
    .a(acu_a_r), .b(acu_b_r), .q(modulus),
    .valid_in(acu_start), .result(acu_res), .valid_out(acu_vld)
);

shuffling_controller #(.MAX_ROWS(MAX_ROWS), .LOG2R(LOG2R)) u_shuf (
    .clk(clk), .rst_n(rst_n), .load_seed(load_seed), .seed(shuf_seed),
    .start_shuffle(shuf_start), .num_rows(num_rows), .next_req(shuf_next),
    .row_out(shuf_row), .row_valid(shuf_valid), .shuf_done(shuf_done_sig), .rand_vl(rand_vl)
);

ntt_intt_hybrid #(
    .N(N), .LOG2_N(LOG2_N), .COEF_W(COEF_W), .NBF(NBF), .MOD_W(MOD_W), .TF_FILE("tf_intt.mem")
) u_intt (
    .clk(clk), .rst_n(rst_n), .start(intt_start),
    .ntt_sel(1'b1), .modulus(modulus),
    .coef_in(intt_din), .coef_wa(intt_wa), .coef_we(intt_we),
    .coef_ra(result_addr), .coef_out(intt_out_coef),
    .tf_in({COEF_W{1'b0}}), .tf_wa({LOG2_N{1'b0}}), .tf_we(1'b0),
    .done(intt_done), .probe_a(), .probe_b()
);

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        fsm <= FSM_IDLE;
        pipeline_stage <= 4'd0;
        busy <= 1'b0;
        global_done <= 1'b0;
        ntt_start_pt <= 1'b0;
        ntt_start_ct <= 1'b0;
        intt_start <= 1'b0;
        intt_we <= 1'b0;
        acu_start <= 1'b0;
        shuf_next <= 1'b0;
        shuf_start <= 1'b0;
        coef_cnt <= {LOG2_N{1'b0}};
        row_cnt <= {LOG2R{1'b0}};
        acu_a_r <= {COEF_W{1'b0}};
        acu_b_r <= {COEF_W{1'b0}};
        intt_din <= {COEF_W{1'b0}};
        intt_wa <= {LOG2_N{1'b0}};
    end else begin
        global_done  <= 1'b0;
        ntt_start_pt <= 1'b0;
        ntt_start_ct <= 1'b0;
        intt_start   <= 1'b0;
        intt_we      <= 1'b0;
        acu_start    <= 1'b0;
        shuf_next    <= 1'b0;
        shuf_start   <= 1'b0;

        case (fsm)
            FSM_IDLE: begin
                pipeline_stage <= 4'd0;
                busy <= 1'b0;
                coef_cnt <= {LOG2_N{1'b0}};
                row_cnt  <= {LOG2R{1'b0}};
                if (start) begin
                    busy <= 1'b1;
                    pipeline_stage <= 4'd1;
                    ntt_start_pt <= 1'b1;
                    ntt_start_ct <= 1'b1;
                    shuf_start <= 1'b1;
                    fsm <= FSM_NTT;
                end
            end

            FSM_NTT: begin
                pipeline_stage <= 4'd2;
                if (ntt_done_pt && ntt_done_ct) begin
                    coef_cnt <= {LOG2_N{1'b0}};
                    fsm <= FSM_SHUF;
                end
            end

            FSM_SHUF: begin
                pipeline_stage <= 4'd3;
                shuf_next <= 1'b1;
                fsm <= FSM_REQROW;
            end

            FSM_REQROW: begin
                pipeline_stage <= 4'd3;
                if (shuf_valid) begin
                    row_cnt  <= row_cnt + 1'b1;
                    coef_cnt <= {LOG2_N{1'b0}};
                    fsm <= FSM_MUL;
                end
            end

            FSM_MUL: begin
                pipeline_stage <= 4'd4;
                fsm <= FSM_MUL_RD;
            end

            FSM_MUL_RD: begin
                pipeline_stage <= 4'd4;
                acu_a_r   <= ntt_out_pt;
                acu_b_r   <= ntt_out_ct + {{(COEF_W-LOG2R){1'b0}}, shuf_row};
                acu_start <= 1'b1;
                fsm <= FSM_WAITMUL;
            end

            FSM_WAITMUL: begin
                pipeline_stage <= 4'd5;
                if (acu_vld) begin
                    if (coef_cnt == N-1) begin
                        coef_cnt <= {LOG2_N{1'b0}};
                        if (row_cnt == num_rows)
                            fsm <= FSM_LOADINT;
                        else
                            fsm <= FSM_SHUF;
                    end else begin
                        coef_cnt <= coef_cnt + 1'b1;
                        fsm <= FSM_MUL;
                    end
                end
            end

            FSM_LOADINT: begin
                pipeline_stage <= 4'd6;
                fsm <= FSM_LOADINT_WRITE;
            end

            FSM_LOADINT_WRITE: begin
                pipeline_stage <= 4'd6;
                intt_din <= accum_rd_data;
                intt_wa  <= coef_cnt;
                intt_we  <= 1'b1;
                if (coef_cnt == N-1) begin
                    coef_cnt <= {LOG2_N{1'b0}};
                    intt_start <= 1'b1;
                    fsm <= FSM_INTT;
                end else begin
                    coef_cnt <= coef_cnt + 1'b1;
                    fsm <= FSM_LOADINT;
                end
            end

            FSM_INTT: begin
                pipeline_stage <= 4'd7;
                if (intt_done)
                    fsm <= FSM_DONE;
            end

            FSM_DONE: begin
                pipeline_stage <= 4'd8;
                busy <= 1'b0;
                global_done <= 1'b1;
                fsm <= FSM_IDLE;
            end

            default: fsm <= FSM_IDLE;
        endcase
    end
end

integer i_init;
initial begin
    for (i_init = 0; i_init < N; i_init = i_init + 1)
        accum[i_init] = {COEF_W{1'b0}};
    accum_rd_data = {COEF_W{1'b0}};
end

endmodule
