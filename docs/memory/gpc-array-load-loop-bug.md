---
name: gpc-array-load-loop-bug
description: RESOLVED — the "array read in loop hangs" bug was DIM not zero-initializing elements; garbage floats hung ROM FOUT on PRINT. Fixed in op_dim.
metadata: 
  node_type: memory
  type: project
  originSessionId: 481504f0-31d5-4658-a8c1-3b05e8802238
---

**RESOLVED 2026-07-08.** The earlier diagnosis in this note (an sp-leak in `op_aload` on a value
subscript that compounds over loop iterations into the FOR frame; "needs the VICE monitor") was
**WRONG**. Root-caused and fixed by static + host-console reproduction, no special tooling needed.

**Real root cause:** `vm.op_dim` allocated array elements from `arrheap` (a Prog8 `memory()` slab that is
NOT zeroed; in-process it holds stale compiler bytes) but **never zero-initialized them**. Classic BASIC
guarantees a freshly `DIM`'d numeric array reads `0.0`; GPC left garbage. Reading a never-stored element
returned a garbage 5-byte value, and when that non-normalized MFLPT "float" reached the ROM float->ASCII
formatter (**FOUT**, via `PRINT`/`STR$`) it **looped forever** — that was the "hang".

**Why the loop/variable-subscript framing was a red herring:** every observed hang was actually in a
later `PRINT` of a garbage value read from an unfilled slot. Decisive isolation (host console, which the
corpus captures reliably — the mailbox is clobbered by the emulator RQM protocol):
- `S=A(I)` in a loop then `PRINT 111` (constant) -> instant, correct. Load + loop + var subscript are FINE.
- `PRINT A(0)` on a fresh DIM (no loop at all) -> HANGS. Pure format-of-garbage.
- Filled array read in a loop (any count) -> instant, correct.
- `S=A(0)` (store garbage, never print it) -> terminates. Only FORMATTING garbage hangs.

**Fix (one place):** `op_dim` now `sys.memset(arrheap + arr_top, adtot*5, 0)` right after reserving the
element range (bounded by the existing `arr_top + adtot*5 <= ARRHEAP_SIZE` guard). Scalars (`varsf`),
integer vars (`ivarsf`), and array dimensions were already zeroed in `vm` init; this closes the last gap,
so every readable numeric value now starts as a valid `0.0` and there is no in-language way to synthesize
the malformed float that hangs FOUT. Undimmed / out-of-range reads were already safe (op_aload returns 0.0).

**Regression coverage added** (test.sh, Arrays section): fresh-DIM `PRINT A(0)`, fresh-DIM 2-D read,
var-subscript read across a multi-iteration loop (both multiline and single-line — the exact old repro),
and a partially-filled array (`A(4)=7:PRINT A(3)+A(4)+A(5)` = 7). Corpus **262/262 green**.

**Residual latent note (not chased, no trigger remains):** ROM FOUT will still spin on a malformed MFLPT
if one is ever produced by a *future* bug (e.g. a new opcode that leaves junk on the float stack). Cheap
guard if it ever recurs: validate/normalize before FOUT, or trap. Unblocks re-attempting
[[gpc-inc2-design]]'s 2c (integer arrays) — that now only needs the RAM strategy, not a bug hunt.
