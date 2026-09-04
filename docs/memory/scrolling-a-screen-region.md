---
name: scrolling-a-screen-region
description: Three ways to scroll part of the X16 text screen, and which to pick — there is no GP command for it
metadata:
  type: reference
---

There is no `GP.SCROLL`. To scroll a rectangle (say cols 10-55, rows 4-22) there are three ways,
and the choice is about how often it scrolls, not about speed alone.

**1. STASH, moved.** `STASH.RESTORE` with `STASH.MOVE = 1` pastes the saved rectangle somewhere
else, so save rows N+1..M and restore at N. Zero new code, and **anything outside the rectangle
does not move** — which is how `samples/GPC-HELP` keeps its title and status bars still while the
text slides. Two passes through banked RAM, so twice the traffic of (2), but the bytes move in
assembly. A bank is 8,192 B and a cell is 2, and `STASH` refuses `W > 128`. Use a bank nothing else
owns: `GUI.BANK` holds the cells under an open dialog.

**2. VERA-to-VERA `memory_copy`.** VERA's two address ports step independently, so point ADDR0 at
the source row-segment and ADDR1 at the destination, put `$9F23`/`$9F24` in r0/r1 (the KERNAL does
not increment pointers inside `$9F00-$9FFF`), the byte count in r2, and `GP.CALL $FEE7`. One call a
row, no assembly to write. `BMX.PALCOPY` in `GPC-BASIC/BMX.INC.BL` is the worked example, and
`STASH.WALK` has the row-address arithmetic — which asks VERA for `L1_CONFIG` and `L1_MAPBASE`
rather than assuming the mode.

**3. Hardware `VSCROLL`, masked.** Moves a whole LAYER, never a rectangle — but **attribute 0 is
transparent in text mode**, so layer 1 with fg and bg both 0 is a hole onto layer 0. Put the
scrolling content on layer 0 and mask the rest with layer 1. Two register writes and one newly
exposed row: the only genuinely free option, and what `samples/editor` does (`ED.LAYERS`,
`ED.HW.SCROLL.DOWN`). Costs you layer 0 program-wide, and the content must be laid out at map
coordinates, so it pays for one big pane and not several small ones.

**Pick:** one pane that scrolls constantly → 3. Any region, occasionally → 1. Several regions, or
you want ordinary screen coordinates → 2.

Whichever you use, **verify by reaching the same position two ways** — by sliding and by a full
repaint — and comparing the screens cell by cell with `VPEEK`, attributes included. A slide that
puts a row one off looks like a working scroll. See [[gpc-editor-branch-and-gui-next]] and
[[vera-fx-cache-write-is-aligned]].
