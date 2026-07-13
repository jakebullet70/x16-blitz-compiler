# Benchmark results — Blitz-X16 vs stock X16 BASIC

Measured 2026-07-13, after the float multiply/add speedups.
Emulator `bin/x16emu` (r49 Pyrite), ROM R49. Run with `bash bench/run-bench.sh`.

Timing is `TI` (jiffies, 1/60 s) read **inside** the emulator, so it is independent of `-warp`.
Verified: the same program under `-warp` and without gives an identical count (285 both ways), and
that 285 reproduces GPC's recorded stock-BASIC baseline for `01_forloop` exactly — which
cross-validates the whole comparison. (A note in the GPC repo claims the 60 Hz timer freezes under
`-warp`; on this emulator it does not. Do not trust that note.)

| benchmark | stock | compiled | **speedup** | GPC | C64 Blitz |
|---|---:|---:|---:|---:|---:|
| 01_forloop   | 285 | 114 | **2.50×** | 1.4× | 1.3× |
| 02_floatmath | 572 | 331 | **1.73×** | 1.9× | 2.8× |
| 03_nested    | 773 | 210 | **3.68×** | 1.4× | 2.8× |
| 04_sieve     | 318 |  73 | **4.36×** | 1.0× | 3.1× |
| 05_string    | 217 |  56 | **3.88×** | 1.4× | 4.1× |
| 06_peek      | 179 |  54 | **3.31×** | 1.5× | 2.6× |
| 07_intmath   | 669 | 193 | **3.47×** | 1.4× | 2.7× |
| **GEOMEAN**  |     |     | **3.15×** | 1.41× | 2.65× |

*GPC* = the abandoned sibling P-code compiler (`../X16-GPCompiler/bench/RESULTS.md`).
*C64 Blitz* = the original Skyles compiler on a real C64, compiled-vs-uncompiled — the yardstick.

## Verdict

**3.15× geometric mean.** That beats the C64 Blitz yardstick (2.65×) and is **2.2× better than GPC**
(1.41×), which was abandoned for being too slow. The thesis holds: no ROM float calls, an automatic
integer fast path, and compile-time variable addressing are worth roughly double what a
ROM-float-backed P-code VM achieves.

Note `04_sieve` was **degenerate for GPC** (its 1.0× is an artefact — `DIM F(2000)` did not fit GPC's
array heap, so the sieve never sieved). It is a real measurement here: 12,006 bytes now allocates and
the array round-trips correctly. Blitz-X16's 4.36× also beats real C64 Blitz's 3.1× on the same work.

## `02_floatmath`: 1.25× → 1.73×

This was the one benchmark below 2×, and the only one where **both** GPC (1.9×) and C64 Blitz (2.8×)
beat us. The body is `X = I*1.5+2` — a genuine float multiply, so it fell entirely on `ifloat32`'s
*software* 32-bit multiply rather than the integer fast path.

Two byte-at-a-time shortcuts fixed most of it (456 → 331 jiffies):

- **`FloatMultiplyShort`** skips eight zero multiplier bits at once. Normalising shifts *left*, so an
  integer operand arrives packed with trailing zeros — `I=8000` normalises to `$7D000000`, eighteen of
  them — and the loop used to grind through every one a bit at a time.
- **`FloatAdd`**'s exponent alignment shifts the mantissa a byte at a time while it has 8 or more
  places still to go, instead of one bit per trip.

Both are pure loop shortcuts: truncation composes, so the results are **bit for bit identical**. That
was verified by diffing raw float bytes out of the emulator's RAM image for 18 cases (9 multiply,
9 add — integer fast paths, dense mantissas, both signs, alignments of exactly 7 and 8), because the
randomised suites *structurally cannot* see a 1-ULP change: they assert through `f.cmp`, which is
`FloatCompare`, and that deliberately ignores the low 12 bits of a difference.

What is left is fixed overhead, not an algorithmic hole: both operands get normalised on every call,
and for an integer operand that is work the byte-skip immediately undoes. Diminishing returns.

## Reproducing

```
bash bench/run-bench.sh
```
Each program powers the machine off when done so the emulator exits immediately. Both columns now run
byte-identical source: Blitz compiles `POWEROFF`, so the `I2CPOKE 66,1,0` substitution this script
used to make is gone. Stock BASIC is injected with `-bas`, which types the listing in through the
keyboard, so those sources must be **uppercase** (the script uppercases them).
