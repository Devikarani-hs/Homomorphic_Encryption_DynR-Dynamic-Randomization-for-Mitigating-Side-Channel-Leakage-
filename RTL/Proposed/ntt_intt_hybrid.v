`timescale 1ns/1ps
module ntt_intt_hybrid #(
    parameter N      = 4096,
    parameter LOG2_N = 12,
    parameter COEF_W = 36,
    parameter NBF    = 4,
    parameter MOD_W  = 36,
    parameter TF_FILE = "" 
)(
    input  wire                 clk,
    input  wire                 rst_n,
    input  wire                 start,
    input  wire                 ntt_sel,
    input  wire [MOD_W-1:0]     modulus,
    input  wire [COEF_W-1:0]    coef_in,
    input  wire [LOG2_N-1:0]    coef_wa,
    input  wire                 coef_we,
    input  wire [LOG2_N-1:0]    coef_ra,
    output reg  [COEF_W-1:0]    coef_out,
    input  wire [COEF_W-1:0]    tf_in,
    input  wire [LOG2_N-1:0]    tf_wa,
    input  wire                 tf_we,
    output reg                  done,
    output reg  [COEF_W-1:0]    probe_a,
    output reg  [COEF_W-1:0]    probe_b
);

(* ram_style = "block" *) reg [COEF_W-1:0] coef_mem_even [0:N/2-1];
(* ram_style = "block" *) reg [COEF_W-1:0] coef_mem_odd  [0:N/2-1];
(* ram_style = "block" *) reg [COEF_W-1:0] tf_mem        [0:N-1];

reg running, running_d1;
reg [LOG2_N-1:0] idx, idx_d1;
reg [COEF_W-1:0] U, V, W;

// --- 1. CLEAN ADDRESSING WIRES ---
wire [LOG2_N-2:0] wa_half   = coef_wa[LOG2_N-1:1];
wire [LOG2_N-2:0] ra_half   = coef_ra[LOG2_N-1:1];
wire [LOG2_N-2:0] idx_half  = idx[LOG2_N-1:1];
wire [LOG2_N-2:0] idx_d1_half = idx_d1[LOG2_N-1:1];

// --- 2. CLEAN MATH WIRES (BRAM PRE-CALCULATION) ---
wire [COEF_W-1:0] din_ext        = coef_in % 12289;
wire [COEF_W-1:0] din_tf         = tf_in % 12289;
wire [COEF_W-1:0] prod_val       = (W * V) % 12289;
wire [COEF_W-1:0] din_math_even  = (U + prod_val) % 12289;
wire [COEF_W-1:0] din_math_odd   = (U + modulus - prod_val) % 12289;

// --- 3. CLEAN WRITE ENABLES ---
wire we_ext_even = coef_we & ~coef_wa[0];
wire we_ext_odd  = coef_we &  coef_wa[0];
wire we_math     = running_d1;

reg [COEF_W-1:0] coef_out_even, coef_out_odd;
reg coef_ra_lsb;

// ==========================================
// BRAM BANK: EVEN (Strict Dual-Port)
// ==========================================
always @(posedge clk) begin
    if (we_ext_even) coef_mem_even[wa_half] <= din_ext;
    coef_out_even <= coef_mem_even[ra_half];
end
always @(posedge clk) begin
    if (we_math) coef_mem_even[idx_d1_half] <= din_math_even;
    U <= coef_mem_even[idx_half];
end

// ==========================================
// BRAM BANK: ODD (Strict Dual-Port)
// ==========================================
always @(posedge clk) begin
    if (we_ext_odd) coef_mem_odd[wa_half] <= din_ext;
    coef_out_odd <= coef_mem_odd[ra_half];
end
always @(posedge clk) begin
    if (we_math) coef_mem_odd[idx_d1_half] <= din_math_odd;
    V <= coef_mem_odd[idx_half];
end

// ==========================================
// ROM BANK: TWIDDLE FACTORS
// ==========================================
always @(posedge clk) begin
    if (tf_we) tf_mem[tf_wa] <= din_tf;
    W <= tf_mem[idx];
end

// Output Multiplexer
always @(*) begin
    coef_out = coef_ra_lsb ? coef_out_odd : coef_out_even;
end

// --- STATE MACHINE ---
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        done <= 0; running <= 0; running_d1 <= 0; idx <= 0; idx_d1 <= 0;
        probe_a <= 0; probe_b <= 0; coef_ra_lsb <= 0;
    end else begin
        done <= 1'b0;
        probe_a <= U;
        probe_b <= V;
        coef_ra_lsb <= coef_ra[0];
        
        if (start && !running) begin
            running <= 1'b1; idx <= 0;
        end else if (running) begin
            running_d1 <= 1'b1;
            idx_d1 <= idx;
            if (idx >= N-2) begin
                running <= 1'b0;
                done <= 1'b1;
            end else idx <= idx + 2;
        end else running_d1 <= 1'b0;
    end
end

integer i_init;
initial begin
    for (i_init = 0; i_init < N/2; i_init = i_init + 1) begin
        coef_mem_even[i_init] = 0;
        coef_mem_odd[i_init] = 0;
    end
    for (i_init = 0; i_init < N; i_init = i_init + 1) begin
        tf_mem[i_init] = 0;
    end
    if (TF_FILE != "") $readmemh(TF_FILE, tf_mem); 
end
endmodule
