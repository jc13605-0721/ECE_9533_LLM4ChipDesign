`default_nettype none

module tb_trojan_exploit();

  parameter CLK_HALF_PERIOD = 1;
  parameter CLK_PERIOD      = 2 * CLK_HALF_PERIOD;

  reg            tb_clk;
  reg            tb_reset_n;
  reg            tb_next;
  reg            tb_keylen;
  wire           tb_ready;
  wire [3:0]     tb_round;
  wire [127:0]   tb_round_key;
  wire [31:0]    tb_sboxw;
  wire [31:0]    tb_new_sboxw;
  reg  [127:0]   tb_block;
  wire [127:0]   tb_new_block;
  reg  [127:0]   key_mem [0:14];

  integer cycles_case_a;
  integer cycles_case_b;
  reg [127:0] result_case_a;
  reg [127:0] result_case_b;

  assign tb_round_key = key_mem[tb_round];

  aes_sbox sbox (
    .sboxw(tb_sboxw),
    .new_sboxw(tb_new_sboxw)
  );

  aes_encipher_block dut (
    .clk(tb_clk),
    .reset_n(tb_reset_n),
    .next(tb_next),
    .keylen(tb_keylen),
    .round(tb_round),
    .round_key(tb_round_key),
    .sboxw(tb_sboxw),
    .new_sboxw(tb_new_sboxw),
    .block(tb_block),
    .new_block(tb_new_block),
    .ready(tb_ready)
  );

  always #CLK_HALF_PERIOD tb_clk = !tb_clk;

  task reset_dut;
    begin
      tb_reset_n = 0;
      #(4 * CLK_PERIOD);
      tb_reset_n = 1;
      #(2 * CLK_PERIOD);
    end
  endtask

  task wait_ready;
    begin
      while (!tb_ready)
        #(CLK_PERIOD);
    end
  endtask

  task load_nist128_key;
    begin
      key_mem[00] = 128'h2b7e151628aed2a6abf7158809cf4f3c;
      key_mem[01] = 128'ha0fafe1788542cb123a339392a6c7605;
      key_mem[02] = 128'hf2c295f27a96b9435935807a7359f67f;
      key_mem[03] = 128'h3d80477d4716fe3e1e237e446d7a883b;
      key_mem[04] = 128'hef44a541a8525b7fb671253bdb0bad00;
      key_mem[05] = 128'hd4d1c6f87c839d87caf2b8bc11f915bc;
      key_mem[06] = 128'h6d88a37a110b3efddbf98641ca0093fd;
      key_mem[07] = 128'h4e54f70e5f5fc9f384a64fb24ea6dc4f;
      key_mem[08] = 128'head27321b58dbad2312bf5607f8d292f;
      key_mem[09] = 128'hac7766f319fadc2128d12941575c006e;
      key_mem[10] = 128'hd014f9a8c9ee2589e13f0cc8b6630ca6;
      key_mem[11] = 128'h00000000000000000000000000000000;
      key_mem[12] = 128'h00000000000000000000000000000000;
      key_mem[13] = 128'h00000000000000000000000000000000;
      key_mem[14] = 128'h00000000000000000000000000000000;
    end
  endtask

  // baseline stimulus
  task load_case_a_keys;
    begin
      load_nist128_key();
    end
  endtask

  // altered stimulus
  task load_case_b_keys;
    begin
      load_nist128_key();

      // 在这里放“变体 case”的 key 修改
      // 注意：如果 DUT 在某一个时刻只观察一个输入总线，
      // 那么你希望同时成立的多个字节条件，需要出现在同一次被观察的数据上。
      // 下面只是占位示例，请按你自己的设计意图调整。
      key_mem[4][31:24] = 8'h5A;
      key_mem[4][23:16] = 8'hA5;
    end
  endtask

  task run_case;
    input [127:0] block_in;
    output [127:0] block_out;
    output integer cycles_out;
    integer start_time;
    integer end_time;
    begin
      tb_block = block_in;
      #(2 * CLK_PERIOD);

      start_time = $time;
      tb_next = 1'b1;
      #(2 * CLK_PERIOD);
      tb_next = 1'b0;

      wait_ready();
      end_time   = $time;
      block_out  = tb_new_block;
      cycles_out = (end_time - start_time) / CLK_PERIOD;
    end
  endtask

  initial begin
    tb_clk     = 0;
    tb_reset_n = 1;
    tb_next    = 0;
    tb_keylen  = 0;
    tb_block   = 128'h0;

    $display("\n==================================================");
    $display("=== AES Differential Behavior Demonstration ===");
    $display("==================================================\n");

    // CASE A
    $display("[CASE A] Baseline stimulus");
    reset_dut();
    load_case_a_keys();
    run_case(128'h6bc1bee22e409f96e93d7e117393172a, result_case_a, cycles_case_a);

    $display("  Output : 0x%032x", result_case_a);
    $display("  Cycles : %0d\n", cycles_case_a);

    // CASE B
    $display("[CASE B] Altered stimulus");
    reset_dut();
    load_case_b_keys();
    run_case(128'h6bc1bee22e409f96e93d7e117393172a, result_case_b, cycles_case_b);

    $display("  Output : 0x%032x", result_case_b);
    $display("  Cycles : %0d\n", cycles_case_b);

    // Compare outputs
    if (result_case_b !== result_case_a)
      $display("  [OBSERVED] Output mismatch detected between CASE A and CASE B");
    else
      $display("  [OBSERVED] No output mismatch detected");

    // Compare latency
    if (cycles_case_b > cycles_case_a)
      $display("  [OBSERVED] Additional latency detected: %0d cycles", cycles_case_b - cycles_case_a);
    else if (cycles_case_b < cycles_case_a)
      $display("  [OBSERVED] Reduced latency detected: %0d cycles", cycles_case_a - cycles_case_b);
    else
      $display("  [OBSERVED] No latency difference detected");

    $display("\n==================================================");
    $display("=== Demonstration Complete ===");
    $display("==================================================");

    $finish;
  end

endmodule