---
name: gpasm-inline-assembly-research
description: "In-progress GP.ASM inline-assembly feature for GP-BASIC — research doc location, decisions taken, and what is still open"
metadata: 
  node_type: memory
  type: project
  originSessionId: 4b8bda58-db0d-4799-90e8-505eac54670b
  modified: 2026-08-30T07:03:09.248Z
---

Ongoing work as of 2026-08-30: designing **GP.ASM**, inline 65C02 assembly for
GP-BASIC, with `{VAR}` syntax to reach BASIC variables from the assembly.
**Research only — nothing implemented.**

All findings live in `docs/blitz/GP-BASIC.ASM.RESEARCH.md` (untracked as of
2026-08-30). It has a reading guide at the top; **§13 is superseded by §14, §Q by
§Q2, and §6/§15.7's quoting assumption by §17** — read those, not the originals.

Decisions the user made 2026-08-30 (these are choices, not derivable from code):

- Assembler runs **at compile time on the X16**, inside `GPC.BLITZ.BIN` — not a
  host preprocessor.
- Syntax is a **`GP.ASM` / `REM <instruction>` / `GP.ENDASM` block** (§17).
  This **supersedes the earlier "quoted, one instruction per line" decision** —
  measured through real BASLOAD, REM text survives verbatim *and* is immune to
  `#CONTROLCODES 1`, which aborts on quoted `{...}`. Delimiters are real tokens
  so an empty block (`#REM 0` left on) is detectable rather than silent.
- Multi-file assembly is **`#INCLUDE` of a REM-bodied `.asm` file** (§19.1) —
  works today, no compiler change. **`GP.ASMFILE` was proposed and then dropped
  by the user** (§19.2); do not re-propose it.
- `{VAR}` must reach **numeric scalars, strings and arrays**, **read and write**.
- Assembled bytes go **inline in the p-code**.
- **Compile-time memory cost is explicitly NOT a concern. Only runtime bytes
  matter.** This is what makes the design work — it lets everything expensive
  move into the compiler.

Not yet chosen: the lowering. §18 left two survivors, both 0 runtime bytes —
**A** a `SYS` composite with blobs pooled past the `$FF` end marker (no ABI bump,
no size cap, N+5 per block) and **B** a new `.asm` core opcode (N+2, but ABI
21→22 and spends 20 of the 26 core cushion bytes).

Still open (§Q2): what `{A}` means on an `ifloat32` scalar given writes are in
scope; how `{MACPTR}`-style KERNAL names get resolved; whether to reuse
`GP.A/X/Y/C` for register hand-back; whether to fix the host tokeniser so the REM
form works there too (§17.6).

Related: [[gpc-blitz-runtime-slack-and-limits]], [[gpc-core-page-cushion-below-gpbase]].
