---
name: basl-dead-code-elimination-measured
description: "MEASURED 2026-09-07: stripping never-called routines from GPBMODS saves 1,212 resident bytes (8.9%), but 691 of those are free by deleting two #INCLUDE lines -- automatic tree shaking is worth 521 bytes over doing nothing clever."
metadata:
  type: project
---

**PARKED, to revisit.** The question was whether BASLOAD should drop routines the program never
calls before it writes the tokenised file. Measured with `source/unit-tests/deadcode.py`, which
reproduces every number here.

## What it is worth

`GPBMODS.BASL` -- 210 label blocks, **18 unreachable**, 387 of 2,073 source code lines.

| | resident bytes | |
|---|---:|---|
| p-code total | 13,563 | |
| **dead** | **1,212** | **8.9%** |

and the split that decides the design:

| | bytes | |
|---|---:|---|
| whole unused modules -- `SORT`, `STRCASE` | 691 | 57% |
| dead routines **inside** modules that are used | 521 | 43% |

**691 of it is free today.** Delete the `SORT` and `STRCASE` `#INCLUDE` lines from
`GPBMODS.BASL`; they are included for their menu rows and never called. Automatic tree shaking
buys **521 bytes over that, 3.8%**, for ~200 lines of assembly and a new class of silent failure.
The 521 is what hand-gating cannot reach cheaply -- 426 of it is `STRINGS`, which would need a
`#IFNDEF` around each of eight routines.

`GPBFILES.BASL` has the same 18 dead blocks plus `FILE.COPY`. **Not priced** -- it fails
`PROGRAM TOO BIG`, so there is no map, and nobody has measured how far over it is. That number
decides whether this is the fix for it or a footnote next to
[[gpbmods-resident-pcode-breakdown]]'s GOSUB-frame code-bank field.

## The analysis, and why it is shaped this way

`source/unit-tests/deadcode.py <TOP.BASL> [dirs] --price MAP SYM [gpBankStart]`.

**Reachability must be transitive, not a reference count.** `FILE.DIR.OPEN` calls `BANKHOLD`,
`WHERE`, `ASKFOR` and `SUCK`, so if nothing calls `OPEN`, refcounting still sees four live
references and keeps all five routines. **Dead code holds dead code up**, and it holds it up in
exactly the library-module case this exists to find.

**An edge is any whole-token occurrence of a label name**, not a parse of `GOTO` / `GOSUB` /
`THEN` / `ON..GOSUB`. That is exact rather than lazy: labels and variables share one name space
(see [[basload-label-and-variable-collide]]), so a name is one or the other and never both. Blank
string literals first or menu text naming a routine reads as a call to it -- `GPBMODS` has a
`MENUVERT.ITEM$` of `" SORT.RUN"`.

A **block** is a label and everything up to the next label. The program entry is the only root.
Fall-through keeps the next block alive unless this one ends `RETURN` / `END` / `STOP` / `GOTO`.

## The trap that turned out not to be here

`READ` walks every `DATA` in the program in order, so dropping one inside a dead region silently
derails the caller's own `READ`s -- wrong data, no error. `DIM` is the same shape. **No dead block
in either program contains either**, but any implementation has to refuse to strip one that does.

Second unresolved trap: a variable assigned only in dead code still has a `#SYMFILE` entry, so a
`GP.ASM` blob reaching it through `{VAR}` may find a symbol and no runtime variable. Unchecked.

## Not measured

Whether `GPC` is the better home. It would work over line numbers instead of labels -- finer, no
renumbering, and it would cover hand-written `.PRG` input -- but it cannot see that six labels are
one routine, and it needs a compiler rebuild.
