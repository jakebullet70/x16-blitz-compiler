---
name: gpc-gui-next-defs-in-a-folder
description: "Asked for on 2026-09-16, not started: GPC.GUI saves and loads its definition and project files in a GPC-GUI-DATA folder"
metadata:
  type: project
---

**Next editing session on `samples/GPC-GUI-HELPER/GPC.GUI.BASL`:** the definition
files and project files it saves and loads move into a folder named
**`GPC-GUI-DATA`**. Asked for 2026-09-16, deliberately deferred to its own session.

Today they are written to the current drive by bare name — `FILE.NAME$ =
GG.DEFNAME$` straight into `FILE.SAVEARRAY` and `FILE.LOADARRAY`. The change is a
path prefix in one place each, plus whatever CMDR-DOS wants for a directory that
does not exist yet, plus the OPEN dialog's default.

Related: [[samples-build-in-place]], [[gpc-gui-size-not-a-constraint]].
