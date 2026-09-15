---
name: region-overlay-ovl-file
description: "BUILT: every GP.BANKED region goes to its own NAME.nnn file, the bank in three digits from .002 to .255, that the bootstrap LOADs straight into its bank, so region bytes never enter low RAM or the 24,063-byte file ceiling"
metadata:
  type: project
---

**Designed 2026-09-08, built the same day.** GPBMODS fell from 23,553 bytes to 10,249 and GPBFILES
went from `PROGRAM TOO BIG` to 13,538. Cost: +305 bytes of compiler, none of runtime.

## The problem it solved

Every region used to ship inside the object, and a GP program's whole file is capped at **24,063
bytes** ([[object-file-must-fit-under-the-runtime]]). So a banked byte paid full file price to
arrive: it was compiled into the object, LOADed at `$0801` with everything else, and only then
copied up to `$A000`. Eight regions of 8K would have been 64K against a 24K file. **The region cap
was never what bound; the file was.**

## What was built

**One file per region, named by its bank** — `GPBMODS.005`. Not the single `.OVL` the design
first chose: that wanted consecutive banks and 8K of padding a region on disk, and per-region
files want neither. The compiler writes each one at `ObjStreamClose`, after the source is finished,
scratching it by exact name first because `"name,S,W"` refuses to open over a file that exists.

**The extension page holds a 32-byte bitmap, one bit a bank, and the highest bank.** It was one
byte a region, terminated by 0, until `docs/blitz/ALL-BANKS.PLAN.md` (2026-09-14). The compiler
bakes in ONE name template ending `000` and the bootstrap pokes each bank's three digits in,
because N names at 16 characters would not fit the page. Before loading anything the page calls
`MEMTOP`, and a machine without the highest bank prints `?RAM` and returns to READY.

**Secondary address 1 is the whole trick.** It makes the KERNAL honour the file's own two-byte load
address and ignore the address in X/Y, so an overlay whose header says `$A000` lands at `$A000`.
Selecting the bank in `$00` is then the entire bank handling, and `bootstrap2.asm`'s copy loop is
gone. **The bytes never enter the low 40K at all.**

**A missing overlay prints `?OVL` and stops.** Running whatever the bank happened to hold is the one
failure this must not have.

## What was decided against, and why

- **No version stamp pairing `.PRG` to `.nnn`.** The programmer owns stale overlays, by decision.
- **No wildcard sweep of old overlays** — see [[wildcard-scratch-eats-the-source]]. `S0:NAME.B*`
  deleted `NAME.BASL` when overlays were `.Bnn`. Exact-name scratching covers what the sweep was for.
- **A letter in the extension.** `.Bnn` capped the bank at 99, and `GPBankCheckBankNumber` refused
  100 up by name. Three digits and no `B` came to 1 byte more in `ObjBuildOverlayName`, and every
  bank a 2 MB X16 has now has a name.

## The fact worth keeping on its own

**LOAD into banked RAM auto-increments the bank crossing `$BFFF`**, so setting the bank IS the whole
of the bank handling — `source/runtime/_library.asm:4403` and `docs/x16/X16 Reference - 04 - BASIC.md`
line 417. Per-region files never cross `$BFFF`, so this is not relied on here any more, but it is true
and [[macptr-wraps-banks-itself]] is its neighbour.

`$030D/$030E` hold the end address after a LOAD and `$00` the ending bank, so a caller can check a
file arrived whole for free.

## What it unlocked

Region bytes stopped counting against the file, which is what made raising the region count worth
doing at all — do it the other way round and you only move where `PROGRAM TOO BIG` fires.
`GPBANK_MAXREGIONS` is **127** now, code and text together. Seven region tables are two bytes a
region and are read with the region doubled into X or Y, and 127 is the most a byte holds doubled.
It does not limit the bank numbers: regions use banks 2 to 255. The 1K storage hole capped the
count at 16 until the region tables moved into the **code section**, which is the compiler's own
image and is thrown away when the object is written: they cost a compiled program nothing there,
and no access site had to change. Measured: `BNK255` has code regions in banks 255, 100 and 2 and
text in bank 254; it runs at `-ram 2048` and stops with `?RAM` at 512K. See
[[compiler-must-not-cap-program-size]].

**Resident p-code is still capped by the workspace test** — this never touched that, and GPBMODS
proves it: its object fell by 13K while its free-memory figure did not move.

## A .nnn FILE SIZE IS A PAGE COUNT, NOT A BYTE COUNT

**Only the topmost region is unpadded.** Every other one is rounded up to a whole page, so its
`.nnn` is always a multiple of 256 plus the 2-byte load address and says NOTHING about the bytes
inside its last page. `GPBMODS` has five regions and its `.004` read 7,168 / 7,680 / 7,936 / 8,192
across four phases of the GUI refactor -- four exact page counts, quoted in the plan for three
phases as if they were code sizes, with a "free of 8,192" column derived from them. They were the
padding. The same six modules built into `GUIFRMT`, which has ONE region and no padding, measured
7,852 and then 8,033.

**To measure a region, build it in a program where it is the only one**, or where it is topmost.
The ceiling is **8,188**, not 8,192: `gpbank.asm:582` refuses a 33rd page and counts four bytes of
bridges into the length.

Related: [[gp-bankedstr-literal-text-in-a-bank]], [[object-writer-regions-vs-low-code]],
[[load-chain-clears-memory]] (a LOAD-chained set needs its own overlays per program).
