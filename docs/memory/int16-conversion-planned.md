---
name: int16-conversion-planned
description: "GPC-BASIC library % (int16) conversion planned 2026-09-13, not started; where the handoff and the check tool are"
metadata: 
  node_type: memory
  type: project
  originSessionId: 422a7b37-5897-4def-9e69-98fb13f87ae9
  modified: 2026-09-12T21:04:50.527Z
---

The library's untyped numeric scalars are to take `%` where they fit, then root, XBASE and GPC.HELP
follow. Nothing was converted as of 2026-09-13.

Handoff: `GPC-BASIC-TOOLS-SRC/GPB-MODS-TESTING/INT16-HANDOFF.md`. Tool: `source/gpc/int16scan.py`
(`--names`, `--check`, `--spread`).

**Why:** 4 B of workspace a scalar and zero p-code; about 1,384 B on GPBMODS, 1,500 B on XBASE.

**How to apply:** read the handoff before renaming a variable. A missed site compiles clean and
splits the variable in two. See [[library-working-copy-then-root]], [[array-element-sizes-measured]],
[[basload-label-and-variable-collide]].

A `%` scalar costs 2 bytes ([[every-scalar-allocated-six-bytes]]).

**Scope decided 2026-10-03.** The TURBO GPC GUI change converts the 14 modules it touches, public
names included ([[turbo-gpc-ide-plan]]). It fixes every caller in the same pass. The rest of the
library is converted before the release. TODO.md, Wanted, has the entry.

**A value the caller hands in can be an address, and int16scan cannot see it.** A `GP.BOX` style of
256 or more is a glyph address. On 2026-10-03 a string heap address measured 40,692. Stored in an
int16 it reads -24,844, and `GP.BOX` then draws nothing. The scan passed `MENU.STYLE%` and
`GUI.STYLE%`, because the module never calls `GP.STRPTR` itself; MENUTO.EXP.BL does. Those
variables, `DLG.STYLE` and `GUI.BOX.STYLE` are untyped again, each with a WARNING at its `GP.BOX`.
Before converting a formal, check what callers may pass in, not only what the module assigns.
