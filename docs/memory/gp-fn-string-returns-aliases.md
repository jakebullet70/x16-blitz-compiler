---
name: gp-fn-string-returns-aliases
description: OPEN BUG -- two GP.FN calls on the same string-returning verb, adjacent in one expression, both give the second answer
metadata:
  type: project
---

**OPEN BUG, found and confirmed 08/09/26. To fix.** Two `GP.FN` calls on the **same** verb, with
nothing between them in one expression, both read that verb's single `RETURNS` variable, so both
terms come out as the second call's answer. Silently, with both passes agreeing.

```basl
D$ = "one"
E$ = "two"
PRINT GP.FN(STR.UCASE, D$) + GP.FN(STR.UCASE, E$)
```

prints `TWOTWO` where `ONETWO` is intended. Recorded as line `D1` in `testing/SCASE.BASL`.

**Why:** a string term is a REFERENCE, not a value. `ReadStringCommand`
(`source/runtime/source/memory/read_string.asm`) pushes the block ADDRESS into `NSMantissa0/1,x`,
and `GPFNCompile` (`source/compiler/source/commands/gpdefproc.asm:556-566`) ends with a plain
`GetSetVariable` read of the `RETURNS` variable. Two calls therefore leave two references to one
variable, and the second call overwrites what the first one pointed at.

**Numeric verbs are safe** -- the value itself goes on the evaluation stack.

**These escape it:**

- `GP.FN(V,A$) + "-" + GP.FN(V,B$)` -- `+` is left-associative, so the first concat concretes A
  into a string temporary before the second call runs. An accident, not a rule to hold.
- Two DIFFERENT verbs in one expression -- they have different `RETURNS` variables.

**Two ways out.** Document it in `GP-BASIC.md` §3.11 beside the recursion rule; or fix it at the
call site -- after `.fnrestore`, when `procRetType` is a string, emit whatever concretes it into a
temporary. The fix costs p-code on every string `GP.FN` call and nothing on numeric ones, and
resident p-code is the side that is short of room.

Related: [[gp-defproc-one-line-calls]], [[gpc-string-blocks-never-shrink]].
