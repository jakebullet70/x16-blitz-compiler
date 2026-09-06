---
name: two-pass-compiler
description: "Rebuilding GPC to compile the source twice and stream p-code to disk, so the object buffer stops capping program size. Branch two-pass-compiler; steps 1-5 done and verified; the object checksum is the safety net."
metadata: 
  node_type: memory
  type: project
  originSessionId: 75714395-f705-4d27-8da6-af4a832a1e0b
  modified: 2026-09-06T06:17:51.719Z
---

**Branch `two-pass-compiler`, off `3335ab5`, started 2026-09-06.** Chosen by the user over shaving
compiler bytes and over [[compiler-overlay-into-a-bank]], both of which only move the wall. Rests
on [[compile-is-write-only]].

**The problem.** `FreeMemory` is `.align 256` after the compiler's last byte and the object buffer
runs from there to `ObjectCeiling $9F00`, so every compiler byte comes 1:1 off the largest
compilable program. Worse now that a program may have **eight** GP.BANKED regions: a maximal
object is 15,616 low + 8 x 8,192 = 81,152 bytes and low RAM below `$9F00` is 39,679 in total, so
**no amount of overlaying compiler code into banks can ever reach it.** That, not the failed
overlay attempt, is the real argument for two passes.

## DONE AND VERIFIED (steps 1-5)

1. **The gate.** Nothing reads the object mid-compile -- see [[compile-is-write-only]].
2. **The driver.** `CompilePass` / `ResetPassState` in `main/compiler.asm`. Turned up `AsmPoolLen`
   and `AsmFixupCount`, never reset, working only because they sit in the code section and arrive
   zeroed by the loader -- same family as the `gpBankCount` bug.
3. **`_variable.space` resolved at emit**, its `FixBranches` handler deleted.
4. **Pass one lays the object out** (runs `AsmFlushPool` + `GPBankRelocate` too) and **pass two
   writes each region straight to its final address** -- entry bridge in low memory, cursor to the
   region, exit bridge and end marker, cursor back. Pass two rotates nothing.
5. **The layout is handed over at the HEAD of pass two**, so `GPBankMakeOffset` works while pass
   two is still emitting. The GP.BANKED generators get a pass-two path that neither records nor
   re-validates.

**THE INVARIANT: `ObjectChecksum`.** Both passes lay their object out and it Fletcher-16s the
result; the tail of pass two compares sum, length and variable space, and a mismatch is
`.error_internal` with no object written. It sums the **finished object, not the stream of
writes** -- the write order legitimately differs now that pass two places regions directly. It
skips the first three bytes, `_variable.space` and its operand, the one place the two objects are
meant to differ.

## Two traps that cost a cycle each

- **`STRMarkLine` is called with the line number still in YA.** The `RegionSwitch` hook sits in
  front of it in the main loop (it must, a region begins ON the GP.BANKED line's marker byte) and
  so has to be register-transparent. It was not: every banked program failed
  `UNKNOWN LINE NUMBER @ 3`.
- **`GPBankStructure` goes out of branch range easily.** `CommandGPBankedCompile` is long and
  branches to it; anything inserted between pushes it away. The pass-two halves live BELOW it, as
  globals -- 64tass scopes a `_` label to the enclosing global.

## STILL TO DO

6. **Resolve the rest at emit and delete `FixBranches`.** The line table already works for this:
   `STRReset` resets only the *pointer*, not the banked data, so during pass two the lines not yet
   re-marked still hold pass one's final addresses and the re-marked ones hold identical values --
   `STRFindLine` is correct throughout. Order matters, because `.unwind` reads the following
   GOTO's operand as a line number and breaks the moment that GOTO is resolved:
   a. one byte of **block depth per line** in its own bank (do NOT widen the 4-byte line record;
      that drops the cap from 2,048 lines to 1,638);
   b. `.unwind` at emit, from it;
   c. GOTO / GOSUB / RESTORE / .fngosub at emit;
   d. structural forward branches -- `blockEnd[]` by block ordinal and `altNext[]` by alternative
      ordinal, both in a bank. No chains needed: several `.exitdo`s in one loop all read the same
      `blockEnd` entry, and there is at most one pending `.ifnext` per open block.
      `BlockDepthUp`/`Down` (`goto.asm:70`) are already the GP.DO hooks and `SelectDepth` is
      already a compile-time stack.
7. **Stream pass two to the file.** Both files are open at once, so buffer a page -- `object.asm`
   already measures it: 28,000 CHKIN/CHKOUT pairs per byte against 94 per page. The alignment gaps
   between regions must be filled then; today pass two lands on pass one's addresses in the same
   buffer, so the gaps still hold pass one's bytes.

**Measured cost: 2.19x** (PICKDEMO 3.54 s -> 7.75 s, warp, best of 3). Worse than the 1.8x guess
because pass one still stores every byte; step 7 stops that, but it still parses everything, so
2x is the standing cost. `FreeMemory` has gone `$5200 -> $5400` along the way; irrelevant, the
buffer goes away at step 7.

**GPBMODS still fails `PROGRAM TOO BIG @ 1889` -- on the compiler at `3335ab5` too.** It has never
compiled on this branch's baseline; only step 7 fixes it.

Related: [[compiler-must-not-cap-program-size]], [[gp-banked-region-relocation]],
[[baseline-compiler-is-the-application-copy]], [[measure-before-changing-code]].
