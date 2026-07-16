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

## Runtime footprint

Every compiled program carries the same support runtime — the P-code VM, all command handlers, and the
math libraries — copied in ahead of its own code. It measures **~11 KB** (10,956 bytes): `runtime.library`
7.3K (the VM plus all 158 handlers), `ifloat32` 2.3K, `polynomials` 0.9K, then the error vectors and the
BASIC stub.

For comparison, the vintage **C64 Blitz!** runtime (in `demo-c64/`) is roughly **half** ours — its compiled `DIR`
is 6.2 KB against our 11 KB build of the same program, an estimated ~5.8 KB of runtime. The difference
is two design choices, not overhead:

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
make release     # package release/ (the compiler + samples)
make latest      # download & install the matching x16emu + ROM into bin/x16emu/
```

## Compiling a program

The compiler engine is **`GPC.BLITZ.BIN`**. It reads its job from a control file, **`GPC.INPUT`**,
of up to three text lines:

| Line | Contents | |
| --- | --- | --- |
| 1 | the tokenised BASIC `.PRG` to compile | required |
| 2 | the compiled `.PRG` to write | required |
| 3 | a debug map to write (see below), or empty for none | optional |

A line ends at a CR, an LF, or any control byte, and blank lines are skipped — so a `GPC.INPUT`
typed on a CRLF host drives the X16 compiler unchanged. Names may be lowercase; the compiler folds
them to the uppercase PETSCII the KERNAL wants in a filename. With the source or object line missing
the compiler prints `NO GPC.INPUT FILE` and stops, rather than guess at what to build.

### Driving it — two ways

**Interactively, with `GPC.PRG`.** The front end asks the three questions, writes `GPC.INPUT`, and
chain-loads the engine. A bare RETURN at the output prompt names the object `C.` + source (`DIR.PRG`
→ `C.DIR.PRG`); answer the map question and the map is named `M.` + source:

```sh
cd release
../bin/x16emu/x16emu.exe -rom ../bin/x16emu/rom.bin -fsroot . -prg GPC.PRG -run
```

**Scripted, by writing `GPC.INPUT` yourself** and running the engine directly — this is what lets
one program drive another:

```sh
cd release
printf 'SOURCE.PRG\nOBJECT.PRG\n\n' > GPC.INPUT   # third line empty: no map
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
