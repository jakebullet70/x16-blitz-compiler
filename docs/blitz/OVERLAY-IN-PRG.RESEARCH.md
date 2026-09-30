# Putting the overlays inside the PRG

Research, 2026-09-16. No code was written. The question was whether a compiled program
can carry its `GP.BANKED` region data inside the `.PRG` instead of shipping a `NAME.nnn`
file beside it for every region.

The short answer is option D. A program whose code and regions fit in 39,679 bytes ships as
one PRG. A larger one ships as the PRG and `NAME.OVL`. One file of any size is possible, but
LOAD then prints `?OUT OF MEMORY ERROR`, and that was ruled out on 2026-09-29. Section 6 has
the mechanism and 6.5 the decision.

## 1. The wall

BASIC's `LOAD"PROG",8` reads the whole file into low RAM starting at `$0801`. Low RAM ends
at `ObjectCeiling $9F00` (`start.asm:121`). A PRG has exactly one two-byte load address, the
KERNAL cannot be asked to stop early, and it cannot scatter one file to several addresses.

    $9F00 - $0801 = 39,679 bytes

**A clean LOAD is capped at 39,679 bytes of total payload, regions included.** A longer
file loads up to `$9EFF` and stops with an error, which section 6 turns to use. For comparison, a shared banked program's low code today has
to end below `RTGPBASE $6F00` (`common.inc:113`), which is 26,367 bytes of payload; the
regions are on top of that and pay no low-RAM price at all.

Four escapes were considered:

- **Re-LOAD the program's own file into scratch banks.** Fails. A second LOAD stops at
  `$9F00` the same way the first does.
- **OPEN the program's own file, skip the low part, and read the tail into banks.** Works,
  and section 6 builds on it. The skip is a read-and-discard loop, so the CMDR-DOS `P` seek
  is not needed. `P` also carries a hostfs warning: footnote 7 of *Working with CMDR-DOS* says the `,?,M` mode "Doesn't work in the
  emulator and hostfs", and the headless build loop runs on hostfs, so `P` is unverified
  here and cannot be leaned on.
- **Pad the low part up to `$A000` so LOAD spills into the banked window.** Costs
  `$A000 - $0801 = 39,935` bytes of padding on disk and drops the first region into bank 0,
  which is the KERNAL's.
- **Two load addresses in one file.** The KERNAL LOAD has no multi-segment form.

## 2. What the measurements say

`GPC-BASIC-TOOLS-SRC/GPC-GUI-HELPER`, as built on 2026-09-16:

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

Option C2 is built, to `OVERLAY-SINGLE-FILE.PLAN.md`: one `NAME.OVL`, read through `ACPTR`.
`ACPTR` measured 8,192 bytes in 17 jiffies under hostfs. The SD card image number is
still owed.

Option D is chosen and not built. Section 6 shows a single file works at any size, at the
price of an error on LOAD. Section 6.5 rules that out.

## 6. The wall is soft

Read from the X16 ROM and x16emu source on 2026-09-28. Nothing has been run.

The KERNAL LOAD stops cleanly at the I/O page. `x16-rom kernal/cbm/channel/load.s` reads
in `MACPTR` blocks until `$9D00` and one byte at a time from there (`cmp #$9d`). The byte
loop tests for `$9F00` (`cmp #$9f`, `beq ld81`). At `ld81` it closes the file and returns
error 16. Every byte up to `$9EFF` is written and none past it. A file that ends exactly
at `$9EFF` meets end-of-file first and loads with no error.

BASIC then prints `?OUT OF MEMORY ERROR`. `cload` in `basic/code26.s` takes the error exit
before it sets `vartab` and before it runs `lnkprg`. The program text at `$0801` is intact,
and its line links came from the file, so `RUN` should reach the SYS line.

x16emu gets past the error. `-prg` pastes `LOAD":*",8,1` and `-run` pastes `RUN` as a
separate line (`src/main.c:1829-1840`), so the RUN arrives after the error. The
`USER-RUNS` batch files keep working.

### 6.1 The shape

- The file is today's PRG with the `.OVL` stream appended, in the same format, `$01` end
  marker included.
- The bootstrap opens its own PRG in place of `NAME.OVL`, through the same 48-byte name
  slot.
- It reads and discards the low part. The compiler bakes that length into the page.
- The existing `ACPTR` region reader then runs unchanged.

The tail always comes from disk, so how much of the file LOAD delivered does not matter.
Nothing caps the size, which keeps `compiler-must-not-cap-program-size`.

A file of 39,679 bytes or less loads clean. GPBMODS is 10,249 bytes of low part and
32,016 of regions, 42,265 in all, so it would print the error.

### 6.2 The costs

1. **The error on large programs.** `RUN"NAME"` and the `↑NAME` load-and-run shortcut
   both abort on it. The user types LOAD, then RUN.
2. **Chaining.** GPC's LOAD statement writes `10 LOAD "<name>"` at `$0801` and RUNs it
   in the ROM (`load.asm`). A program-mode LOAD that raises error 16 stops there, so a
   chain into a large single file never runs. The chain needs a KERNAL LOAD of its own
   that accepts error 16 for a GPC file. That code has to sit outside `$0801-$9EFF`,
   since the file lands over the runtime.
3. **Bootstrap room.** The extension page has 9 free bytes, `$09F7-$09FF` in the current
   listing. The skip loop needs more than that. It either squeezes out of the existing
   code or takes a second page. A second page moves banked p-code from `$0A00` to `$0B00`,
   256 bytes off every banked program's low RAM.
4. **Startup time.** At the measured rate, skipping GPBMODS' 10,249-byte low part costs
   about 21 jiffies, 0.35 s. The region read already costs 75 jiffies, 1.25 s.
5. **The name is baked.** The bootstrap opens the name it was compiled under, so a
   renamed PRG stops with `?OVL`. A renamed PRG with a separate `.OVL` still finds it.
6. **No resident runtime on a second run.** A file that runs past `RTGPBASE $6F00`, or
   `RTBASE $7700`, overwrites the runtime on LOAD, so every run reloads it.
7. **The compiler side.** The regions are written during pass two alongside the object,
   so they cannot stream straight into the PRG. The simplest route writes `NAME.OVL` as
   now, appends its bytes to the PRG and scratches it. The CMDR-DOS `C` command does not
   work on hostfs (*Working with CMDR-DOS*, footnote 7), so the compiler copies the bytes
   itself, about 1 to 2 s a compile.

### 6.3 Owed before building

- LOAD a file over 39,679 bytes and confirm `RUN` reaches the SYS line, and that the stale
  `vartab` does a SYS bootstrap no harm.
- The same on a mounted SD card image. The same KERNAL code runs there, but nothing in the
  tree mounts one.
- A self re-OPEN straight after the LOAD, under hostfs and on the SD image.

### 6.4 Compression

The KERNAL has an LZSA2 decompressor, `memory_decompress $FEED`, and a streaming form,
extapi `memory_decompress_from_func`, which takes its bytes from a caller's function. It
could shrink the appended regions and keep more programs under the clean-LOAD line. The
compressor would have to run inside the compiler on the X16, which is the expensive part.
The single file does not need it.

### 6.5 The decision

Decided 2026-09-29: `?OUT OF MEMORY ERROR` on LOAD is not acceptable. The plan is option D.

- The compiler appends the regions to the PRG when the total fits in 39,679 bytes.
- It writes `NAME.OVL` beside the PRG when the total does not fit.
- Every file loads clean, so `RUN"NAME"`, `↑NAME` and the GPC LOAD chain keep working.
- The probes in 6.3 are not needed.
- Still open: room on the extension page for a second region path beside the `ACPTR`
  reader (section 3).

Related: `region-overlay-ovl-file`, `object-writer-regions-vs-low-code`,
`object-file-must-fit-under-the-runtime`, `compiler-must-not-cap-program-size`,
`macptr-wraps-banks-itself`.
