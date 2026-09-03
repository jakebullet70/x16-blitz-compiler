---
name: paste-cannot-drive-a-running-program
description: "x16emu -bas paste only feeds the READY prompt, so an interactive compiled program cannot be tested headlessly - build a fixed-answer variant instead"
metadata: 
  node_type: memory
  type: project
  originSessionId: 0ab8399a-fad5-4910-bb84-5b25da13690f
  modified: 2026-09-03T15:59:19.464Z
---

**`x16emu -bas FILE -pastewarp` types FILE's text at the READY prompt only.** Once a program is
running, the rest of the paste does not reach its `GET` loop — it is dropped, not queued. Padding
the paste with `CHR$(20)` so a startup `CLEAR.KB` drain has something harmless to eat does **not**
help; the keys never arrive at all.

So an interactive front end (`GPC.PRG`, `CRUNCH.PRG`) **cannot be driven headlessly**. What works
instead, and what actually needs testing:

**Generate a fixed-answer variant FROM the real source** and compile that. A script that replaces
each `PR$ = "..." : GOSUB READLINE` / `GOSUB YESNO` with a literal assignment, asserting every
pattern was found, keeps the harness honest — it tests the real file's write path and hand-off,
and only the key-reading loop goes untested. That loop is lifted verbatim from `GPC.BASL` anyway.

This is how the `CRUNCH.INPUT` field format and the chain-load were verified for
[[basl-cruncher-built]] — and it immediately caught a real bug the engine's own tests could not
have: the front end writes CR-terminated output, which the engine's sniffer misread
([[basl-sources-use-all-three-line-endings]]).

Chain-loading is fine in both directions: **a compiled GPC program chain-loads another compiled
GPC program**, EMBEDDED or SHARED, with `LOAD "NAME"` and no `,8`.
