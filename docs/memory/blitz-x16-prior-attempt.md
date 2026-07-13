---
name: blitz-x16-prior-attempt
description: The prior Blitz-X16 compiler attempt that GPC ports proven code from
metadata: 
  node_type: memory
  type: reference
  originSessionId: 481504f0-31d5-4658-a8c1-3b05e8802238
---

`c:\dev\CmdrX16\dos_tools\BLITZ-COMPILER` (aka **Blitz-X16**) is a prior, ~90%-complete self-hosted X16 BASIC→P-code compiler in Prog8, with **173 passing headless tests**. Its detailed milestone log is in its `README.md`. GPC (see [[gpc-project]]) is a fresh project that **ports its proven foundation** (with the user's approval of a specific file list) rather than continuing it in place.

Proven pieces to port: `src/shared/pcode_format.p8` (63-opcode stack-VM contract + standalone memory layout, `PCODE_BASE=$4800`), `src/runtime/vm.p8` (stack VM; numeric cell = 5-byte ROM float → ROM Math lib), `src/compiler/blitzc.p8` (tokenized-BASIC lexer, banked-source reader, re-entrant iterative shunting-yard parser, two-pass line-map/fixups, banked emitter, standalone `.prg` writer), plus `scripts/` harness and `tests/`.

Key correction GPC makes: Blitz-X16 wrote its own string GC and deferred command pass-through as "infeasible on X16." Both are actually feasible on R49 — proven in `X16-GPCompiler/spikes/` (see [[gpc-gating-requirement]] and [[x16-rom-internal-calls]]). GPC redesigns string storage to BASIC format to reuse the ROM GC, and adds a PASSTHRU path for X16 keywords.
