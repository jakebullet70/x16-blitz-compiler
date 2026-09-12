---
name: build-toolchain-location
description: "Where make, 64tass, python and node actually live on this box -- only node is on a shell PATH"
metadata:
  type: reference
---

Neither Git Bash nor PowerShell has these on PATH; searching the usual places finds nothing.

- `C:\8bitProgramming\64tass-1.60\64tass.exe`
- `C:\8bitProgramming\make-4.4.1\bin\make.exe`
- `C:\Users\Admin\AppData\Local\Programs\Python\Python313\python.exe` (`python` alone is not found;
  the harness scripts must be run with this full path)
- `C:\8bitProgramming\nodejs\node.exe` -- Node 24.21.0 LTS, npm 11.19.0,
  installed 2026-09-11 from the official zip. This one IS on the user PATH, so a NEW shell finds
  `node`, `npm` and `npx`; a shell started before that edit does not. No winget, choco or scoop here.

The engine build (`make libs`, `make release`) also wants `SDLDIR = C:/sdl2` per
`documents/common.make`. A rebuild of the compiler and the runtime image must happen TOGETHER when a
constant in `source/common-source/source/common.inc` changes -- `FrameStackPages` and `MIN_WS_PAGES`
are read by both ends, and the file says so.

See [[headless-basl-build-recipe]] for the emulator side, which needs none of this.
