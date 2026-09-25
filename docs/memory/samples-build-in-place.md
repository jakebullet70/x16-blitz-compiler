---
name: samples-build-in-place
description: Samples are tokenised and compiled in their own folder now; never stage sources or modules into source/drive/
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 0d6e3a5c-1c6a-49d8-8913-24b4a3de4616
  modified: 2026-09-13T12:19:29.057Z
---

Samples build in their own folder, with that folder as the emulator drive. Do not copy
sources or `.INC.BL` modules into `source/drive/` to build or test them. The master includes its
modules with the folder name, `#INCLUDE "GPC-BASIC/GPB.INC.BL"` (no leading slash), so the copy
beside the sample is the one read.

**Why:** on 2026-09-13 the user said "stop copying to testing, they are tested in place now".
The flat copy in `source/drive/` is how stale modules (an old GUI.INC.BL, a downgraded GPB.INC.BL)
got built without warning.

**How to apply:** `build_basl.py` and `compile_shared.py` take `--drive DIR`. In
`samplesbuild.py` a program marked `inplace=True` builds in its src folder and stages nothing.
Only GPB.HELP has that mark so far. GPBMODS, COLORTST, EDITOR and BMXVIEW still include bare
names, and their folders have no GPC.BIN or BASLOAD-GPC.BIN. They stay staged until their
includes change, and the user makes that change. [[headless-basl-build-recipe]] still describes staging.
