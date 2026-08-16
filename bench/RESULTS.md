# Benchmark results — Blitz-X16 vs stock X16 BASIC

Measured 2026-08-16, after the array-access work (see below). Previously 2026-07-13.
Emulator `bin/x16emu` (r49 Pyrite), ROM R49. Run with `bash bench/run-bench.sh`.

Timing is `TI` (jiffies, 1/60 s) read **inside** the emulator, so it is independent of `-warp`.
Verified: the same program under `-warp` and without gives an identical count (285 both ways), and
that 285 reproduces GPC's recorded stock-BASIC baseline for `01_forloop` exactly — which
cross-validates the whole comparison. (A note in the GPC repo claims the 60 Hz timer freezes under
`-warp`; on this emulator it does not. Do not trust that note.)

| benchmark | stock | compiled | **speedup** | GPC | C64 Blitz |
|---|---:|---:|---:|---:|---:|
| 01_forloop   | 285 | 110 | **2.59×** | 1.4× | 1.3× |
| 02_floatmath | 572 | 364 | **1.57×** | 1.9× | 2.8× |
| 03_nested    | 772 | 203 | **3.80×** | 1.4× | 2.8× |
| 04_sieve     | 318 |  66 | **4.82×** | 1.0× | 3.1× |
| 05_string    | 216 |  54 | **4.00×** | 1.4× | 4.1× |
| 06_peek      | 178 |  52 | **3.42×** | 1.5× | 2.6× |
| 07_intmath   | 669 | 186 | **3.60×** | 1.4× | 2.7× |
| **GEOMEAN**  |     |     | **3.23×** | 1.41× | 2.65× |

*GPC* = the abandoned sibling P-code compiler (`../X16-GPCompiler/bench/RESULTS.md`).
*C64 Blitz* = the original Skyles compiler on a real C64, compiled-vs-uncompiled — the yardstick.

## Array access, 814 → 651 cycles (2026-08-16)

Three changes, each measured on its own with a dedicated micro-benchmark — `DIM A(255)` read in a
tight loop, 20,480 iterations, `TI` inside the emulator, figures net of the empty loop:

| | array read over a scalar read |
| --- | ---: |
| before | 814 cycles |
| a doubled `FloatIntegerPart` removed from `ArrayConvert` | 768 |
| `dec`/`beq` break counter in `NextCommand` | ” |
| **`PCD_ARRAY1` — fused single-subscript opcode** | **651** |

- **The doubled truncation.** `ArrayConvert` called `FloatIntegerPart` on each subscript and then
  called `GetInteger16Bit`, which opens with `.floatinteger` — *the same call*. The second could
  only ever take the do-nothing path, since the first leaves `NSExponent` zero. 26 cycles a
  subscript, on every array access in every program.
- **The dispatcher.** `NextCommand` polled Ctrl+C with `lda/adc/sta/bcc` (13 cycles) on every
  p-code word in order to act one time in sixteen. `dec`/`beq` is 8 for the same rate. Five cycles
  a keyword, everywhere: the empty-loop baseline fell 508 → 495 cycles on that alone.
- **`PCD_ARRAY1`.** `OutputIndexGroup` always pushed a subscript-count word, which `ArrayConvert`
  read straight back with `GetInteger8Bit`. For one subscript — very nearly every reference — the
  compiler knew the count at compile time. The fused opcode takes it as implicit, removing a whole
  p-code dispatch and a runtime call: 117 cycles, and it makes compiled programs *smaller* too.

`RT_ABI` went 2 → 3: p-code IDs are handed out in `;; [name]` scan order, so everything after
`array1` shifted, and a resident runtime of the same ABI is deliberately reused across builds.

Verified against every benchmark here, A/B on the same host with two engine binaries — no stash,
no rebuild between runs. **Nothing regressed:**

| benchmark | HEAD | with the change | |
|---|---:|---:|---|
| 01_forloop | 113 | 110 | −2.7% |
| 02_floatmath | 366 | 364 | −0.5% |
| 03_nested | 210 | 203 | −3.3% |
| 04_sieve | 73 | 66 | **−9.6%** |
| 05_string | 55 | 54 | −1.8% |
| 06_peek | 53 | 52 | −1.9% |
| 07_intmath | 192 | 186 | −3.1% |

`04_sieve` gains most, as it should — it is the one benchmark that is mostly array traffic.

It also turned up a bug that had nothing to do with performance: **`A(B(I))` did not work.**
`OutputIndexGroup` counted subscripts into one global, and `CompileExpressionAt0` recurses back
into it, so the inner reference re-counted the outer's tally and a nested subscript emitted a
two-subscript access against a one-dimensional array — `BAD ARRAY INDEX`, at runtime, naming
neither line nor cause. Fixed by saving the tally across the descent. **The randomised `arrays`
suite could not see it**: every subscript it generated was a bare literal. It now routes a third of
them through an index array whose element *k* is *k*, so `A(NX%(3))` appears alongside `A(3)`.

## Where the loop cycles actually go (2026-08-16)

A cycle-attribution pass over the ~487-cycle empty loop iteration, to answer one question with data
rather than argument: **is a dedicated fast/integer loop variable worth building?**

Harness: `bench/loop/run-loop-profile.py`, compiled-only (this profiles the VM, so the stock column
is irrelevant). Every variant runs the **same 60,000 iterations**, so each pair differs in exactly
one thing and the difference is that thing's cost. `TI` read inside the emulator, as ever. At 8 MHz
and 60,000 iterations one jiffy is 2.22 cycles/iteration — twice the resolution the 30,000-iteration
`01_forloop` gives.

| program | cycles/iter | isolates |
|---|---:|---|
| `L0_null` | 0.0 | harness overhead — confirms the method has no floor |
| `L1_empty` | **486.7** | `FOR`/`NEXT`, empty body |
| `L2_one` | 937.8 | one `K=I` |
| `L3_two` | 1388.9 | two — marginal +451.1, **exactly linear** |
| `L4_four` | 2291.1 | four — marginal +902.2 = 2 × 451.1, **still exactly linear** |
| `L5_const` | 817.8 | `K=1` (store, no variable load) |
| `L6_desc` | 1215.6 | descending loop — `NEXT` off its integer fast path |
| `L7_step1` | 486.7 | explicit `STEP 1` — identical, fast path holds |
| `L8_goto` | 1706.7 | hand-rolled `I=I+1 : IF I<N THEN` loop |
| `L9_4inline` | 2093.3 | the same four statements on **one** line |
| `LA_fltassign` | 937.8 | `K=J`, float scalar |
| `LB_intassign` | 895.6 | `K%=J%`, integer scalar |

**Attribution**

| component | cycles |
|---|---:|
| `NEXT` itself (486.7 − one line marker) | **420.8** |
| one assignment statement, `K=I` (451.1 − one line marker) | **385.2** |
| — of which the variable *load* alone | 120.0 |
| — `K=1`, store with no load | 265.2 |
| one extra **source line** | **65.9** |
| `NEXT` without the integer fast path (descending) | +728.9 |
| 2-byte integer scalar vs 6-byte float scalar | **−42.2 (9.4%)** |

The static cycle counts through `00runtime.asm` → `.vaddress` → `ReadFloatZTemp0Sub` agree: they
predict the load-vs-constant difference at 122 against a measured **120**, the statement at 354
against 385, and the line marker at 51 against 66. Consistently 10–20% low in absolute terms, never
wrong in shape — so the *share* each component takes is trustworthy. Of the 385-cycle assignment,
roughly 190 is the two 6-byte iFloat32 copies, 70 the `.vaddress` operand decode, 85 the two p-code
dispatches, and 50 `jsr`/`rts` plus `entercmd`/`exitcmd` glue.

### Three findings

**1. `FOR`/`NEXT` is not the problem — it is already the fast path.** A hand-rolled `IF`/`GOTO` loop
costs **1706.7** against `FOR`/`NEXT`'s 486.7: the dedicated loop construct is **3.5× better** than
doing it by hand. And its integer fast path is already earning 728.9 cycles an iteration over the
float path. `STEP 1` written explicitly costs exactly nothing.

**2. A faster integer variable is NOT the lever — measured, not reasoned.** The integer scalar path
already exists end to end: `GetSetVariable` emits opcodes 80–95 for `%` variables and the runtime has
`ReadIntegerCommand`/`WriteIntegerCommand` wired into `ReadWriteVectors`, moving **2 bytes instead of
6**. It is worth **9.4%**. Byte count is not where the time goes — dispatch, `.vaddress`, and
converting to and from the iFloat32 stack format are, and `ReadIntegerZTemp0Sub` still pays four
`stz`s and sign handling to produce a stack value. **A zero-page integer register file would inherit
every one of those costs** unless it also brought integer-native arithmetic and comparison opcodes —
i.e. a second ALU path through the whole VM, not a storage change.

**3. Every source line costs 65.9 cycles**, and that is actionable today with no VM change at all.
`PCD_NEWCMD_LINE` is emitted once per line by `MainCompileLoop`; `CommandNewLine` itself is four
instructions (`plx` / `stz stringInitialised` / `ldx #$FF` / `jmp NextCommand`), so nearly all of the
65.9 is the dispatch to reach it. Putting four statements on one line instead of four
(`L4_four` → `L9_4inline`) is **2291.1 → 2093.3, 8.6% faster for free**.

### Recommendation

Ranked by cycles saved × breadth, and against the measured shares above:

1. **Fuse the integer `FOR`/`NEXT`.** `NEXT` is 420.8 cycles and the single biggest line item in any
   small loop. Three of its per-iteration costs are subroutine calls that a fused opcode can fold:
   `StackFindFrame` (~40), the unconditional `jsr FixUpY` (~42), and `StackLoadCurrentPosition`
   (~42) — ~124 cycles, ~25%, before touching the four-byte terminal compare. No source changes, so
   every existing program benefits. This is the `PCD_ARRAY1` play, which is the one that has already
   worked here.
2. **Attack `new.line`.** 65.9 cycles on *every line of every program*, for a handler that does two
   stores. Either fold it into the preceding opcode, or let the compiler skip emitting it where it
   can prove the line needs neither the string-system reset nor the stack reset.
3. **Do not build `R0`–`R7` as scoped.** Finding 2 is the evidence: the storage change alone buys
   9.4%. It only pays with integer-native arithmetic throughout the VM, which is a far larger project
   than the fused opcode above and should be judged on its own merits, not as a loop optimisation.

Immediately usable without any of the above: **put multiple statements on one line** — 8.6% measured.

## ⚠ `02_floatmath` — a real regression, and it is NOT from the work above

The 2026-07-13 table recorded **331**. It reads **366 today at HEAD**, before any of the changes
above are applied — measured directly, by building HEAD and this branch as two binaries and running
both. So float multiply lost ~10% somewhere between `1e76209`-era and now, and this file has been
quoting a number that no longer reproduces.

Candidates are the commits since: `b67e26d` (one-way pointer guards, program limit to 18K) and
`755136b` (frame-stack reset on a LOAD chain). Both add work to paths that could plausibly be hot.
**Not yet bisected.** Worth doing — it is the one benchmark below 2× and the one that drags the
geometric mean.

## Verdict

**3.23× geometric mean.** That beats the C64 Blitz yardstick (2.65×) and is **2.2× better than GPC**
(1.41×), which was abandoned for being too slow. The thesis holds: no ROM float calls, an automatic
integer fast path, and compile-time variable addressing are worth roughly double what a
ROM-float-backed P-code VM achieves.

Note `04_sieve` was **degenerate for GPC** (its 1.0× is an artefact — `DIM F(2000)` did not fit GPC's
array heap, so the sieve never sieved). It is a real measurement here: 12,006 bytes now allocates and
the array round-trips correctly. Blitz-X16's 4.36× also beats real C64 Blitz's 3.1× on the same work.

## `02_floatmath`: 1.25× → 1.73× — *historical; it is 1.57× today, see the warning above*

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
