---
name: gpc-array-heap-capacity
description: GPC's array heaps are tiny (float 2048 B / int 1024 B) — a DIM bigger than ~409 float or 512 int elements silently becomes unusable (arr_len=0, all accesses OOB→0/dropped). This, not indexing speed, is the Blitz-sieve blocker.
metadata:
  type: project
  originSessionId: 574aca0d-1e65-4eab-aab1-acf026f5db05
---

GPC's numeric arrays live in fixed bump heaps sized by consts in `src/runtime/vm.p8`:
`ARRHEAP_SIZE = 2048` (float, 5 B/elem → ~**409** elements total across ALL float arrays) and
`IARRHEAP_SIZE = 1024` (int `%`, 2 B/elem → **512** elements total across all int arrays).

`op_dim`/`op_idim` check `arr_top + total*elsize <= HEAP_SIZE`; if it doesn't fit, the array is marked
**unusable** (`arr_len[slot] = 0`) — NOT an error. Then every `A(i)` access is out-of-range: reads give
0.0/0, stores are silently dropped (GPC never raises `?OUT OF MEMORY`/`?BAD SUBSCRIPT`). So a too-big
`DIM` produces a program that runs but computes garbage.

**Consequence for the benchmarks / Blitz comparison:** `bench/04_sieve.bas` does `DIM F(2000)` (needs
2001×5 = 10005 B ≫ 2048) → F is unusable → the "sieve" never sieves, it degenerates to an all-`i` loop
over an array that reads 0 everywhere. The int sieve is the same (`F%(2000)` = 4002 B > 1024). So the
recorded "GPC 1.0× vs Blitz 3.1× on the sieve" was **GPC failing to allocate the array**, not slow
indexing — the C64/Blitz sieve fits in its 38 KB BASIC RAM and actually runs. **The Blitz sieve gap is a
heap-CAPACITY problem, not an indexing-speed one.** Corrects [[blitz-c64-benchmark-yardstick]].

To make a sieve actually run today, keep it within the heap (e.g. `DIM F(400)` → 401×5 = 2005 B fits;
verified: a fitting N=400 sieve compiles and prints 78 = π(400)). To close the Blitz sieve gap for real,
the array heap must grow to hold thousands of elements — on the memory-walled X16 that most likely means
relocating array storage to **banked RAM** (precedent: the litpool/datapool banked-pool relocation), which
adds a per-access bank-switch cost to weigh against the [[gpc-array-index-fastpath]] savings. Deferred by
the user (2026-07-13) in favor of shipping the indexing fast path first.
