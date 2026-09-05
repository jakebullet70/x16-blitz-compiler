---
name: gp-draw-under-a-reordered-font
description: "GP.BOX picks glyphs from a runtime table so only style 0 survives an ASCII-reordered font, and GP.FILL converts its glyph argument PETSCII to screen code (+$40 across $80-$9F)"
metadata: 
  node_type: memory
  type: project
  originSessionId: 5591d6bc-636d-4001-b0b0-d858156d6ec0
  modified: 2026-08-31T13:50:55.787Z
---

Two GP drawing facts, both measured on the machine, neither in the docs.

**`GP.FILL` CONVERTS its glyph argument.** Passing `128` put tile **192** on the screen:
`GPDrawPet2Scr` adds `$40` across `$80-$9F` (the offset table is
`GPDrawP2SOffset: .byte $80,$00,$C0,$E0,$40,$C0,$80,$80`, indexed by the top 3 bits).
The runtime's own comment — `gpdChar: GP.FILL's glyph, already a screen code` — describes
the *variable it lands in*, not the argument you hand it. So to place a glyph at tile `T`,
park the bitmap at `T` and pass `T - $40` for that range.

**`GP.BOX` takes its glyphs from a table in the RUNTIME**, so it can only ever draw the
four styles that table holds (RENUMBERED since this note was written -- dither and thick
shaded are gone and everything above 1 moved down one):

```
0 solid block $A0   1 single line   2 single line, round corners   3 thick line
```

A style of 256 or more is an address -- the caller's own eight screen codes, copied into
`GPDrawCustom` and then indexed as `GPD_CUSTOM = 4`. `GPD_STYLES = 4`, so a plain 4..255 is
`BAD STYLE`.

Styles 1-3 are built from screen codes `$40-$7D`. Under `samples/editor`'s ASCII-ordered
font that range is ASCII letters, so **the single-line style draws "p @ B"** (observed
as style 2, which is style 1 under the numbering above) and only **style 0
survives**, because `$80-$FF` is the one region the re-order never touches. If a different
border is wanted, draw it with `GP.FILL` — which takes the glyph as an argument — not with
`GP.BOX`.

**Where the line glyphs actually are, in pristine charset 3** (read out of VRAM, not
guessed — the ROM block layout did *not* match any offline reconstruction):
`$40` ─, `$5D` │, `$70` ┌, `$6E` ┐, `$6D` └, `$7D` ┘. Also `$5B` ┼, `$6B` ├, `$71` ┴,
`$72` ┬, `$73` ┤.

**`ED.PETFONT` destroys nearly all of them**, leaving exactly one horizontal (at `$60`,
i.e. on `` ` ``) and one vertical (at `$7D`, on `}`) as accidental survivors, and **no
corners at all**. The editor now rescues all six into `$C0-$C5` as the *first* thing
`ED.PETFONT` does, while every source is still pristine.

**How to see the live font rather than reason about it**: `VPEEK(1, 61440 + code * 8 + row)`
is the charset at `$1:F000`. Scanning all 256 codes for `row3 = 255, row0 = 0` finds
horizontals; all-rows-equal-and-small finds verticals. One build answers what an afternoon
of ROM archaeology did not.

Related: [[gpc-editor-is-ascii-inside-petscii-outside]], [[menuhelp-use-the-whole-interface]].
