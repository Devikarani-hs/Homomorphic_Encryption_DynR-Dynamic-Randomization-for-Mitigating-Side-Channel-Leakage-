`timescale 1ns/1ps
module tb_standard_top;

    localparam DW     = 30;
    localparam N      = 4096;
    localparam LOG_N  = 12;
    localparam N_RPAU = 6;

    reg               clk;
    reg               rst_n;

    reg  [7:0]        cmd;
    reg               cmd_valid;
    wire              cmd_done;

    reg  [LOG_N-1:0]  wr_addr;
    reg  [31:0]       wr_data;
    reg  [2:0]        wr_rpau;
    reg  [3:0]        wr_cop;
    reg               wr_en;

    reg  [LOG_N-1:0]  rd_addr;
    reg  [2:0]        rd_rpau;
    reg  [3:0]        rd_cop;
    wire [31:0]       rd_data;
    wire              rd_valid;

    reg  [3:0]        cfg_cop;
    reg  [2:0]        cfg_rpau;
    reg  [29:0]       cfg_modulus;
    reg  [59:0]       cfg_barrett_k;
    reg  [29:0]       cfg_n_inv;
    reg               cfg_we;

    standard_top #(
        .DW(DW), .N(N), .LOG_N(LOG_N), .N_RPAU(N_RPAU), .N_COP(16)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .cmd(cmd),
        .cmd_valid(cmd_valid),
        .cmd_done(cmd_done),
        .wr_addr(wr_addr),
        .wr_data(wr_data),
        .wr_rpau(wr_rpau),
        .wr_cop(wr_cop),
        .wr_en(wr_en),
        .rd_addr(rd_addr),
        .rd_rpau(rd_rpau),
        .rd_cop(rd_cop),
        .rd_data(rd_data),
        .rd_valid(rd_valid),
        .cfg_cop(cfg_cop),
        .cfg_rpau(cfg_rpau),
        .cfg_modulus(cfg_modulus),
        .cfg_barrett_k(cfg_barrett_k),
        .cfg_n_inv(cfg_n_inv),
        .cfg_we(cfg_we)
    );

    always #5 clk = ~clk;

    task write_cfg;
        input [3:0] cop;
        input [2:0] rpau;
        input [29:0] mod;
        input [59:0] bk;
        input [29:0] ninv;
        begin
            @(posedge clk);
            cfg_cop       <= cop;
            cfg_rpau      <= rpau;
            cfg_modulus   <= mod;
            cfg_barrett_k <= bk;
            cfg_n_inv     <= ninv;
            cfg_we        <= 1'b1;
            @(posedge clk);
            cfg_we        <= 1'b0;
        end
    endtask

    task write_coeff;
        input [3:0] cop;
        input [2:0] rpau;
        input [LOG_N-1:0] addr;
        input [31:0] data;
        begin
            @(posedge clk);
            wr_cop  <= cop;
            wr_rpau <= rpau;
            wr_addr <= addr;
            wr_data <= data;
            wr_en   <= 1'b1;
            @(posedge clk);
            wr_en   <= 1'b0;
        end
    endtask

    task start_cmd;
        input [3:0] cop;
        input [2:0] op;
        begin
            @(posedge clk);
            cmd       <= {cop, 1'b1, op};
            cmd_valid <= 1'b1;
            @(posedge clk);
            cmd_valid <= 1'b0;
            cmd       <= 8'd0;
        end
    endtask

    integer c, i, r;

    initial begin
        clk = 1'b0;
        rst_n = 1'b0;
        cmd = 8'd0; cmd_valid = 1'b0;
        wr_addr = 0; wr_data = 0; wr_rpau = 0; wr_cop = 0; wr_en = 0;
        rd_addr = 0; rd_rpau = 0; rd_cop = 0;
        cfg_cop = 0; cfg_rpau = 0; cfg_modulus = 0; cfg_barrett_k = 0; cfg_n_inv = 0; cfg_we = 0;

        #50;
        rst_n = 1'b1;

        for (c = 0; c < 16; c = c + 1) begin
            for (r = 0; r < 2; r = r + 1) begin
                write_cfg(c[3:0], r[2:0], 30'd536608769 + c + r, 60'd34359738368 + c + r, 30'd536346625 + c + r);
            end
        end

        for (c = 0; c < 16; c = c + 1) begin
            for (i = 0; i < 64; i = i + 1) begin
                write_coeff(c[3:0], 3'd0, i[LOG_N-1:0], i + c + 1);
                write_coeff(c[3:0], 3'd1, i[LOG_N-1:0], (i + 1) * (c + 1));
            end
        end

        for (c = 0; c < 16; c = c + 1) begin
            start_cmd(c[3:0], 3'd4);
        end
        repeat (400) @(posedge clk);

        for (c = 0; c < 16; c = c + 1) begin
            start_cmd(c[3:0], 3'd2);
        end
        repeat (6000) @(posedge clk);

        rd_cop  = 4'd0;
        rd_rpau = 3'd0;
        rd_addr = 12'd0;
        repeat (20) @(posedge clk);

        $finish;
    end

endmodule
