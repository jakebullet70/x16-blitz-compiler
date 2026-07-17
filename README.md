# GPC Blitz-X16 — a BASIC compiler for the Commander X16

> Code name… Greased Piglet!

A Blitz-style compiler that turns tokenised Commander X16 BASIC into a **standalone
65C02 machine-code program**. There is no runtime interpreter in the output: a compiled
program is native code plus a small support library, and it runs with no BASIC in memory.

The compiler itself is a 6502 program — it runs **on the X16** (or an emulator), reads a
tokenised BASIC file, and writes a compiled `.PRG`.

Forked from Paul Robson's original: <https://github.com/paulscottrobson/blitz-compiler>

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
| `bin/` | `x16emu/` (test emulator + ROM) and `box16/` (debugger) |
| `testing/` | the built compiler, the shared runtime `GPC.RT.BIN`, and sample programs, ready to run (also the scratch `prg-batch/`/`archive/` test inputs) |
| `documents/` | build include (`common.make`), notes, and reference PDFs |
| `x16emu.bat` / `box16.bat` | project-root launchers that boot the emulators with `testing/` as the drive |

## Runtime footprint

By default every compiled program carries the same support runtime — the P-code VM, all command handlers,
and the math libraries — copied in ahead of its own code. It measures **~11 KB** (10,956 bytes): `runtime.library`
7.3K (the VM plus all 158 handlers), `ifloat32` 2.3K, `polynomials` 0.9K, then the error vectors and the
BASIC stub. (A program can instead **share** one resident copy of this runtime — see
[the shared runtime](#the-shared-runtime-line-4--shared) — so its object is just a bootstrap plus p-code.)

For comparison, the vintage **C64 Blitz!** runtime (in `demo-c64/`) is roughly **half** ours — its compiled `DIR`
is 6.2 KB against our 11 KB build of the same program, an estimated ~5.8 KB of runtime. The difference
is two design choices, not overhead: (Note: Blitz for the Commodore 128 is about the same size as GPC)

- **Our own floating point.** We bundle a 32-bit float + transcendental library (`ifloat32` +
  `polynomials`, ~3.2K) by design (a 32-bit format, not the ROM's 40-bit); C64 Blitz calls the C64 ROM's
40-bit BASIC floats instead.
- **X16 hardware.** ~2K of handlers for `SPRITE`, `MOVSPR`, VERA graphics, `TILE`, `MOUSE`, FM/PSG sound,
  `BLOAD`/`BSAVE` — none of which exist as C64 BASIC V2 keywords.

Those two (~5.2K) account for essentially the whole gap. [`TODO.md`](TODO.md#shrinking-the-runtime) covers
how a program that uses less could ship less.

## Building

Needs **GNU make**, **[64tass](https://sourceforge.net/projects/tass64/)**, and **Python 3**.
On Windows, build from **Git Bash** — every recipe in the tree is POSIX, and `common.make`
forces `SHELL := sh` accordingly. Per-machine tool paths go in an untracked
`documents/local.make`.

```sh
make libs        # build the five bin/*.library files and the compiler
make release     # package testing/ (the compiler + samples)
make latest      # download & install the matching x16emu + ROM into bin/x16emu/
```

## Compiling a program

The compiler engine is **`GPC.BLITZ.BIN`**. It reads its job from a control file, **`GPC.INPUT`**,
of up to four text lines:

| Line | Contents | |
| --- | --- | --- |
| 1 | the tokenised BASIC `.PRG` to compile | required |
| 2 | the compiled `.PRG` to write | required |
| 3 | a debug map to write (see below), or empty for none | optional |
| 4 | the compile **mode** — `shared` (first byte `S`) selects the shared runtime; empty/anything else = the default self-contained build | optional |

A line ends at a CR, an LF, or any control byte, and blank lines are skipped — so a `GPC.INPUT`
typed on a CRLF host drives the X16 compiler unchanged. An empty line 3 (no map) still holds its
slot, so line 4 is read as the mode either way. Names may be lowercase; the compiler folds
them to the uppercase PETSCII the KERNAL wants in a filename. With the source or object line missing
the compiler prints `NO GPC.INPUT FILE` and stops, rather than guess at what to build. Line 4 is
optional and is not checked — omit it for the default build.

### Driving it — two ways

**Interactively, with `GPC.PRG`.** The front end asks the questions — input file, output file, map,
and **shared runtime?** — writes `GPC.INPUT`, and chain-loads the engine. A bare RETURN at the output
prompt names the object `C.` + source (`DIR.PRG` → `C.DIR.PRG`); answer the map question and the map
is named `M.` + source. Answer *yes* to "shared runtime?" and it writes `shared` as line 4:

```sh
cd release
../bin/x16emu/x16emu.exe -rom ../bin/x16emu/rom.bin -fsroot . -prg GPC.PRG -run
```

**Scripted, by writing `GPC.INPUT` yourself** and running the engine directly — this is what lets
one program drive another:

```sh
cd release
printf 'SOURCE.PRG\nOBJECT.PRG\n\n' > GPC.INPUT           # default self-contained build (no map)
printf 'SOURCE.PRG\nOBJECT.PRG\n\nshared\n' > GPC.INPUT   # shared-runtime build (line 4 = mode)
../bin/x16emu/x16emu.exe -rom ../bin/x16emu/rom.bin -fsroot . -prg GPC.BLITZ.BIN -run
#  -> GPC SQUEALING...
#     IN:  SOURCE.PRG
#     OUT: OBJECT.PRG
```

On success `OBJECT.PRG` is a standalone program you can `LOAD"OBJECT.PRG"` / `RUN`. `LIST` it and it
identifies itself — the BASIC stub reads `SYS 2069 : REM GPC!` (the way the original C64 Blitz stamps
`REM Blitz!` and Prog8 stamps `REM PROG8`). On failure the compiler prints the error and the offending
line, e.g. `SYNTAX ERROR @ 610` or `NOT IMPLEMENTED @ 2400`.

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

### The shared runtime (line 4 = `shared`)

By default every object is **self-contained**: the ~11 KB runtime is copied in ahead of the
program's own code (see [Runtime footprint](#runtime-footprint)). That is ideal for shipping one
program, but wasteful when several compiled programs load one after another — each carries its own
copy of the same runtime.

The **shared** mode factors that runtime out into a single resident copy. A program compiled with
line 4 = `shared` (first byte `S`) carries **no embedded runtime**: the compiler streams a 255-byte
bootstrap at `$0801` followed by the p-code, and the object is just that — bootstrap plus p-code.
The runtime lives once, on the drive, as a standalone binary **`GPC.RT.BIN`** that loads at `$7300`.

On `RUN`, the bootstrap checks for the magic `GPC1` at `$7300`. If the runtime isn't already
resident it `LOAD`s `GPC.RT.BIN` once (device 8, secondary 1, so the file's own load address is
honoured); otherwise it reuses the copy already in memory. It then enters the runtime and runs the
p-code. So the first shared program to run pays the load cost, and every shared program after it
starts instantly and shares the one resident runtime — the payoff for a suite of programs that hand
off to each other.

Requirements and limits:

- **`GPC.RT.BIN` must be on the drive** alongside the shared objects. It is built by the runtime
  makefile and ships in `testing/`.
- Programs mixing shared and self-contained builds are fine; a shared object simply needs the
  resident runtime present when it runs.
- Very large programs can be rejected with `PROGRAM TOO BIG` (the p-code must leave room for the
  work area below the runtime); in practice the compiler's general memory ceiling is hit first.

The regression test lives in `source/unit-tests/shared-runtime/` — it compiles a program shared,
checks the object layout, and proves both a cold start (fresh machine loads `GPC.RT.BIN`) and a warm
start (runtime already resident, and provably reused rather than reloaded).

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
make -C source/unit-tests/compiler-runtime    # randomised compile-and-run regression suites
```

A suite **passes when the emulator exits** (the compiled test reaches a `jmp $FFFF`) and
**fails by looping forever**, so always run under a timeout.

## License

MIT — see [`LICENSE`](LICENSE). © 2023 paulscottrobson and contributors.
