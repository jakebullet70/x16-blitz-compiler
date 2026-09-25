# Sample — BMXVIEWER

The reference BMX viewer, written for the ROM interpreter. `GPC-BASIC/BMXVIEW.EXP.BL` was written
against this program, and `GPC-BASIC/BMX.INC.BL` does the same job in a fifth of the source.

Run it:

```
bmx-demo.bat
```

## Files

| File | What it is |
| --- | --- |
| `BMXVIEWER.BAS` | the viewer — BASLOAD source, with its ML row helper as `DATA` |
| `BMXVIEWER.PRG` | the tokenised program |
| `STANDARD.BI` | `#INCLUDE`d KERNAL, VERA and zero-page equates |
| `DPAL.BIN` | the 256-entry default palette, 512 bytes |
| `SAMPLES/` | eight `.BMX` images, one for each header shape |

## SAMPLES/

`BMX.PARSE` in `GPC-BASIC/BMX.INC.BL` reads a 32-byte header: width at 6-7, height at 8-9, palette
entries used at 10, first palette index at 11, image data offset at 12-13, compression at 14. Each
image covers a different reading of those fields.

| File | Pixels | Palette | Data at | What it covers |
| --- | --- | --- | --- | --- |
| `XMASCARD.BMX` | 320x240 | 256 | 544 | full width, so the paint runs as one block |
| `CANDLE.BMX` | 320x240 | 256 | 544 | the fixture `BMXSPD.EXP.BL` times the one-block path on |
| `BEARDGUY.BMX` | 240x240 | 256 | 544 | narrower than the screen, so it is centred a row at a time |
| `TREE7.BMX` | 300x240 | 256 | 544 | a width that is neither 320 nor 240 |
| `TREE9.BMX` | 320x180 | 256 | 544 | short, so `BMX.Y0` centres it vertically |
| `ROBOSPIDER.BMX` | 186x200 | 232 | 496 | the only partial palette, and odd on both axes |
| `DESERTFISH.BMX` | 320x240 | 256 | 32 | data offset lands inside the palette, so `BMX.SKIP` goes negative and the guard at `BMX.INC.BL:182` drops it |
| `CAT1.BMX` | 320x240 | 256 | 544 | byte 15 is `$FF`, a reserved byte the parser does not read |

> **WARNING** — `CANDLE.BMX` and `BEARDGUY.BMX` are opened by name from
> `GPC-BASIC/BMXSPD.EXP.BL` and `GPC-BASIC/BMXPAL.EXP.BL`. Removing or renaming either stops
> those two programs.
