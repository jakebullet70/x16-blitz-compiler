---
name: basl-sources-use-all-three-line-endings
description: "LF, CRLF and CR all appear in the tree - how to sniff which, and the short-CR-file trap that reads as CRLF"
metadata: 
  node_type: memory
  type: project
  originSessionId: 0ab8399a-fad5-4910-bb84-5b25da13690f
  modified: 2026-09-03T15:59:10.684Z
---

**Any tool reading BASL source has to handle all three endings, because the tree uses all three:**
`EDITOR.BASL` and everything in `GPC-BASIC/` are **LF**, `testing/GPC.BASL` is **CRLF**, and the
editor itself **writes CR**. BASLOAD takes any of them, so a source-to-source tool must too — and
must write back what it found.

**One probe read with `LINPUT# 2, P$, 10` tells them apart:**

| probe | file is | read with |
|---|---|---|
| no CR at all | LF | delimiter 10 |
| **first** CR is the LAST character | CRLF | delimiter 10, strip trailing CR |
| a CR before the end | CR only | delimiter 13 |

**THE TRAP: test WHERE the first CR is, not whether the probe ends in one.** A short CR-terminated
file comes back **whole** from a delimiter-10 read and therefore ends in a CR exactly like a single
CRLF line does. `CRUNCH.INPUT` is precisely that file — the front end writes it with `PRINT#`,
which emits CR — and reading it as CRLF found zero fields and the engine reported `LINES READ 0`
with no error. `GP.INSTR(P$, CHR$(13)) = LEN(P$)` is the CRLF test; anything else with a CR is
CR-only.

The probe eats the first line, so close and reopen after sniffing.

Used by [[basl-cruncher-built]]; the `LINPUT#` mechanics and the `ST AND 2` missing-file guard are
in [[gpc-editor-loader-linput-and-blob]].
