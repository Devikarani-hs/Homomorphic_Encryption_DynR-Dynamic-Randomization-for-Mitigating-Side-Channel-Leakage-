`timescale 1ns/1ps
module shuffling_controller #(
    parameter MAX_ROWS = 128,
    parameter LOG2R    = 8
)(
    input  wire              clk,
    input  wire              rst_n,
    input  wire              load_seed,
    input  wire [31:0]       seed,
    input  wire              start_shuffle,
    input  wire [LOG2R-1:0]  num_rows,
    input  wire              next_req,
    output reg  [LOG2R-1:0]  row_out,
    output reg               row_valid,
    output reg               shuf_done,
    output reg  [5:0]        rand_vl
);

// Internal RAM to hold the shuffled indices
reg [LOG2R-1:0] shuf_mem [0:MAX_ROWS-1];

// Fisher-Yates State Machine
localparam IDLE = 2'd0, INIT = 2'd1, SHUFFLE = 2'd2, READY = 2'd3;
reg [1:0] state;

reg [LOG2R-1:0] i_cnt;
reg [LOG2R-1:0] dp;
reg [31:0] lfsr;

// 32-bit Galois LFSR for Hardware Pseudo-Randomness
wire lfsr_fb = lfsr[0];
wire [31:0] next_lfsr = {lfsr_fb, lfsr[31:1]} ^ (lfsr_fb ? 32'h80200003 : 32'h0);

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        lfsr <= 32'hACE1ACE1;
    end else if (load_seed) begin
        lfsr <= seed;
    end else if (state == SHUFFLE) begin
        lfsr <= next_lfsr;
    end
end

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
        i_cnt <= 0;
        dp <= 0;
        row_out <= 0;
        row_valid <= 0;
        shuf_done <= 0;
        rand_vl <= 16;
    end else begin
        row_valid <= 0;
        shuf_done <= 0;

        case (state)
            IDLE: begin
                if (start_shuffle) begin
                    state <= INIT;
                    i_cnt <= 0;
                end
            end
            INIT: begin
                shuf_mem[i_cnt] <= i_cnt;
                if (i_cnt == num_rows - 1'b1) begin
                    state <= SHUFFLE;
                    i_cnt <= num_rows - 1'b1;
                end else begin
                    i_cnt <= i_cnt + 1'b1;
                end
            end
            SHUFFLE: begin
                shuf_mem[i_cnt] <= shuf_mem[lfsr[6:0]];
                shuf_mem[lfsr[6:0]] <= shuf_mem[i_cnt];

                if (i_cnt == 0) begin
                    state <= READY;
                    dp <= 0;
                    shuf_done <= 1;
                end else begin
                    i_cnt <= i_cnt - 1'b1;
                end
            end
            READY: begin
                if (start_shuffle) begin
                    state <= INIT;
                    i_cnt <= 0;
                end else if (next_req && (dp < num_rows)) begin
                    row_out <= shuf_mem[dp];
                    row_valid <= 1;
                    dp <= dp + 1'b1;
                    rand_vl <= lfsr[5:0];
                end
            end
        endcase
    end
end
endmodule
