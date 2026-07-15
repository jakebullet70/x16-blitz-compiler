---
name: blitz-x16-basic-conformance
description: Blitz-vs-stock-X16-BASIC conformance — all four defects fixed, plus the float PRINTER bug found underneath them
metadata:
  type: project
---

Ran the [[gpc-x16-basic-coverage]] lexer-blocker list and the [[gpc-for-step0-semantics]] / [[gpc-if-semantics]] semantics
checks against the **compiled** Blitz output, with stock X16 BASIC (interpreted, R49) as the control. Method: tokenise with
`bin/tokenise.zip`, compile via `GPC.BLITZ.PRG` under `bin/x16emu`, run `OBJECT.PRG`, compare printed output. NB the emulator does
not self-exit for these, so each run must be `timeout`-capped; and `-bas` injection types through the keyboard, so control
programs must be **UPPERCASE**. A compiled program can end with `I2CPOKE 66,1,0` to power the machine off (Blitz has no
`POWEROFF` handler), which makes the emulator exit immediately.

**PASSES** (Blitz already handled these): hex `$FF` · binary `%1010` · decimals >= 65536 · identifiers > 7 chars ·
`IF` line semantics (a false `IF` correctly skips the WHOLE line).

## ALL FOUR FIXED (2026-07-13)

- **`FOR ... STEP 0`** — was worse than recorded. `next.asm` branched on the step's sign BIT, giving only two cases, so a zero
  step took the ascending path and exited at once. AND `for.asm`'s optimised integer path did not exclude a zero step: its
  carry-propagating increment never terminates when adding 0 to a 0 byte, so `FOR I=0 TO 5 STEP 0` compiled fine and then
  **hung forever**. Now a three-way test, and a zero step is kept out of the optimised path.
- **Reversed relationals** — `><`, `=<`, `=>` were syntax errors. All six spellings now fold to the three real operators.
- **Scientific notation** — `9.2E5` now compiles. The trap: **the exponent's sign is a TOKEN, not ASCII** (`$AB`, not `$2D`),
  because the encoder is fed tokenised text.
- **Float literals** — `0.5` compiled to `0.4999999998`. The fraction was built as `digits x 10^-dc` from a table of NEGATIVE
  powers, and `10^-n` can never be exact (1/10 is not a binary fraction); worse, the error was LOW. Now the table holds
  POSITIVE powers and we **divide** by them — `Int32ShiftDivide` is exact whenever the quotient is, so `5/10` lands on 0.5
  exactly. **The table entries must be plain INTEGERS, not normalised floats:** `FloatMultiply` has an integer fast path that
  is exact whenever the product fits and *returns an integer*, whereas a normalised operand forces the truncating float path
  and returns a float. Both compute `9E5` correctly, but only the integer one prints as `900000`.

## The real prize: the float PRINTER was adding a whole ULP

Hunting the literal bug turned up something worse, and entirely pre-existing:

```basic
PRINT 1000000000-999999999     ->  1.5      (!!)
PRINT 0.5*1e9                  ->  500000000.25
```

Nothing was wrong with the arithmetic. The compiler emitted both constants perfectly (`CE 00 00 CA 9A 3B` /
`CE 00 FF C9 9A 3B`), the runtime loaded them correctly, and an assembly probe proved `FloatSubtract` returned **exactly**
1.0. Feeding exactly 1.0 (mantissa 2, exponent -1) straight into `FloatToString` produced the string `" 1.5"`.

`tostring.asm` rounded by adding `1 x 2^exponent` — **one whole ULP of the BINARY mantissa** — to stop values printing as
`6.999999`. But a binary ULP has nothing to do with the decimal place being rounded to, and on a large value it is enormous:
1.0 held as `2 x 2^-1` has a ULP of 0.5. Now it adds half of the last decimal place actually printed (`5 x 10^-(dp+1)`), and
trailing zeros are trimmed afterwards. That also fixed `3.14159` printing as `3.1415900`, made `2/3` round to `.6666667`
instead of truncating, and absorbed the sub-ULP shortfall that had made `1.5E-2` print as `0.0149999`.

Pulling that thread turned up two more, both pre-existing and both in the same area:

- **`FloatFractionalPart` was broken for every value >= 2^30** (`fractional.asm`). The bits above the point are
  `exponent+32`, but it worked that out with an unsigned `sbc #$E0` and branched on the borrow. The exponent is **signed**,
  so any exponent >= 0 underflows, carry clears, and the value is declared "already fractional" and handed back whole. So
  `PRINT 2000000000` printed `2000000000.125`. `FloatIntegerPart` right next door gets this right with a plain `bpl` — a
  normalised value with a non-negative exponent is a whole number — and `FloatFractionalPart` now tests it the same way.
  This is very likely the old TODO about long integers loading wrong.
- **The printer bailed out as soon as the remainder fell below ~4e-6** (a `cmp #$D0` guard), which silently ate the
  significant digits of small numbers: `0.0000001` printed as `0.0`. With rounding now correct and the loop already bounded
  by `decimalPlaces`, there is nothing to guard against; it simply runs until the remainder is zero.

**Why this survived since 2023, and the thing to remember:** the randomised ifloat32 / compiler-runtime suites assert with
`f.cmp =`, which is `FloatCompare` — and `FloatCompare` deliberately **ignores the low 12 bits** of a float difference
(`compare.asm`, ~1 part in 2^18). A 1-ULP error is ~8000x finer than that tolerance, so **the suites are structurally blind to
ULP bugs and always will be.** This is also the answer to the old "compare and subtract disagree about equality" note: they
never claimed the same thing. `FloatAdd`/`FloatSubtract` are exact and deliberately **do not normalise** their result
(`addsub.asm` says so), while `IF A=B` is an approximate compare by design. Nothing to fix there.

To check float internals, bypass BASIC entirely: hand-build the stack slots in a small `.asm`, `jsr` the routine, store the
6 result bytes to a fixed address, and read them out of the emulator's `-dump R` image. That is the only way to see the bits;
`PRINT` cannot be trusted as a readout, which is exactly what cost time here.

## Still open

- **Cosmetic only:** Blitz prints `0.5`, real X16 BASIC prints `.5` (no leading zero). Trailing zeros are now gone.
- `STR$` passes 8 decimal places, `PRINT` passes 7 — both go through the same rounding now.

See [[blitz-x16-r44-plus-keywords]] and [[blitz-x16-build-setup]].
