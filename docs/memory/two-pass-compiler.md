---
name: two-pass-compiler
description: "Rebuilding GPC to compile the source twice and stream p-code to disk, so the object buffer stops capping program size. Branch two-pass-compiler; steps 1-6c done and verified; both passes now resolve, and the object checksum compares the two answers."
metadata: 
  node_type: memory
  type: project
  originSessionId: 75714395-f705-4d27-8da6-af4a832a1e0b
  modified: 2026-09-06T00:00:00.000Z
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

## THE INVARIANT, and why it is what makes the rest safe

`ObjectChecksum` Fletcher-16s the object each pass has laid out; the tail of pass two compares
sum, length and variable space, and a mismatch is `.error_internal` with no object written. It
sums the **finished object, not the stream of writes** -- the write order legitimately differs
once pass two places regions directly. It skips the first three bytes, `_variable.space` and its
operand, the one place the two objects are meant to differ.

**BOTH PASSES NOW RESOLVE.** FixBranches runs at the end of pass one as well, so what the checksum
compares is two FINISHED objects. That is what lets the resolving move into pass two's emitter one
branch kind at a time: pass one keeps answering the old way, structurally, from the laid-out
object, so every kind that moves is checked against the answer it used to get, on every program
compiled. Pass one keeps FixBranches until step 7 takes its buffer away.

## DONE AND VERIFIED (steps 1-6c)

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
6a. **One byte of block depth per line**, bank 5, at the SAME address as the line record so there
   is no arithmetic between them. `STRMarkLine` writes it, `STRFindLine` remembers which record
   matched and `STRLineDepth` reads it back. Do NOT widen the 4-byte line record instead: 5 bytes
   an entry drops the cap from 2,048 lines to 1,638.
6b. **`.unwind` at emit**, from that table. `CommandGOTO` reads the target line BEFORE writing
   anything, because the `.unwind` goes in front of the GOTO.
6c. **GOTO / GOSUB / .gotoz / .gotonz / RESTORE / .fngosub at emit**, through `WriteBranchTo` and
   `WriteBranchToAddress` in `commands/goto.asm`. The offset is measured from the OPCODE, so
   nothing is written until it is worked out. Five more emitters had to join them: `CompileGotoEOL`
   (a false IF), bare `RESTORE`, the FN call, the compiler's own two GOTOs into and out of the
   implicit-DIM prologue, and `_RSBridge` -- the GP.BANKED entry and exit bridges, which pass two
   writes itself.

## Traps that cost a cycle each

- **`STRMarkLine` is called with the line number still in YA.** The `RegionSwitch` hook sits in
  front of it in the main loop (it must, a region begins ON the GP.BANKED line's marker byte) and
  so has to be register-transparent. It was not: every banked program failed
  `UNKNOWN LINE NUMBER @ 3`.
- **`GPBankStructure` goes out of branch range easily.** `CommandGPBankedCompile` is long and
  branches to it; anything inserted between pushes it away. The pass-two halves live BELOW it, as
  globals -- 64tass scopes a `_` label to the enclosing global. Same trap bit `_STRFoundAt`, which
  had to become the global `STRFoundAt`.
- **`GPBankMakeOffset` corrupts X.** `RegionSwitchWork` holds the region number in X across the
  bridge, and the bridge resolves itself now, so it needs a `phx`/`plx`.
- **An address recorded before the move must fall strictly INSIDE its section.** `GPBankAdjust`
  puts the byte at `gpBankEnd` on the LOW side, and "one past the last GP.LOOP of a region" is
  exactly that byte. So the block-end table stores the GP.LOOP's own address and the reader adds
  one back.

## STILL TO DO

6d. **The structural forward branches**, and then `FixBranches` is pass one's alone.
   Each block gets an ORDINAL as it opens (both passes number them the same way, being the same
   source in the same order) and pass one writes down where it ended under that ordinal, in bank
   6 -- `BlockEndTable $A000`, `BlockAltTable $B000`, 2,048 entries of 2 bytes each. NOT indexed
   by nesting depth: two sibling loops share a depth and the second would overwrite an answer the
   first still needs. Every entry is fixed up by `_GBFixBlockEnds` when a region moves, exactly as
   the line table is.
   - **6d-1 `.exitdo`** -- WRITTEN, not yet built or tested. `BlockDepthUp` hands out the ordinal,
     `BlockDepthDown` records the end, `BlockEnclosingDo` reads it back.
   - **6d-2 `.ifnext` / `.ifelse`** -- `.ifelse` goes to `structEnd[the open GP.IF]`; `.ifnext`
     gets an ALTERNATIVE ordinal and its target is recorded by whatever alternative comes next
     (GP.ELSEIF, GP.ELSE or GP.ENDIF). One pending alternative per open IF, no chains.
   - **6d-3 `.casenext` / `.caseend`** -- the same shape, with GP.CASE / GP.OTHER / GP.ENDSEL.
     `SelectDepth` is already the compile-time stack.
7. **Stream pass two to the file.** Both files are open at once, so buffer a page -- `object.asm`
   already measures it: 28,000 CHKIN/CHKOUT pairs per byte against 94 per page. Three things it
   has to deal with:
   - the alignment gaps between regions must be FILLED then; today pass two lands on pass one's
     addresses in the same buffer, so the gaps still hold pass one's bytes;
   - `AsmPatchAll` (`commands/gpasmcode.asm`) patches the buffer AFTER `WriteObjectCode` has
     settled `newWorkspacePage` -- real back-patching, and the last of it;
   - pass one loses its buffer too, or the wall stays -- so FixBranches goes, and the checksum
     cannot walk an object any more. It has to become a WRITE-TIME sum, and the write order
     differs between the passes: one accumulator for low code and one for the regions, switched
     where `RegionSwitch` already switches, keeps each one's order identical in both passes.

**Measured cost: 2.19x** at step 5 (PICKDEMO 3.54 s -> 7.75 s, warp, best of 3). Pass one now
runs FixBranches too, so it is worse than that today and comes back as each kind moves.
`FreeMemory` has gone `$5200 -> $5500`; irrelevant, the buffer goes away at step 7.

**GPBMODS still fails `PROGRAM TOO BIG` -- on the compiler at `3335ab5` too.** It has never
compiled on this branch's baseline; only step 7 fixes it.

**Test programs added:** `testing/UNWIND.BASL` (GOTO out of one, two and three nested GP.DO
blocks, forwards, backwards and at the same depth) and `testing/BANKZ.BASL` (GP.DO, GP.IF and
GP.SELECT INSIDE a GP.BANKED region, with the GP.LOOP deliberately the last statement in it --
the boundary case above). Nothing in the suite covered either before.

Related: [[compiler-must-not-cap-program-size]], [[gp-banked-region-relocation]],
[[baseline-compiler-is-the-application-copy]], [[measure-before-changing-code]].
