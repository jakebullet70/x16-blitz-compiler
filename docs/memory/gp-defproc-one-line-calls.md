---
name: gp-defproc-one-line-calls
description: BUILT -- GP.DEFPROC/GP.SUB/GP.FN call a BASL routine in one statement; the verb lives in the variable list, GP.SUB costs one byte a declaration, and GP.FN's four runtime opcodes fit in GP block padding
metadata:
  type: project
---

`GP.DEFPROC <verb> [,<formal> ...]` declares the routine on the line that follows and names the
variables its callers fill in; `GP.SUB <verb> [,<expr> ...]` assigns each expression to its formal
and calls it. `GP.FN(<verb> [,<expr> ...])` does the same from inside an expression and gives back
the variable the declaration named after `RETURNS`. Built 2026-09-08, tokens 52817, 52816, 52815 and
52814. **+875 bytes of GPC.BIN over HEAD, 0 of program size, and `StorageEnd` does not move** —
every byte of working storage went to the code section, by Wall 2's precedent.

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

**A FORMAL MUST BE A PLAIN SCALAR, so an array-indexed API gets the one-line call and no
argument passing at all.** `GetReferenceTerm` returns a negative type for an array and the formal is
refused. XBase's `DBBANK.INC.BL` is the case: its convention is that a record is an array element
(`DB.FILE$(DB.A)`, `DB.FLD$(0, 2)`, `DB.RECNO(DB.A)`), so of its twenty-one shims only three read
scalars and can take formals -- `DB.SELECT`, `DB.FIND` and `DB.FINDFLD`. The other eighteen declare
a verb worth nothing over the `GOSUB` it replaces. Check what a module's arguments actually ARE
before expecting `GP.SUB` to carry them.

**`GP.FN` NEEDED FOUR RUNTIME OPCODES AND THEY COST A PROGRAM NOTHING.** `MainCompileLoop` emits a
line marker before every source line and `CommandNewLine` resets the string system and empties the
evaluation stack, so a call into a multi-line body from mid-expression would wipe the caller's
half-built expression. `.fnsave` `$F1` pushes the live stack onto the frame stack, one frame a slot,
and drops the string temporary base below the caller's live temporaries; `.fnrestore` `$F2` puts
both back. With `.fnpush`/`.fnpop` below that is 252 bytes — which went into the padding in
`source/main/05rtcore.divider` that carries the GP block up to `RTBASE`, leaving 675 of the 927
that were there. `RTGPBASE $6600` and `RTBASE $6E00` did not move, so max program size is
unchanged. The runtime image ends at `$9D01` with 511 bytes to `$9F00`, and that is the figure to
watch.

**A VERB'S FORMALS ARE SHARED VARIABLES, WHICH IS WHY THE CALL IS FREE AND WHY RECURSION IS NOT
CHECKED.** A verb may appear inside its own argument list — `GP.FN(AREA, 2, GP.FN(AREA, 3, 4))` is
correct, because the whole list is evaluated before any of it is stored and the stores then come off
the evaluation stack last formal first. **A verb's BODY calling its own verb is not**: it writes over
the arguments in use, compiles clean, both passes agree, and the answer is wrong. Detecting it needs
a call graph the compiler does not build; it is a rule in `GP-BASIC.md` §3.11 instead. Storing each
argument as it compiled was the actual defect this fix came from — 36 for what the longhand made 24
([[measure-before-changing-code]]).

**AND THEN THE ARGUMENTS MOVED OFF THE EVALUATION STACK TOO.** Evaluating the list before storing
any of it put N formals into N of the twelve `MathStackSize` slots where one had done, and **there
is no overflow check anywhere in the runtime** — `NSStatus,x` at x=12 is `NSMantissa0[0]`, the
bottom of the same stack, so overflowing it corrupts a live value silently. `PROC_MAXFORMALS` is
also 12, so a twelve-formal verb sat on the edge of it. `.fnpush` `$F3` sends each evaluated
argument to the frame stack as a `FRAME_FNSLOT` — the frame `.fnsave` already uses, because that
is what an argument waiting for a call is — and `.fnpop` `$F4` brings it back in front of the
store that consumes it. A call then holds ONE argument at a time however many it has, so the
formal count caps nothing and the 4K frame stack, which `StackOpenFrame` checks, is what a long
list runs into. **The last argument is never pushed**: evaluated last, stored first, nothing
between — so a one-formal verb emits neither opcode. **2 bytes of p-code an argument after the
first** (`DEFP3` 528 → 532, its one three-formal call site) and **~360 cycles**, or ~80 for an
argument a nested `GP.FN`'s `.fnsave` would have moved anyway. `GP.SUB` pays it with nothing to
offset against, which is the honest price. `testing/DEFFNS.BASL` is the test: twelve formals and a
four-term last argument, called both ways, both giving 11.

Tests are `testing/DEFP1|DEFP1B|DEFP1C|DEFP2.BASL` and five refusals `DEFPV`..`DEFPZ`. `DEFP3` is
that whole front door -- **twenty-one verbs in one program**, three of them with formals -- against
its longhand control `DEFP3C`: **two bytes at each of the twenty-one call sites**, so nothing about
the cost changes with the number of records, plus the four `.fnpush`/`.fnpop` bytes its one
three-formal call site now carries — 532 of p-code against `DEFP3C`'s 528. `GP.FN` has
`source/unit-tests/fntest.py`, twelve programs and `FAILURES: 0`: `DEFFN1` against `DEFFN1C`, the
`DEFP3` pair carried in the same harness because both keywords share `ProcCompileArguments`,
`DEFFN2`/`DEFFN3`/`DEFFN4` for the multi-line body shapes, `DEFFNS` for the twelve-formal stack
case, and four refusals `DEFFNW`..`DEFFNZ`.

**Building it, the whole failure was a stale installed runtime** — see
[[make-libs-does-not-install-the-runtime]]. Plan and measurements: `docs/blitz/GP-DEFPROC.PLAN.md`
§9 and §10. Reference entries are `GP-BASIC.md` §3.11, which `MKHELP.PY` turns into the on-machine help.
