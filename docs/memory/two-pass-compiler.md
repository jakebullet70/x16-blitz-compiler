---
name: two-pass-compiler
description: "Rebuilding GPC to compile the source twice and write p-code straight to disk, so the compiler's own size stops capping program size. Branch two-pass-compiler; steps 1-7 done -- neither pass stores an object, GPBMODS compiles, and what bounds a program is now whether it can RUN."
metadata: 
  node_type: memory
  type: project
  originSessionId: 75714395-f705-4d27-8da6-af4a832a1e0b
  modified: 2026-09-06T00:00:00.000Z
---

**Branch `two-pass-compiler`, off `3335ab5`, started 2026-09-06.** Chosen by the user over shaving
compiler bytes and over [[compiler-overlay-into-a-bank]], both of which only move the wall. Rests
on [[compile-is-write-only]].

**The problem, and it is gone.** `FreeMemory` was `.align 256` after the compiler's last byte and
the object buffer ran from there to `ObjectCeiling $9F00`, so every compiler byte came 1:1 off the
largest compilable program. With **eight** GP.BANKED regions a maximal object is 15,616 low +
8 x 8,192 = 81,152 bytes against 39,679 of low RAM in total, so no amount of overlaying compiler
code into banks could ever have reached it.

**Neither pass stores an object now.** Pass one only COUNTS -- it works out where every line,
block and region lands and how long the whole thing is. Pass two writes the answer straight into
OBJECT.PRG as it compiles. `samples/GPB-MODS-TESTING/GPBMODS.BASL` compiles: **OK CODE 19730 FREE
5888**, against a compile-side wall that stood at 19,712.

## WHAT BOUNDS A PROGRAM NOW

Not the compiler. `PrepareObjectCode` asks, at the end of pass one, whether the thing can RUN --
p-code base page + pages + the 4K frame stack gap, against the runtime's base less `MIN_WS_PAGES`.
Shared mode: **15,360 bytes** of low p-code with the GPB handlers, 17,664 without, PLUS up to
8 x 8,192 in banks -- so a maximal object is about 80,896. Embedded: 17,152 / 18,176 and no
regions. The other two limits are the line table (2,048 lines) and the variable list (1,365).

## THE INVARIANT, and how it changed

It was `ObjectChecksum`: a Fletcher-16 over the object each pass laid out, compared at the end.
Both passes laying a FINISHED object out is what let the resolving move into pass two's emitter
one branch kind at a time -- pass one still answered the old way, and a disagreement was
`.error_internal` here rather than a wrong program. Six branch kinds moved over five commits and
not one needed a debugging session.

There is no object to sum now, so what the two passes still both produce is checked instead, each
where it is read:

- **every line's address** -- `STRMarkLine` compares rather than overwrites (storage/mark_line.asm)
- **every block end and alternative** -- `BlockEndCheck` (commands/goto.asm)
- **the GP.ASM pool's base** -- `AsmFlushPool` (commands/gpasmcode.asm)
- **the sum of every byte the GENERATORS emit**, in `WriteCodeByte`. That stream IS identical in
  both passes except where pass two writes an answer pass one could not know, and those are
  counted out in `sumSkip`: a branch's two operand bytes, an `.unwind`'s count, a blob's address,
  the variable space, the GP.ASM pool, and the GP.BANKED bookkeeping. **Every placeholder writer
  has to skip too** -- exitdo.asm, gpif.asm and select.asm each write two bytes pass one cannot
  fill in, and forgetting them is an INTERNAL ERROR on every program with a block in it.
- **the length and the variable space**, at the tail of `SaveCodeAndExit`.

## HOW PASS TWO WRITES

- **The object file is opened between the passes**, by `PrepareObjectCode` -> `ObjStreamOpen`, and
  the runtime image (or the bootstrap and its extension page) goes into it there. It is open
  across the whole of pass two, so it needs a logical file of its own: **3 source, 4 runtime
  image, 5 symbol file, 6 object.**
- **SELECTING ONE DIRECTION TAKES THE OTHER WITH IT.** CHKIN and CHKOUT are not independent here:
  after the object file is selected for output the source is no longer selected for input, and a
  read that assumed it still was simply STOPPED -- no error, no end of file, indistinguishable
  from the compiler hanging. That is what GPBMODS did at line 1573, one buffer-flush in. Each of
  `IOSelectSource` / `IOSelectObject` now forgets what the other knew.
- **The low code is buffered 8K in bank 7**, because a statement that fails to compile is rolled
  back and a throw-stub put in its place -- bytes already in a file cannot be taken back. Nothing
  goes out until the statement that wrote it has compiled (`objHold`). **Only for statements that
  begin in the LOW buffer**: a region is random access, so a rollback there is written over, and
  holding a REGION address as the low buffer's mark makes the flush length a subtraction of two
  unrelated addresses.
- **Each GP.BANKED region gets a bank of its own, 8 upwards.** A region is written to its final
  address, which is ABOVE the low code still being emitted, so the two cannot share one
  forward-only stream. At most 8 regions of at most 8K each, so it fits exactly.
- **The object still leaves in file order**: low code and the GP.ASM pool as they are compiled,
  then the alignment padding, then each region out of its bank.
- **A compile that stops takes the object with it** (`ObjStreamAbort` from `_CCStopped`). The file
  exists from the end of pass one, so a failure would otherwise leave a truncated one -- which at
  the filesystem level is indistinguishable from a program.

## WHAT WENT, AND WHAT REPLACED IT

- `FixBranches` -- pass two resolves every branch where it writes it, out of pass one's tables.
- `ScanGPUsage`'s walk -- `GPScanByte` decodes the p-code FORWARDS as pass one emits it, same
  bitmap and same instruction sizes. The cursor is checked, not assumed: a rolled-back statement
  restarts the decoder at an instruction boundary, which needs nothing to tell it.
- `GPBankRelocate`'s rotation, `_GBShiftUp`, `_GBReverse`, `_GBWriteGoto`, `_GBRFindLowEnd`,
  `GPBankHop`, `gpBankHops`, `_GBFixFnCalls`, `_GBFixAsmCalls` -- all of it walked or moved bytes.
  What is left of the relocator is the arithmetic.
- `AFIX_CALL` -- pass two knows the pool base and the run page by the time it writes a blob call,
  so it writes the address. The pool's own fixups are resolved IN THE BANK, immediately before
  `AsmFlushPool` copies it out, because after that it is out of reach.
- **An unclosed block** was found by FixBranches running off the end. `SaveCodeAndExit` asks
  `blockDepth | ifDepth | SelectDepth` instead -- a compare, not a walk.
- **"GP.BANKED alone on its line"** read the byte at objPtr-1. It compares objPtr-1 against
  `lineMarkerAt` now.

## Traps that cost a cycle each

- **`STRMarkLine` is called with the line number still in YA**, and anything hooked in front of or
  inside it has to hand A and Y back. Cost `UNKNOWN LINE NUMBER @ 3` once and a wrong line record
  once.
- **`IOSelectScreen` does not preserve X**, and `_CAPrintScreen` keeps the character to print
  there. CLRCHN clobbers it.
- **BRANCH RANGE, six times.** Every step put 150+ bytes between a test and the `.error_*` exit it
  branched to. Move the error exits ABOVE the new routines, or reach them with a `jmp`.
- **64tass scopes a `_` label to the enclosing GLOBAL label.** Splitting one routine into two puts
  half the branches on the wrong side of the new name: `WriteObjectCode` becoming
  `PrepareObjectCode` + `WriteObjectCode` made six labels globals.
- **`GPBankMakeOffset` corrupts X**, and `RegionSwitchWork` holds the region number there.
- **An address recorded before the move must fall strictly INSIDE its section.** The block tables
  store one SHORT of the answer and every reader adds it back. `testing/BANKZ.BASL` is that case.
- **A `.def` helper MUST return carry clear**, or the generator silently drops every token after it.
- **The alignment padding is $FF now.** Nothing writes or reads it, and there is no buffer left
  holding what the rotation used to leave there.

## Verification

**A stored reference set beats the internal checksum**: `chk.py ref` compiles thirteen programs
and keeps the objects; `chk.py chk` compiles them again and diffs. Byte for byte identical through
every step of 7, GPBMODS added to it afterwards. The bank suite (`banktest3.py`) is the behaviour
test and `sweep.py` compiles everything in `testing/`.

**x16emu's `-echo` catches every CHROUT, and the object file is written through CHROUT**, so the
p-code goes into the log too and "ERROR" turns up inside string literals. Stop on `READY.` AFTER
`OUT:`, not on a word in the text.

**Measured cost: 2.08x** at step 6 (PICKDEMO 3.55 s -> 7.37 s, warp, best of 3). Pass one still
parses everything and will always cost about what pass two does, so 2x is the standing price.

**Test programs added:** `testing/UNWIND.BASL` (GOTO out of one, two and three nested GP.DO
blocks), `testing/BLOCKS.BASL` (every arm of a four-way IF chain and a SELECT) and
`testing/BANKZ.BASL` (all three block kinds INSIDE a GP.BANKED region). Nothing covered any of it
before.

**Still open:** the `gp.if` / `gp.select` / `gp.case` / `gp.endsel` MARKER tokens are emitted into
every program and nothing reads them any more -- the resolver that walked them is gone. Removing
them is a byte off every block keyword and its own verification job.

Related: [[compiler-must-not-cap-program-size]], [[gp-banked-region-relocation]],
[[measure-before-changing-code]], [[write-readable-code-user-crunches]],
[[baseline-compiler-is-the-application-copy]].
