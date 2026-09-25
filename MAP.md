# Where things are

One line per top-level folder. The layout is being restructured in stages; this file is kept
current with every stage.

| Folder | Holds |
| --- | --- |
| `source/` | The compiler, runtime, math libraries, build scripts, `common.make` and the unit tests. |
| `source/gpc/` | The GPC front end and the build drivers: `samplesbuild.py`, `build_basl.py`, `compile_shared.py`. |
| `GPC-BASIC/` | The master copy of the GP.BASIC library and its manual `GP-BASIC.md`. |
| `BASLOAD-GPC/` | The BASLOAD tokeniser fork, with its vendored upstream. |
| `samples/` | Every program built with GPC: the apps (help, editor, GUI, error viewer, XBase) and the examples. Each builds in its own folder. |
| `testing/` | The emulator drive: the built compiler, runtimes and scratch test programs. |
| `USER-RUNS/` | The `.bat` launchers that run the emulator on a sample or the drive. |
| `bin/` | The emulators (`x16emu/`, `box16/`) and the built `*.library` files. |
| `bench/` | Speed benchmarks. |
| `fixes/` | Regression programs, one folder per fixed bug. |
| `docs/` | `BUILDING.md`, the plans in `blitz/`, X16 notes in `x16/`, reference PDFs in `reference/`, and the memory notes in `memory/`. |
| `release/` | The release drop folder. |
| `demo-c64/` | The original C64 Blitz disk images. |

Root files: `README.md` (overview), `TODO.md` (the running work list, large; grep it), `CLAUDE.md`,
`Makefile`, `build.sh`, `release.sh`.
