# MANDELBROT-SPEED

This sample draws one Mandelbrot picture three ways and times each one.

## Files

| File | What | Runs in |
|---|---|---|
| `MANDEL.SRC.PRG` | `MANDEL.BASL`, tokenised by BASLOAD. | ROM BASIC |
| `MANDEL.PRG` | `MANDEL.BASL`, compiled by GPC. | GPC |
| `MANDELASM.PRG` | `MANDELASM.BASL`, compiled by GPC. | GPC |
| `MANDEL.BASL` | Source. Plain X16 BASIC, no GP keywords. | ROM BASIC, GPC |
| `MANDELASM.BASL` | Source. `MANDEL.BASL` with a `GP.ASM` inner loop. | GPC |
| `README.md` | This file. | |

`MANDELASM.BASL` runs in GPC only. ROM BASIC cannot run a GP keyword.

`MANDEL.PRG` and `MANDELASM.PRG` are compiled EMBEDDED. Each carries its own
runtime, so no runtime file is needed beside it. Neither has an `.OVL`.

## Run it

Start in the release root.

| Step | Type | Result |
|---|---|---|
| 1 | `DOS"CD:SAMPLES"` | Changes to `SAMPLES`. |
| 2 | `DOS"CD:MANDELBROT-SPEED"` | Changes to `SAMPLES/MANDELBROT-SPEED`. |
| 3 | `LOAD "MANDEL.SRC.PRG",8` | Loads the ROM BASIC version. |
| 4 | `RUN` | Shows the title page. |

Load `MANDEL.PRG` or `MANDELASM.PRG` the same way as in step 3.

| When | The screen |
|---|---|
| After `RUN` | The title page names all three programs and the one running. |
| A key is pressed | The run starts. |
| The last cell is drawn | Row 29 shows the time in jiffies and seconds. |
| | Row 30 says `PRESS A KEY TO EXIT.` |
| A key is pressed | The program exits. |

On exit the program puts back the screen mode, text colour and charset it
found.

## Times

`TI` is read when the key is pressed and again after the last cell is drawn.
Measured on x16emu R49 with ROM R49, at 60 jiffies a second.

| Program | Jiffies | Seconds | Speed |
|---|---|---|---|
| `MANDEL.SRC.PRG`, ROM BASIC | 6,048 | 100.8 | 1x |
| `MANDEL.PRG`, GPC | 3,075 | 51.3 | 1.97x |
| `MANDELASM.PRG`, GPC + `GP.ASM` | 284 | 4.7 | 21.3x |

## The picture

| Setting | Value |
|---|---|
| Screen mode | `SCREEN 3`, 40x30 |
| Picture | 40x28 cells |
| Iteration cap | 32 a cell |
| Real axis | -2.2 to 0.8 |
| Imaginary axis | -1.05 to 1.05 |
| Palette | 13 colours, repeating |

A cell's background colour is the count of iterations it took to escape,
through the 13-colour palette. A black cell never escaped, so it is in the
set.

## Why compiling gives 2x and GP.ASM gives 21x

The interpreter's work is scanning lines, finding variables and the backward
`GOTO` search. Compiling removes it. Compiling does not remove the arithmetic,
and this program is mostly floating-point multiplies and adds.

| Program | Interpreter work | Inner loop arithmetic |
|---|---|---|
| `MANDEL.SRC.PRG` | Kept | Floating point |
| `MANDEL.PRG` | Removed | Floating point, about 31,000 cycles an iteration |
| `MANDELASM.PRG` | Removed | 4.12 fixed point in `GP.ASM` |

Scaled-integer arithmetic written in BASIC is slower than the float version,
both interpreted and compiled. `INT()` and `/` cost more than the float
multiply they replace.

## MANDEL.BASL

`MANDEL.BASL` tells how it is running from `PEEK($0805)`.

| `PEEK($0805)` | Running under |
|---|---|
| `$9E`, `SYS` token | GPC. A compiled program's BASIC stub is `SYS 2069`. |
| Any other | ROM BASIC. The byte is the start of the program's first line. |

WARNING: The first statement of `MANDEL.BASL` must not be a `SYS`. Under ROM
BASIC its `$9E` token would sit at `$0805`, and the run would read as
compiled.

`MANDEL.BASL` does not include `APPSYS.INC.BL`. APPSYS uses `GP.CALL`, and ROM
BASIC cannot run a GP keyword. `MANDEL.BASL` saves and puts back the same
three settings in plain BASIC. On exit they are put back in the order of this
table.

| Setting | Saved with | Put back with |
|---|---|---|
| Text colour | `PEEK($0376)` | `COLOR` |
| Screen mode | `POKE 783,1`, `SYS $FF5F`, `PEEK(780)` | `SCREEN` |
| Charset | `PEEK($0372)` | `SYS $FF62` and `POKE $0372` |

ROM BASIC and GPC both pass `SYS` registers at 780-783.

## MANDELASM.BASL

BASIC keeps the screen, the rows and columns, the colours and the `VPOKE`. For
each cell it does `GOSUB MANDEL.ESCAPE.COUNT`. That routine is a `GP.ASM`
block. It iterates one point in 4.12 fixed point, where 4096 is 1.0, with a
shift-and-add 16x16 multiply. Each column's real part is worked out once, into
`MANDEL.COLUMN.REAL%()`.

`MANDEL.ESCAPE.COUNT` reads and writes these variables.

| Name | Direction | Holds |
|---|---|---|
| `MANDEL.C.REAL%` | In | The real part of c, 4.12. |
| `MANDEL.C.IMAGINARY%` | In | The imaginary part of c, 4.12. |
| `MANDEL.MOST.ITERATIONS%` | In | The cap, under 256. |
| `MANDEL.COUNT%` | Out | Iterations taken, or the cap if z never escaped. |

It uses this zero page.

| Address | Name |
|---|---|
| `$02-$10` | Part of the KERNAL's r0-r15, `$02-$21`. |
| `$2C-$31` | zTemp0-2. |

Any KERNAL call may change `$02-$21`, so no caller keeps a value there across
a block.

Against the float version, 19 of the 1,120 cells differ. All of them are on
the edge of the set.

`MANDELASM.BASL` includes `GPC-BASIC/GPB.INC.BL` and
`GPC-BASIC/APPSYS.INC.BL`. It saves the screen mode, text colour and charset
with `APPSYS.STARTUP` and puts them back with `APPSYS.RESTORE`.

## Rebuilding

The sample cannot be rebuilt in `SAMPLES/MANDELBROT-SPEED/`. The `#INCLUDE`
lines in `MANDELASM.BASL` need a `GPC-BASIC/` folder beside the source, and
that folder has none. The compiler is not there either. See the release root's
`README.md`, section "Compiling a program".

<!-- release: the rest is for the source tree -->

## In the repository

### Run it

`USER-RUNS\mandel-demo.bat` runs the three PRGs in the emulator.

| Argument | Runs |
|---|---|
| (none) | All three in turn. Close the emulator window to start the next. |
| `BASIC` | `MANDEL.SRC.PRG` |
| `GPC` | `MANDEL.PRG` |
| `ASM` | `MANDELASM.PRG` |

### Build

From the repository root:

```
python source\gpc\samplesbuild.py MANDEL MANDELASM
```

### Files

- `GPC-BASIC/` holds `GPB.INC.BL` and `APPSYS.INC.BL`, the modules
  `MANDELASM.BASL` includes.
- `GPC.BIN`, `GPC.PRG`, `BASLOAD-GPC.PRG` and `BASLOAD-GPC.BIN` are the
  compiler and tokeniser, for building on the machine.
- `GPC.IMG.131.BIN`, `GP1.IMG.131.BIN` and `*.RT.131.BIN` are the runtime
  images the compiler embeds.
- `GPC.INPUT` names the last compile's files. `GPC.PRG` writes it on every
  compile and `GPC.BIN` reads it.

### Build outputs

| File | Written by | Ships |
|---|---|---|
| `MANDEL.SRC.PRG` | BASLOAD | Yes |
| `MANDEL.PRG` | GPC | Yes |
| `MANDEL.MAP` | GPC | No |
| `MANDELASM.SRC.PRG` | BASLOAD | No |
| `MANDELASM.SRC.SYM` | BASLOAD | No |
| `MANDELASM.PRG` | GPC | Yes |
| `MANDELASM.MAP` | GPC | No |
