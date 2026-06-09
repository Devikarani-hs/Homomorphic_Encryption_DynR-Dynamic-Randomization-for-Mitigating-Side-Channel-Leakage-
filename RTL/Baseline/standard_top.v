`timescale 1ns/1ps
module standard_top #(
    parameter DW      = 30,
    parameter N       = 4096,
    parameter LOG_N   = 12,
    parameter N_RPAU  = 6,
    parameter N_COP   = 16
)(
    input  wire              clk,
    input  wire              rst_n,

    input  wire [7:0]        cmd,
    input  wire              cmd_valid,
    output reg               cmd_done,

    input  wire [LOG_N-1:0]  wr_addr,
    input  wire [31:0]       wr_data,
    input  wire [2:0]        wr_rpau,
    input  wire [3:0]        wr_cop,
    input  wire              wr_en,

    input  wire [LOG_N-1:0]  rd_addr,
    input  wire [2:0]        rd_rpau,
    input  wire [3:0]        rd_cop,
    output reg  [31:0]       rd_data,
    output reg               rd_valid,

    input  wire [3:0]        cfg_cop,
    input  wire [2:0]        cfg_rpau,
    input  wire [29:0]       cfg_modulus,
    input  wire [59:0]       cfg_barrett_k,
    input  wire [29:0]       cfg_n_inv,
    input  wire              cfg_we
);

    localparam MODW = DW * N_RPAU;
    localparam BKW  = 2 * DW * N_RPAU;

    wire rst = ~rst_n;

    reg [DW-1:0]   modulus_r   [0:N_COP-1][0:N_RPAU-1];
    reg [2*DW-1:0] barrett_k_r [0:N_COP-1][0:N_RPAU-1];
    reg [DW-1:0]   n_inv_r     [0:N_COP-1][0:N_RPAU-1];
    reg [N_RPAU-1:0] wr_en_vec [0:N_COP-1];

    wire [MODW-1:0] modulus_flat   [0:N_COP-1];
    wire [BKW-1:0]  barrett_k_flat [0:N_COP-1];
    wire [MODW-1:0] n_inv_flat     [0:N_COP-1];
    wire [MODW-1:0] rd_dout_flat   [0:N_COP-1];
    wire [N_COP-1:0] instr_done_w;

    genvar ci, gi;
    generate
        for (ci = 0; ci < N_COP; ci = ci + 1) begin : PACK_COP
            for (gi = 0; gi < N_RPAU; gi = gi + 1) begin : PACK_RPAU
                assign modulus_flat[ci][gi*DW +: DW]       = modulus_r[ci][gi];
                assign barrett_k_flat[ci][gi*2*DW +: 2*DW] = barrett_k_r[ci][gi];
                assign n_inv_flat[ci][gi*DW +: DW]         = n_inv_r[ci][gi];
            end
        end
    endgenerate

    integer cii, gii;
    always @(posedge clk) begin
        if (rst) begin
            for (cii = 0; cii < N_COP; cii = cii + 1) begin
                wr_en_vec[cii] <= {N_RPAU{1'b0}};
                for (gii = 0; gii < N_RPAU; gii = gii + 1) begin
                    modulus_r[cii][gii]   <= {DW{1'b0}};
                    barrett_k_r[cii][gii] <= {(2*DW){1'b0}};
                    n_inv_r[cii][gii]     <= {DW{1'b0}};
                end
            end
        end else begin
            for (cii = 0; cii < N_COP; cii = cii + 1) begin
                wr_en_vec[cii] <= {N_RPAU{1'b0}};
                for (gii = 0; gii < N_RPAU; gii = gii + 1) begin
                    if (wr_en && (wr_cop == cii[3:0]) && (wr_rpau == gii[2:0]))
                        wr_en_vec[cii][gii] <= 1'b1;
                end
            end

            if (cfg_we) begin
                modulus_r[cfg_cop][cfg_rpau]   <= cfg_modulus;
                barrett_k_r[cfg_cop][cfg_rpau] <= cfg_barrett_k;
                n_inv_r[cfg_cop][cfg_rpau]     <= cfg_n_inv;
            end
        end
    end

    generate
        for (ci = 0; ci < N_COP; ci = ci + 1) begin : COP_BANK
            coprocessor #(
                .DW(DW), .N(N), .LOG_N(LOG_N), .N_RPAU(N_RPAU)
            ) u_cop (
                .clk(clk),
                .rst(rst),
                .instr(cmd[2:0]),
                .instr_valid(cmd_valid && cmd[3] && (cmd[7:4] == ci[3:0])),
                .instr_done(instr_done_w[ci]),
                .wr_addr(wr_addr),
                .wr_din_flat({N_RPAU{wr_data[DW-1:0]}}),
                .wr_en_vec(wr_en_vec[ci]),
                .rd_addr(rd_addr),
                .rd_dout_flat(rd_dout_flat[ci]),
                .modulus_flat(modulus_flat[ci]),
                .barrett_k_flat(barrett_k_flat[ci]),
                .n_inv_flat(n_inv_flat[ci])
            );
        end
    endgenerate

    always @(posedge clk) begin
        if (rst) begin
            rd_data  <= 32'd0;
            rd_valid <= 1'b0;
            cmd_done <= 1'b0;
        end else begin
            rd_data  <= {2'b00, rd_dout_flat[rd_cop][rd_rpau*DW +: DW]};
            rd_valid <= 1'b1;
            cmd_done <= |instr_done_w;
        end
    end

endmodule
