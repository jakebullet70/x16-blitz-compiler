---
name: vera-fx-cache-write-is-aligned
description: "The editor's row renderer writes two cells through VERA's FX cache, and that write is 4-byte aligned -- so a text column must be EVEN"
metadata:
  type: project
---

**`ED.ROW.STREAM` (`samples/editor/EDITOR.BASL`) writes TWO CELLS PER FLUSH through VERA's FX cache,
and the flush is 4-BYTE ALIGNED: it lands at `address AND NOT 3`.** So the destination column must be
EVEN. Column 0 is aligned, which is why nothing in this editor ever had to know -- until the line
number gutter put the text base at byte 10 (column 5). That rounded down to byte 8: the whole
document rendered one column left and overwrote the gutter's last cell.

**The symptom is silent and looks like an off-by-one in your own arithmetic.** `ED.ASM.BASE%` probed
as 266 -- exactly right -- while the characters appeared at column 4. Do not go looking for the bug
in the address computation; check the alignment first. Reading a RANGE of cells rather than one
(`GUT 32 32 32 49 35` -- a `#` where a space belonged) is what made it visible at all.

`ED.GUT.W` is therefore 6, not 5: four digit columns plus two blanks. The same trap waits for
anything that asks that block for an odd column, `ED.PUT.FIELD` included (it draws the bars at
column 0 today, so it is fine by luck).

Related: [[gp-draw-under-a-reordered-font]], [[gpc-editor-branch-and-gui-next]].
