# GPC-HELP

The GP.BASIC and BASL reference that `GPB.HELP.PRG` shows on the X16, in one file you can read on a PC.

**Generated. Do not edit.** `MKHELP.PY` builds it and the `.HLP` files together from `GPC-BASIC/` -- the manual, the name register and the module banner headers. Fix anything wrong at the source and rebuild:

```
python samples/GPC-HELP/MKHELP.PY
```

## Contents

- **GETTING STARTED**
  - [1. What GP.BASIC is](#1-what-gpbasic-is)
  - [2. Using it](#2-using-it)
- **WHAT IS IN GPC**
  - [1. What has to be on the drive to compile](#1-what-has-to-be-on-the-drive-to-compile)
  - [2. The compiler](#2-the-compiler)
  - [3. The tools](#3-the-tools)
  - [4. GPC-BASIC/ -- the library](#4-gpc-basic----the-library)
  - [5. GPC-BASIC/ -- the examples](#5-gpc-basic----the-examples)
  - [6. The documents](#6-the-documents)
- **GP.* CORE KEYWORDS**
  - [3. Command reference](#3-command-reference)
  - [3.1 Loops](#31-loops)
  - [3.2 Multi-way branch](#32-multi-way-branch)
  - [3.3 Machine code](#33-machine-code)
  - [3.4 Strings](#34-strings)
  - [3.5 Arrays](#35-arrays)
  - [3.6 Screen -- stash and restore](#36-screen----stash-and-restore)
  - [3.7 Screen -- drawing](#37-screen----drawing)
  - [3.8 Block IF](#38-block-if)
  - [3.9 Inline assembly](#39-inline-assembly)
  - [3.9 Inline assembly (2)](#39-inline-assembly-2)
- **BASL MODULES**
  - [4. Module reference -- the BASL library](#4-module-reference----the-basl-library)
  - [4.1 THEME.INC.BL -- named colour roles](#41-themeincbl----named-colour-roles)
  - [4.2 STRINGS.INC.BL -- string helpers](#42-stringsincbl----string-helpers)
  - [4.3 APPSYS.INC.BL -- start politely, leave it as you found it](#43-appsysincbl----start-politely-leave-it-as-you-found-it)
  - [4.4 LINEINPUT.INC.BL -- a positioned entry field](#44-lineinputincbl----a-positioned-entry-field)
  - [4.5 BMX.INC.BL -- a BMX bitmap into VERA](#45-bmxincbl----a-bmx-bitmap-into-vera)
  - [4.6 MENUVERT.INC.BL -- a vertical menu](#46-menuvertincbl----a-vertical-menu)
  - [4.6 MENUVERT.INC.BL -- a vertical menu (2)](#46-menuvertincbl----a-vertical-menu-2)
  - [4.7 SORT.INC.BL -- shell sort a string array](#47-sortincbl----shell-sort-a-string-array)
  - [4.8 STRCASE.INC.BL -- case and trim, in place](#48-strcaseincbl----case-and-trim-in-place)
  - [GUI.INC.BL -- four dialogs, in a box that puts the screen back.](#guiincbl----four-dialogs-in-a-box-that-puts-the-screen-back)
  - [GUI2.INC.BL -- a listbox, single or multi select.](#gui2incbl----a-listbox-single-or-multi-select)
  - [MENUBAR.INC.BL -- a horizontal menu, in BASIC.](#menubarincbl----a-horizontal-menu-in-basic)
  - [STASH.INC.BL -- save a text rectangle, and put it back.](#stashincbl----save-a-text-rectangle-and-put-it-back)
  - [STASHFILE.INC.BL -- a saved text rectangle, through a file.](#stashfileincbl----a-saved-text-rectangle-through-a-file)
- **GLOBALS AND NAMING**
  - [5. Variables](#5-variables)
  - [1. The prefixes that are taken](#1-the-prefixes-that-are-taken)
  - [2. GP.* is keywords, not variables -- and the difference bites](#2-gp-is-keywords-not-variables----and-the-difference-bites)
  - [3. The modules](#3-the-modules)
  - [3. The modules (2)](#3-the-modules-2)
  - [4. Labels are global too](#4-labels-are-global-too)
  - [5. Two more naming rules that are not about collisions](#5-two-more-naming-rules-that-are-not-about-collisions)
  - [6. Regenerating this](#6-regenerating-this)
- **THE TRAPS**
  - [6. The traps, collected](#6-the-traps-collected)

---

# GETTING STARTED

## 1. What GP.BASIC is

#### 1. What GP.BASIC is

Three layers, innermost first.

**Core keywords.** 30 tokens, compiled to p-code and handled by assembly in the runtime:

    GP.DO GP.LOOP GP.EXITDO
    GP.IF GP.ELSEIF GP.ELSE GP.ENDIF
    GP.SELECT GP.CASE GP.OTHER GP.ENDSEL
    GP.INSTR GP.COMP GP.STRPTR GP.ARRPTR
    GP.BOX GP.FILL GP.CHAR GP.PRINTAT
    GP.CALL GP.A GP.X GP.Y GP.C
    GP.ASM GP.ENDASM

They are assembly because BASIC is slow at per-character string scans, screen fills and VERA writes.

The handlers occupy `GPBase $3800` to `ObjectBase $3c00`: 1,024 bytes, page aligned, all or nothing.
`ScanGPUsage` walks the finished p-code and drops the whole block from the object if nothing in it
is reached.

The block costs those 1,024 bytes once. The bytes in the object and the bytes off the workspace
floor are the same bytes — `runtimeEndPage` is a single page number that decides how much of the
runtime image is written out, where the p-code lands, and where the workspace starts. Maximum
p-code is 17,152 bytes with the block and 18,176 without: `ObjectBase` to `$9F00`, less the 4K
frame stack and the 4K minimum workspace.

**Composites.** `GP.CONTAINS`, `GP.ISEMPTY`, `GP.HIBYTE`, `GP.LOBYTE`. The compiler expands each
into opcodes that already exist. No handler, no vector slot, nothing in the block.

**The library.** `GPC-BASIC/`: 14 `.INC.BL` modules, 22 `.EXP.BL` examples. Ordinary BASL,
`#INCLUDE`d by path, called with `GOSUB`. Zero runtime bytes — a module costs its own p-code, in the
programs that include it. Menus vertical and bar, panels, themes, entry fields, in-place case and
trim, shell sort, a screen rectangle to a RAM bank or a file, BMX into VERA.

`STASH.INC.BL`, `SORT.INC.BL` and `STRCASE.INC.BL` are `GP.ASM` and still modules: as keywords their
925 bytes (329, 408, 188) would sit in the block, paid by every GP program. `GP.ARRPTR` and
`GP.STRPTR` are what lets them out — a BASL subroutine takes an address, not an array or a string.

The division is assembly for loops and bulk moves, BASIC for everything else. `LINEINPUT.GET`
waits on the keyboard, so speed does not apply to it; writing it in BASL saved 166 runtime bytes.

---


*See also: STASH.INC.BL -- save a text rectangle, and put it back., 4.7 SORT.INC.BL -- shell sort a string array, 4.8 STRCASE.INC.BL -- case and trim, in place*

## 2. Using it

#### 2. Using it

Every BASL source that uses a `GP.` keyword must declare the tokens:

```basic
#INCLUDE "GPB.INC.BL"
```

BASLOAD knows only the ROM's keywords. Without that line `GP.DO 5` is a syntax error. The
host-side tokeniser for hand-written `.bas` needs no such declaration; it learns the same tokens
from `c64tokens.py` at build time.

##### Where the library lives

Keep `GPC-BASIC/` as a folder beside your own sources and include from it by path:

```basic
#INCLUDE "/GPC-BASIC/GPB.INC.BL"
```

`#INCLUDE` accepts a path as well as a bare filename. Verified on R49 for both absolute
(`/GPC-BASIC/GPB.INC.BL`) and relative (`GPC-BASIC/GPB.INC.BL`) forms. Use the leading slash: it is
absolute from the drive root and still resolves when the program sits in a subdirectory. `../` and
`//` are not understood by the filesystem, so a path descends and never rises.

Then BASLOAD and GPC as usual: `BASLOAD "MYPROG.BL"`, then compile the resulting PRG with
`GPC.PRG`.

##### A program that uses GP.BASIC is compile-only

One GP.BASIC keyword is enough: from there the program is **compiler input**, and the ROM can no
longer `LIST` or `RUN` it. BASLOAD tokenises those keywords into `$CE58`-`$CE7F` and stock BASIC
has no handler behind those bytes.

**GPB is what GPC implements, and it has no existence apart from it.** The keyword set is not an
extension the ROM might one day understand, or a library that could be loaded to make it work:
`GP.DO` means something because the compiler emits code for it, and nowhere else. That is why the
tokenised file is not a program yet — there is nothing to run it with but GPC.

That is the intended route: run `GPC.PRG` on the tokenised `.PRG` and run the object it writes.

##### Numbers, and what a variable holds

One numeric type on the evaluation stack: a 4-byte mantissa, a 1-byte exponent and a status byte
carrying the sign. Exponent 0 means the value is an exact integer.

| Variable | Bytes | Holds |
|---|---:|---|
| `A` `A()` | 6 | mantissa, exponent, status. Exact integers while the exponent is 0 |
| `A%` `A%()` | 2 | signed 16-bit two's complement, **-32,768 to 32,767** |
| `A$` `A$()` | 2 | a pointer into the string heap |

`%` is smaller, not faster, and it truncates without raising an error. `WriteInteger` stores the
low two bytes of the value on the stack; `ReadInteger` sign-extends the MSB. `A% = 49152` reads back
as -16,384. Use `%` for counters, indices and screen coordinates.

Do not use `%` for an address. Main RAM runs to `$9F00` (40,704), the string heap is above 32,767 by
definition, and a VRAM address is 17 bits (up to 131,071). Hold an address in an untyped variable,
which represents all three exactly, or split it into page and offset.

Numeric literals above 65,535 are accepted. The compiler has a 16-bit fast path for constants;
anything wider compiles through the float encoder. Neither wraps.

`AND` and `OR` are 16-bit signed and raise `OUT OF RANGE` above 32,767; see §6.

---


*See also: 6. The traps, collected*

---

# WHAT IS IN GPC

## 1. What has to be on the drive to compile

#### 1. What has to be on the drive to compile

Five files, and all five. Put them beside each other:

| | |
|---|---|
| `GPC.PRG` | the front end you `RUN` |
| `GPC.BIN` | the engine it hands the job to |
| `GPC.IMG.nnn.BIN` | the runtime a self-contained object carries |
| `GPB.RT.nnn.BIN` | the shared runtime, with the `GP.*` handlers |
| `GPC.RT.nnn.BIN` | the same runtime without them |

`nnn` is the runtime build number and it is part of the name on purpose: a stale runtime under a
fixed name would still be found, and the mismatch would not show until something ran wrong.

Both shared runtimes are needed. Which one a program wants is decided when it is compiled, not when
it runs, so a drive carrying only one works for half the programs built against it. A program that
cannot find its runtime prints `?RT` and stops.

The front end needs `GPB.RT.nnn.BIN` for itself: `GPC.PRG` is a compiled GP.BASIC program built in
shared mode. The compiler is written in the language it compiles.

---


## 2. The compiler

#### 2. The compiler

`GPC.PRG` asks four questions — input file, output file, debug map, shared runtime — writes the
answers to `GPC.INPUT`, and chain-loads the engine. Writing that file is all it does.

`GPC.BIN` takes its whole job from `GPC.INPUT` and asks nothing. One program can therefore drive
another: write the control file and `RUN GPC.BIN`. That is how this project's test harness compiles,
and how to get a build if the front end itself is broken.

`GPC.INPUT` is up to four text lines: source, object, map file, and the word `SHARED`. It is
per-user state and is not shipped; the front end rewrites it on every compile.

`GPC.IMG.nnn.BIN` is the runtime streamed into every self-contained object as it is written. The
engine cannot compile without it. It was inside the engine until the object buffer was given the low
RAM, which is when the largest program GPC can build grew.

A compiled program identifies itself: `LIST` one and the BASIC stub reads `SYS 2069 : REM GPC!`.

---


## 3. The tools

#### 3. The tools

`GPC.ERR.PRG` turns a runtime error's `@ $XXXX` into a source line, using the debug map the
compiler writes when `MAKE A DEBUG MAP?` is answered yes. Without the map the address cannot be
resolved.

`BASLOAD` is not a file here; it is built into the R49 ROM. It reads `.BASL` source — BASIC with
long names, labels instead of line numbers, `#INCLUDE` and `#DEFINE` — and writes the tokenised
`.PRG` that GPC compiles. Every `.INC.BL` and `.EXP.BL` in this folder is BASLOAD source.

A program using GP.BASIC is compile-only. BASLOAD's output for one is not a program the ROM can
`LIST` or `RUN`, because nothing in BASIC sits behind a `GP.` token. It is compiler input.

---


## 4. GPC-BASIC/ -- the library

#### 4. `GPC-BASIC/` — the library

Text-mode building blocks, in BASL, `#INCLUDE`d into your source. BASL has no dead code
elimination: including a module costs its whole size whether or not it is called.

| | |
|---|---|
| `GPB.INC.BL` | the `GP.*` keyword definitions for BASLOAD. **Every source using a GP keyword needs this one**, and no other include is ever optional either |
| `THEME.INC.BL` | named colour roles, light and dark |
| `APPSYS.INC.BL` | start an application politely, and leave the machine as it was found |
| `STASH.INC.BL` | save a text rectangle to a RAM bank, and put it back |
| `STASHFILE.INC.BL` | the same rectangle, through a file |
| `LINEINPUT.INC.BL` | a positioned, length-limited entry field |
| `MENUVERT.INC.BL` | a vertical menu |
| `MENUBAR.INC.BL` | a horizontal menu bar |
| `GUI.INC.BL` | four dialogs — ask, say, type, choose — in a box that puts the screen back |
| `GUI2.INC.BL` | a listbox, single or multi select |
| `STRINGS.INC.BL` | the string helpers that belong in BASIC rather than assembly |
| `STRCASE.INC.BL` | case and trim, rewriting a string in place, in assembly |
| `SORT.INC.BL` | shell sort a string array in place, in assembly |
| `BMX.INC.BL` | load a BMX bitmap into VERA |

What each one costs in bytes is in the command reference, under *At a glance*.

---


*See also: 4.1 THEME.INC.BL -- named colour roles, 4.3 APPSYS.INC.BL -- start politely, leave it as you found it, STASH.INC.BL -- save a text rectangle, and put it back., STASHFILE.INC.BL -- a saved text rectangle, through a file., 4.4 LINEINPUT.INC.BL -- a positioned entry field, 4.6 MENUVERT.INC.BL -- a vertical menu, MENUBAR.INC.BL -- a horizontal menu, in BASIC., GUI.INC.BL -- four dialogs, in a box that puts the screen back., GUI2.INC.BL -- a listbox, single or multi select., 4.2 STRINGS.INC.BL -- string helpers, 4.8 STRCASE.INC.BL -- case and trim, in place, 4.7 SORT.INC.BL -- shell sort a string array*

## 5. GPC-BASIC/ -- the examples

#### 5. `GPC-BASIC/` — the examples

One `.EXP.BL` per topic. Several are also the regression test for the module they sit beside.

| | |
|---|---|
| `LOOPS.EXP.BL` | `GP.DO` / `GP.LOOP` / `GP.EXITDO` |
| `IF.EXP.BL` | `GP.IF` / `GP.ELSEIF` / `GP.ELSE` / `GP.ENDIF` |
| `SELECT.EXP.BL` | `GP.SELECT` / `GP.CASE` / `GP.OTHER` / `GP.ENDSEL` |
| `UNWIND.EXP.BL` | a `GOTO` may leave a `GP.SELECT` or a `GP.DO` |
| `STRINGS.EXP.BL` | the GP.BASIC string set |
| `ARRAYS.EXP.BL` | the GP.BASIC array set |
| `SCREEN.EXP.BL` | the GP.BASIC text drawing set |
| `ISO.EXP.BL` | `GP.PRINTAT` and `GP.BOX` in ISO mode |
| `MLCALL.EXP.BL` | `GP.CALL` with `GP.A` / `GP.X` / `GP.Y` / `GP.C` |
| `ASM.EXP.BL` | `GP.ASM` / `GP.ENDASM`, inline 65C02 |
| `MENU.EXP.BL` | a whole small application, in the shape the GP set is for |
| `MENUDEMO.EXP.BL` | `MENUVERT` drawn the way an application would draw it |
| `GUI.EXP.BL` | the four dialogs, over a screen they have to put back |
| `FORM.EXP.BL` | three fields you can move between, `LINEINPUT` style |
| `BMXVIEW.EXP.BL` | a BMX bitmap viewer, in about thirty lines |
| `BMXPAL.EXP.BL` `BMXSPD.EXP.BL` | the palette question, and the speed of each path |
| `SORT.EXP.BL` `STRCTST.EXP.BL` `SPLITT.EXP.BL` | the regression tests for `SORT`, `STRCASE` and `STR.SPLIT` |
| `MENUTST.EXP.BL` `GUI2TST.EXP.BL` | the same for the menu and the listbox, driven through the keyboard buffer |

---


## 6. The documents

#### 6. The documents

| | |
|---|---|
| `GP-BASIC.md` | the manual — the keyword reference and the module reference |
| `GP-BASIC.GLOBALS.md` | every global name each module owns, and the prefixes you may not use |
| `GP-BASIC.FILES.md` | this page |
| `README.md` | how to run the compiler, and what its answers mean |
| `SRC/` | the BASLOAD source of the tools. Reference only — nothing in it is needed to run |

The library's documents live beside the includes they describe, in this folder, so a relative link
works both in the repository and in an unzipped release.

---

# GP.* CORE KEYWORDS

## 3. Command reference

#### 3. Command reference

30 tokens, `$CE7F` down to `$CE58`, allocated downward. Ten of the forty slots are holes, and they
stay holes: the token values are the ABI and are never renumbered.

##### At a glance — where each part comes from

Three implementations, and what each costs:

- **ASM** — a keyword run by machine code in the runtime. Costs runtime bytes, and one GP keyword
  anywhere in a program pays for the whole 1,024-byte block. Documented in §3.
- **BASIC** — a `.INC.BL` module of ordinary BASL, called with `GOSUB`. Costs nothing unless
  `#INCLUDE`d, and then only its own p-code. Documented in §4.
- **COMPOSITE** — a keyword with no machine code of its own; the compiler expands it into keywords
  that already exist. Costs the runtime nothing. Documented in §3 with the ASM keywords.

| | | |
|---|---|---|
| **Loops** | ASM | `GP.DO` `GP.LOOP` `GP.EXITDO` |
| **Multi-way branch** | ASM | `GP.SELECT` `GP.CASE` `GP.OTHER` `GP.ENDSEL` |
| **Block IF** | ASM | `GP.IF` `GP.ELSEIF` `GP.ELSE` `GP.ENDIF` — see §3.8 |
| **Machine code** | ASM | `GP.CALL` `GP.A` `GP.X` `GP.Y` `GP.C` |
| **Inline assembly** | COMPOSITE | `GP.ASM` `GP.ENDASM` — free, and stays GP-BASIC OUT, see §3.9 |
| **Strings** | ASM | `GP.INSTR` `GP.STRPTR` `GP.COMP` |
| **Strings** | COMPOSITE | `GP.CONTAINS` `GP.ISEMPTY` — free, see §3.4 |
| **Addresses** | COMPOSITE | `GP.HIBYTE` `GP.LOBYTE` — free, see §3.3 |
| **Arrays** | ASM | `GP.ARRPTR` |
| **Screen** | ASM | `GP.BOX` `GP.FILL` `GP.PRINTAT` |
| **Screen** | COMPOSITE | `GP.CHAR` — free, one cell in `GP.PRINTAT`'s shape running `GP.FILL`'s handler |
| **Colour roles** | BASIC | `THEME.INC.BL` — `THEME.LOAD`, `THEME.CLR()` · §4.1 |
| **String helpers** | BASIC | `STRINGS.INC.BL` — `PADR` `PADL` `PADC` `SPLIT` `REPLACE` `PET2SCR` · §4.2 |
| **Screen etiquette, panels** | BASIC | `APPSYS.INC.BL` — `STARTUP` `RESTORE` `PANEL.SAVE/LOAD/PUT` · §4.3 |
| **Entry fields** | BASIC | `LINEINPUT.INC.BL` — `LINEINPUT.GET`, `LINEINPUT.ASK` · §4.4 |
| **Bitmaps** | BASIC | `BMX.INC.BL` — `BMX.SHOW`, `BMX.RESTORE` · §4.5 |
| **Menus** | BASIC | `MENUVERT.INC.BL` — `RUN` `DRAW` `ROW` `HOTFIND` · §4.6 |

The rule is in §1: assembly for tight loops and bulk data moves, BASIC for everything else, and a
composite for anything that is only a spelling of keywords already present. A menu waits on a human,
so `MENUVERT` is BASIC; as a keyword it would cost every GP program 462 bytes whether or not it used
a menu.

---

The keywords in detail. Square brackets mean optional. Optionals cannot be skipped over:
`GP.BOX X,Y,W,H,,7` is a syntax error — write out the default you are passing through.


*See also: 4. Module reference -- the BASL library, 3.8 Block IF, 3.9 Inline assembly, 3.4 Strings, 3.3 Machine code, 4.1 THEME.INC.BL -- named colour roles, 4.2 STRINGS.INC.BL -- string helpers, 4.3 APPSYS.INC.BL -- start politely, leave it as you found it, 4.4 LINEINPUT.INC.BL -- a positioned entry field, 4.5 BMX.INC.BL -- a BMX bitmap into VERA, 4.6 MENUVERT.INC.BL -- a vertical menu, 1. What GP.BASIC is*

## 3.1 Loops

##### 3.1 Loops

```
GP.DO [count]
    ...
GP.LOOP
```

Counted loop, modelled on prog8's `repeat`. A count of 0, or no count, loops forever. Loops nest.

```
GP.EXITDO
```

Leaves the innermost `GP.DO`, closing its stack frame. A `GOTO` out of a `GP.DO` closes its frames
too — see §3.2 — but `GP.EXITDO` is two bytes and needs no branch target.

```basic
GP.DO
  TICK = TICK + 1
  IF TICK = 9 THEN GP.EXITDO
GP.LOOP
```

Example: [`LOOPS.EXP.BL`](LOOPS.EXP.BL)

---


*See also: 3.2 Multi-way branch*

## 3.2 Multi-way branch

##### 3.2 Multi-way branch

```
GP.SELECT <var>
GP.CASE <expr> [,<expr> ...]
    ...
GP.OTHER
    ...
GP.ENDSEL
```

The selector must be a plain numeric variable. It is re-read at each `GP.CASE`, the tests run in
the order written, and the first match wins. `GP.OTHER` is optional; if nothing matches and there is
no `GP.OTHER` the select is skipped, which is not an error.

An expression, a constant or an array element is refused at compile time. Assign to a scalar first:
`T = RND(1)*3 : GP.SELECT T`. A scalar is a fixed slot, so the re-read yields the same value every
time. The restriction is what lets the construct compile to core opcodes only — a program whose one
GP keyword is a select does not carry the GP block, as with `GP.IF`.

Case values are numeric expressions, not only constants. prog8's `when` requires compile-time
integers.

`GP.ENDSEL` is required. Nothing needs cleaning up; the requirement is structural. The compiler has
no symbol table, the emitted tokens are the block, and every case branch resolves by scanning
forward to it.

A case body may take its statements on the same line, after a colon:

```basic
GP.SELECT ED.KEY
  GP.CASE 157 : GOSUB ED.MOVE.LEFT
  GP.CASE 29  : GOSUB ED.MOVE.RIGHT
  GP.CASE 27  : MENU.ACTIVE = 0 : GOSUB ED.OPEN.MENUBAR
  GP.OTHER    : GOSUB ED.KEY.RANGE
GP.ENDSEL
```

More than one statement after the colon is allowed, and so is `GP.OTHER`. The body may also go on
the following lines. Both forms compile to the same code.

`GOTO` out of a select is safe: a select holds nothing open. `GP.DO` is the one block that opens a
stack frame, and a `GOTO` leaving one is handled — the compiler emits an `.unwind` before it and
`FixBranches` fills in how many loop frames it closes. No runtime bytes; two p-code bytes at the
`GOTO`. The case it cannot handle is a `GOTO` from inside one `GP.DO` into another at the same
depth: the depth difference is zero, nothing is closed, and the frame survives.

`GP.SELECT` does not replace `ON x GOTO/GOSUB`, which is a jump table and remains correct for a
dense `1..n` index. Use `GP.SELECT` for a sparse selector — key codes, state machines, bit depths —
where `ON` does not apply.

```basic
GP.SELECT BMX.DEPTH
    GP.CASE 8
    GP.CASE 1, 2, 4
        BMX.ERROR$ = "NEEDS ANOTHER SCREEN MODE"
    GP.OTHER
        BMX.ERROR$ = "BAD BIT DEPTH"
GP.ENDSEL
```

An empty case body, `8` above, matches and falls out of the select. It is the cheapest way to say
that a value is acceptable.

Example: [`SELECT.EXP.BL`](SELECT.EXP.BL)

---


## 3.3 Machine code

##### 3.3 Machine code

```
GP.CALL address [,a] [,x] [,y] [,carry]
GP.A   GP.X   GP.Y   GP.C
```

Calls machine code with the registers set. All four arguments are optional and default to 0. The
four value words read the registers back afterwards.

They are keywords, not variables: `X = GP.A` reads, `GP.A = 5` is a syntax error. They share `SYS`'s
`$030C`–`$030F`, so they also read what a plain `SYS` left behind.

```basic
GP.CALL $FF5F, 0, 0, 0, 1          ' KERNAL screen_mode, carry set = report
COLS = GP.X : ROWS = GP.Y
```

Put machine code in banked RAM, `$A000`–`$BFFF`, not at `$0400`. Stock X16 BASIC leaves `$0400`
free for the user; a compiled GPC program does not. That page holds runtime state
(`stringHighMemory`, `storeStartHigh`, `variableStartPage`), and code POKEd over it corrupts the
program without raising an error.

###### Splitting an address — `GP.HIBYTE` / `GP.LOBYTE`

| Form | Does |
|---|---|
| `GP.HIBYTE(n)` | `INT(n / 256)` — which 256-byte page. **Composite** |
| `GP.LOBYTE(n)` | `MOD(n, 256)` — the offset within it. **Composite** |

A 6502 address is sixteen bits and everything that consumes one takes eight bits at a time:
`GP.CALL`'s registers, VERA's `$9F20`/`$9F21`. Every address passed from BASIC to machine code is
therefore split. `GP.STRPTR` and `GP.ARRPTR` produce the addresses to pass:

```basic
P = GP.STRPTR(A$)
GP.CALL $A000, GP.LOBYTE(P), GP.HIBYTE(P)
```

Do not write `P AND 255` for the low byte. `AND` is 16-bit signed in GPC, and any address worth
splitting is above 32,767 (the string heap always is), so it raises `OUT OF RANGE` rather than
masking. `GP.LOBYTE` is built on `MOD`, which uses the full 32-bit divide.

Range is 0–65,535, which covers every address on the machine. Both are composite: no runtime code,
compiling to `INT(n/256)` and `MOD(n,256)`.

Example: [`MLCALL.EXP.BL`](MLCALL.EXP.BL)

For anything longer than a few bytes use `GP.ASM` (§3.9) instead of `GP.CALL` and a POKE loop. It
assembles into the program: no bank to reserve, and no list of numbers to keep in step with a
comment.

---


*See also: 3.9 Inline assembly*

## 3.4 Strings

##### 3.4 Strings

| Form | Does |
|---|---|
| `GP.INSTR(hay$, needle$ [,start])` | position of `needle$`, 1-based; **0 = not found**. `start` is where to begin |
| `GP.CONTAINS(hay$, needle$)` | −1 if `needle$` occurs anywhere in `hay$`, 0 if not. **Composite** — see below |
| `GP.ISEMPTY(a$)` | −1 if `a$` has zero length, 0 if not. **Composite** |
| `GP.COMP(a$, b$)` | compare **ignoring case**: −1 before, 0 same, 1 after |
| `GP.STRPTR(a$)` | address of the string's `[ActLen][Data]` block |

Trimming and case folding are in `STRCASE.INC.BL` (§4.8) rather than keywords: they would take 188
bytes of the all-or-nothing GP block to serve one caller in the tree outside their own example.
`GP.STRPTR` is a keyword because the module is built on it.

`GP.INSTR` is the only string search GPC has; without it there is none.

`GP.CONTAINS` answers the same question without the position: `IF GP.CONTAINS(F$, ".BAS")`. It is
case sensitive, comparing raw bytes as `GP.INSTR` does; use `GP.COMP` for a case-blind test. An
empty needle returns 0, not −1, because `GP.INSTR` reports not-found for one.

`GP.CONTAINS` is composite. The compiler expands it to `GP.INSTR(hay$, needle$) <> 0`, and the
object is byte-for-byte identical to writing that out (verified by compiling both). Use whichever
spelling reads better; there is no size difference.

`GP.ISEMPTY(a$)` is `LEN(a$) = 0`. A string of spaces is not empty — apply `STRCASE.TRIM` first if
that is the intent. It compiles to the same four bytes as `LEN(a$)=0`, and `IF a$=""` costs about
the same (a literal points into the p-code, so the empty string allocates nothing). The three
spellings do not differ in size.

`GP.COMP` provides a case-blind equality test, `IF GP.COMP(A$,B$) = 0`, which `=` cannot do, and an
ordering comparator. Length breaks a tie: `"abc"` sorts before `"ABCD"`.

The in-place statements take a string variable, never a literal or an expression; the compiler
rejects those. Case conversion leaves digits, punctuation and PETSCII graphics unchanged.

There is no `GP.PAD`. Padding grows a string, and an in-place handler receives the string block and
not the variable slot, so it cannot reallocate beyond the capacity the string was created with. Use
`STR.PADR` / `PADL` / `PADC` (§4.2), which are BASIC assignments and do reallocate.

###### `GP.STRPTR` and the address-splitting trap

The address is that of `[ActLen][Data]`: the length byte is at the address, the first character at
+1, and the block capacity at −2. With `GP.CALL`, machine code can fill a BASIC string in place and
set its length, which stock BASIC cannot do.

Split the address with `GP.LOBYTE` / `GP.HIBYTE`, not with `P AND 255`:

```basic
GP.CALL $A000, GP.LOBYTE(P), GP.HIBYTE(P)
```

`AND` is 16-bit signed and the string heap is above 32,767, so `P AND 255` raises `OUT OF RANGE`.
The longhand `H = INT(P / 256) : L = P - H * 256` is correct and is what the keywords compile to.
The same applies to `GP.ARRPTR` and to any VRAM address in the top eighth of memory.

Example: [`STRINGS.EXP.BL`](STRINGS.EXP.BL)

---


*See also: 4.8 STRCASE.INC.BL -- case and trim, in place, 4.2 STRINGS.INC.BL -- string helpers, 4.8 STRCASE.INC.BL -- case and trim, in place*

## 3.5 Arrays

##### 3.5 Arrays

```
GP.ARRPTR(a())
```

Sorting is `SORT.INC.BL` (§4.7) rather than a keyword: 408 bytes of the all-or-nothing GP block,
carried by every program whether or not it sorts. `GP.ARRPTR` is a keyword because the module needs
it — a BASL subroutine cannot be passed an array, so an address is the only interface.

`GP.ARRPTR` returns the address of element zero; the header is already skipped. Machine code called
through `GP.CALL` can then work on the array in bulk. Add the stride yourself: 2 bytes per element
for a string array (each element is a pointer to the string block — see `GP.STRPTR` for its layout),
6 for a numeric array. Multi-dimensional arrays are rejected, and `GP.ARRPTR(A(3))` is a syntax
error; write `3*2` or `3*6` into the address.

Example: [`ARRAYS.EXP.BL`](ARRAYS.EXP.BL)

---


*See also: 4.7 SORT.INC.BL -- shell sort a string array, 4.7 SORT.INC.BL -- shell sort a string array*

## 3.6 Screen -- stash and restore

##### 3.6 Screen — stash and restore

Stashing a rectangle is `STASH.INC.BL`, written in `GP.ASM`, rather than a keyword. It writes a
4-byte self-describing header and holds at most 4,094 cells: a bank is 8K and a cell is two bytes,
so a full 80x60 screen at 9,600 bytes does not fit. As keywords it would take 329 bytes of the
all-or-nothing GP block in every program, stashing or not.

```
#SYMFILE "@:MYPROG.SYM"
#INCLUDE "STASH.INC.BL"
STASH.BANK = 8 : STASH.X = 10 : STASH.Y = 4 : STASH.W = 30 : STASH.H = 8
GOSUB STASH.SAVE
...
GOSUB STASH.RESTORE
```

`STASHFILE.INC.BL` is the same rectangle through a file. It is a separate module because BASL has
no dead code elimination: everything a module holds is compiled into every program that includes it,
called or not.

---


*See also: STASH.INC.BL -- save a text rectangle, and put it back., STASHFILE.INC.BL -- a saved text rectangle, through a file.*

## 3.7 Screen -- drawing

##### 3.7 Screen — drawing

```
GP.BOX x, y, w, h [,style] [,col]
GP.FILL x, y, w, h, char [,col]
GP.PRINTAT x, y, text$ [,col]
```

All three write directly to VERA and call no KERNAL routine, which is why they are several times
faster than `PRINT`. GPC's character output makes two KERNAL calls per character, and `BSOUT`
carries scroll, quote mode and cursor handling.

`GP.BOX` draws the frame only. Styles: 0 solid, 1 dither, 2 single line, 3 rounded, 4 thick, 5 thick
shaded. `char` in `GP.FILL` is PETSCII, e.g. `ASC(" ")`.

The colour argument is optional. Omitted, it uses whatever `COLOR` last set, read from the KERNAL's
`$0376` — the colour a `PRINT` would have used. Supplied, it is one byte packed as the X16 packs it:
`background * 16 + foreground`. 255 is a real colour (light grey on light grey), not a
leave-unchanged marker.

These calls do not move the cursor `PRINT` uses. A `PRINT` after a `GP.PRINTAT` continues from
wherever the KERNAL's cursor was, not after the text just drawn. Use `LOCATE` first, or stay in one
world or the other.

Nothing is clipped. Drawing off the right edge wraps to the next row; off the bottom writes past the
end of the screen map. Zero width or height draws nothing, which is what a computed size reaches
when it collapses.

###### ISO mode is handled for you

In ISO mode — `PRINT CHR$(15)`, or Ctrl+O — the VERA tile index is the character code, so
translating PETSCII to a screen code is wrong rather than merely wasteful: `A` would be written as
`$01`. `GP.PRINTAT` reads the KERNAL's ISO flag (bit 6 of `$0372`) per character and skips the
translation when it is set. A program that switches charset needs no source change and nothing to
declare. The test costs 7 cycles a cell in PETSCII mode and saves 34 in ISO.

`GP.FILL` needs no test: it converts its single character before the loop, and `$20` is a fixed
point of the translation, so a space fill — padding and blanking — is correct in both modes.

`GP.BOX` is the one case that needs the caller to act. It does no translation at all; its glyphs go
to VERA as tile indices, so the four built-in styles are PETSCII screen codes and appear as letters
in ISO mode. Translation cannot fix this, because ISO-8859-15 has no box-drawing characters to
translate to. A style value of 256 or more is instead the address of eight glyphs, and in ISO mode a
tile index is a character code, so ASCII `+ - |` make a usable frame:

```
ISO.GLYPH$ = "++++--||"                        ' TR TL BR BL TOP BOTTOM LEFT RIGHT
GP.BOX 50, 26, 4, 3, GP.STRPTR(ISO.GLYPH$) + 1, 1
```

`GP.STRPTR` returns the address of the string block and the text starts at +1, so a string literal
is the cheapest way to carry the eight bytes. This costs no runtime bytes; the pointer form already
exists, and `samples/editor` uses the same mechanism to draw frames from a re-ordered font.

`ISO.EXP.BL` tests all of this, reading cells back with `VPEEK` rather than trusting the display.
The ISO box corner, top edge and side read back as 43, 45 and 124.

Example: [`SCREEN.EXP.BL`](SCREEN.EXP.BL)


---


## 3.8 Block IF

##### 3.8 Block IF

```
GP.IF <expr> THEN
    ...
GP.ELSEIF <expr> THEN
    ...
GP.ELSE
    ...
GP.ENDIF
```

Each of the four keywords is alone on its line, and `THEN` is required. There is no one-line form:
`GP.IF X > 5 THEN PRINT` is a syntax error. Allowing it would mean a block that swallowed every line
down to the next `GP.ENDIF`. Stock `IF ... THEN` is unchanged and remains the one-line form.

`GP.ELSEIF` may repeat any number of times; `GP.ELSE` is optional. The first true condition wins and
nothing below it runs, so there is no break to omit. If nothing matches and there is no `GP.ELSE`
the block is skipped, which is not an error. Conditions are numeric expressions.

`GP.IF` and `GP.SELECT` cover different cases. A select fetches one value and compares it against
each alternative — a sparse key code, a state machine. A block IF tests a different condition in
every branch: ranges, compound conditions, a string in one arm and a number in the next.

`GP.ENDIF` is required, but unlike `GP.ENDSEL` it does no work: the condition is evaluated and
consumed on the line it is written, so there is no frame to release and a `GOTO` out of a `GP.IF` is
safe. Omitting `GP.ENDIF` stops the compile with `STRUCTURE IMBALANCE`.

```basic
GP.IF N < 0 THEN
    PRINT "NEGATIVE"
GP.ELSEIF N = 0 THEN
    PRINT "ZERO"
GP.ELSE
    PRINT "POSITIVE"
GP.ENDIF
```

IFs nest freely — inside each other, inside a `GP.CASE` body, and inside a `GP.DO` loop.

It costs 14 runtime bytes, none of them code. All four p-code opcodes reuse existing handlers: the
two branches are `.goto.z` and `.goto` under different names, and the two markers share one four-byte
no-op. See §11 of `docs/blitz/GP-BASIC.TIERS.md`.

Example: [`IF.EXP.BL`](IF.EXP.BL)

---


## 3.9 Inline assembly

##### 3.9 Inline assembly

```
GP.ASM
REM <instruction>
...
GP.ENDASM
```

65C02 assembly, assembled by GPC at compile time, with the bytes placed in the program.

The alternative is to assemble by hand: work out the opcode for each instruction, `POKE` the numbers
into memory nothing else is using, and point `GP.CALL` at that address. These two do the same thing
— increment A, then X, then Y:

```basic
#### by hand: 26, 232 and 200 ARE inc a / inx / iny, and ML has to be somewhere safe
POKE ML+0,26 : POKE ML+1,232 : POKE ML+2,200 : GP.CALL ML,10,20,30
```
```basic
#### assembled: the bytes land in the program, and there is no address to find
GP.ASM
REM inc a
REM inx
REM iny
GP.ENDASM
```

It costs no runtime bytes. A block is five bytes of p-code plus the assembled instructions, and
every handler it uses is already in every compiled program. A program whose only GP.BASIC keyword is
`GP.ASM` compiles GP-BASIC OUT, without the 1 KB block: measured `RT 12031`, the same as a program
using no GP keyword.

###### `#REM 1` is required

The body rides in REM statements because BASLOAD stores REM text byte for byte. Outside a REM,
`ORA`, `AND`, `EOR` and `ROR` are BASIC keywords and the text is destroyed; inside one it arrives
intact, braces included. Lower case is accepted and upshifted.

`#REM 0` is BASLOAD's default and strips the body before the compiler runs. `GP.ASM` and
`GP.ENDASM` are real keywords rather than REMs so that the block is still found, empty, and GPC
reports `BLOCK MISMATCH` rather than compiling a program that contains no code. Set `#REM 0` again
after `GP.ENDASM`.

###### Labels and branches

A label is `name:`, alone on a line or in front of an instruction; six characters are significant.
Labels belong to their block — the same name in two blocks is two different labels, and neither can
branch to the other.

```basic
GP.ASM
REM ldx #5
REM loop: lda #42
REM jsr $ffd2
REM dex
REM bne loop
GP.ENDASM
```

`BNE`, `BEQ`, `BRA` and the rest take a label, as do `JMP` and `JSR`. A branch further than 127
bytes is `OUT OF RANGE` at compile time, reported on its own line, rather than a wrong address at
run time.

###### `{VAR}` — a BASIC variable's slot

`{VAR}` is the address of the variable's slot, so reading and writing use the same form: `LDA {N%}`
reads it, `STA {N%}` writes it, in the slot BASIC itself uses.

| Form | Is |
|---|---|
| `{N}` `{N%}` `{N$}` | the scalar's slot |
| `{N()}` | the **array's** slot, which holds the base address of its data — an element is two steps, as through `GP.ARRPTR` |

A name is letters, digits and dots, starting with a letter, up to 64 characters — the same limit as
BASLOAD. `{DOC.GOT.OFF}` works, so the dotted names used throughout the library are reachable from
assembly. Underscore is not accepted: BASLOAD allows it in a name, this does not, and `{A_B}` reads
the name as `A`.

`{VAR}` requires `#SYMFILE`. BASLOAD renames variables — `N%` becomes `A%`, which is how it provides
64 significant characters on a two-character BASIC — and it does not rename REM text with them, so
the code says `A%` while the REM still says `{N%}`. `#SYMFILE` is BASLOAD's record of that mapping
and the compiler reads it:

```
#SYMFILE "@:PROG.SYM"
```

Put it at the top of the source, named to match the PRG: compiling `PROG.PRG` reads `PROG.SYM`.
Nothing else changes — `{N%}` is still written with the name as authored.

Two compile-time errors, both naming the line:

| | means |
|---|---|
| `NO SYMBOL FILE FOR {}` | no `#SYMFILE`, or it is not beside the PRG under the matching name |
| `UNKNOWN VARIABLE IN {}` | the name is not a variable of this program |

`{VAR}` never creates a variable, unlike an ordinary BASIC reference. Assign the variable once in
BASIC first, even `M% = 0`. A name that does not exist otherwise resolves to a slot BASIC never
reads, and the block runs, stores, and changes nothing observable.

###### What is not there

No expressions: `{N%}+1` and `LABEL+2` are not understood. Use an index register.

Zero page or absolute is decided by the operand. `$34` is zero page, `$0034` is absolute, and a
decimal under 256 is zero page. Every 65C02 addressing mode is available, including the two the NMOS
6502 lacks — `LDA ($34)` and `JMP ($1234,X)` — except `BBR`, `BBS`, `RMB` and `SMB`.

Registers come back through `GP.A` / `GP.X` / `GP.Y` / `GP.C` as they do from `GP.CALL`; a block
uses the same `$030C`–`$030F` slots. Those four are GP block keywords, so reading one pulls in the
1 KB block that `GP.ASM` alone avoids. `{VAR}` does not.

A body can come from a file. `#INCLUDE` splices it in verbatim, and BASLOAD's `REM #nn-mm`
attribution makes an error inside it name the file:

```basic
#REM 1
GP.ASM
#INCLUDE "MACPTR.ASM"
GP.ENDASM
#REM 0
```

Example: [`ASM.EXP.BL`](ASM.EXP.BL)

---


## 3.9 Inline assembly (2)


---

# BASL MODULES

## 4. Module reference -- the BASL library

#### 4. Module reference — the BASL library

Called with `GOSUB`. Arguments go into named variables before the call, results come back in named
variables after it. Every module is position-independent — each jumps over itself — so `#INCLUDE` it
anywhere, including the top of the program.


## 4.1 THEME.INC.BL -- named colour roles

##### 4.1 `THEME.INC.BL` — named colour roles

| Routine | in | out |
|---|---|---|
| `THEME.LOAD` | `THEME.DARK` (0 light, non-zero dark) | fills `THEME.CLR()` |
| `THEME.SET` | `THEME.ATTR` | issues `COLOR` — makes it the colour `PRINT` uses |
| `THEME.HI` | `THEME.ATTR` | `THEME.INV`, the inverse attribute |

Roles, for indexing `THEME.CLR()`: `THEME.PAGE` `THEME.TEXT` `THEME.TITLE` `THEME.BORDER`
`THEME.HILITE` `THEME.DIMMED` `THEME.WARN`, and `THEME.SLOTS` = 7.

```basic
THEME.DARK = 1 : GOSUB THEME.LOAD
GP.BOX 4,2,30,8, 2, THEME.CLR(THEME.BORDER)
GP.PRINTAT 6,3, "TITLE", THEME.CLR(THEME.TITLE)
```

The values are packed attributes, `background * 16 + foreground`, which is what `GP.BOX`, `GP.FILL`
and `GP.PRINTAT` take. For `COLOR`, which takes the halves separately, use `THEME.SET`.

`#DEFINE` substitutes at translation time, so `THEME.CLR(THEME.TITLE)` compiles to `THEME.CLR(2)`.
The readable name costs no variable and no lookup.

`THEME.CLR` is `DIM`med by the module. Do not `DIM` it in your own program.


*See also: 4.1 THEME.INC.BL -- named colour roles*

## 4.2 STRINGS.INC.BL -- string helpers

##### 4.2 `STRINGS.INC.BL` — string helpers

| Routine | in | out |
|---|---|---|
| `STR.PADR` | `STR.STR$` `STR.WIDTH` | `STR.STR$` left-justified |
| `STR.PADL` | same | right-justified |
| `STR.PADC` | same | centred (odd gap goes right) |
| `STR.SPLIT` | `STR.STR$` `STR.DELIM$` `STR.MAX` | `STR.N`, `STR.FIELD$(1..N)` |
| `STR.REPLACE` | `STR.STR$` `STR.FIND$` `STR.REPL$` | `STR.STR$`, every occurrence replaced |
| `STR.PET2SCR` | `STR.PET` | `STR.SCR` |

The three pad routines leave a string that is already at or past the width unchanged. They pad and
never truncate; use `STRCASE.RTRIM` (§4.8) to shorten.

`SPLIT` reads `STR.STR$` without modifying it. `STR.MAX` of 0 means 10. Empty fields are preserved:
`"A,,C"` is three fields and `"A,"` is two. Splitting an empty string gives one empty field, never
zero. Reaching the limit is not an error and loses nothing — the last field receives the unsplit
remainder, delimiters included.

`STR.FIELD$` is the one array the library does not `DIM`. Left alone, GPC's implicit `DIM` gives
0..10. For more, `DIM` it before the first call and set `STR.MAX` to match. `DIM`ming an array GPC
has already auto-dimensioned is an error, so it is one or the other. Note that this is the reverse
of `THEME.CLR`, which the module `DIM`s.

`REPLACE` swaps every occurrence of `STR.FIND$` for `STR.REPL$`, modifying `STR.STR$` in place. The
replacement may be shorter, longer, or `""` to delete. It is case sensitive, because `GP.INSTR`
compares raw bytes.

A replacement that contains the search text is safe: `"A"` to `"AA"` terminates and doubles the As,
where a naive in-place version would not. The routine builds a new string and never re-scans what it
has emitted. An empty `STR.FIND$` leaves the string unchanged rather than hanging, because
`GP.INSTR` reports not-found for a zero-length needle. Like the pad routines it is not length
checked: a longer replacement can push the result past 255 characters.

`PET2SCR` converts a PETSCII code to the screen code the tile map holds, for `TILE`, `TDATA` and
`VPOKE`. `GP.PRINTAT` and `GP.FILL` do this internally.

Examples: [`SPLITT.EXP.BL`](SPLITT.EXP.BL)


*See also: 4.8 STRCASE.INC.BL -- case and trim, in place, 4.2 STRINGS.INC.BL -- string helpers*

## 4.3 APPSYS.INC.BL -- start politely, leave it as you found it

##### 4.3 `APPSYS.INC.BL` — start politely, leave it as you found it

| Routine | in | out |
|---|---|---|
| `APPSYS.STARTUP` | — | `APPSYS.MODE` `APPSYS.COLS` `APPSYS.ROWS` `APPSYS.COLOUR` |
| `APPSYS.RESTORE` | those | screen mode and colour put back |
| `APPSYS.PANEL.SAVE` | `APPSYS.FILE$` `.BANK` `.X` `.Y` `.W` `.H` [`.DEV`] | a file |
| `APPSYS.PANEL.LOAD` | `APPSYS.FILE$` `.BANK` | back where it came from |
| `APPSYS.PANEL.PUT` | `APPSYS.FILE$` `.BANK` `.X` `.Y` | pasted somewhere else |

```basic
GOSUB APPSYS.STARTUP
' ... the application, laid out with APPSYS.COLS / APPSYS.ROWS ...
GOSUB APPSYS.RESTORE : END
```

Call `STARTUP` before any `SCREEN` or `COLOR` of your own. It records the state as it finds it, so
anything changed beforehand is what gets restored.

Lay out from `APPSYS.COLS` / `APPSYS.ROWS` rather than assuming 80x60. The X16 boots 80x60, but
`SCREEN 0` is 40x30 and a user who prefers larger text is running one.

`APPSYS.DEV` defaults to 8. The panel routines are implemented in `STASHFILE.INC.BL`. A panel file
is self-describing — it carries the stash's 4-byte header — so loading one needs only its name.


*See also: 4.3 APPSYS.INC.BL -- start politely, leave it as you found it, STASHFILE.INC.BL -- a saved text rectangle, through a file.*

## 4.4 LINEINPUT.INC.BL -- a positioned entry field

##### 4.4 `LINEINPUT.INC.BL` — a positioned entry field

| Routine | in | out |
|---|---|---|
| `LINEINPUT.GET` | `LINEINPUT.X` `.Y` `.LEN` `.ATTR` `.TEXT$` `.MASK` | `LINEINPUT.TEXT$` `LINEINPUT.KEY` |
| `LINEINPUT.ASK` | the same plus `LINEINPUT.LABEL$` | the same; `LINEINPUT.X` restored |

```basic
LINEINPUT.X = 10 : LINEINPUT.Y = 6
LINEINPUT.LEN = 20
LINEINPUT.ATTR = THEME.CLR(THEME.TEXT)
LINEINPUT.TEXT$ = ""
GOSUB LINEINPUT.GET
IF LINEINPUT.KEY = 27 THEN GOTO CANCELLED
```

`INPUT` and `LINPUT` cannot be used on a drawn screen: both take the bottom of the screen, scroll
it, echo in the current colour, and accept any length. A `LINEINPUT` field stays at the given
position, in the given colour, and stops at the given width.

`LINEINPUT.KEY` is the key that ended the field, which is what makes a multi-field form possible:

| | |
|---:|---|
| 13 | RETURN — finished |
| 27 / 3 | ESC / STOP — cancelled, and `LINEINPUT.TEXT$` is put back to what it was |
| 17 / 145 / 9 | cursor down / up / TAB — left the field, **text kept** |

A form is therefore a loop over fields rather than a sequence of prompts, and the user can return to
an earlier field without restarting.

`LINEINPUT.MASK` non-zero displays asterisks while holding the real string. The field does not
scroll: when it is full, further characters are refused and the cursor inverts the last character
rather than sitting past the end. The cursor blinks off `TI` rather than a delay loop; a delay loop
would swallow keys pressed during it.

Example: [`FORM.EXP.BL`](FORM.EXP.BL) — three fields, one masked, in a themed panel.


*See also: 4.4 LINEINPUT.INC.BL -- a positioned entry field*

## 4.5 BMX.INC.BL -- a BMX bitmap into VERA

##### 4.5 `BMX.INC.BL` — a BMX bitmap into VERA

| Routine | in | out |
|---|---|---|
| `BMX.OPEN` | `BMX.FILE$` | `BMX.ERROR$`, and the header — `BMX.WIDTH` `.HEIGHT` `.DEPTH` `.VERSION` `.PALUSED` `.PALFIRST` `.DATAOFF` `.PACKED` |
| `BMX.PAINT` | an open file | palette and pixels in VRAM, file closed |
| `BMX.SHOW` | `BMX.FILE$` | both of the above |
| `BMX.CLOSE` | — | abandons a file opened by `BMX.OPEN` |
| `BMX.RESTORE` | — | puts the machine's own palette back |

`BMX.ERROR$` empty means it worked.

```basic
BMX.FILE$ = "TITLE.BMX"
SCREEN 128
GOSUB BMX.SHOW
IF BMX.ERROR$ <> "" THEN PRINT BMX.ERROR$
```

Use the long form to read the size before committing to a screen mode, or to report a bad file
before the display is torn down:

```basic
BMX.FILE$ = F$
GOSUB BMX.OPEN
IF BMX.ERROR$ <> "" THEN GOTO COMPLAIN
' ... BMX.WIDTH, BMX.HEIGHT, BMX.PALUSED readable here ...
SCREEN 128
GOSUB BMX.PAINT
```

Set the screen mode before `BMX.PAINT`, not after. `SCREEN` reloads the default palette, so a mode
change after painting discards the image's colours: correct pixels, wrong palette.

`BMX.PAINT` writes the image's colours over the machine's palette, and nothing on the X16 restores
them — not `SCREEN`, not the KERNAL's `screen_mode`. `BMX.PAINT` therefore stashes all 256 entries
in spare VRAM first, and `BMX.RESTORE` writes them back:

```basic
BMX.FILE$ = "TITLE.BMX"
SCREEN 128
GOSUB BMX.SHOW
' ... the title screen ...
GOSUB BMX.RESTORE
```

A program that keeps the machine need never call it. A program that returns the machine to BASIC or
chains to another calls it once. It is safe to call at any time: with nothing stashed there is
nothing to do, so a program whose image failed to load can still call it on the way out. All 256
entries are kept, not the range the file claims, and they are kept once per run — so a slideshow
restores the machine's own palette rather than the previous image's.

`BMX.STASH` is the VRAM address they go to, `$13000` by default, which is free above the 320x240
framebuffer in the mode this module paints into. A caller using tiles, sprites or a second bitmap
there must move it or switch it off with `BMX.STASH = -1`. The address is checked: a stash inside the
bitmap or overlapping the PSG registers is reported and nothing is painted.

Use `-1` to switch it off, not `0`. Zero is what the variable holds before it is set, and `BMX.INIT`
runs at the first `BMX.OPEN`, after a caller would have set it, so `0` has to keep meaning unset.

The module handles 8 bits per pixel, uncompressed, which is what `SCREEN 128` displays without a
decompressor. Anything else is reported rather than attempted. The image is centred, and anything
larger than 320x240 is clipped.

Examples: [`BMXVIEW.EXP.BL`](BMXVIEW.EXP.BL), and [`BMXPAL.EXP.BL`](BMXPAL.EXP.BL) for the palette


*See also: 4.5 BMX.INC.BL -- a BMX bitmap into VERA*

## 4.6 MENUVERT.INC.BL -- a vertical menu

##### 4.6 `MENUVERT.INC.BL` — a vertical menu

| Routine | in | out |
|---|---|---|
| `MENUVERT.RUN` | the variables below | `MENUVERT.SEL` `MENUVERT.KEY` |
| `MENUVERT.DRAW` | the same | draws the menu without driving it |
| `MENUVERT.ROW` | `MENUVERT.DRAWROW` `MENUVERT.DRAWATTR` | one row, in the attribute you name |
| `MENUVERT.HOTFIND` | `MENUVERT.DRAWROW` `MENUVERT.DRAWTEXT$` | `MENUVERT.HOTAT` — where that row's hotkey letter sits, 1-based, or **0 for "do not tint"** |

The menu is BASIC rather than assembly, which keeps 462 bytes of code and 11 of storage out of the
block every GP program carries. Assembly would only be needed to move the highlight without knowing
the text underneath it, by swapping the cell's attribute nibbles instead of redrawing. A BASIC menu
owns the item array and can reprint the row.

The difference is not visible: a nibble swap is 59 cycles a cell, `GP.FILL` 31 and `GP.PRINTAT` 94,
so redrawing two rows costs about a millisecond against the swap's half, in a 16.7 ms frame.

| in | |
|---|---|
| `MENUVERT.X` `.Y` | top left of the **first row**, not of a frame — draw the border yourself with `GP.BOX`, so the menu owes nothing to one style of border |
| `MENUVERT.WIDTH` | cells wide. This is the width of the **highlight**, so it is the width of the menu whatever the text happens to do |
| `MENUVERT.COUNT` | how many rows |
| `MENUVERT.ITEM$()` | the rows, `1..COUNT` — **the caller owns the `DIM`**, see below |
| `MENUVERT.ATTR` | packed attribute, `background * 16 + foreground` |
| `MENUVERT.HIATTR` | the same for the highlighted row. **0 means invert `MENUVERT.ATTR`** |
| `MENUVERT.HOT$` | one character a row, `""` for none |
| `MENUVERT.HOTATTR` | paint the hotkey letter in this attribute. **0 is off, and off is the default** |
| `MENUVERT.FLAGS` | added together, below |
| `MENUVERT.SEL` | the row to start on; 0 starts at 1 |

| out | |
|---|---|
| `MENUVERT.SEL` | `1..COUNT`, or **0 if cancelled** |
| `MENUVERT.KEY` | the key that ended it — 13 chose, 27 cancelled, or the hotkey itself |

```basic
MENUVERT.X = 8 : MENUVERT.Y = 6
MENUVERT.WIDTH = 24 : MENUVERT.COUNT = 4
MENUVERT.ITEM$(1) = " NEW GAME"           ' ... and so on
MENUVERT.ATTR = THEME.CLR(THEME.TEXT)
MENUVERT.HIATTR = THEME.CLR(THEME.HILITE)
MENUVERT.HOT$ = "NLOQ"
GOSUB MENUVERT.RUN
IF MENUVERT.SEL = 0 THEN GOTO CANCELLED
```

| Key | |
|---|---|
| cursor up / down | move |
| RETURN | choose |
| ESC or STOP | cancel |
| a hotkey | chooses its row at once |

| flags, added together | |
|---:|---|
| 1 | **must select** — ESC does not cancel |
| 2 | **keep mark** — leave the chosen row highlighted on the way out |
| 4 | **no wrap** — stop at the ends instead of wrapping round |
| 8 | **gamepad** — drive it from the SNES pad in port 1 as well as the keyboard |

The constants `MENUVERT.MUSTSEL`, `.KEEPMARK`, `.NOWRAP` and `.GAMEPAD` are defined; add those
rather than the numbers.

A hotkey chooses its row rather than moving to it. `MENUVERT.HOT$` is one character per row in
order, matched without case. It may be shorter than `MENUVERT.COUNT`, in which case the later rows
have no hotkey.

`MENUVERT.HOTATTR` paints the hotkey letter in a second attribute. The letter is located in the
row's own text — the first case-insensitive match for that row's `MENUVERT.HOT$` character — so
nothing extra is passed in and `" START"` with hotkey `S` needs no markup. A row whose text does not
contain its hotkey is left untinted rather than reported; the hotkey still works. Only rows in the
normal attribute are tinted: on the selected row the highlight carries the meaning.

The caller owns the `DIM`. A module cannot be passed an array in BASIC, so it names one; `DIM`ming
it inside the module would fix a bound and then fail for a caller who wanted more rows. Leave
`MENUVERT.ITEM$` undimensioned and GPC's implicit `DIM` gives 0..10, a ten-row menu. `DIM` it
yourself for more. Do not do both.

###### The gamepad flag

With flag 8, up and down move the highlight and B or Start chooses. Cancel remains keyboard-only:
ESC and STOP have no unambiguous pad equivalent, and a must-select menu has no cancel.

It reads port 1, the physical pad, not port 0. Port 0 is the keyboard presented as a joystick, and
the menu reads the keyboard directly, so reading both would move the highlight twice for one cursor
key. Port 0 is also unreliable, reporting absent on roughly half of all reads (measured in
AlienAirlift: 2,060 negative against 2,057 valid over 14 seconds).

One step per press, no auto-repeat. The wait loop spins as fast as the CPU allows, so the pad is
edge-triggered and holding a direction moves once. A button still held from whatever opened the menu
is not read as a fresh
press either, so a menu cannot answer itself on the way in.

With no pad connected the flag changes nothing: the pad is read only when the keyboard is quiet,
and an absent pad reads as nothing held. In the emulator a real pad needs `-joy1`, which binds
physical hardware and does not map the keyboard.

Examples: [`MENUDEMO.EXP.BL`](MENUDEMO.EXP.BL) on its own, [`MENU.EXP.BL`](MENU.EXP.BL) inside a
whole small application, and [`MENUTST.EXP.BL`](MENUTST.EXP.BL) for the 21-case regression test.

---


## 4.6 MENUVERT.INC.BL -- a vertical menu (2)


*See also: 4.6 MENUVERT.INC.BL -- a vertical menu*

## 4.7 SORT.INC.BL -- shell sort a string array

##### 4.7 `SORT.INC.BL` — shell sort a string array

| Routine | in | out |
|---|---|---|
| `SORT.RUN` | `SORT.PTR` `SORT.DESCEND` `SORT.NOCASE` | `SORT.OK` `SORT.COUNT` |

```
#SYMFILE "@:MYPROG.SYM"
#INCLUDE "SORT.INC.BL"

SORT.PTR = GP.ARRPTR(NAME$())
SORT.DESCEND = 0 : SORT.NOCASE = 0
GOSUB SORT.RUN
```

Shell sort with Ciura's gap sequence — 132, 57, 23, 10, 4, 1 — moving the 2-byte element pointers
rather than string data. A swap costs the same whatever the strings are: no temporary, no copy, no
heap traffic.

The array is passed as an address because a BASL subroutine cannot be passed an array; `GP.ARRPTR`
is a keyword for this purpose. The empty parentheses in `GP.ARRPTR(A$())` are required — `A$` and
`A$()` are different variables.

`SORT.OK` is 0 if the sort was refused: more than 255 elements, so `DIM A$(254)` is the largest
accepted (`DIM A$(255)` is 256 elements), or an array whose elements are not strings. The element
count and the type are read from the array's own header, three bytes below what `GP.ARRPTR` returns,
so a wrong count cannot be passed in.

Never-assigned elements are empty strings, not garbage. A `DIM A$(20)` with five entries filled
sorts its fifteen empties to the front; a null pointer reads as `""`, as it does elsewhere in the
runtime.

`SORT.DESCEND` and `SORT.NOCASE` are ordinary variables rather than arguments, so they are sticky.
Set both on every call.

The program must have a `#SYMFILE`, placed before the `#INCLUDE`s. The assembly reaches BASIC's
variables through `{VAR}`, and BASLOAD crunches every name before the compiler sees it; without the
mapping the compile stops with `NO SYMBOL FILE FOR {}`.

Example: [`ARRAYS.EXP.BL`](ARRAYS.EXP.BL). Regression test: [`SORT.EXP.BL`](SORT.EXP.BL), eight
cases including a 200-element array — element 128 is where the doubled index stops fitting in a
byte. Every case checks content as well as order: a sort that reads the wrong element leaves the
array in order with a string duplicated.

---


*See also: 4.7 SORT.INC.BL -- shell sort a string array*

## 4.8 STRCASE.INC.BL -- case and trim, in place

##### 4.8 `STRCASE.INC.BL` — case and trim, in place

| Routine | in | out |
|---|---|---|
| `STRCASE.GO` | `STRCASE.PTR` `STRCASE.MODE` | *(the string itself)* |

```
#SYMFILE "@:MYPROG.SYM"
#INCLUDE "STRCASE.INC.BL"

STRCASE.PTR = GP.STRPTR(LINE$)
STRCASE.MODE = STRCASE.RTRIM
GOSUB STRCASE.GO
```

| mode | does |
|---|---|
| `STRCASE.UPPER` | a–z → A–Z, everything else untouched |
| `STRCASE.LOWER` | A–Z → a–z, everything else untouched |
| `STRCASE.TRIM` | spaces off **both** ends |
| `STRCASE.LTRIM` | spaces off the **leading** end |
| `STRCASE.RTRIM` | spaces off the **trailing** end |

One blob, with the mode tested once at entry rather than inside the loop, where the byte count is
the whole cost.

The argument is an address because a BASL subroutine cannot be passed a variable. Copying the
caller's string in and back out would be two allocations and two copies per call — the heap traffic
this module exists to avoid. `GP.STRPTR` gives the block and the assembly rewrites it in place.

Do not pass a literal. `GP.STRPTR("hello")` is the address of that text inside the p-code, so
upper-casing it edits the running program, and the edit persists the next time the line runs. The
equivalent keywords could not be misused this way, because the compiler required a string variable
at the call site; a `GOSUB` cannot enforce that.

`STRCASE.MODE` is sticky: an ordinary variable, not an argument, so a call that does not set it
repeats the last operation. Set both inputs every time, as with `SORT.DESCEND` and `STASH.MOVE`.

There is no pad routine here. Padding grows a string, and nothing working on the block alone can
grow one past the capacity it was created with. Use `STR.PADR` (§4.2).

Example: [`STRINGS.EXP.BL`](STRINGS.EXP.BL). Regression test:
[`STRCTST.EXP.BL`](STRCTST.EXP.BL), twenty cases — empty, all spaces, a single space, one character,
a single leading space (the boundary in the slide), 200 characters, and guard strings either side to
catch an off-by-one write into the neighbouring block.

---


*See also: 4.2 STRINGS.INC.BL -- string helpers, 4.8 STRCASE.INC.BL -- case and trim, in place*

## GUI.INC.BL -- four dialogs, in a box that puts the screen back.


*From the banner header of `GUI.INC.BL`.*

```

      GUI.SAY     something to say, and one way out
      GUI.YN      a question, and a Y or N answer
      GUI.MENU    a question, and a row chosen from a list
      GUI.TEXT    a question, and a line of typed text

  What they share is the BOX: measure it against the text, centre it, save
  what it covers, draw a frame, give the pixels back on the way out. That is
  GUI.OPEN and GUI.CLOSE, and the three entry points are thin. GUI.MENU is
  MENUVERT.RUN inside a frame and GUI.TEXT is LINEINPUT.GET inside one, so
  only GUI.YN -- four keys -- reads the keyboard itself.

  REQUIRES, and does not #INCLUDE for you, in this order:
      GPB.INC.BL        GP.BOX, GP.FILL, GP.PRINTAT, GP.CALL
      STASH.INC.BL      saves the cells the box covers -- and wants a
                        #SYMFILE in your program, see its own header
      THEME.INC.BL      the colour roles, and GOSUB THEME.LOAD first
      MENUVERT.INC.BL   drawn on by GUI.MENU
      LINEINPUT.INC.BL  drawn on by GUI.TEXT

  BOTH ARE REQUIRED EVEN IF YOU ONLY CALL GUI.YN. BASLOAD resolves every
  label in the file, not the ones a path reaches, so leaving either out
  stops the tokenise with LABEL NOT FOUND rather than compiling a smaller

  Usage, the whole of it:
      THEME.DARK = 0 : GOSUB THEME.LOAD
      GUI.BANK = 8
      GUI.MSG$ = "Delete the file?"
      GOSUB GUI.YN
      IF GUI.ANSWER = 1 THEN <yes>

   in   GUI.MSG$        the question. "" for none
        GUI.MSG2$       a second line, for detail that does not fit. "" for
                        none, and then there is no gap
        GUI.TITLE$      a name in the top edge of the frame. "" for none
        GUI.BANK        a spare RAM bank to save the covered cells in.
                        0 MEANS DO NOT SAVE, and then the box is still on
                        the screen when the call returns
        GUI.STYLE       0, the default, draws the single line box. 1 to 5
                        are GP.BOX's other styles
        GUI.PANEL.IN    the panel: the box's background AND the colour the
                        message lines are written in. 0 takes THEME.TEXT
        GUI.BORDER.IN   the frame's attribute. 0 takes THEME.BORDER
        GUI.GLYPH       non-zero frames the box from six glyphs of the
                        CALLER'S, and GUI.STYLE is then not consulted.
                        They are TILE INDICES: GUI.FRAME hands them to
                        GP.BOX as a custom set, which does not convert
                            GUI.EDGE.H      the horizontal run
                            GUI.EDGE.V      the vertical run
                            GUI.CORNER.TL   .TR  .BL  .BR
        GUI.PLACE       0 centres the box. Non-zero uses GUI.X, GUI.Y
        GUI.X  GUI.Y    top left, when GUI.PLACE says so
        GUI.ROW.OFFSET  added to the row the box lands on, however it was
                        placed. 0 for almost everybody -- see below

   out  GUI.KEY         the key that ended it, whichever call
        GUI.LEFT GUI.TOP GUI.WIDTH GUI.HEIGHT   where the box went, and
                        how big it turned out

  GUI.ROW.OFFSET IS FOR HARDWARE SCROLLING. The GP commands address the text
  MAP, and VERA's L1_VSCROLL decides which map row shows as screen row 0. A
  caller scrolling that way sets GUI.ROW.OFFSET to VSCROLL/8 and is centred
  against what the user can see. Everyone else leaves it 0.

  UPPER CASE, ON THE DEFAULT CHARSET. GP.PRINTAT converts PETSCII and
  BASLOAD passes literals through as source bytes, so on charset 2 ASCII
  lower case lands on the graphics half of the font -- "Confirm" measured as
  tiles 3, 79, 78, 70, 73, 82, 77. ISO mode fixes the text and breaks the
  frame, GP.BOX's $40-$7D being letters in that order: so it is upper case
  with a frame, or mixed case without one, unless the caller re-orders the
  font and says where the glyphs went with GUI.GLYPH. That is what
  samples/editor does, and the whole reason the frame is overridable.

  A BOX OVER 4094 CELLS WILL NOT FIT ONE BANK, and that is not an error: the
  save is skipped, the dialog still runs, and GUI.STASHED comes back 0 so the
  caller knows it must repaint. Same when GUI.BANK is 0.

  .IN IS "WHAT THE CALLER ASKED FOR" -- GUI.PANEL and GUI.BORDER are what
  GUI.OPEN settled on, and those are what everything downstream draws with.
  Both requests are 0-means-default: attribute 0 is black on black, legal and
  no use to anybody, so it is free to spend as "I did not choose".

  The whole GUI.* name space belongs to this file, except GUI.LISTBOX.*,
  which is GUI2.INC.BL -- a listbox is a GUI dialog and reads like one, but
  it is the only one that scrolls and the only one that marks, so it is its
  own #INCLUDE and you pay for it only when you want it.
```

*See also: STASH.INC.BL -- save a text rectangle, and put it back., 4.1 THEME.INC.BL -- named colour roles, 4.6 MENUVERT.INC.BL -- a vertical menu, 4.4 LINEINPUT.INC.BL -- a positioned entry field, GUI2.INC.BL -- a listbox, single or multi select.*

## GUI2.INC.BL -- a listbox, single or multi select.


*From the banner header of `GUI2.INC.BL`.*

```

      GUI.LISTBOX   a WINDOW onto a list longer than the box, and
                    optionally more than one answer

  SEPARATE FROM GUI.INC.BL ON PURPOSE. This is the only dialog that needs
  a scrolling window and a set of marks, and nothing else in the library
  wants either. #INCLUDE it when you want a listbox and pay nothing when
  you do not.

  GUI.MENU is not this and should not be stretched into it: that is
  MENUVERT.RUN in a frame, so the list must fit the screen and it returns
  one row. This is the two things it does not do.

  REQUIRES, and does not #INCLUDE for you, in this order:
      GPB.INC.BL        GP.FILL, GP.PRINTAT, GP.STRPTR, GP.SELECT
      STASH.INC.BL      via GUI.OPEN -- and wants a #SYMFILE, see its header
      THEME.INC.BL      the colour roles, and GOSUB THEME.LOAD first
      MENUVERT.INC.BL   MENUVERT.ROW draws the rows
      GUI.INC.BL        GUI.OPEN and GUI.CLOSE are the box

  Usage:
      DIM MENUVERT.ITEM$(200)
      ... fill 1..N ...
      GUI.LISTBOX.COUNT = N : GUI.LISTBOX.ROWS = 8 : GUI.LISTBOX.MULTI = 1
      GUI.MSG$ = "PICK FILES" : GUI.BANK = 8
      GOSUB GUI.LISTBOX
      IF GUI.LISTBOX.SEL = 0 THEN <cancelled>

   in   GUI.LISTBOX.COUNT   how many items. 0 or less returns cancelled
        MENUVERT.ITEM$()    the items, 1..COUNT. THE CALLER OWNS THE DIM,
                            for MENUVERT's reason: a module cannot be handed
                            an array, and DIMming one means guessing a bound
        GUI.LISTBOX.ROWS    rows visible at once. 0 takes 10, and it is
                            always cut to COUNT and to what the screen holds
        GUI.LISTBOX.MULTI   0 chooses one row. 1 marks a set with SPACE
        GUI.LISTBOX.MARKS$  multi only, IN as well as out: COUNT characters,
                            "1" marked. Anything else -- "" included --
                            starts with none marked
        GUI.LISTBOX.SEL     the item to start on. 0 starts at 1
        plus everything GUI.OPEN reads: GUI.MSG$, GUI.MSG2$, GUI.TITLE$,
        GUI.BANK, GUI.STYLE, GUI.GLYPH, GUI.PLACE and the rest

   out  GUI.LISTBOX.SEL     the item under the highlight, 1..COUNT, or 0 if
                            cancelled. In multi that is where the cursor was,
                            not the answer -- the marks are the answer
        GUI.LISTBOX.MARKS$  multi only: COUNT characters, "1" marked
        GUI.LISTBOX.MARKED  multi only: how many are marked
        GUI.KEY             13 accepted, 27 or 3 cancelled

  THE BOTTOM FRAME EDGE says nothing it does not have to. In multi it is
  "2 SELECTED OF 20" and follows every SPACE; otherwise it is "20 ITEMS" for a
  list too long to see at once, and blank for one that fits.

  KEYS: up and down move, PgUp and PgDn page, HOME and END jump, SPACE
  toggles a mark in multi, RETURN accepts, ESC and STOP cancel. The codes
  are the ones samples/editor dispatches on, so they are known good.

  THE LAST TWO ARE ON THE BOX, in a dimmed row under the list with ENTER and
  ESC picked out -- GUI.TEXT's hint, in GUI.TEXT's words, at GUI.TEXT's two
  offsets, because a dialog that answers OK or CANCEL should say so the same
  way wherever you meet it. It costs the body a spacer row and a hint row,
  and the box a minimum width of 26.

  THE MARKS ARE A STRING AND ARE TOGGLED IN PLACE. GP.STRPTR gives the
  address of the characters, so SPACE POKEs one byte and allocates nothing
  -- where LEFT$ + CHR$ + MID$ would build a whole new string per keypress,
  and the old block is dead for good. It also means no second array to DIM
  and no bound to guess. THE PRICE IS 250 ITEMS, which is a string.

  THE WINDOW IS MENUVERT.SCROLL. Screen row R draws ITEM$(SCROLL + R), so
  the drawing is MENUVERT.ROW unchanged and this file only decides what
  SCROLL is. That input is an offset defaulting to 0 precisely so every
  menu that never heard of it is unaffected.

  THE MARK COLUMNS ARE THIS FILE'S, NOT MENUVERT'S. In multi the rows are
  indented by two columns and MENUVERT owns only the text columns, so the
  caller's array is never touched to add a marker to it.

  NO #DEFINEs AND NO INCLUDE GUARD IN HERE, ON PURPOSE. BASLOAD rejects a
  DIGIT in a #DEFINE or #IFNDEF name, so a GUI.LISTBOX.* constant cannot exist and
  a GUILIST.* one would be a second name space for one module. The numbers
  are written where they are used, next to the comment that names them.
  #INCLUDE this file once.

  The whole GUI.LISTBOX.* name space belongs to this file.
```

*See also: GUI.INC.BL -- four dialogs, in a box that puts the screen back., STASH.INC.BL -- save a text rectangle, and put it back., 4.1 THEME.INC.BL -- named colour roles, 4.6 MENUVERT.INC.BL -- a vertical menu*

## MENUBAR.INC.BL -- a horizontal menu, in BASIC.


*From the banner header of `MENUBAR.INC.BL`.*

```

      MENUBAR.RUN     draw it, drive it, return the item chosen
      MENUBAR.DRAW    draw it without driving it
      MENUBAR.ITEM    one item, in whichever attribute you name

  MENUVERT.INC.BL is the VERTICAL menu; this is the other axis. Items sit side by
  side, each as wide as its own text, and left and right are what move.

  REQUIRES, and does not #INCLUDE for you:
      GPB.INC.BL        GP.FILL, GP.PRINTAT
      MENUVERT.INC.BL   MENUVERT.ROW draws the items and tints the
                        hotkeys; this file owns the layout and the keys

  A SEPARATE FILE, NOT A FLAG ON MENUVERT: a BASL module has no dead code
  elimination, so a horizontal path inside MENUVERT would be carried by every
  vertical menu ever written. STASHFILE.INC.BL was split off for the same reason.

  IT SHARES MENUVERT'S ARRAY AND COLOURS -- MENUVERT.ITEM$, .ATTR, .HIATTR,
  .HOTATTR, .HOT$ -- because a program with a bar and a dropdown wants one
  convention, and copying an array between name spaces per call would be worse.

  Usage:
      MENUVERT.ITEM$(1) = " FILE "     ... and so on
      MENUVERT.COUNT = 3
      MENUVERT.ATTR = THEME.CLR(THEME.TITLE)
      MENUVERT.HIATTR = THEME.CLR(THEME.HILITE)
      MENUBAR.X = 0 : MENUBAR.Y = 0
      GOSUB MENUBAR.RUN
      IF MENUBAR.SEL = 0 THEN <cancelled>

   in   MENUBAR.X  MENUBAR.Y   where the bar starts
        MENUBAR.GAP            cells BETWEEN items. 0 is the default,
                               because the space belongs in the item
                               text -- " FILE " is how you get a
                               highlight with air in it, exactly as a
                               vertical menu's " NEW GAME" does
        MENUBAR.FLAGS          added together, see below
        MENUBAR.SEL            the item to start on; 0 starts at 1
        and MENUVERT.COUNT, MENUVERT.ITEM$(), MENUVERT.ATTR,
        MENUVERT.HIATTR, MENUVERT.HOT$, MENUVERT.HOTATTR

   out  MENUBAR.SEL     1..COUNT, or 0 if cancelled
        MENUBAR.KEY     what ended it: 13 chose, 27 cancelled, 17 or
                        145 if the cross-axis flags are on, or the
                        hotkey itself
        MENUBAR.SELX    the COLUMN the chosen item starts at, and
        MENUBAR.SELW    how wide it is -- so a caller can drop a panel
                        under it without working the layout out again

  THE WIDTH OF AN ITEM IS THE LENGTH OF ITS TEXT -- no column width, no
  MENUBAR.WIDTH. A bar reading "FILE SEARCH HELP" with every item as wide as the
  longest is a row of buttons, not a menu bar. That is the real difference from
  MENUVERT, and why this could not have been a flag.

  UP AND DOWN ARE OPTIONAL EXITS, off by default. A bar over dropdowns wants DOWN
  to end it so the caller can open the panel and come back; a bar that is only a
  bar wants them ignored. Neither is the general case, so off means "an arrow
  across the grain does nothing".

  The whole MENUBAR.* name space belongs to this file.
```

*See also: 4.6 MENUVERT.INC.BL -- a vertical menu, STASHFILE.INC.BL -- a saved text rectangle, through a file.*

## STASH.INC.BL -- save a text rectangle, and put it back.


*From the banner header of `STASH.INC.BL`.*

```

      STASH.SAVE      copy a rectangle of the screen into a RAM bank
      STASH.RESTORE   copy it back, where it was or somewhere else

  For the same rectangle through a FILE see STASHFILE.INC.BL, built on this and
  kept separate so a program wanting only the bank does not carry the disk half --
  a BASL module has no dead code elimination, and those three routines are 127 bytes.

  A MODULE, NOT A RUNTIME KEYWORD, so it costs its bytes only in the programs that
  ask for it: as a keyword it would be 329 bytes carried by every program that never
  stashed anything.

  YOUR PROGRAM MUST HAVE A #SYMFILE. The assembly reaches BASIC's variables through
  {VAR} and BASLOAD crunches every name first -- STASH.VADDR% is some two-letter
  name by then. Without it the compile stops with "NO SYMBOL FILE FOR {}", naming
  the cause but not the file. Name it to match the PRG:

      #SAVEAS "@:MYPROG.PRG"
      #SYMFILE "@:MYPROG.SYM"
      #INCLUDE "GPB.INC.BL"
      #INCLUDE "STASH.INC.BL"

  Both directives go BEFORE the includes.

  Usage:
      STASH.BANK = 8
      STASH.X = 10 : STASH.Y = 4 : STASH.W = 30 : STASH.H = 8
      GOSUB STASH.SAVE
      ... draw over it ...
      GOSUB STASH.RESTORE

   in   STASH.BANK     the RAM bank to keep the cells in. 1..255, and
                       it is yours: this writes the whole of it
        STASH.X  STASH.Y     top left, in CELLS
        STASH.W  STASH.H     size, in cells

   out  STASH.OK       1 if it fitted and was saved, 0 if not

  RESTORE NEEDS ONLY THE BANK: four header bytes go in first -- w, h, x, y -- so the
  rectangle describes itself and cannot be put back at the wrong size. STASH.MOVE = 1
  with STASH.X / STASH.Y pastes it somewhere else instead.

  A BANK IS 8,192 BYTES AND A CELL IS TWO, so 4,094 cells fit -- 63x63, larger than
  any dialog and NOT a whole 80x60 screen (9,600 bytes). Too big is refused before
  the first write, with STASH.OK = 0, rather than running on into the next bank.

  WHY THE SPLIT IS WHERE IT IS: the address of a row is worked out in BASIC, once a
  row, and the 160 bytes are copied in assembly. That keeps the assembly free of any
  pointer needing zero page -- and there is none to have, because a GP.ASM blob runs
  with the interpreter live and codePtr, zTemp0, NSStatus and the mantissas must all
  survive it. The destination goes into the OPERAND of the instruction that uses it,
  which is the idiom samples/editor's renderers are built on.

  EACH BLOCK IS WRAPPED IN #REM 1 / #REM 0. Without it BASLOAD's default strips the
  body and the block reaches the compiler EMPTY, which gpasm.asm deliberately
  refuses as "block mismatch" rather than compiling a program that quietly contains
  none of the code. The #REM 0 after each block restores BASLOAD's default.

  The whole STASH.* name space belongs to this file.
```

*See also: STASHFILE.INC.BL -- a saved text rectangle, through a file.*

## STASHFILE.INC.BL -- a saved text rectangle, through a file.


*From the banner header of `STASHFILE.INC.BL`.*

```

      STASH.FILE.SAVE   a rectangle of the screen, out to a file
      STASH.FILE.LOAD   a saved file, back where it came from
      STASH.FILE.PUT    a saved file, pasted somewhere else

  REQUIRES, and does not #INCLUDE for you:
      GPB.INC.BL      GP.ASM
      STASH.INC.BL    which does the actual copying
  and, like it, a #SYMFILE in your program. See that file's header.

  Usage:
      STASH.BANK = 8 : STASH.FILE$ = "PANEL.BIN"
      STASH.X = 10 : STASH.Y = 4 : STASH.W = 30 : STASH.H = 8
      GOSUB STASH.FILE.SAVE
      ...
      GOSUB STASH.FILE.LOAD

   in   STASH.FILE$    the name
        STASH.DEV      the device. 0 means 8, the usual drive
        STASH.BANK     the bank to stage through
        and, for SAVE, the geometry STASH.SAVE wants

  A SEPARATE FILE FROM STASH.INC.BL ON PURPOSE: a BASL module has no dead code
  elimination, and these three are 127 bytes. A dialog that stashes to a bank and
  puts it back never goes near a disk and should not pay for one.

  THE FILE IS SELF-DESCRIBING BECAUSE THE STASH IS -- the four header bytes go out
  with the cells, so loading one back needs nothing but the name. That is the flaw
  dotBASIC admits to in its own .CUT/.PASTE, which "requires correctly
  re-describing the width and height of each cut".

  BSAVE's end address is EXCLUSIVE, so this writes the header and the cells and no
  padding. The length is w * h * 2 + 4, which BASIC works out for itself -- which
  is why no GP.END keyword was ever spent on telling BSAVE where a stash ended.

  The STASH.FILE.* names belong to this file; the rest of STASH.* is
  STASH.INC.BL's.
```

*See also: STASH.INC.BL -- save a text rectangle, and put it back.*

---

# GLOBALS AND NAMING

## 5. Variables

#### 5. Variables

BASL has one flat namespace. There are no locals, no scoping and no parameters. Every variable in
every `#INCLUDE`d module is visible to your program and the reverse, and nothing warns you: a
collision is a wrong answer, not an error.

The convention is one dotted prefix per module, and nothing writes outside its own prefix.

##### Prefixes already taken

| Prefix | Owner |
|---|---|
| `GP.` | keywords, **not variables** — see below |
| `STR.` | `STRINGS.INC.BL` |
| `THEME.` | `THEME.INC.BL` |
| `APPSYS.` | `APPSYS.INC.BL` |
| `LINEINPUT.` | `LINEINPUT.INC.BL` |
| `MENUVERT.` | `MENUVERT.INC.BL` |
| `BMX.` / `BMXK.` | `BMX.INC.BL` (variables / its KERNAL constants) |

Use any other prefix for your own program: `GAME.`, `MAP.`, `AIRLIFT.`. A prefix costs nothing at
runtime — BASLOAD crunches every identifier to a short BASIC variable, so a long readable name and a
two-letter one compile to the same thing.

Do not reuse a taken prefix for a name the module has not defined. `THEME.MINE` is free today and is
one library update from not being.

##### `GP.*` is keywords, not variables

`GPB.INC.BL` defines no variables: 27 `#TOKEN` lines and nothing else.

```basic
GP.A = 5          ' SYNTAX ERROR — GP.A is a keyword
X = GP.A          ' correct
```

The value words are `GP.A` `GP.X` `GP.Y` `GP.C`, the registers after `GP.CALL`, and that is all of
them. They are tokens rather than variables because nothing in the runtime can write a BASIC
variable by name, so a command that returns a value must return it through a keyword. X16's own
`ST`, `MX` and `MY` work the same way.

The complete per-module in / out / internal register is
[GP-BASIC.GLOBALS.md](GP-BASIC.GLOBALS.md), with a script in §6 of that file for re-checking it
after a change.

---


*See also: 6. The traps, collected, 4.2 STRINGS.INC.BL -- string helpers, 4.1 THEME.INC.BL -- named colour roles, 4.3 APPSYS.INC.BL -- start politely, leave it as you found it, 4.4 LINEINPUT.INC.BL -- a positioned entry field, 4.6 MENUVERT.INC.BL -- a vertical menu, 4.5 BMX.INC.BL -- a BMX bitmap into VERA*

## 1. The prefixes that are taken

#### 1. The prefixes that are taken

| Prefix | Owner | What it is |
|---|---|---|
| `GP.` | `GPB.INC.BL` | **keywords, not variables** — see §2, this one is different |
| `STR.` | `STRINGS.INC.BL` | string helpers |
| `THEME.` | `THEME.INC.BL` | colour roles |
| `APPSYS.` | `APPSYS.INC.BL` | screen save/restore, panels to disk |
| `LINEINPUT.` | `LINEINPUT.INC.BL` | entry fields |
| `MENUVERT.` | `MENUVERT.INC.BL` | vertical menus |
| `BMX.` | `BMX.INC.BL` | BMX bitmap loading |
| `BMXK.` | `BMX.INC.BL` | its KERNAL/VERA constants, kept apart from its variables |

Pick anything else for your own program. `AIRLIFT.`, `GAME.`, `MAP.` — a prefix costs nothing at
runtime because BASLOAD crunches every identifier down to a short BASIC variable, so a long
readable name and a two-letter one compile to exactly the same thing.

Do not reuse a taken prefix for a name the module has not defined. `THEME.MINE` looks
free today; it is one library update away from not being.

---


*See also: 2. Using it, 4.2 STRINGS.INC.BL -- string helpers, 4.1 THEME.INC.BL -- named colour roles, 4.3 APPSYS.INC.BL -- start politely, leave it as you found it, 4.4 LINEINPUT.INC.BL -- a positioned entry field, 4.6 MENUVERT.INC.BL -- a vertical menu, 4.5 BMX.INC.BL -- a BMX bitmap into VERA*

## 2. GP.* is keywords, not variables -- and the difference bites

#### 2. `GP.*` is keywords, not variables — and the difference bites

`GPB.INC.BL` defines no variables. It is 31 `#TOKEN` lines and nothing else. Everything
spelled `GP.something` is a BASIC *keyword*, so:

```basic
GP.A = 5          ← SYNTAX ERROR. GP.A is a keyword; you cannot assign to it.
X = GP.A          ← correct. It reads the accumulator after the last GP.CALL.
```

The value words are `GP.A`, `GP.X`, `GP.Y` and `GP.C` — the registers after `GP.CALL`, and now the
whole list of them. They are tokens rather than variables because nothing in the runtime can write
a BASIC variable by name, so a command that returns a value has to
hand it back through a keyword. X16's own `ST`, `MX` and `MY` exist for the same reason.

The full keyword list lives in `GPC-BASIC/GPB.INC.BL`, and the token numbers mirror `getGP()` in
`source/common-scripts/c64tokens.py`.

---


## 3. The modules

#### 3. The modules

Each table is **in** (set before the `GOSUB`), **out** (read after it), and **internal** (do not
read, do not write, do not rely on).

##### `THEME.INC.BL`

| | |
|---|---|
| in | `THEME.DARK` — 0 light, non-zero dark, read by `THEME.LOAD`<br>`THEME.ATTR` — a packed attribute, for `THEME.SET` and `THEME.HI` |
| out | `THEME.CLR(role)` — the colour array, `DIM`med to `THEME.SLOTS`<br>`THEME.INV` — the inverse attribute, from `THEME.HI` |
| internal | `THEME.READY` |
| constants | `THEME.PAGE` `THEME.TEXT` `THEME.TITLE` `THEME.BORDER` `THEME.HILITE` `THEME.DIMMED` `THEME.WARN` `THEME.SLOTS` |

`THEME.CLR` is the array this module `DIM`s. Do not `DIM` it yourself — the module owns it, and
`DIM`ming an array GPC has already dimensioned is an error.

##### `APPSYS.INC.BL`

| | |
|---|---|
| in | `APPSYS.FILE$` `APPSYS.BANK` `APPSYS.X` `APPSYS.Y` `APPSYS.W` `APPSYS.H` `APPSYS.DEV` — the panel routines |
| out | `APPSYS.MODE` `APPSYS.COLS` `APPSYS.ROWS` `APPSYS.COLOUR` — set by `APPSYS.STARTUP` |
| internal | `APPSYS.LAST` |
| constants | `APPSYS.SCRMODE` `APPSYS.COLREG` `APPSYS.WINDOW` `APPSYS.HEADER` |

Lay the screen out from `APPSYS.COLS` and `APPSYS.ROWS`. Do not assume 80x60 —
the X16 boots there but `SCREEN 0` is 40×30, and someone who prefers larger text is running one.

##### `STRINGS.INC.BL`

| | |
|---|---|
| in | `STR.STR$` — the string, in and out<br>`STR.WIDTH` — field width, the pad routines<br>`STR.DELIM$` `STR.MAX` — `SPLIT` (`MAX` 0 means 10)<br>`STR.FIND$` `STR.REPL$` — `REPLACE`<br>`STR.PET` — a PETSCII code, `PET2SCR` |
| out | `STR.STR$` — padded, or replaced, in place<br>`STR.N` — how many fields `SPLIT` found, always ≥ 1<br>`STR.FIELD$(1..N)` — the fields themselves<br>`STR.SCR` — the screen code from `PET2SCR` |
| internal | `STR.GAP` `STR.HALF` `STR.REST$` `STR.AT` `STR.LIM` `STR.OUT$` |

`STR.FIELD$` is the one array the library does not `DIM`. Left alone, GPC's implicit `DIM` gives
0..10. For more, `DIM` it before the first call and set
`STR.MAX` to match — `DIM`ming an array GPC has already auto-dimensioned is an error, so it is
one or the other. This is the opposite of `THEME.CLR`, which the module owns outright; the two are
worth keeping straight.

##### `LINEINPUT.INC.BL`

| | |
|---|---|
| in | `LINEINPUT.X` `LINEINPUT.Y` — top left of the field<br>`LINEINPUT.LEN` — how many characters fit<br>`LINEINPUT.ATTR` — packed attribute<br>`LINEINPUT.TEXT$` — the starting value<br>`LINEINPUT.MASK` — non-zero shows asterisks<br>`LINEINPUT.LABEL$` — `LINEINPUT.ASK` only |
| out | `LINEINPUT.TEXT$` — what was typed<br>`LINEINPUT.KEY` — the key that ended it |
| internal | `LINEINPUT.SHOW$` `LINEINPUT.WAS$` `LINEINPUT.K$` `LINEINPUT.CELL$` `LINEINPUT.CODE` `LINEINPUT.CX` `LINEINPUT.CA` `LINEINPUT.INV` `LINEINPUT.LIT` `LINEINPUT.TICK` `LINEINPUT.DONE` `LINEINPUT.FILLED` `LINEINPUT.HOME` `LINEINPUT.BAR` |
| constants | `LINEINPUT.RETURN` `LINEINPUT.DELETE` `LINEINPUT.ESCAPE` `LINEINPUT.STOP` `LINEINPUT.DOWN` `LINEINPUT.UP` `LINEINPUT.TAB` `LINEINPUT.SPACE` `LINEINPUT.STAR` `LINEINPUT.BLINK` |

`LINEINPUT.SHOW$` is listed internal but is the one exception worth knowing: it holds what the field
*displayed*, which is what you want if you are repainting a masked field yourself. `FORM.EXP.BL`
uses it for exactly that.

##### `BMX.INC.BL`

| | |
|---|---|
| in | `BMX.FILE$` |
| out | `BMX.ERROR$` — empty means it worked<br>`BMX.WIDTH` `BMX.HEIGHT` `BMX.DEPTH` `BMX.VERSION` `BMX.PALUSED` `BMX.PALFIRST` `BMX.DATAOFF` `BMX.PACKED` — the header, readable after `BMX.OPEN` |
| in, optional | `BMX.STASH` — where `BMX.PAINT` keeps the machine's palette; VRAM `$13000` by default, `-1` to keep nothing |
| internal | `BMX.PTR` `BMX.HEADER$` `BMX.SCRATCH` `BMX.SCRATCH$` `BMX.PALBASE` `BMX.ADDR` `BMX.LO` `BMX.HI` `BMX.BANK` `BMX.REST` `BMX.COUNT` `BMX.CHUNK` `BMX.GOT` `BMX.STEP` `BMX.SKIP` `BMX.ROW` `BMX.ROWS` `BMX.X0` `BMX.Y0` `BMX.BAD` `BMX.KEPT` `BMX.SRC` `BMX.DST` |
| constants | `BMXK.MACPTR` `BMXK.CHKIN` `BMXK.CLRCHN` `BMXK.MEMCOPY` `BMXK.VCTRL` `BMXK.VLO` `BMXK.VMID` `BMXK.VHI` `BMXK.PORTLO` `BMXK.PORTLO.B` `BMXK.PORTHI` `BMXK.LFN` |

`BMX.PTR` doubles as the "have I initialised" flag — it is zero until `BMX.INIT` has run. Zeroing it
yourself would leak a string block and re-allocate.

`BMX.STASH` is the one variable here a caller may want to set, and it has to be set before the
first
`BMX.OPEN` — `BMX.INIT` runs then, and fills in the default only if you have not. That is why `-1`
rather than `0` switches the stash off: `0` already means "never set". `BMX.KEPT` is the once-per-run
guard that makes a slideshow restore the *machine's* palette rather than the previous picture's.

##### `MENUVERT.INC.BL`

| | |
|---|---|
| in | `MENUVERT.X` `MENUVERT.Y` — top left of the first row<br>`MENUVERT.WIDTH` — cells wide, which is the width of the highlight<br>`MENUVERT.COUNT` — how many rows<br>`MENUVERT.ITEM$()` — the rows, 1..COUNT; **the caller owns the `DIM`**<br>`MENUVERT.ATTR` — packed attribute<br>`MENUVERT.HIATTR` — the highlighted row; 0 inverts `MENUVERT.ATTR`<br>`MENUVERT.HOT$` — one hotkey character a row<br>`MENUVERT.HOTATTR` — tint for the hotkey letter; 0 is off<br>`MENUVERT.FLAGS` — added together<br>`MENUVERT.SEL` — the row to start on |
| out | `MENUVERT.SEL` — 1..COUNT, or 0 if cancelled<br>`MENUVERT.KEY` — the key that ended it |
| internal | `MENUVERT.SCAN` `MENUVERT.EACH` `MENUVERT.DONE` `MENUVERT.CODE` `MENUVERT.INCHAR$` `MENUVERT.PREVSEL` `MENUVERT.HIGHLIGHT` `MENUVERT.DRAWROW` `MENUVERT.DRAWATTR` `MENUVERT.DRAWTEXT$` `MENUVERT.DRAWY` `MENUVERT.HOTCODE` `MENUVERT.HOTLAST` `MENUVERT.WANTCODE` `MENUVERT.HOTAT` `MENUVERT.HOTWANT` `MENUVERT.HOTHERE` `MENUVERT.HOTSCAN` `MENUVERT.PADNOW` `MENUVERT.PADNEW` `MENUVERT.PADHELD` `MENUVERT.PADRAW` |
| constants | `MENUVERT.MUSTSEL` `MENUVERT.KEEPMARK` `MENUVERT.NOWRAP` `MENUVERT.GAMEPAD` `MENUVERT.UP` `MENUVERT.DOWN` `MENUVERT.ENTER` `MENUVERT.ESCAPE` `MENUVERT.STOP` `MENUVERT.SPACE` `MENUVERT.PORT` `MENUVERT.PAD.UP` `MENUVERT.PAD.DOWN` `MENUVERT.PAD.B` `MENUVERT.PAD.START` |

`MENUVERT.SEL` is both an input and an output: the row to start on going in, and the row
chosen coming out, so a menu reopened without clearing it reopens where it was. That is usually what
you want; set it to 0 when it is not.

`MENUVERT.DRAWROW`, `MENUVERT.DRAWATTR` and `MENUVERT.DRAWTEXT$` are listed internal but are the
documented arguments to `MENUVERT.ROW`, which is public: they are internal to `MENUVERT.RUN`, not to
you. `MENUVERT.HOTFIND` reads the first two and answers in `MENUVERT.HOTAT`.

---


## 3. The modules (2)


*See also: 4.1 THEME.INC.BL -- named colour roles, 4.3 APPSYS.INC.BL -- start politely, leave it as you found it, 4.2 STRINGS.INC.BL -- string helpers, 4.4 LINEINPUT.INC.BL -- a positioned entry field, 4.5 BMX.INC.BL -- a BMX bitmap into VERA, 4.6 MENUVERT.INC.BL -- a vertical menu*

## 4. Labels are global too

#### 4. Labels are global too

Every `NAME:` in every module is a jump target in one flat space, including the ones you were never
meant to call. `BMX.STREAM.MORE`, `LINEINPUT.REDRAW`, `THEME.LOAD.DARK` and most of `MENUVERT.*` are
internal, and a `GOSUB` to one will do something, just not something useful.

`MENUVERT` is the module with the most of them, because driving a menu is mostly branching:
**`MENUVERT.RUN`, `MENUVERT.DRAW`, `MENUVERT.ROW` and `MENUVERT.HOTFIND` are the four you may call.**
`MENUVERT.WAIT`, `.KEYED`, `.SETTLE`, `.WRAPTOP`, `.WRAPBOT`, `.CANCEL`, `.HOTKEY`, `.PADKEY`,
`.PADREAD` and the three `FOLD` helpers are not.

`STRINGS` has two of its own, both loop continuations rather than entry points:
**`STR.SPLIT.NEXT`** and **`STR.REPLACE.NEXT`**. Enter either one directly and you resume a
loop whose accumulators were never initialised. The callable names are `STR.PADR`, `PADL`,
`PADC`, `SPLIT`, `REPLACE` and `PET2SCR`.

Each module also has a skip label it jumps over itself with — `THEME.SKIP`, `APPSYS.SKIP`,
`STR.SKIP`, `BMX.MODULE.END`, `LINEINPUT.MODULE.END`, `MENUVERT.MODULE.END`. Those exist so an
include can sit anywhere in the file, the top included. **Do not branch to one.**

BASLOAD refuses a name used as both a label and a variable (`BASLOAD.MD:319`). `BMX.SKIP` is the
byte-skip counter, so the module's skip label had to
be `BMX.MODULE.END` — a name is either a label or a variable, never both.

---


## 5. Two more naming rules that are not about collisions

#### 5. Two more naming rules that are not about collisions

**`#DEFINE` takes an INT16** (`BASLOAD.MD:313`). A constant above 65535 is
`ERROR: INVALID PARAMETER`, not a warning — which is why `BMX.PALBASE` (VRAM `$1FA00`, 129536) is an
ordinary variable and not a `#DEFINE`. Every VRAM address past `$FFFF` has the same problem.

**A dotted name whose tail is a reserved word is fine.** `MENUVERT.COUNT`, `THEME.CLR`,
`LINEINPUT.LEN` and `LINEINPUT.RETURN` all contain keywords and all work, because BASLOAD matches the whole identifier. An
*undotted* one does not: `POS`, `MB`, `ST`, `LEN` and `CHAR` cannot be variables at all. This is the
main reason the library is dotted throughout.

One rule applies only outside BASL: BASLOAD gives 64 significant characters, the built-in BASIC
gives two. Write the same code as a hand-typed `.bas` for the host tokeniser and
`THEME.CLR` and `THEME.COUNT` become the same variable. That is a silent wrong answer — it cost two
test cycles during tier 6, both times looking exactly like a compiler bug. Inside BASL you are safe;
in a raw `.bas`, give every variable a distinct first two characters.

---


## 6. Regenerating this

#### 6. Regenerating this

The tables above were extracted from the sources rather than remembered. To check them after a
change:

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

---

# THE TRAPS

## 6. The traps, collected

#### 6. The traps, collected

Each of these has cost a debugging session at least once.

| Trap | What happens | Do this |
|---|---|---|
| `P AND 255` on a heap or VRAM address | `AND` is 16-bit signed; above 32,767 it raises `OUT OF RANGE` instead of masking | `H = INT(P/256) : L = P - H*256` |
| an address in an `A%` variable | `%` is signed 16-bit and truncates without error — `A% = 49152` reads back -16,384 | untyped variable, or split into page and offset |
| `$0400` for machine code | stock BASIC leaves it free, a compiled GPC program does not — runtime state lives there, and it is corrupted with no error | banked RAM, `$A000`–`$BFFF` |
| `PRINT` after `GP.PRINTAT` | GP drawing never calls the KERNAL, so the cursor is wherever it was | `LOCATE` first, or stay in one world |
| `SORT.INC.BL` with no `#SYMFILE` | `{VAR}` cannot resolve a crunched name — `NO SYMBOL FILE FOR {}` | `#SYMFILE "@:PROG.SYM"`, before the `#INCLUDE`s |
| `GP.BOX X,Y,W,H,,7` | optionals cannot be skipped over | `GP.BOX X,Y,W,H,0,7` |
| `SCREEN` after `BMX.PAINT` | reloads the default palette and throws the image's colours away | set the mode first |
| `STR.FIELD$` wanted bigger | auto-`DIM`ed at 0..10 on first use, and you cannot `DIM` it after | `DIM` it **before** the first call, set `STR.MAX` |
| `#DEFINE X 129536` | `#DEFINE` takes an INT16 — `ERROR: INVALID PARAMETER` | an ordinary variable |

Two notes on names. Inside BASL, 64 characters are significant, so `PANEL.COL` and `PANEL.ROW` are
different variables and readable names cost nothing. The same source written as a raw `.bas` for the
host tokeniser is back to two significant characters.

Dotted names also avoid the keyword-collision trap. `MENUVERT.COUNT`, `THEME.CLR`, `LINEINPUT.LEN`
and `LINEINPUT.RETURN` all contain reserved words and all work, because BASLOAD matches the whole
identifier. Undotted names do not: `POS`, `MB`, `ST`, `LEN` and `CHAR` cannot be variables. That is
why the library is dotted throughout.

*See also: 4.7 SORT.INC.BL -- shell sort a string array*

