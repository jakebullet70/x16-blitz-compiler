# One overlay file: NAME.OVL

Plan for option C of `OVERLAY-IN-PRG.RESEARCH.md`. Every `GP.BANKED` region and every
`GP.BANKEDSTR` text bank stops being a `NAME.nnn` file of its own and goes into a single
`NAME.OVL` beside the program. A compiled program becomes two files in embedded mode
instead of N+1. Paths are from the repo root.

Nothing here is built. Step 1 is a measurement that decides step 5.

## 1. Decisions

- **One file, `<object base>.OVL`.** The extension replaces `.nnn` entirely. `GPC.GUI.PRG`
  ships with `GPC.GUI.OVL`. There is no digit form left anywhere.
- **The file describes itself.** Two header bytes per region, no directory, no length table
  and no bank bitmap in the bootstrap. The extension page stops carrying `BXMap`.
- **Order does not matter**, exactly as it does not today: every region carries its own bank
  number, so code regions and text banks can be written in whatever order they close.
- **Page counts come from `layoutPages`.** `compiler.asm:961` already holds one byte per
  region, and `memreport.asm:211` already documents it as whole pages. No new arithmetic.
- **The reader is `ACPTR` unless step 1 says otherwise.** `MACPTR` is used nowhere in this
  codebase; it is the fallback, not the first choice.
- **No second extension page.** The budget in section 3 says the `ACPTR` reader fits the
  page that exists. If it does not, the plan stops and the `MACPTR` variant is costed
  separately.
- **No compatibility with `.nnn`.** Per `no-backward-compatibility-needed`, old programs are
  recompiled. The digit poker goes out of both `object.asm` and `bootstrap2.asm`.

## 2. The file format

    bank byte
    page count byte          1..32
    page count * 256 bytes   the region, padded to the page
    ...repeated, once per region...
    EOF

A region is capped at 8,188 bytes, so the page count fits a byte and 32 is its ceiling.
Every region except the topmost is already an exact number of pages, because the next
region's `layoutStart` is page aligned; only the topmost needs the writer to pad.

The file ends exactly at a region boundary, so EOF at a boundary is clean and EOF anywhere
else is a truncated file the bootstrap can refuse. That is new: a short `.nnn` today simply
loads and runs.

Padding cost, measured on `samples/GPC-GUI-HELPER`: 6,912 + 2,560 + 1,536 + 1,280 plus
8 bytes of headers is **12,296** against the 12,103 the four `.nnn` files take now.

## 3. Byte budget in the extension page

From `source/application/build/code.lbl`, the page today:

    $0900-$0986   code              135 bytes
    $0987         BXMap              32
    $09A7-$09A9   BXHigh, BXByte, BXNameLen
    $09AA         BXName             48
    $09DA-$09DD   BXBase, BXWS, BXWSEnd, BXIndex
    $09DE         BXPow10             3
    $09E1-$09EC   "?OVL", "?RAM"     12
    $09ED-$09EF   free                3

What this plan removes:

| removed | bytes |
|---|---:|
| `BXMap` | 32 |
| `BXByte`, `BXIndex`, `BXPow10` | 5 |
| digit poker, `$092F-$094F` | 33 |
| map walk, `BXNext..BXBit` | 26 |
| `BXSkip` walk tail | 5 |
| **Total** | **101** |

With the 3 already free, the reader has about **104 bytes**. The sketch in section 8 comes
to about 97. `BXHigh` stays but changes job: it becomes the re-run guard only.

## 4. Step 1 — measure `ACPTR` (gate)

The whole plan turns on one number: how long `ACPTR` takes to read 8,192 bytes.

- Open an existing 8K file, `CHKIN`, read it byte by byte into a bank, count jiffies.
- Run it **under hostfs** and **under a mounted SD card image**. They are different code
  paths in the emulator and the hostfs one is what the build loop uses.
- Report seconds per 8K for both.

**Threshold: about 0.3 s per 8K.** At or under it, take the `ACPTR` reader in step 5 and the
plan proceeds as written. Over it, stop and re-cost the `MACPTR` variant, which needs a
second extension page and moves banked p-code from `$0A00` to `$0B00`.

*Needs agreeing before it is written: GP.ASM blob or a standalone 64tass PRG.* The probe is
throwaway either way, and GP.ASM is quicker to iterate.

### Measured, 2026-09-16 -- hostfs

`drive/ACPTRBEN.BASL`, a GP.ASM blob, run at real speed under `-fsroot`. One `OPEN`, then four
8,192-byte reads a phase into bank 4 at `$A000`, with a checksum of the bank afterwards so a fast
number cannot be a number for bytes that never arrived. Both phases checked out at 496.

| | jiffies per 8K | seconds per 8K |
|---|---:|---:|
| `OPEN` | 0 | under a jiffy |
| `ACPTR` | 17 | **0.283** |
| `CHRIN` | 19 | 0.317 |

**`ACPTR` passes, by six per cent.** The threshold above is 0.3 s and the reader takes 0.283 s, so
the plan proceeds as written and `MACPTR` is not needed. `CHRIN` is 12% slower and would fail the
same gate, which settles the choice between the two byte-at-a-time calls as well.

### The baseline, measured the same day

A per-8K figure is not what a program pays. It pays for the bytes it actually has, and it pays
them against what the `.nnn` files cost today rather than against zero. `drive/LOADBEN.BASL`
measures both halves over the real GPBMODS data: eight `BLOAD`s of `GPBMODS.004` to `.011`, which
is the KERNAL `LOAD` the bootstrap already calls, and then one `OPEN` and one `ACPTR` walk of a
`GPBMODS.OVL` built to this plan's format. Both phases checksum the eight banks afterwards, and
both came out right, so neither number is a number for bytes that never arrived.

GPBMODS declares eight regions holding 32,000 bytes -- 125 pages, every one of them already an
exact page multiple, so this plan's page padding costs GPBMODS nothing and the `.OVL` is 32,016
bytes, the 16 being the headers.

| | jiffies | seconds |
|---|---:|---:|
| eight `LOAD`s, 32,000 bytes | 1 | 0.017 |
| one `OPEN` of the `.OVL` | 0 | under a jiffy |
| `ACPTR` walk, 32,016 bytes | 75 | **1.250** |

The walk works out at 0.282 s per 8K, which is the 0.283 s above to within a jiffy, so the
per-8K figure does scale.

**Under hostfs the regression is 1.23 s and the ratio is 75 to one.** The eight `LOAD`s are
effectively free, because a hostfs `LOAD` is a block copy on the host side with no IEC and no
card in the way.

**Hostfs flatters the baseline and not the reader**, which is the important half of this. The
`ACPTR` walk is CPU-bound -- 32,016 `JSR $FFA5` and 32,016 indexed stores -- so 1.25 s is close
to what any device pays. `LOAD` from a real SD card is nowhere near one jiffy. So 1.23 s is the
worst case for the regression rather than the expected one, and the real figure needs the card
measurement below.

For scale at the other end, the GUI helper's four regions hold 12,296 padded bytes, which is
0.424 s by the same rate.

**Still unmeasured: the SD card image.** Nothing in this tree mounts one -- no `-sdcard` anywhere,
and `bin/x16emu/` ships `makecart.exe` and no image builder -- so that half of this step needs an
image made first. Hostfs is what the build loop uses and real hardware is not hostfs, so the
number above is the development number, not the shipping one.

## 5. Step 2 — the name

`ObjBuildOverlayName` in `object.asm:1275` copies the object name up to and including the
last dot, then writes three digits. Replace the digit half with a literal `OVL`, drop
`_OBONPow10` and the `ovlBank` parameter. The routine keeps `ovlNameLen`, which
`_WOCSExtPage` reads, and keeps the no-dot case that appends `.OVL` to a name that has no
extension.

The `BXNAMEMAX` bound check at `_WOCSExtNameLong` is unchanged.

## 6. Step 3 — the object writer

`ObjEmitRegion` (`object.asm:1062`) keeps its span arithmetic untouched. `ObjEmitOverlay`
(`object.asm:1104`) changes shape:

- **Open once, not per region.** The scratch-then-open pair moves out to a routine called
  from the first region close, guarded by a flag, so a program with no regions writes no
  file. Both callers of `BLC_REGIONDONE` run in pass two — `compiler.asm:655` for code
  regions and `gpbstrflush.asm:193` for text banks — so one open channel spans them.
  `IO_OVL_FILE` is one logical file and only one overlay ever exists at a time, so the
  file number needs no change.
- **No `$A000` header.** The two bytes that made secondary address 1 work are gone. In
  their place, per region: `gpBankBanks,x` then `layoutPages,x`.
- **Pad to the page count.** Write `objSpan` bytes as now, then
  `layoutPages,x * 256 - objSpan` zeroes. That is zero for every region but the topmost.
- **Close at the end.** `ObjStreamClose` closes the overlay file if it was opened.
- **`ObjStreamAbort`** (`object.asm:1375`) already scratches the overlay in flight by name;
  it now scratches one file rather than the one that happened to be open, which is the same
  code with the name fixed.

`IOOpenOverlay`, `IOSelectOverlay` and `IOOverlayClose` in `file-io/read.asm:116-140` are
unchanged. The stale comment above them at `read.asm:105` says overlays are written at the
end of pass two; it already describes the old behaviour and should be corrected while the
file is open.

`IODeleteOutputs` in `file-io/write.asm:63` gains `.OVL` alongside the object and the map.
The long note at the end of that file explaining why the `.nnn` sweep was refused stops
applying: one name is known before the source is read, so the orphan case the note
describes goes away. Rewrite the note, do not delete it — the reason a wildcard is still
refused (`wildcard-scratch-eats-the-source`) is worth keeping.

## 7. Step 4 — the extension page patcher

`_WOCSExtPage` in `object.asm:525`:

- Delete the `_WOCSExtMap` loop and `_WOCSExtBits`.
- Delete the `BootExtHighOffset` write. `BXHigh` becomes the re-run guard and the template
  value of 0 is correct.
- Keep the GP.BSTR table copy at `_WOCSExtBStr` exactly as it is. It is unrelated.
- Keep the name copy. The call becomes `jsr ObjBuildOverlayName` with no bank argument.

## 8. Step 5 — the bootstrap

`bootstrap2.asm` keeps its entry contract: A, X and Y arrive holding the p-code base page,
the workspace start page and the workspace end page, and are handed on to `RT_ENTRY`
unchanged. Everything between those two points is replaced.

    BXEntry:   save A/X/Y
               lda BXHigh : bne BXRun      ; second RUN: banks already hold it
               SETNAM BXName / BXNameLen
               SETLFS 0, 8, 2              ; a data channel, not a LOAD
               OPEN, CHKIN                 ; carry from either -> BXFail
               sec : X16_MEMTOP : dec a : sta BXTop
    BXRegion:  ACPTR -> bank
               cmp BXTop : bcs BXNoRam     ; the bank is above the machine's highest
               sta $00
               ACPTR -> BXPages
    BXPage:    ldy #0
    BXByteIn:  ACPTR : sta (BXPtr),y : iny : bne BXByteIn
               inc BXPtr+1
               dec BXPages
               beq BXPageEnd
               READST : bne BXFail         ; short file, mid region
               bra BXPage
    BXPageEnd: READST : bne BXAllDone      ; clean EOF, at a region boundary
               bra BXRegion
    BXAllDone: CLRCHN, CLOSE 0
               inc BXHigh                  ; the re-run guard
    BXRun:     restore A/X/Y : jmp RT_ENTRY

Notes on the shape:

- **`BXPtr` is reset to `$A000` at each `BXRegion`,** not carried across. Two bytes.
- **The status check is per page, not per byte.** A truncated file is caught to within a
  page and costs about 14 bytes.
- **`?RAM` is now per region** rather than a single pre-pass against the highest bank in a
  bitmap. It is stricter and it is 4 bytes inside the loop.
- **`?OVL` keeps its text and its meaning**, and now also covers a truncated file. `?RAM`
  shares the print loop as it does today.
- **The re-run guard inverts.** Today `stz BXHigh` makes the walk stop; now a nonzero
  `BXHigh` skips the open. Same byte, same page, same reason it survives — p-code starts
  above it and the frame stack is far above that.

Every label stays global and `BX`-prefixed. The file's own header note explains why, and it
cost a build once.

## 9. Step 6 — reports and prose

- `PrintBankReport` in `memreport.asm:222` needs no logic change. Its header note names
  "the .nnn file" and must be corrected.
- `gpbank.asm:972` describes the `.002`..`.255` naming. Rewrite.
- `bootstrap2.asm`'s own header is half an essay on why there is a file per bank. It is the
  main piece of prose this replaces.
- `docs/memory/region-overlay-ovl-file.md` records the `.nnn` decision and its warning that
  a `.nnn` size is a page count unless it is topmost. Update it: the page count is now in
  the file, explicitly, for every region including the topmost.
- `GP-BASIC.md` — grep for `.nnn` and for `overlay` before touching anything, and patch the
  render delta rather than regenerating the HLP (`hlp-files-carry-hand-edits`).
- The `GPBMODS.BASL` comment block at line 2544 says "ONE OVERLAY FILE A BANK". It is the
  user's sample prose; flag it rather than editing it.

## 10. Test matrix

| case | what it proves |
|---|---|
| a program with no `GP.BANKED` at all | no `.OVL` is created, object is byte for byte unchanged |
| `GPC.GUI` — 4 code regions, banks 4-7 | the ordinary path, and the 12,296 vs 12,103 size |
| GPBMODS — 6 code regions and 2 text banks, 4-11 | text banks and code regions in one file |
| non-contiguous banks, e.g. 4 and 200 | proves order and gaps are irrelevant |
| a region that is exactly 32 pages | the page count ceiling |
| delete the `.OVL` and run | `?OVL` |
| truncate the `.OVL` by 100 bytes and run | `?OVL`, not a silent bad run |
| RUN twice without reloading | the second RUN skips the load |
| a bank above `MEMTOP` | `?RAM` |
| abort a compile mid-region | no `.OVL` left behind |

Do not build PICKDEMO for any of these.

## 11. Rollback

Every change is in four files — `object.asm`, `bootstrap2.asm`, `file-io/read.asm`,
`file-io/write.asm` — plus prose. There is no format negotiation and no on-disk state to
migrate, so reverting is a revert and a recompile.

Related: `OVERLAY-IN-PRG.RESEARCH.md`, `region-overlay-ovl-file`,
`object-writer-regions-vs-low-code`, `compiler-must-not-cap-program-size`.
