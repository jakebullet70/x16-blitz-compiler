# GPC Blitz-X16 — a BASIC compiler for the Commander X16

> Code name… Greased Piglet!

A Blitz-style compiler that turns tokenised Commander X16 BASIC into a **standalone
65C02 machine-code program**. There is no runtime interpreter in the output: a compiled
program is native code plus a small support library, and it runs with no BASIC in memory.

The compiler itself is a 6502 program — it runs **on the X16** (or an emulator), reads a
tokenised BASIC file, and writes a compiled `.PRG`.

Forked from Paul Robson's original: <https://github.com/paulscottrobson/blitz-compiler>

## Compiling a program

### Run `GPC.PRG`

`GPC.PRG` is the front end, and it is all you need. Put it on the drive beside the engine
`GPC.BLITZ.BIN`, load it, and answer four questions:

```text
LOAD "GPC.PRG",8 : RUN

GPC... A BLITZ INSPIRED X16 COMPILER
           V0.9 - SUMMER 2026

INPUT  FILE: DIR.PRG
OUTPUT FILE:
MAKE A DEBUG MAP? YES
SHARED RUNTIME? NO
```

| Prompt | A bare RETURN means |
| --- | --- |
| `INPUT  FILE:` | **quit** (`BYE, EXITING`) — the one prompt where RETURN backs out |
| `OUTPUT FILE:` | `C.` + the source name, so `DIR.PRG` → `C.DIR.PRG` |
| `MAKE A DEBUG MAP?` | no. `Y` names the map `M.` + source (`M.DIR.PRG`) — see [below](#the-debug-map-line-3) |
| `SHARED RUNTIME?` | no, the default self-contained build. `Y` selects the [shared runtime](#the-shared-runtime-line-4--shared) |

Both yes/no prompts take `Y` or `N` in either case. The source must already exist — a name that is
not on the drive stops with `INPUT FILE NOT FOUND` before anything is written or deleted.

It then scratches last time's object and map (CMDR-DOS will not overwrite a file, so a leftover
object would fail the save), writes your answers to `GPC.INPUT`, and chain-loads the engine, which
prints its own version and compiles.

On success `C.DIR.PRG` is a standalone program you can `LOAD"C.DIR.PRG"` / `RUN`. `LIST` it and it
identifies itself — the BASIC stub reads `SYS 2069 : REM GPC!`. On failure the compiler prints the
error and the offending line, e.g. `SYNTAX ERROR @ 610` or `NOT IMPLEMENTED @ 2400`.

### Scripted — write `GPC.INPUT` yourself

Writing that control file is the *only* thing `GPC.PRG` does. The engine **`GPC.BLITZ.BIN`** takes
its whole job from **`GPC.INPUT`** and asks nothing, so writing the file directly is what lets one
program drive another — it is how this repo's own test harness compiles. Up to four text lines:

| Line | Contents | |
| --- | --- | --- |
| 1 | the tokenised BASIC `.PRG` to compile | required |
| 2 | the compiled `.PRG` to write | required |
| 3 | a debug map to write (see below), or empty for none | optional |
| 4 | the compile **mode** — `shared` (first byte `S`) selects the shared runtime; empty/anything else = the default self-contained build | optional |

```text
DIR.PRG
C.DIR.PRG
M.DIR.PRG
shared
```

Then run the engine — it carries its own BASIC stub, so `LOAD"GPC.BLITZ.BIN",8 : RUN` is enough.

A line ends at a CR, an LF, or any control byte, and blank lines are skipped — so a `GPC.INPUT`
typed on a CRLF host drives the X16 compiler unchanged. An empty line 3 (no map) still holds its
slot, so line 4 is read as the mode either way. Names may be lowercase; the compiler folds
them to the uppercase PETSCII the KERNAL wants in a filename. With the source or object line missing
the compiler prints `NO GPC.INPUT FILE` and stops, rather than guess at what to build. Line 4 is
optional and is not checked — omit it for the default build.

**Delete a previous object and map yourself.** The engine opens the object with `,S,W` and no `@:`
overwrite prefix, and CMDR-DOS refuses to overwrite — so a leftover file from the last run fails the
save. `GPC.PRG` scratches them for you; driving the engine directly, you have to do it yourself —
`OPEN15,8,15,"S:C.DIR.PRG"` on the X16, or an ordinary file delete if you are scripting an emulator.

### The debug map (line 3)

Name a third file and the compiler writes a **line-number map** beside the object — one line per
source line, in code order: a 4-digit hex **p-code offset** and the decimal BASIC line that begins
there.

```text
0030 12
```

It exists for *runtime* errors, which report a p-code offset, not a line — `DIVIDE BY ZERO @ $0030`.
To place one, find the largest offset in the map that is `<=` the reported value: `$0030` is line 12.
(Two synthetic entries, lines 65024 and 65535, are the implicit-`DIM` prologue's own code, not yours.)

To get a tokenised `SOURCE.PRG` from a text listing without a running X16, use the host
tokeniser (`bin/tokenise.zip`, stdlib Python) — the test harness does exactly this.

### GPC.ERR — turning `@ $XXXX` back into a line number

Doing that lookup by hand gets old, so the release ships a helper that does it on the X16. Run it,
give it the map file, then paste the whole error line — it accepts `DIVIDE BY ZERO @ $0030`, or just
`$0030`, or `0030`:

```text
LOAD "GPC.ERR.PRG",8 : RUN
MAP FILE (E.G. M.MYPROG): M.SOURCE
ERROR ADDRESS: DIVIDE BY ZERO @ $0030
$0030 IS ON BASIC LINE 12
```

It distinguishes an exact hit (`IS ON BASIC LINE 12`, the address is a line's first byte) from a
landing inside a line (`IS ON/NEAR BASIC LINE 12`), and it recognises the two synthetic entries —
an address in the implicit-`DIM` prologue reports `IS IN COMPILER SETUP CODE, NOT A LINE` rather
than blaming the nearest real line, and an address below the first entry reports `IS BEFORE THE
FIRST MAPPED LINE`. A bare RETURN at either prompt quits.

The shipped `GPC.ERR.PRG` is **compiled**, in `shared` mode — so it needs `GPC.RT.<build>.BIN`
beside it or at the card root, which the release puts there anyway. In the source tree the same file
is called `C.GPC.ERR.PRG`, because the compiler's input there is the interpreted `GPC.ERR.PRG` and
the two need distinct names; the release drops the `C.` prefix so there is only one name to know.

If the runtime is missing or is a different ABI — which may be the very thing you are diagnosing —
rebuild the interpreted version instead: `BASLOAD "SRC/GPC.ERR.BASL"`. It is slower but needs no
runtime at all. Note that its `#SAVEAS` writes `GPC.ERR.PRG`, overwriting the compiled helper, so
re-extract from the zip when you want the fast one back.

**A runtime address is a p-code offset, not a line number, and the two look alike.** A compile-time
error already names its line in decimal (`SYNTAX ERROR @ 120` — that *is* line 120, and GPC.ERR is
the wrong tool for it). Only the `$` hex form needs decoding.

### How big a program can it compile?

**About 1,300 BASIC lines.** The limit is on the *p-code*, not the source, and it is a hard number:

| | max p-code |
| --- | --- |
| default (self-contained) | **18,432 bytes** |
| `shared` | **18,176 bytes** |

P-code runs about two thirds the size of the tokenised `.PRG` and averages ~14 bytes per BASIC
line, so a 27 KB tokenised source is roughly the ceiling. What binds is not the compiler's buffer
(19,456 bytes) but the *run* side: the object, a 4K FOR/GOSUB frame stack and a 4K minimum
workspace all have to fit below `$9F00`.

Go over and the compiler stops with **`PROGRAM TOO BIG`**, naming the line the budget ran out on.
It is worth saying plainly that this used to be silent: past 12,032 bytes the object code grew into
the compiler's own variable table and every variable reference after that point quietly became a
*new* variable, so the compile said `OK` and the tail of the program misbehaved. If you have a
large program that was built with an engine older than build 114, recompile it.

### The shared runtime (line 4 = `shared`)

By default every object is **self-contained**: the ~11 KB runtime is copied in ahead of the
program's own code (see [Runtime footprint](#runtime-footprint)). That is ideal for shipping one
program, but wasteful when several compiled programs load one after another — each carries its own
copy of the same runtime.

The **shared** mode factors that runtime out into a single resident copy. A program compiled with
line 4 = `shared` (first byte `S`) carries **no embedded runtime**: the compiler streams a 255-byte
bootstrap at `$0801` followed by the p-code, and the object is just that — bootstrap plus p-code.
The runtime lives once, on the drive, as a standalone binary **`GPC.RT.<build>.BIN`** that loads at
`RTBASE` (`$6800`) — `GPC.RT.152.BIN` for engine build 152, the number `GPC.BLITZ.BIN` prints at
startup. It is **not tracked in the repo**, precisely because the name changes on every engine
build; produce the one matching your checkout with `make -C source/runtime gpc-rt`. The
name carries the build, so a compiled program asks for the exact runtime it was built against *by
name*: one of a different vintage sitting on the card is simply not found, rather than loaded and
jumped into. **The build number bumps on every engine build, so shared programs must be recompiled
whenever the engine is** — the pairing is deliberately exact. A release ships exactly one runtime,
the one matching the `GPC.BLITZ.BIN` beside it.

On `RUN`, the bootstrap checks for the magic `GPC2` at `$7000`. That magic is the *ABI* ordinal
(`RT_ABI` in `common.inc`), not the build number: it answers only "is a runtime resident that I can
safely enter?", so a resident runtime from another build of the same ABI is reused. If none is
resident it `LOAD`s `GPC.RT.<build>.BIN` once (device 8, secondary 1, so the file's own load address
is honoured) — first from the current directory, then from the **root of the SD card**
(`/GPC.RT.<build>.BIN`) if it isn't alongside the program. It then enters the runtime and runs the
p-code. So the first shared program to run pays the load cost, and every shared program after it
starts instantly and shares the one resident runtime — the payoff for a suite of programs that hand
off to each other.

Requirements and limits:

- **`GPC.RT.<build>.BIN` must be on the drive** — either alongside the shared objects or in the card's
  root directory, so a card full of program folders needs only one ~11K copy. It is built by the
  runtime makefile (`make -C source/runtime gpc-rt`) and ships in `testing/`.
- Programs mixing shared and self-contained builds are fine; a shared object simply needs the
  resident runtime present when it runs.
- Shared mode's ceiling is slightly *lower* than the default build's — 18,176 bytes of p-code
  against 18,432 — because the p-code and its work area both have to fit below `RTBASE` at
  `$7000`. Either way the compiler stops with `PROGRAM TOO BIG` rather than overrunning; see
  [How big a program can it compile?](#how-big-a-program-can-it-compile).

The regression test lives in `source/unit-tests/shared-runtime/` — it compiles a program shared,
checks the object layout, and proves a cold start (fresh machine loads the runtime), the root
fallback (program run from a subdirectory with no local runtime reaches the one at the root), and a
warm start (runtime already resident, and provably reused rather than reloaded).

## Status

- Targets **ROM revision R49**.
- **63 of the X16's 81 extended keywords compile**; the remaining 18 are deliberate rejections
  (keywords that act on the BASIC *environment*, which a standalone binary doesn't have).
  `POINTER` and `STRPTR` are recognised but rejected with `NOT IMPLEMENTED`, because they expose
  the interpreter's internal variable layout, which the compiled runtime stores differently.
- See [`TODO.md`](TODO.md) for the full keyword-by-keyword status, decoded against the R49 ROM.

## Repository layout

| Path | What it is |
| --- | --- |
| `source/compiler` | the compiler front end (parsing, code generation) |
| `source/runtime` | the runtime support library linked into every compiled program |
| `source/ifloat32` | the 32-bit float / integer math library |
| `source/polynomials` | polynomial approximations (`SIN`, `COS`, `LOG`, …) |
| `source/common-source` / `common-scripts` | shared assembly + Python build tooling |
| `source/tools` | host-side helpers (tokeniser, detokeniser) |
| `source/unit-tests` | the randomised compiler-runtime regression suites |
| `source/application` | packages the release |
| `source/gpc` | the interactive front end `GPC.PRG`, tokenised from BASLOAD source `GPC.BASL` by `build_basl.py` (no Java/Prog8) |
| `bin/` | `x16emu/` (test emulator + ROM) and `box16/` (debugger) |
| `testing/` | the built compiler, the shared runtime `GPC.RT.<build>.BIN`, and sample programs, ready to run (also the scratch `prg-batch/`/`archive/` test inputs) |
| `documents/` | build include (`common.make`), notes, and reference PDFs |
| `docs/` | [`BUILDING.md`](docs/BUILDING.md), the build-and-test walkthrough |
| `samples/` | complete example programs with their sources and documentation |
| `x16emu.bat` / `box16.bat` | project-root launchers that boot the emulators with `testing/` as the drive |

## Runtime footprint

By default every compiled program carries the same support runtime — the P-code VM, all command handlers,
and the math libraries — copied in ahead of its own code. Measured at build 114 it is **11,775 bytes**
(`$0801`–`$3600`, then padded to the page boundary at `ObjectBase`):

| Component | Span | Bytes |
| --- | --- | ---: |
| `runtime` — the VM plus all the command handlers | `$082D`–`$25DA` | 7,597 |
| `common` — error vectors, the BASIC stub, shared tables | `$25FB`–`$279F` | 420 |
| `ifloat32` — 32-bit float and integer math | `$27AD`–`$31EB` | 2,622 |
| `polynomials` — `SIN`, `COS`, `LOG`, … | `$31F4`–`$3600` | 1,036 |

(A program can instead **share** one resident copy of this runtime — see
[the shared runtime](#the-shared-runtime-line-4--shared) — so its object is just a bootstrap plus p-code.)

Because that is a fixed cost, small programs are almost all runtime: the sample `DIR.PRG` compiles to
12,278 bytes of which only **245** are its own p-code.

For comparison, the vintage **C64 Blitz!** runtime (in `demo-c64/`) is roughly **half** ours — its compiled `DIR`
is 6.2 KB against our 12.0 KB build of the same program, an estimated ~5.8 KB of runtime. The difference
is two design choices, not overhead: (Note: Blitz for the Commodore 128 is about the same size as GPC)

- **Our own floating point.** We bundle a 32-bit float + transcendental library (`ifloat32` +
  `polynomials`, 3.6K) by design (a 32-bit format, not the ROM's 40-bit); C64 Blitz calls the C64 ROM's
40-bit BASIC floats instead.
- **X16 hardware.** ~2K of handlers for `SPRITE`, `MOVSPR`, VERA graphics, `TILE`, `MOUSE`, FM/PSG sound,
  `BLOAD`/`BSAVE` — none of which exist as C64 BASIC V2 keywords.

Those two (~5.6K) account for essentially the whole gap. [`TODO.md`](TODO.md#shrinking-the-runtime) covers
how a program that uses less could ship less.

## Building

Needs **GNU make**, **[64tass](https://sourceforge.net/projects/tass64/)**, and **Python 3**.
On Windows, build from **Git Bash** — every recipe in the tree is POSIX, and `common.make`
forces `SHELL := sh` accordingly. Per-machine tool paths go in an untracked
`documents/local.make`.

```sh
./release.sh     # full build, then package release/gpc-release-<n>.zip
```

That is the one to use. It runs the four steps in the order that keeps them consistent:

```sh
make libs                       # the bin/*.library files + the engine GPC.BLITZ.BIN
                                # (this also BUMPS source/application/buildnum.txt)
make release                    # stage the engine, GPC.INPUT and the samples into testing/
make -C source/runtime gpc-rt   # the shared runtime, testing/GPC.RT.<build>.BIN
make -C source/gpc release      # GPC.PRG, then GPC.ERR re-tokenised and compiled SHARED
                                # against the runtime just built
```

Order matters more than it looks: `GPC.ERR` is compiled in shared mode, so it names the runtime it
was built against *inside itself*. Rebuild the engine without rebuilding `GPC.ERR` and the shipped
helper goes looking for a `GPC.RT.<old>.BIN` that is no longer there.

`make latest` downloads and installs the matching x16emu + ROM into `bin/x16emu/`.

**[`docs/BUILDING.md`](docs/BUILDING.md) is the full walkthrough** — prerequisites and exact
Windows tool paths, what each target produces, how to read a test result (the suites do not print
`PASS`), the memory map, which emulator to use for what, and a troubleshooting table. Start there
if a build fails.

## Emulators

Two emulators live in `bin/`, each in its own directory because they need incompatible
`SDL2.dll` versions:

- **`bin/x16emu/`** — runs the automated test suites and is the correct emulator for anything
  that reads hardware (e.g. VERA sprite collision). Launch with **`x16emu.bat`** (project root).
- **`bin/box16/`** — the debugger. Launch with **`box16.bat`** (project root).

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

## License

MIT — see [`LICENSE`](LICENSE). © 2023 paulscottrobson and contributors.
