---
name: blitz-x16-basic-conformance
description: Blitz-vs-stock-X16-BASIC conformance results (2026-07-13) — 4 real defects found
metadata:
  type: project
---

Ran the [[gpc-x16-basic-coverage]] lexer-blocker list and the [[gpc-for-step0-semantics]] / [[gpc-if-semantics]] semantics
checks against the **compiled** Blitz output, with stock X16 BASIC (interpreted, R49) as the control. Method: tokenise with
`bin/tokenise.zip`, compile via `BLITZ.PRG` under `bin/x16emu`, run `OBJECT.PRG`, compare printed output. NB the emulator does
not self-exit for these, so each run must be `timeout`-capped; and `-bas` injection types through the keyboard, so control
programs must be **UPPERCASE**.

**PASSES** (Blitz already handles these; they were GPC blockers):
hex literals `$FF` · binary literals `%1010` · decimals >= 65536 (`1000000`) · identifiers > 7 chars ·
`IF` line semantics (a false `IF` correctly skips the WHOLE line, incl. every colon-separated statement after THEN).

**DEFECTS FOUND:**

1. **Decimal fraction literals are one ULP low.** `A=0.5` (and `.5`) stores `0.5 - 2^-31` and PRINTs as `0.4999999`; stock X16
   BASIC gives `.5`. Computed `1/2` IS exact, so the fault is the compiler's decimal->iFloat32 **literal** conversion
   (truncates instead of round-to-nearest), not the arithmetic. `0.25` happens to land exact. Diagnostic: `A=0.5 : B=1/2 :
   PRINT (A-B)*10000000` -> `-0.0046566`, i.e. `A-B = -2^-31` exactly. Start at
   `source/compiler/source/helpers/constant.asm` + the ifloat32 fractional conversion.
   **Related inconsistency:** `IF A=B` reports SAME even though `A-B <> 0` — so iFloat32's compare and subtract disagree about
   equality. Worth understanding before "fixing" either.

2. **`FOR ... STEP 0` terminates after one iteration.** `source/runtime/source/commands/next.asm` branches on the step's SIGN
   BIT (`bmi _CNDownStep`), giving only two cases, so a zero step falls into the ascending path and exits as soon as
   `loopvar > limit`. Correct CBM/X16 rule: exit iff `compare(loopvar,limit) == sign(step)` and `sign(0)==0`, i.e. a zero step
   exits ONLY on exact equality. So `FOR I=0 TO -1 STEP 0` (a real idiom — loop until you set I to the limit) dies immediately.
   Test: expects 3, gets 1. This is the SAME bug GPC had; see [[gpc-for-step0-semantics]] for the ROM citation
   (`ref/x16-rom/basic/code8.s`).

3. **Scientific notation is not accepted.** `A=9.2E5` -> compile error. Valid X16 BASIC.

4. **Reversed relationals are not accepted.** `IF 1 => 1` -> compile error. CBM/X16 folds `<`,`=`,`>` in ANY order, so all of
   `=<` `=>` `><` are legal.

**Cosmetic (not a value bug):** Blitz PRINTs `0.5` / `0.25`; real X16 BASIC prints `.5` / `.25` (no leading zero). Matters if
compiled output should be indistinguishable from BASIC.

Note items 3 and 4 are LEXER/compiler gaps and item 2 is a RUNTIME gap — they sit in different layers. See
[[blitz-x16-build-setup]] for how to build and run these checks.
