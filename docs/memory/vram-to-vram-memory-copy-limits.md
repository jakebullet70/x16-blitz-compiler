---
name: vram-to-vram-memory-copy-limits
description: "VERA's auto-increment carries into bit 16; a VRAM-to-VRAM memory_copy is exact at 15,360 bytes, across $10000, at odd counts, and overlapping downward. All four measured."
metadata:
  node_type: memory
  type: reference
---

**Measured 2026-09-07, `work/stashvram/SVGATE.BASL`, 8/8 green.** These were the open questions
under `STASHVRAM.INC.BL`, and all four answers are yes.

A VRAM-to-VRAM copy is r0 = `$9F23` (DATA0, source), r1 = `$9F24` (DATA1, target), r2 = count,
`GP.CALL $FEE7`. The KERNAL does not step a pointer inside `$9F00-$9FFF`, so VERA's own
auto-increment walks both ends. **The X16 reference documents this exact use** — *"copying data
inside VERA (source `$9F23`, destination `$9F24`)"*, `docs/x16/X16 Reference - 05 - KERNAL.md:643`.

| | |
|---|---|
| **VERA's auto-increment carries into bit 16** | Write four bytes from `$0FFFE`, read the last two back at `$10000`. Nothing in the tree had ever crossed that line: every existing use sets ADDRH once and stays inside one 64K half |
| 15,360 bytes in ONE call | exact — a full 80x60 screen at a 128-wide map |
| A copy crossing `$10000` | exact, source side and destination side |
| A count that is not a multiple of 256 | exact, and it does not overrun by a byte |
| **An overlapping slide DOWNWARD** | exact. The reference promises overlap for main memory; with two auto-incrementing ports it had to be observed. This is what a compactor does |

## How to verify one of these cheaply

**`memory_crc` (`$FEEA`) also does not step a `$9F00-$9FFF` address**, so it checksums a VRAM region
through a data port and turns a 15,360-byte comparison into two numbers. Its `r0` is the address and
`r1` the count; the CRC16 comes back in `r2`. Below R48 it processes the remainder of a non-multiple
of 256 in the wrong byte order, so verify odd counts by reading, not by CRC alone.

**Fill each destination with a DIFFERENT seed before the copy.** Otherwise a copy that never
happened passes: two regions holding the same pattern give the same CRC either way.

## Costs and ceilings

- `memory_copy` counts in **16 bits**, so anything at or above 65,536 must be chunked. A `#DEFINE`
  of `$8000` is no good as the chunk size — a `#DEFINE` is a signed int16 and it arrives as
  `-32768`, clamping the count negative. `$4000` is the largest round chunk that stays positive.
- `HELP.PAGE.SHIFT` (`samples/GPC-HELP/GPB.HELP.BASL:835`) already shipped this at 4,480 bytes and
  is the blob-free template to copy: geometry asked of VERA, two ports, the 17-bit split, r0/r1/r2
  poked, one `GP.CALL`. Benchmarked at **1.6 jiffies against STASH's 11.0**.
- A VRAM address is 17 bits, so `GP.HIBYTE`/`GP.LOBYTE` cannot split it (they reach 65,535) and
  `P AND 255` raises `OUT OF RANGE` above 32,767 because `AND` is signed. Take bit 16 off by
  division first.

Related: [[scrolling-a-screen-region]], [[macptr-wraps-banks-itself]],
[[gp-drawing-targets-layer-1]].
