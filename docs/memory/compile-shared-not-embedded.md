---
name: compile-shared-not-embedded
description: "Standing instruction from 2026-09-04: compile SHARED, not --embedded; the checked-in GPC-HELP object stays uncrunched"
metadata:
  node_type: memory
  type: feedback
---

**Compile SHARED from now on.** Said on 2026-09-04, after a CRUNCH comparison on `HELP.BASL`:
*"will ship uncrunched, compile shared from now on though."* The same message settled the other
half — the checked-in `HELP.PRG` stays **uncrunched**; CRUNCH was a measurement, not a build step.

**Why:** shared compiles faster and its byte count IS the p-code, which is the number worth
watching. `--embedded` bundles ~13 KB of runtime image into every object, so its size hides the
only figure a change moves. It also needs a versioned `GPB.RT.nnn.BIN` on the drive, which is one
more thing to have deleted.

**How to apply:** `python source/gpc/compile_shared.py SRC.PRG OUT.PRG` with no `--embedded`.
Ask before building embedded, including for the checked-in `samples/GPC-HELP/HELP.PRG` — that one
is embedded today and the readme says why, so switching it is a decision, not a default.
A shared object needs `GPC.RT.nnn.BIN` beside it at run time.

See [[no-ship-language-this-is-dev]] (do not build unless asked) and [[basl-cruncher-built]]
(what CRUNCH is worth: 349 lines and 265 bytes on GPC-HELP, 2.5%).
