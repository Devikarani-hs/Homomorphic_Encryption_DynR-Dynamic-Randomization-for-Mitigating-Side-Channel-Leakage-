`timescale 1ns/1ps
module shuffling_controller #(
    parameter MAX_ROWS = 128,
    parameter LOG2R    = 8
)(
    input  wire               clk,
    input  wire               rst_n,
    input  wire               load_seed,
    input  wire [31:0]        seed,
    input  wire               start_shuffle,
    input  wire [LOG2R-1:0]   num_rows,
    input  wire               next_req,
    output reg  [LOG2R-1:0]   row_out,
    output reg                row_valid,
    output reg                shuf_done,
    output reg  [5:0]         rand_vl
);
reg [LOG2R-1:0] dp;
reg running, ready;
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        running <= 0; ready <= 0; shuf_done <= 0;
        dp <= 0; row_valid <= 0; row_out <= 0; rand_vl <= 16;
    end else begin
        row_valid <= 0; shuf_done <= 0;
        if (start_shuffle) begin
            dp <= 0; running <= 1; ready <= 1; shuf_done <= 1;
        end
        if (ready && next_req && (dp < num_rows)) begin
            row_out <= dp; // LINEAR OUTPUT, NO SHUFFLE
            row_valid <= 1; dp <= dp + 1'b1; rand_vl <= 8;
        end
    end
end
endmodule
