---
name: gpc-input-empty-line
description: "An empty RETURN at INPUT gives \"\" (or 0) in GPC; ROM R49 keeps the variable's old value. A chosen divergence, fixed 2026-09-29"
metadata:
  node_type: memory
  type: project
  originSessionId: 31483210-c8c1-490c-83c9-a28dc1e25b64
  modified: 2026-09-29T13:24:25.798Z
---

**An empty RETURN at `INPUT` gives `""`, or 0 for a number, and the program carries on.** Fixed
2026-09-29 in `source/runtime/source/commands/input.asm`. Before the fix, GPC re-prompted with `?`
for ever, so a "RETURN alone to stop" loop could never stop. BMXVIEW is where it showed.

ROM R49 does something different: the program continues and **the variable keeps its old value**.
The user chose `""` over matching the ROM. Matching it would need the compiler to skip the store
after each INPUT item.

The trap in the code: `GetStringToBuffer` (read.asm) treats a line end at the start of an item as
"go on to the next line", which DATA needs. So `InputStringToBuffer` catches the empty line itself,
and `InputBufferPos = $FF` (`InputNoLine`) is what marks "no line in hand".

**Why it went unseen:** the skip was a deliberate 2023 design ("Ignore blank lines" in the compiler
notes), and no test typed at an INPUT until [[paste-cannot-drive-a-running-program]] got its
kbdbuf_put trick. The test is `source/scratch/inptest/INPTEST.BASL`.

**How to apply:** do not "fix" this back towards the ROM without asking. `INPUT#` now returns `""`
for an empty line in a file instead of skipping it. Related: [[blitz-x16-basic-conformance]].
