---
name: blitz-x16-r44-plus-keywords
description: "The R44+ X16 keywords Blitz was missing are all in and implemented — verified 6th September 2026, do not re-fix"
metadata: 
  node_type: memory
  type: project
  originSessionId: 6e74cea8-6119-4555-a4b8-303deb39e634
  modified: 2026-09-06T02:23:06.605Z
---

**Closed.** The gap this note recorded no longer exists. Verified 2026-09-06 against the tree:

- `source/common-scripts/c64tokens.py` `getX16()` carries all ten that were missing — `SPRITE`,
  `SPRMEM`, `MOVSPR`, `BASLOAD`, `OVAL`, `RING`, `HBLOAD`, `TDATA`, `TATTR`, `MOD`.
- `LINPUT#` / `LINPUT` are in ROM order, and both have handlers in `x16_command.def`.
- `OVAL`, `RING`, `SPRITE`, `SPRMEM`, `MOVSPR` compile from `x16_command.def`; `MOD`, `TDATA`,
  `TATTR` from `x16_unary.def`. `samples/editor` calls `MOD`.

Do not "fix the table" again, and do not write `GP.MOD` — `MOD(A,B)` is a working X16 keyword here.

The one durable fact behind the original note, also stated in `c64tokens.py`: ROM statements number
upward from `$CE80` and ROM functions re-anchor at a fixed `$CED0`, so ROM growth can never reach
below `$CE80`. That is why `GP.*` allocates **downward** from `$CE7F`.

See [[blitz-x16-basic-conformance]] for the semantic defects, which are still open.
