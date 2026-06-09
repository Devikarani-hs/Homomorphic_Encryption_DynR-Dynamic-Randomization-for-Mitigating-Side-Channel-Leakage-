`timescale 1ns/1ps
// ntt_butterfly.v — Cooley-Tukey butterfly using mod_mul_30
module ntt_butterfly #(parameter DW = 30)(
    input  wire             clk, rst,
    input  wire [DW-1:0]    a_in, b_in, w, modulus,
    input  wire [2*DW-1:0]  barrett_k,
    input  wire             valid_in,
    output reg  [DW-1:0]    a_out, b_out,
    output reg              valid_out
);
    wire [DW-1:0] t_r; wire t_vld;
    mod_mul_30 #(.DW(DW)) u_mul(
        .clk(clk),.rst(rst),.a(w),.b(b_in),
        .modulus(modulus),.barrett_k(barrett_k),
        .valid_in(valid_in),.result(t_r),.valid_out(t_vld)
    );
    reg [DW-1:0] a1,a2,a3;
    always @(posedge clk) begin a1<=a_in; a2<=a1; a3<=a2; end
    wire [DW:0] s = {1'b0,a3} + {1'b0,t_r};
    wire [DW:0] d = {1'b0,a3} + {1'b0,modulus} - {1'b0,t_r};
    wire [DW-1:0] sr = (s>={1'b0,modulus}) ? s[DW-1:0]-modulus : s[DW-1:0];
    wire [DW-1:0] dr = (d>={1'b0,modulus}) ? d[DW-1:0]-modulus : d[DW-1:0];
    always @(posedge clk) begin
        if (rst) begin a_out<=0; b_out<=0; valid_out<=0; end
        else    begin a_out<=sr; b_out<=dr; valid_out<=t_vld; end
    end
endmodule
