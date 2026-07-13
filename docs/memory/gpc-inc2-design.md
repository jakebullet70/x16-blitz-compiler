---
name: gpc-inc2-design
description: Integer-first increment 2 — 2a (int compare/IJZ) + 2b (int FOR) SHIPPED; 2c (int arrays DIM A%()) now ALSO SHIPPED (e5a8f5a, branch int-arrays) after Tier-1 RAM freed it
metadata: 
  node_type: memory
  type: project
  originSessionId: 481504f0-31d5-4658-a8c1-3b05e8802238
---

**2c SHIPPED (2026-07-09, branch `int-arrays`, commit e5a8f5a):** integer arrays `DIM A%()` re-landed.
Opcodes IDIM/IALOAD/IASTORE = 89/90/91; 2-byte elements in their own iarrheap (host-assigned slab like the
others post-Tier-1); reuses the generic dim_setup/index_of; loads typed TY_INT (native-int fast path). The
two blockers that killed it in inc2 are BOTH gone: the RAM (runtime asm-shrink + Tier-1 slabs-above-pcode
freed the in-process string heap) and the array zero-init bug (fixed). Corpus 286/286. Two fresh gotchas hit
+ recorded in [[gpc-runtime-asm-conversion]] (the dispatch `cmp #N` opcode bound + the PCODE_BASE-above-BSS
invariant). NOTE: the opcode numbers here (89-91, PCODE_BASE $3E00) SUPERSEDE the "recoverable from transcript"
89-91/$5800 mention below.

Increment 2 of [[gpc-project]] integer-first arithmetic. Outcome (2026-07-08):

**SHIPPED (green):**
- **2a — integer comparisons + logic + branch.** New opcodes 77-86: ICMPEQ/NE/LT/GT/LE/GE (pop 2 ints, push CBM truth -1/0), IJZ (imm16; pop int, branch if 0 — a trampoline), IAND/IOR/INOT (bitwise on the 16-bit int). Same firing rule as inc1 arithmetic: integer variant only when both operands intish AND >=1 real TY_INT, so `%`-free code is byte-value-identical. `emit_op` folds them into ONE cascade using the fact that the int opcode is a fixed offset above the float one (CMP*: +66, AND/OR: +67); the integer-capable float opcodes 11..18 form a contiguous block, so `fop>=OP_CMPEQ and fop<=OP_OR` gates the integer path. `parse_if` sets `expr_keep_int=true` then emits IJZ vs JZ by `is_intish(expr_type)`.
- **2b — integer FOR/NEXT.** Opcodes 87-88: IFORPUSH/IFORNEXT. `FOR I%=..` (V2 rejects `FOR I%`, so it's a pure extension). Runtime frame adds `word[8] for_ilimit/for_istep` (a frame uses the float OR the int pair, fixed by the opcode — no runtime tag). Compiler `for_is_int[MAXFOR]`; parse_for/parse_next dispatch int vs float NEXT. `for_operand(is_int)` helper truncates a float bound via FTOI. Integer stepping wraps at 16 bits (documented `%` opt-in).

**REVERTED (user chose "revert 2c, ship 2a+2b"):**
- **2c — integer arrays (`DIM A%()`, IDIM/IALOAD/IASTOR).** Was fully implemented and worked for common cases, but hit two walls: (1) the resident compiler + bundled VM grew so large that the in-process string heap (placed at [progend..MEMTOP]) collided with the image under R49 MEMTOP $9f00 — every string program crashed in-process; (2) it surfaced the pre-existing bug below. Reverted cleanly; `A%(` again raises E_SYNTAX. The 2c work is recoverable from the session transcript if revisited AFTER the array bug + a RAM strategy.

**KEPT (infrastructure improvements, all clean wins):**
- **Banked-RAM migration of ALL compile-time symbol/map tables** to NAMES_BANK (= PCODE_BANK0+2 = bank 9, a free RAM bank above source banks 1-6 and P-code banks 7-8): var/int/string/array name tables (`varnames_ptr = BRAM+0` etc.), the GOTO/THEN line map (`linenums_ptr`/`lineaddrs_ptr`, record_line/find_line_addr rewritten with peekw/pokew), and DEF FN names (`fnnames_bptr`). Each intern_*/record_line/find_line_addr does `cx16.rambank(NAMES_BANK)` first; every P-code emit (pc_poke) and source read (next_src_line) re-asserts ITS own bank, so the switch self-corrects. Freed ~3 KB of low RAM. This is the RIGHT architecture (a run reads P-code by slot, never by name/line).
- **heapfloor fix:** vm.heapfloor field; in-process the host sets it to `sys.progend()` (above all slabs) instead of the increment-1 datatop-based placement (which relied on the now-banked name-table gap). Standalone leaves it 0 -> floors at datatop. NOTE: still fragile — as the image grows toward MEMTOP the heap window shrinks; this is what killed 2c in-process.
- **tbase/keep_int nested-parse fix (real latent-bug fix):** Prog8 locals are STATIC (fixed addresses, no call stack), and parse_expr recurses via parse_index for subscripts/args. The nested call clobbers the outer parse_expr's `keep_int` and `tbase` locals. inc1 added those locals but never saved them across the recursion (only `mybase`/`stop_rp` were protected). Now `fr_tbase[EXPRNEST]`/`fr_keepint[EXPRNEST]` save/restore them at all 6 nested-parse sites. Without this, an integer expression containing an array/func load mis-types its result.

Corpus: 2a added 15 tests, 2b added 8 -> **257/257 green** after the 2c revert. Benchmark (loop-control-heavy: `FOR`, an `IF x>N` guard, counter `x=x+1`, 25000 iters, -warp best-of-3): float **3.44 s** vs `%`-integer **1.19 s** = **~2.9x** on loop CONTROL (2a IF-compare + 2b FOR + inc1 arithmetic), matching inc1's ~2.9x on raw arithmetic. See [[gpc-project]] for the running record.

**2c re-attempt UNBLOCKED (2026-07-08):** the "critical array bug" that was the stated prerequisite is
FIXED (see [[gpc-array-load-loop-bug]] — it was just DIM not zero-initializing elements, a one-line
`op_dim` memset, NOT the feared sp-leak). So re-attempting integer arrays now only needs the **RAM
strategy** (the resident compiler+VM must fit under MEMTOP $9f00 with room for the in-process string heap):
bank the LIT/DATA pools, or split the VM out of the resident compiler. The 2c opcode/compiler work
(IDIM/IALOAD/IASTOR, opcodes 89-91, PCODE_BASE $5800) is recoverable from this session's transcript.
Corpus is now **262/262** (5 array zero-init regression tests added).
