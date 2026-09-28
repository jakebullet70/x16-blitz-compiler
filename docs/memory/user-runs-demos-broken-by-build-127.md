---
name: user-runs-demos-broken-by-build-127
description: "USER-RUNS demos: the runtimes are back beside each sample since 2026-09-28, but GPC.ERR.PRG and GPC.GUI.PRG are still build-126 objects and need a rebuild"
metadata:
  node_type: memory
  type: project
  originSessionId: a6c8e91e-e94a-4d89-bcb6-b55accf60704
  modified: 2026-09-28T10:37:52.014Z
---

Found 2026-09-27. Build 127 (c6919f0) moved the runtimes into `GPC-BASIC-TOOLS-SRC/GPC/` and deleted the per-sample copies, while the USER-RUNS demos still mount the sample folder as the drive, so `/GPC/` was invisible. On 2026-09-28 the nine tool files were copied back into every sample folder (see [[tool-home-layout-deferred]]), which closes the drive problem.

Still open:
- `gpcerr-demo.bat`: `GPC-HELP/GPC.ERR.PRG` and `GPC.ERR/GPC.ERR.PRG` are build-126 objects and ask for `GPC.RT.126.BIN`, which no longer exists anywhere. Rebuild at 127 with the two commands in the bat header, then copy GPC.ERR.PRG and .OVL into GPC-HELP.
- `gpc-gui-demo.bat`: `GPC.GUI.PRG` is a 126 object, same rebuild.
- `help-demo.bat`: GPB.HELP.PRG is 127 and now finds its runtime. Expected to work; not re-run.
- EDIT.PRG, CRUNCH.PRG, COLORTST.PRG are embedded objects and never needed a runtime.

**How to apply:** rebuilds run in the emulator and take minutes; ask first, see [[run-builds-in-background]] and [[gpcerr-builds-in-its-sample-folder]].
