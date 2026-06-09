`timescale 1ns/1ps
// mod_mul_30.v — Barrett modular multiplier, 30-bit, 3-stage pipeline
module mod_mul_30 #(parameter DW = 30)(
    input  wire             clk, rst,
    input  wire [DW-1:0]    a, b, modulus,
    input  wire [2*DW-1:0]  barrett_k,
    input  wire             valid_in,
    output reg  [DW-1:0]    result,
    output reg              valid_out
);
    reg [2*DW-1:0] s1_prod; reg s1_v;
    reg [2*DW-1:0] s2_qest; reg [2*DW-1:0] s2_prod; reg s2_v;
    wire [2*DW-1:0] t  = s2_prod - (s2_qest * modulus);
    wire [DW-1:0]  t_r = (t >= modulus) ? t[DW-1:0] - modulus : t[DW-1:0];
    always @(posedge clk) begin
        if (rst) begin
            s1_v<=0; s2_v<=0; valid_out<=0;
            s1_prod<=0; s2_qest<=0; s2_prod<=0; result<=0;
        end else begin
            s1_prod <= a * b;                              s1_v <= valid_in;
            s2_prod <= s1_prod;
            s2_qest <= (s1_prod * barrett_k) >> (2*DW);   s2_v <= s1_v;
            result    <= t_r;
            valid_out <= s2_v;
        end
    end
endmodule
