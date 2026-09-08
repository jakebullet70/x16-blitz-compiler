# `testing/` -- the emulator drive

**This folder is `-fsroot`.** Every headless build run points the emulator here, so anything a
program has to LOAD, OPEN or SAVE at run time has to be sitting in it. That is the whole reason
the folder exists, and the whole reason it fills up.

**Almost everything here is disposable.** Only the sixteen files listed below are worth keeping;
if a file is not on this list, it is build output, a staged copy of something tracked elsewhere,
or a probe that has served its purpose. Cleaned to this state on 2026-09-09, when it had reached
13 MB and 300-odd files, of which four megabytes were emulator memory dumps from one debugging
afternoon. The pre-clean state is `../testing-archive-2026-09-09.zip`.

## What is kept, and why

### The toolchain -- deleting these breaks the build

| | |
|---|---|
| `GPC.BIN` | the compiler engine. `source/gpc/compile_shared.py` runs it. `source/application/GPC.BIN` is the master; this copy can go stale, which is the point -- see `docs/memory/baseline-compiler-is-the-application-copy.md` |
| `BASLOAD-GPC.BIN` `BASLOAD-GPC.PRG` | the tokeniser, and its front end. `source/gpc/build_basl.py` runs them |
| `GPC.RT.120.BIN` | the resident runtime a SHARED object loads instead of carrying a copy |
| `GPB.RT.120.BIN` | the same, for a program that uses a GPB keyword |
| `GPC.IMG.120.BIN` | the runtime image the compiler embeds for `--embedded` |
| `GPC.BASL` `GPC.PRG` | the compiler's own BASL front end. `source/gpc/GPC.BASL` is the master |

**The three `*.RT.*` / `*.IMG.*` files are INSTALLED, not built here.** `make libs` does not put
them in place; `make -C source/runtime gpc-rt` does. Delete them and the next compile fails.

### Reference, not machinery

| | |
|---|---|
| `GPC.ERR.BASL` `GPC.ERR.PRG` `C.GPC.ERR.PRG` | the error-line helper. It must be built SHARED and in the main directory -- `docs/memory/gpcerr-build-shared-in-main-dir.md` says why, and the source's own header repeats it |
| `DIR.PRG` | the worked example in `README.md`: the program the compiler is demonstrated on |
| `POINTER.PRG` | cited by `TODO.md` for the `POINTER` return-value mismatch |
| `MD5` | the X16 wiki's MD5 program. It builds its constants in a way `altbase.asm` had to be fixed for |
| `MSEDIT/` `XFMGR/` | two third-party X16 applications, kept to run against. `MSEDIT/BASLOAD.MD` is BASLOAD's own manual, and the `basload` agent reads it |
| `ED` `XT` | two-line BASIC stubs that LOAD those two |

## What gets deleted, and what puts it back

| what | where it comes from |
|---|---|
| `*.INC.BL`, `<PROGRAM>.BASL` | copied in from `samples/<name>/GPC-BASIC/` and `GPC-BASIC/` before a build. The tracked copy is the master; one here that outlives a build is stale |
| `*.SRC.PRG` `*.SRC.SYM` | `build_basl.py` |
| `*.PRG` `*.B04`..`*.Bnn` `*.MAP` | `compile_shared.py` -- the object, its region overlays, and the map |
| `GPC.INPUT` `GPCCOMP.LOG` `RUN.LOG` | the headless harness's scratch |
| `samples/` | `make samples`, mirroring the tracked `samples/` tree |
| `HELP-TXT/` | xcopied from `samples/GPC-HELP/HELP-TXT/` so `GPB.HELP.PRG` can read it off the drive |
| `dump*.bin` | the emulator's `-dump` -- 565 KB each, and nothing reads them afterwards |
| `FIODIR/` `ZZDIR/` | left behind by FILEIO's MKDIR tests when a run does not reach its RMDIR |

**A one-off probe does not belong here once it has answered its question.** Seventy of them
accumulated -- `BANKA`..`BANKZ` for the region work, `DEFFN*`/`DEFP*` for the verbs, `BSTR*` and
`TXT*` for the text banks -- and none was ever run twice. What each one proved is written up in
`docs/memory/`, which is the record; the file is not. They are in git history to `afbbc55` and in
the archive zip. **A probe worth keeping is a unit test**, and belongs in
`source/unit-tests/compiler-runtime/`.
