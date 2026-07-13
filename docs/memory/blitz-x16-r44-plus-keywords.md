---
name: blitz-x16-r44-plus-keywords
description: The 10 X16 BASIC keywords added after R43 that Blitz does not know, plus a LINPUT/LINPUT# token swap
metadata:
  type: project
---

Blitz's keyword table (`source/common-scripts/c64tokens.py`, `getX16()`, dated **April 2023** = the R42/R43
era) is stale against R49. Verified by decoding the keyword text table straight out of BASIC ROM bank 4
(`bin/x16emu/rom.bin`) and cross-checking types/origins against `docs/x16/X16 Reference - 04 - BASIC.md`.
**ROM has 81 extended keywords; Blitz knows 71.**

**Token layout (why this is safe to fix):** extended statements are `$CE80 + index`, and functions restart at
a FIXED anchor `$CED0`, keyed off the position of `VPEEK` in the same text table. So statements can grow
without disturbing any function token. Every keyword Blitz already knows has the correct token value —
confirmed against the ROM — with the one exception below.

**MISSING (10).** Adding a statement here means inserting it before `VPEEK` in the list; the function block
re-anchors itself automatically.

| keyword | token | manual type | worth compiling? |
|---|---|---|---|
| `SPRITE`  | `$CEBB` | Statement | yes |
| `SPRMEM`  | `$CEBC` | Statement | yes |
| `MOVSPR`  | `$CEBD` | Statement | yes |
| `BASLOAD` | `$CEBE` | **Command** | no — dev-time loader, `LIST` class |
| `OVAL`    | `$CEBF` | Statement | yes — same family as `LINE`/`FRAME`/`RECT`, already supported |
| `RING`    | `$CEC0` | Statement | yes |
| `HBLOAD`  | `$CEC1` | **undocumented** | no — in the ROM table, no entry in the manual |
| `TDATA`   | `$CEDC` | Function | yes |
| `TATTR`   | `$CEDD` | Function | yes |
| `MOD`     | `$CEDE` | Function | yes |

The manual's **Type** column is the triage signal: "Command" (`BASLOAD`) means interactive, not something a
compiled program contains. `HBLOAD` has no manual entry at all.

**BUG — `LINPUT` / `LINPUT#` are swapped.** Blitz: `LINPUT=$CEB3, LINPUT#=$CEB4`. ROM: `LINPUT#=$CEB3,
LINPUT=$CEB4`. Both are still on TODO.txt's "Add" list so nothing emits them yet, but the tokeniser would
produce the wrong byte the moment they are implemented. Fix the ORDER in `getX16()`, not just the names.

Two layers to any fix: (1) `c64tokens.py` — shared by the host tokeniser (`tokenise.zip`) AND the compiler,
so they cannot disagree; (2) the compiler needs a handler emitting P-code and the runtime an implementation.
Adding to the table alone buys correct tokenisation and a clean "unsupported" error instead of a syntax error.

See [[blitz-x16-basic-conformance]] for the separate semantic defects (float literals, STEP 0, sci notation,
reversed relops).
