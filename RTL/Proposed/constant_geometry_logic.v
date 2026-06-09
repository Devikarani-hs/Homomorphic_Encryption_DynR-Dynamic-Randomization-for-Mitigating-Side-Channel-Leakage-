`timescale 1ns/1ps
// ============================================================
// constant_geometry_logic.v
// CG-NTT address generator: N=4096, NBF=4 parallel BFUs
// Produces rd/wr/tf addresses and swap_en per BFU per cycle
// ============================================================
module constant_geometry_logic #(
    parameter N      = 4096,
    parameter LOG2_N = 12,
    parameter NBF    = 4
)(
    input  wire              clk, rst_n, start,
    output reg [LOG2_N-1:0]  stage_idx,
    output reg [LOG2_N-2:0]  rd_base,
    output reg [LOG2_N-1:0]  rd_addr_0, rd_addr_1, rd_addr_2, rd_addr_3,
    output reg [LOG2_N-1:0]  wr_addr_0, wr_addr_1, wr_addr_2, wr_addr_3,
    output reg [LOG2_N-1:0]  tf_addr_0, tf_addr_1, tf_addr_2, tf_addr_3,
    output reg [NBF-1:0]     swap_en,
    output reg               valid,
    output reg               done
);

localparam GRPS = (N/2)/NBF;   // 512

reg               running;
reg [LOG2_N-1:0]  s;
reg [LOG2_N-2:0]  g;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        running<=0; done<=0; valid<=0; s<=0; g<=0;
        stage_idx<=0; rd_base<=0;
        rd_addr_0<=0; rd_addr_1<=0; rd_addr_2<=0; rd_addr_3<=0;
        wr_addr_0<=0; wr_addr_1<=0; wr_addr_2<=0; wr_addr_3<=0;
        tf_addr_0<=0; tf_addr_1<=0; tf_addr_2<=0; tf_addr_3<=0;
        swap_en<=0;
    end else begin
        done<=0; valid<=0;
        if (start && !running) begin running<=1; s<=0; g<=0; end
        if (running) begin
            valid     <= 1;
            stage_idx <= s;
            rd_base   <= g;
            rd_addr_0 <= g*NBF;   wr_addr_0 <= g*NBF;
            tf_addr_0 <= ({{(LOG2_N-1){1'b0}},1'b1} << s) + ((g*NBF+0) >> (LOG2_N-1-s));
            swap_en[0]<= ((g*NBF+0) >> (LOG2_N-1-s)) & 1'b1;
            rd_addr_1 <= g*NBF+1; wr_addr_1 <= g*NBF+1;
            tf_addr_1 <= ({{(LOG2_N-1){1'b0}},1'b1} << s) + ((g*NBF+1) >> (LOG2_N-1-s));
            swap_en[1]<= ((g*NBF+1) >> (LOG2_N-1-s)) & 1'b1;
            rd_addr_2 <= g*NBF+2; wr_addr_2 <= g*NBF+2;
            tf_addr_2 <= ({{(LOG2_N-1){1'b0}},1'b1} << s) + ((g*NBF+2) >> (LOG2_N-1-s));
            swap_en[2]<= ((g*NBF+2) >> (LOG2_N-1-s)) & 1'b1;
            rd_addr_3 <= g*NBF+3; wr_addr_3 <= g*NBF+3;
            tf_addr_3 <= ({{(LOG2_N-1){1'b0}},1'b1} << s) + ((g*NBF+3) >> (LOG2_N-1-s));
            swap_en[3]<= ((g*NBF+3) >> (LOG2_N-1-s)) & 1'b1;
            if (g == GRPS-1) begin
                g<=0;
                if (s==LOG2_N-1) begin running<=0; done<=1; valid<=0; end
                else s<=s+1;
            end else g<=g+1;
        end
    end
end
endmodule
