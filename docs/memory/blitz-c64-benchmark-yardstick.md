---
name: blitz-c64-benchmark-yardstick
description: C64 Blitz! compiler benchmarked vs stock BASIC (~2.6x avg) as a yardstick for GPC (~1.5x); array indexing + VM dispatch are the two biggest gaps.
metadata:
  type: project
  originSessionId: 574aca0d-1e65-4eab-aab1-acf026f5db05
---

Ran the same 7 float benchmarks (`bench/c64/b1..b7.bas`, ports of `bench/01..07`) on a **C64 with the vintage Blitz! (Skyles) compiler** under VICE `x64sc`, compiled-vs-uncompiled, timed via `TI` jiffies. Results in `bench/c64/RESULTS.md`.

**Blitz averages ~2.6×** (empty loop 1.3×, floatmath 2.8×, nested 2.8×, sieve 3.1×, string 4.1×, peek 2.6×, intmath 2.7×) — vs **GPC's ~1.5×** on the X16 for the same workloads.

**Why:** Blitz is threaded/native-style (resolves var/array addresses at compile time, emits near-metal code); GPC is a P-code VM (removes interpreter line-rescan but keeps a dispatch loop + still calls ROM for arithmetic/indexing).

**CORRECTION (2026-07: the sieve comparison was invalid).** GPC's array access does NOT go through ROM — it uses GPC's own `op_aload`/`index_of` heap handlers. The real reason `04_sieve` shows 1.0× is that **`DIM F(2000)` doesn't fit GPC's array heap** (`ARRHEAP_SIZE`=2048 B; needs 2001×5=10005 B), so `op_dim` marks it unusable (`arr_len=0`) and EVERY access is out-of-range — the sieve never sieves, it runs a degenerate all-`i` loop. Same for the int sieve (`F%(2000)`=4002 B vs 1024 B `IARRHEAP_SIZE`). So the Blitz "3.1× sieve" was C64 actually sieving (38 KB BASIC RAM) vs GPC failing to allocate. **The Blitz sieve gap is array-heap CAPACITY, not indexing speed.** See [[gpc-array-heap-capacity]]. A 1-D array-index fast path WAS added (branch `perf/vm-speed`; skips `index_of`'s call/marshal/`peekw`/multiply for single-subscript access, ~31% faster on fitting arrays — `08_arridx.int` 455→313 j), but it can't help the sieve until the array fits.

**The original (now-qualified) claim:**
1. **Array indexing** — sieve: GPC **1.0×** vs Blitz **3.1×**. The 1-D fast path is the indexing half (real 31% win where arrays fit); the sieve specifically needs the heap-capacity fix first (see correction above).
2. **VM dispatch** — Blitz's blanket ~2.6× vs GPC ~1.5× is mostly per-opcode fetch/decode/branch cost. This is the already-selected (paused) "Optimize VM dispatch" task in `src/runtime/vm.p8 run()`; the C64 numbers quantify its ceiling.

GPC still beats Blitz on integer-heavy code via native `%` types (5.6× on X16; Blitz has no integer path). Related: [[gpc-runtime-asm-conversion]], [[gpc-engine-shrink]], [[blitz-x16-prior-attempt]].

**Clock-normalized cross-machine check (identical workloads/iter counts both suites → compare CPU cycles/iter; X16 8MHz/60Hj, C64 1.0227MHz NTSC/60Hj):** (1) UNCOMPILED, stock X16 BASIC and C64 BASIC cost within ±6% cycles/iter (~same ROM interpreter) — so the ~8× wall-clock gap between the machines is 100% clock speed (8.0/1.023=7.8×), and the near-1.00 match confirms C64 ran a ~60Hz jiffy (not 50). (2) COMPILED, Blitz uses 1.4–2.7× FEWER CPU cycles/iter than GPC on every real-body bench (only loses the empty loop, 0.90×) — so Blitz's advantage is genuine compiler quality, NOT the C64's slow clock flattering it. Clock normalization sharpens, not softens, the verdict. Full table in `bench/c64/RESULTS.md` "Factoring in CPU clock speed".

**Method gotchas (VICE x64sc, all reusable):** timing must be non-warp for wall-clock but jiffy count is warp-independent so `-warp` is fine; drive input via `-keybuf` with `\n` (NOT `\r` — segfaults); `LOAD"x",8`+`RUN` must be on SEPARATE keybuf lines; Blitz compile = `LOAD"BLITZ",8`/`RUN`/menu `1`/filename → writes `c/NAME` (runnable, ~24 blk) + `z/NAME` (scratch); ~400M cycles/~90s wall per compile (disk-heavy). Fan out compiles across separate `.d64` copies to parallelize (16 cores → 6 at once fine). Read `R=` from `-exitscreenshot` PNG.
