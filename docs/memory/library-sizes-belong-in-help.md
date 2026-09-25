---
name: library-sizes-belong-in-help
description: "OWED: the runtime footprint and the per-module GPC-BASIC p-code sizes are to be written into GP-BASIC.md section 7, so a user can budget a program without a build"
metadata: 
  node_type: memory
  type: project
  originSessionId: 6478d6d9-72bb-47d5-98f5-55eb680c2e40
  modified: 2026-09-24T09:58:25.820Z
---

Asked 2026-09-24. The two size figures a user needs before including anything are only in memory and
in `GPC-BASIC-TOOLS-SRC/GPB-MODS-TESTING/readme.md`. They belong in the help system, under
`GPC-BASIC/GP-BASIC.md` **§7 "Memory, and what the compiler tells you"**, which already explains the
compiler's own size report and is where somebody looks when a program will not fit.

Two numbers, and they answer different questions.

**The runtime is 10,956 bytes in every program.** Unconditional, no dead-code elimination. See
[[blitz-x16-runtime-footprint]] for the component split.

**Nothing in GPC-BASIC is added automatically.** A module costs what it costs, once, per
`#INCLUDE`. The per-module p-code table is in `GPC-BASIC-TOOLS-SRC/GPB-MODS-TESTING/readme.md` under *Where the
bytes go*, measured by the method in [[measure-pcode-per-module]]; the whole 21-module stack is
16,930 bytes, of which GPBMODS keeps only 595 in low RAM.

The help entry must state the `GP.ASM` trap: a blob module measures near zero on the map because
BASLOAD strips the `REM` lines its body rides in, so `STRCASE` reads 54 bytes and costs about 174.

Re-measure before writing: the readme table is a dated build, and
[[help-topic-writing-rules]] says a help topic carries current behaviour only. The rendered `.HLP`
carries hand edits, so patch the delta rather than re-rendering whole -- see
[[hlp-files-carry-hand-edits]]. `doc-style` owns the prose.
