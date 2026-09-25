---
name: gpc-home-path-form
description: "On R49 hostfs, a file in the /GPC tool home opens as \"/GPC/NAME\" from any subfolder; the CMD form works too"
metadata:
  type: project
---

Measured 2026-09-25 on R49, hostfs, `-fsroot GPC-BASIC-TOOLS-SRC`, after `DOS"CD:BMXVIEWER"`:

- `OPEN 2,8,2,"/GPC/GPC.BIN,S,R"` gives `00, OK`. The CMD form `"//GPC/:GPC.BIN"` also works.
- `LOAD "/GPC/BASLOAD-GPC.PRG"` loads.
- `"/GPC/GPC-BASIC/GPB.INC.BL"` opens, so a nested path works.
- A bare `GPC.BIN` from the subfolder gives `62, FILE NOT FOUND`, as expected.

Use the plain `/GPC/NAME` form everywhere. An SD card image (FAT32) is not measured yet.

The probe is `source/scratch/gpchome/probe.py`. `make install` fills `GPC-BASIC-TOOLS-SRC/GPC/`.
See [[keep-claude-files-off-the-root]].
