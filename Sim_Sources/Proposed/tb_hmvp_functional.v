module tb_hmvp_functional;
    parameter N = 4096;
    parameter COEF_W = 36;
    parameter MOD_W = 36;
    parameter LOG2_N = 12;
    parameter LOG2R = 8;
//new
    reg clk, rst_n, start;
    reg [1:0] hmvp_mode;
    reg [LOG2R-1:0] num_rows;
    reg [MOD_W-1:0] modulus;
    reg [31:0] shuf_seed;
    reg load_seed;

    reg [COEF_W-1:0] pt_coef_in, ct_coef_in;
    reg [LOG2_N-1:0] pt_addr, ct_addr;
    reg pt_we, ct_we;

    reg [LOG2_N-1:0] result_addr;
    wire [COEF_W-1:0] result_coef;
    wire done, busy;

    // [FIX]: Removed probe_ntt_a, probe_ntt_b, probe_acu_r, pipeline_stage
    // These do not exist as external ports in the physical synthesized netlist.

    reg [COEF_W-1:0] pt_mem [0:N-1];
    reg [COEF_W-1:0] ct_mem [0:N-1];
    integer i;
    integer file_out;
    // integer dbg; // [FIX]: Disabled debug log

    safe_top_engine #(
        .N(N),
        .LOG2_N(LOG2_N),
        .COEF_W(COEF_W),
        .MOD_W(MOD_W),
        .MAX_ROWS(256),
        .LOG2R(LOG2R)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .start(start),
        .hmvp_mode(hmvp_mode),
        .num_rows(num_rows),
        .modulus(modulus),
        .shuf_seed(shuf_seed),
        .load_seed(load_seed),
        .pt_coef_in(pt_coef_in),
        .pt_addr(pt_addr),
        .pt_we(pt_we),
        .ct_coef_in(ct_coef_in),
        .ct_addr(ct_addr),
        .ct_we(ct_we),
        .result_addr(result_addr),
        .result_coef(result_coef),
        .done(done),
        .busy(busy)
        // [FIX]: Removed the debug port connections here
    );

    always #5 clk = ~clk;

    initial begin
        // The failsafe timeout
        #400000000;
        $display("\n[!] FATAL ERROR: Simulation Timeout! FSM Hung.\n");
        // $stop;
    end

    initial begin
        $readmemh("/home/cwell/Desktop/Devika/he_accelerator_vivado/results/pt_in.txt", pt_mem);
        $readmemh("/home/cwell/Desktop/Devika/he_accelerator_vivado/results/ct_in.txt", ct_mem);

        file_out = $fopen("/home/cwell/Desktop/Devika/he_accelerator_vivado/results/rtl_out.txt", "w");
        // dbg      = $fopen("/home/cwell/Desktop/Devika/he_accelerator_vivado/results/fsm_trace.txt", "w");

        if (file_out == 0) begin
            $display("[ERROR] Could not open rtl_out.txt");
        end

        // [FIX]: Disabled the header for the debug file
        // $fdisplay(dbg, "time fsm ps busy...");

        clk = 0;
        rst_n = 0;
        start = 0;
        pt_we = 0;
        ct_we = 0;
        pt_addr = 0;
        ct_addr = 0;
        pt_coef_in = 0;
        ct_coef_in = 0;
        result_addr = 0;
        modulus = 12289;
        shuf_seed = 32'hDEADBEEF;
        load_seed = 1;
        hmvp_mode = 2'b01;
        num_rows = 128;

        #20;
        rst_n = 1;
        load_seed = 0;

        for (i = 0; i < N; i = i + 1) begin
            @(posedge clk);
            #1;
            pt_we = 1;
            ct_we = 1;
            pt_addr = i;
            ct_addr = i;
            pt_coef_in = pt_mem[i];
            ct_coef_in = ct_mem[i];
        end

        @(posedge clk);
        #1;
        pt_we = 0;
        ct_we = 0;

        #20;
        @(posedge clk);
        #1 start = 1;
        @(posedge clk);
        #1 start = 0;

        wait(done);

        for (i = 0; i < N; i = i + 1) begin
            result_addr = i;
            @(posedge clk);
            #1;
            $fdisplay(file_out, "%09x", result_coef);
        end

        $fclose(file_out);
        // $fclose(dbg);

        #100;
        // $stop;
    end

    // [FIX]: CRITICAL - Completely commented out the hierarchical polling block
    // always @(posedge clk) begin
    //     if (dbg != 0) begin
    //         $fdisplay(dbg, "%0t %0d...", $time, dut.fsm, ...);
    //     end
    // end
endmodule
