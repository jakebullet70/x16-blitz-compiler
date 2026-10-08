# GPC 1.2.0 release notes

GPC 1.2.0 follows 0.9.114, the last public release. Versions 1.0.0 and
1.1.0 went to testers only, so these notes cover every change since 0.9.114.

- Download: `gpc-release-1.2.0.zip`.
- Target: X16 ROM R49.
- Runtime: build 133.

`README.md` covers using the compiler. `GPC-BASIC/GP-BASIC.md` is the
manual for the language and the library.

## Highlights

- GP.BASIC: block `IF`, `DO` loops, `SELECT`, procedures, functions,
  string verbs, screen drawing and pointers, as `GP.` keywords. A program
  that uses none of them carries none of their runtime code.
- Inline 65C02 assembly in `GP.ASM` blocks, with labels and BASIC variables
  by name.
- Banked code. `GP.BANKED` regions run from RAM banks 2 to 255, 127 regions
  a program, loaded from one `.OVL` file.
- The `GPC-BASIC/` library: menus, dialogs, forms, a file picker, file and
  directory verbs, string helpers, a sort, key-value stores and a RAM bank
  manager.
- BASLOAD-GPC, a BASLOAD with no source size limit, string `#DEFINE` and a
  name pool for each kind of variable.
- GPC.HELP, the manual on the X16.
- More room for code. The largest `LOW CODE`:

  | Build | 0.9.114 | 1.2.0 |
  | --- | --- | --- |
  | self-contained, `CORE` | 18,432 | 22,272 |
  | self-contained, `GPBASIC` | - | 20,736 |
  | shared, `CORE` | 18,176 | 22,016 |
  | shared, `GPBASIC` | - | 19,968 |

- 12,286 code lines a program.
- Dead-code removal, on by default.
- `#GPC` directives. A source names its own build, and GPC.PRG skips the
  prompts it answers.
- Eight samples.

## Compiler

- The engine is `GPC.BIN`. It was `GPC.BLITZ.BIN`.
- The compiler reads the source in two passes and writes the object
  straight to disk.
- A self-contained compile copies its runtime from `GPC.IMG.133.BIN` and
  `GP1.IMG.133.BIN`. Without them it stops with `NO RUNTIME IMAGE`.
- An input file that is not a tokenised BASIC PRG stops with
  `NOT A BASIC PRG FILE`. GPC.PRG checks the same at its prompt.
- The engine scratches the last run's object and map before it compiles.
  A failed compile leaves no object behind.
- `STRUCTURE IMBALANCE` is now `BLOCK MISMATCH`.
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
  `PROGRAM TOO BIG @ 12287`. The line table and the variables no longer
  share one bank, which raised `PROGRAM TOO BIG` early.
- A `%` or `$` scalar takes 2 bytes. 0.9.114 gave every scalar 6 bytes.
  Scalars past 4,096 bytes stop the compile with `TOO MANY VARIABLES`.

## GP.BASIC

`GPB.INC.BL` defines the `GP.` keywords for BASLOAD. `GPC-BASIC/GP-BASIC.md`
section 3 documents each one.

- Blocks: `GP.IF`, `GP.ELSEIF`, `GP.ELSE`, `GP.ENDIF`; `GP.DO`, `GP.LOOP`,
  `GP.EXITDO`; `GP.SELECT`, `GP.CASE`, `GP.OTHER`, `GP.ENDSEL`. A `GOTO` may
  leave a block.
- Calls: `GP.CALL`; `GP.DEFPROC` and `GP.SUB` for one-line calls; `GP.FN`
  with `RETURNS`.
- Strings: `GP.FIND`, `GP.INSTR`, `GP.CONTAINS`, `GP.COMP`, `GP.PAD` and
  `GP.ISEMPTY`.
- Pointers: `GP.STRPTR`, `GP.ARRPTR`, `GP.LOBYTE` and `GP.HIBYTE`.
- Screen: `GP.BOX`, `GP.FILL`, `GP.PRINTAT` and `GP.CHAR`.
- Assembly: `GP.ASM` and `GP.ENDASM`. A block is assembled into the object
  and costs no runtime bytes. `{NAME}` gives a BASIC variable's address,
  read from the `.SYM` file BASLOAD writes.
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
- Literal text in a bank: `GP.BANKEDSTR` declares a group of strings,
  `GP.BSTR` reads one and `GP.BSTRSET NAME, n, A$` writes slot n, cut to the
  slot's size. A `SPC(n)` line in a group declares an empty slot of n bytes,
  0 to 50.

## Runtime, build 133

- A shared program loads one of two runtimes. `GPB.RT.133.BIN` holds the GP
  handlers. `GPC.RT.133.BIN` holds the core only and leaves more room.
- Rarely used handlers run from bank 1. A shared program loads
  `GP1.RT.133.BIN` beside its runtime. A self-contained program carries the
  bank 1 code.
- A missing runtime file is named on screen: `?RTB133`, `?RTC133` or
  `?RT1133`.
- A runtime error inside a region prints the bank and the address, as in
  `$0C:AAF4`. GPC.ERR takes that form.
- A program loaded by `LOAD` from a compiled program starts with every
  variable cleared, as an interpreted program does on the X16.
- Fixes:
  - A program chained by `LOAD` ran on the loader's frame stack and stopped
    with `OUT OF MEMORY` at its first `GOSUB` or `FOR`.
  - Re-entering a `FOR` that was left without its `NEXT` added a frame each
    time until `OUT OF MEMORY`. `FOR` now reuses the frame, as X16 BASIC
    does.
  - `A(B(I))`, an array index inside an array index, stopped with
    `BAD ARRAY INDEX`.
  - The string heap now reuses dead blocks. A long run of string work could
    stop with `OUT OF MEMORY`.
- Fixes where a compiled program differed from X16 BASIC:
  - `JOY` returns the A, X, L and R buttons in the high byte.
  - `PSGVOL` and `FMVOL` take a volume. They were inverted.
  - `PRINT#` releases its channel, and `CLS` and `COLOR` print to the
    screen.
  - `PEEK` of `$C000` to `$FFFF` reads the ROM bank that `BANK` chose, and
    `SYS` into that range runs under it. The ROM bank starts at 0, the
    KERNAL. `PEEK($FF80)` gives 49, not 255.
- Faster array access and `NEXT`, and a cheaper STOP key check.

## BASLOAD-GPC

`BASLOAD-GPC.PRG` is Stefan Jakobsson's BASLOAD, run from RAM, with these
changes. Its source is in `SRC/GPC-BASLOAD/`.

- It writes the PRG straight to disk. The source has no size limit.
- `#DEFINE NAME "text"` takes a string. Every later use of NAME is replaced
  by the text, quotes included. A use inside a string literal or on a
  `#GPC` line is not replaced.
- Each of the six kinds of variable name (`N`, `N%`, `N$`, `N(`, `N%(`,
  `N$(`) has its own pool of about 1,135 names. ROM BASLOAD has about 950
  names shared by all six.
  - A crunched name may start with `[ \ ] ^ _` as well as `A` to `Z`.
  - Past the pool, BASLOAD-GPC stops with `OUT OF VARIABLE NAMES`.
  - The `.SYM` file records each name with its sigil and `(`.
- A `#GPC` line goes into the PRG as a `REM` for the compiler.
- After a clean run, when `.BASLOAD.NEXT` is on the source's drive, the
  engine prints `RUNNING .BASLOAD.NEXT`, then loads and runs it. A build
  can chain the compile after the tokenise.

## Library, `GPC-BASIC/`

A program `#INCLUDE`s the modules it uses, and pays only for those.

| Module | What it does |
| --- | --- |
| `GPB` | the `GP.` keywords; every GP.BASIC source needs it |
| `APPSYS` | start an application and leave the machine as it was |
| `THEME` | named colour roles, in five themes |
| `KB` | empty the keyboard buffer |
| `MENU` | menus built a row at a time: a popup and a bar |
| `MENU.INC.BANKED` | the menu row store |
| `MENUPULL` | a dropdown under a bar item |
| `MENUKEY` | a menu bar run from the program's own key loop |
| `GUI` | the box that puts the screen back, and its controls |
| `GUI-DIALOGS` | every dialog as a verb, list boxes and forms |
| `CHECK` | a check box form control |
| `COMBO` | a drop-down list form control |
| `GUI-LITE` | a message box and a menu in low memory |
| `LINEINPUT` | a positioned, length-limited entry field |
| `FILEIO` | drive status, exists, delete, rename, copy, directories |
| `FILEDIR` | a directory read into a RAM bank or low RAM |
| `FILEPICK` | a popup file picker |
| `DOS` | a smaller `FILEIO`: a drive command and a file test |
| `STRINGS` | string helpers |
| `STRCASE` | case, rewriting a string in place |
| `STRUSING` | a number to a template, as PRINT USING |
| `SORT` | shell sort a string array in place |
| `KV` | strings by key in one RAM bank, saved as one file |
| `KVBIN` | keys and values in one shared file; runs in ROM BASIC too |
| `BANKMGR` | which RAM bank belongs to whom |
| `STASH` | a text rectangle saved to a RAM bank |
| `STASHFILE` | a text rectangle saved through a file |
| `STASHVRAM` | rectangles and byte blobs in spare VRAM |
| `BITS` | packed flags, eight to the byte |
| `MATH` | the smaller and the larger of two numbers |
| `MEM` | a block copied and a block filled |
| `BMX` | a BMX bitmap loaded into VERA |

- The GUI modules take their RAM bank and address from the program. They
  never pick one themselves.
- A dialog saves the screen cells it covers and puts them back when it
  closes.
- A module goes inside a `GP.BANKED` region as it is, because a call into
  the region selects its bank.
- The `.EXP.BL` files are short example programs.

`GPC-BASIC/GP-BASIC.md` section 4 documents each module.
`GPC-BASIC/GP-BASIC.GLOBALS.md` lists every name each module owns.

## Tools

- GPC.PRG is a shared GP.BASIC program. It needs `GPB.RT.133.BIN` and
  `GP1.RT.133.BIN` beside it.
- GPC.HELP is the manual on the X16: `GPC.HELP.PRG`, `GPC.HELP.OVL` and
  `HELP-TXT/`. It has 76 topics and a page for each library module. An
  example program opens from the index in syntax colour.
- GPC.ERR is a windowed program. It loads a map by name or from a file
  picker, and takes a runtime error address, `$027E` or `$0C:AAF4`, or a
  BASIC line number. It answers with the source file, the line and the
  nearest label above it.
- `SRC/` holds the source of GPC.PRG, GPC.ERR, GPC.HELP and BASLOAD-GPC.

## Samples

Every sample carries its runtime and runs from its own folder, under
`SAMPLES/`.

- `GUI-LITE`: a message box and a menu in one low-memory program.
- `GUI-FIELD-EDIT`: a video rental checkout, one 80x30 form of 26
  controls. Its library code runs from banked regions.
- `KV-BIN-STORE`: a registry in one file, edited from GPC-BASIC, ROM BASIC
  and Prog8.
- `MANDELBROT-SPEED`: one picture drawn by ROM BASIC, by GPC and with a
  `GP.ASM` inner loop. 6,048, 3,075 and 284 jiffies on x16emu R49.
- `LANDER64`: a port of rosdec/lander64 in GP.BASIC, with sprites,
  joystick and sound.
- `GPBMODS`, `BMXVIEW` and `COLORTST`.

## Upgrading from 0.9.114

- Replace every file from 0.9.114. `GPC.BLITZ.BIN` is now `GPC.BIN`. A
  script that loads the engine by name needs the new name. `GPC.INPUT`
  keeps its first four lines as they were.
- Copy the runtime files with the compiler: `GPC.IMG.133.BIN`,
  `GP1.IMG.133.BIN`, `GPB.RT.133.BIN`, `GPC.RT.133.BIN` and
  `GP1.RT.133.BIN`.
- Recompile every shared program. A 0.9.114 shared program needs the
  runtime from 0.9.114. Self-contained programs carry their runtime and keep
  running.
- A program loaded from a compiled program starts with its variables
  cleared. In 0.9.114 it inherited the loader's variables. Pass a value
  across a `LOAD` in a file.
- `STRUCTURE IMBALANCE` is now `BLOCK MISMATCH`.
- Dead-code removal is on. `#GPC NOSTRIP` keeps every line.
- Do not delete the last object and map before a compile. The engine
  scratches them.

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
