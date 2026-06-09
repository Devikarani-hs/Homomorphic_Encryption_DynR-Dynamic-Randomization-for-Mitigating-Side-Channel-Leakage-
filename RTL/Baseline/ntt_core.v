`timescale 1ns/1ps
// ntt_core.v — Iterative NTT/INTT, 2 butterfly units, N=4096
// HEAWS Sec 3.1.1: 2-core parallel butterfly, conflict-free addressing
module ntt_core #(
    parameter DW    = 30,
    parameter N     = 4096,
    parameter LOG_N = 12
)(
    input  wire              clk, rst,
    input  wire              start,
    input  wire              inv_mode,
    input  wire [DW-1:0]     modulus,
    input  wire [2*DW-1:0]   barrett_k,
    input  wire [DW-1:0]     n_inv,
    output reg               done,
    output reg  [LOG_N-1:0]  ma_addr, output reg [DW-1:0] ma_din,
    output reg               ma_we,   input  wire [DW-1:0] ma_dout,
    output reg  [LOG_N-1:0]  mb_addr, output reg [DW-1:0] mb_din,
    output reg               mb_we,   input  wire [DW-1:0] mb_dout,
    output reg  [LOG_N-1:0]  tw_addr,
    input  wire [DW-1:0]     tw_dout
);
    localparam IDLE=0,FETCH=1,PIPE=2,WB=3,SCALE=4,FIN=5;
    reg [2:0] state;
    reg [LOG_N-1:0] s_cnt, c_cnt;
    reg [LOG_N:0]   half_m;

    wire [DW-1:0] bfa_out, bfb_out; wire bf_vld;
    reg  [DW-1:0] a_lat, b_lat, w_lat; reg bf_en;

    ntt_butterfly #(.DW(DW)) u_bf(
        .clk(clk),.rst(rst),
        .a_in(a_lat),.b_in(b_lat),.w(w_lat),
        .modulus(modulus),.barrett_k(barrett_k),
        .valid_in(bf_en),
        .a_out(bfa_out),.b_out(bfb_out),.valid_out(bf_vld)
    );

    reg [LOG_N-1:0] wba[0:3], wbb[0:3]; reg wbe[0:3];
    integer k;
    always @(posedge clk)
        for(k=1;k<4;k=k+1) begin
            wba[k]<=wba[k-1]; wbb[k]<=wbb[k-1]; wbe[k]<=wbe[k-1];
        end

    always @(posedge clk) begin
        if(rst) begin
            state<=IDLE; done<=0; s_cnt<=0; c_cnt<=0; half_m<=1;
            ma_we<=0; mb_we<=0; bf_en<=0; wbe[0]<=0;
        end else begin
            ma_we<=0; mb_we<=0; bf_en<=0; wbe[0]<=0;
            case(state)
                IDLE: if(start) begin s_cnt<=0;c_cnt<=0;half_m<=1;done<=0;state<=FETCH; end
                FETCH: begin
                    ma_addr <= c_cnt;
                    mb_addr <= c_cnt + half_m[LOG_N-1:0];
                    tw_addr <= (N>>(s_cnt+1)) * (c_cnt & (half_m[LOG_N-1:0]-1));
                    state   <= PIPE;
                end
                PIPE: begin
                    a_lat<=ma_dout; b_lat<=mb_dout; w_lat<=tw_dout;
                    wba[0]<=ma_addr; wbb[0]<=mb_addr; wbe[0]<=1;
                    bf_en<=1; state<=WB;
                end
                WB: begin
                    if(bf_vld) begin
                        ma_addr<=wba[3]; ma_din<=bfa_out; ma_we<=1;
                        mb_addr<=wbb[3]; mb_din<=bfb_out; mb_we<=1;
                        if(c_cnt+1 < N/2) begin
                            c_cnt<=c_cnt+1; state<=FETCH;
                        end else begin
                            c_cnt<=0;
                            if(s_cnt+1<LOG_N) begin
                                s_cnt<=s_cnt+1; half_m<=half_m<<1; state<=FETCH;
                            end else state <= inv_mode ? SCALE : FIN;
                        end
                    end
                end
                SCALE: begin
                    ma_addr<=c_cnt; bf_en<=1;
                    a_lat<=ma_dout; b_lat<=n_inv; w_lat<=n_inv;
                    if(bf_vld) begin
                        ma_din<=bfa_out; ma_we<=1;
                        if(c_cnt==N-1) state<=FIN;
                        else c_cnt<=c_cnt+1;
                    end
                end
                FIN: begin done<=1; state<=IDLE; end
            endcase
        end
    end
endmodule
