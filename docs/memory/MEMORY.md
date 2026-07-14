# Memory Index

Knowledge base for the Blitz-X16 compiler. The `gpc-*` notes are what survived the prune of the
abandoned sibling project (GPC): everything kept here is a fact about **X16 BASIC or the X16 itself**,
not about GPC's internals. The rest are recoverable from git history (commit `0f3f82b`).

## This project
- [Build setup](blitz-x16-build-setup.md) — how to build it, and the 5 blockers that made a fresh clone unbuildable on any OS
- [Emulator split](blitz-x16-emulator-split.md) — x16emu r49 runs the tests, Box16 is for debugging; why Box16 can't run the suites
- [X16 BASIC conformance](blitz-x16-basic-conformance.md) — Blitz vs stock BASIC: 4 real defects (float literals, STEP 0, sci notation, reversed relops)
- [R44+ keywords](blitz-x16-r44-plus-keywords.md) — 10 keywords added after R43 that Blitz doesn't know (SPRITE, MOVSPR, OVAL, RING, MOD…) + a LINPUT/LINPUT# token swap
- [Blitz-X16 prior attempt](blitz-x16-prior-attempt.md) — the earlier Prog8 self-hosted compiler (now deleted from disk)

## X16 BASIC semantics (ROM-verified — apply to any compiler)
- [IF semantics](gpc-if-semantics.md) — a false IF skips the WHOLE line, not just the first statement. Blitz gets this right.
- [FOR STEP 0 semantics](gpc-for-step0-semantics.md) — NEXT exits iff sign(loopvar−limit)==sign(step); STEP 0 needs EXACT equality. **Blitz gets this wrong.**
- [X16 BASIC coverage](gpc-x16-basic-coverage.md) — the 7 lexer blockers on valid X16 BASIC (hex, binary, .5, >=65536, 9.2E5, long names, `=<` `=>` `><`)

## Performance
- [C64 Blitz benchmark yardstick](blitz-c64-benchmark-yardstick.md) — real C64 Blitz ≈2.6× vs stock BASIC; the bar to beat
- [Array heap capacity](gpc-array-heap-capacity.md) — arrays that don't fit silently invalidate benchmarks; check allocation before trusting a timing
- [Array index fast path](gpc-array-index-fastpath.md) — 1-D indexing fast path was worth ~31%; incl. the OOB short-circuit gotcha

## X16 platform / toolchain
- [X16 ROM internal calls](x16-rom-internal-calls.md) — verified R49 dispatcher/GC addresses + ZP pointers
- [X16 toolchain](x16-toolchain.md) — 64tass / emulator paths on this machine
- [x16emu -echo doubling](x16emu-echo-doubling.md) — non-warp `-echo raw` prints every char TWICE
- [Memory is git-tracked](memory-is-git-tracked.md) — this folder versions with the project
- [Prog8 PETSCII char literals](prog8-petscii-charlits.md) — legacy; only relevant if Prog8 comes back
