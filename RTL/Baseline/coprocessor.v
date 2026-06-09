`timescale 1ns/1ps
// coprocessor.v — Single HEAWS coprocessor with 6 RPAUs

module coprocessor #(
    parameter DW     = 30,
    parameter N      = 4096,
    parameter LOG_N  = 12,
    parameter N_RPAU = 6
)(
    input  wire                   clk,
    input  wire                   rst,
    input  wire [2:0]             instr,
    input  wire                   instr_valid,
    output reg                    instr_done,
    input  wire [LOG_N-1:0]       wr_addr,
    input  wire [DW*N_RPAU-1:0]   wr_din_flat,
    input  wire [N_RPAU-1:0]      wr_en_vec,
    input  wire [LOG_N-1:0]       rd_addr,
    output wire [DW*N_RPAU-1:0]   rd_dout_flat,
    input  wire [DW*N_RPAU-1:0]   modulus_flat,
    input  wire [2*DW*N_RPAU-1:0] barrett_k_flat,
    input  wire [DW*N_RPAU-1:0]   n_inv_flat
);

    wire [N_RPAU-1:0] rpau_done;
    reg               rpau_start;
    reg  [2:0]        rpau_op;

    genvar gi;
    generate
        for (gi = 0; gi < N_RPAU; gi = gi + 1) begin : RPAU_BANK
            if (gi == 0) begin
                rpau #(.DW(DW), .N(N), .LOG_N(LOG_N), .INIT_TW("twiddle_q0.mem")) u_rpau (
                    .clk(clk), .rst(rst),
                    .op(rpau_op), .start(rpau_start), .done(rpau_done[gi]),
                    .modulus(modulus_flat[gi*DW +: DW]),
                    .barrett_k(barrett_k_flat[gi*2*DW +: 2*DW]),
                    .n_inv(n_inv_flat[gi*DW +: DW]),
                    .wr_addr(wr_addr), .wr_din(wr_din_flat[gi*DW +: DW]), .wr_en(wr_en_vec[gi]),
                    .rd_addr(rd_addr), .rd_dout(rd_dout_flat[gi*DW +: DW]),
                    .b_addr(rd_addr), .b_dout()
                );
            end else if (gi == 1) begin
                rpau #(.DW(DW), .N(N), .LOG_N(LOG_N), .INIT_TW("twiddle_q1.mem")) u_rpau (
                    .clk(clk), .rst(rst),
                    .op(rpau_op), .start(rpau_start), .done(rpau_done[gi]),
                    .modulus(modulus_flat[gi*DW +: DW]),
                    .barrett_k(barrett_k_flat[gi*2*DW +: 2*DW]),
                    .n_inv(n_inv_flat[gi*DW +: DW]),
                    .wr_addr(wr_addr), .wr_din(wr_din_flat[gi*DW +: DW]), .wr_en(wr_en_vec[gi]),
                    .rd_addr(rd_addr), .rd_dout(rd_dout_flat[gi*DW +: DW]),
                    .b_addr(rd_addr), .b_dout()
                );
            end else if (gi == 2) begin
                rpau #(.DW(DW), .N(N), .LOG_N(LOG_N), .INIT_TW("twiddle_q2.mem")) u_rpau (
                    .clk(clk), .rst(rst),
                    .op(rpau_op), .start(rpau_start), .done(rpau_done[gi]),
                    .modulus(modulus_flat[gi*DW +: DW]),
                    .barrett_k(barrett_k_flat[gi*2*DW +: 2*DW]),
                    .n_inv(n_inv_flat[gi*DW +: DW]),
                    .wr_addr(wr_addr), .wr_din(wr_din_flat[gi*DW +: DW]), .wr_en(wr_en_vec[gi]),
                    .rd_addr(rd_addr), .rd_dout(rd_dout_flat[gi*DW +: DW]),
                    .b_addr(rd_addr), .b_dout()
                );
            end else if (gi == 3) begin
                rpau #(.DW(DW), .N(N), .LOG_N(LOG_N), .INIT_TW("twiddle_q3.mem")) u_rpau (
                    .clk(clk), .rst(rst),
                    .op(rpau_op), .start(rpau_start), .done(rpau_done[gi]),
                    .modulus(modulus_flat[gi*DW +: DW]),
                    .barrett_k(barrett_k_flat[gi*2*DW +: 2*DW]),
                    .n_inv(n_inv_flat[gi*DW +: DW]),
                    .wr_addr(wr_addr), .wr_din(wr_din_flat[gi*DW +: DW]), .wr_en(wr_en_vec[gi]),
                    .rd_addr(rd_addr), .rd_dout(rd_dout_flat[gi*DW +: DW]),
                    .b_addr(rd_addr), .b_dout()
                );
            end else if (gi == 4) begin
                rpau #(.DW(DW), .N(N), .LOG_N(LOG_N), .INIT_TW("twiddle_q4.mem")) u_rpau (
                    .clk(clk), .rst(rst),
                    .op(rpau_op), .start(rpau_start), .done(rpau_done[gi]),
                    .modulus(modulus_flat[gi*DW +: DW]),
                    .barrett_k(barrett_k_flat[gi*2*DW +: 2*DW]),
                    .n_inv(n_inv_flat[gi*DW +: DW]),
                    .wr_addr(wr_addr), .wr_din(wr_din_flat[gi*DW +: DW]), .wr_en(wr_en_vec[gi]),
                    .rd_addr(rd_addr), .rd_dout(rd_dout_flat[gi*DW +: DW]),
                    .b_addr(rd_addr), .b_dout()
                );
            end else begin
                rpau #(.DW(DW), .N(N), .LOG_N(LOG_N), .INIT_TW("twiddle_q5.mem")) u_rpau (
                    .clk(clk), .rst(rst),
                    .op(rpau_op), .start(rpau_start), .done(rpau_done[gi]),
                    .modulus(modulus_flat[gi*DW +: DW]),
                    .barrett_k(barrett_k_flat[gi*2*DW +: 2*DW]),
                    .n_inv(n_inv_flat[gi*DW +: DW]),
                    .wr_addr(wr_addr), .wr_din(wr_din_flat[gi*DW +: DW]), .wr_en(wr_en_vec[gi]),
                    .rd_addr(rd_addr), .rd_dout(rd_dout_flat[gi*DW +: DW]),
                    .b_addr(rd_addr), .b_dout()
                );
            end
        end
    endgenerate

    always @(posedge clk) begin
        if (rst) begin
            rpau_start <= 1'b0;
            rpau_op    <= 3'd0;
            instr_done <= 1'b0;
        end else begin
            rpau_start <= 1'b0;
            instr_done <= 1'b0;
            if (instr_valid) begin
                rpau_op    <= instr;
                rpau_start <= 1'b1;
            end
            if (&rpau_done)
                instr_done <= 1'b1;
        end
    end

endmodule
