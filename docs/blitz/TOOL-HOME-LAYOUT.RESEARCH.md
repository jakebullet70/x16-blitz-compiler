# Tool home and project folders

Research, 2026-09-27. Deferred to the next version. The rule today is: copy the
compiler and everything it needs into the folder you are working in. The sample
folders under `GPC-BASIC-TOOLS-SRC/` each carry their own copy.

## Target layout

One drive, one root. The tools live in `/GPC/`, every program in its own folder
under `/BASIC-SRC/`, and a build runs from the program's folder as cwd.

    /GPC/                      BASLOAD-GPC.PRG BASLOAD-GPC.BIN GPC.PRG GPC.BIN
                               GPB.RT.nnn.BIN GPC.RT.nnn.BIN GP1.RT.nnn.BIN
                               GPC.IMG.nnn.BIN GP1.IMG.nnn.BIN
                               GPC-BASIC/   HELP-TXT/
    /BASIC-SRC/MYPROG/         MYPROG.BASL, its .PDEF, everything it writes

    DOS"CD:/BASIC-SRC/MYPROG"
    LOAD"/GPC/BASLOAD-GPC.PRG",8 : RUN      MYPROG.BASL -> MYPROG.SRC.PRG in cwd
    LOAD"/GPC/GPC.PRG",8 : RUN              MYPROG.SRC.PRG -> C.MYPROG.PRG, .OVL, .MAP in cwd
    LOAD"C.MYPROG.PRG",8 : RUN

In the repo the root is `GPC-BASIC-TOOLS-SRC/` and the samples sit directly under
it, the same shape with one level fewer. `make install` fills `GPC-BASIC-TOOLS-SRC/GPC/`
and takes `GPCHOME=` for any other root.

## What already works from a project folder

Build 127 gave every file open a second try at `/GPC/` after cwd:

| open | where | fallback |
|---|---|---|
| engine, BASLOAD-GPC.PRG | `BASLOAD-GPC/frontend/BASLOAD-GPC.BASL` FIND | DOS error channel, then `/GPC/` |
| engine, GPC.PRG | `source/gpc/GPC.BASL` FIND.ENGINE | same |
| `#INCLUDE` | `BASLOAD-GPC/src/option.inc` include: | cwd, then `/GPC/`+name |
| runtime image | `source/application/source/file-io/read.asm` IOOpenImage | cwd, then `/GPC/` |
| GPB/GPC/GP1.RT at run time | `source/application/source/compiler/bootstrap.asm` | cwd, `/GPC/`, `/` |

Everything written lands in cwd: `GPC.INPUT`, the object, the `.OVL`, the map, and
BASLOAD's output, because every `#SAVEAS` is `@:NAME`. The `.OVL` is opened from cwd
only, which is right: it belongs to the program, not the tools.

`/GPC/NAME` opens from any folder on hostfs. No CMD syntax is needed.

## The gaps

1. **`#INCLUDE "GPB.INC.BL"` misses the library.** The fallback tries `/GPC/GPB.INC.BL`;
   `make install` puts the library at `/GPC/GPC-BASIC/GPB.INC.BL`. Seven sources use
   the bare form, five use `GPC-BASIC/GPB.INC.BL`. No `.INC.BL` module includes another,
   so this is one line per program. Fix: a third try, `/GPC/GPC-BASIC/`+name, next to
   `gpc_include_path` in option.inc. About a dozen lines of asm, one more prefix buffer.
   Both spellings then work and a project needs no `GPC-BASIC/` copy of its own.
   The alternative, flattening the library into `/GPC/` at install, breaks the
   prefixed form instead.
2. **Two front ends have no engine fallback.** `GPC.GUI.BASL:993` and `CRUNCH.BASL:114`
   load `GPC.BIN` bare.
3. **Host scripts know only "sample" and "not sample".** `build_basl.py` and
   `compile_shared.py` mount `GPC-BASIC-TOOLS-SRC` as fsroot and CD into the sample; any
   other drive is mounted at itself. They need `--root` and `--project`, with the sample
   detection as the default.
4. **USER-RUNS demos mount the sample as the drive**, which hides `/GPC/`. They move to
   fsroot at the root plus a CD-and-RUN driver, the shape `tmp-emu.bat` already uses.
5. **release.sh ships the tools at the drive root**, not in `GPC/`. A release drive
   should have the repo drive's shape.
6. **Map name.** GPC.PRG writes `NAME.MAP`; the `.PDEF` spec in `GPC.GUI.BASL:14-27`
   says `M.`+SRC. Pick one.

## Decisions taken

- **`/GPC/` stays fixed.** Three asm routines and two front ends read it, all before
  anything else is open, and bootstrap.asm is size-critical. A root file naming the
  tool home would have to be found and parsed by the code that does not yet know
  where anything is.
- **A root KEY=VALUE file is for preferences**, not for locating tools: last project,
  default MODE and MAP answers, editor and help colours. Plain text at `/GPC.CFG`,
  read with LINPUT#, because BASLOAD-GPC.PRG is plain BASIC and cannot use the
  KV.INC.BL bank image. Write it when the second consumer appears.
- **Several programs in one folder** (OASIS is the case) is the per-program `.PDEF`
  model GPC.GUI already defined: a folder holds any number of `.PDEF` files and a
  `.MAKE` listing them. GPC.PRG grows one first prompt, `PROJECT FILE (.PDEF, BLANK =
  ASK)`. A name reads the KEY=VALUE lines and skips the five prompts; blank keeps
  today's prompts. Building a whole `.MAKE` is the sixth GPC.INPUT line already agreed.

## Order when it is picked up

1. option.inc third include try. Asm, so agree it first. Rebuild BASLOAD-GPC, `make install`.
2. `--root`/`--project` in the host scripts, USER-RUNS bats onto root plus CD, release.sh
   layout. Then the per-sample tool copies can go again.
3. GPC.PRG reads a `.PDEF`; map name unified; GPC.GUI and CRUNCH get the engine fallback.
4. `/GPC.CFG` when something needs it.
