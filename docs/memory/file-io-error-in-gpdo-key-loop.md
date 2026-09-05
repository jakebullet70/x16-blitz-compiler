---
name: file-io-error-in-gpdo-key-loop
description: "OPEN/PRINT#/CLOSE inside a GP.DO key loop writes the file correctly then stops with INPUT/OUTPUT ERROR @ $005B; a plain PRINT after CLOSE makes it go away"
metadata:
  node_type: memory
  type: project
---

Found 2026-09-05 building `samples/color-test`. A save routine reached from inside the program's
`GP.DO` key loop **writes its file completely and correctly**, then the program stops with

    INPUT/OUTPUT ERROR @ $005B

The address is the same in every failing build, which says a clobbered instruction pointer rather
than a real device error. `.error_channel` is raised from `x16_open.asm` (OPEN carry set) and
`x16_printchar.asm` (CHKOUT then READST non-zero).

**What was ruled out, each with its own compiled probe:**

| Shape | Result |
|---|---|
| `OPEN`/`PRINT#`/`CLOSE` at top level | passes |
| four consecutive `PRINT#` with no `PRINT` between | passes |
| the same inside a `GP.DO` ... `GP.EXITDO` | passes |
| the same behind a `GOSUB` inside a `GP.DO` | passes |
| the same behind `GP.SELECT` -> `GOSUB` inside a `GP.DO` | passes |
| the real routine called from the top level of the same program | passes |
| the real routine reached from the program's own `GP.DO` key loop | **FAILS** |

**A plain `PRINT` immediately after the `CLOSE` makes it pass.** Channel 0 output runs `CLRCHN`
(`XPrintCharacterToChannel`, X = 0); a non-zero channel runs `CHKOUT` + `READST` instead. So the
next suspect is channel state left behind, and `currentChannel`, which `CLOSE` clears only when the
closed LFN matches it.

**How to apply:** it is not the file I/O and it is not any single block construct, so do not
re-bisect those seven shapes. Start at the runtime's channel handling. The sample ships without the
save key; the readme records the same repro.

Related: [[headless-basl-build-recipe]].
