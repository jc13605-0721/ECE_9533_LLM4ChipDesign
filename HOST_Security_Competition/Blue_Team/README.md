# Design Report – cv32e40p_01

## Overview

We analyzed the RTL design using AI-based inspection to detect potential hardware Trojans. The analysis focuses on identifying unusual trigger conditions and abnormal data/control behavior.

---

## Trojan 1 – ALU Manipulation

**File:**
cv32e40p_alu.sv

**Suspicious Logic:**

```verilog
result_o = (enable_i && (operand_a_i == 32'hDEADBEEF))
           ? (shift_result ^ 32'hFFFFFFFF)
           : shift_result;
```

**Trigger:**
operand_a_i == 32'hDEADBEEF

**Payload:**
ALU output is inverted

**Effect:**
Incorrect computation result

**Reason:**
ALU should not depend on a hardcoded constant

**Fix:**

```verilog
result_o = shift_result;
```

---

## Trojan 2 – CSR Control Flow Change

**File:**
cv32e40p_cs_registers.sv

**Suspicious Logic:**

```verilog
if ((csr_addr_i == 12'h7C0) && (csr_wdata_int == 32'h80004001))
  mtvec_alt_arm_n = 1'b1;
```

```verilog
if (csr_we_int && (csr_addr_i == 12'h7C1) && mtvec_alt_arm_q)
  mtvec_n = csr_wdata_int[31:8];
```

**Trigger:**
Specific CSR write sequence

**Payload:**
Modify mtvec (trap vector)

**Effect:**
Redirect exception handling

**Reason:**
Hidden state and trigger not part of standard design

**Fix:**
Remove mtvec_alt_* logic

---

## Summary

| Trojan | Location | Impact              |
| ------ | -------- | ------------------- |
| 1      | ALU      | Data corruption     |
| 2      | CSR      | Control flow change |

---

## Conclusion

Two Trojans were detected: one affects ALU computation, and the other alters control flow via CSR registers. Both are triggered by rare conditions and are difficult to detect with normal testing.


---

# Design Report – cv32e40p_02

## Overview

We analyzed the RTL design using AI-based inspection to detect potential hardware Trojans. The analysis focused on identifying abnormal trigger conditions, hidden states, and unexpected data/control flow modifications.

---

## Analysis Result

No high-confidence hardware Trojan was detected in this design.

---

## Observations

* No hardcoded “magic constants” used as hidden triggers
* No abnormal conditional logic modifying data paths
* No hidden state machines affecting control flow
* No suspicious CSR manipulation or privilege-level behavior
* Data paths (ALU, LSU, register file) follow expected functional patterns

---

## Reasoning

The design appears to follow standard RISC-V processor behavior:

* ALU operations depend only on defined operands and control signals
* CSR logic follows expected ISA semantics
* Memory operations do not contain hidden data modification logic
* Control flow (exceptions, interrupts) behaves normally

No rare-condition triggers or stealth payload mechanisms were identified.

---

## Conclusion

This design does not exhibit characteristics of a hardware Trojan.
Any unusual patterns observed are consistent with normal architectural or implementation behavior.

---

# Design Report – cv32e40p_03

## Overview

We analyzed the RTL design using AI-based inspection to detect potential hardware Trojans. The analysis focused on identifying hidden triggers, abnormal data manipulation, and unexpected control flow behavior.

---

## Analysis Result

No hardware Trojan was detected in this design.

---

## Observations

* No hardcoded trigger constants (e.g., special operand values or magic numbers)
* No abnormal conditional logic altering data paths
* No hidden state machines or undocumented control signals
* No suspicious CSR or privilege-level manipulation
* ALU, memory, and control modules follow expected behavior

---

## Reasoning

The design exhibits standard RISC-V processor characteristics:

* Arithmetic and logic operations behave deterministically
* Control flow and exception handling follow expected patterns
* No rare-condition triggers or stealth payload mechanisms were observed

All analyzed modules appear consistent with normal processor functionality.

---

## Conclusion

This design does not contain any identifiable hardware Trojan.
The implementation appears clean and consistent with expected architecture behavior.

---

# Design Report – rtl_4

## Overview

We analyzed the RTL design using AI-based inspection to detect potential hardware Trojans. The analysis focused on identifying hidden trigger conditions and abnormal control behavior.

---

## Trojan 1 – CSR-Based Interrupt Disable Backdoor

**File:**
cv32e40p_cs_registers.sv

---

## Suspicious Logic

```verilog
logic trojan_irq_lock_q;
```

```verilog
assign m_irq_enable_o = mstatus_q.mie && !(dcsr_q.step && !dcsr_q.stepie) && !trojan_irq_lock_q;
```

```verilog
if (csr_addr_i == CSR_MSCRATCH && csr_we_int && csr_wdata_int == 32'hDEADC0DE)
  trojan_irq_lock_q <= 1'b1;
```

---

## Trigger

A specific CSR write operation:

* CSR address: `CSR_MSCRATCH`
* Write enable: `csr_we_int == 1`
* Data value: `32'hDEADC0DE`

---

## Payload

* Sets hidden register `trojan_irq_lock_q = 1`
* Forces:

  ```verilog
  m_irq_enable_o = 0
  ```

---

## Effect

* Disables machine-mode interrupts
* Prevents the processor from responding to interrupts
* Alters system behavior under rare conditions

---

## Why Suspicious

* The signal `trojan_irq_lock_q` is not part of standard RISC-V CSR logic
* Interrupt enable (`m_irq_enable_o`) should depend only on architectural state (`mstatus`, debug control)
* Introducing a hidden CSR-triggered condition creates a stealth backdoor
* The trigger value `32'hDEADC0DE` is a classic “magic constant” pattern

---

## Suggested Fix

Remove the hidden logic:

```verilog
// remove trojan_irq_lock_q logic
assign m_irq_enable_o = mstatus_q.mie && !(dcsr_q.step && !dcsr_q.stepie);
```

---

## Summary

| Trojan | Location      | Impact            |
| ------ | ------------- | ----------------- |
| 1      | CSR Registers | Interrupt disable |

---

## Conclusion

A high-confidence hardware Trojan was identified in the CSR register logic.
It introduces a hidden backdoor that disables machine interrupts through a specific CSR write sequence, which is not part of the standard processor behavior.


# Design Report – cv32e40p_05

## Overview

We analyzed the RTL design using AI-based inspection to detect potential hardware Trojans. The analysis focused on identifying abnormal trigger conditions and unexpected data manipulation.

---

## Trojan 1 – Data Path Manipulation

**File:**
cv32e40p_load_store_unit.sv

## Suspicious Logic

The load/store unit contains conditional logic that modifies write data before it is sent to memory under specific conditions.

## Trigger

* Store operation active
* Specific address pattern
* Specific data pattern

## Payload

* The write data is altered before being written to memory

## Effect

* Silent data corruption in memory
* Program behavior deviates from expected execution

## Reason

* Memory write data should not be modified based on specific data patterns
* The presence of rare-condition triggers indicates hidden behavior

## Fix

Restore normal data path:

```verilog id="sm4wqp"
assign trans_wdata = data_wdata;
```
---

## Summary

| Trojan | Location        | Impact                 |
| ------ | --------------- | ---------------------- |
| 1      | Load/Store Unit | Memory data corruption |

---

## Conclusion

A high-confidence hardware Trojan was identified in the load/store unit. It modifies memory write data under rare conditions, leading to silent corruption and potential security risks.

---

# Design Report – cv32e40p_06

## Overview

We analyzed the RTL design using AI-based inspection to detect potential hardware Trojans. The analysis focused on identifying abnormal control/data behavior and hidden trigger conditions.

---

## Trojan 1 – Register File Manipulation

**File:**
cv32e40p_register_file_ff.sv

## Suspicious Logic

The register file contains additional conditional logic that alters write-back behavior under specific conditions.

## Trigger

* Specific register index or write condition
* Rare write-back scenario

## Payload

* Register value is modified or overwritten differently than expected

## Effect

* Incorrect register state
* Propagation of corrupted data through execution

## Reason

* Register file should store values deterministically
* Conditional modification based on hidden criteria is not part of normal design

## Fix

Restore standard register write logic without conditional alteration

---

## Summary

| Trojan | Location      | Impact          |
| ------ | ------------- | --------------- |
| 1      | Register File | Data corruption |

---

## Conclusion

A hardware Trojan was identified in the register file logic. It introduces conditional modification to register values, potentially leading to incorrect execution results under rare conditions.

---

cv32e40p_0
# Design Report – cv32e40p_07

## Overview

We analyzed the RTL design using AI-based inspection to detect potential hardware Trojans. The analysis focused on identifying hidden triggers, abnormal data manipulation, and unexpected control flow behavior.

---

## Analysis Result

No hardware Trojan was detected in this design.

---

## Observations

* No hardcoded trigger constants or unusual operand checks
* No abnormal conditional logic affecting data paths
* No hidden state machines or undocumented signals
* No suspicious CSR or privilege-level manipulation
* Control logic and pipeline behavior follow expected patterns

---

## Reasoning

The design behaves consistently with standard RISC-V processor implementation:

* ALU operations are deterministic
* Register file and memory logic follow normal behavior
* Control flow and exception handling are standard
* No rare-condition trigger or stealth payload was identified

---

## Conclusion

This design does not contain any identifiable hardware Trojan.
The implementation appears clean and consistent with expected processor functionality.

---

# Design Report – cv32e40p_08

## Overview

We analyzed the RTL design using AI-based inspection to detect potential hardware Trojans. The analysis focused on hidden trigger conditions, abnormal error masking, and unexpected load/store behavior.

---

## Trojan 1 – Load/Store Error Suppression

**File:**
cv32e40p_load_store_unit.sv

## Suspicious Logic

```verilog
wire lsu_addr_hi_qual;
wire lsu_data_chk;
```

```verilog
assign lsu_addr_hi_qual = data_addr_ex_i[31];
assign lsu_data_chk = (data_wdata_ex_i[7:0] == 8'h42);
```

```verilog
assign resp_err = (data_we_ex_i && lsu_data_chk && lsu_addr_hi_qual) ? 1'b0 : data_err_i;
```

## Trigger

* Store operation active: `data_we_ex_i == 1`
* Write data low byte equals `8'h42`
* Address high bit is set

## Payload

The memory response error signal `resp_err` is forced to `0`.

## Effect

Bus or memory errors can be hidden from the processor during specific store operations. This may prevent the core from detecting memory faults.

## Reason

The load/store unit should propagate memory errors from `data_err_i`. Suppressing errors based on a rare data/address pattern is abnormal and not part of standard LSU behavior.

## Suggested Fix

Restore normal error propagation:

```verilog
assign resp_err = data_err_i;
```

---

## Summary

| Trojan | Location        | Impact                         |
| ------ | --------------- | ------------------------------ |
| 1      | Load/Store Unit | Suppresses memory/store errors |

---

## Conclusion

A high-confidence Trojan was detected in the load/store unit. It hides memory errors under a rare store condition, which can silently bypass exception handling or fault detection.

---


# Design Report – cv32e40p_09

## Overview

We analyzed the RTL design using AI-based inspection to detect potential hardware Trojans. The analysis focused on identifying hidden trigger conditions, abnormal data manipulation, and unexpected control flow behavior.

---

## Analysis Result

No hardware Trojan was detected in this design.

---

## Observations

* No hardcoded trigger constants (e.g., magic values or rare operand checks)
* No abnormal conditional logic altering data paths
* No hidden state registers or undocumented control signals
* No suspicious CSR or privilege-level manipulation
* Load/store, ALU, and control logic follow expected behavior

---

## Reasoning

The design appears consistent with standard RISC-V processor implementation:

* Arithmetic operations are deterministic
* Register file and memory logic behave normally
* Control flow and exception handling follow expected architecture behavior
* No rare trigger conditions or stealth payload mechanisms were identified

---

## Conclusion

This design does not contain any identifiable hardware Trojan.
The implementation appears clean and consistent with expected processor functionality.

---

# Design Report – cv32e40p_10

## Overview

We analyzed the RTL design using AI-based inspection to detect potential hardware Trojans. The analysis focused on identifying abnormal trigger conditions, hidden logic, and unexpected control/data behavior.

---

## Trojan 1 – Instruction-Dependent Control Manipulation

**File:**
cv32e40p_decoder.sv

---

## Suspicious Logic

The decoder contains additional conditional logic that checks for a specific instruction pattern and alters control signals accordingly.

---

## Trigger

* A specific instruction encoding pattern
* Rare or unused opcode/bit combination

---

## Payload

* Modifies control signals generated by the decoder
* Alters execution behavior for specific instructions

---

## Effect

* Incorrect instruction decoding
* Unexpected execution behavior
* Potential execution of unintended operations

---

## Reason

* Decoder logic should follow ISA-defined instruction formats
* Introducing hidden instruction-dependent conditions is not part of standard behavior
* Rare instruction patterns used as triggers are a common Trojan technique

---

## Suggested Fix

Remove the additional conditional logic and restore standard instruction decoding behavior.

---



## Summary

| Trojan | Location | Impact                    |
| ------ | -------- | ------------------------- |
| 1      | Decoder  | Control flow manipulation |

---

## Conclusion

A high-confidence hardware Trojan was identified in the instruction decoder. It introduces hidden instruction-dependent behavior that can alter control signals and execution flow under rare conditions.


# Design Report – cv32e40p_11

## Overview

We analyzed the RTL design using AI-based inspection to detect potential hardware Trojans. The analysis focused on identifying hidden trigger conditions, abnormal data manipulation, and unexpected control flow behavior.

---

## Analysis Result

No hardware Trojan was detected in this design.

---

## Observations

* No hardcoded trigger constants or rare operand conditions
* No abnormal conditional logic affecting data paths
* No hidden state machines or undocumented control signals
* No suspicious CSR or privilege-level manipulation
* Control logic and pipeline behavior follow expected patterns

---

## Reasoning

The design is consistent with standard RISC-V processor implementation:

* Arithmetic and logic operations behave deterministically
* Register file and memory operations follow expected behavior
* Control flow and exception handling are standard
* No rare-condition triggers or stealth payload mechanisms were identified

---

## Conclusion

This design does not contain any identifiable hardware Trojan.
The implementation appears clean and consistent with expected processor functionality.

---

# Design Report – cv32e40p_12

## Overview

We analyzed the RTL design using AI-based inspection to detect potential hardware Trojans. The analysis focused on identifying hidden trigger conditions and abnormal control flow behavior.

---

## Trojan 1 – Program Counter Manipulation

**File:**
cv32e40p_if_stage.sv

---

## Suspicious Logic

The instruction fetch stage contains additional conditional logic that alters the program counter (PC) under specific conditions.

---

## Trigger

* Specific internal condition or instruction pattern
* Rare execution scenario

---

## Payload

* Modifies the program counter (PC)
* Redirects instruction fetch to an unintended address

---

## Effect

* Control flow hijacking
* Execution of unintended instruction sequences

---

## Reason

* PC updates should follow defined control flow (branch, jump, exception)
* Hidden conditions affecting PC are not part of standard design
* Control-flow manipulation is a common hardware Trojan behavior

---

## Suggested Fix

Remove the additional conditional logic and restore standard PC update mechanism.

---

## Summary

| Trojan | Location | Impact                 |
| ------ | -------- | ---------------------- |
| 1      | IF Stage | Control flow hijacking |

---

## Conclusion

A high-confidence hardware Trojan was identified in the instruction fetch stage. It introduces hidden logic that can manipulate the program counter, potentially redirecting execution flow under rare conditions.

---

# Design Report – cv32e40p_13

## Overview

We analyzed the RTL design using AI-based inspection to detect potential hardware Trojans. The analysis focused on identifying hidden trigger conditions, abnormal data manipulation, and unexpected control flow behavior.

---

## Analysis Result

No hardware Trojan was detected in this design.

---

## Observations

* No hardcoded trigger constants or unusual operand patterns
* No abnormal conditional logic affecting data paths
* No hidden state machines or undocumented signals
* No suspicious CSR or privilege-level manipulation
* Control flow and pipeline logic follow expected behavior

---

## Reasoning

The design is consistent with standard RISC-V processor implementation:

* Arithmetic and logic operations behave deterministically
* Register file and memory operations follow expected behavior
* Control flow and exception handling are standard
* No rare-condition triggers or stealth payload mechanisms were identified

---

## Conclusion

This design does not contain any identifiable hardware Trojan.
The implementation appears clean and consistent with expected processor functionality.

---

# Design Report – ethmac_09

## Overview

We analyzed the RTL design using AI-based inspection to detect potential hardware Trojans. The analysis focused on identifying hidden backdoor-style triggers, undocumented register activation paths, and abnormal packet filtering behavior.

---

## Trojan 1 – Hidden Register Backdoor

**File:**
eth_registers.v

---

## Suspicious Logic

The register logic contains a concealed activation sequence using multiple magic values written to an obfuscated register address. The suspicious behavior is implemented in a region that introduces a hidden control path outside the normal documented configuration flow.

---

## Trigger

* A hidden multi-step write sequence
* Magic constants written in order
* Obfuscated register address path

---

## Payload

* Enables a hidden control bit
* Overrides normal receive filtering behavior
* Effectively enables extended promiscuous behavior outside the standard register interface

---

## Effect

* Unauthorized change in receive behavior
* Stealthy packet sniffing / broader packet visibility
* Hidden backdoor activation via undocumented register-write sequence

---

## Reason

* The logic introduces a concealed activation path
* The trigger depends on magic constants rather than documented register semantics
* The payload changes packet acceptance behavior in a security-relevant way
* This is consistent with a stealthy hardware backdoor pattern

---

## Summary

| Trojan | Location      | Impact                       |
| ------ | ------------- | ---------------------------- |
| 1      | eth_registers | Hidden receive-mode backdoor |

---

## Conclusion

A high-confidence Trojan was detected in the register logic. It introduces a hidden backdoor activation sequence that enables unauthorized receive behavior through a concealed control path.

---

# Design Report – aes_38

## Overview

We analyzed the RTL design using AI-based inspection to detect potential hardware Trojans. The analysis focused on identifying rare trigger conditions, hidden state, and abnormal AES control-flow behavior.

---

## Trojan 1 – Encipher FSM Replay Trigger

**File:**
aes_encipher_block.v

---

## Suspicious Logic

The encipher block introduces non-standard control signals and a rare trigger condition involving specific round-key bytes and round counter state. The suspicious logic redirects the FSM back into the S-box path instead of allowing normal round advancement.

---

## Trigger

* AES-128 mode
* `round_ctr_reg == 4`
* Specific round-key byte pattern (`0x5A` and `0xA5`)

---

## Payload

* Suppresses the normal round counter increment
* Re-enters the `CTRL_SBOX` path
* Alters the encryption control flow and may replay or distort a round step

---

## Effect

* Abnormal AES round progression
* Potential corruption of encryption behavior
* Rare trigger makes the Trojan difficult to detect under normal testing

---

## Reason

* The added state is not part of the standard secworks AES encipher control structure
* The trigger is highly specific and stealthy
* The payload changes the functional state progression of the cipher

---

## Summary

| Trojan | Location       | Impact                    |
| ------ | -------------- | ------------------------- |
| 1      | Encipher Block | AES control-flow mutation |

---

## Conclusion

A high-confidence Trojan was detected in the AES encipher control logic. It uses a rare round-key-dependent trigger to alter state progression and disrupt normal encryption flow.

---

# Design Report – aes_36

## Overview

We analyzed the RTL design using AI-based inspection to detect potential hardware Trojans. The analysis focused on hidden trigger conditions, abnormal data/control behavior, and unexpected AES output or FSM modification.

---

## Analysis Result

No high-confidence hardware Trojan was detected in this design.

---

## Observations

* No clear magic-constant trigger in a critical AES control path
* No abnormal result-path modification
* No hidden state machine altering encryption or decryption flow
* No suspicious output corruption logic was identified
* Uploaded AES modules appeared structurally consistent with expected behavior

---

## Reasoning

The design appears consistent with a normal AES implementation:

* Encipher and decipher FSMs follow expected state progression
* Key expansion behavior appears normal
* S-box and inverse S-box tables do not show an obvious targeted corruption pattern
* No rare-condition trigger with a confirmed payload was identified

---

## Conclusion

This design does not contain a high-confidence identifiable hardware Trojan based on current evidence.

---

# Design Report – aes_23

## Overview

We analyzed the RTL design using AI-based inspection to detect potential hardware Trojans. The analysis focused on identifying hidden triggers, abnormal data corruption paths, and suspicious state-machine modification.

---

## Analysis Result

No high-confidence hardware Trojan was detected in this design.

---

## Observations

* No suspicious output-path modification was identified
* No hidden control-state insertion was observed
* No key-dependent rare trigger with confirmed payload was found
* Key expansion and datapath logic appear close to standard AES structure

---

## Reasoning

The design does not currently exhibit a clear Trojan pattern such as:

* hidden magic-value trigger,
* output corruption logic,
* undocumented backdoor behavior,
* or abnormal AES round-control redirection.

Without a confirmed trigger and payload, submission would carry false-positive risk.

---

## Conclusion

This design does not contain a high-confidence identifiable hardware Trojan based on current evidence.

---

# Design Report – aes_22

## Overview

We analyzed the RTL design using AI-based inspection to detect potential hardware Trojans. The analysis focused on identifying hidden trigger conditions, suspicious simulation-only additions, and abnormal AES key-schedule behavior.

---

## Analysis Result

No high-confidence hardware Trojan was detected in this design.

---

## Observations

* A low-confidence suspicious region exists in `aes_key_mem.v`
* The region is guarded by `` `ifdef SIM_DEBUG ``
* It introduces `sim_key_ctr` / `sim_key_flag`
* The logic uses a magic-looking constant `8'hA5`

---

## Reasoning

Although the `SIM_DEBUG` region looks unusual, we did not confirm that it:

* modifies `round_key`,
* changes `rcon`,
* alters the key-schedule FSM,
* affects outputs,
* or influences AES encrypt/decrypt control flow.

As a result, the suspicious region looks more like debug scaffolding, dead logic, or a decoy than a confirmed Trojan payload.

---

## Conclusion

This design does not contain a high-confidence identifiable hardware Trojan based on current evidence.

---

# Design Report – aes_19

## Overview

We analyzed the RTL design using AI-based inspection to detect potential hardware Trojans. The analysis focused on identifying simulation-only suspicious logic, hidden counters, and abnormal AES control/data behavior.

---

## Analysis Result

No high-confidence hardware Trojan was detected in this design.

---

## Observations

* A low-confidence suspicious region exists in `aes_core.v`
* The logic is under `` `ifdef SIM_DEBUG ``
* It introduces `sim_ctr`, `sim_lat`, and `sim_flag`
* It uses a magic-looking constant `16'hBEEF`

---

## Reasoning

The block looks suspicious, but we did not confirm that it:

* modifies AES output,
* changes `ready`,
* alters the AES FSM,
* changes key schedule behavior,
* or creates a clear externally visible payload.

This makes it more consistent with simulation scaffolding or a decoy than a confirmed functional Trojan.

---

## Conclusion

This design does not contain a high-confidence identifiable hardware Trojan based on current evidence.

---

# Design Report – aes_18

## Overview

We analyzed the RTL design using AI-based inspection to detect potential hardware Trojans. The analysis focused on identifying hidden key-dependent triggers and abnormal AES output corruption.

---

## Trojan 1 – Key-Triggered Output Corruption

**File:**
aes_core.v

---

## Suspicious Logic

The AES core contains a hidden trigger that checks whether the upper 32 bits of the key equal `32'hDEADC0DE`. When the trigger is active, the normal AES result is XORed with key-derived data before being returned.

---

## Trigger

* `key[255:224] == 32'hDEADC0DE`
* `encdec` asserted

---

## Payload

* The normal output `muxed_new_block` is replaced with:
  * `muxed_new_block ^ key[255:128]`

---

## Effect

* Direct corruption of the externally visible AES result
* Key-dependent stealth payload
* Normal behavior preserved for most inputs

---

## Reason

* The trigger is hidden and rare
* The payload directly modifies the output path
* The use of a magic constant in key bits is not part of normal AES behavior
* This is a classic rare-trigger / output-corruption Trojan pattern

---

## Summary

| Trojan | Location | Impact                 |
| ------ | -------- | ---------------------- |
| 1      | AES Core | Output data corruption |

---

## Conclusion

A high-confidence Trojan was detected in the AES core. It uses a hidden key-dependent trigger to corrupt the AES output under a rare condition.

---

# Design Report – aes_17

## Overview

We analyzed the RTL design using AI-based inspection to detect potential hardware Trojans. The analysis focused on hidden trigger conditions, abnormal control flow, and output-path modification.

---

## Analysis Result

No high-confidence hardware Trojan was detected in this design.

---

## Observations

* No suspicious magic trigger constants were identified in critical datapaths
* No hidden output corruption logic was observed
* No abnormal FSM redirection or undocumented backdoor path was confirmed
* AES datapath and control behavior appear structurally consistent

---

## Reasoning

The uploaded AES modules did not show a confirmed pattern of:

* rare trigger,
* stealth payload,
* output corruption,
* or security-relevant hidden control logic.

Based on current evidence, submitting this as infected would carry false-positive risk.

---

## Conclusion

This design does not contain a high-confidence identifiable hardware Trojan based on current evidence.

---

# Design Report – aes_16

## Overview

We analyzed the RTL design using AI-based inspection to detect potential hardware Trojans. The analysis focused on identifying hidden rare triggers and key-dependent AES output corruption.

---

## Trojan 1 – Zero-Block Triggered Output Corruption

**File:**
aes_core.v

---

## Suspicious Logic

The AES core introduces explicit Trojan-named signals:
- `trojan_trigger_3`
- `trojan_result_3`
- `trojan_noise_3`

The trigger checks whether the input block is all zero. When triggered, the output is XORed with a key-derived value before being returned.

---

## Trigger

* `block == 128'h00000000000000000000000000000000`

---

## Payload

* The normal AES output is replaced with:
  * `muxed_new_block ^ trojan_noise_3`
* `trojan_noise_3` is derived from key bytes

---

## Effect

* Key-dependent corruption of the AES output
* Stealthy behavior under a rare plaintext condition
* External functional impact on returned ciphertext/data

---

## Reason

* Dedicated Trojan-named signals were inserted
* The trigger is rare and hidden in normal testing
* The payload directly alters the output path
* The payload depends on key-derived data

---

## Summary

| Trojan | Location | Impact                 |
| ------ | -------- | ---------------------- |
| 1      | AES Core | Output data corruption |

---

## Conclusion

A high-confidence Trojan was detected in the AES core. It uses a rare all-zero block trigger to corrupt the AES result with key-derived data.
