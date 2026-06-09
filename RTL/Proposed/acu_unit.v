`timescale 1ns/1ps
// ============================================================
// acu_unit.v -- Arithmetic Computing Unit
// Op: 00=ModAdd  01=ModSub  10=ModMul(Barrett)  11=Pass
// DATA_W=36 covers 34-bit BFV moduli
// Fully synthesizable, 3-stage pipeline
// ============================================================
module acu_unit #(
    parameter DATA_W = 36,
    parameter MOD_W  = 36
)(
    input  wire               clk, rst_n,
    input  wire [1:0]         op,
    input  wire [DATA_W-1:0]  a, b,
    input  wire [MOD_W-1:0]   q,
    input  wire               valid_in,
    output reg  [DATA_W-1:0]  result,
    output reg                valid_out
);

// Modular Add (constant-time)
wire [DATA_W:0] add_s  = {1'b0,a} + {1'b0,b};
wire [DATA_W:0] add_r  = add_s - {1'b0,q};
wire [DATA_W-1:0] mod_add = add_r[DATA_W] ? add_s[DATA_W-1:0] : add_r[DATA_W-1:0];

// Modular Sub (constant-time)
wire [DATA_W:0] sub_d  = {1'b0,a} - {1'b0,b};
wire [DATA_W:0] sub_r  = sub_d  + {1'b0,q};
wire [DATA_W-1:0] mod_sub = sub_d[DATA_W] ? sub_r[DATA_W-1:0] : sub_d[DATA_W-1:0];

// Barrett Multiply: 3-stage pipeline
reg [2*DATA_W-1:0] s1_prod;
reg [DATA_W-1:0]   s2_qest, s2_tlow;
reg [DATA_W-1:0]   s3_res;
reg [2:0]          vld_pipe;
reg [1:0]          op_p1, op_p2, op_p3;
reg [DATA_W-1:0]   lin_p1, lin_p2, lin_p3;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        s1_prod<=0; s2_qest<=0; s2_tlow<=0; s3_res<=0;
        vld_pipe<=0; op_p1<=0; op_p2<=0; op_p3<=0;
        lin_p1<=0; lin_p2<=0; lin_p3<=0;
    end else begin
        // Stage 1: product
        s1_prod     <= a * b;
        op_p1       <= op;
        lin_p1      <= (op==2'b00) ? mod_add :
                       (op==2'b01) ? mod_sub : a;
        vld_pipe[0] <= valid_in;
        // Stage 2: Barrett upper/lower
        s2_qest     <= s1_prod[2*DATA_W-1:DATA_W];
        s2_tlow     <= s1_prod[DATA_W-1:0];
        op_p2       <= op_p1;
        lin_p2      <= lin_p1;
        vld_pipe[1] <= vld_pipe[0];
        // Stage 3: remainder + reduce
        begin : s3blk
            reg [DATA_W:0] rem;
            rem    = {1'b0,s2_tlow} - s2_qest * q;
            s3_res <= rem[DATA_W] ? rem[DATA_W-1:0]+q : rem[DATA_W-1:0];
        end
        op_p3       <= op_p2;
        lin_p3      <= lin_p2;
        vld_pipe[2] <= vld_pipe[1];
    end
end

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin result<=0; valid_out<=0; end
    else begin
        valid_out <= vld_pipe[2];
        result    <= (op_p3==2'b10) ? s3_res : lin_p3;
    end
end
endmodule
