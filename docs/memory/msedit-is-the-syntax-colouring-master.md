---
name: msedit-is-the-syntax-colouring-master
description: "Where the Prog8 BASIC syntax colouring lives (x16-MSEDIT/SRC/syntax.p8), what it covers, and its measured keyword gap against GPC's token list"
metadata:
  node_type: memory
  type: reference
  originSessionId: d3ac16d2-cd1b-4147-b724-55dc40a31b99
  modified: 2026-10-02T11:11:40.937Z
---

The BASIC syntax colouring the user wrote is in `C:\dev\CmdrX16\dos_tools\x16-MSEDIT\SRC\`. XFMGR2's
`SRC\xsyntax.p8` is a port of it, built as the overlay `XSYNTAX.OVL`.

| file | what to take from it |
|---|---|
| `syntax.p8` (216 lines) | `classify(src, len, dest)` writes one colour byte a column. Stateless per line. |
| `edit.p8:1077` `draw_wrapped_row` | The row painter: classify once, one VERA address setup, two `DATA0` writes a cell, column slice for horizontal scroll. |
| `misc.p8:199` `kw_addrs` | The three keyword blobs, space-delimited, each under 256 bytes. |
| `theme.p8` `TABLE` | Six syntax colours a theme, hand-picked per background. |
| `basload.md` | The BASLOAD language spec. |

`tview.p8` is a paged viewer that re-opens the file and skips bytes on every page. It colours only
Markdown headings. Nothing in it beats what GPC.HELP already does.

**Keyword gap, measured 2026-10-02 against `source/common-scripts/c64tokens.py`.** GPC has 191 tokens:
151 plain and 40 `GP.*`. MSEDIT's blobs hold 94 words. 61 plain tokens are missing, 390 bytes with
separators. Four MSEDIT words are not tokens: `CIRCLE`, `ELSE`, `FONT`, `KEY`. No `GP.*` word is in the
blobs, and a dotted name is one token, so every `GP.` word comes out uncoloured.

**Rules the classifier lacks:** `#` directives, labels, `$hex` and `%binary` numbers, `GP.` words, and
`REM` lines inside `GP.ASM`, which it colours as comments.

GPC.HELP's port of it, with those rules added, is [[help-source-viewer-state]].

Related: [[gpc-help-scroll-cost-is-the-file-read]], [[ask-before-writing-asm]].
