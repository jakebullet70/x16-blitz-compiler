---
name: run-side-workspace-read-from-the-prg
description: "A shared program's whole run-side budget is readable out of its built .PRG -- workspace pages from the bootstrap, scalar bytes from the first .varspace opcode -- and a run-time OUT OF MEMORY names where the last temporary was asked for, not where the memory went"
metadata:
  node_type: memory
  type: project
---

**Three numbers, no emulator, no source.** Given only `NAME.PRG` compiled SHARED:

- **The workspace's two page numbers** are operands in the bootstrap. `BBBasePage`
  (`source/application/source/compiler/bootstrap.asm`) is `lda #PCODE_PAGE` / `ldx BBWSStart` /
  `ldy BBWSEnd` / `jmp`, so scan the first ~600 bytes for `A9 ?? AE lo hi AC lo hi 4C`, follow the
  two absolute operands back into the file, and read the bytes they point at. `$54`/`$66` means
  the workspace is `$5400`..`$6600`. The end is `RTBASE>>8` for a program using no GPB keyword and
  `RTGPBASE>>8` for one that does -- 2,560 bytes of difference.
- **Scalar bytes** are the operand of the FIRST p-code opcode, `.varspace` = `$E7`, emitted at the
  top of the object by `CompilePass` (`compiler/main/compiler.asm`). Find the first `$E7` after the
  bootstrap; the two bytes after it are the total.
- **What is left** is arrays plus the entire string heap. A string or `%` array element is **2**
  bytes, a float one 6, plus 3 bytes a level.

Measured on GPBMODS 2026-09-08: `$5400`..`$6600` = 4,608 bytes, `.varspace $08EA` = 2,282, four
string arrays ~154 -- about **2,170 for every string the program holds at once**.

## A run-time OUT OF MEMORY names the messenger

`FILES / DIR OPEN` reported `OUT OF MEMORY @ $056B`, which `GPBMODS.MAP` places inside
`STR.PADR` -- a two-line pad that cannot itself be the problem. `StringInitialise`
(`runtime/strings/stralloc.asm`) refuses as soon as `availableMemory` is within **2 pages** of
`stringHighMemory`, and it only runs when something allocates a **temporary** (`STR$`, `CHR$`,
`RPT$`, concatenation). So the report lands on the next routine to build a temporary, wherever the
heap actually went. Assignment has its own test in `StringConcrete` and a different message path.

**Where it went here:** twenty-four listbox rows of ~38 characters. A concrete block is
`length x 1.5 + 3` and is **never freed**, only flagged dead and re-fitted, so the rows alone want
~1,440 bytes of a 1,660-byte usable heap. See [[gpc-string-blocks-never-shrink]] and
[[string-heap-scavenger]].

## The frame stack was the fix, and it was not this program's fault

`FrameStackPages` (`source/common-source/source/common.inc`) reserved **16 pages, 4K**, between
the p-code and the workspace -- set when a program was small and its workspace was most of the
machine, and by 2026-09-08 nearly as big as the whole workspace it sat under. **It is 8 now**, and
every shared program gets 2,048 bytes back; GPBMODS went 4,608 -> 6,656. Two kilobytes is still
~125 `GOSUB` frames (4 bytes) or ~107 `FOR` frames (19, the largest), and overflow is loud either
way -- `StackOpenFrame` tests `stackFloorHigh` and reports `OUT OF MEMORY`, which is what stock
BASIC says for too many nested GOSUBs.

**Both ends read that constant**, so it needs `make libs` AND `make -C source/runtime gpc-rt`, and
every program must be recompiled -- a stale object gets a floor that is not where its gap is. In
practice the build number pins each program to its own runtime file, so a mismatch cannot load.

**The program's own half came next, and it is the bigger lever.** A second `GP.BANKED` region took
eight more modules out of low RAM, and GPBMODS ended the day at 14,001 resident with a
`$4800`..`$6600` workspace -- **while gaining two modules and three panels**. See
[[second-region-for-the-utilities]]: what disqualifies a module from a region is a `BANK`
statement and nothing else.

Related: [[gpc-blitz-runtime-slack-and-limits]], [[blitz-arrays-share-the-workspace]],
[[gpc-shared-pcode-cap-is-rtbase]], [[measure-before-changing-code]].
