# GPC Blitz-X16 — a BASIC compiler for the Commander X16

> Code name… Greased Piglet!

GPC compiles tokenised Commander X16 BASIC to p-code, and GPC's runtime executes the p-code. A
compiled program either carries the runtime or loads it from a file. At run time there is no BASIC
program in memory and no BASIC interpreter.

GPC runs on the X16 or in an emulator. It reads a tokenised BASIC `.PRG` and writes a compiled
`.PRG`.

GP.BASIC adds `GP.*` keywords to the language, and `GPC-BASIC/` holds a library of modules built on
them. [GPC-BASIC/GP-BASIC.md](GPC-BASIC/GP-BASIC.md) is the manual.

Forked from Paul Robson's original: <https://github.com/paulscottrobson/blitz-compiler>

## What is in the zip

`128` is the runtime build number. Every file that carries it comes from the same build.

| | |
| --- | --- |
| `GPC.PRG` | the compiler front end, the program you run |
| `GPC.BIN` | the compiler engine, which `GPC.PRG` loads |
| `GPC.IMG.128.BIN` | the runtime a self-contained program carries |
| `GP1.IMG.128.BIN` | the bank 1 code a self-contained program carries |
| `GPB.RT.128.BIN` | the shared runtime with the GP handlers |
| `GPC.RT.128.BIN` | the shared runtime without the GP handlers |
| `GP1.RT.128.BIN` | the bank 1 code both shared runtimes load |
| `GPC.ERR.PRG` | turns a runtime error address into a source line |
| `GPC.ERR.OVL` | the banked code of `GPC.ERR.PRG` |
| `GPC.HELP.PRG` | the GPC reference, on the X16 |
| `GPC.HELP.OVL` | the banked code of `GPC.HELP.PRG` |
| `BASLOAD-GPC.PRG` | the streaming tokeniser, the program you run |
| `BASLOAD-GPC.BIN` | the streaming tokeniser's engine |
| `README.md` | this file |
| `LICENSE` | the MIT licence |
| `HELP-TXT/` | the index and topic files `GPC.HELP.PRG` reads |
| `GPC-BASIC/` | the GP.BASIC library: the modules, `GP-BASIC.md` (the manual), `GP-BASIC.GLOBALS.md` (every name each module owns), `GP-BASIC.FILES.md` (what each file is for) and `README.md` |
| `SRC/` | the source of `GPC.PRG`, GPC.ERR, GPC.HELP and BASLOAD-GPC, in `GPC/`, `GPC-ERROR/`, `GPC-HELP/` and `GPC-BASLOAD/`. `SRC/README.TXT` says how to rebuild them. Nothing in it is needed to run GPC |
| `SAMPLES/` | `GPBMODS/`, `EDITOR/`, `BMXVIEW/`, `COLORTST/` and `GUI-LITE/`: compiled programs with their source |

The samples are there to be read and run. They cannot be rebuilt where they sit: their `#INCLUDE`
lines need a `GPC-BASIC/` folder beside the source, and a sample folder has none.

`GPBMODS` and `BMXVIEW` are shared programs. Run from their own folder, they find the runtime files
only in `/GPC/` or at the root of the drive (see
[where the runtime files go](#where-the-runtime-files-go)). `EDITOR`, `COLORTST` and `GUI-LITE` carry
their own runtime. `GPBMODS.PRG` reads `GPBMODS.OVL` from beside it, and `EDIT.PRG` reads `EDIT.OVL`.

## Compiling a program

### Tokenise the source

GPC compiles a tokenised BASIC `.PRG`, not `.BASL` text. Tokenise the source with BASLOAD, which is
in the R49 ROM, or with [BASLOAD-GPC](#basload-gpc-the-streaming-tokeniser).

A source that uses a `GP.` keyword tokenises to a `.PRG` the ROM can neither `LIST` nor `RUN`. It is
input for GPC.

### Run `GPC.PRG`

Run it from the folder the zip unpacked to. Every file it needs is there.

```text
LOAD "GPC.PRG",8
RUN

GPC... A BLITZ INSPIRED X16 COMPILER
           V1.1 - SUMMER 2026

INPUT  FILE: DIR.PRG
OUTPUT FILE:
MAKE A DEBUG MAP? YES
SHARED RUNTIME? NO
REMOVE DEAD CODE? NO
```

| Prompt | A bare RETURN means |
| --- | --- |
| `INPUT  FILE:` | quit, with `BYE, EXITING` |
| `OUTPUT FILE:` | `C.` and the source name: `DIR.PRG` gives `C.DIR.PRG` |
| `MAKE A DEBUG MAP?` | no. `Y` writes a [debug map](#the-debug-map) named after the source, with `.PRG` and then `.SRC` taken off the end and `.MAP` added: `DIR.PRG` gives `DIR.MAP` |
| `SHARED RUNTIME?` | no: the program carries its own runtime. `Y` compiles it [shared](#shared) |
| `REMOVE DEAD CODE?` | no. `Y` leaves out every line nothing reaches, and writes their numbers to `D.` and the source name. `GPC-BASIC/GP-BASIC.md` §7 has the rules |

The yes/no prompts take `Y` or `N` in either case. A file name holds up to 39 characters.

`GPC.PRG` checks the input file before it asks for the output name. A name not on the drive stops
with `INPUT FILE NOT FOUND`. A file that does not load at `$0801` stops with `NOT A BASIC PRG FILE`
and `COMPILE THE .PRG, NOT THE .BASL SOURCE.`

It then scratches the object, map and dead-code list from the last run, writes the answers to
`GPC.INPUT`, and loads the engine: `GPC.BIN` from the current folder, or `/GPC/GPC.BIN` when the
current folder has none. A shared compile first prints
`** SHARED RUNTIME SELECTED, REMEMBER TO INCLUDE IT **`.

`GPC.PRG` is itself a shared program that uses the GP handlers. It needs `GPB.RT.128.BIN` and
`GP1.RT.128.BIN` (see [where the runtime files go](#where-the-runtime-files-go)).

### What the compiler prints

The engine prints its name and version, then the two file names:

```text
GPC SQUEALING... V1.1.0
IN:  DIR.PRG
OUT: C.DIR.PRG
```

Each pass prints `PASS 1` or `PASS 2`, and a dot for every 64 source lines. With dead-code removal
on, `PASS 0` comes first.

A compile that succeeds prints `OK` and a report of what the program costs.
`GPC-BASIC/GP-BASIC.md` §7 explains each item. The report says `GPBASIC` when the program uses the
GP handlers and `CORE` when it does not. Some GP keywords compile to core p-code and need no handler.
`LOW FREE` is the workspace left for variables, strings and arrays.

The object runs as it is: `LOAD "C.DIR.PRG"` and `RUN`. `LIST` shows `10 SYS 2069:REM GPC!`.

A statement that fails with `SYNTAX ERROR` does not stop the compile. The compiler puts a stub in
place of the statement and the rest of its line, and the stub raises `SYNTAX ERROR` if the program
reaches it. The line numbers are listed above the `OK`:

```text
2 STATEMENTS NOT COMPILED: 1669 1702
```

Any other error stops the compile. The compiler prints the message and the BASIC line, as in
`NOT IMPLEMENTED @ 2400`, and leaves no output files.

### The debug map

The map is a text file with one line per compiled BASIC line: an address, a space, and the decimal
line number that starts there. The address has one of two forms.

- A line in low memory has the four-digit hex p-code offset.
- A line in a `GP.BANKED` region has the region's bank in hex, a colon, and the four-digit hex
  address it runs at. Every region runs from `$A000` in its own bank.

```text
0030 12
14:A043 57
```

A runtime error prints the address, not the line: `DIVIDE BY ZERO @ $0030`, or
`DIVIDE BY ZERO @ $14:A048` for an error in the region in bank `$14`. The line is the one with the
largest address not above the reported value, among the lines in the same bank. So `$0030` is line
12 and `$14:A048` is line 57. `GPC.ERR.PRG` does the lookup (see
[GPC.ERR](#gpcerr-a-runtime-address-back-to-a-source-line)).

- The map is in source order, not address order, so check every line.
- Lines 65024 and 65535 are the compiler's setup code, not source lines.
- A compile error prints its line in decimal. Only the `$` form needs the map.

### Driving `GPC.BIN` directly

`GPC.BIN` asks nothing. It takes its job from `GPC.INPUT` in the current folder, and writing that
file is all `GPC.PRG` does. Write the file yourself to compile from another program or a script.

| Line | Contents |
| --- | --- |
| 1 | the tokenised `.PRG` to compile. Required |
| 2 | the object to write. Required |
| 3 | the debug map to write, or empty for none |
| 4 | `SHARED` for a shared program. Empty, or anything not starting with `S`, for a self-contained one |
| 5 | the dead-code list to write, or empty. A name turns dead-code removal on |

```text
DIR.PRG
C.DIR.PRG
DIR.MAP
SHARED
D.DIR.PRG
```

Then `LOAD "GPC.BIN",8` and `RUN`.

- A line ends at CR, at LF, or at any other byte below a space. CR followed by LF ends one line, so a
  file written on a PC works.
- An empty line keeps its place. An empty line 3 leaves line 4 as the mode.
- Lines missing from the end read as empty.
- Lower case is folded to upper case.
- A line holds 63 characters. The rest is dropped.
- With no readable `GPC.INPUT`, or with line 1 or line 2 empty, the engine prints
  `NO GPC.INPUT FILE` and stops.
- Before it compiles, the engine scratches the files lines 2, 3 and 5 name, and the object's `.OVL`.
- A source it cannot read stops with `SOURCE NOT FOUND OR EMPTY`. One that does not load at `$0801`
  stops with `NOT A BASIC PRG FILE`.
- A self-contained compile reads `GPC.IMG.128.BIN` and `GP1.IMG.128.BIN` from the current folder, or
  from `/GPC/`. Without them it prints `NO RUNTIME IMAGE` and writes nothing. A shared compile does
  not read them.

## Self-contained and shared programs

### Self-contained

This is the default. The object carries the runtime ahead of its p-code: 10,239 bytes when the
report says `CORE`, 11,775 bytes when it says `GPBASIC`. The report prints this figure as `RUNTIME`.
After the p-code, from the next page boundary, come 2,432 bytes of bank code, which the program
copies to RAM bank 1 as it starts.

A self-contained program needs no other file, except its `.OVL` when it has a `GP.BANKED` region.

### Shared

A shared object carries no runtime. It is a 255-byte bootstrap at `$0801`, then the p-code from
`$0900`. A program with a `GP.BANKED` region carries one more page, and its p-code starts at `$0A00`.

When the program runs, the bootstrap uses a runtime already in memory if it is from a compatible
build. Otherwise it loads one:

| File | Loads at | Loaded for |
| --- | --- | --- |
| `GPB.RT.128.BIN` | `$6F00` | a `GPBASIC` program: the GP handlers and the core |
| `GPC.RT.128.BIN` | `$7700` (`RTBASE`) | a `CORE` program: the core only |
| `GP1.RT.128.BIN` | `$A000` in RAM bank 1 | every shared program: the bank 1 code |

The compiler chooses between the first two at compile time, and an edit to the program can change
the choice. Keep all three files available.

A shared program's workspace ends where the runtime starts: `$6F00` for `GPBASIC`, `$7700` for
`CORE`. A `CORE` program uses the memory the GP handlers occupied, so the next `GPBASIC` program
loads `GPB.RT.128.BIN` again.

#### Where the runtime files go

The bootstrap looks in three places, in order: the current folder, `/GPC/`, then the root of the
drive. It loads `GP1.RT.128.BIN` from the place the runtime came from.

A file that is not found prints `?RT`, the third letter of its name and the build number, then
returns to BASIC: `?RTB128` for `GPB.RT.128.BIN`, `?RTC128` for `GPC.RT.128.BIN`, `?RT1128` for
`GP1.RT.128.BIN`.

A shared object carries the file name of the runtime it was compiled against, so a runtime from
another build is not found. Recompile every shared program for a new runtime build.

## How big a program can be

The limit is on the p-code that stays in low memory, which the report prints as `LOW CODE`. The
compiler rounds it up to whole pages. Above it there must be room for the 2,048-byte frame stack and
at least 4,096 bytes of workspace, below `$9F00` for a self-contained program and below the runtime
for a shared one.

| Build | Largest `LOW CODE` |
| --- | --- |
| self-contained, `CORE` | 22,272 bytes |
| self-contained, `GPBASIC` | 20,736 bytes |
| shared, `CORE` | 22,016 bytes |
| shared, `GPBASIC` | 19,968 bytes |

A shared program with a `GP.BANKED` region has 256 bytes less. A self-contained program with one is
always `GPBASIC`.

A program over the limit stops with `PROGRAM TOO BIG` and no line number, and no object is written.
`LOW FREE` minus 4,096 is how much more p-code fits, in whole pages.

### Code in RAM banks

`GP.BANKED` puts code in a RAM bank, where it does not count against `LOW CODE`. The compiler writes
every region to one file beside the object, named after it with `.OVL` in place of its extension:
`C.DIR.PRG` has `C.DIR.OVL`. The program reads it as it starts. `GPC-BASIC/GP-BASIC.md` §3.12
covers regions.

- Keep the `.OVL` beside its program, under the name the compiler gave it. The program reads it by
  that name.
- A missing or short `.OVL` prints `?OVL` and the program stops. A region in a bank the machine does
  not have prints `?RAM`.
- A region holds at most 32 pages, 8K. A larger one stops the compile with
  `GP.BANKED REGION OVER 8K`.
- Regions go in banks 2 to 255. `GP.BANKED 1` stops the compile with `BANK 1 IS RESERVED`.
- A program holds at most 127 regions. More stops the compile with `TOO MANY GP.BANKED REGIONS`.

### Other limits

- 4,096 BASIC lines. `PROGRAM TOO BIG @` and a line number means a compiler table filled at that
  line.
- 4,096 bytes of scalar variables: 6 bytes for each numeric variable without a suffix, 2 for each
  `%` or `$` variable. More stops the compile with `TOO MANY VARIABLES`.

## GPC.ERR: a runtime address back to a source line

`GPC.ERR.PRG` takes a debug map and an address from a runtime error. It answers with the BASIC line,
the source file the line came from, and the nearest label above it.

It is a shared program that uses the GP handlers, so it needs `GPB.RT.128.BIN` and `GP1.RT.128.BIN`.
It needs `GPC.ERR.OVL` beside it. It runs on an 80x30 screen.

| Menu | Items |
| --- | --- |
| `FILE` | `LOAD MAP`, `BROWSE MAP`, `QUIT` |
| `SEARCH` | `BY ADDRESS`, `BY LINE` |
| `HELP` | `HOW TO`, `ABOUT` |

ESC opens the menu bar. ALT and an item's marked letter opens that item's dropdown. LEFT and RIGHT
move from one dropdown to the next, and ESC closes an open one.

- `LOAD MAP` asks for the map's name, and fills it in when the drive holds exactly one `.MAP`.
  `BROWSE MAP` opens a file picker on the same list.
- `BY ADDRESS` takes the address a runtime error prints, `$027E` or `$0C:AAF4`, or the whole error
  line.
- `BY LINE` takes a BASIC line number, such as one from `STATEMENTS NOT COMPILED`.
- Both searches need a map loaded first.

It reads three files, found from the map's name:

| | |
| --- | --- |
| the map | `NAME.MAP` or `M.NAME` |
| the symbol file | `NAME.SRC.SYM`, or `NAME.SYM` when that is not there |
| the tokenised source | `NAME.SRC.PRG`, or `NAME.PRG` when that is not there |

Without the symbol file it shows no file name, label or names. Without the tokenised source it shows
no source lines.

The answer says where the address landed: on a line's first byte, a number of bytes into a line,
before the first mapped line, or past the last one. A line number at or above 65,024 is reported as
compiler setup code. Below that it shows:

- `BASIC LINE`, `FILE` and `NEAR`, the label at or above the line.
- `SOURCE`: up to seven lines of the tokenised source, with the line looked up marked `>`.
- `NAMES`: up to six of the crunched names in those lines, turned back into the names in the source.

## GPC.HELP: the reference on the X16

`GPC.HELP.PRG` shows the GP.BASIC manual, the name register, the file list and a page for each
library module, on an 80x30 screen.

It reads `GPC.HELP.IDX` and the topic files from `HELP-TXT/` beside it, or from `/GPC/HELP-TXT/` when
there is none beside it. The folder name `HELP-TXT` is fixed. When the index does not load it prints
`GPC.HELP: HELP-TXT/GPC.HELP.IDX WOULD NOT LOAD.` and ends.

It is a shared program that uses the GP handlers, so it needs `GPB.RT.128.BIN` and `GP1.RT.128.BIN`.
It needs `GPC.HELP.OVL` beside it.

On the index:

| Key | Does |
| --- | --- |
| UP, DOWN, PgUp, PgDn, HOME, END | move the highlight |
| RETURN | open the highlighted topic |
| `/` or `F` | find |
| `N` | find the next match |
| `T` | the next colour theme |
| `?` or `H` | the about box |
| ESC | asks whether to quit |

In a topic:

| Key | Does |
| --- | --- |
| UP, DOWN, PgUp, PgDn, SPACE, HOME, END | scroll |
| `L` | list the topic's cross references, and open the one chosen |
| `X` | write the topic's code out as a `.BL` file, when it has code |
| `T` | the next colour theme |
| ESC | back one step |

## BASLOAD-GPC: the streaming tokeniser

`BASLOAD-GPC.PRG` tokenises a `.BASL` source as the ROM's BASLOAD does, and writes each line to the
output file as it finishes it. BASIC RAM does not bound the source. The ROM's BASLOAD builds the
program in BASIC RAM and stops at 38,655 bytes.

`BASLOAD-GPC.PRG` is the front end and `BASLOAD-GPC.BIN` the engine. The front end loads the engine
from the current folder, or from `/GPC/`. It is plain X16 BASIC and needs no runtime.

```text
LOAD "BASLOAD-GPC.PRG",8
RUN

BASLOAD --> BASIC SOURCE TO TOKENISED PRG (GPC VERSION)
BASLOAD-GPC.BIN WAS BUILT FROM GIT SOURCE, SEPT 2026
BASLOAD IS (C)2021-2023, STEFAN JAKOBSSON

SOURCE FILE: HELLO.BASL

TOKENISING HELLO.BASL ...
```

- An empty answer ends without tokenising.
- The output name is the source's `#SAVEAS`. Prefix it `@:` to overwrite an existing file. Without
  `#SAVEAS` the run fails with `FILENAME NOT SPECIFIED`.
- The device is 8.
- A run that fails deletes the output file it created.
- After a clean run, when `.BASLOAD.NEXT` is on the source's drive, the engine prints
  `RUNNING .BASLOAD.NEXT`, then loads and runs it. The file is not deleted, so it runs after every
  clean tokenise in that folder.

`SRC/GPC-BASLOAD/` holds its documents and its source.

## Status

- Targets X16 ROM R49.
- 63 of the 81 extended keywords compile. The other 18 act on the BASIC environment, which a compiled
  program does not have, and are rejected.
- `POINTER` and `STRPTR` stop the compile with `NOT IMPLEMENTED`. GPC lays variables out differently
  from the interpreter. `GP.STRPTR` returns the address of a GPC string block
  (`GPC-BASIC/GP-BASIC.md` §3.4).

## License

MIT. See [`LICENSE`](LICENSE). © 2023 paulscottrobson and contributors.

<!-- release: the rest is for the source tree -->

## Repository layout

[`MAP.md`](MAP.md) is the one-page guide to where things are. [`TODO.md`](TODO.md) holds the
keyword-by-keyword status against the R49 ROM and the open work, including
[shrinking the runtime](TODO.md#shrinking-the-runtime).

| Path | What it is |
| --- | --- |
| `source/compiler` | the compiler library: parsing and code generation |
| `source/runtime` | the runtime support library linked into every compiled program |
| `source/ifloat32` | the 32-bit float / integer math library |
| `source/polynomials` | polynomial approximations (`SIN`, `COS`, `LOG`, …) |
| `source/common-source` / `common-scripts` | shared assembly + Python build tooling |
| `source/tools` | host-side helpers (tokeniser, detokeniser) |
| `source/unit-tests` | the randomised compiler-runtime regression suites |
| `source/application` | the engine `GPC.BIN`: file I/O, the object writer and the bootstraps; and the runtime images `GPC.IMG.<n>.BIN` and `GP1.IMG.<n>.BIN` |
| `source/gpc` | the front end `GPC.PRG`: BASLOAD source `GPC.BASL`, written in GP.BASIC, tokenised by `build_basl.py` and compiled by `compile_shared.py`. `samplesbuild.py` builds the sample programs |
| `bin/` | the built `*.library` files, `tokenise.zip` (the host tokeniser, stdlib Python), `x16emu/` (test emulator + ROM) and `box16/` (debugger) |
| `source/drive/` | the built compiler, the runtime images, the shared runtimes `GPB/GPC/GP1.RT.<n>.BIN`, and sample programs, ready to run |
| `BASLOAD-GPC/` | the streaming tokeniser: its source, build script and tests |
| `GPC-BASIC/` | the GP.BASIC library master and its manuals |
| `docs/` | [`BUILDING.md`](docs/BUILDING.md), the build-and-test walkthrough |
| `GPC-BASIC-TOOLS-SRC/` | complete example programs with their sources and documentation |
| `USER-RUNS/` | Windows launchers: `x16emu.bat` and `box16.bat` boot the emulators with `source/drive/` as the drive, `release.bat` runs `release.sh`, and a `*-demo.bat` runs each sample |
| `release/` | where `release.sh` stages the release (`release/TMP`) and writes the zip |

## Building

Needs **GNU make**, **[64tass](https://sourceforge.net/projects/tass64/)**, and **Python 3**.
On Windows, build from **Git Bash** — every recipe in the tree is POSIX, and `common.make`
forces `SHELL := sh` accordingly. Per-machine tool paths go in an untracked
`source/local.make`.

```sh
./release.sh          # full build, then package release/gpc-release-<version>.zip
./release.sh stage    # stage release/TMP from the current build: no rebuild, no zip
./release.sh zip      # zip release/TMP as it stands
```

That is the one to use. It runs the five steps in the order that keeps them consistent:

```sh
make libs                          # the bin/*.library files + the engine GPC.BIN
make release                       # stage the engine, GPC.INPUT and the samples into source/drive/
make -C source/runtime gpc-rt      # the shared runtimes, source/drive/GPB/GPC/GP1.RT.<n>.BIN
make -C source/gpc release         # GPC.PRG and GPC.ERR: both tokenised, then compiled SHARED
                                   # (this target builds gpc-rt itself, so the line above it is
                                   #  only needed if you want the runtime on its own)
python source/gpc/samplesbuild.py  # the sample programs, each tokenised then compiled
```

The zip's `README.md` is this file, cut at the release marker above Repository layout.

`<version>` is `source/application/buildnum.txt`, which `GPC.BIN` prints and which is edited by
hand. The runtime build number, the `<n>` in every `.RT.` and `.IMG.` file name, is
`source/application/rtbuild.txt`. Nothing bumps either. A shared object carries its runtime's file
name, so after a change to `rtbuild.txt` every shared program must be recompiled.

`make latest` downloads and installs the matching x16emu + ROM into `bin/x16emu/`.

**[`docs/BUILDING.md`](docs/BUILDING.md) is the full walkthrough** — prerequisites and exact
Windows tool paths, what each target produces, how to read a test result (the suites do not print
`PASS`), the memory map, which emulator to use for what, and a troubleshooting table. Start there
if a build fails.

## Emulators

Two emulators live in `bin/`, each in its own directory because they need incompatible
`SDL2.dll` versions:

- **`bin/x16emu/`** — runs the automated test suites and is the correct emulator for anything
  that reads hardware (e.g. VERA sprite collision). Launch with **`USER-RUNS/x16emu.bat`**.
- **`bin/box16/`** — the debugger. Launch with **`USER-RUNS/box16.bat`**.

The launch conventions differ (`-fsroot` vs `-hypercall_path`, `-run` vs an issued `RUN`), so
prefer the `.bat` wrappers, which get this right. Box16 does **not** emulate sprite collision —
playtest `$9F27`-reading programs under x16emu.

## Testing

```sh
export SDL_VIDEODRIVER=dummy                             # headless; otherwise it steals focus

make -C source/ifloat32 run                              # 32-bit float library
make -C source/polynomials run                           # log/exp/trig
make -C source/unit-tests/compiler-runtime all           # six randomised compile-and-run suites
python source/unit-tests/shared-runtime/shared_test.py   # shared mode, cold + root + warm
```

A suite **passes when the emulator exits** (the compiled test reaches a `jmp $FFFF`, and the
emulator says so on stdout) and **fails by looping forever**, so always run under a timeout — and
give the `variables` and `arrays` suites several minutes each before concluding anything, because
the replay step is not warped. Details in [`docs/BUILDING.md`](docs/BUILDING.md#3-test-it).

### Checking the name register

The name tables in [`GPC-BASIC/GP-BASIC.GLOBALS.md`](GPC-BASIC/GP-BASIC.GLOBALS.md) are extracted
from the sources rather than remembered. To check them after a change:

```bash
python - <<'PY'
import re, os, glob
for f in sorted(glob.glob("GPC-BASIC/*.INC.BL")):
    s = open(f, encoding="utf-8").read()
    body = "\n".join(l for l in s.split("\n") if not l.strip().startswith("##"))
    body = re.sub(r'"[^"]*"', ' ', body)          # literals are not identifiers
    defines = set(re.findall(r"^#DEFINE\s+([A-Z0-9.$]+)", body, re.M))
    labels  = set(re.findall(r"^([A-Z][A-Z0-9.]*):", body, re.M))
    pref    = os.path.basename(f).split(".")[0]
    idents  = {i for i in re.findall(r"\b([A-Z][A-Z0-9.]*\$?)", body)
               if i.startswith(pref) or i.startswith(pref[:3] + "K")}
    print(os.path.basename(f))
    print("  const :", " ".join(sorted(defines)))
    print("  labels:", " ".join(sorted(labels)))
    print("  vars  :", " ".join(sorted(idents - defines - labels)))
PY
```

It cannot tell **in** from **out** from **internal** — that is a judgement call and lives in each
module's header comment. What it will catch is a variable that has appeared and is not written down
here.
