`timescale 1ns/1ps
// mod_add.v — single-cycle modular adder, 30-bit (HEAWS RPAU adder width)
module mod_add #(parameter DW = 30)(
    input  wire             clk, rst,
    input  wire [DW-1:0]    a, b, modulus,
    input  wire             valid_in,
    output reg  [DW-1:0]    result,
    output reg              valid_out
);
    wire [DW:0] sum = {1'b0,a} + {1'b0,b};
    wire [DW:0] sub = sum - {1'b0,modulus};
    always @(posedge clk) begin
        if (rst) begin result <= 0; valid_out <= 0; end
        else begin
            result    <= sub[DW] ? sum[DW-1:0] : sub[DW-1:0];
            valid_out <= valid_in;
        end
    end
endmodule
