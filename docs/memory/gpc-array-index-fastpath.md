---
name: gpc-array-index-fastpath
description: perf/vm-speed branch — 1-D array element access skips the generic index_of (call+marshal+peekw+multiply); ~31% faster on fitting arrays, runtime-only, no P-code change. Correct; a total==0 short-circuit avoids a regression on too-big/undimensioned arrays.
metadata:
  type: project
  originSessionId: 574aca0d-1e65-4eab-aab1-acf026f5db05
---

On branch **`perf/vm-speed`** (off `bench-suite`; also carries the O1+O2 dispatch tuning), the four numeric
array handlers `op_aload`/`op_astore`/`op_iaload`/`op_iastore` in `src/runtime/vm.p8` got a **1-D fast path**.
For `nd==1` (the common `A(I)` case) the element count `arr_len[slot]` IS the dim-0 size, so the offset is
just the subscript — one unsigned-16-bit bounds check, then a jump into the EXISTING address-compute+copy
tail (`_alok`/`_ilok`/`_asok`/`_isok`). It skips the generic `index_of`: its 5-arg call+marshal, the dim-table
`peekw`, and the full `off*sz` `multiply_words`. `nd!=1` falls through to the unchanged generic path.
**Runtime-only** — compiler + P-code format unchanged, corpus recompiles byte-identical.

Key correctness facts (verified): subscripts are ALWAYS 5-byte floats on the `float[32] stack` even for
`A%()` (compiler auto-emits `OP_ITOF`), so the fast path reads them via `stack_word` (same MOVFM+cast as
`index_of`). Value for an int store is on `istack[value_slot]`; subscript on the float `stack`. Full
`scripts/test.sh` green; a fitting sieve N=400 prints 78 = π(400).

**GOTCHA that caused a real regression (found via before/after bench, fixed):** the generic `index_of`
short-circuits the `total==0` (unusable/undimensioned array) case IMMEDIATELY, before reading any subscript.
The first fast-path cut always called the expensive `stack_word` first, so on OOB-heavy code (e.g. the
degenerate `04_sieve`, whose array is too big to allocate — see [[gpc-array-heap-capacity]]) it was ~+51 j
SLOWER despite doing "less work" for in-range. Fix: test `arr_len[slot]==0` (cheap `ora`) BEFORE `stack_word`
and short-circuit to the OOB path, matching `index_of`. After the fix: `08_arridx.int` (fitting, 30k in-range
accesses) **455→313 j (31% faster, ~630 cyc/access)**; degenerate sieves unchanged (no regression); non-array
benches identical. Lesson: a fast path must reproduce the slow path's cheap early-exits, or it loses on the
inputs that hit them. PCODE_BASE margin got tight (full tier ~68 B) — watch it. Bench `bench/08_arridx.int.bas`
demonstrates the win. Related: [[blitz-c64-benchmark-yardstick]], [[gpc-runtime-asm-conversion]].
