`timescale 1ns/1ps
// scale_unit.v — RNS Basis Scaling Scale_Q->q (HEAWS Sec 2.6, 3.3)
// Fixed: renamed 'buf' array to 'coef_buf' (buf is a Verilog-2001 keyword)
module scale_unit #(
    parameter DW   = 30,
    parameter L_QQ = 13
)(
    input  wire             clk,
    input  wire             rst,
    input  wire             start,
    input  wire [DW-1:0]    a_in,
    input  wire             a_valid,
    output reg  [DW-1:0]    a_out,
    output reg              a_out_valid,
    output reg              done
);
    localparam [DW-1:0] T_QBAR = 30'h001F_FFFF;

    reg [3*DW-1:0] mac1, mac2;
    reg [3:0]      stage;
    reg            busy;
    reg [DW-1:0]   coef_buf [0:L_QQ-1];   // renamed from 'buf'
    reg [3:0]      in_cnt;

    always @(posedge clk) begin
        if (rst) begin
            stage       <= 0;
            busy        <= 0;
            mac1        <= 0;
            mac2        <= 0;
            a_out_valid <= 0;
            done        <= 0;
            in_cnt      <= 0;
        end else begin
            a_out_valid <= 0;
            done        <= 0;

            // Accumulate incoming Q-basis shares
            if (a_valid && !busy) begin
                coef_buf[in_cnt] <= a_in;
                in_cnt           <= in_cnt + 1;
                if (in_cnt == L_QQ - 1) begin
                    busy   <= 1;
                    stage  <= 0;
                    in_cnt <= 0;
                end
            end

            // 6-stage MAC pipeline (HPS approximation, HEAWS Sec 2.6)
            if (busy) begin
                stage <= stage + 1;
                case (stage)
                    4'd0: mac1 <= coef_buf[0]  * T_QBAR;
                    4'd1: mac1 <= mac1 + coef_buf[1] * T_QBAR;
                    4'd2: mac1 <= mac1 + coef_buf[2] * T_QBAR;
                    4'd3: mac2 <= coef_buf[6]  * T_QBAR;
                    4'd4: mac2 <= mac2 + coef_buf[7] * T_QBAR;
                    4'd5: begin
                        a_out       <= mac1[DW-1:0] + mac2[DW-1:0];
                        a_out_valid <= 1;
                        busy        <= 0;
                        done        <= 1;
                    end
                    default: ;
                endcase
            end
        end
    end
endmodule
