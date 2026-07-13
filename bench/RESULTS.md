# Benchmark results — Blitz-X16 vs stock X16 BASIC

Measured 2026-07-13, after the memory reclamation (commit `7dadca6`).
Emulator `bin/x16emu` (r49 Pyrite), ROM R49. Run with `bash bench/run-bench.sh`.

Timing is `TI` (jiffies, 1/60 s) read **inside** the emulator, so it is independent of `-warp`.
Verified: the same program under `-warp` and without gives an identical count (285 both ways), and
that 285 reproduces GPC's recorded stock-BASIC baseline for `01_forloop` exactly — which
cross-validates the whole comparison. (A note in the GPC repo claims the 60 Hz timer freezes under
`-warp`; on this emulator it does not. Do not trust that note.)

| benchmark | stock | compiled | **speedup** | GPC | C64 Blitz |
|---|---:|---:|---:|---:|---:|
| 01_forloop   | 285 | 114 | **2.50×** | 1.4× | 1.3× |
| 02_floatmath | 572 | 456 | **1.25×** | 1.9× | 2.8× |
| 03_nested    | 773 | 210 | **3.68×** | 1.4× | 2.8× |
| 04_sieve     | 318 |  74 | **4.30×** | 1.0× | 3.1× |
| 05_string    | 217 |  56 | **3.88×** | 1.4× | 4.1× |
| 06_peek      | 179 |  54 | **3.31×** | 1.5× | 2.6× |
| 07_intmath   | 669 | 193 | **3.47×** | 1.4× | 2.7× |
| **GEOMEAN**  |     |     | **3.00×** | 1.41× | 2.65× |

*GPC* = the abandoned sibling P-code compiler (`../X16-GPCompiler/bench/RESULTS.md`).
*C64 Blitz* = the original Skyles compiler on a real C64, compiled-vs-uncompiled — the yardstick.

## Verdict

**3.00× geometric mean.** That beats the C64 Blitz yardstick (2.65×) and is **2.1× better than GPC**
(1.41×), which was abandoned for being too slow. The thesis holds: no ROM float calls, an automatic
integer fast path, and compile-time variable addressing are worth roughly double what a
ROM-float-backed P-code VM achieves.

Note `04_sieve` was **degenerate for GPC** (its 1.0× is an artefact — `DIM F(2000)` did not fit GPC's
array heap, so the sieve never sieved). It is a real measurement here: 12,006 bytes now allocates and
the array round-trips correctly. Blitz-X16's 4.30× also beats real C64 Blitz's 3.1× on the same work.

## The one weak spot: `02_floatmath` (1.25×)

The only benchmark below 2×, and the only one where **both** GPC (1.9×) and C64 Blitz (2.8×) beat us.
The body is `X = I*1.5+2` — a genuine float multiply. So `ifloat32`'s *software* 32-bit float multiply
is slower than the ROM's hand-tuned 5-byte routine. Everywhere the values stay integral, the tagged
int fast path wins big; when they don't, we pay for not using the ROM.

That is the clear optimisation target: `source/ifloat32/source/binary/multiply.asm` (and `divide.asm`).
Every other benchmark is already at or above the yardstick.

## Reproducing

```
bash bench/run-bench.sh
```
Each program powers the machine off when done so the emulator exits immediately: stock BASIC uses
`POWEROFF`; Blitz cannot compile that, so the compiled build substitutes `I2CPOKE 66,1,0` — the same
write to the SMC (`$42` = 66, register 1). Stock BASIC is injected with `-bas`, which types the
listing in through the keyboard, so those sources must be **uppercase** (the script uppercases them).
