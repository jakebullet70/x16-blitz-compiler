---
name: int16-conversion-planned
description: "GPC-BASIC library % (int16) conversion planned 2026-09-13, not started; where the handoff and the check tool are"
metadata: 
  node_type: memory
  type: project
  originSessionId: 422a7b37-5897-4def-9e69-98fb13f87ae9
  modified: 2026-09-12T21:04:50.527Z
---

The library's untyped numeric scalars are to take `%` where they fit, then root, XBASE and GPB.HELP
follow. Nothing was converted as of 2026-09-13.

Handoff: `samples/GPB-MODS-TESTING/INT16-HANDOFF.md`. Tool: `source/gpc/int16scan.py`
(`--names`, `--check`, `--spread`).

**Why:** 4 B of workspace a scalar and zero p-code; about 1,384 B on GPBMODS, 1,500 B on XBASE.

**How to apply:** read the handoff before renaming a variable. A missed site compiles clean and
splits the variable in two. See [[library-working-copy-then-root]], [[array-element-sizes-measured]],
[[basload-label-and-variable-collide]].
