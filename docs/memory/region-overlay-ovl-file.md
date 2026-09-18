---
name: region-overlay-ovl-file
description: "BUILT: every GP.BANKED region of a program goes into ONE self-describing NAME.OVL that the bootstrap reads through ACPTR, bank byte and page count ahead of each region and a $01 end marker after the last, so region bytes never enter low RAM or the file ceiling"
metadata:
  type: project
---

**Designed 2026-09-08, built the same day** as one `NAME.nnn` file a region. **Replaced 2026-09-17
by one `NAME.OVL` for the whole program**, to the plan in
[docs/blitz/OVERLAY-SINGLE-FILE.PLAN.md](../blitz/OVERLAY-SINGLE-FILE.PLAN.md). The gain that
mattered was never the file count: GPBMODS fell from 23,553 bytes to 10,249 and GPBFILES went from
`PROGRAM TOO BIG` to 13,538, and that is the `.nnn` work, which `.OVL` keeps whole.

## The problem it solved

Every region used to ship inside the object, and a GP program's whole file is capped at **24,063
bytes** ([[object-file-must-fit-under-the-runtime]]). So a banked byte paid full file price to
arrive: it was compiled into the object, LOADed at `$0801` with everything else, and only then
copied up to `$A000`. Eight regions of 8K would have been 64K against a 24K file. **The region cap
was never what bound; the file was.**

## The file, as it is now

**One `NAME.OVL` for the whole program, self-describing.** Its whole grammar:

    bank byte, page count byte, pagecount * 256 bytes of region      repeated, then $01, then EOF

**The `$01` end marker went in 2026-09-18.** Bank 1 is the runtime's and `GP.BANKED 1` is refused
(`BANK 1 IS RESERVED`), so no bank byte is ever `$01`. `ObjStreamClose` writes it after the last
region, the `GP.BANKEDSTR` text banks included. Old `.OVL` files stop with `?OVL` until recompiled.

No directory, no length table, no bank bitmap, no load address. Every region is padded up to a
whole page, which is what keeps the count in one byte: the region ceiling is 8,188 bytes, 32 pages.
Order does not matter and gaps do not matter — a program with regions in banks 4 and 200 writes
them in that order and the reader follows.

**The compiler opens it at the first region and holds it open across the rest of pass two**, writing
each region's two header bytes and then its bank, and scratching the file by exact name before the
first write because `"name,S,W"` refuses to open over a file that exists. A program with no
`GP.BANKED` writes no `.OVL` at all.

**The bootstrap extension page reads it through `ACPTR`, not `LOAD`** — `bootstrap2.asm`, `$0900` to
`$09EB` (236 bytes, 48 of them the name), one page with **4 bytes to spare** before the pinned
`GPBSTRBANKS` table at `$09F0` (measured 2026-09-18, after the end marker).
It OPENs on logical file 2, secondary 2 (a data channel: the file has no load address and does not
go to one place). Per region it reads the bank byte and stops cleanly if it is the marker. Otherwise it
checks `READST` (an empty file), checks the bank against `MEMTOP`, selects it in `$00`, reads the
page count and fills that many pages through a self-modifying store. **`READST` after every page is
an error**: a whole file hits EOF only on the marker, so a cut anywhere stops with `?OVL`.

**Before the marker, a truncated file could run.** The last region's last byte was EOF, so EOF on a
region boundary was the normal way out. A cut on a region boundary looked the same, and so did a
cut inside a region's last page: the reader read the missing bytes past EOF, then saw EOF at the page
end. With 1-page regions no cut was caught. banktest3's `BNKOVL` (100 bytes off `BNK255.OVL`)
exposed it.

**The name is baked in whole, and the page pokes nothing into it.** `ObjBuildOverlayName` builds
`<object>.OVL` once, and 48 bytes of the page hold it with its length.

**A short overlay prints `?OVL` and stops; a bank above `MEMTOP` prints `?RAM`.** A missing one
stops if `OPEN` or `CHKIN` fails, or if the first byte `ACPTR` returns is not `$01`. That byte has not
been tested. Both
close the file first. Running whatever the bank happened to hold is the one failure this must not
have.

**The cost is startup time, and only startup time.** Eight `BLOAD`s of GPBMODS' `.nnn` files took
1 jiffy; the `ACPTR` walk of its 32,016-byte `.OVL` takes **75 jiffies, 1.25 s**, under hostfs, which
flatters the baseline and not the reader — see [[overlay-in-prg-research]] for the measurement. The
load happens once per load, not once per RUN: `BXHigh` is the guard and a second RUN skips the lot.

## What the old shape was, and why it went

**One file per region, named by its bank** — `GPBMODS.005`, `.002` to `.255`. It was chosen over a
single `.OVL` in 2026-09-08 because the design of the day wanted consecutive banks and 8K of padding
a region on disk. Putting the bank and the page count *in* the file costs neither, which is what
reopened it. The extension page's 32-byte bank bitmap, its three-digit name poker and its
`BBTryLoad` calls all went with it, and paid for the reader.

**Secondary address 1 was the whole trick of the old shape.** It made the KERNAL honour the file's
own two-byte load address, so an overlay whose header said `$A000` landed at `$A000` and selecting
the bank in `$00` was the entire bank handling. The `.OVL` has no load address per region, so this
no longer applies — but see the fact below, which is still true.

**Still decided against: no version stamp pairing `.PRG` to `.OVL`.** The programmer owns a stale
overlay, by decision. And still **no wildcard sweep** — [[wildcard-scratch-eats-the-source]];
`S0:NAME.B*` deleted `NAME.BASL` when overlays were `.Bnn`. One exact name is now the whole sweep.

## The fact worth keeping on its own

**LOAD into banked RAM auto-increments the bank crossing `$BFFF`** — `source/runtime/_library.asm:4403`
and `docs/x16/X16 Reference - 04 - BASIC.md` line 417. Nothing here relies on it any more, but it is
true and [[macptr-wraps-banks-itself]] is its neighbour.

`$030D/$030E` hold the end address after a LOAD and `$00` the ending bank, so a caller can check a
file arrived whole for free.

## What it unlocked

Region bytes stopped counting against the file, which is what made raising the region count worth
doing at all — do it the other way round and you only move where `PROGRAM TOO BIG` fires.
`GPBANK_MAXREGIONS` is **127**, code and text together. Seven region tables are two bytes a region
and are read with the region doubled into X or Y, and 127 is the most a byte holds doubled. It does
not limit the bank numbers: regions use banks 2 to 255. The 1K storage hole capped the count at 16
until the region tables moved into the **code section**, which is the compiler's own image and is
thrown away when the object is written: they cost a compiled program nothing there, and no access
site had to change. Measured: `BNK255` has code regions in banks 255, 100 and 2 and text in bank
254; it runs at `-ram 2048` and stops with `?RAM` at 512K. See
[[compiler-must-not-cap-program-size]].

**Resident p-code is still capped by the workspace test** — this never touched that, and GPBMODS
proves it: its object fell by 13K while its free-memory figure did not move.

## A REGION'S SIZE IS A PAGE COUNT, NOT A BYTE COUNT

**Every region is padded to a whole page now, the topmost one included** — the old `.nnn` shape left
the topmost unpadded, and that exception is gone. The page count in the file says NOTHING about the
bytes inside the last page. `GPBMODS` has five regions and its `.004` read 7,168 / 7,680 / 7,936 /
8,192 across four phases of the GUI refactor — four exact page counts, quoted in the plan for three
phases as if they were code sizes, with a "free of 8,192" column derived from them. They were the
padding. The same six modules built into `GUIFRMT`, which has ONE region, measured 7,852 and 8,033.

**To measure a region, build it in a program where it is the only one.** The ceiling is **8,188**,
not 8,192: `gpbank.asm:582` refuses a 33rd page and counts four bytes of bridges into the length.

Related: [[overlay-in-prg-research]], [[gp-bankedstr-literal-text-in-a-bank]],
[[object-writer-regions-vs-low-code]], [[load-chain-clears-memory]] (a LOAD-chained set needs its
own overlay per program).
