---
name: basload-autonum-breaks-strcase
description: "#AUTONUM with STRCASE.INC.BL included compiles to UNKNOWN LINE NUMBER - drop the directive, do not chase the label"
metadata: 
  node_type: memory
  type: project
  originSessionId: 0ab8399a-fad5-4910-bb84-5b25da13690f
  modified: 2026-09-03T15:58:54.834Z
---

**`#AUTONUM 5` plus `#INCLUDE "STRCASE.INC.BL"` makes GPC stop with `UNKNOWN LINE NUMBER @ 129`.**
Remove the `#AUTONUM` line and the identical source compiles and runs.

The failure names a line number that **cannot exist** — 129 is not a multiple of the step — so the
temptation is to hunt for a bad `GOTO` in your own code. There is none. BASLOAD resolves the
included module's label targets against the wrong step; `STRCASE.INC.BL` has a `GOTO
STRCASE.MODULE.END` jumping over its own body, which is what lands wrong.

`GPC.BASL` uses `#AUTONUM 5` happily with only `GPB.INC.BL`, so the directive is not broken on its
own — it is the combination. **Default step 1 is fine; just leave `#AUTONUM` out.**

Found while building [[basl-cruncher-built]], whose engine includes STRCASE for its in-place
TRIM/UPPER.
