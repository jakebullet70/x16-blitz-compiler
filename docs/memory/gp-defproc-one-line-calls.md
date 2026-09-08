---
name: gp-defproc-one-line-calls
description: BUILT -- GP.DEFPROC/GP.SUB call a BASL routine in one statement; the verb lives in the variable list, and the only cost is one byte a declaration
metadata:
  type: project
---

`GP.DEFPROC <verb> [,<formal> ...]` declares the routine on the line that follows and names the
variables its callers fill in; `GP.SUB <verb> [,<expr> ...]` assigns each expression to its formal
and calls it. Built 2026-09-08, tokens 52817 and 52816. **+672 bytes of GPC.BIN, 0 of runtime, 0 of
program size, and `StorageEnd` does not move** — every byte of working storage went to the code
section, by Wall 2's precedent.

**The verb is an ordinary NAME, in the variable list — there is no proc table.** `DEF FN` claims
bit 7 of the second name byte to keep `FNA` apart from the variable `A`; **bit 6 was free** and is
what marks a verb, so a verb cannot collide with a variable, an `FN`, or `TI`/`TI$`/`ST`. A variable
record is already variable-length — byte 0 is its size and `FindVariable` walks by it — so a proc
record just runs on: byte 5 is the formal count, which `FindVariable` hands back in A anyway, and
three bytes a formal after it (address low, address high, type), which is exactly what
`GetSetVariable` takes. Create the record AFTER reading the formals: reading one may create a
variable record of its own on the space the proc record is about to grow into.

**The call site costs nothing, and a declaration costs one byte.** Two identical programs, one using
the keywords and one written out longhand, both compile to 423 bytes and differ in ten bytes: two at
each of five call sites (`.fngosub $E9` for `.gosub $E4`, and the operand one higher, because
`.fngosub` enters just past the line marker the label points at). The one byte is the LINE and not
the keyword — every source line emits a `new.line` marker — so a declaration folded onto the shim's
own statement line costs nothing at all. Folding it onto a BARE label line does not:
[[folding-onto-a-label-line-saves-nothing]].

**A GP.SUB must sit below its GP.DEFPROC**, because `.fngosub` carries an address and not a line
number, and it is refused by name. `WriteBranchToAddress` corrects the operand in both directions,
so the [[gp-banked-region-relocation]] shim pattern works: declaration on a low memory shim whose
body is at `$A000`, and a `GP.SUB` inside a region reaching back down.

Tests are `testing/DEFP1|DEFP1B|DEFP1C|DEFP2.BASL` and five refusals `DEFPV`..`DEFPZ`. **`GP.FN` and
`RETURNS` are NOT built** — and `RETURNS` will need a `#TOKEN` of its own, because BASLOAD crunches
a bare word as a variable and the compiler never sees it; `TO` (token $A4) is the free alternative.
The buffers holding one call's formals are flat, which is safe only because `GP.SUB` is a statement;
`GP.FN` is an expression term and will need them as a stack. Plan and measurements:
`docs/blitz/GP-DEFPROC.PLAN.md`.
