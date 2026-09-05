---
name: write-readable-code-user-crunches
description: "Write BASL expanded and readable; the user crunches lines himself, and dense code blocks his review"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 75714395-f705-4d27-8da6-af4a832a1e0b
  modified: 2026-09-05T14:15:32.485Z
---

**Write readable code first. Do not pre-crunch BASL to save lines or bytes.** Said 2026-09-05 after
a refactor of `BANKMGR.INC.BL`: *"write readible code 1st, I will crunch line myself. That helps me
to review your code."*

Three specifics settled at the same time:

1. **One statement a line.** Joining with `:` is the user's pass, not mine.
2. **A single-statement conditional is a plain `IF ... THEN <statement>`**, not a
   `GP.IF` / `GP.ENDIF` block. Blocks are for multi-statement bodies.
3. **NEVER put a statement on a label's line** — `BANKMGR.INIT: IF ...` is out. The user saw the
   idiom in the crunch program, dislikes it, and may still apply it himself in a final review.
   Nothing in the shipped library does it; every module gives a label its own line.

**Why:** dense lines are what he reads to review the logic, and crunching is a separate, later,
deliberate pass that belongs to him. Line-joining is also nearly free in p-code — the `BANKMGR`
crunch was 17 lines for 18 bytes — so it buys little and costs review.

**How to apply:** write it expanded, say what it measured, and leave the crunching alone. If a
program genuinely will not fit, say so and let him decide, rather than crunching pre-emptively.
See [[comments-light-code-should-flow]] and [[prose-style-is-flat-reference]] for the prose half,
and [[basl-cruncher-built]] for what a crunch pass is actually worth.
