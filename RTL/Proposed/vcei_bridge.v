`timescale 1ns/1ps
// ============================================================
// vcei_bridge.v  --  AXI4-Lite Control Register Bridge
// Maps host writes to safe_top_engine control signals
// ============================================================
module vcei_bridge #(
    parameter ADDR_W = 32,
    parameter DATA_W = 32,
    parameter COEF_W = 36,
    parameter LOG2_N = 12,
    parameter MOD_W  = 36
)(
    input  wire               clk, rst_n,
    // AXI4-Lite slave
    input  wire [ADDR_W-1:0]  s_awaddr,
    input  wire               s_awvalid,
    output wire               s_awready,
    input  wire [DATA_W-1:0]  s_wdata,
    input  wire               s_wvalid,
    output wire               s_wready,
    output wire [1:0]         s_bresp,
    output wire               s_bvalid,
    input  wire               s_bready,
    input  wire [ADDR_W-1:0]  s_araddr,
    input  wire               s_arvalid,
    output wire               s_arready,
    output wire [DATA_W-1:0]  s_rdata,
    output wire [1:0]         s_rresp,
    output wire               s_rvalid,
    input  wire               s_rready,
    // Engine control
    output reg                eng_start,
    output reg  [1:0]         eng_mode,
    output reg  [6:0]         eng_rows,
    output reg  [MOD_W-1:0]   eng_modulus,
    output reg  [31:0]        eng_seed,
    output reg                eng_load_seed,
    input  wire               eng_done,
    input  wire               eng_busy,
    input  wire [3:0]         eng_stage,
    // Data ports pass-through
    output reg  [COEF_W-1:0]  pt_coef,
    output reg  [LOG2_N-1:0]  pt_addr,
    output reg                pt_we,
    output reg  [COEF_W-1:0]  ct_coef,
    output reg  [LOG2_N-1:0]  ct_addr,
    output reg                ct_we,
    output reg  [LOG2_N-1:0]  result_addr,
    output reg                irq
);
// Register map:
// 0x00: CTRL   [0]=start [1]=load_seed
// 0x04: STATUS [0]=busy  [1]=done  [7:4]=stage
// 0x08: ROWS
// 0x0C: MOD_LO
// 0x10: MOD_HI
// 0x14: SEED
// 0x18: MODE

reg [DATA_W-1:0] csr [0:6];
reg aw_pend, w_pend, bv;
reg [ADDR_W-1:0] aw_r;
reg arv, rv;
reg [DATA_W-1:0] rdat;

assign s_awready = !aw_pend;
assign s_wready  = !w_pend;
assign s_bresp   = 2'b00;
assign s_bvalid  = bv;
assign s_arready = !arv;
assign s_rdata   = rdat;
assign s_rresp   = 2'b00;
assign s_rvalid  = rv;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        aw_pend<=0;w_pend<=0;bv<=0;aw_r<=0;
        eng_start<=0;eng_load_seed<=0;pt_we<=0;ct_we<=0;irq<=0;
        eng_mode<=0;eng_rows<=4;eng_modulus<=0;eng_seed<=0;
        pt_coef<=0;pt_addr<=0;ct_coef<=0;ct_addr<=0;result_addr<=0;
    end else begin
        eng_start<=0; eng_load_seed<=0;
        if (s_awvalid&&!aw_pend) begin aw_r<=s_awaddr; aw_pend<=1; end
        if (s_wvalid&&!w_pend) begin
            csr[aw_r[4:2]]<=s_wdata; w_pend<=1;
            case(aw_r[4:2])
                3'd0: begin eng_start<=s_wdata[0]; eng_load_seed<=s_wdata[1]; end
                3'd2: eng_rows    <= s_wdata[6:0];
                3'd3: eng_modulus[31:0]  <= s_wdata;
                3'd4: eng_modulus[35:32] <= s_wdata[3:0];
                3'd5: eng_seed    <= s_wdata;
                3'd6: eng_mode    <= s_wdata[1:0];
                default:;
            endcase
        end
        if (aw_pend&&w_pend) begin bv<=1; aw_pend<=0; w_pend<=0; end
        if (bv&&s_bready) bv<=0;
        if (eng_done) irq<=1;
        if (eng_start) irq<=0;
    end
end

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin arv<=0; rv<=0; rdat<=0; end
    else begin
        if (s_arvalid&&!arv) begin
            arv<=1; rv<=1;
            case(s_araddr[4:2])
                3'd1: rdat<={24'b0,eng_stage,2'b0,eng_done,eng_busy};
                default: rdat<=csr[s_araddr[4:2]];
            endcase
        end
        if (rv&&s_rready) begin rv<=0; arv<=0; end
    end
end
endmodule
