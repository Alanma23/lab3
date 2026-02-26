# Performance Improvement Implementation Directions

This document maps the lab handout’s optimization ideas to **concrete implementation steps** in this codebase, with a focus on **SIMD-style vectorization** (like the packed-byte Sobel approach) and related hardware/software changes.

---

## 1. Packed SIMD (highest impact for Sobel)

**Idea:** One 32-bit register holds 4 bytes. Add instructions that operate on 4 lanes at once so pixel math gets ~4× throughput.

### Instructions to add

| Instruction      | Meaning                          | Use in Sobel                    |
|------------------|----------------------------------|---------------------------------|
| `PADD.B $rd,$rs,$rt` | 4 byte adds in parallel         | Gx/Gy partial sums              |
| `PSUB.B $rd,$rs,$rt` | 4 byte subtracts in parallel    | Differences and negation        |
| `PSLL.B $rd,$rs,shamt` | Shift each byte left (×2)     | Center pixel ×2 in kernel       |
| `PABS.B $rd,$rs`     | Absolute value per byte         | \|Gx\|, \|Gy\|                  |
| `PUNPKLO $rd,$rs`    | Unpack lower 2 bytes → 16-bit   | Widen for accumulation          |
| `PUNPKHI $rd,$rs`    | Unpack upper 2 bytes → 16-bit   | Widen for accumulation          |

Sobel kernel weights are ±1 or ±2: `PSLL.B` by 1 does ×2, `PSUB.B` does negation. Use unpack + scalar add (or a future PHADD) to accumulate without overflow (sum can reach ~2040).

### Implementation steps

1. **`hw/hdl/verilog/mips/mips_defines.v`**
   - Pick **new funct codes** under `SPECIAL` (op `6'b000000`) for the packed ops, e.g.:
     - `PADD_B`, `PSUB_B`, `PSLL_B`, `PABS_B`, `PUNPKLO`, `PUNPKHI` (use unused funct values, e.g. in the 0x20–0x3f range if available).
   - Add **ALU opcodes** (you have 4-bit `alu_opcode`; `ALU_SUBM` is 4'd16, so you have room or can repurpose):
     - e.g. `ALU_PADD_B`, `ALU_PSUB_B`, `ALU_PSLL_B`, `ALU_PABS_B`, `ALU_PUNPKLO`, `ALU_PUNPKHI`.

2. **`hw/hdl/verilog/mips/decode.v`**
   - In the `casex({op, funct})` block, add entries for each new instruction:
     - `{`SPECIAL`, `PADD_B`}: alu_opcode = `ALU_PADD_B;` (and similarly for PSUB_B, PSLL_B, PABS_B, PUNPKLO, PUNPKHI).
   - For `PSLL.B`, `alu_op_x` should be the **shift amount** (e.g. from `shamt`), same as existing SLL; for the rest, `alu_op_x` = rs, `alu_op_y` = rt (or 0 for PABS / unpack).
   - Ensure `read_from_rs` / `read_from_rt` and `reg_write_addr` include these (R-type: rd = dest; PABS and unpack only use rs).

3. **`hw/hdl/verilog/mips/alu.v`**
   - Implement each new opcode:
     - **PADD.B / PSUB.B:** Operate on four 8-bit lanes: e.g. `rd[7:0]=rs[7:0]±rt[7:0]`, same for [15:8], [23:16], [31:24]. Use saturation or truncation (e.g. clip to 0–255 for bytes).
     - **PSLL.B:** For each byte lane, shift left by `alu_op_x[2:0]` (or `shamt[2:0]`), keep result in 8 bits (mask to byte after shift).
     - **PABS.B:** Per byte: negate if negative (e.g. sign-extend byte to 32b, take abs, then take low 8 bits).
     - **PUNPKLO:** `rd[15:0] = {8'b0, rs[7:0]}; rd[31:16] = {8'b0, rs[15:8]};` (zero-extend).
     - **PUNPKHI:** `rd[15:0] = {8'b0, rs[23:16]}; rd[31:16] = {8'b0, rs[31:24]};`.

4. **Assembler / encoding**
   - Your toolchain may not know these opcodes. You can:
     - Use `.insn` or equivalent in assembly to emit the desired machine words, or
     - Add a small assembler script that replaces pseudo-ops with the correct `SPECIAL` + funct encoding.

5. **Sobel kernel (assembly)**
   - Rewrite the inner loop to compute **4 output pixels per iteration**:
     - Load 4 consecutive pixels per row (e.g. load a word, or 4 bytes into packed regs).
     - Use PADD.B/PSUB.B/PSLL.B to compute 4 Gx and 4 Gy in parallel; PABS.B for magnitude; then PUNPKLO/PUNPKHI and scalar adds to form 16-bit sums, then clamp and store 4 bytes.

This gives the “~4× on the compute-bound portion” mentioned in the handout.

---

## 2. Scalar ABS instruction

**Idea:** `ABS $rd, $rs` → magnitude of `$rs` in one cycle. Replaces the `slt` + `subu` + `movn` sequence used in the current Sobel for \|Gx\| and \|Gy\|.

### Implementation

- **mips_defines.v:** New funct under `SPECIAL`, e.g. `ABS`; new ALU opcode `ALU_ABS`.
- **decode.v:** One case in the decode `casex`: `{`SPECIAL`, `ABS`}: alu_opcode = `ALU_ABS;`. `alu_op_x` = rs, rt unused.
- **alu.v:** `ALU_ABS`: `alu_result = (alu_op_x_signed < 0) ? -alu_op_x : alu_op_x;` (or equivalent 32-bit abs).

Useful even before SIMD: the current `sobel_mips.S` uses `slt` + `subu` + `movn` for abs; a single `ABS` reduces cycles and simplifies scheduling.

---

## 3. Multiply-accumulate (MADD)

**Idea:** `MADD $rd, $rs, $rt, $ra` → `rd = rs*rt + ra`. Removes the mul–add dependency and reduces instruction count in multiply-heavy code.

### Implementation notes

- **Encoding:** Fits naturally in `SPECIAL2` (op `6'b011100`) alongside `MUL`; add a new funct for MADD.
- **Data path:** MADD needs **three** register reads (rs, rt, ra) and one write (rd). Your decode currently drives `alu_op_x` and `alu_op_y` from rs/rt. You need:
  - A way to read `$ra` (or a third operand reg) into the ALU (e.g. `alu_op_z` or a dedicated MADD path).
  - ALU: either a combined `result = (x * y) + z` in one cycle, or use the existing MUL and add in the same stage (ra forwarded like rs/rt).
- **decode.v:** Forward `reg_write_data_mem` / `alu_result_ex` to the “ra” operand when the instruction in EX/MEM is the one writing ra; handle hazards like any other three-source instruction.

So: small decode change in terms of opcode, but **one extra operand (ra)** and ALU expansion. Often done after SIMD + ABS for a smaller design.

---

## 4. Software-only improvements (no Verilog)

- **Use \|Gx\| + \|Gy\| instead of sqrt:** Your current `sobel_mips.S` already does `addu $2,$2,$3` after clamping Gx and Gy, i.e. magnitude sum. If you have a sqrt-based version elsewhere (e.g. C), switching to magnitude sum avoids the sqrt loop and saves many cycles.
- **Instruction scheduling:** Reduce load-use stalls by loading all 9 pixels (or the next set of 4 packed pixels) early and doing arithmetic from the **previous** pixel in the delay slots. Reorder the assembly so that no dependent use happens immediately after a load.
- **Loop unrolling:** Process 4 output pixels per iteration (or 2). Amortizes branch and counter updates and gives more independent work to hide load latency. Pairs well with packed SIMD.

---

## 5. Larger-effort hardware options

- **Cache:** Instruction cache (e.g. 256 entries) and data cache (e.g. 512, write-through) so repeated row access in the 3×3 window doesn’t hit main memory every time. Biggest potential fps gain, but most work.
- **Superscalar / dual-issue:** Issue one ALU and one memory op per cycle. Requires a second decode path and hazard logic for independence. Complements SIMD by hiding memory latency while SIMD improves compute.

---

## Suggested order for this lab

1. **Packed SIMD (PADD.B, PSUB.B, PSLL.B, PABS.B, PUNPKLO, PUNPKHI)** in `mips_defines.v` → `decode.v` → `alu.v`, then rewrite Sobel to process 4 pixels per iteration with packed registers.
2. **Scalar ABS** in decode + ALU; optionally use in scalar Sobel or in the scalar “tail” of the SIMD loop.
3. **Software:** Better scheduling and loop unrolling; confirm \|Gx\| + \|Gy\| everywhere.
4. **MADD** if you have time and want to reduce mul+add stalls; otherwise cache or dual-issue for extra credit.

This order gives a clear path to “close to 4× on the compute-bound portion” with SIMD vectorization similar in spirit to what you did for Sobel in software, but now in hardware.
