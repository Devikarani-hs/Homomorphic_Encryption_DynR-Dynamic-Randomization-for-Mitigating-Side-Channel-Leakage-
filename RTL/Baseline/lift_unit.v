`timescale 1ns/1ps
// lift_unit.v — RNS Basis Extension Lift_q->Q (HEAWS Sec 2.5, 3.2)
// 7-cycle block pipeline per coefficient
// Fixed: renamed 'buf' array to 'coef_buf' (buf is a Verilog-2001 keyword)
module lift_unit #(
    parameter DW    = 30,
    parameter L_IN  = 6,
    parameter L_OUT = 7
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
    localparam [DW-1:0] Q_BAR = 30'h0055_5555;

    reg [3*DW-1:0] accum;
    reg [2:0]      stage;
    reg            busy;
    reg [DW-1:0]   coef_buf [0:L_IN-1];   // renamed from 'buf'
    reg [2:0]      in_cnt;

    always @(posedge clk) begin
        if (rst) begin
            stage       <= 0;
            busy        <= 0;
            accum       <= 0;
            a_out_valid <= 0;
            done        <= 0;
            in_cnt      <= 0;
        end else begin
            a_out_valid <= 0;
            done        <= 0;

            // Accumulate incoming RNS shares
            if (a_valid && !busy) begin
                coef_buf[in_cnt] <= a_in;
                in_cnt           <= in_cnt + 1;
                if (in_cnt == L_IN - 1) begin
                    busy   <= 1;
                    stage  <= 0;
                    in_cnt <= 0;
                end
            end

            // 7-stage pipeline for MAC over L_IN shares
            if (busy) begin
                stage <= stage + 1;
                case (stage)
                    3'd0: accum <= coef_buf[0] * Q_BAR;
                    3'd1: accum <= accum + coef_buf[1] * Q_BAR;
                    3'd2: accum <= accum + coef_buf[2] * Q_BAR;
                    3'd3: accum <= accum + coef_buf[3] * Q_BAR;
                    3'd4: accum <= accum + coef_buf[4] * Q_BAR;
                    3'd5: accum <= accum + coef_buf[5] * Q_BAR;
                    3'd6: begin
                        a_out       <= accum[DW-1:0];
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
