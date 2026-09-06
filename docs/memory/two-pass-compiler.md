---
name: two-pass-compiler
description: "Rebuilding GPC to compile the source twice and stream p-code straight to disk, so the object buffer stops capping program size. Branch two-pass-compiler; the checksum invariant is the safety net; regions/FixBranches/streaming are coupled and must move together."
metadata: 
  node_type: memory
  type: project
  originSessionId: 75714395-f705-4d27-8da6-af4a832a1e0b
  modified: 2026-09-06T03:10:04.704Z
---

**Started 2026-09-06 on branch `two-pass-compiler`, off `3335ab5`.** Chosen by the user over
shaving compiler bytes and over [[compiler-overlay-into-a-bank]], both of which only move the
wall. Rests on [[compile-is-write-only]].

**The problem.** `FreeMemory` is `.align 256` after the compiler's last byte and the object
buffer runs from there to `ObjectCeiling $9F00`, so every compiler byte comes 1:1 off the
largest compilable program, and a page crossing costs 256 bytes of user program. Worse now that
a program may have **eight** GP.BANKED regions: a maximal object is 15,616 low + 8 x 8,192 =
81,152 bytes, and low RAM below `$9F00` is only 39,679 in total. **No amount of overlaying
compiler code into banks can ever reach that** -- which is the real argument for two passes, not
that the overlay attempt broke.

**The shape.** Pass one compiles the whole source to answer what a forward pass cannot -- line
addresses, variable space, block branch targets. Pass two compiles the same source again knowing
all of it, and emits final bytes with nothing to go back and patch, so it can stream to the file
through a page buffer.

## THE INVARIANT, and it is the whole safety net

The two passes must emit identical bytes and nothing structural enforces it. So `WriteCodeByte`
(`compiler/source/helpers/api.asm`) accumulates a **Fletcher-16 over every byte**, and the tail
of pass two compares sum, length and variable space against pass one's before anything is
written. A mismatch raises `.error_internal` and writes no object. `ResetPassState`
(`main/compiler.asm`) is what puts the state back between passes -- **anything missing from it
shows up as a checksum mismatch on the first program that touches it**, which is the point.

`WriteCodeResolved` is the escape hatch: same emit, but the byte is left out of the sum. Only for
operands whose value legitimately differs between passes. The slot is still counted, so the
length check still covers it and both passes skip the same slots.

## Two things the plan got wrong, found while building

1. **The deferred-statement rollback is not a problem.** `errorhandler.asm` rewinds `objPtr` over
   a failed statement, and a file cannot be rewound -- but pass one already knows which statements
   defer, so pass two can emit the stub without compiling them. No statement window, no size
   bound to measure.
2. **Regions, FixBranches and streaming are one change, not three.** Branch resolution at emit
   needs final addresses; addresses are not final until the region layout is; the layout is
   decided by `GPBankRelocate`, which today runs *after* the compile. The keystone that decouples
   them is a **run-address cursor** (`codePos`) distinct from the write cursor (`objPtr`): a
   region's run addresses start at `$A000` and are known the moment `GP.BANKED n` opens, with no
   lookahead. That makes `gpBankCrossings` zero by construction -- it holds exactly
   `$A0 - <region's buffer page>` (`gpbank.asm:712`) -- and collapses `GPBankMakeOffset`,
   `GPBankHop` and most of the relocator.

## Order that actually works

1. Two-pass driver + checksum. **Done** -- PICKDEMO byte-identical (`d242798f2efb4f67cd4d2ec8e5f33f80`).
2. `_variable.space` resolved at emit; its FixBranches handler deleted. (First use of `WriteCodeResolved`.)
3. `codePos` -- the keystone above.
4. Structural forward branches into two ordinal-indexed tables in a bank: `blockEnd[]` by block
   ordinal, `altNext[]` by alternative ordinal. No chains needed -- several `.exitdo`s in one loop
   all read the same `blockEnd` entry.
5. `.unwind`: one byte of block depth per line, parallel to the line table (its own bank; do NOT
   widen the 4-byte line record, that would drop the cap from 2,048 lines to 1,638).
6. Stream pass two to the file. **Both files are open at once, so buffer a page** --
   `object.asm` already measures the cost: 28,000 CHKIN/CHKOUT pairs per byte against 94 per page.

Note the driver cost `FreeMemory` another page (`$5200 -> $5300`); irrelevant, it goes away at
step 6.

Related: [[compiler-must-not-cap-program-size]], [[gp-banked-region-relocation]],
[[program-too-big-fires-early]], [[measure-before-changing-code]].
