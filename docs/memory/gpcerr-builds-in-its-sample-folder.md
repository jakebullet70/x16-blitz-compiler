---
name: gpcerr-builds-in-its-sample-folder
description: GPC.ERR builds in samples/GPC.ERR/, which is its own emulator drive, and is always compiled SHARED against GPB.RT; a standalone build of it is the wrong artifact
metadata:
  type: project
---

`GPC.ERR` turns a runtime `<MSG> @ $XXXX` back into a BASIC line by reading a `M.<source>` debug map.

**It builds in `samples/GPC.ERR/`, which is the emulator drive.** Nothing is staged into `drive/`.
See [[samples-build-in-place]]. Two steps, from the repository root:

    python source/gpc/build_basl.py --drive samples/GPC.ERR GPC.ERR.BASL GPC.ERR.SRC.PRG
    python source/gpc/compile_shared.py --drive samples/GPC.ERR GPC.ERR.SRC.PRG GPC.ERR.PRG GPC.ERR.MAP

`source/gpc/samplesbuild.py` carries a `GPC.ERR` entry, `inplace=True` and `shared=True`, that runs
those two and installs `GPC.ERR.PRG` and `GPC.ERR.OVL` into `samples/GPC-HELP/`.

**User instruction, 2026-09-01: always compile it SHARED, never standalone.** Shared leaves the
runtime out of the object, ~12 KB a standalone build would carry. That is the point of a helper you
run beside the program you are debugging. A standalone build is not a bigger version of this
program, it is the wrong one. `scratchpad/edbuild.py` builds standalone, so nothing it produces may
be copied over the object.

It compiles against `GPB.RT.nnn.BIN`, the runtime with the GP handlers, not the core-only
`GPC.RT.nnn.BIN`. The folder carries build 126 of all three: `GPC.RT.126.BIN`, `GPB.RT.126.BIN` and
`GP1.RT.126.BIN`.

**The names carry no prefix.** Tokenised source `GPC.ERR.SRC.PRG`, symbol file `GPC.ERR.SRC.SYM`,
object `GPC.ERR.PRG`, overlay `GPC.ERR.OVL`, map `GPC.ERR.MAP`. The compiler bakes the object's own
name into the object and the bootstrap reads `<object name>.OVL` from it, so the object name and the
overlay name have to agree. `GPB.HELP` in `samples/GPC-HELP/` is the same shape.

**`GPC.ERR.OVL` has to travel with the `.PRG`.** It is 28,433 bytes and holds the six code regions
and the two text banks. Without it the program prints `?OVL` and stops. Both files are ordinary
tracked files in `samples/`, which git does not ignore.

**The object is 10,197 bytes after the GUI refactor (2026-09-25), against a 22,016 byte ceiling.**
The library runs from banked regions, so the resident p-code is the shell and the resolvers. See
`docs/blitz/GPC-ERR-GUI.PLAN.md` and [[gpc-shared-pcode-cap-is-rtbase]].

The build rule is also in the header of `samples/GPC.ERR/GPC.ERR.BASL` and in
`samples/GPC.ERR/readme.md`, where whoever rebuilds it will be looking.
