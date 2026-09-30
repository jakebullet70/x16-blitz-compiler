---
name: samples-build-in-place
description: Every sample is tokenised and compiled in its own folder, GPBMODS included; never stage sources or modules into source/drive/
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 0d6e3a5c-1c6a-49d8-8913-24b4a3de4616
  modified: 2026-09-30T12:32:34.194Z
---

Samples build in their own folder, with that folder as the emulator drive. Do not copy
sources or `.INC.BL` modules into `source/drive/` to build or test them. The master includes its
modules with the folder name, `#INCLUDE "GPC-BASIC/GPB.INC.BL"` (no leading slash), so the copy
beside the sample is the one read.

**Why:** on 2026-09-13 the user said "stop copying to testing, they are tested in place now".
The flat copy in `source/drive/` is how stale modules (an old GUI.INC.BL, a downgraded GPB.INC.BL)
got built without warning.

**How to apply:** `build_basl.py` and `compile_shared.py` take `--drive DIR`, and
`samplesbuild.py` builds every program in its src folder; it has no staging path left. On
2026-09-30 GPBMODS moved too: its 26 library `#INCLUDE` lines gained the `GPC-BASIC/` prefix (the
user's go-ahead), `modsbuild.py` was deleted, and `gpbmods-demo.bat` mounts
`GPC-BASIC-TOOLS-SRC/GPB-MODS-TESTING`. `samplesbuild.py` warns when a folder's
`GPC-BASIC/GPB.INC.BL` differs from root's, since the keyword ABI is root's.
[[headless-basl-build-recipe]] still describes staging. See [[release-samples-shape]].
