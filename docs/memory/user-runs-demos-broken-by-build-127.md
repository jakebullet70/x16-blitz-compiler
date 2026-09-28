---
name: user-runs-demos-broken-by-build-127
description: "USER-RUNS demos after Build 127: runtimes are back beside each sample and GPC.ERR is rebuilt; GPC.GUI.PRG is still a 126 object and the user wants to work on it before rebuilding"
metadata:
  node_type: memory
  type: project
  originSessionId: a6c8e91e-e94a-4d89-bcb6-b55accf60704
  modified: 2026-09-28T14:50:44.993Z
---

Found 2026-09-27. Build 127 (c6919f0) moved the runtimes into `GPC-BASIC-TOOLS-SRC/GPC/` and deleted the per-sample copies, while the USER-RUNS demos still mount the sample folder as the drive, so `/GPC/` was invisible. On 2026-09-28 the nine tool files were copied back into every sample folder (see [[tool-home-layout-deferred]]) and GPC.ERR was rebuilt at 127 and copied into GPC-HELP (84a0e8d).

Still open:
- `gpc-gui-demo.bat`: `GPC.GUI.PRG` is a 126 object and asks for `GPC.RT.126.BIN`, which no longer exists. The user said on 2026-09-28 they still want to work on GPC.GUI, so it gets rebuilt as part of that work, not on its own.
- `help-demo.bat` and `gpcerr-demo.bat`: expected to work now; neither was re-run in a window.
- EDIT.PRG, CRUNCH.PRG, COLORTST.PRG are embedded objects and never needed a runtime.

**How to apply:** rebuilds run in the emulator and take minutes; ask first, see [[run-builds-in-background]] and [[gpcerr-builds-in-its-sample-folder]].
