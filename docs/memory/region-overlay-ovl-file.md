---
name: region-overlay-ovl-file
description: "BUILT: every GP.BANKED region goes to its own NAME.Bnn file that the bootstrap LOADs straight into its bank, so region bytes never enter low RAM or the 24,063-byte file ceiling"
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

**One file per region, named by its bank** — `GPBMODS.B05`. Not the single `.OVL` the design
first chose: that wanted consecutive banks and 8K of padding a region on disk, and per-region
files want neither. The compiler writes each one at `ObjStreamClose`, after the source is finished,
scratching it by exact name first because `"name,S,W"` refuses to open over a file that exists.

**The extension page's table is one byte a region — the bank — terminated by 0.** Bank 0 is refused
everywhere, which is what frees it as the terminator. The compiler bakes in ONE name template with
`B00` on the end and the bootstrap pokes the two digits in per region, because N names at 16
characters would not fit the page.

**Secondary address 1 is the whole trick.** It makes the KERNAL honour the file's own two-byte load
address and ignore the address in X/Y, so an overlay whose header says `$A000` lands at `$A000`.
Selecting the bank in `$00` is then the entire bank handling, and `bootstrap2.asm`'s copy loop is
gone. **The bytes never enter the low 40K at all.**

**A missing overlay prints `?OVL` and stops.** Running whatever the bank happened to hold is the one
failure this must not have.

## What was decided against, and why

- **No version stamp pairing `.PRG` to `.Bnn`.** The programmer owns stale overlays, by decision.
- **No wildcard sweep of old overlays** — see [[wildcard-scratch-eats-the-source]]. `S0:NAME.B*`
  deletes `NAME.BASL`. Exact-name scratching covers what the sweep was for.
- **Two digits, so the bank caps at 99.** One fixed-width template rather than N names. A 512K X16
  has banks 0-63 so nothing runnable is bounded, and `GPBankReadNumber` refuses 100 up by name
  rather than emitting `.B:0`. Three digits is about six bytes if it ever matters.

## The fact worth keeping on its own

**LOAD into banked RAM auto-increments the bank crossing `$BFFF`**, so setting the bank IS the whole
of the bank handling — `source/runtime/_library.asm:4403`, `docs/x16/X16 Reference - 04 - BASIC.md`
line 417, and `samples/prg2basload/prg2basload.basl:76` which BLOADs through as many banks as it
needs. Per-region files never cross `$BFFF`, so this is not relied on here any more, but it is true
and [[macptr-wraps-banks-itself]] is its neighbour.

`$030D/$030E` hold the end address after a LOAD and `$00` the ending bank, so a caller can check a
file arrived whole for free.

## What it unlocked

Region bytes stopped counting against the file, which is what made raising the region count worth
doing at all — do it the other way round and you only move where `PROGRAM TOO BIG` fires.
`GPBANK_MAXREGIONS` is **16** now, capped by the 1K compiler storage hole rather than by the
extension page (which holds a byte a region and has room for over a hundred). See
[[compiler-must-not-cap-program-size]].

**Resident p-code is still capped by the workspace test** — this never touched that, and GPBMODS
proves it: its object fell by 13K while its free-memory figure did not move.

Related: [[gp-bankedstr-literal-text-in-a-bank]], [[object-writer-regions-vs-low-code]],
[[load-chain-strands-array-strings]] (a LOAD-chained set needs its own overlays per program).
