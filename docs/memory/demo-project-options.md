---
name: demo-project-options
description: "The six showcase demo projects proposed on 2026-10-01 after GUI-LITE, which one was picked, and the library gaps each fills"
metadata:
  node_type: memory
  type: project
  originSessionId: d2b7b119-5992-421b-90e8-03d6d590b04d
  modified: 2026-10-01T10:25:55.151Z
---

On 2026-10-01, after the GUI-LITE sample, the user asked for demo projects that show off
GPC-BASIC. Six were proposed. The user picked number 1 and asked for it in
`GPC-BASIC-TOOLS-SRC/MANDELBROT-SPEED/`, to move to `release/` when done.

No sample includes `KV`, `SORT`, `STRUSING`, `MATH` or `MEM` yet. That gap drove the list.

1. **Speed Duel (PICKED).** The same Mandelbrot run three ways: ROM BASIC, GPC compiled, and GPC
   with the inner loop in `GP.ASM`. Times shown side by side. The duel core must be plain X16
   BASIC, because a GP.BASIC program is compile-only.
2. **Control Panel.** A settings editor, the full-GUI counterpart of GUI-LITE. One form with
   `LINEINPUT`, `CHECK`, `COMBO`, `MENUPULL`, saved through `KV.SAVE`. Fills `KV`. Small.
3. **Ledger / checkbook.** `STRUSING` money columns, `SORT` by date, `FILEIO SAVEARRAY/LOADARRAY`,
   a menu bar, `GUI.YN` to confirm a delete. Fills `STRUSING`, `SORT`, `SAVEARRAY`, `MATH`. Medium.
   The recommended second pick.
4. **Text-mode game** (Minesweeper or Snake). `GP.PRINTAT`, `GP.CHAR`, `GP.BOX`, `GP.SELECT` keys in
   a `GP.DO` loop, `THEME`, a high score through `DOS.INC`, a `MSGBOX` at game over. Tests need the
   `POKE 780` key queue. Medium.
5. **File Commander.** Two-pane disk manager: `FILEDIR` into a bank, `FILEIO` copy, rename, delete,
   mkdir and chdir, `STASHVRAM` to swap panes. Wait for the LISTS/DIR work, because the DIR read
   loop is slow. Medium to large.
6. **Text adventure bigger than BASIC RAM.** `GP.BANKEDSTR` room text, `GP.BANKED` code, `KV` game
   state, a `SPLIT`/`STRCASE` parser, one PRG plus `.OVL`. Needs story content. Large.

A picture slideshow was dropped, because BMXVIEWER covers it.

**Number 1 was built 2026-10-01** and added to `release.sh` the same day as
`SAMPLES/MANDELBROT-SPEED/`. The user chose a
per-cell `GP.ASM` blob, a 40x28 picture, a key to start, and APPSYS save and restore. Times:
ROM 6,048 jiffies, GPC 3,075 (1.97x), GP.ASM 284 (21.3x). Fixed-point maths in BASIC was slower
both ways, so it was dropped. The folder `readme.md` holds the rest.

**How to apply:** when the user asks for the next demo, start from this list. Related:
[[release-samples-shape]], [[samples-build-in-place]], [[ask-before-writing-asm]].
