---
name: comments-light-code-should-flow
description: "Go light on REMs — a note or two, not essays. Heavy commenting is a symptom of code that does not flow and variables that are not named right."
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 5591d6bc-636d-4001-b0b0-d858156d6ec0
  modified: 2026-09-01T18:59:49.453Z
---

**User, 2026-09-01, with 40+ years of paid programming behind it:**

> there are too many, code needs to be written so it flows and the programmer can follow it,
> when there are lots of REMs it might look good to an employer counting lines but to me it
> means the code is not flowing, the vars are not named right. So, lets go lighter on the REMs,
> keep adding them but more concise, just a note or two

**Why:** a wall of comment is a smell, not a service. If a routine needs fifteen lines of prose to
be followable, the fix is the naming and the shape of the code, not more prose. Volume also reads as
line-count padding rather than care.

**How to apply:** keep commenting, but a note or two. Say the thing that is NOT visible in the code
— an ordering constraint, a hardware quirk, why the obvious approach fails — and stop. Do not narrate
what the next line does, do not restate the routine's inputs when the header already lists them, and
do not write the history of a decision where one clause will do.

Concrete calibration from the same day: my `GUI.FRAME` header was ~40 lines of rationale for an
8-line routine. Rewritten it is 10 lines of interface plus ONE note — that the glyphs are tile
indices and not PETSCII, which is the only part a caller cannot see. That is the right density.

This does not license deleting a constraint. When trimming, keep the rules a future editor could
break unknowingly — see the `GUI.YN.MARK` "first match wins, so the order of the two mark calls
matters" note. Compress it to a line; do not drop it.

**A COMMENT LEFT TOO LONG IS USUALLY ALSO A COMMENT LEFT WRONG, and the length is what hides it.**
Every file swept on 2026-09-01 had stale blocks: `EDITOR.BASL` still explained the `+64` glyph bias
in three places after `GUI.FRAME` removed it (one of them in the self-check, giving a stale reason
for a correct expectation) and described the dropdown frame two contradictory ways forty lines apart;
`GUI.INC.BL` still documented `GUI.GLYPH` as `GP.FILL` arguments. **Read for staleness while
trimming — that is where the value is, not in the line count.**

**Method that makes it safe**, and reusable: write it as a script of exact comment-block
replacements rather than a rewrite, then prove the code did not move —
`grep -v -E '^[[:space:]]*(##|REM([[:space:]]|$))'` old vs new must be identical — and rebuild to
confirm the object is unchanged. Both editor rebuilds landed on `OK CODE 15166 RT 13055`.

**Two traps in this repo:** `EDBENCH.BASL`'s `REM`s are the **GP.ASM source itself** under `#REM 1`
and must not be touched, and `GUI.INC.BL` exists in **two copies** (`GPC-BASIC/` and
`samples/editor/GPC-BASIC/`) that have to stay identical.

**Progress:** `samples/editor/EDITOR.BASL` (709 → 423 prose lines), `STORE.BASL` and
`GPC-BASIC/GUI.INC.BL` (372 → 256) are done. A library module cuts less than a sample — its
parameter table and per-routine in/out blocks are what a caller opens the file to read, so `GUI`
cut 31% against the editor's 40%. Twelve `GPC-BASIC/*.INC.BL` remain, worst first `STRCASE` 90%,
`SORT` 89%, `GPB` 85%; the twelve `.EXP.BL` examples are unmeasured. Table is in `TODO.md`.
