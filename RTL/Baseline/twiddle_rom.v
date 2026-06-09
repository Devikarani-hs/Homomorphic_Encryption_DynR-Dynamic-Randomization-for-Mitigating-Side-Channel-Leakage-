`timescale 1ns/1ps
// twiddle_rom.v — block ROM for NTT twiddle factors, init from .mem file
module twiddle_rom #(
    parameter DW        = 30,
    parameter DEPTH     = 4096,
    parameter INIT_FILE = "twiddle_q0.mem"
)(
    input  wire                      clk,
    input  wire [$clog2(DEPTH)-1:0]  addr,
    output reg  [DW-1:0]             dout
);
    (* rom_style = "block" *)
    reg [DW-1:0] rom [0:DEPTH-1];
    initial $readmemh(INIT_FILE, rom);
    always @(posedge clk) dout <= rom[addr];
endmodule
