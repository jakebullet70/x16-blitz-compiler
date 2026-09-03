---
name: editor-return-is-the-line-table
description: "The editor's slow RETURN was the line-table shift — fixed with a GP.ASM memmove, 87x, and the segment boundary is the trap that hides from every short document"
metadata:
  node_type: memory
  type: project
  originSessionId: 5591d6bc-636d-4001-b0b0-d858156d6ec0
  modified: 2026-09-02T08:00:00.000Z
---

**FIXED 2026-09-02.** "Inserting a blank line scrolls slowly" was never the scrolling: 75% of a
RETURN was `DOC.INSERT.SLOT` walking the line table one entry at a time in BASIC.

**Measured old against new in ONE program on ONE fixture** (`samples/editor/SLOTBEN.BASL`, which
carries a verbatim copy of the old loops so the comparison owes nothing to two builds). 100 lines,
at index 1, ten reps, `--nowarp`:

| | old | new |
|---|---:|---:|
| `DOC.INSERT.SLOT` | 435 j | **5 j** (87x) |
| `DOC.DELETE.SLOT` | 396 j | **5 j** (79x) |

The old insert measured 435 against the 447 recorded the day before — the harness agreeing with
itself, which is worth more than either number alone.

**The shape: BASIC decides WHICH BYTES MOVE, assembly moves them.** The shift is +/- one entry, so
source and destination overlap and **direction is the whole correctness argument** — insert copies
top-down so it cannot eat its own source, delete bottom-up. Chunking (255 bytes at a time, because
Y is 8-bit) preserves it: insert takes chunks from the top, delete from the bottom.

**Patch the operands, do not use zero page.** `STA MDS,X` with X=1/2 patching a `LDA $FFFF,Y` is the
idiom `EDITOR.BASL`'s renderers already use, and it costs no assumption about where the runtime
keeps `zTemp0`. (For the record it is `$2c/$2e/$30` in the runtime image and `$26/$28/$2a` in the
compiler link — two different numbers, which is reason enough not to hardcode either.)

**THE SEGMENT BOUNDARY IS THE TRAP.** The table is banks 1..3 at 2048 entries and one bank is
selected for a whole copy, so the single entry whose destination lands in the NEXT bank cannot go
through the block — those go the old per-entry way, at most two per shift. **A document under 2048
lines never crosses one**, so a naive block passes every casual test and corrupts the first long
file it meets. `samples/editor/SLOTTST.BASL` is the guard: 2,100 entries, **every slot checked, not
a sample**, twelve cases at 5 / 0 / 2040 / 2047 / 2048 / last.

**It cost 481 bytes** (object 15,086 -> 15,567). Unlike the renderers, which came out smaller, this
adds segment-and-chunk arithmetic that did not exist. Headroom is `FREE - 4096` — see
[[program-too-big-fires-early]].

**The repaint is now the dominant cost** (~102 j of the ~160 a RETURN takes), which it was not
before. Repainting from `ED.CUR.ROW` down is the next move, and only now worth making.

Related: [[gpasm-implementation-status]], [[headless-basl-build-recipe]],
[[gpasm-blob-may-use-ztemp]].
