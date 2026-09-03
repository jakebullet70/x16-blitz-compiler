---
name: gpc-string-blocks-never-shrink
description: "A Blitz string variable owns its block and capacity never shrinks -- the fix for a big temporary is to never build it, not to free it"
metadata:
  type: project
---

**`A$ = ""` does NOT give memory back.** A string variable OWNS its block; the assignment sets the
length to 0 and keeps the capacity. The heap scavenger ([[string-heap-scavenger]]) only reclaims a
block a string **outgrew** and abandoned -- never one a variable still holds. So a working buffer
that has once seen a 250-character line is spoken for until the program ends.

**Therefore: in this runtime you do not free a big temporary, you avoid creating it.** Measured
2026-09-02 -- the editor's `ED.FIND.NEXT` folded the needle *and every line it scanned* into new
strings (`ED.FOLD.IN$`, `ED.FOLD.OUT$`, `ED.HAY$`) and compared with `MID$` per position: **579
bytes gone for the rest of the run** from a workspace with 1,489 free, which is what the GUI
dialogs then died on. Rewritten as `GP.ASM` case-folding **in place** through `GP.STRPTR` plus one
`GP.INSTR` per line -- `GP.INSTR(hay$, needle$, start)` takes a 1-based start, so no slicing is
needed -- a find costs **81 bytes**, and the program got 59 bytes SMALLER.

The same rule killed the loader's cost: `LINE.TEXT$ = LINE.TEXT$ + CHR$(c)` per byte is one
allocation per character. See [[gpc-editor-loader-linput-and-blob]].

**How to find this class of bug in two minutes, not two days:** `PRINT FRE(0)` at ~8 points down
the run and read the descent -- it is a high-water ceiling, so it only falls, and the step that
falls is the culprit. Two rounds of plausible p-code shaving bought 18 bytes; one probe run found
the 579. See [[measure-before-changing-code]].
