---
name: release-samples-shape
description: "A release SAMPLES/<PROG> folder holds the program's own BASL (no GPC-BASIC modules) and a standalone EMBEDDED PRG, plus its .OVL and data"
metadata:
  node_type: memory
  type: feedback
  originSessionId: 6cb2a824-c1cb-47e0-8336-85f9918b1083
  modified: 2026-10-01T10:25:53.974Z
---

Each `release/TMP/SAMPLES/<PROG>/` folder holds the program's own sources and a PRG that runs on its
own. The five are `GPBMODS`, `BMXVIEW`, `COLORTST`, `GUI-LITE` and `MANDELBROT-SPEED`, all built
in their `GPC-BASIC-TOOLS-SRC` folders and copied by `release.sh` (the `SAMPLES` table).
`MANDELBROT-SPEED` also ships `MANDEL.SRC.PRG`, the tokenised source that ROM BASIC runs, because
the sample is a timing race against it.

- **Sources:** every file the compile needs that is not a `GPC-BASIC` library module, so
  `GPB-MENUS.BASL` beside `GPBMODS.BASL`, and the ten `ED-*.BASL` beside `EDIT.BASL`. The library
  modules are never copied into a sample folder.
- **Object:** EMBEDDED, so no `.RT.` file is needed. A banked program's `.OVL` ships beside it.
  BMXVIEW ships as `BMXVIEW.PRG` (no `C.` prefix), with its eight `.BMX` images.
- `EDIT` is out of the release. The user wants more work on it first.
- A folder `readme.md` stays in the source tree, except MANDELBROT-SPEED's. It ships as
  `README.md`, cut at `README_CUT` like the root README, so its build and demo-bat notes stay
  behind (user's ask, 2026-10-01).

**Why:** the user's spec, 2026-09-30: "bare src code (just BASL - not the needed GPC-BASIC) and
compiled standalone runnable prg", and "if a file is not included in GPC-BASIC but is needed to
compile then include it".

**The user reviews `release/TMP` and edits files there.** On 2026-09-30 they removed `#AUTONUM 5`
from `SRC/GPC/GPC.BASL` in place. A stage wipes the folder, so carry any such edit back to the
master named in `release.sh`'s tables first. `GPC.BASL` has two tracked masters kept identical,
`source/gpc/GPC.BASL` and `source/drive/GPC.BASL`; the stage reads the second.

**How to apply:** a new sample gets `shared=False` in `samplesbuild.py` and a `SAMPLES` entry that
lists its own sources, never its modules. Embedded costs no room: GPBMODS reports `LOW FREE 11008`
embedded against 9,984 for the same source shared, because the runtime sits in low memory in both
modes. See [[samples-build-in-place]].
