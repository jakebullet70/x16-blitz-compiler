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

## Reviewing a crunch he hands back

**Check every merged line for an `IF` that is not LAST on it.** A false `IF` skips the WHOLE line,
so a statement joined after the THEN-clause silently becomes conditional. The `STRUSING` crunch was
clean; `GUI.INC.BL` 2026-09-07 was not, and merged `GOSUB GUI.CLOSE` onto
`IF GUI.OK = 0 THEN GUI.TEXT$ = GUI.WAS$`, so `GUI.INPUT` closed its box only on a cancel. Fix by
splitting, then fold the following statement onto the next line instead -- the byte comes back.

**Prove the rest mechanically, do not read it.** Split both versions on the statement separator and
diff the lists: same count, same order means only the grouping moved. That settled 86 statements in
`STRUSING` and 216 in `GUI` in seconds. See [[gpc-if-semantics]] and
[[folding-onto-a-label-line-saves-nothing]].

## A source file that changed and I did not change it

**Check it for line crunching, and if that is all it is, carry on without a word.** Standing note,
2026-09-09. The user crunches sources between turns, and a working copy that moved underneath a
session is his pass, not a conflict or a lost edit. Diff it the mechanical way above — same
statements, same order, fewer lines — and keep going.

**Why:** stopping to report "this file changed" on every crunch is noise, and re-expanding it would
undo his work. Only a difference that is NOT a crunch — a statement gone, an order changed, an `IF`
no longer last on its line — is worth raising. See [[user-runs-concurrent-agents-here]] for the case
where the change came from another agent instead.
