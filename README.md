# GPC Blitz-X16 — a BASIC compiler for the Commander X16

> Code name… Greased Piglet!

A Blitz-style compiler that turns tokenised Commander X16 BASIC into a **standalone
65C02 machine-code program**. There is no runtime interpreter in the output: a compiled
program is native code plus a small support library, and it runs with no BASIC in memory.

The compiler itself is a 6502 program — it runs **on the X16** (or an emulator), reads a
tokenised BASIC file, and writes a compiled `.PRG`.

Forked from Paul Robson's original: <https://github.com/paulscottrobson/blitz-compiler>

## Status

- Targets **ROM revision R49**. The bundled emulator ROM in `bin/x16emu/` must match; bumping
  `REVISION` in the `Makefile` means refreshing that `rom.bin` too.
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
| `release/` | the built compiler and sample programs, ready to run |
| `documents/` | build include (`common.make`), notes, and reference PDFs |

## Building

Needs **GNU make**, **[64tass](https://sourceforge.net/projects/tass64/)**, and **Python 3**.
On Windows, build from **Git Bash** — every recipe in the tree is POSIX, and `common.make`
forces `SHELL := sh` accordingly. Per-machine tool paths go in an untracked
`documents/local.make`.

```sh
make libs        # build the five bin/*.library files and the compiler
make release     # package release/ (the compiler + samples)
make latest      # download & install the matching x16emu + ROM into bin/x16emu/
```

## Compiling a program

The compiler reads its job from **`GPC.INPUT`** — two lines, the tokenised source `.PRG` and
the output `.PRG`:

```text
SOURCE.PRG
OBJECT.PRG
```

Load and run the compiler in the emulator; it reads `SOURCE.PRG`, compiles, and writes
`OBJECT.PRG`:

```sh
cd release
../bin/x16emu/x16emu.exe -rom ../bin/x16emu/rom.bin -fsroot . -prg GPC.BLITZ.BIN -run
#  -> GPC SQUEALING...
#     IN:  SOURCE.PRG
#     OUT: OBJECT.PRG
```

On success `OBJECT.PRG` is a standalone program you can `LOAD"OBJECT.PRG"` / `RUN`. On failure
the compiler prints the error and the offending line, e.g. `SYNTAX ERROR @ 610` or
`NOT IMPLEMENTED @ 2400`.

To get a tokenised `SOURCE.PRG` from a text listing without a running X16, use the host
tokeniser (`bin/tokenise.zip`, stdlib Python) — the test harness does exactly this.

## Emulators

Two emulators live in `bin/`, each in its own directory because they need incompatible
`SDL2.dll` versions:

- **`bin/x16emu/`** — runs the automated test suites and is the correct emulator for anything
  that reads hardware (e.g. VERA sprite collision). Launch with **`release/x16emu.bat`**.
- **`bin/box16/`** — the debugger. Launch with **`release/box16.bat`**.

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
