// =============================================================================
// Module: tb_mac_array_4x4
// Description: Self-checking testbench for 4x4 MAC Array Accelerator
//              Tests matrix multiplication with random and corner cases
//              Includes golden reference model and comprehensive verification
// =============================================================================

module tb_mac_array_4x4;

    // =========================================================================
    // Parameters
    // =========================================================================
    parameter int N      = 4;
    parameter int DATA_W = 8;
    parameter int ACC_W  = 32;
    parameter int CLK_PERIOD = 10;  // 10ns clock period (100 MHz)

    // =========================================================================
    // DUT Signals
    // =========================================================================
    logic                    clock;
    logic                    reset_n;
    logic                    load_A;
    logic [3:0]              a_addr;
    logic signed [DATA_W-1:0] a_wdata;
    logic                    load_B;
    logic [3:0]              b_addr;
    logic signed [DATA_W-1:0] b_wdata;
    logic                    start;
    logic                    done;
    logic                    out_valid;
    logic [3:0]              out_addr;
    logic signed [ACC_W-1:0] out_rdata;

    // =========================================================================
    // Testbench Variables
    // =========================================================================
    logic signed [DATA_W-1:0] A_matrix [0:N-1][0:N-1];
    logic signed [DATA_W-1:0] B_matrix [0:N-1][0:N-1];
    logic signed [ACC_W-1:0]  C_expected [0:N-1][0:N-1];
    logic signed [ACC_W-1:0]  C_actual [0:N-1][0:N-1];
    
    int test_count;
    int pass_count;
    int fail_count;
    int error_count;

    // =========================================================================
    // DUT Instance
    // =========================================================================
    mac_array_4x4 #(
        .N      (N),
        .DATA_W (DATA_W),
        .MUL_W  (16),
        .ACC_W  (ACC_W)
    ) dut (
        .clock      (clock),
        .reset_n    (reset_n),
        .load_A     (load_A),
        .a_addr     (a_addr),
        .a_wdata    (a_wdata),
        .load_B     (load_B),
        .b_addr     (b_addr),
        .b_wdata    (b_wdata),
        .start      (start),
        .done       (done),
        .out_valid  (out_valid),
        .out_addr   (out_addr),
        .out_rdata  (out_rdata)
    );

    // =========================================================================
    // Clock Generation
    // =========================================================================
    initial begin
        clock = 0;
        forever #(CLK_PERIOD/2) clock = ~clock;
    end

    // =========================================================================
    // Golden Reference Model - Matrix Multiplication
    // =========================================================================
    function void compute_golden_model();
        logic signed [ACC_W-1:0] sum;
        for (int i = 0; i < N; i++) begin
            for (int j = 0; j < N; j++) begin
                sum = 0;
                for (int k = 0; k < N; k++) begin
                    sum = sum + (A_matrix[i][k] * B_matrix[k][j]);
                end
                C_expected[i][j] = sum;
            end
        end
    endfunction

    // =========================================================================
    // Task: Reset DUT
    // =========================================================================
    task reset_dut();
        reset_n = 0;
        load_A  = 0;
        load_B  = 0;
        start   = 0;
        a_addr  = 0;
        b_addr  = 0;
        a_wdata = 0;
        b_wdata = 0;
        out_addr = 0;
        repeat(5) @(posedge clock);
        reset_n = 1;
        repeat(2) @(posedge clock);
    endtask

    // =========================================================================
    // Task: Load A Matrix into DUT
    // =========================================================================
    task load_matrix_A();
        for (int i = 0; i < N; i++) begin
            for (int j = 0; j < N; j++) begin
                @(posedge clock);
                load_A  = 1;
                a_addr  = (i << 2) | j;  // Linear address: i*4 + j
                a_wdata = A_matrix[i][j];
            end
        end
        @(posedge clock);
        load_A = 0;
        @(posedge clock);
    endtask

    // =========================================================================
    // Task: Load B Matrix into DUT
    // =========================================================================
    task load_matrix_B();
        for (int i = 0; i < N; i++) begin
            for (int j = 0; j < N; j++) begin
                @(posedge clock);
                load_B  = 1;
                b_addr  = (i << 2) | j;  // Linear address: i*4 + j
                b_wdata = B_matrix[i][j];
            end
        end
        @(posedge clock);
        load_B = 0;
        @(posedge clock);
    endtask

    // =========================================================================
    // Task: Start Computation and Wait for Done
    // =========================================================================
    task start_and_wait();
        int timeout_cycles;
        timeout_cycles = 0;
        
        @(posedge clock);
        start = 1;
        @(posedge clock);
        start = 0;
        
        // Wait for done signal with timeout
        while (!done && timeout_cycles < 100) begin
            @(posedge clock);
            timeout_cycles++;
        end
        
        if (timeout_cycles >= 100) begin
            $display("LOG: %0t : ERROR : tb_mac_array_4x4 : dut.done : expected_value: 1'b1 actual_value: 1'b0", $time);
            $display("ERROR: Computation timeout!");
            error_count++;
        end
    endtask

    // =========================================================================
    // Task: Read Results from DUT
    // =========================================================================
    task read_results();
        for (int i = 0; i < N; i++) begin
            for (int j = 0; j < N; j++) begin
                @(posedge clock);
                out_addr = (i << 2) | j;  // Linear address: i*4 + j
                @(posedge clock);  // Wait one cycle for output
                C_actual[i][j] = out_rdata;
            end
        end
    endtask

    // =========================================================================
    // Task: Verify Results
    // =========================================================================
    task verify_results(string test_name);
        automatic int mismatch_count = 0;
        
        for (int i = 0; i < N; i++) begin
            for (int j = 0; j < N; j++) begin
                if (C_actual[i][j] !== C_expected[i][j]) begin
                    $display("LOG: %0t : ERROR : tb_mac_array_4x4 : dut.C_acc[%0d][%0d] : expected_value: %0d actual_value: %0d", 
                             $time, i, j, C_expected[i][j], C_actual[i][j]);
                    mismatch_count++;
                    error_count++;
                end else begin
                    $display("LOG: %0t : INFO : tb_mac_array_4x4 : dut.C_acc[%0d][%0d] : expected_value: %0d actual_value: %0d", 
                             $time, i, j, C_expected[i][j], C_actual[i][j]);
                end
            end
        end
        
        if (mismatch_count == 0) begin
            $display("[PASS] %s", test_name);
            pass_count++;
        end else begin
            $display("[FAIL] %s - %0d mismatches found", test_name, mismatch_count);
            fail_count++;
        end
        
        test_count++;
    endtask

    // =========================================================================
    // Task: Generate Random Matrix
    // =========================================================================
    task generate_random_matrices();
        for (int i = 0; i < N; i++) begin
            for (int j = 0; j < N; j++) begin
                A_matrix[i][j] = $random;
                B_matrix[i][j] = $random;
            end
        end
    endtask

    // =========================================================================
    // Task: Print Matrix
    // =========================================================================
    task print_matrix(string name, logic signed [ACC_W-1:0] matrix [0:N-1][0:N-1]);
        $display("%s:", name);
        for (int i = 0; i < N; i++) begin
            $write("  [");
            for (int j = 0; j < N; j++) begin
                $write("%8d", matrix[i][j]);
                if (j < N-1) $write(", ");
            end
            $display("]");
        end
    endtask

    // =========================================================================
    // Task: Run Single Test
    // =========================================================================
    task run_test(string test_name);
        $display("\n========================================");
        $display("Running: %s", test_name);
        $display("========================================");
        
        // Compute golden reference
        compute_golden_model();
        
        // Load matrices into DUT
        load_matrix_A();
        load_matrix_B();
        
        // Start computation
        start_and_wait();
        
        // Read and verify results
        read_results();
        verify_results(test_name);
    endtask

    // =========================================================================
    // Main Test Sequence
    // =========================================================================
    initial begin
        $display("TEST START");
        $display("========================================");
        $display("TinyMAC 4x4 Accelerator Testbench");
        $display("========================================");
        
        // Initialize counters
        test_count  = 0;
        pass_count  = 0;
        fail_count  = 0;
        error_count = 0;
        
        // Reset DUT
        reset_dut();
        
        // =====================================================================
        // Test 1: All Zeros
        // =====================================================================
        for (int i = 0; i < N; i++) begin
            for (int j = 0; j < N; j++) begin
                A_matrix[i][j] = 0;
                B_matrix[i][j] = 0;
            end
        end
        run_test("Test 1: All Zeros");
        
        // =====================================================================
        // Test 2: Identity Matrix (A) × Random (B)
        // =====================================================================
        for (int i = 0; i < N; i++) begin
            for (int j = 0; j < N; j++) begin
                A_matrix[i][j] = (i == j) ? 8'sd1 : 8'sd0;
                B_matrix[i][j] = $random;
            end
        end
        run_test("Test 2: Identity × Random");
        
        // =====================================================================
        // Test 3: Max Positive Values
        // =====================================================================
        for (int i = 0; i < N; i++) begin
            for (int j = 0; j < N; j++) begin
                A_matrix[i][j] = 8'sd127;  // Max positive int8
                B_matrix[i][j] = 8'sd1;
            end
        end
        run_test("Test 3: Max Positive Values");
        
        // =====================================================================
        // Test 4: Max Negative Values
        // =====================================================================
        for (int i = 0; i < N; i++) begin
            for (int j = 0; j < N; j++) begin
                A_matrix[i][j] = -8'sd128;  // Max negative int8
                B_matrix[i][j] = 8'sd1;
            end
        end
        run_test("Test 4: Max Negative Values");
        
        // =====================================================================
        // Test 5: Mixed Signs
        // =====================================================================
        for (int i = 0; i < N; i++) begin
            for (int j = 0; j < N; j++) begin
                A_matrix[i][j] = (i + j) % 2 ? 8'sd10 : -8'sd10;
                B_matrix[i][j] = (i * j) % 2 ? 8'sd5 : -8'sd5;
            end
        end
        run_test("Test 5: Mixed Signs");
        
        // =====================================================================
        // Test 6-10: Random Tests
        // =====================================================================
        for (int t = 6; t <= 10; t++) begin
            generate_random_matrices();
            run_test($sformatf("Test %0d: Random Matrices", t));
        end
        
        // =====================================================================
        // Test Summary
        // =====================================================================
        $display("\n========================================");
        $display("TEST SUMMARY");
        $display("========================================");
        $display("Total Tests: %0d", test_count);
        $display("Passed:      %0d", pass_count);
        $display("Failed:      %0d", fail_count);
        $display("Errors:      %0d", error_count);
        $display("========================================");
        
        if (fail_count == 0 && error_count == 0) begin
            $display("TEST PASSED");
        end else begin
            $display("TEST FAILED");
            $error("Test failed with %0d failures and %0d errors", fail_count, error_count);
        end
        
        // Finish simulation
        repeat(10) @(posedge clock);
        $finish(0);
    end

    // =========================================================================
    // Waveform Dump
    // =========================================================================
    initial begin
        $dumpfile("dump.vcd");
        $dumpvars(0, tb_mac_array_4x4);
    end

    // =========================================================================
    // Simulation Timeout Watchdog
    // =========================================================================
    initial begin
        #1000000;  // 1ms timeout
        $display("LOG: %0t : ERROR : tb_mac_array_4x4 : simulation_timeout : expected_value: completion actual_value: timeout", $time);
        $display("ERROR: Simulation timeout!");
        $display("TEST FAILED");
        $fatal(1, "Simulation exceeded maximum runtime");
    end

endmodule
