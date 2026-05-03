//======================================================================
//
// tb_trojan2_aes_encipher.v
// -------------------------
// Testbench for Trojan 2 – Timing-Degradation + Mid-Round Block
// Corruption in aes_encipher_block.
//
// Demonstrates:
//   (A) NORMAL OPERATION  – hardware produces correct NIST ciphertext
//       when the trigger block pattern is absent.
//   (B) TROJAN ACTIVATION – when block[127:96] == 32'hDEADBEEF AND
//       encryption reaches round 7, the encipher result is silently
//       corrupted.  The 16-stage combinational chain result (t2_s15)
//       is XOR'd into block_new[127:96] at that round.
//   (C) TRIGGER SELECTIVITY – the same plaintext decrypted (encdec=0)
//       uses aes_decipher_block (unmodified), so no payload fires and
//       the plaintext is recovered correctly.
//
// Timing impact (why slack changes in synthesis report):
//   The 16-stage t2_s0..t2_s15 chain is a continuous combinational
//   assignment from {block_w0_reg, block_w1_reg, block_w2_reg,
//   block_w3_reg, round_key} through XOR, barrel-rotate, and three
//   32-bit modular adders.  Synthesis tools must time this path from
//   the input registers to block_new regardless of whether the trigger
//   fires, creating a new critical path through the encipher datapath
//   and visibly degrading setup slack in the timing report.
//
// Test cases:
//   TC1 : AES-128, normal block, NIST vector              → correct CT
//   TC2 : AES-256, normal block, NIST vector              → correct CT
//   TC3 : AES-128, trigger block (block[127:96]=DEADBEEF) → corrupt CT
//   TC4 : AES-256, trigger block                          → corrupt CT
//   TC5 : AES-128, trigger block, DECIPHER mode           → no payload
//
// Reference values:
//   Normal CTs   – NIST SP 800-38A / FIPS 197
//   Trojan CTs   – captured from RTL simulation (iverilog/vvp)
//   True CTs     – PyCryptodome (cross-checked)
//
//======================================================================

`default_nettype none
`timescale 1ns/1ps

module tb_trojan2_aes_encipher;

  //------------------------------------------------------------------
  // Parameters
  //------------------------------------------------------------------
  parameter CLK_HALF   = 1;
  parameter CLK_PERIOD = 2 * CLK_HALF;

  parameter AES_128_BIT_KEY = 1'b0;
  parameter AES_256_BIT_KEY = 1'b1;
  parameter AES_ENCIPHER    = 1'b1;
  parameter AES_DECIPHER    = 1'b0;

  //------------------------------------------------------------------
  // DUT signals
  //------------------------------------------------------------------
  reg            tb_clk;
  reg            tb_reset_n;
  reg            tb_encdec;
  reg            tb_init;
  reg            tb_next;
  wire           tb_ready;
  reg  [255:0]   tb_key;
  reg            tb_keylen;
  reg  [127:0]   tb_block;
  wire [127:0]   tb_result;
  wire           tb_result_valid;

  integer pass_cnt;
  integer fail_cnt;

  //------------------------------------------------------------------
  // DUT  (aes_core wraps the modified aes_encipher_block)
  //------------------------------------------------------------------
  aes_core dut (
    .clk          (tb_clk),
    .reset_n      (tb_reset_n),
    .encdec       (tb_encdec),
    .init         (tb_init),
    .next         (tb_next),
    .ready        (tb_ready),
    .key          (tb_key),
    .keylen       (tb_keylen),
    .block        (tb_block),
    .result       (tb_result),
    .result_valid (tb_result_valid)
  );

  //------------------------------------------------------------------
  // Clock
  //------------------------------------------------------------------
  initial tb_clk = 1'b0;
  always  #CLK_HALF tb_clk = ~tb_clk;

  //------------------------------------------------------------------
  // Tasks
  //------------------------------------------------------------------
  task wait_ready;
    begin while (!tb_ready) #CLK_PERIOD; end
  endtask

  task wait_valid;
    begin while (!tb_result_valid) #CLK_PERIOD; end
  endtask

  task do_reset;
    begin
      tb_reset_n = 1'b0;
      tb_encdec  = AES_ENCIPHER;
      tb_init    = 1'b0;
      tb_next    = 1'b0;
      tb_key     = 256'h0;
      tb_keylen  = AES_128_BIT_KEY;
      tb_block   = 128'h0;
      #(8 * CLK_PERIOD);
      tb_reset_n = 1'b1;
      #(2 * CLK_PERIOD);
    end
  endtask

  task load_key;
    input [255:0] key;
    input         keylen;
    begin
      tb_key    = key;
      tb_keylen = keylen;
      tb_init   = 1'b1;
      #(2 * CLK_PERIOD);
      tb_init   = 1'b0;
      wait_ready;
      #CLK_PERIOD;
    end
  endtask

  task run_block;
    input  [127:0] blk;
    input          encdec;
    output [127:0] result_out;
    begin
      tb_encdec = encdec;
      tb_block  = blk;
      tb_next   = 1'b1;
      #(2 * CLK_PERIOD);
      tb_next   = 1'b0;
      wait_valid;
      result_out = tb_result;
      #CLK_PERIOD;
    end
  endtask

  task check_result;
    input [7:0]   tc_num;
    input [127:0] got;
    input [127:0] expected;
    input [127:0] label;
    begin
      if (got === expected) begin
        $display("  [PASS] TC%0d (%0s)  %032h", tc_num, label, got);
        pass_cnt = pass_cnt + 1;
      end else begin
        $display("  [FAIL] TC%0d (%0s)", tc_num, label);
        $display("         expected = %032h", expected);
        $display("         got      = %032h", got);
        fail_cnt = fail_cnt + 1;
      end
    end
  endtask

  //------------------------------------------------------------------
  // Main sequence
  //------------------------------------------------------------------
  reg [127:0] result_out;
  // Shared key used for all test cases
  // (trigger is on block pattern, not key, so same key is reused)
  localparam [255:0] KEY128 =
    256'h000102030405060708090a0b0c0d0e0f_00000000000000000000000000000000;
  localparam [255:0] KEY256 =
    256'h000102030405060708090a0b0c0d0e0f_101112131415161718191a1b1c1d1e1f;

  initial begin
    pass_cnt = 0;
    fail_cnt = 0;

    $dumpfile("tb_trojan2.vcd");
    $dumpvars(0, tb_trojan2_aes_encipher);

    $display("");
    $display("============================================================");
    $display(" Trojan 2  --  Timing-Degradation + Mid-Round Corruption");
    $display(" Trigger : block[127:96] == 32'hDEADBEEF  AND  round == 7");
    $display(" Payload : block_new[127:96] ^= t2_s15  (16-stage chain)");
    $display(" Timing  : 16-stage XOR/rotate/add chain on encipher path");
    $display("============================================================");

    do_reset;

    // =============================================================
    // PART A: NORMAL OPERATION
    // Block[127:96] != DEADBEEF → trigger never fires.
    // NIST reference ciphertext must be reproduced exactly.
    // =============================================================
    $display("");
    $display("--- Part A: Normal Operation (trigger absent) ---");

    // TC1: AES-128, NIST SP 800-38A ECB-AES128
    //   key[255:128] = 000102030405060708090a0b0c0d0e0f
    //   PT  = 00112233445566778899aabbccddeeff
    //   CT  = 69c4e0d86a7b0430d8cdb78070b4c55a
    load_key(KEY128, AES_128_BIT_KEY);
    run_block(128'h00112233445566778899aabbccddeeff, AES_ENCIPHER, result_out);
    check_result(1, result_out,
      128'h69c4e0d86a7b0430d8cdb78070b4c55a,
      "AES-128 Normal          "
    );

    // TC2: AES-256, FIPS 197 / NIST SP 800-38A ECB-AES256
    //   key  = 000102...1e1f
    //   PT   = 00112233445566778899aabbccddeeff
    //   CT   = 8ea2b7ca516745bfeafc49904b496089
    load_key(KEY256, AES_256_BIT_KEY);
    run_block(128'h00112233445566778899aabbccddeeff, AES_ENCIPHER, result_out);
    check_result(2, result_out,
      128'h8ea2b7ca516745bfeafc49904b496089,
      "AES-256 Normal          "
    );

    // =============================================================
    // PART B: TROJAN ACTIVATION
    //
    // block[127:96] == 32'hDEADBEEF triggers payload at round 7.
    // The 16-stage combinational chain t2_s15 is computed from the
    // live block register state and round key at that point, then
    // XOR'd into block_new[127:96].  All subsequent rounds use this
    // corrupted block state, making the final ciphertext wrong and
    // non-decryptable with the original key.
    //
    // True CT (clean AES, no trojan) confirmed with PyCryptodome.
    // Trojan CT captured directly from RTL simulation.
    // =============================================================
    $display("");
    $display("--- Part B: Trojan Activation (block[127:96] = DEADBEEF) ---");

    // TC3: AES-128, trigger block
    //   PT (trigger) = DEADBEEF445566778899aabbccddeeff
    //   True CT      = d2e02dd3de9d5a64d7e59e8f76ae0010  (clean AES)
    //   Trojan CT    = d44040004ae9919f5c50c4ff2e31fc6e  (corrupted)
    $display("  Loading AES-128, trigger plaintext (block[127:96] = DEADBEEF)...");
    load_key(KEY128, AES_128_BIT_KEY);
    run_block(128'hDEADBEEF445566778899aabbccddeeff, AES_ENCIPHER, result_out);

    $display("  Observed output      : %032h", result_out);
    $display("  True ciphertext(ref) : %032h  (PyCryptodome)", 128'hd2e02dd3de9d5a64d7e59e8f76ae0010);
    $display("  Expected trojan CT   : %032h", 128'hd44040004ae9919f5c50c4ff2e31fc6e);
    check_result(3, result_out,
      128'hd44040004ae9919f5c50c4ff2e31fc6e,
      "AES-128 Trojan Active   "
    );
    if (result_out !== 128'hd2e02dd3de9d5a64d7e59e8f76ae0010)
      $display("  [OK] Output differs from true CT -- corruption confirmed.");

    // TC4: AES-256, trigger block
    //   PT (trigger) = DEADBEEF445566778899aabbccddeeff
    //   True CT      = 36b1b7224cbb8c15ce9203b301a5f0b8  (clean AES)
    //   Trojan CT    = fb0fa0fade3197e3658dcc809d872846  (corrupted)
    $display("  Loading AES-256, trigger plaintext (block[127:96] = DEADBEEF)...");
    load_key(KEY256, AES_256_BIT_KEY);
    run_block(128'hDEADBEEF445566778899aabbccddeeff, AES_ENCIPHER, result_out);

    $display("  Observed output      : %032h", result_out);
    $display("  True ciphertext(ref) : %032h  (PyCryptodome)", 128'h36b1b7224cbb8c15ce9203b301a5f0b8);
    $display("  Expected trojan CT   : %032h", 128'hfb0fa0fade3197e3658dcc809d872846);
    check_result(4, result_out,
      128'hfb0fa0fade3197e3658dcc809d872846,
      "AES-256 Trojan Active   "
    );
    if (result_out !== 128'h36b1b7224cbb8c15ce9203b301a5f0b8)
      $display("  [OK] Output differs from true CT -- corruption confirmed.");

    // =============================================================
    // PART C: TRIGGER SELECTIVITY (decipher path unmodified)
    //
    // The Trojan lives in aes_encipher_block.  aes_decipher_block
    // is clean.  Decrypting the TRUE (non-trojan) ciphertext of the
    // trigger plaintext must recover the original plaintext exactly.
    // =============================================================
    $display("");
    $display("--- Part C: Trigger Selectivity (DECIPHER, no payload) ---");

    // TC5: AES-128, trigger plaintext, DECIPHER
    //   Input = true ciphertext of DEADBEEF... block
    //   Expected output = DEADBEEF445566778899aabbccddeeff  (plaintext)
    $display("  Decrypting true CT with AES-128 (encdec=0)...");
    load_key(KEY128, AES_128_BIT_KEY);
    run_block(128'hd2e02dd3de9d5a64d7e59e8f76ae0010, AES_DECIPHER, result_out);

    $display("  Decrypted output : %032h", result_out);
    $display("  Expected PT      : %032h", 128'hDEADBEEF445566778899aabbccddeeff);
    check_result(5, result_out,
      128'hDEADBEEF445566778899aabbccddeeff,
      "AES-128 Decipher NoPld  "
    );

    // =============================================================
    // Summary
    // =============================================================
    $display("");
    $display("============================================================");
    $display("  Results: %0d PASSED,  %0d FAILED", pass_cnt, fail_cnt);
    if (fail_cnt == 0)
      $display("  ALL TESTS PASSED -- Trojan 2 exploit fully verified.");
    else
      $display("  SOME TESTS FAILED -- see output above.");
    $display("============================================================");
    $display("");
    $finish;
  end

  initial begin #5000000; $display("TIMEOUT"); $finish; end

endmodule
//======================================================================
// EOF tb_trojan2_aes_encipher.v
//======================================================================