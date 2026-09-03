---
name: menubar-menuhelp-cross-axis-exits
description: How a horizontal MENUBAR and a vertical MENUHELP dropdown drive each other — the two cross-axis exit flags, and why the caller owns the loop
metadata:
  type: project
---

**The composition, built 2026-09-01 for `samples/editor`.**

`MENUBAR.INC.BL` is a horizontal bar; `MENUHELP.INC.BL` is a vertical menu. A menu bar with
dropdowns needs both at once, and the join is two flags — each module handing back a key that means
nothing on ITS axis, so the CALLER decides what it meant:

- `MENUBAR.DOWNEXIT` / `MENUBAR.UPEXIT` — DOWN ends the bar, so the caller can open the panel.
- `MENUHELP.KEYEXIT` — **added 2026-09-01**; a key the vertical menu has no use for ends it with
  `MENUHELP.KEY` set and **`MENUHELP.SEL` left alone** (that is the whole difference from ESC, which
  returns 0). Covers LEFT/RIGHT to walk the bar with the panel open, and letters that jump menus.

Both default OFF: ignoring cross-axis keys stays right for a menu that is only a menu.

**They share `MENUHELP.ITEM$`, `ATTR`, `HIATTR`, `HOT$`, `HOTATTR` deliberately** — one convention,
not two. So the array holds whichever of the bar and the dropdown is being drawn, and each caller
routine reloads its own before use. Two traps that follow:

- `MENUBAR.ITEM` sets `MENUHELP.Y = MENUBAR.Y - MENUBAR.DRAWN + 1` (it aims `MENUHELP.ROW` sideways),
  so after drawing the bar those fields are meaningless to the dropdown — set X/Y/WIDTH/COUNT fresh.
- `MENUHELP.HOT$` must be **emptied** for a dropdown whose letters mean MENUS, or `MENUHELP.HOTKEY`
  matches them against the ITEM list and picks the wrong row.

**An item's width is its text**, so a bar's padding lives in the item string: `" File "`, not
`"File"`. With `MENUBAR.X = 0` and `GAP = 0` that reproduces a hand-rolled bar starting at column 2
exactly.

`MENUBAR.RUN` drives a bar that is alone on screen. The editor never has one — ESC opens straight
into a dropdown — so it uses `MENUBAR.DRAW` / `MARK` / `WHERE` for layout and paint and lets
`MENUHELP.RUN` own the key loop. That is a real use of the module, not a partial one.

Verified by diffing the editor's self-check output against the same file built with the pre-merge
compiler: byte for byte identical. See [[headless-basl-build-recipe]].
