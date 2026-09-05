---
name: menuhelp-use-the-whole-interface
description: "MENUVERT works; the editor's broken dropdown was a caller that set three fields of the interface and hand-rolled the rest - and MDPROBE is the way to prove which side is wrong"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 5591d6bc-636d-4001-b0b0-d858156d6ec0
  modified: 2026-08-31T12:10:57.230Z
---

**The module was called `MENUHELP.INC.BL` when this was written and is `MENUVERT.INC.BL` now.**

**When a shipped library "does not work", build its own example headlessly before touching
it.** `MENUVERT.INC.BL` was suspected for most of a session over a dropdown that drew the
wrong height with rows missing. It was never the library.

`GPC-BASIC/MENUDEMO.EXP.BL` is MENUVERT's documented example. Copied into a work dir with
`GPB/THEME/MENUVERT.INC.BL`, with `MENUVERT.RUN` swapped for `MENUVERT.DRAW` and a VPEEK
loop over the tile map at `45056 + row * 256 + col * 2` printed after a `CHR$(147)`, it
renders **perfectly** — 5 items, 5 rows, frame above and below. That took one build to
establish and settled the question outright.

**The actual defect: the caller used three fields of a nine-field interface.**
`ED.DRAW.DROPDOWN` set `MENUVERT.X`, `.Y` and `.WIDTH`, then hand-rolled a `FOR` loop
poking `.DRAWROW`/`.DRAWATTR` into `MENUVERT.ROW` — the module's *lowest* entry point —
leaving `.COUNT`, `.ATTR` and `.HIATTR` at zero. `MENUVERT.ROW` reads `MENUVERT.ATTR`
itself (it is the test at its tail that decides whether a row gets its hotkey tinted), so
a caller that never sets it is not calling the routine, it is guessing at it. Setting the
documented inputs and calling `MENUVERT.DRAW` was **5 bytes smaller** (`OK CODE 9650` ->
`9645`).

**Two habits this cost a session:**

- **Read the module's own example first.** The difference between MENUDEMO's nine
  assignments and the editor's three was visible in a side-by-side read, before any
  emulator ran.
- **One sampled cell is not a test of a panel.** The self-check asserted `DD CH=`/`AT=`
  on a single VPEEK and was green the whole time the panel was the wrong height with rows
  missing. Geometry needs the whole shape walked: frame row, every item row, frame row.

Related: [[gpc-editor-is-ascii-inside-petscii-outside]], [[answer-the-question-asked]].
