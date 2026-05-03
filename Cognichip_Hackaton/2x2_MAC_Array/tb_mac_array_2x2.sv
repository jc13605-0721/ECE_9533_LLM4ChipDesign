n// Testbench for 2x2 MAC Array
module tb_mac_array_2x2;

    // Parameters
    parameter DATA_WIDTH = 8;
    parameter ACC_WIDTH = 20;
    parameter CLK_PERIOD = 10;  // 10ns clock period

    // DUT signals
    logic                    clock;
    logic                    reset;
    logic                    enable;
    logic                    clear_all;
    logic [DATA_WIDTH-1:0]   a_00, a_01, a_10, a_11;
    logic [DATA_WIDTH-1:0]   b_00, b_01, b_10, b_11;
    logic [ACC_WIDTH-1:0]    acc_00, acc_01, acc_10, acc_11;
    
    // Test variables
    int error_count = 0;
    logic [ACC_WIDTH-1:0] expected_00, expected_01, expected_10, expected_11;

    // Instantiate DUT
    mac_array_2x2 #(
        .DATA_WIDTH(DATA_WIDTH),
        .ACC_WIDTH(ACC_WIDTH)
    ) dut (
        .clock(clock),
        .reset(reset),
        .enable(enable),
        .clear_all(clear_all),
        .a_00(a_00), .b_00(b_00), .acc_00(acc_00),
        .a_01(a_01), .b_01(b_01), .acc_01(acc_01),
        .a_10(a_10), .b_10(b_10), .acc_10(acc_10),
        .a_11(a_11), .b_11(b_11), .acc_11(acc_11)
    );

    // Clock generation
    initial begin
        clock = 0;
        forever #(CLK_PERIOD/2) clock = ~clock;
    end

    // Test stimulus
    initial begin
        $display("TEST START");
        $display("========================================");
        $display("测试开始: 2x2 MAC阵列");
        $display("========================================");
        
        // Initialize signals
        reset = 1;
        enable = 0;
        clear_all = 0;
        a_00 = 0; b_00 = 0;
        a_01 = 0; b_01 = 0;
        a_10 = 0; b_10 = 0;
        a_11 = 0; b_11 = 0;
        
        // Wait for a few clocks
        repeat(2) @(posedge clock);
        
        // Release reset
        reset = 0;
        @(posedge clock);
        
        $display("\n[测试1] 复位后检查 - 所有累加器应为0");
        @(posedge clock);
        check_outputs(0, 0, 0, 0, "复位检查");
        
        // Test 1: Single MAC operation on MAC[0][0]
        $display("\n[测试2] MAC[0][0] 单次运算: 3 * 4 = 12");
        enable = 1;
        a_00 = 3; b_00 = 4;
        @(posedge clock);
        @(posedge clock);  // Wait for result
        expected_00 = 12;
        check_outputs(expected_00, 0, 0, 0, "MAC[0][0]单次乘法");
        
        // Test 2: Accumulation on MAC[0][0]
        $display("\n[测试3] MAC[0][0] 累加: 12 + (5 * 6) = 42");
        a_00 = 5; b_00 = 6;
        @(posedge clock);
        @(posedge clock);
        expected_00 = 42;
        check_outputs(expected_00, 0, 0, 0, "MAC[0][0]累加");
        
        // Test 3: Test all MACs simultaneously
        $display("\n[测试4] 所有MAC同时工作");
        a_00 = 2; b_00 = 3;  // acc_00 = 42 + 6 = 48
        a_01 = 4; b_01 = 5;  // acc_01 = 0 + 20 = 20
        a_10 = 6; b_10 = 7;  // acc_10 = 0 + 42 = 42
        a_11 = 8; b_11 = 9;  // acc_11 = 0 + 72 = 72
        @(posedge clock);
        @(posedge clock);
        expected_00 = 48;
        expected_01 = 20;
        expected_10 = 42;
        expected_11 = 72;
        check_outputs(expected_00, expected_01, expected_10, expected_11, "所有MAC同时运算");
        
        // Test 4: Another accumulation cycle
        $display("\n[测试5] 第二轮累加");
        a_00 = 1; b_00 = 2;   // acc_00 = 48 + 2 = 50
        a_01 = 3; b_01 = 4;   // acc_01 = 20 + 12 = 32
        a_10 = 5; b_10 = 6;   // acc_10 = 42 + 30 = 72
        a_11 = 7; b_11 = 8;   // acc_11 = 72 + 56 = 128
        @(posedge clock);
        @(posedge clock);
        expected_00 = 50;
        expected_01 = 32;
        expected_10 = 72;
        expected_11 = 128;
        check_outputs(expected_00, expected_01, expected_10, expected_11, "第二轮累加");
        
        // Test 5: Clear all accumulators
        $display("\n[测试6] 清零所有累加器");
        clear_all = 1;
        @(posedge clock);
        clear_all = 0;
        @(posedge clock);
        check_outputs(0, 0, 0, 0, "清零功能");
        
        // Test 6: Verify accumulation after clear
        $display("\n[测试7] 清零后重新累加");
        a_00 = 10; b_00 = 10;  // acc_00 = 0 + 100 = 100
        a_01 = 11; b_01 = 11;  // acc_01 = 0 + 121 = 121
        a_10 = 12; b_10 = 12;  // acc_10 = 0 + 144 = 144
        a_11 = 13; b_11 = 13;  // acc_11 = 0 + 169 = 169
        @(posedge clock);
        @(posedge clock);
        expected_00 = 100;
        expected_01 = 121;
        expected_10 = 144;
        expected_11 = 169;
        check_outputs(expected_00, expected_01, expected_10, expected_11, "清零后累加");
        
        // Test 7: Disable test
        $display("\n[测试8] Enable=0时不应累加");
        enable = 0;
        a_00 = 50; b_00 = 50;  // Should not accumulate
        @(posedge clock);
        @(posedge clock);
        check_outputs(expected_00, expected_01, expected_10, expected_11, "使能关闭");
        
        // Test 8: Large value test
        $display("\n[测试9] 大数值测试 (最大8位值)");
        enable = 1;
        clear_all = 1;
        @(posedge clock);
        clear_all = 0;
        a_00 = 255; b_00 = 255;  // Max 8-bit value: 255*255 = 65025
        a_01 = 200; b_01 = 200;  // 200*200 = 40000
        a_10 = 150; b_10 = 150;  // 150*150 = 22500
        a_11 = 128; b_11 = 128;  // 128*128 = 16384
        @(posedge clock);
        @(posedge clock);
        expected_00 = 65025;
        expected_01 = 40000;
        expected_10 = 22500;
        expected_11 = 16384;
        check_outputs(expected_00, expected_01, expected_10, expected_11, "大数值");
        
        // Final summary
        $display("\n========================================");
        if (error_count == 0) begin
            $display("测试完成: 所有测试通过! ✓");
            $display("TEST PASSED");
        end else begin
            $display("测试完成: 发现 %0d 个错误", error_count);
            $display("ERROR");
            $fatal(1, "测试失败");
        end
        $display("========================================");
        
        $finish;
    end

    // Check outputs task
    task check_outputs(
        input logic [ACC_WIDTH-1:0] exp_00,
        input logic [ACC_WIDTH-1:0] exp_01,
        input logic [ACC_WIDTH-1:0] exp_10,
        input logic [ACC_WIDTH-1:0] exp_11,
        input string test_name
    );
        logic pass = 1;
        
        if (acc_00 !== exp_00) begin
            $display("LOG: %0t : ERROR : tb_mac_array_2x2 : dut.acc_00 : expected_value: %0d actual_value: %0d", 
                     $time, exp_00, acc_00);
            error_count++;
            pass = 0;
        end
        
        if (acc_01 !== exp_01) begin
            $display("LOG: %0t : ERROR : tb_mac_array_2x2 : dut.acc_01 : expected_value: %0d actual_value: %0d", 
                     $time, exp_01, acc_01);
            error_count++;
            pass = 0;
        end
        
        if (acc_10 !== exp_10) begin
            $display("LOG: %0t : ERROR : tb_mac_array_2x2 : dut.acc_10 : expected_value: %0d actual_value: %0d", 
                     $time, exp_10, acc_10);
            error_count++;
            pass = 0;
        end
        
        if (acc_11 !== exp_11) begin
            $display("LOG: %0t : ERROR : tb_mac_array_2x2 : dut.acc_11 : expected_value: %0d actual_value: %0d", 
                     $time, exp_11, acc_11);
            error_count++;
            pass = 0;
        end
        
        if (pass) begin
            $display("  ✓ %s 通过 [acc_00=%0d, acc_01=%0d, acc_10=%0d, acc_11=%0d]", 
                     test_name, acc_00, acc_01, acc_10, acc_11);
        end else begin
            $display("  ✗ %s 失败", test_name);
        end
    endtask

    // Waveform dump
    initial begin
        $dumpfile("dumpfile.fst");
        $dumpvars(0);
    end

    // Timeout watchdog
    initial begin
        #100000;  // 100us timeout
        $display("ERROR: 仿真超时!");
        $fatal(1, "测试超时");
    end

endmodule
