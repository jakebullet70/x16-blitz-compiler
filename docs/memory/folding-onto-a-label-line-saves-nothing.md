---
name: folding-onto-a-label-line-saves-nothing
description: "A bare label line costs zero bytes -- BASLOAD emits no BASIC line for it -- so hand-crunching LABEL: onto the statement below it saves nothing. Only merging real statements does."
metadata:
  node_type: memory
  type: project
---

**Measured 2026-09-07.** Twenty routines written as

```
T.R1:
    T.N = T.N + 1
    RETURN
```

and the same twenty written as

```
T.R1:  T.N = T.N + 1
    RETURN
```

compile to **the identical byte count both ways** -- 523 tokenised, `OK CODE 298`. A bare label
line is not a BASIC line: BASLOAD records the label against the NEXT line it emits and produces no
line of its own. Folding the statement up onto it removes a source line and no object byte.

## Why this matters

`samples/cruncher/readme.md` says **"a line costs exactly one byte of p-code, plus a four-byte
entry in the compiler's line-number table"**, and that is true -- of BASIC lines. It is easy to
read it as "source lines", and then to spend an afternoon pulling labels onto statements for
nothing. The cruncher's own rule 2 ("a label names a line, so a line carrying one cannot fold into
its predecessor") is about what the tool may safely do, not about where the savings are.

**The savings come from merging STATEMENT lines**, where the label rule and the `IF` rule allow it:

- `MENUVERT.INC.BL`, 23 lines merged, **23 bytes** -- the GP.CASE bodies and the multi-statement
  setup lines, all real statement merges.
- `MENUBAR.INC.BL`, 14 merges, **0 bytes** -- every one of them a label fold. GPBMODS compiled to
  `OK CODE 19778` before and after, and even tokenised to the same 36,318.

## What is still worth doing by hand

Folding a label reads better and costs nothing, so it is a style choice, not an optimisation. Say
so rather than quoting a saving. See [[basl-cruncher-built]] and
[[basload-basic-ram-is-the-tokenise-ceiling]] -- on that second one, comment lines DO matter,
because `GP.ASM` rides in `REM` statements that survive tokenising even though `##` prose does not.
