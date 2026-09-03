---
name: gpc-editor-branch-and-gui-next
description: "Where samples/editor stands on feature/editor-petscii as of 2026-08-31, and the GUI.INC.BL library that is the next piece of work"
metadata: 
  node_type: memory
  type: project
  originSessionId: 5591d6bc-636d-4001-b0b0-d858156d6ec0
  modified: 2026-09-01T19:00:03.265Z
---

**UPDATED 2026-09-01 (end of session).** `feature/editor-petscii` is pushed and clean at
`2c42d25`, still off `main`. Build: **`OK CODE 15166 FREE 6144 RT 13055 GP-BASIC IN`**
(`FREE` here is runtime workspace, NOT compile headroom — see
[[program-too-big-fires-early]]). `GUI.INC.BL` SHIPPED and is in use by the editor.

Landed that day: `GUI.FRAME` reduced to one `GP.BOX` custom-glyph call (70 bytes, and the
`+64` tile bias is gone — the `ED.GL.*` defines are now the real indices 192..197);
`GUI.YN.WAIT` rewritten as a `GP.SELECT`; the menu bar moved to `MENUBAR.INC.BL` with a
targeted two-title repaint; and a comment-density sweep of `EDITOR.BASL`, `STORE.BASL` and
`GUI.INC.BL` (see [[comments-light-code-should-flow]]). Tracked sample binaries were stale
and are rebuilt.

**Next session, agreed: switch to the COMPILER and chase
[[program-too-big-fires-early]].** After that, in the editor:
[[editor-return-is-the-line-table]] (a `GP.ASM` memmove for `DOC.INSERT.SLOT` and
`DOC.DELETE.SLOT`), then a listbox for `GUI.INC.BL` — both written up in `TODO.md`.

---

**As of 2026-08-31.** `feature/editor-petscii` is pushed and tracking origin, **six
commits ahead of `main`** (`main` is still `88a58fe`, deliberately untouched — the user
said "stay off of main"). Build: `OK CODE 10746 FREE 9728 RT 14079 GP-BASIC IN`.

What landed, in order: MENUHELP driven through its real interface; the menu key loop
refactored to `GP.DO` + `GP.SELECT`; a single-line dropdown frame; ALT+letter via the
keyboard layout; the dropdown recoloured to the document's own attribute; and
`editor-demo.bat`.

**The editor now works end to end** — thin-framed dropdowns, ALT+F/S/H **and** ESC-then-
letter, dark panel with a blue highlight bar. `editor-demo.bat` at the repo root runs it
with `samples\editor` as the drive; `C.EDITOR.PRG` is checked in so a fresh clone needs no
build. **File>Save overwrites the real `TEST.MD`** because that directory *is* the drive.

**Self-check assertions to keep green** (`DEBUG.MODE = 1`, then look for `M4 OK`):

```
ALTKEYS N= 3 PLAIN= 41600 ALT= 41984
DDROWS 192 78 79 83 83 69 192
MENU 600 OPENS MSG=GPC EDIT -- a simple X16 text editor
MENU LETTER H ->  2 (want 2)
```

**Next: `GPC-BASIC/GUI.INC.BL`**, for the *main* gpc branch, in the house style of the
other `*.INC.BL` files (banner block, `#IFNDEF x.DEFS`, `GOTO x.MODULE.END`, whole name
space owned, theme colours). Three entry points — `GUI.YN` (1-2 line question, Y/N),
`GUI.MENU` (a box around `MENUHELP`), `GUI.TEXT` (question plus one line of input via
`INPHELP`) — plus `GUI.EXP.BL` demonstrating them.

**It must not inherit the editor's quirks.** `samples/editor` re-orders the font, which is
why only `GP.BOX` style 0 works *there*; a main-branch library draws on the stock charset
where the line styles are fine — see [[gp-draw-under-a-reordered-font]].

Related: [[menuhelp-use-the-whole-interface]], [[gpc-editor-alt-keys-need-the-keymap]],
[[headless-basl-build-recipe]], [[gpc-editor-is-ascii-inside-petscii-outside]].
