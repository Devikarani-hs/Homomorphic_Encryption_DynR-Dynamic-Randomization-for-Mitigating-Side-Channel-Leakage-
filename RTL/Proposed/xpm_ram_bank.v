`timescale 1ns/1ps
module xpm_ram_bank #(
    parameter ADDR_WIDTH = 12,
    parameter DATA_WIDTH = 36,
    parameter DEPTH = 4096
)(
    input  wire                     clk,
    input  wire                     en,
    input  wire                     we,
    input  wire [ADDR_WIDTH-1:0]    addr,
    input  wire [DATA_WIDTH-1:0]    din,
    output wire [DATA_WIDTH-1:0]    dout
);

xpm_memory_spram #(
    .ADDR_WIDTH_A(ADDR_WIDTH),
    .AUTO_SLEEP_TIME(0),
    .BYTE_WRITE_WIDTH_A(DATA_WIDTH),
    .CASCADE_HEIGHT(0),
    .ECC_MODE("no_ecc"),
    .MEMORY_INIT_FILE("none"),
    .MEMORY_INIT_PARAM("0"),
    .MEMORY_OPTIMIZATION("true"),
    .MEMORY_PRIMITIVE("block"),
    .MEMORY_SIZE(DEPTH*DATA_WIDTH),
    .MESSAGE_CONTROL(0),
    .READ_DATA_WIDTH_A(DATA_WIDTH),
    .READ_LATENCY_A(1),
    .READ_RESET_VALUE_A("0"),
    .RST_MODE_A("SYNC"),
    .SIM_ASSERT_CHK(0),
    .USE_MEM_INIT(0),
    .WAKEUP_TIME("disable_sleep"),
    .WRITE_DATA_WIDTH_A(DATA_WIDTH),
    .WRITE_MODE_A("read_first")
) u_mem (
    .sleep(1'b0),
    .clka(clk),
    .rsta(1'b0),
    .ena(en),
    .regcea(1'b1),
    .wea(we),
    .addra(addr),
    .dina(din),
    .injectsbiterra(1'b0),
    .injectdbiterra(1'b0),
    .douta(dout),
    .sbiterra(),
    .dbiterra()
);

endmodule
