---
name: gpc-engine-shrink
description: engine-shrink branch — the 3-phase tiered-runtime system that shrinks compiled .PRG size
metadata:
  type: project
---

Branch `engine-shrink`: shrink the compiled-program size (the whole Phase 1-3 arc is about the
PCODE_BASE floor, since `write_output()` pads every .PRG up to PCODE_BASE — lowering the base is
the ONLY lever that shrinks EVERY program). Benchmarked against the real 1986 SuperSoft Blitz!
(~5.7KB runtime, has native int), NOT the Prog8 BLITZ-COMPILER reimplementation. See [[gpc-runtime-asm-conversion]].

Three shipped phases (all corpus-green, both paths):
- **Phase 1** (049cd2e): universal — PCODE_BASE $3C80 → $3A80. −512 B / −2 blocks per program.
- **Phase 2** (dacc438): `nosarr` tier — AUTO-selected per program. A program that never DIMs a
  string array bundles a runtime with the 4 sarr opcodes (OP_SDIM/SALOAD/SASTORE/RDSTR) stripped,
  loading at NOSARR_PCODE_BASE $3740. −832 B / −3 blocks. Correct by construction: `uses_sarr` is
  set only in `intern_sarr()`, and every sarr-opcode emit shares that path.
- **Phase 3** (9de5d47): `noint` tier — a WHOLE-COMPILER mode, NOT auto-selected (nearly every
  program has an int literal → OP_IPUSHI, so int can't be stripped per-program). Building `gpc noint`
  sets `const bool INTSUPPORT=false`: `%` vars/literals degrade to float, none of the 25 native-int
  opcodes (67..91, ipushi..iastore) are emitted, output bundles the noint runtime at NOINT_PCODE_BASE
  $3400. −833 B / −3 blocks vs nosarr (no-sarr program); −1668 B / −7 blocks vs full (sarr program,
  since sarr forces the full base). noint KEEPS strings/sarr — only int is removed.

**Phase 3 reroute is minimal (correct by construction):** the only two SOURCES of a TY_INT/TY_ILIT
type are int literals and `%` variables. Gate both → is_intish() is naturally always false → every
int-arith/compare/coercion emit (all is_intish-gated) is dead. Edits: (1) tokenizer emits T_IDENT
instead of T_IVAR for a `%` suffix (T_IVAR has exactly ONE producer site) — a distinct float var
still named with '%', so DIM A%()/FOR I%/A%()/assign all fall through to their float paths; (2) the
literal site emits OP_PUSHI/TY_FLOAT instead of OP_IPUSHI/TY_ILIT. OP_PUSHI (opcode 3, kept in all
tiers — used for default args) pushes the UNSIGNED imm word as a float via GIVUAYFAY.

**build_tier mechanism** (scripts/build.sh): builds a stripped runtime tier by (a) inserting a
halting `_unimpl` stub before `_optab`, (b) sed-repointing the stripped opcodes' `_optab` entries to
`_unimpl` (range `/^_optab:/,/p8s_op_iastore/`), (c) awk-collapsing their `asmsub` bodies to bare
`rts` (prog8 never DCEs asmsubs) — regular `sub`s (op_ftoi/op_idim) prog8 DCEs itself once orphaned,
(d) lowering PCODE_BASE via a build/gen pcode_format override. assert-pcode-base.sh checks the
tier's footprint against its LOWERED base (2nd arg). A tier's base const (gpc.p8) MUST match the
build_tier base literal (build.sh) — the assert enforces the fit, not the match.

**write_output tier selection** (gpc.p8): `if not INTSUPPORT { noint@$3400 } else if uses_sarr
{ full@$3A80 } else { nosarr@$3740 }`; any missing tier .bin falls back to the full runtime at the
full base (a lower-tier program still runs correctly on the full runtime, just loaded higher — never
fail a compile over a missing tier file). No 4-way sarr×int cross-product (noint is a single tier
that keeps sarr).

Harness: check-standalone.sh takes GPC/RT/RTNAME env overrides to pick a tier's compiler+runtime.
The FULL compiler auto-selects full/nosarr, so run.sh/check-*/stage-demo stage gpc.rt.nosarr.bin;
the noint compiler is separate (build/gpc_noint.prg) and only test.sh exercises it. Demo staging of
a noint compiler is NOT yet wired (possible follow-up). See [[gpc-x16basic-look-act]] [[gpc-inc2-design]].
