---
name: measure-pcode-per-module
description: "The map file plus the BASLOAD symbol file give exact p-code bytes per include and per routine, with no experimental builds"
metadata:
  node_type: memory
  type: reference
---

**`compile_shared.py <src.prg> <obj.prg> <map>` takes a THIRD argument** and writes an
address-per-line map (`0006 1` / `000A 2` / …, hex address then BASIC line). Pair it with the
`#SYMFILE` output, which lists labels grouped under `FILE: NAME.INC.BL` with `=lineno;` on each,
and you get **exact p-code bytes per include and per routine** — differencing addresses between
consecutive lines. No experimental builds, no including modules one at a time.

Works because BASLOAD numbers the concatenated source in `#INCLUDE` order, so **each file's lines
are one contiguous range**: take each file's first label line as its start and the next file's as
its end. Per-routine is the same difference between consecutive labels.

Found 2026-09-04 answering "how big is the GUI library really". The numbers it produced are in
`TODO.md` under *How much of the GUI library fits in a bank?* — and they overturned the guess:
GPC-HELP's four dialogs are 825 bytes between them while the box machinery under them is 1,322, so
splitting `GUI.INC.BL` per dialog is worth a few hundred bytes, not thousands.

**Two things that will look like bugs and are not:**

- **A `GP.ASM` module measures near zero.** `STRCASE.INC.BL` comes out at 26 bytes from 140 source
  lines, because the blob rides in `REM` lines that BASLOAD strips. See
  [[gpasm-implementation-status]].
- **Map total < object size.** 9,847 against 10,474 on GPC-HELP; the rest is headers and tables.

See [[measure-before-changing-code]] and [[gpc-blitz-runtime-slack-and-limits]].
