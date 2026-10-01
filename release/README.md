# release/

The release drop folder. It is kept apart from `source/drive/`, which is the daily build and
scratch area. The folder is tracked so a fresh clone has it. Everything `release.sh` writes into
it is ignored.

| Entry | What | Git |
|---|---|---|
| `README.md` | this file | tracked |
| `TMP/` | the release unpacked, in the shape the zip will have | ignored, `/release/TMP/` in `.gitignore` |
| `gpc-release-<version>.zip` | the packaged download | ignored, `gpc-release-*.zip` in `.gitignore` |

`<version>` is the whole content of `source/application/buildnum.txt`, now `1.1.0`. It is edited by
hand when a release is cut. The `128` in runtime file names is a separate stamp, the runtime build
number, read from `source/application/rtbuild.txt`.

## Commands

`release.sh` is the only release build file. It is a POSIX script, run from Git Bash at the repo
root. `USER-RUNS/release.bat` puts make, 64tass and Python on PATH and passes its arguments through
to `release.sh`, so `release.bat stage` works.

| Command | Builds | Stages (wipes and refills `TMP/`) | Zips |
|---|---|---|---|
| `./release.sh` | yes | yes | yes |
| `./release.sh stage` | no | yes | no |
| `./release.sh zip` | no | no | yes, `TMP/` exactly as it stands |

The full build runs these steps in order.

| Step | Command | Writes |
|---|---|---|
| 1 | `make libs` | the libraries and the compiler engine `GPC.BIN` |
| 2 | `make release` | the engine and samples, staged into `source/drive/` |
| 3 | `make -C source/runtime gpc-rt` | the shared runtimes and their bank code, `GPB/GPC/GP1.RT.nnn.BIN` |
| 4 | `make -C source/gpc release` | `GPC.PRG` and `GPC.ERR` |
| 5 | `python source/gpc/samplesbuild.py` | the sample programs and `GPC.HELP` |

The sample build is last because some programs compile SHARED against the runtime step 3 wrote. It
is also the slow step.

## Workflow

1. Stage, with `./release.sh` or `./release.sh stage`.
2. Read `TMP/` and `TMP/MANIFEST.TXT`. Boot it with `USER-RUNS/tmp-emu.bat`.
3. Correct what is wrong.
4. Zip, with `./release.sh zip`. It does not restage, so a hand edit in `TMP/` goes into the zip.

WARNING: `stage` wipes `TMP/`, so a hand edit there is lost at the next stage. Carry the edit back
to its master file, named in the tables in `release.sh`, before staging again.

The layout is defined once, in `release.sh`: the LAYOUT section and the tables after it, including
`SAMPLES`.

## Helpers in `USER-RUNS/`

| File | Does |
|---|---|
| `release.bat` | runs `release.sh` with the toolchain on PATH |
| `tmp-emu.bat` | boots x16emu with `release/TMP` as its drive, to READY |
| `tmp-shell.bat` | opens a command prompt in `release/TMP` |

Inside `tmp-emu.bat`:

| Type | Starts |
|---|---|
| `RUN "XT"` | XFMGR |
| `RUN "GPC.PRG"` | the compiler |
| `RUN "GPC.HELP.PRG"` | the help |
| `DOS"CD:SAMPLES"`, then `DOS"CD:<FOLDER>"`, then `RUN "<NAME>.PRG"` | a sample |

## What `TMP/` holds

| Path | What | Zipped |
|---|---|---|
| `GPC.PRG` | compiler front end, the program you run | yes |
| `GPC.BIN` | compiler engine, loaded by `GPC.PRG` | yes |
| `GPC.IMG.128.BIN`, `GP1.IMG.128.BIN` | the runtime and bank 1 code a self-contained program carries | yes |
| `GPB.RT.128.BIN`, `GPC.RT.128.BIN`, `GP1.RT.128.BIN` | shared runtime with GP handlers, shared runtime without, and the bank 1 code both load | yes |
| `GPC.ERR.PRG`, `GPC.ERR.OVL` | maps a runtime error address to a source line, and its banked code | yes |
| `GPC.HELP.PRG`, `GPC.HELP.OVL` | the on-machine reference, and its banked code | yes |
| `BASLOAD-GPC.PRG`, `BASLOAD-GPC.BIN` | the streaming tokeniser and its engine | yes |
| `README.md` | the repo-root `README.md` up to the line `<!-- release: the rest is for the source tree -->` | yes |
| `LICENSE` | MIT licence | yes |
| `HELP-TXT/` | `GPC.HELP.IDX` and the `Hnnn.HLP` topic files `GPC.HELP` reads | yes |
| `GPC-BASIC/` | the GP.BASIC library whole, with `GP-BASIC.md`, `GP-BASIC.GLOBALS.md`, `GP-BASIC.FILES.md` and `README.md` | yes |
| `SRC/` | source of the tools; nothing in it is needed to run GPC | yes |
| `SAMPLES/` | one folder per sample program | yes |
| `MANIFEST.TXT` | every staged file, its size and where it came from | no |
| `XFMGR/`, `XT` | the file manager, and the 28-byte BASIC shim that loads it, for `tmp-emu.bat` | no, `DEV ONLY` |

The zip step skips `XFMGR/`, `XT` and `MANIFEST.TXT`. The list is `NOT_SHIPPED` in `release.sh`.

### `SRC/`

| Path | Holds |
|---|---|
| `GPC/` | `GPC.BASL` and `GPB.INC.BL`, the one module it includes |
| `GPC-ERROR/` | `GPC.ERR.BASL`, `ERRTOKEN.INC.BL`, `ERRSRC.INC.BL`, `README.md`, and `GPC-BASIC/` with the modules it includes |
| `GPC-HELP/` | `GPC.HELP.BASL`, `GPC-HELP.md`, `README.md`, `HELP-TXT/`, and `GPC-BASIC/` with the modules it includes |
| `GPC-BASLOAD/` | `BASLOAD-GPC.PRG`, `BASLOAD-GPC.BIN`, `BASLOAD-SRC.ZIP`, `basload-rom.bin`, `README.md`, `RESEARCH.md` |
| `README.TXT` | how to rebuild the tools; written by `release.sh` |

Each tool folder carries its own module copies. BASLOAD resolves `#INCLUDE` against the folder it
runs in, so the root `GPC-BASIC/` is out of reach from inside `SRC/`. The copies are the ones the
shipped object was built from.

### `SAMPLES/`

Every sample is EMBEDDED. It carries its runtime and runs from its own folder with nothing else on
the drive. A banked program loads its `.OVL` from beside it. A sample folder holds the program's own
BASL and none of the GPC-BASIC library modules, so a sample cannot be rebuilt where it sits.
`source/gpc/samplesbuild.py` builds each one in its folder under `GPC-BASIC-TOOLS-SRC/`.

| Release folder | Built in | Files | Program |
|---|---|---|---|
| `GPBMODS/` | `GPB-MODS-TESTING/` | `GPBMODS.BASL`, `GPB-MENUS.BASL`, `GPBMODS.PRG`, `GPBMODS.OVL` | library test harness: a menu bar whose dropdowns reach nearly every public library entry point |
| `BMXVIEW/` | `BMXVIEWER/` | `BMXVIEW.BASL`, `BMXVIEW.PRG`, eight `.BMX` images | BMX picture viewer |
| `COLORTST/` | `COLOR-TEST/` | `COLORTST.BASL`, `COLORTST.PRG` | edits a `THEME.INC.BL` theme against a mock of the GUI |
| `GUI-LITE/` | `GUI-LITE/` | `GUI-LITE.BASL`, `GUI-LITE.PRG` | a message box and a menu that fit in low memory |
| `MANDELBROT-SPEED/` | `MANDELBROT-SPEED/` | `MANDEL.BASL`, `MANDEL.SRC.PRG`, `MANDEL.PRG`, `MANDELASM.BASL`, `MANDELASM.PRG`, `README.md` | one Mandelbrot picture timed three ways |

MANDELBROT-SPEED on x16emu R49:

| Program | Runs as | Jiffies |
|---|---|---|
| `MANDEL.SRC.PRG` | ROM BASIC | 6,048 |
| `MANDEL.PRG` | compiled | 3,075 |
| `MANDELASM.PRG` | compiled, inner loop in GP.ASM | 284 |

The EDIT sample is built but kept out of the release.

## Placeholders

Staging never compiles. A program with no compiled object is staged as a placeholder: a two-line
BASIC stub that prints `<NAME> NOT BUILT -- PLACEHOLDER` and ends.

| Where | Shows |
|---|---|
| `MANIFEST.TXT` | `(placeholder)` as the source of a stub, and `DEV ONLY` on the dev files |
| `stage` output | a warning naming every placeholder |
| `zip` output | a warning naming every placeholder the zip ships |
