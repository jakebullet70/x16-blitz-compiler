---
name: basload-autonum-breaks-strcase
description: "Do not write #AUTONUM: it sets the STEP, and any step but 1 plus STRCASE.INC.BL gives UNKNOWN LINE NUMBER"
metadata: 
  node_type: memory
  type: project
  originSessionId: 0ab8399a-fad5-4910-bb84-5b25da13690f
  modified: 2026-09-05T00:00:00.000Z
---

**Do not write `#AUTONUM`.** It does not turn numbering on: BASLOAD numbers every output line
whatever you write, and the directive only sets the **step** between the numbers, default 1. Step 1
is the only one the library survives, so the directive has one correct value and is better left
out.

**`#AUTONUM 5` plus `#INCLUDE "STRCASE.INC.BL"` makes GPC stop with `UNKNOWN LINE NUMBER @ 129`.**
Set the step back to 1 and the identical source compiles and runs.

The failure names a line number that **cannot exist** — 129 is not a multiple of the step — so the
temptation is to hunt for a bad `GOTO` in your own code. There is none. BASLOAD resolves the
included module's label targets against the wrong step; `STRCASE.INC.BL` has a `GOTO
STRCASE.MODULE.END` jumping over its own body, which is what lands wrong. At step 1 a line's number
and its ordinal position are the same number, which is why nothing shows until the step moves.

**It is GPC's error, not BASLOAD's** — `ErrorV_line` in `bin/common.library`, spelled
`UNKNOWN LINE NUMBER`. The tokenise succeeds and BASLOAD reports nothing; the bad `GOTO` target only
gets refused a step later, so look in `CMP.LOG`, not `TOK.LOG`.

`GPC.BASL` uses `#AUTONUM 5` happily with only `GPB.INC.BL`, so the directive is not broken on its
own — it is the combination. **`GPB.HELP.BASL` and `CRUNCHER.BASL` carry no `#AUTONUM` and a
comment saying why**, and take the default step.

Found while building [[basl-cruncher-built]], whose engine includes STRCASE for its in-place
TRIM/UPPER.
