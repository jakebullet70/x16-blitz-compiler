---
name: user-runs-demos-broken-by-build-127
description: "USER-RUNS demos after Build 127: runtimes are back beside each sample and every object in the tree was recompiled at 127 on 2026-09-29"
metadata:
  node_type: memory
  type: project
  originSessionId: a6c8e91e-e94a-4d89-bcb6-b55accf60704
  modified: 2026-09-28T14:50:44.993Z
---

Found 2026-09-27. Build 127 (c6919f0) moved the runtimes into `GPC-BASIC-TOOLS-SRC/GPC/` and deleted the per-sample copies, while the USER-RUNS demos still mount the sample folder as the drive, so `/GPC/` was invisible. On 2026-09-28 the nine tool files were copied back into every sample folder (see [[tool-home-layout-deferred]]) and GPC.ERR was rebuilt at 127 and copied into GPC-HELP (84a0e8d).

On 2026-09-29 the runtime changed again under the same 127 name, so every object in the
tree was recompiled: GPBMODS, GPB.HELP, COLORTST, BMXVIEW, GPC.GUI, EDIT, GPC.ERR. All
seven passed. `GPC.GUI.PRG` is a 127 object now.

On 2026-09-30 the runtime moved to build 128 (see [[banked-error-address-unplaceable]]), the 127
files were replaced in all nine sample folders, and GPBMODS, GPC.HELP, COLORTST, BMXVIEW, GPC.GUI,
EDIT and GPC.ERR were rebuilt. CRUNCH and XBASE were not.

Still open:
- `help-demo.bat`, `gpcerr-demo.bat` and `gpc-gui-demo.bat` have not been re-run since.
- EDIT.PRG, CRUNCH.PRG, COLORTST.PRG are embedded objects and never needed a runtime.

**The trap this window surfaced:** `rtbuild.txt` does not move when the runtime code changes,
so `GPB.RT.127.BIN` was rewritten with different content and every object compiled against
the older 127 went stale under a name that still looked right. Compare the runtime's mtime
against each object's before trusting a build number.

**How to apply:** rebuilds run in the emulator and take minutes; ask first, see [[run-builds-in-background]] and [[gpcerr-builds-in-its-sample-folder]].
