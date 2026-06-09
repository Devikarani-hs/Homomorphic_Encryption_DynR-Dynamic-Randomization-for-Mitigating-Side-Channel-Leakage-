`timescale 1ns/1ps
// poly_mem.v — dual-port BRAM for one residue polynomial (N=4096, 30-bit)
module poly_mem #(
    parameter DW    = 30,
    parameter DEPTH = 4096
)(
    input  wire                      clk,
    input  wire [$clog2(DEPTH)-1:0]  addr_a,
    input  wire [DW-1:0]             din_a,
    input  wire                      we_a,
    output reg  [DW-1:0]             dout_a,
    input  wire [$clog2(DEPTH)-1:0]  addr_b,
    input  wire [DW-1:0]             din_b,
    input  wire                      we_b,
    output reg  [DW-1:0]             dout_b
);
    (* ram_style = "block" *)
    reg [DW-1:0] mem [0:DEPTH-1];
    always @(posedge clk) begin
        if (we_a) mem[addr_a] <= din_a;
        dout_a <= mem[addr_a];
    end
    always @(posedge clk) begin
        if (we_b) mem[addr_b] <= din_b;
        dout_b <= mem[addr_b];
    end
endmodule
