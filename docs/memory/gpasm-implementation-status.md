---
name: gpasm-implementation-status
description: GP.ASM inline assembler being implemented on branch feature/gp-asm; what works, what does not, and the numbers
metadata:
  node_type: memory
  type: project
---

**Branch `feature/gp-asm`, started 2026-08-30** off main at `664ac20`; first commit
`ef7dc6e`. Research is
[[gpasm-inline-assembly-research]]; this is the build.

**Working and verified in x16emu**, program compiles and the assembly runs:

```
GP.ASM / REM LDA #65 / REM JSR $FFD2 / GP.ENDASM   ->  prints A
OK CODE 59 FREE 22272 RT 12031 GP OUT
```

`GP OUT` and `RT 12031` are the whole point: the lowering is `.word <addr>` +
`.shift sys` (5 bytes), every handler below `GPBase`, so **an ASM-only program
pays nothing for the 2 KB GP block**. Blobs are pooled after the `$FF` end
marker, so no length byte and no 127-byte cap.

**Labels, branches and `{VAR}` all built** (commit `b20f38f`). Verified host-tokenised:
`LDA {A%}` / `STA {B%}` with a backward BNE, a forward BEQ and a JMP to a
label prints `S A ... Z E 66`.

**`{VAR}` UNDER BASLOAD WORKS, via `#SYMFILE`** (commit `ed73ecb`). BASLOAD
crunches `N%` to `A%` in the code and keeps REM text byte for byte, so the name
in the braces is not the name the code uses; `#SYMFILE` is BASLOAD's own record
of the mapping and the compiler reads it (`BLC_SYMLOOKUP`, and
`source/application/source/compiler/symfile.asm`). The source needs
`#SYMFILE "@:PROG.SYM"` at the top, named to match the PRG.

**Two traps that cost a test cycle each.** The sym file does NOT record the
sigil — `PR$` is filed as `PR` — so one entry serves `N`, `N$` and `N%` and the
compiler re-attaches the type. And **CMDR-DOS opens a missing file happily**,
reporting it only on the first read, so "no symbol file" and "empty symbol file"
are indistinguishable at OPEN; detect a missing one by its `BASLOAD` banner
line, not by the open's carry. The same is true of any file the compiler opens.

**Trap that cost a test cycle:** `ExtractVariableName` wants the first character
ALREADY CONSUMED in A (`GetNextNonSpace`, not `LookNextNonSpace`). Get it wrong
and `{A%}` parses as the name `AA%` and silently creates a second variable.

**The gotcha that cost a build:** `FreeMemory` is an APPLICATION symbol, and
`source/compiler/` is also built standalone against only common+ifloat32 — so
compiler-library code cannot name it. Fixups therefore store **absolute buffer
addresses**, and `AsmPatchBlobs` takes a one-byte **page delta** that object.asm
computes (`runtimeEndPage - FreeMemory>>8`, or `PCODE_PAGE - FreeMemory>>8`).

**The blob pool and fixup list live in RAM BANK 3** (`$A000-$BFFF`), through
`asm_access`/`asm_release` in `system-specific/x16/x16_storage.inc` — the same
route the compiler's name/line tables took to bank 2, and the bank allocation
list in that header is the one place it is written down. Low RAM is not free:
`FreeMemory` is page aligned right after the compiler, so every compiler byte
comes one-for-one off the object buffer, i.e. off max program size. Banking the
pool took the buffer 12,800 -> 13,824, but the label/{VAR} CODE is low RAM and
put it back: `FreeMemory` is `$6D00` again and raised the per-program assembly cap
1,024 -> **8,064**.

**The opcode tables (626 B) did NOT move and cannot cheaply**: `build.py` sweeps
`gpasmtable.asm` into `compiler.library`, which links BEFORE `zzfree.footer`
where `FreeMemory` is declared, so the init-overlay (stage above FreeMemory, copy
to bank, let the object buffer overwrite it) would mean splitting the table out of
the compiler library. Recorded in `TODO.md`, "Growing the object buffer".

**The buffer used to bind before the run side did, and no longer does.** On
2026-08-30, branch `feature/object-buffer` took `FreeMemory` `$6D00` -> `$4400`
and the buffer 12,800 -> **23,296** by moving the runtime image out of low RAM
into `GPC.IMG.nnn.BIN`. Every run-side ceiling (18,432 embedded GP OUT down to
15,616 shared GP IN) is now below it, so GP.ASM's 2,827 bytes of compiler no
longer cost anyone program size. See [[gpc-blitz-runtime-slack-and-limits]].

Error text `structure imbalance` was renamed **`block mismatch`** at the user's
choice (errors.py) — it is shared with GP.IF/GP.SELECT/GP.EXITDO, and lives below
`GPBase`, so its length is runtime bytes in every program.

Opcode table is generated: `source/compiler/scripts/genasm.py` ->
`source/compiler/source/generated/gpasmtable.asm`, wired into the Makefile
`prelim` target. 66 mnemonics, 180 entries. BBR/BBS/RMB/SMB deliberately omitted.

**`{VAR}` NOW TAKES DOTTED NAMES (2026-08-30).** `AsmParseBrace`'s scanner was letters and digits
only, so `{DOC.GOT.OFF}` read the name as `DOC`, missed, and reported `UNKNOWN VARIABLE IN {}` —
true, but with nothing pointing at the dot. Dotted names are the house style exactly because they
dodge BASLOAD's keyword trap, so this made `{VAR}` unreachable from most real BASL code. Fixed by
taking `.` as a name character in `_APBNameChar`: **4 bytes of compiler, zero runtime bytes, and
`FreeMemory` did not move** (it came out of alignment padding). Underscore is still out — BASLOAD
allows it, but what byte it arrives as through PETSCII was never measured, and guessing would
quietly swallow some other character into a name.

**First real user, and the numbers are much better than the research predicted.**
`samples/editor/` renders with two `GP.ASM` blocks. Measured with both versions in one program
(`samples/editor/EDBENCH.BASL`, real speed, loop floor subtracted, cells VPEEK'd back and blanked
between variants), jiffies per 1000 renders of an 80-cell row: text row **2320 -> 18.8** (123x,
~31 cycles/cell), chrome field **2538 -> 23.3** (109x). That is past prog8's real MSEDIT loop (67)
and within 1.4x of the hand-assembled raw-write floor (13). **The p-code got SMALLER** — 7190 ->
7101 bytes — because the `FOR` loops removed were bigger than the ~250 bytes of assembly, and the
program is still `GP OUT`.

**Two idioms worth reusing, both proven in a probe before the real code was written.** There is no
expression syntax, so a computed address goes INTO the operand of the instruction that reads it:
`STA LBL,X` with `X=1` patches the low byte and `X=2` the high, `LBL: LDA $FFFF,Y` reads through it,
and forward label references resolve. And a `%` variable holds a 16-bit address **verbatim, above
32767** — 40960 stores as `$00,$A0` — so no two's-complement trick is needed to pass VERA or
banked-RAM addresses. A string is reached by dereferencing: `{A$}` is the SLOT, the slot holds the
block, `block+2` is the length and `block+3` the text.

**Headless harness trap, cost a cycle.** Do NOT wait for the compiler by polling the object file's
size for stability — it is written in bursts with pauses, and a 3,781-byte fragment sat still long
enough to look finished. Wait on the `-echo` stream instead (the third `READY.`). Note `bench/loop/
run-loop-profile.py` uses the size-settle approach and has the same latent bug.


**The assembler's table limits were raised on 1st September 2026**, in `gpasmcode.asm`:
`ASM_MAX_LABELS` 16 -> **32**, `ASM_MAX_LOCALS` 32 -> **64**, `ASM_MAX_FIXUPS` 96 -> **128**. Those
are the *architectural* maxima and cannot go higher without widening an index — every subscript is
count, count*2, count*4 or count*8 held in X, so labels cap at 31 stored, locals at 63, fixups at
127. Sixteen labels was never a considered figure; it was enough for `samples/editor`'s two
straight-line renderers and no more, and `SORT.INC.BL` — 25 labels, 31 references — failed to
assemble with `OUT OF MEMORY` on the first try. **The 416 bytes came off the blob pool: total inline
assembly per program is 7,040 now, not 8,064.** That is the right trade; the pool has never been
close to full and the label cap was hit by the first routine with a subroutine in it.

**And zero page IS available inside a blob** — see [[gpasm-blob-may-use-ztemp]], which the sort
proved. That changes what is worth writing in `GP.ASM`: pointer-walking code no longer needs the
self-patching idiom.

**`{VAR}` NEEDS A SLOT THE COMPILER HAS ALREADY MADE (found 2026-09-02).** The name being in the
`#SYMFILE` is not enough: a variable whose first assignment is further DOWN the file than the
`GP.ASM` block referencing it fails at compile time with `UNKNOWN VARIABLE IN {} @ <line>` -- and
the compiler then reports a secondary `?STRING TOO LONG ERROR`, which is fallout, not the cause.
Assign it once, textually above the block (an init routine is the natural home).

Two more from the same day, both in `samples/editor/STORE.BASL` and `EDITOR.BASL`: a
count-down loop (`LDY {LEN%}` ... `DEY` / `BNE`) leaves offset 0 -- a Blitz string's length byte --
untouched for free, and MUST be guarded against a zero length in BASIC before the `GOSUB`, or `DEY`
wraps and rewrites 255 bytes of somebody else's heap. Copy-and-translate in ONE pass (read, fold,
store) is the shape that pays: see [[gpc-string-blocks-never-shrink]].
