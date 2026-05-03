# AI Interaction Log — Trojan 2: Timing-Degradation + Mid-Round Block Corruption

**Competition:** IEEE HOST 2026 AI Hardware Attack (AHA!) Challenge
**Target Design:** secworks AES Core — `aes_encipher_block.v`
**Model Used:** Claude Sonnet (claude.ai web interface)
**Trojan:** 16-stage combinational chain inserted into the AES encipher datapath

---

## Overview of AI Usage Strategy

The design process for Trojan 2 followed a structured, iterative methodology. Rather than asking the AI to generate a Trojan in one shot, the process was broken into distinct phases: design exploration, injection point analysis, implementation, reference value computation, testbench generation, and simulation-driven verification. The AI acted as both a code analyst and a hardware design collaborator throughout.

---

## Phase 1 — Design Goal Setting

**Prompt intent:** Establish design constraints before writing any code.

The prompt specified three explicit goals:

1. The Trojan should involve **larger RTL changes** than Trojan 1 (which was only 2 lines in `aes_core.v`), targeting a different module to maximize submission diversity.
2. The modification should **affect synthesis timing** — specifically, it should create a new combinational path long enough to appear in the Yosys/OpenSTA timing report as a slack degradation.
3. Functional correctness for non-trigger inputs must be preserved.

The AI was asked to reason about *which module* and *which signal path* would produce the most timing impact. It identified `aes_encipher_block.v` as the best target because:
- The encipher path is on the synthesis critical path for AES encryption.
- The `round_logic` always block computes `block_new` combinationally from `{block_w0_reg..block_w3_reg}` and `round_key` — a chain starting and ending at registers, exactly the structure synthesis tools time.
- Modifications here affect *every encryption operation's timing*, not just key expansion.

---

## Phase 2 — Trigger and Payload Design

**Prompt intent:** Choose a trigger/payload pair that is stealthy, verifiable, and produces noticeable timing impact.

The AI proposed and compared several options:

| Option | Trigger | Payload | Timing Impact |
|---|---|---|---|
| A | `key[255:224]` pattern | Corrupt round key 7 in `aes_key_mem.v` | Moderate — key mem not on enc critical path |
| B | `round_ctr_reg == 4'h7` always | Inject fixed XOR at round 7 | Low — simple gate, minimal depth |
| **C (chosen)** | `block[127:96] == DEADBEEF AND round == 7` | XOR `block_new[127:96]` with 16-stage chain | **High — chain sits directly on enc data path** |

Option C was selected because the 16-stage chain (`t2_s0` through `t2_s15`) incorporates three 32-bit modular adders. Adders produce deep carry-chain logic (~5–6 gate levels each in ripple-carry, fewer but still non-trivial with carry-lookahead). Synthesis tools must time the full path from `block_w0_reg` through all 16 stages to `block_new`, regardless of whether the trigger ever fires at runtime. This is the key insight: **the timing impact is unconditional even if the functional payload is conditional**.

The trigger was placed on `block[127:96]` (the original plaintext word 0) rather than on an internal register, making the testbench easy to control: the tester simply sets the first 32 bits of the plaintext to `0xDEADBEEF`.

---

## Phase 3 — Injection Point Identification

**Prompt intent:** Ask the AI to read the existing source and identify exactly where to insert code.

The AI was given the full `aes_encipher_block.v` and asked to locate:

1. Where wire declarations could be added without disturbing the existing synthesis boundary.
2. Which specific line in `round_logic` to modify for the payload.

The AI identified two insertion points:

- **Wire section** (after `reg [31:0] muxed_sboxw;`): safe to add continuous `wire` assignments here — they are outside any always block and synthesize as independent combinational logic.
- **MAIN_UPDATE case** (line ~325): the single line `block_new = addkey_main_block;` was replaced with a ternary that muxes in the corrupted version when the trigger fires.

The AI also flagged that the trigger signal must be declared as a `wire` outside the always block (not a `reg` inside it) to avoid Verilog simulation mismatches between blocking and non-blocking assignment semantics.

---

## Phase 4 — Iterative Chain Depth Design

**Prompt intent:** Design the 16-stage chain for maximum gate depth with minimal area.

The AI reasoned about the gate-level structure of each operation:

- **XOR:** 1 gate level, zero cost.
- **Barrel rotate / bit-select reordering:** 0 gate levels (pure wiring in synthesis).
- **32-bit addition (`+`):** ~5–6 gate levels for carry-lookahead, or 32 for ripple-carry. Synthesis tools choose the implementation; either way, it is significantly deeper than XOR.

The chain was designed to alternate between low-cost XOR/rotate stages (which create data dependencies without deep logic) and three adder stages (which add genuine gate depth). The resulting chain:

```
t2_s0  = XOR with round_key           (1 level)
t2_s1  = XOR + rotate                 (1 level)
t2_s2  = XOR + rotate                 (1 level)
t2_s3  = XOR + rotate                 (1 level)
t2_s4  = XOR + rotate                 (1 level)
t2_s5  = ADD block_w1_reg             (~5-6 levels)  ← adder #1
t2_s6  = XOR + rotate                 (1 level)
t2_s7  = XOR + rotate                 (1 level)
t2_s8  = XOR with round_key[95:64]    (1 level)
t2_s9  = ADD block_w2_reg             (~5-6 levels)  ← adder #2
t2_s10 = XOR + rotate                 (1 level)
t2_s11 = XOR + rotate                 (1 level)
t2_s12 = XOR with round_key[63:32]    (1 level)
t2_s13 = ADD block_w3_reg             (~5-6 levels)  ← adder #3
t2_s14 = XOR + rotate                 (1 level)
t2_s15 = XOR + rotate                 (1 level)
```

Total estimated gate depth: ~21–26 levels beyond the existing `round_logic` path, providing a visible slack delta in the timing report.

---

## Phase 5 — Reference Value Computation

**Prompt intent:** Compute exact expected ciphertext values for both normal and trigger cases.

Because the testbench needed to check specific hex values, the AI generated and executed a Python script using PyCryptodome:

```python
from Crypto.Cipher import AES

k128      = bytes.fromhex("000102030405060708090a0b0c0d0e0f")
pt_normal = bytes.fromhex("00112233445566778899aabbccddeeff")
pt_trig   = bytes.fromhex("DEADBEEF445566778899aabbccddeeff")

# Verify normal NIST vectors
ct_normal_128 = AES.new(k128, AES.MODE_ECB).encrypt(pt_normal)
# → 69c4e0d86a7b0430d8cdb78070b4c55a  ✓ matches NIST SP 800-38A

# True (clean) CT for trigger block
ct_true_trig_128 = AES.new(k128, AES.MODE_ECB).encrypt(pt_trig)
# → d2e02dd3de9d5a64d7e59e8f76ae0010
```

The Trojan CT values (what the modified hardware actually produces) could not be computed analytically because `t2_s15` depends on the live block register state mid-encryption. Instead, a **probe simulation** was run first:

```
AES128 NORMAL  CT: 69c4e0d86a7b0430d8cdb78070b4c55a   ← matches NIST ✓
AES128 TRIGGER CT: d44040004ae9919f5c50c4ff2e31fc6e   ← different from true CT ✓
AES256 NORMAL  CT: 8ea2b7ca516745bfeafc49904b496089   ← matches NIST ✓
AES256 TRIGGER CT: fb0fa0fade3197e3658dcc809d872846   ← different from true CT ✓
```

These values were then hardcoded into the final testbench as expected values.

---

## Phase 6 — Testbench Generation

**Prompt intent:** Generate a self-contained testbench that proves all three properties.

The AI structured the testbench around three explicit claims that the testbench must prove:

1. **Normal operation:** Hardware produces NIST-correct ciphertext for non-trigger inputs.
2. **Trojan activation:** Trigger input produces the known-corrupted ciphertext (not the true AES value).
3. **Trigger selectivity:** The same trigger plaintext in decipher mode (which uses the unmodified `aes_decipher_block`) produces the correct plaintext.

The timing idiom used (`#(2 * CLK_PERIOD)` delays rather than `@(posedge clk)` event waits for `init`/`next` handshaking) was deliberately copied from the original secworks `tb_aes_core.v` to ensure simulation correctness — a lesson learned from debugging Trojan 1's testbench.

---

## Phase 7 — Simulation and Verification

The final simulation run produced:

```
[PASS] TC1 (AES-128 Normal)   69c4e0d86a7b0430d8cdb78070b4c55a
[PASS] TC2 (AES-256 Normal)   8ea2b7ca516745bfeafc49904b496089
[PASS] TC3 (AES-128 Trojan)   d44040004ae9919f5c50c4ff2e31fc6e
[PASS] TC4 (AES-256 Trojan)   fb0fa0fade3197e3658dcc809d872846
[PASS] TC5 (AES-128 Decipher) deadbeef445566778899aabbccddeeff

Results: 5 PASSED,  0 FAILED
ALL TESTS PASSED -- Trojan 2 exploit fully verified.
```

---

## Summary of AI Utilization

| Phase | AI Role | Human Role |
|---|---|---|
| Design goal setting | Proposed candidate modules and explained trade-offs | Chose timing impact as primary constraint |
| Trigger/payload selection | Generated and compared options A/B/C with rationale | Approved Option C |
| Injection point analysis | Read source, identified two exact insertion locations | Reviewed proposed locations |
| Chain depth design | Designed 16-stage structure, reasoned about gate levels per operation | Approved structure |
| Reference value computation | Wrote and executed Python PyCryptodome script; ran probe simulation | Verified outputs made sense |
| RTL modification | Generated `str_replace` patches; applied to file | None — fully AI-generated |
| Testbench generation | Generated complete testbench file | None — fully AI-generated |
| Simulation & debug | Compiled, ran, interpreted results | Reviewed final pass/fail output |

All RTL and testbench code was generated entirely by the AI with no manual editing by team members.

---

## CVSS Score

**Vector:** `CVSS:3.1/AV:N/AC:H/PR:N/UI:N/S:C/C:H/I:H/A:H`
**Base Score: 8.1 (High)**

| Metric | Value | Rationale |
|---|---|---|
| Attack Vector | Network | Encrypted traffic observable remotely |
| Attack Complexity | High | Attacker must control or predict plaintext[127:96] |
| Privileges Required | None | No authentication required |
| User Interaction | None | Passive — trigger fires automatically |
| Scope | Changed | Compromise affects downstream systems relying on integrity of ciphertext |
| Confidentiality | High | Corrupted ciphertext cannot be decrypted; data is unrecoverable |
| Integrity | High | Ciphertext is silently wrong; receiver cannot detect corruption |
| Availability | High | Data encrypted with trigger plaintext is permanently unrecoverable |
