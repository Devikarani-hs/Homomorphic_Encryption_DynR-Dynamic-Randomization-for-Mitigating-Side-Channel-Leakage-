`timescale 1ns/1ps
module tb_standard_saif;
    parameter DW     = 30;
    parameter N      = 4096;
    parameter LOG_N  = 12;
    parameter N_RPAU = 6;
    parameter [DW-1:0] PRIME0 = 30'd536887297;

    reg        clk, rst_n;
    reg  [7:0] cmd; reg cmd_valid; wire cmd_done;
    reg  [LOG_N-1:0] wr_addr; reg [31:0] wr_data;
    reg  [2:0]       wr_rpau; reg        wr_en;
    reg  [LOG_N-1:0] rd_addr; reg [2:0]  rd_rpau;
    wire [31:0]      rd_data; wire       rd_valid;
    reg  [2:0]       cfg_rpau;
    reg  [29:0]      cfg_modulus;
    reg  [59:0]      cfg_barrett_k;
    reg  [29:0]      cfg_n_inv;
    reg              cfg_we;

    standard_top #(.DW(DW),.N(N),.LOG_N(LOG_N),.N_RPAU(N_RPAU)) dut(
        .clk(clk),.rst_n(rst_n),
        .cmd(cmd),.cmd_valid(cmd_valid),.cmd_done(cmd_done),
        .wr_addr(wr_addr),.wr_data(wr_data),.wr_rpau(wr_rpau),.wr_en(wr_en),
        .rd_addr(rd_addr),.rd_rpau(rd_rpau),.rd_data(rd_data),.rd_valid(rd_valid),
        .cfg_rpau(cfg_rpau),.cfg_modulus(cfg_modulus),
        .cfg_barrett_k(cfg_barrett_k),.cfg_n_inv(cfg_n_inv),.cfg_we(cfg_we)
    );

    always #2.5 clk = ~clk;
    integer i, r, rep;

    task configure_all;
        begin
            for (r=0;r<N_RPAU;r=r+1) begin
                @(posedge clk); #0.5;
                cfg_rpau=r[2:0]; cfg_modulus=PRIME0;
                cfg_barrett_k=60'h000B504F333F9DE6;
                cfg_n_inv=30'd536886161; cfg_we=1;
                @(posedge clk); #0.5; cfg_we=0;
            end
        end
    endtask

    task load_random;
        input [2:0] ridx;
        begin
            for (i=0;i<N;i=i+1) begin
                @(posedge clk); #0.5;
                wr_addr=i[LOG_N-1:0];
                wr_data={2'b0, $random % PRIME0};
                wr_rpau=ridx; wr_en=1;
            end
            @(posedge clk); #0.5; wr_en=0;
        end
    endtask

    task send_cmd;
        input [2:0] op;
        begin
            @(posedge clk); #0.5;
            cmd={4'b0001,op}; cmd_valid=1;
            @(posedge clk); #0.5; cmd_valid=0;
            wait(cmd_done); @(posedge clk);
        end
    endtask

    initial begin
        $dumpfile("heaws_power.vcd");
        $dumpvars(0, dut);
    end

    initial begin
        clk=0; rst_n=0; cmd=0; cmd_valid=0;
        wr_addr=0; wr_data=0; wr_rpau=0; wr_en=0;
        rd_addr=0; rd_rpau=0; cfg_we=0;
        cfg_modulus=0; cfg_barrett_k=0; cfg_n_inv=0; cfg_rpau=0;

        repeat(10) @(posedge clk); rst_n=1;
        repeat(5)  @(posedge clk);
        configure_all;

        for (rep=0;rep<3;rep=rep+1) begin
            load_random(3'd0);
            send_cmd(3'd0);   // NTT
            load_random(3'd0);
            send_cmd(3'd0);   // NTT ct
            send_cmd(3'd2);   // PWM
            send_cmd(3'd1);   // INTT
            $display("[SAIF-TB] rep %0d done", rep);
        end

        $display("[SAIF-TB] Complete.");
        #1000; $finish;
    end

    initial begin #200_000_000; $display("[SAIF-TB] TIMEOUT"); $finish; end
endmodule
