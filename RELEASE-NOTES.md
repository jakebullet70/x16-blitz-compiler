# GPC 1.2.0 release notes

GPC 1.2.0 follows 1.0.0. There was no public 1.1.0, so these notes cover
every change since 1.0.0.

- Download: `gpc-release-1.2.0.zip`.
- Target: X16 ROM R49.
- Runtime: build 133. 1.0.0 shipped build 120.

`README.md` covers using the compiler. `GPC-BASIC/GP-BASIC.md` is the
manual for the language and the library.

## Highlights

- More room for code. The largest `LOW CODE` grew by 3,840 to 4,352 bytes:

  | Build | 1.0.0 | 1.2.0 |
  | --- | --- | --- |
  | self-contained, `CORE` | 18,432 | 22,272 |
  | self-contained, `GPBASIC` | 16,384 | 20,736 |
  | shared, `CORE` | 17,664 | 22,016 |
  | shared, `GPBASIC` | 15,616 | 19,968 |

- Dead-code removal, on by default. Lines that no path reaches are left out
  of the object.
- `#GPC` directives. A source names its own build, and GPC.PRG skips the
  prompts it answers.
- `GP.BANKED` regions in banks 2 to 255, 127 regions a program, in one
  `.OVL` file. Calls into and out of a region select the right bank.
- 12,286 code lines a program. The limit was 4,096.
- A rebuilt GUI library: menus, dialogs, forms, combos, check boxes, list
  boxes and a file picker.
- Five new samples: GUI-LITE, GUI-FIELD-EDIT, KV-BIN-STORE,
  MANDELBROT-SPEED and LANDER64.

## Compiler

- Dead-code removal. The compiler leaves out every line that no path from
  the first line reaches. `#GPC NOSTRIP`, or `N` at the GPC.PRG prompt, keeps
  them. The report prints `DEAD CODE:` with the lines removed and the bytes
  saved. `GPC-BASIC/GP-BASIC.md` section 7 lists what counts as reached.
- `#GPC` directives: `#GPC SHARED`, `EMBEDDED`, `OBJECT "NAME.PRG"`, `MAP`,
  `NOSTRIP` and `DEADLIST`. GPC.PRG reads them at the head of the source and
  prints each value with `(SOURCE)` after it. A source with no directives
  gets the usual prompts.
  - The short `#GPC` spelling needs BASLOAD-GPC. `REM #GPC` between `#REM 1`
    and `#REM 0` works under ROM BASLOAD too.
  - A directive after the first code line stops the compile with
    `DIRECTIVE TOO LATE`. An unknown word stops it with
    `UNKNOWN DIRECTIVE`.
  - `GPC-BASIC/GP-BASIC.md` section 2 has the full detail.
- A statement that fails with `SYNTAX ERROR` no longer passes in silence.
  The compile still finishes, and the report lists the lines above the `OK`:
  `2 STATEMENTS NOT COMPILED: 1669 1702`. The stub left in each place raises
  `SYNTAX ERROR` if the program reaches it.
- 12,286 code lines a program. One more stops the compile with
  `PROGRAM TOO BIG @ 12287`.
- A `%` or `$` scalar takes 2 bytes. 1.0.0 gave every scalar 6 bytes.
  Scalars past 4,096 bytes stop the compile with `TOO MANY VARIABLES`.
- `GP.BANKED`:
  - Regions go in banks 2 to 255, at most 127 a program. Bank 1 holds runtime
    code, and `GP.BANKED 1` stops the compile with `BANK 1 IS RESERVED`.
  - Every region of a program is written to one `NAME.OVL` beside the
    object. The program reads it as it starts. A missing or short `.OVL`
    prints `?OVL`. A bank the machine does not have prints `?RAM`.
  - A `GOSUB`, `GP.SUB`, `GP.FN` or `FN` into a region selects the region's
    bank, and `RETURN` selects the caller's again. A call out of a region to
    low memory returns under the region's bank.
  - A `GOTO` into a region from outside it is refused with
    `NOT IMPLEMENTED`. Enter a region by a call.
  - A `GP.ASM` block inside a region is assembled into the region's bank.
    `GP.ASM LOW` keeps a block in low memory.
- `GP.ASM` reads the `.SYM` file once a compile and keeps it in banks 24
  to 27. A program with many names compiles faster.
- Two `GP.FN` calls on one string verb in one expression no longer give the
  second answer twice.

## Runtime, build 133

- Rarely used handlers run from bank 1. This is where the extra `LOW CODE`
  room comes from. A shared program loads `GP1.RT.133.BIN` beside its
  runtime. A self-contained program carries the bank 1 code.
- A missing runtime file is named on screen: `?RTB133`, `?RTC133` or
  `?RT1133`.
- A runtime error inside a region prints the bank and the address, as in
  `$0C:AAF4`. GPC.ERR takes that form.
- A program loaded by `LOAD` from a compiled program starts with every
  variable cleared, as an interpreted program does on the X16.
- Fixes where a compiled program differed from X16 BASIC:
  - `JOY` returns the A, X, L and R buttons in the high byte.
  - `PSGVOL` and `FMVOL` take a volume. 1.0.0 had them inverted.
  - `PRINT#` releases its channel, and `CLS` and `COLOR` print to the
    screen.
  - `PEEK` of `$C000` to `$FFFF` reads the ROM bank that `BANK` chose, and
    `SYS` into that range runs under it. The ROM bank starts at 0, the
    KERNAL. `PEEK($FF80)` gives 49, not 255.

## GP.BASIC keywords

- `GP.BSTRSET NAME, n, A$` writes slot n of a `GP.BANKEDSTR` group, cut to
  the slot's size. A `SPC(n)` line in a group declares an empty slot of n
  bytes, 0 to 50.

## BASLOAD-GPC

- `#DEFINE NAME "text"` takes a string. Every later use of NAME is replaced
  by the text, quotes included. A use inside a string literal or on a
  `#GPC` line is not replaced.
- Each of the six kinds of variable name (`N`, `N%`, `N$`, `N(`, `N%(`,
  `N$(`) has its own pool of about 1,135 names. ROM BASLOAD has about 950
  names shared by all six.
  - A crunched name may start with `[ \ ] ^ _` as well as `A` to `Z`.
  - Past the pool, BASLOAD-GPC stops with `OUT OF VARIABLE NAMES`.
  - The `.SYM` file records each name with its sigil and `(`.
- After a clean run, when `.BASLOAD.NEXT` is on the source's drive, the
  engine prints `RUNNING .BASLOAD.NEXT`, then loads and runs it. A build
  can chain the compile after the tokenise.
- The front end prints each line number once.

## Library, `GPC-BASIC/`

- New modules:

  | Module | What it does |
  | --- | --- |
  | `MENU` | menus built a row at a time: a popup and a bar |
  | `MENU.INC.BANKED` | the menu row store |
  | `MENUPULL` | a dropdown under a bar item |
  | `MENUKEY` | a menu bar run from the program's own key loop |
  | `GUI-DIALOGS` | every dialog as a verb, list boxes and forms |
  | `CHECK` | a check box form control |
  | `COMBO` | a drop-down list form control |
  | `GUI-LITE` | a message box and a menu in low memory |
  | `FILEIO` | drive status, exists, delete, rename, copy, directories |
  | `FILEDIR` | a directory read into a RAM bank or low RAM |
  | `FILEPICK` | a popup file picker |
  | `DOS` | a smaller `FILEIO`: a drive command and a file test |
  | `BANKMGR` | which RAM bank belongs to whom |
  | `STASHVRAM` | rectangles and byte blobs in spare VRAM |
  | `BITS` | packed flags, eight to the byte |
  | `KV` | strings by key in one RAM bank, saved as one file |
  | `KVBIN` | keys and values in one shared file; runs in ROM BASIC too |
  | `MATH` | the smaller and the larger of two numbers |
  | `MEM` | a block copied and a block filled |

- The GUI modules take their RAM bank and address from the program. They
  never pick one themselves.
- Fourteen modules use `%` integer names, public names included: BANKMGR,
  STASHVRAM, THEME, MENU.INC.BANKED, MENU, MENUPULL, GUI, COMBO, CHECK,
  GUI-DIALOGS, FILEIO, FILEDIR, FILEPICK and KVBIN.
- A dialog saves the screen cells it covers and puts them back when it
  closes. The program does not repaint.
- `DLGLABELS ok$, cancel$, yes$, no$` sets the dialog button labels.
  `DLGHISTORY list$` gives the next input box a list of earlier answers, and
  Up and Down walk it.
- `PICKFILE` walks directories, deletes a file on D then Y, and shows or
  hides folders with F. `PICKLABELS` sets its footer text.
- The theme reaches the menus, and dialogs take a box style.
- The bank twins and shims are gone. A module goes inside a `GP.BANKED`
  region as it is, because a call into the region selects its bank.

`GPC-BASIC/GP-BASIC.md` section 4 documents each module.
`GPC-BASIC/GP-BASIC.GLOBALS.md` lists every name each module owns.

## Tools

- GPB.HELP is now GPC.HELP: `GPC.HELP.PRG`, `GPC.HELP.OVL` and
  `HELP-TXT/`. It has 76 topics and a page for each library module.
  An example program opens from the index in syntax colour. Topic text is
  loaded once into banks, so scrolling is fast.
- GPC.ERR is a windowed program. It loads a map by name or from a file
  picker, and takes a runtime error address, `$027E` or `$0C:AAF4`, or a
  BASIC line number. It answers with the source file, the line and the
  nearest label above it.
- `SRC/` holds the source of GPC.PRG, GPC.ERR, GPC.HELP and BASLOAD-GPC.

## Samples

Every sample carries its runtime and runs from its own folder.

- New:
  - `GUI-LITE`: a message box and a menu in one low-memory program.
  - `GUI-FIELD-EDIT`: a video rental checkout, one 80x30 form of 26
    controls. Its library code runs from banked regions.
  - `KV-BIN-STORE`: a registry in one file, edited from GPC-BASIC, ROM BASIC
    and Prog8.
  - `MANDELBROT-SPEED`: one picture drawn by ROM BASIC, by GPC and with a
    `GP.ASM` inner loop. 6,048, 3,075 and 284 jiffies on x16emu R49.
  - `LANDER64`: a port of rosdec/lander64 in GP.BASIC, with sprites,
    joystick and sound.
- Rebuilt: `GPBMODS`, `BMXVIEW` and `COLORTST`.
- Removed: `EDITOR`.

## Upgrading from 1.0.0

- Recompile every shared program. A shared object loads the runtime named
  for the build it was compiled against. A 1.0.0 shared program needs
  `GPB.RT.120.BIN` or `GPC.RT.120.BIN` on the drive. A 1.2.0 one needs a
  `.133.` runtime and `GP1.RT.133.BIN`. Self-contained programs carry
  their runtime and keep running.
- A program with `GP.BANKED` regions ships as `NAME.PRG` and `NAME.OVL`.
  The `.Bnn` files of 1.0.0 are not read. Keep the `.OVL` beside its
  program, under the name the compiler gave it.
- A program loaded from a compiled program starts with its variables
  cleared. Pass a value across a `LOAD` in a file.
- Dead-code removal is on. `#GPC NOSTRIP` keeps every line.
- These library files are gone:
  - `MENUBAR` and `MENUVERT`. Use `MENU`, `MENUPULL` and `MENUKEY`.
  - `GUI2`. Use `GUI` and `GUI-DIALOGS`.
  - `GUI.BANK`, `THEME.BANK`, `LINEINPUT.BANK` and `SHIM.GUIBANK`. Put the
    plain module inside a `GP.BANKED` region.

  A 1.0.0 program built on the GUI needs porting to the 1.2.0 verbs.
  `GUI-LITE` and `GUI-FIELD-EDIT` show the new shape.
- A program that uses the fourteen modules above writes their names with
  `%`: `THEME.CLR%(role)`, not `THEME.CLR(role)`, and `GUI.SEL%`, not
  `GUI.SEL`.

  WARNING: an old bare name compiles with no error. It is a new, unrelated
  variable that holds 0.
- `GUI.INC.BL` needs `STASHVRAM.INC.BL` included before it.
- `MENU.INC.BANKED.BL` has no default text bank. Write
  `#DEFINE MENU.TEXTBANK n` before `#INCLUDE "MENU.INC.BANKED.BL"`.

## Known issues

- `SLEEP n` waits n ticks of the 60 Hz clock. ROM BASIC waits n+1 frames.
  `SLEEP 0` and a bare `SLEEP` return at once, where ROM BASIC waits for the
  next frame. Write `SLEEP 1`.
- Inside a `GP.ASM` block, an operand that names a label starting with `A`
  stops the compile with `PASS 1 SYNTAX ERROR`. `ASL A` is unaffected. Start
  the label with another letter.
- A second `DIM` of a dimensioned array raises no error. X16 BASIC stops
  with `?REDIM'D ARRAY ERROR`. Dimension each array once.
- A `GP.ASM` `{VAR}` with a sigil or an array needs a `.SYM` from
  BASLOAD-GPC. Under ROM BASLOAD, `{N%}`, `{N$}`, `{N()}` and `{N%()}` stop
  the compile with `UNKNOWN VARIABLE IN {}`. A plain `{N}` works under
  either.

## Licence

GPC is MIT: (c) 2023 paulscottrobson, (c) 2026 Steven De George SR. See
`LICENSE`. BASLOAD-GPC is built on Stefan Jakobsson's BASLOAD, under the BSD
2-Clause licence in `SRC/GPC-BASLOAD/LICENSE`. LANDER64 carries its own
GPL-3 licence in its folder.
