---
name: two-pass-compiler
description: "Rebuilding GPC to compile the source twice and stream p-code to disk, so the object buffer stops capping program size. Branch two-pass-compiler; step 6 done, so pass two resolves every branch where it writes it and FixBranches is pass one's alone. Step 7 is what makes GPBMODS compile."
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
**no amount of overlaying compiler code into banks can ever reach it.**

## THE INVARIANT, and why it is what made every step safe

`ObjectChecksum` Fletcher-16s the object each pass has laid out; the tail of pass two compares
sum, length and variable space, and a mismatch is `.error_internal` with no object written. It
sums the **finished object, not the stream of writes** -- the write order legitimately differs
once pass two places regions directly. It skips the first three bytes, `_variable.space` and its
operand, the one place the two objects are meant to differ.

**BOTH PASSES RESOLVE.** FixBranches runs at the end of pass ONE, so the checksum compares two
FINISHED objects. That turned it from a consistency check into a **differential test of the new
resolver against the old one**: every branch kind that moved into pass two's emitter was checked
against the answer FixBranches used to get for it, on every program compiled. Six kinds moved over
five commits and not one needed a debugging session. Pass one keeps FixBranches until step 7 takes
its buffer away.

## DONE AND VERIFIED (steps 1-6)

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
6. **Everything resolved at emit**, in this order, because `.unwind` reads the FOLLOWING GOTO's
   operand as a line number and breaks the moment that GOTO is resolved:
   - **6a** one byte of **block depth per line**, bank 5, at the SAME address as the line record
     so there is no arithmetic between them. `STRMarkLine` writes it, `STRFindLine` remembers
     which record matched and `STRLineDepth` reads it back. Do NOT widen the 4-byte line record:
     5 bytes an entry drops the cap from 2,048 lines to 1,638.
   - **6b** `.unwind` from that table. `CommandGOTO` reads the target line BEFORE writing
     anything, because the `.unwind` goes in front of the GOTO.
   - **6c** GOTO / GOSUB / `.gotoz` / `.gotonz` / RESTORE / `.fngosub`, through `WriteBranchTo`
     and `WriteBranchToAddress` in `commands/goto.asm`. **The line table needed no change**:
     `STRReset` resets the POINTER, not the banked data, so through pass two the lines not yet
     re-marked still hold pass one's final addresses and the re-marked ones hold identical values.
     Five more emitters had to join them and finding them was most of the work -- `CompileGotoEOL`
     (a false IF), bare `RESTORE`, the FN call, the compiler's own two GOTOs into and out of the
     implicit-DIM prologue, and `_RSBridge`, the GP.BANKED bridges pass two writes itself.
   - **6d** the structural branches: `.exitdo`, then `.ifnext`/`.ifelse`, then
     `.casenext`/`.caseend`. **Each block takes an ORDINAL as it opens** and pass one writes down
     where it ended under that ordinal, in bank 6 -- `BlockEndTable $A000`, `BlockAltTable $B000`,
     2,048 entries of 2 bytes each. NOT indexed by nesting depth: two sibling loops share a depth
     and the second would overwrite an answer the first still needs. `_GBFixBlockEnds` /
     `_GBFixBlockAlts` walk both tables when a region moves, exactly as the line table is walked.
     `blockDepth`, `ifDepth` and `SelectDepth` are the three stacks of open blocks.

**PASS TWO NEVER CALLS FixBranches NOW.** That is what step 7 needs: an object that is final on
the way out can go straight to the file.

## Traps that cost a cycle each

- **`STRMarkLine` is called with the line number still in YA.** The `RegionSwitch` hook sits in
  front of it in the main loop (it must, a region begins ON the GP.BANKED line's marker byte) and
  so has to be register-transparent. It was not: every banked program failed
  `UNKNOWN LINE NUMBER @ 3`.
- **BRANCH RANGE, four times.** Every one of these steps put 150+ bytes of table plumbing between
  a test and the `.error_*` exit it branches to. The fix each time is to move the error exits ABOVE
  the new routines (`gpif.asm`, `goto.asm`) or to reach them with a `jmp` (`select.asm`, which
  already had three). `GPBankStructure` had the same trouble in step 5.
- **64tass scopes a `_` label to the enclosing GLOBAL label.** `_STRFoundAt` had to become
  `STRFoundAt`; the GP.BANKED pass-two halves had to become globals too.
- **`GPBankMakeOffset` corrupts X.** `RegionSwitchWork` holds the region number in X across the
  bridge, and the bridge resolves itself now, so it needs a `phx`/`plx`.
- **An address recorded before the move must fall strictly INSIDE its section.** `GPBankAdjust`
  puts the byte at `gpBankEnd` on the LOW side, and "one past the last GP.LOOP of a region" is
  exactly that byte. So the block tables store one SHORT of the answer and every reader adds it
  back. `testing/BANKZ.BASL` is that case, and it runs.
- **A `.def` helper MUST return carry clear.** Every pass-two path that ends in
  `WriteBranchToAddress` needs an explicit `clc` before its `rts`.

## STILL TO DO -- step 7, and it is the one that matters

**Stream pass two to the file.** Both files are open at once, so buffer a page -- `object.asm`
already measures it: 28,000 CHKIN/CHKOUT pairs per byte against 94 per page. Four things:
- **Pass one loses its buffer too, or the wall stays.** So FixBranches goes with it, and the
  checksum cannot walk an object any more. It has to become a WRITE-TIME sum, and the two passes
  write in different orders: one accumulator for low code and one for the regions, switched where
  `RegionSwitch` already switches, keeps each one's order identical in both passes.
- The **alignment gaps** between regions must be FILLED; today pass two lands on pass one's
  addresses in the same buffer, so the gaps still hold pass one's bytes.
- `AsmPatchAll` (`commands/gpasmcode.asm`) patches the buffer AFTER `WriteObjectCode` has settled
  `newWorkspacePage` -- the last real back-patching in the compiler.
- Move `PROGRAM TOO BIG` to the end of pass one as a run-side test, so a rejected compile writes
  nothing.

**GPBMODS still fails `PROGRAM TOO BIG` -- on the compiler at `3335ab5` too.** It has never
compiled on this branch's baseline. The line it dies on has crept 1,889 -> 1,813 as the compiler
grew through step 6, which is the wall doing exactly what it does. Only step 7 fixes it.
`FreeMemory` has gone `$5200 -> $5A00` along the way; irrelevant, the buffer goes away.

**Test programs added:** `testing/UNWIND.BASL` (GOTO out of one, two and three nested GP.DO
blocks, forwards, backwards and at the same depth), `testing/BLOCKS.BASL` (every arm of a four-way
IF chain and a SELECT, including the values that fall through to GP.ELSE and GP.OTHER, plus both
nestings) and `testing/BANKZ.BASL` (all three block kinds INSIDE a GP.BANKED region, with the
GP.LOOP deliberately its last statement). Nothing in the suite covered any of it before.

**The build harnesses live in the session scratchpad**, not the repo: `objdiff.py` (compile with
both compilers and list the differing bytes), `sweep.py` (every `testing/*.BASL`, flagging
`INTERNAL ERROR`), `run1.py` (compile one and run it), `banktest3.py`, `timeit.py`. All of them
A/B against `git show 3335ab5:source/application/GPC.BIN` -- see
[[baseline-compiler-is-the-application-copy]].

Related: [[compiler-must-not-cap-program-size]], [[gp-banked-region-relocation]],
[[measure-before-changing-code]], [[write-readable-code-user-crunches]].
