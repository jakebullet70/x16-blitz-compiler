---
name: strcase-call-overhead-measured
description: Measured cost of a STRCASE.INC.BL GOSUB call (~2,570 cycles) and why it is noise in the editor's find loop
metadata:
  type: project
---

**Measured 2026-09-04**, 30,000 iterations, `TI` read inside the emulator under `-warp`, 8 MHz
(133,333 cycles/jiffy). Same method as `bench/loop/run-loop-profile.py`, but the BASL route
(BASLOAD → GPC → run) because `{VAR}` needs a `#SYMFILE` the host tokeniser cannot make.

| loop body | cycles/iter | over baseline |
|---|---:|---:|
| empty `FOR`/`NEXT` | 453.3 | — |
| bare `GP.ASM` (`.word` + `sys`, `RTS` only) | 822.2 | 368.9 |
| `X% = LEN(S$)` — upper bound on a keyword statement | 986.7 | 533.4 |
| `STRCASE.PTR = GP.STRPTR(S$) : GOSUB STRCASE.GO`, 1 char | 3026.7 | **2573.3** |
| the same, 80 chars | 4231.1 | 3777.8 |

- **A STRCASE call is ~2,570 cycles, ~0.32 ms.** A core keyword would be ~300, so moving it back
  buys ~2,200 a call — see [[gpc-core-page-cushion-below-gpbase]] for why that is not worth doing.
- **Per character 15.25 measured**, against 15 counted statically for the non-folding branch —
  the two agree, which validates the harness. A character that actually folds is 26.
- **Break-even ~170 characters** (~100 if every character folds). Below that the wrapper costs
  more than the work.
- **Static estimates came out 8% low** on the call (2,370 predicted) and 40% low on the bare
  `sys` — `bench/RESULTS.md` warns 10–20%; treat static counts as a floor, not a figure.
- **It is noise where it is hot.** `DOC.LOAD.CHARS` (`ED-STORE.BASL:141`) builds a line one
  `CHR$`+concat at a time: **~300,900 cycles for an 80-char line, ~3,760 per character**. The
  STRCASE call on that line is 3,793 — **1.3%** — before `GP.INSTR`. If the editor's find is ever
  slow, that per-character concat is the target, not the module call.

Harness kept at `scratchpad/scb/` (P1..P6 + `bench.py`); nothing committed.
Related: [[headless-basl-build-recipe]], [[measure-before-changing-code]], [[answer-the-question-asked]].
