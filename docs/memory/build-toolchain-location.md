---
name: build-toolchain-location
description: "Where make, 64tass and python actually live on this box -- none of them are on any shell PATH"
metadata:
  type: reference
---

Neither Git Bash nor PowerShell has these on PATH; searching the usual places finds nothing.

- `C:\8bitProgramming\64tass-1.60\64tass.exe`
- `C:\8bitProgramming\make-4.4.1\bin\make.exe`
- `C:\Users\Admin\AppData\Local\Programs\Python\Python313\python.exe` (`python` alone is not found;
  the harness scripts must be run with this full path)

The engine build (`make libs`, `make release`) also wants `SDLDIR = C:/sdl2` per
`documents/common.make`. A rebuild of the compiler and the runtime image must happen TOGETHER when a
constant in `source/common-source/source/common.inc` changes -- `FrameStackPages` and `MIN_WS_PAGES`
are read by both ends, and the file says so.

See [[headless-basl-build-recipe]] for the emulator side, which needs none of this.
