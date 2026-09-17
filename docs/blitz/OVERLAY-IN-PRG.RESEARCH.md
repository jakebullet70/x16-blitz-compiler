# Putting the overlays inside the PRG

Research, 2026-09-16. No code was written. The question was whether a compiled program
can carry its `GP.BANKED` region data inside the `.PRG` instead of shipping a `NAME.nnn`
file beside it for every region.

The short answer is that one file is reachable only for small programs, and the useful
work is in getting from N extra files down to one.

## 1. The wall

BASIC's `LOAD"PROG",8` reads the whole file into low RAM starting at `$0801`. Low RAM ends
at `ObjectCeiling $9F00` (`start.asm:121`). A PRG has exactly one two-byte load address, the
KERNAL cannot be asked to stop early, and it cannot scatter one file to several addresses.

    $9F00 - $0801 = 39,679 bytes

**Any scheme that appends region bytes to the PRG is capped at 39,679 bytes of total
payload, regions included.** For comparison, a shared banked program's low code today has
to end below `RTGPBASE $6F00` (`common.inc:113`), which is 26,367 bytes of payload; the
regions are on top of that and pay no low-RAM price at all.

Four escapes were considered and all four fail:

- **Re-LOAD the program's own file into scratch banks.** The tail is still inside the stream
  the first LOAD delivers, so it hits the wall before the re-read starts.
- **OPEN the program's own file, seek past the low part with the CMDR-DOS `P` command, and
  MACPTR the tail into banks.** Same wall, for the same reason. `P` also carries a hostfs
  warning: footnote 7 of *Working with CMDR-DOS* says the `,?,M` mode "Doesn't work in the
  emulator and hostfs", and the headless build loop runs on hostfs, so `P` is unverified
  here and cannot be leaned on.
- **Pad the low part up to `$A000` so LOAD spills into the banked window.** Costs
  `$A000 - $0801 = 39,935` bytes of padding on disk and drops the first region into bank 0,
  which is the KERNAL's.
- **Two load addresses in one file.** The KERNAL LOAD has no multi-segment form.

## 2. What the measurements say

`samples/GPC-GUI-HELPER`, as built on 2026-09-16:

| file | bytes | bank |
|---|---|---|
| `GPC.GUI.PRG` | 9,783 | — |
| `GPC.GUI.004` | 6,914 | 4 |
| `GPC.GUI.005` | 2,562 | 5 |
| `GPC.GUI.006` | 1,538 | 6 |
| `GPC.GUI.007` | 1,089 | 7 |

Overlay total 12,103, whole program 21,886. That is comfortably under 39,679, so this
program *would* fit as a single appended file.

GPBMODS declares text banks 5 and 6 and code banks 4, 7, 8, 9, 10 and 11 — eight banks,
`4..11`, contiguous. The GUI helper's four are `4..7`, also contiguous. Both real samples
happen to be contiguous, but the compiler cannot depend on that: `GP.BANKED` takes a
decimal constant the programmer chooses, so `9` and `200` in one program is legal.

## 3. The bootstrap extension page has no room

`bootstrap2.asm` occupies `$0900` exactly, and the GP.BSTR bank table is pinned at
`GPBSTRBANKS $09F0` where the runtime reads it. From `code.lbl`:

    $0900-$0986   code              135 bytes
    $0987         BXMap              32
    $09A7-$09A9   BXHigh, BXByte, BXNameLen
    $09AA         BXName             48
    $09DA-$09DD   BXBase, BXWS, BXWSEnd, BXIndex
    $09DE         BXPow10             3
    $09E1-$09EC   "?OVL", "?RAM"     12
    $09ED-$09EF   free                3

Three bytes. Any loader larger than what it replaces needs a second page, which moves a
banked program's p-code base from `$0A00` to `$0B00`. That is mechanical — the page number
is handed to the runtime in A at run time rather than baked in, and both fit checks already
add `gpBankActive` as a page count — but it is a change in two places and a byte off every
banked program's low-RAM budget.

## 4. The options

### A — append the regions, bootstrap copies them up

Regions are appended page-aligned above the low code and the bootstrap copies each to its
bank before the runtime starts. `ObjEmitBankCode` already does exactly this for the
embedded bank-1 image, so the shape is proven and the writer change is small.

One file, always. Capped at 39,679 bytes total. It also lands on top of `RTGPBASE`, which
kills the warm-start runtime skip for banked programs — every run cold-loads the runtime.

A plain size cap is what `compiler-must-not-cap-program-size` forbids, so A cannot ship on
its own.

### B — append when it fits, `.nnn` when it does not

The same append, with the compiler choosing at `ObjectPrepareShared` / `PrepareObjectCode`,
where the arithmetic already lives: `pass1Len` and every `layoutStart` are settled before
pass two writes a byte. Small banked programs become one file; large ones behave exactly as
they do now. Two write paths in `ObjEmitRegion` and one flag in the extension page telling
`BXEntry` to copy rather than load. No cap, because the fallback has none.

### C — one `.OVL` instead of N `.nnn`

Two files rather than one, but no cap, no wall arithmetic and no dependence on program size.

`ObjEmitRegion` already fires once per region **at region close**, not at the end of the
compile, and `gpBankBanks` order is emit order. So the `.OVL` is a plain sequential append.
Give each region a two-byte header and the file describes itself:

    bank byte, page count byte, pagecount * 256 bytes of region
    ...repeated...
    EOF

No directory, no length table, no bank bitmap. The bootstrap reads a header, sets `$00`,
reads that many pages into `$A000`, and repeats until EOF. `?RAM` becomes a per-region
MEMTOP compare of about 8 bytes, which is stricter than today's single pre-check.

Padding every region up to a page keeps the count in one byte — a region is capped at 8,188
bytes, so 32 pages covers the largest. On the GUI helper the padding costs under 200 bytes:
6,912 + 2,560 + 1,536 + 1,280 + 8 bytes of headers is 12,296 against 12,103 today.

**What C frees in the extension page.** Dropping the bank bitmap and the three-digit name
poker gives back roughly 101 bytes:

| removed | bytes |
|---|---|
| `BXMap` | 32 |
| `BXByte`, `BXIndex`, `BXPow10` | 5 |
| digit poker, `$092F-$094F` | 33 |
| map walk, `BXNext..BXBit` | 26 |
| `BXSkip` walk tail | 5 |

With the 3 already free that is a budget of about 104 bytes for the new reader. `BXHigh`
stays, as the re-run guard.

Three ways to do the reading:

- **C2, an `ACPTR` byte loop.** `SETNAM`/`SETLFS`/`OPEN`/`CHKIN`, then per region two
  `ACPTR` calls for the header, `READST` for EOF, `sta $00`, and `sta (ptr),y` a page at a
  time. Sketches at about 97 bytes, so it fits the freed space and needs **no second page**,
  and it adds no KERNAL call this codebase does not already use. The open risk is speed:
  8,192 `ACPTR` calls per full bank, around 30K for GPBMODS. Unmeasured.
- **C1, `MACPTR`.** Same file format, block reads. `MACPTR` appears nowhere in this
  codebase today — only the address is defined, in `x16_include.inc:83`. It needs an
  `ACPTR` fallback because a set carry means the device does not support it, and a 16-bit
  remaining counter because it may return fewer bytes than asked. `A=0` cannot be used
  here: the KERNAL may then read up to 512 bytes and overrun into the next region's header.
  About 60 bytes more than C2, so it **needs the second page**.
- **C3, one `LOAD` of 8K blocks.** Pad every region to exactly 8,192, write one file with a
  single `$A000` header, and have the bootstrap set `$00` to the lowest bank and call
  `BBTryLoad` unchanged — the bank auto-increment at `$BFFF` fills the rest. The bootstrap
  is about 25 bytes and nothing new is called. It costs file size (32,768 for the GUI
  helper, 65,536 for GPBMODS) and it needs one contiguous bank span, so a program using
  banks 9 and 200 would produce a 1.5 MB file. Guarding the span width is a size cap, so C3
  needs a `.nnn` fallback for sparse spans.

Effects common to all three C variants:

- A truncated `.OVL` becomes detectable — EOF in mid-region is an error the bootstrap can
  see. Today a short `.nnn` simply loads and runs.
- `ObjStreamAbort` has one file to scratch instead of N.
- The channel count is unchanged. The object file and an overlay file already coexist; the
  overlay channel just stays open across the compile instead of reopening per region.
- Stale pairing is no better and no worse: one stale `.OVL` instead of N stale `.nnn`.
- Old `.nnn` files left beside a rebuilt program become inert rather than stale, since
  nothing loads them. That is safer but more confusing on a directory listing, and the
  wildcard sweep is still refused (`wildcard-scratch-eats-the-source`).

### D — B and C together

Append when the whole thing fits under `$9F00`, and fall back to a single `.OVL` when it
does not. Never more than two files, and one file whenever the program is small enough.

## 5. Where it stands

Option D is the shape that gets the single file the question asked for without
reintroducing a build-side size wall.

Within C, C2 is the pick, conditional on one measurement: `ACPTR` throughput under hostfs
and under a mounted SD card image. If 8K reads in under about 0.3 s, C2 wins outright — one
page, no new KERNAL calls, smallest file. If it is slow, C1 and accept the second page. C3
is much the cheapest to build and needs no new bootstrap logic at all, but the eightfold
file inflation on GPBMODS and the sparse-span fallback make it the weaker trade.

Nothing here is decided and nothing has been built.

Related: `region-overlay-ovl-file`, `object-writer-regions-vs-low-code`,
`object-file-must-fit-under-the-runtime`, `compiler-must-not-cap-program-size`,
`macptr-wraps-banks-itself`.
