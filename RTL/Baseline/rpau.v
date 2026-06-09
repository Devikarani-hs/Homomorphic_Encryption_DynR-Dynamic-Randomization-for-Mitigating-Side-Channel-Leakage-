`timescale 1ns/1ps
// rpau.v — Residue Polynomial Arithmetic Unit (one per RNS prime qi)
// op: 0=NTT 1=INTT 2=PWM 3=ADD 4=LOAD 5=READ
module rpau #(
    parameter DW        = 30,
    parameter N         = 4096,
    parameter LOG_N     = 12,
    parameter INIT_TW   = "twiddle_q0.mem"
)(
    input  wire             clk, rst,
    input  wire [2:0]       op,
    input  wire             start,
    output reg              done,
    input  wire [DW-1:0]    modulus,
    input  wire [2*DW-1:0]  barrett_k,
    input  wire [DW-1:0]    n_inv,
    input  wire [LOG_N-1:0] wr_addr,
    input  wire [DW-1:0]    wr_din,
    input  wire             wr_en,
    input  wire [LOG_N-1:0] rd_addr,
    output wire [DW-1:0]    rd_dout,
    input  wire [LOG_N-1:0] b_addr,
    output wire [DW-1:0]    b_dout
);
    reg  [LOG_N-1:0] m0a_addr, m0b_addr;
    reg  [DW-1:0]    m0a_din,  m0b_din;
    reg              m0a_we,   m0b_we;
    wire [DW-1:0]    m0a_dout, m0b_dout;

    poly_mem #(.DW(DW),.DEPTH(N)) u_mem0(
        .clk(clk),
        .addr_a(m0a_addr),.din_a(m0a_din),.we_a(m0a_we),.dout_a(m0a_dout),
        .addr_b(m0b_addr),.din_b(m0b_din),.we_b(m0b_we),.dout_b(m0b_dout)
    );
    poly_mem #(.DW(DW),.DEPTH(N)) u_mem1(
        .clk(clk),
        .addr_a(b_addr),.din_a(wr_din),.we_a(wr_en & (op==3'd4)),.dout_a(b_dout),
        .addr_b(rd_addr),.din_b({DW{1'b0}}),.we_b(1'b0),.dout_b(rd_dout)
    );

    wire [LOG_N-1:0] ntt_ma, ntt_mb, ntt_tw;
    wire [DW-1:0]    ntt_madin, ntt_mbdin, ntt_twdout;
    wire             ntt_mawe, ntt_mbwe, ntt_done;

    twiddle_rom #(.DW(DW),.DEPTH(N),.INIT_FILE(INIT_TW)) u_tw(
        .clk(clk),.addr(ntt_tw),.dout(ntt_twdout)
    );
    ntt_core #(.DW(DW),.N(N),.LOG_N(LOG_N)) u_ntt(
        .clk(clk),.rst(rst),
        .start(start & (op==3'd0|op==3'd1)),
        .inv_mode(op==3'd1),
        .modulus(modulus),.barrett_k(barrett_k),.n_inv(n_inv),
        .done(ntt_done),
        .ma_addr(ntt_ma),.ma_din(ntt_madin),.ma_we(ntt_mawe),.ma_dout(m0a_dout),
        .mb_addr(ntt_mb),.mb_din(ntt_mbdin),.mb_we(ntt_mbwe),.mb_dout(m0b_dout),
        .tw_addr(ntt_tw),.tw_dout(ntt_twdout)
    );

    reg [LOG_N-1:0] alu_cnt; reg alu_run;
    wire [DW-1:0] pwm_r,add_r; wire pwm_v,add_v;

    mod_mul_30 #(.DW(DW)) u_pwm(
        .clk(clk),.rst(rst),.a(m0a_dout),.b(b_dout),
        .modulus(modulus),.barrett_k(barrett_k),
        .valid_in(alu_run & (op==3'd2)),
        .result(pwm_r),.valid_out(pwm_v)
    );
    mod_add #(.DW(DW)) u_add(
        .clk(clk),.rst(rst),.a(m0a_dout),.b(b_dout),
        .modulus(modulus),.valid_in(alu_run & (op==3'd3)),
        .result(add_r),.valid_out(add_v)
    );

    always @(*) begin
        if(op==3'd0|op==3'd1) begin
            m0a_addr=ntt_ma; m0a_din=ntt_madin; m0a_we=ntt_mawe;
            m0b_addr=ntt_mb; m0b_din=ntt_mbdin; m0b_we=ntt_mbwe;
        end else if(op==3'd4) begin
            m0a_addr=wr_addr; m0a_din=wr_din; m0a_we=wr_en;
            m0b_addr=0; m0b_din=0; m0b_we=0;
        end else begin
            m0a_addr=alu_cnt; m0a_din=0; m0a_we=0;
            m0b_addr=alu_cnt;
            m0b_din=(op==3'd2)?pwm_r:add_r;
            m0b_we =(op==3'd2)?pwm_v:add_v;
        end
    end

    always @(posedge clk) begin
        if(rst) begin alu_cnt<=0;alu_run<=0;done<=0; end
        else begin
            done<=0;
            if(start&(op==3'd2|op==3'd3)) begin alu_cnt<=0;alu_run<=1; end
            if(alu_run) begin
                alu_cnt<=alu_cnt+1;
                if(alu_cnt==N-1) begin alu_run<=0;done<=1; end
            end
            if(op==3'd0|op==3'd1) done<=ntt_done;
        end
    end
endmodule
