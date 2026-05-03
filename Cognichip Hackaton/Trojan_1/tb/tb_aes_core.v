//======================================================================
//
// tb_trojan1_aes_core.v
// ---------------------
// Testbench for Trojan 1 – Key-Exfiltration Backdoor in aes_core.
//
// Demonstrates:
//   (A) NORMAL OPERATION  – hardware produces correct NIST ciphertext
//       when the trigger condition is absent.
//   (B) TROJAN ACTIVATION – when key[255:224] == 32'hDEADC0DE AND
//       encdec==1, the output is silently XOR-masked with
//       key[255:128], leaking the AES key to a passive observer.
//   (C) KEY RECOVERY PROOF – attacker derives
//       key[255:128] = trojan_result XOR true_ciphertext.
//   (D) TRIGGER SELECTIVITY – same trigger key in DECIPHER mode
//       produces no payload (Trojan is silent, stealth preserved).
//
// Test cases:
//   TC1 : AES-128, normal key, NIST vector        → correct CT
//   TC2 : AES-256, normal key, NIST vector        → correct CT
//   TC3 : AES-128, trigger key, ENCIPHER          → trojan CT
//   TC4 : AES-256, trigger key, ENCIPHER          → trojan CT
//   TC5 : AES-128, trigger key, DECIPHER          → no payload
//
// Reference values computed with PyCryptodome (verified against
// NIST SP 800-38A / FIPS 197).
//
//======================================================================

`default_nettype none
`timescale 1ns/1ps

module tb_trojan1_aes_core;

  // ------------------------------------------------------------------
  // Parameters
  // ------------------------------------------------------------------
  parameter CLK_HALF   = 1;
  parameter CLK_PERIOD = 2 * CLK_HALF;

  parameter AES_128_BIT_KEY = 1'b0;
  parameter AES_256_BIT_KEY = 1'b1;
  parameter AES_ENCIPHER    = 1'b1;
  parameter AES_DECIPHER    = 1'b0;

  // ------------------------------------------------------------------
  // DUT signals
  // ------------------------------------------------------------------
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

  // ------------------------------------------------------------------
  // DUT
  // ------------------------------------------------------------------
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

  // ------------------------------------------------------------------
  // Clock
  // ------------------------------------------------------------------
  initial tb_clk = 1'b0;
  always  #CLK_HALF tb_clk = ~tb_clk;

  // ------------------------------------------------------------------
  // Tasks (timing matches original secworks tb_aes_core style)
  // ------------------------------------------------------------------
  task wait_ready;
    begin
      while (!tb_ready)
        #(CLK_PERIOD);
    end
  endtask

  task wait_valid;
    begin
      while (!tb_result_valid)
        #(CLK_PERIOD);
    end
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

  // Load key and wait for key expansion (mirrors secworks testbench)
  task load_key;
    input [255:0] key;
    input         keylen;
    begin
      tb_key    = key;
      tb_keylen = keylen;
      tb_init   = 1'b1;
      #(2 * CLK_PERIOD);   // allow core to register init and drop ready
      tb_init   = 1'b0;
      wait_ready;           // poll until key expansion complete
      #(CLK_PERIOD);
    end
  endtask

  // Run one block (encipher or decipher)
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
      #(CLK_PERIOD);
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

  // ------------------------------------------------------------------
  // Main sequence
  // ------------------------------------------------------------------
  reg [127:0] result_out;
  reg [127:0] recovered_key;

  initial begin
    pass_cnt = 0;
    fail_cnt = 0;

    $dumpfile("tb_trojan1.vcd");
    $dumpvars(0, tb_trojan1_aes_core);

    $display("");
    $display("============================================================");
    $display(" Trojan 1  --  Key-Exfiltration Backdoor");
    $display(" Trigger : key[255:224] == 32'hDEADC0DE  AND  encdec == 1");
    $display(" Payload : result ^= key[255:128]  (leaks AES key in CT)");
    $display("============================================================");

    do_reset;

    // ================================================================
    // PART A: NORMAL OPERATION
    // Verify hardware produces correct NIST ciphertext when the
    // trigger condition is absent.
    // ================================================================
    $display("");
    $display("--- Part A: Normal Operation (trigger absent) ---");

    // TC1: AES-128  NIST SP 800-38A ECB-AES128
    //   key[255:128] = 000102030405060708090a0b0c0d0e0f
    //   PT           = 00112233445566778899aabbccddeeff
    //   Expected CT  = 69c4e0d86a7b0430d8cdb78070b4c55a
    load_key(
      256'h000102030405060708090a0b0c0d0e0f_00000000000000000000000000000000,
      AES_128_BIT_KEY
    );
    run_block(128'h00112233445566778899aabbccddeeff, AES_ENCIPHER, result_out);
    check_result(1, result_out,
      128'h69c4e0d86a7b0430d8cdb78070b4c55a,
      "AES-128 Normal          "
    );

    // TC2: AES-256  FIPS 197 / NIST SP 800-38A ECB-AES256
    //   key  = 000102...1e1f
    //   PT   = 00112233445566778899aabbccddeeff
    //   CT   = 8ea2b7ca516745bfeafc49904b496089
    load_key(
      256'h000102030405060708090a0b0c0d0e0f_101112131415161718191a1b1c1d1e1f,
      AES_256_BIT_KEY
    );
    run_block(128'h00112233445566778899aabbccddeeff, AES_ENCIPHER, result_out);
    check_result(2, result_out,
      128'h8ea2b7ca516745bfeafc49904b496089,
      "AES-256 Normal          "
    );

    // ================================================================
    // PART B: TROJAN ACTIVATION
    //
    // key[255:224] == 32'hDEADC0DE  AND  encdec == 1
    //   → result = true_CT  XOR  key[255:128]
    //
    // A passive observer who knows the trigger can recover key[255:128]:
    //   key[255:128] = trojan_output XOR true_ciphertext
    // ================================================================
    $display("");
    $display("--- Part B: Trojan Activation ---");

    // TC3: AES-128, trigger active
    //   key[255:128] = DEADC0DE0405060708090a0b0c0d0e0f  <-- trigger!
    //   key[127:  0] = 0000...0 (unused in 128-bit mode)
    //   PT           = 00112233445566778899aabbccddeeff
    //   True CT      = 479a83653d0cb4289d759dce2c2568ef  (correct AES-128)
    //   Trojan CT    = 993743bb3909b22f957c97c5202866e0  (XOR'd with key)
    $display("  Loading AES-128 TRIGGER key (key[255:224] = DEADC0DE)...");
    load_key(
      256'hDEADC0DE0405060708090a0b0c0d0e0f_00000000000000000000000000000000,
      AES_128_BIT_KEY
    );
    run_block(128'h00112233445566778899aabbccddeeff, AES_ENCIPHER, result_out);
    $display("  Observed output      : %032h", result_out);
    $display("  Expected (trojan)    : %032h", 128'h993743bb3909b22f957c97c5202866e0);
    $display("  True ciphertext(ref) : %032h", 128'h479a83653d0cb4289d759dce2c2568ef);
    check_result(3, result_out,
      128'h993743bb3909b22f957c97c5202866e0,
      "AES-128 Trojan Active   "
    );
    recovered_key = result_out ^ 128'h479a83653d0cb4289d759dce2c2568ef;
    $display("  KEY RECOVERY: out XOR ref_ct = %032h", recovered_key);
    if (recovered_key === 128'hDEADC0DE0405060708090a0b0c0d0e0f) begin
      $display("  [OK] key[255:128] exfiltrated correctly!");
      pass_cnt = pass_cnt + 1;
    end else begin
      $display("  [ERR] key recovery mismatch");
      fail_cnt = fail_cnt + 1;
    end

    // TC4: AES-256, trigger active
    //   key[255:128] = DEADC0DE0405060708090a0b0c0d0e0f  <-- trigger!
    //   key[127:  0] = 101112131415161718191a1b1c1d1e1f
    //   PT           = 00112233445566778899aabbccddeeff
    //   True CT      = 1ad8e424679eeab4b8758c9ccb388952
    //   Trojan CT    = c47524fa639becb3b07c8697c735875d
    $display("  Loading AES-256 TRIGGER key (key[255:224] = DEADC0DE)...");
    load_key(
      256'hDEADC0DE0405060708090a0b0c0d0e0f_101112131415161718191a1b1c1d1e1f,
      AES_256_BIT_KEY
    );
    run_block(128'h00112233445566778899aabbccddeeff, AES_ENCIPHER, result_out);
    $display("  Observed output      : %032h", result_out);
    $display("  Expected (trojan)    : %032h", 128'hc47524fa639becb3b07c8697c735875d);
    $display("  True ciphertext(ref) : %032h", 128'h1ad8e424679eeab4b8758c9ccb388952);
    check_result(4, result_out,
      128'hc47524fa639becb3b07c8697c735875d,
      "AES-256 Trojan Active   "
    );
    recovered_key = result_out ^ 128'h1ad8e424679eeab4b8758c9ccb388952;
    $display("  KEY RECOVERY: out XOR ref_ct = %032h", recovered_key);
    if (recovered_key === 128'hDEADC0DE0405060708090a0b0c0d0e0f) begin
      $display("  [OK] key[255:128] exfiltrated correctly!");
      pass_cnt = pass_cnt + 1;
    end else begin
      $display("  [ERR] key recovery mismatch");
      fail_cnt = fail_cnt + 1;
    end

    // ================================================================
    // PART C: TRIGGER SELECTIVITY (stealth)
    // Same trigger key in DECIPHER mode → trojan_trigger = 0 → no payload
    // ================================================================
    $display("");
    $display("--- Part C: Trigger Selectivity (encdec=0, no payload) ---");

    // TC5: AES-128, trigger key, DECIPHER
    //   Decrypt the TRUE ciphertext → should recover original plaintext
    //   trojan1_trigger = (key[255:224]==DEADC0DE) && encdec = 1 && 0 = 0
    $display("  Decrypting with TRIGGER key in AES-128 DECIPHER mode...");
    load_key(
      256'hDEADC0DE0405060708090a0b0c0d0e0f_00000000000000000000000000000000,
      AES_128_BIT_KEY
    );
    // Decrypt the true (unmodified) ciphertext
    run_block(128'h479a83653d0cb4289d759dce2c2568ef, AES_DECIPHER, result_out);
    $display("  Decrypted output : %032h", result_out);
    $display("  Expected PT      : %032h", 128'h00112233445566778899aabbccddeeff);
    check_result(5, result_out,
      128'h00112233445566778899aabbccddeeff,
      "AES-128 Decipher NoPld  "
    );

    // ================================================================
    // Summary
    // ================================================================
    $display("");
    $display("============================================================");
    $display("  Results: %0d PASSED,  %0d FAILED", pass_cnt, fail_cnt);
    if (fail_cnt == 0)
      $display("  ALL TESTS PASSED -- Trojan 1 exploit fully verified.");
    else
      $display("  SOME TESTS FAILED -- see output above.");
    $display("============================================================");
    $display("");
    $finish;
  end

  // Watchdog (5 ms sim time)
  initial begin
    #5000000;
    $display("TIMEOUT");
    $finish;
  end

endmodule
//======================================================================
// EOF tb_trojan1_aes_core.v
//======================================================================