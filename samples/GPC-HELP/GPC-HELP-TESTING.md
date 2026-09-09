# GPC-HELP-TESTING

The GP.BASIC and BASL reference, in one file you can read on a PC. The module entries are the banner headers of `samples/GPB-MODS-TESTING/GPC-BASIC`, so this file documents THAT copy of the library -- not the one the shipped `.HLP` files were built from.

**Generated. Do not edit.** `MKHELP.PY` builds it from the manual, the name register and the module banner headers. Fix anything wrong at the source and rebuild:

```
python samples/GPC-HELP/MKHELP.PY --mods samples/GPB-MODS-TESTING/GPC-BASIC --md-only --md-name GPC-HELP-TESTING.md
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
  - [3.4.1 GP.INSTR -- position of a substring](#341-gpinstr----position-of-a-substring)
  - [3.4.2 GP.CONTAINS -- test for a substring](#342-gpcontains----test-for-a-substring)
  - [3.4.3 GP.ISEMPTY -- test for a zero-length string](#343-gpisempty----test-for-a-zero-length-string)
  - [3.4.4 GP.COMP -- compare two strings, ignoring case](#344-gpcomp----compare-two-strings-ignoring-case)
  - [3.4.5 GP.STRPTR -- address of a string block](#345-gpstrptr----address-of-a-string-block)
  - [3.5 Arrays](#35-arrays)
  - [3.6 Screen -- stash and restore](#36-screen----stash-and-restore)
  - [3.7 Screen -- drawing](#37-screen----drawing)
  - [3.8 Block IF](#38-block-if)
  - [3.9 Inline assembly](#39-inline-assembly)
  - [3.10 Text in a bank](#310-text-in-a-bank)
- **BASL MODULES**
  - [4. Module reference -- the BASL library](#4-module-reference----the-basl-library)
  - [4.1 THEME.INC.BL -- named colour roles](#41-themeincbl----named-colour-roles)
  - [4.2 STRINGS.INC.BL -- string helpers](#42-stringsincbl----string-helpers)
  - [4.3 APPSYS.INC.BL -- start politely, leave it as you found it](#43-appsysincbl----start-politely-leave-it-as-you-found-it)
  - [4.4 LINEINPUT.INC.BL -- a positioned entry field](#44-lineinputincbl----a-positioned-entry-field)
  - [4.5 BMX.INC.BL -- a BMX bitmap into VERA](#45-bmxincbl----a-bmx-bitmap-into-vera)
  - [4.6 MENUVERT.INC.BL -- a vertical menu](#46-menuvertincbl----a-vertical-menu)
  - [4.7 SORT.INC.BL -- shell sort a string array](#47-sortincbl----shell-sort-a-string-array)
  - [4.8 STRCASE.INC.BL -- case, in place](#48-strcaseincbl----case-in-place)
  - [4.10 STRUSING.INC.BL -- a number to a template](#410-strusingincbl----a-number-to-a-template)
  - [GUI.INC.BL -- four dialogs, in a box that puts the screen back.](#guiincbl----four-dialogs-in-a-box-that-puts-the-screen-back)
  - [GUI2.INC.BL -- a listbox, single or multi select.](#gui2incbl----a-listbox-single-or-multi-select)
  - [MENUBAR.INC.BL -- a horizontal menu, in BASIC.](#menubarincbl----a-horizontal-menu-in-basic)
  - [STASH.INC.BL -- save a text rectangle, and put it back.](#stashincbl----save-a-text-rectangle-and-put-it-back)
  - [STASHFILE.INC.BL -- a saved text rectangle, through a file.](#stashfileincbl----a-saved-text-rectangle-through-a-file)
  - [BANKMGR.INC.BL -- who owns which RAM bank.](#bankmgrincbl----who-owns-which-ram-bank)
  - [FILEDIR.INC.BL -- a directory, into a bank or into low RAM.](#filedirincbl----a-directory-into-a-bank-or-into-low-ram)
  - [FILEIO.INC.BL -- the drive: status, files, directories.](#fileioincbl----the-drive-status-files-directories)
  - [KB.INC.BL -- the keyboard buffer, emptied.](#kbincbl----the-keyboard-buffer-emptied)
  - [LIBBANK.INC.BL -- the low memory front door to a banked library.](#libbankincbl----the-low-memory-front-door-to-a-banked-library)
  - [LIBBANKFD.INC.BL -- the low memory front door to a banked FILEDIR.](#libbankfdincbl----the-low-memory-front-door-to-a-banked-filedir)
  - [STASHVRAM.INC.BL -- screen rectangles and byte blobs, kept in VRAM.](#stashvramincbl----screen-rectangles-and-byte-blobs-kept-in-vram)
  - [STASHVRAMGC.INC.BL -- close the holes in a STASHVRAM store.](#stashvramgcincbl----close-the-holes-in-a-stashvram-store)
- **GLOBALS AND NAMING**
  - [5. Variables](#5-variables)
  - [1. The prefixes that are taken](#1-the-prefixes-that-are-taken)
  - [2. GP.* is keywords, not variables -- and the difference bites](#2-gp-is-keywords-not-variables----and-the-difference-bites)
  - [3. The modules](#3-the-modules)
  - [4. Labels are global too](#4-labels-are-global-too)
  - [5. TRUE IS -1](#5-true-is--1)
  - [6. Two more naming rules that are not about collisions](#6-two-more-naming-rules-that-are-not-about-collisions)
- **THE TRAPS**
  - [6. The traps, collected](#6-the-traps-collected)
- **MEMORY AND LIMITS**
  - [7. Memory, and what the compiler tells you](#7-memory-and-what-the-compiler-tells-you)

---

# GETTING STARTED

## 1. What GP.BASIC is

#### 1. What GP.BASIC is

Three layers, innermost first.

**Core keywords.** 30 of them, compiled to p-code and handled by assembly in the runtime:

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
programs that include it. Menus vertical and bar, panels, themes, entry fields, in-place case, trim
and splice, shell sort, a screen rectangle to a RAM bank or a file, BMX into VERA.

`STASH.INC.BL`, `SORT.INC.BL`, `STRCASE.INC.BL` and `STRINGS.INC.BL` are `GP.ASM` and still
modules: as keywords their bytes would sit in the block, paid by every GP program. `GP.ARRPTR` and
`GP.STRPTR` are what lets them out — a BASL subroutine takes an address, not an array or a string.

The division is assembly for loops and bulk moves, BASIC for everything else. `LINEINPUT.GET`
waits on the keyboard, so speed does not apply to it; writing it in BASL saved 166 runtime bytes.

---


*See also: STASH.INC.BL -- save a text rectangle, and put it back., 4.7 SORT.INC.BL -- shell sort a string array, 4.8 STRCASE.INC.BL -- case, in place, 4.2 STRINGS.INC.BL -- string helpers*

## 2. Using it

#### 2. Using it

Every BASL source that uses a `GP.` keyword must declare the keyword set:

```basic
#INCLUDE "GPB.INC.BL"
```

BASLOAD knows only the ROM's keywords. Without that line `GP.DO 5` is a syntax error. The
PC-side converter for hand-written `.bas` needs no such declaration; it reads the same keyword
list from `c64tokens.py` at build time.

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

One GP.BASIC keyword is enough. BASLOAD encodes them as the byte pairs `$CE58`-`$CE7F` and stock
BASIC has no handler behind them, so the ROM can neither `LIST` nor `RUN` the result. It is compiler
input.

Run `GPC.PRG` on BASLOAD's `.PRG`, then run the object it writes.

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

These five files are needed for the compiler to work. Put them beside each other:

| | |
|---|---|
| `GPC.PRG` | the front end you `RUN` |
| `GPC.BIN` | the engine it hands the job to |
| `GPC.IMG.nnn.BIN` | the runtime a self-contained object carries |
| `GPB.RT.nnn.BIN` | the shared runtime, with GP.BASIC included |
| `GPC.RT.nnn.BIN` | the same runtime without it |

`nnn` is the runtime build number and it is part of the name on purpose: a stale runtime under a
fixed name would still be found, and the mismatch would not show until something ran wrong.

Both shared runtimes are needed. Which one a program wants is decided when it is compiled, not when
it runs, so a drive carrying only one works for half the programs built against it. A program that
cannot find its runtime prints `?RT` and stops.

The front end needs `GPB.RT.nnn.BIN` for itself: `GPC.PRG` is a compiled GP.BASIC program built in
shared mode. The compiler front end is written in the language it compiles. The engine behind it,
`GPC.BIN`, is 100% assembly.

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
engine cannot compile without it.

A compiled program identifies itself: `LIST` one and the BASIC stub reads `SYS 2069 : REM GPC!`.

---


## 3. The tools

#### 3. The tools

`GPC.ERR.PRG` turns a runtime error's `@ $XXXX` into a source line, using the debug map the
compiler writes when `MAKE A DEBUG MAP?` is answered yes. Without the map the address cannot be
resolved.

`GPB.HELP.PRG` is this reference, on the machine. It reads `HELP-TXT/` beside it — `GPB.HELP.IDX`
and one `.HLP` per topic — and shows 49 topics at 80x30. Arrows, `PgUp` / `PgDn`, `HOME` and `END`
move. `RETURN` opens the highlighted index row. `/` finds and `N` repeats the search. `L` follows a
topic's cross references, `X` writes its code out as a `.BL` where it has any, `T` cycles the colour
themes, `?` is the about box. `ESC` goes back a step, and quits from the index.

---


## 4. GPC-BASIC/ -- the library

#### 4. `GPC-BASIC/` — the library

Text-mode building blocks, in BASL, `#INCLUDE`d into your source. BASL has no dead code
elimination: including a module costs its whole size whether or not it is called.

| | |
|---|---|
| `GPB.INC.BL` | the `GP.*` keyword definitions for BASLOAD. **Every source using a GP keyword needs this one**, and no other include is ever optional either |
| `THEME.INC.BL` | named colour roles, in three themes |
| `APPSYS.INC.BL` | start an application politely, and leave the machine as it was found |
| `STASH.INC.BL` | save a text rectangle to a RAM bank, and put it back |
| `STASHFILE.INC.BL` | the same rectangle, through a file |
| `STASHVRAM.INC.BL` | rectangles and byte blobs in spare VRAM, addressed by handle. No `GP.ASM`, so no `#SYMFILE` |
| `STASHVRAMGC.INC.BL` | closes the holes a `STASHVRAM` freed out of order. Its own file, so it costs nothing unless called |
| `LINEINPUT.INC.BL` | a positioned, length-limited entry field |
| `MENUVERT.INC.BL` | a vertical menu |
| `MENUBAR.INC.BL` | a horizontal menu bar |
| `GUI.INC.BL` | four dialogs — ask, say, type, choose — in a box that puts the screen back |
| `GUI2.INC.BL` | a listbox, single or multi select |
| `STRINGS.INC.BL` | the string helpers: BASIC where BASIC is enough, assembly where it is not |
| `STRCASE.INC.BL` | case, rewriting a string in place, in assembly |
| `STRUSING.INC.BL` | a number to a template: PRINT USING's mask, in BASIC |
| `SORT.INC.BL` | shell sort a string array in place, in assembly |
| `BMX.INC.BL` | load a BMX bitmap into VERA |

What each one costs in bytes is in the command reference, under *At a glance*.

---


*See also: 4.1 THEME.INC.BL -- named colour roles, 4.3 APPSYS.INC.BL -- start politely, leave it as you found it, STASH.INC.BL -- save a text rectangle, and put it back., STASHFILE.INC.BL -- a saved text rectangle, through a file., STASHVRAM.INC.BL -- screen rectangles and byte blobs, kept in VRAM., STASHVRAMGC.INC.BL -- close the holes in a STASHVRAM store., 4.4 LINEINPUT.INC.BL -- a positioned entry field, 4.6 MENUVERT.INC.BL -- a vertical menu, MENUBAR.INC.BL -- a horizontal menu, in BASIC., GUI.INC.BL -- four dialogs, in a box that puts the screen back., GUI2.INC.BL -- a listbox, single or multi select., 4.2 STRINGS.INC.BL -- string helpers*

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
| `STRUSING.EXP.BL` | one value through six masks, a column, and the overflows |
| `ARRAYS.EXP.BL` | the GP.BASIC array set |
| `SCREEN.EXP.BL` | the GP.BASIC text drawing set |
| `ISO.EXP.BL` | `GP.PRINTAT` and `GP.BOX` in ISO mode |
| `MLCALL.EXP.BL` | `GP.CALL` with `GP.A` / `GP.X` / `GP.Y` / `GP.C` |
| `ASM.EXP.BL` | `GP.ASM` / `GP.ENDASM`, inline 65C02 |
| `MENU.EXP.BL` | a whole small application, in the shape the GP set is for |
| `MENUDEMO.EXP.BL` | `MENUVERT` drawn the way an application would draw it |
| `GUI.EXP.BL` | the four dialogs, over a screen they have to put back |
| `STASHVRAM.EXP.BL` | three panels nested in VRAM, a blob, and the compactor. Needs no `#SYMFILE`, which is the point |
| `FORM.EXP.BL` | three fields you can move between, `LINEINPUT` style |
| `BMXVIEW.EXP.BL` | a BMX bitmap viewer, in about thirty lines |
| `BMXPAL.EXP.BL` `BMXSPD.EXP.BL` | the palette question, and the speed of each path |
| `SORT.EXP.BL` `STRCTST.EXP.BL` `STRTST.EXP.BL` `SPLITT.EXP.BL` | the regression tests for `SORT`, `STRCASE`, the `STRINGS` assembly and `STR.SPLIT` |
| `USINGT.EXP.BL` | the regression test for `STR.USING`, thirty-nine cases |
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

36 keywords, encoded `$CE7F` down to `$CE52` and allocated downward. Ten of the forty-six slots
are holes and stay holes: the byte values are the ABI and are never renumbered.

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
| **Banked text** | ASM | `GP.BANKEDSTR` `GP.ENDBANKEDSTR` `GP.BSTR` · `GP.BSTRCOUNT` is COMPOSITE — see §3.10 |
| **Screen** | ASM | `GP.BOX` `GP.FILL` `GP.PRINTAT` |
| **Screen** | COMPOSITE | `GP.CHAR` — free, one cell in `GP.PRINTAT`'s shape running `GP.FILL`'s handler |
| **Colour roles** | BASIC | `THEME.INC.BL` — `THEME.LOAD`, `THEME.CLR()` · §4.1 |
| **String helpers** | BASIC+ASM | `STRINGS.INC.BL` — `PADR` `PADL` `PADC` `SPLIT` `REPLACE` `SPLICE` `PET2SCR` `TRIM` `LTRIM` `RTRIM` · §4.2 |
| **Screen etiquette, panels** | BASIC | `APPSYS.INC.BL` — `STARTUP` `RESTORE` `PANEL.SAVE/LOAD/PUT` `ISEMU` · §4.3 |
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


*See also: 4. Module reference -- the BASL library, 3.8 Block IF, 3.9 Inline assembly, 3.4 Strings, 3.3 Machine code, 3.10 Text in a bank, 4.1 THEME.INC.BL -- named colour roles, 4.2 STRINGS.INC.BL -- string helpers, 4.3 APPSYS.INC.BL -- start politely, leave it as you found it, 4.4 LINEINPUT.INC.BL -- a positioned entry field, 4.5 BMX.INC.BL -- a BMX bitmap into VERA, 4.6 MENUVERT.INC.BL -- a vertical menu*

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
no symbol table, the emitted keywords are the block, and every case branch resolves by scanning
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

Five keywords. `GP.INSTR` is the only string search GPC has; without it there is none.

Trimming, padding, splicing and case folding are modules, not keywords: `STRCASE.INC.BL` (§4.8)
for case, `STRINGS.INC.BL` (§4.2) for everything else. They cost p-code only in the programs that
`#INCLUDE` them and nothing in the GP block. `GP.STRPTR` is the keyword they are built on.

The in-place routines take an ADDRESS, `GP.STRPTR(a$)`, and never a literal: `GP.STRPTR("hello")`
is an address inside the p-code, so trimming it edits the running program. Case conversion leaves
digits, punctuation and PETSCII graphics unchanged.

There is no `GP.PAD`. In-place work cannot grow a string past the capacity it was created with,
which is what decides which side of `STRINGS.INC.BL` a routine lands on: the pads and `STR.SPLICE`
grow, so they are BASIC assignments and reallocate; the trims only shrink, so they are assembly.

Example: [`STRINGS.EXP.BL`](STRINGS.EXP.BL)


*See also: 3.4.1 GP.INSTR -- position of a substring, 3.4.2 GP.CONTAINS -- test for a substring, 3.4.3 GP.ISEMPTY -- test for a zero-length string, 3.4.4 GP.COMP -- compare two strings, ignoring case, 3.4.5 GP.STRPTR -- address of a string block, 4.8 STRCASE.INC.BL -- case, in place, 4.2 STRINGS.INC.BL -- string helpers*

## 3.4.1 GP.INSTR -- position of a substring

###### 3.4.1 `GP.INSTR` — position of a substring

```entry
  Syntax    GP.INSTR(hay$, needle$ [, start])
  Returns   Position of needle$ in hay$, 1-based. 0 if not found.
  Kind      ASM. Needs the GP block.
  Notes     start is the position to begin at. Default 1.
            Case sensitive. It compares raw bytes; §3.4.4 is the
            case-blind test.
            An empty needle$ returns 0.
  Example
```
```basic
            P = GP.INSTR(F$, ".BAS", 1)
            IF P > 0 THEN PRINT "FOUND AT"; P
```


*See also: 3.4.4 GP.COMP -- compare two strings, ignoring case*

## 3.4.2 GP.CONTAINS -- test for a substring

###### 3.4.2 `GP.CONTAINS` — test for a substring

```entry
  Syntax    GP.CONTAINS(hay$, needle$)
  Returns   -1 if needle$ occurs anywhere in hay$, 0 if not.
  Kind      COMPOSITE. Expands to GP.INSTR(hay$, needle$) <> 0, and
            compiles to the same object. Use whichever reads better.
  Notes     Case sensitive, as §3.4.1 is.
            An empty needle$ returns 0, not -1, because GP.INSTR
            reports not-found for one.
  Example
```
```basic
            IF GP.CONTAINS(F$, ".BAS") THEN GOSUB LOAD.IT
```


*See also: 3.4.1 GP.INSTR -- position of a substring*

## 3.4.3 GP.ISEMPTY -- test for a zero-length string

###### 3.4.3 `GP.ISEMPTY` — test for a zero-length string

```entry
  Syntax    GP.ISEMPTY(a$)
  Returns   -1 if a$ has zero length, 0 if not.
  Kind      COMPOSITE. Expands to LEN(a$) = 0.
  Notes     A string of spaces is not empty. STR.TRIM first if
            that is the intent.
            GP.ISEMPTY(a$), LEN(a$) = 0 and a$ = "" are the same four
            bytes. Use whichever reads better.
```


## 3.4.4 GP.COMP -- compare two strings, ignoring case

###### 3.4.4 `GP.COMP` — compare two strings, ignoring case

```entry
  Syntax    GP.COMP(a$, b$)
  Returns   -1 if a$ sorts before b$, 0 the same, 1 after.
  Kind      ASM. Needs the GP block.
  Notes     Case is ignored. GP.COMP(A$, B$) = 0 is the case-blind
            equality test that = cannot do, and the same call orders
            a sort.
            Length breaks a tie: "abc" sorts before "ABCD".
  Example
```
```basic
            IF GP.COMP(N$, "QUIT") = 0 THEN GOTO BYE
```


## 3.4.5 GP.STRPTR -- address of a string block

###### 3.4.5 `GP.STRPTR` — address of a string block

```entry
  Syntax    GP.STRPTR(a$)
  Returns   Address of the string's [ActLen][Data] block.
  Kind      ASM. Needs the GP block.
  Notes     The length byte is at the address, the first character at
            +1, the block capacity at -2.
            With GP.CALL, machine code can fill a string in place and
            set its length. Stock BASIC cannot do that.
  WARNING   Split the address with GP.LOBYTE / GP.HIBYTE (§3.3),
            never with P AND 255. AND is 16-bit signed and the string
            heap is above 32,767, so P AND 255 raises OUT OF RANGE.
            The longhand H = INT(P / 256) : L = P - H * 256 is what
            the keywords compile to. The same applies to §3.5
            GP.ARRPTR and to any VRAM address in the top eighth of
            memory.
  Example
```
```basic
            P = GP.STRPTR(A$)
            GP.CALL $A000, GP.LOBYTE(P), GP.HIBYTE(P)
```


*See also: 3.3 Machine code, 3.5 Arrays*

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


*See also: 4.7 SORT.INC.BL -- shell sort a string array*

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

**More than one rectangle in a bank.** `STASH.SLOT` is a byte offset into the bank, default 0, and
`STASH.NEXT` comes back as the offset just past what was written. Feed one into the other and the
bank holds a stack of rectangles — which is what nested dialogs want, one bank for the lot rather
than one bank a level. Nothing checks that two saves do not overlap: the header describes a
rectangle's size, not its identity, so the offsets are yours to keep straight.

**`STASHVRAM.INC.BL` keeps rectangles in spare VRAM instead**, addressed by handle so a program can
hold many at once without counting offsets. It needs **no `#SYMFILE`**, because there is no
`GP.ASM` in it: the cells never leave VRAM, so one data port reads, the other writes, and
`memory_copy` moves between them. It executes no `BANK` either, so unlike `STASH` it runs inside a
`GP.BANKED` region. `STASHVRAMGC.INC.BL` closes the holes if a caller frees out of order, and is a
third file for the same dead-code reason.

---


*See also: STASH.INC.BL -- save a text rectangle, and put it back., STASHFILE.INC.BL -- a saved text rectangle, through a file., STASHVRAM.INC.BL -- screen rectangles and byte blobs, kept in VRAM., STASHVRAMGC.INC.BL -- close the holes in a STASHVRAM store.*

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

`GP.BOX` draws the frame only. Styles: 0 solid block, 1 single line, 2 single line with rounded
corners, 3 thick line. A style of 256 or more is an ADDRESS, not a style: eight screen codes of the
caller's own, in the table's order — see the custom glyph note below. `char` in `GP.FILL` is
PETSCII, e.g. `ASC(" ")`.

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


## 3.10 Text in a bank

##### 3.10 Text in a bank

```basic
GP.BANKEDSTR <bank> <NAME>
  "first"
  "second"
GP.ENDBANKEDSTR

  A$ = GP.BSTR(<NAME>, n)
  N  = GP.BSTRCOUNT(<NAME>)
```

Moves a program's literal text out of low RAM and into a RAM bank, at compile time. A string
constant costs `2 + LEN` bytes of p-code wherever it appears; `GP.BSTR(NAME, n)` costs **5**, so
text of four characters or more is cheaper read from the bank than written in the line. Over half
of a menu-driven program's own code is usually literal text, and text is the one thing in a
program with no reason to be resident: it is never executed, never indexed, and read one item at a
time.

**The body is bare quoted lines.** One string a line, nothing else on the line, and they pass
through byte for byte — case, leading spaces and trailing spaces included. They are not `REM`
lines and must not be: BASLOAD upper-cases `REM` text.

**Blocks are named, and you may write as many as you like.** Each is indexed from zero within
itself, so inserting a line in one group moves nothing outside it. All the groups in a program
share one bank, which is why every block names the same one — written on each block rather than
only the first so a block can be read where it sits.

**The name costs nothing at run time.** It is resolved while the program compiles, into the
group's first index, and the compiler adds that to your index for you. No letter of the name
reaches the object, which is the whole reason the lookup is not in the bank.

`GP.BSTRCOUNT(NAME)` is a composite: it compiles to a plain number, so
`FOR I = 0 TO GP.BSTRCOUNT(MENU.FILE) - 1` costs no more than writing the count out.

```basic
#DEFINE GM.TEXTBANK 5

GP.BANKEDSTR GM.TEXTBANK MENU.FILE
  " OPEN "
  " SAVE "
  " QUIT "
GP.ENDBANKEDSTR

GP.BANKEDSTR GM.TEXTBANK MENU.EDIT
  " CUT "
  " PASTE "
GP.ENDBANKEDSTR

  FOR I = 0 TO GP.BSTRCOUNT(MENU.EDIT) - 1
    PRINT GP.BSTR(MENU.EDIT, I)
  NEXT I
```

**Claim the bank**, exactly as a `GP.BANKED` code region's bank is claimed. The compiler picks it
while the object is written, so `BANKMGR` has to be told rather than asked:

```basic
BANKMGR.WANT = GM.TEXTBANK : GOSUB BANKMGR.CLAIM
```

**Compile SHARED.** The text is copied into its bank by the program's bootstrap, and an embedded
program has none — the same rule `GP.BANKED` works to. An embedded build is refused rather than
compiled into a program that reads an empty bank.

**A group name is not a variable.** No `$`, no `%`, no `(` — any of those is a syntax error rather
than something quietly ignored. A name that no block declared is a syntax error at the line that
used it, and so is a second block claiming a name already taken. An empty block is refused too: a
group of no strings would make `GP.BSTRCOUNT` zero and every `GP.BSTR` on it read the next group's
text.

**There is no run-time bounds check.** The compiler knows every index it emits and nothing a
program does can produce one out of range, so an index past the end of a group reads whatever
follows it. That is the same bargain the array fast path makes.

One bank of text a program, up to 8 KB of it, up to 128 groups. `GP.BSTR` is an ordinary GP
keyword, so it pulls in the 1 KB GP block; the two block keywords do not, and neither does
`GP.BSTRCOUNT`.

Reading it from inside a `GP.BANKED` region works: the handler puts the caller's bank back before
it returns.

---


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
| `THEME.LOAD` | `THEME.ID` | fills `THEME.CLR()` |
| `THEME.NEXT` | `THEME.ID` | the following theme, loaded |
| `THEME.RESET` | `THEME.ID` | the selected theme's shipped values, reloaded |
| `THEME.SET` | `THEME.ATTR` | issues `COLOR` — makes it the colour `PRINT` uses |
| `THEME.HI` | `THEME.ATTR` | `THEME.INV`, the inverse attribute |

Five themes, `THEME.COUNT` of them:

| `THEME.ID` | | |
|---:|---|---|
| 0 | `X16` | blue page, white text, cyan headings. The default |
| 1 | `DARK` | black page, light grey text |
| 2 | `LIGHT` | white page, black text |
| 3 | `GRAY` | dark grey page, light blue frames. From the XFMGR file manager |
| 4 | `CUSTOM` | whatever `THEME.CLR()` already holds |

`THEME.NEXT` moves to the following one and wraps, which is what a program binds to a key. A cached
attribute does not follow it: work out anything derived from `THEME.CLR()`, a reversed bar included,
after every load.

**`CUSTOM` loads nothing.** Selecting it leaves `THEME.CLR()` as it stands, so a program that lets
the user change colours carries those changes into `CUSTOM` rather than discarding them. The one
exception is a cold start — `CUSTOM` selected before any other theme has been loaded — where there
is nothing to keep and it takes `X16`'s values. `THEME.RESET` goes back to those.

`samples/color-test` edits all seven roles against a mock of the GUI and prints the
`THEME.CLR()` lines to paste back in here.

Roles, for indexing `THEME.CLR()`: `THEME.PAGE` `THEME.TEXT` `THEME.TITLE` `THEME.BORDER`
`THEME.HILITE` `THEME.DIMMED` `THEME.WARN`, and `THEME.SLOTS` = 7.

```basic
THEME.ID = 1 : GOSUB THEME.LOAD
GP.BOX 4,2,30,8, 2, THEME.CLR(THEME.BORDER)
GP.PRINTAT 6,3, "TITLE", THEME.CLR(THEME.TITLE)
```

The values are packed attributes, `background * 16 + foreground`, which is what `GP.BOX`, `GP.FILL`
and `GP.PRINTAT` take. For `COLOR`, which takes the halves separately, use `THEME.SET`.

`#DEFINE` substitutes at translation time, so `THEME.CLR(THEME.TITLE)` compiles to `THEME.CLR(2)`.
The readable name costs no variable and no lookup.

`THEME.CLR` is `DIM`med by the module. Do not `DIM` it in your own program.

Formatting a NUMBER into a column is `STRUSING.INC.BL` (§4.10), a separate
module: it needs no `#SYMFILE` and neither module depends on the other.


*See also: 4.10 STRUSING.INC.BL -- a number to a template, 4.1 THEME.INC.BL -- named colour roles*

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
| `STR.SPLICE` | `STR.STR$` `STR.AT` `STR.CUT` `STR.SUB$` | `STR.STR$`, edited at that position |
| `STR.TRIM` | `STR.PTR` | *(the string itself)*, spaces off both ends |
| `STR.LTRIM` | same | spaces off the **leading** end |
| `STR.RTRIM` | same | spaces off the **trailing** end |

**The module needs a `#SYMFILE`, and so does every program that includes it**, before the
`#INCLUDE`s and named after the source PRG. The three trims are `GP.ASM` and reach BASIC's
variables through `{VAR}`; without a symbol file the compile stops with `NO SYMBOL FILE FOR {}`.
This is new — the module was pure BASIC until the trims moved here out of `STRCASE.INC.BL`.

**The two halves take their argument differently, and one question decides which:** does the
routine GROW the string. The pads and `SPLICE` do, so they are BASIC — they take the string by
value in `STR.STR$` and hand it back there, and an assignment reallocates for free. The trims only
ever shrink, so they are assembly — they take its ADDRESS in `STR.PTR` and rewrite the block where
it lies, which is the only way a `GOSUB` can edit a caller's string without two allocations and two
copies a call. Never pass a literal to those: `GP.STRPTR("hello")` is an address inside the
p-code.
The three pad routines leave a string that is already at or past the width unchanged. They pad and
never truncate; use `STR.RTRIM` to shorten.

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

The three trims are three entry labels sharing one blob, so there is no mode to forget to set. A
zero-length string and an all-spaces string are not special cases: the walk counts down and
reaching zero is the answer.

`SPLICE` edits by POSITION where `REPLACE` edits by content: it replaces `STR.CUT` characters at
`STR.AT` with `STR.SUB$`. One routine covers all three of insert, overwrite and delete, because
they are the same operation with a different count — `STR.CUT` of 0 inserts, `LEN(STR.SUB$)`
overwrites, and an empty `STR.SUB$` deletes. `STR.AT` is 1-based, matching `GP.INSTR`.

Past the end appends and below 1 clamps to 1, both falling out of `LEFT$` and `MID$` rather than
being tested for; a cut running past the end takes the rest of the string. It is not length
checked, like `REPLACE` and the pads. `SPLICE` clamps `STR.AT` and `STR.CUT` in place, so read them
back rather than assuming what you set survived the call.

It was written in `GP.ASM` first and rewritten in BASIC, which is worth knowing because the reason
generalises: the assembly could overwrite and delete but never insert, because in-place work cannot
grow a string, and it cost about 280 bytes of p-code where the one BASIC line costs about 40.

Examples: [`SPLITT.EXP.BL`](SPLITT.EXP.BL), [`STRINGS.EXP.BL`](STRINGS.EXP.BL). Regression test:
[`STRTST.EXP.BL`](STRTST.EXP.BL), thirty-three cases — the trim edges, every splice mode, both
clamps, appending past the end, splicing an empty string, growing a 200-character string past the
block it was born with, and guard strings either side to catch an off-by-one write into the
neighbouring block.


*See also: 4.2 STRINGS.INC.BL -- string helpers, 4.8 STRCASE.INC.BL -- case, in place*

## 4.3 APPSYS.INC.BL -- start politely, leave it as you found it

##### 4.3 `APPSYS.INC.BL` — start politely, leave it as you found it

| Routine | in | out |
|---|---|---|
| `APPSYS.STARTUP` | — | `APPSYS.MODE` `APPSYS.COLS` `APPSYS.ROWS` `APPSYS.COLOUR` |
| `APPSYS.RESTORE` | those | screen mode and colour put back |
| `APPSYS.ISEMU` | — | `APPSYS.IS.EMULATOR` — -1 under x16emu, 0 otherwise |

```basic
A screen rectangle through a file is `STASH.FILE.SAVE` / `.LOAD` / `.PUT` in `STASHFILE.INC.BL`.

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

`APPSYS.ISEMU` answers the question a timing loop has to ask. `$9FBE` and `$9FBF` are the last of
the emulator's own I/O registers and read as `"1"` and `"6"` under x16emu, with the debugger on or
off; the routine is those two `PEEK`s and a comparison.

```basic
GOSUB APPSYS.ISEMU
IF APPSYS.IS.EMULATOR THEN PRINT "EMULATED"
IF NOT APPSYS.IS.EMULATOR THEN PRINT "NOT x16emu"
```

**The flag is -1, not 1**, so `NOT` works on it: `NOT` is `-x-1` here, so `NOT -1` is 0 while
`NOT 1` is -2 — still true. -1 is also what a comparison hands back, so the flag reads like one.
`IF` itself tests non-zero, so either value would have worked with the plain form.

**It answers for x16emu and nothing else.** A 0 means "not x16emu" — a real machine, or another
emulator that does not carry those registers. And `$9FA0-$9FBF` is expansion card I/O on the real
machine, so a card at I/O5 could in principle answer `"16"` as well: a 1 is strong, a 0 is
certain.


*See also: 4.3 APPSYS.INC.BL -- start politely, leave it as you found it, STASHFILE.INC.BL -- a saved text rectangle, through a file.*

## 4.4 LINEINPUT.INC.BL -- a positioned entry field

##### 4.4 `LINEINPUT.INC.BL` — a positioned entry field

| Routine | in | out |
|---|---|---|
| `LINEINPUT.GET` | `LINEINPUT.X` `.Y` `.LEN` `.ATTR` `.TEXT$` `.MASK` `.ALLOW$` `.DENY$` | `LINEINPUT.TEXT$` `LINEINPUT.KEY` |
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

`LINEINPUT.ALLOW$` and `LINEINPUT.DENY$` restrict what may be typed. Both are empty by default, and
the field then takes any printable character, as it always has. `ALLOW$` lists the characters
accepted and `DENY$` the ones refused; a caller that sets both gets `ALLOW$`, and `DENY$` is not
consulted. A refused key changes nothing — not the text, and not the caret.

They compare raw bytes, so a set of LETTERS depends on the charset: PETSCII shifted letters arrive
as `$C1-$DA` and ISO ones as `$41-$5A`, and an `ALLOW$` written for one silently refuses every
capital in the other. Digits are 48-57 in both. Use `ALLOW$` for a closed set short enough to write
out, `DENY$` for everything-except:

| Field | Spelling |
|---|---|
| Digits only | `ALLOW$ = "0123456789"` |
| Number with sign and point | `ALLOW$ = "0123456789.-"` |
| Yes or no | `ALLOW$ = "YyNn"` |
| Letters, no digits | `DENY$ = "0123456789"` |
| Filename, no punctuation | `DENY$ = ",:=*?"` |

Both are sticky, like every other input in the library, so a form sets them on the way into each
field rather than once at the top.

Example: [`FORM.EXP.BL`](FORM.EXP.BL) — three fields, one masked and one digits-only, in a themed panel.


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

`SORT.OK` is -1 when it sorted and 0 if the sort was refused: more than 255 elements, so `DIM A$(254)` is the largest
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

## 4.8 STRCASE.INC.BL -- case, in place

##### 4.8 `STRCASE.INC.BL` — case, in place

| Routine | in | out |
|---|---|---|
| `STRCASE.GO` | `STRCASE.PTR` `STRCASE.MODE` | *(the string itself)* |

```
#SYMFILE "@:MYPROG.SYM"
#INCLUDE "STRCASE.INC.BL"

STRCASE.PTR = GP.STRPTR(LINE$)
STRCASE.MODE = STRCASE.UPPER
GOSUB STRCASE.GO
```

| mode | does |
|---|---|
| `STRCASE.UPPER` | a–z → A–Z, everything else untouched |
| `STRCASE.LOWER` | A–Z → a–z, everything else untouched |

One blob, with the mode tested once at entry rather than inside the loop, where the byte count is
the whole cost.

The argument is an address because a BASL subroutine cannot be passed a variable. Copying the
**`TRIM`, `LTRIM` and `RTRIM` were here** and are `STR.TRIM` / `STR.LTRIM` / `STR.RTRIM` in
`STRINGS.INC.BL` (§4.2) now. They are string editing rather than case work, and every other
string routine already lived in that one module. A program that only trims does not need this file
at all; one that only folds case saves 113 bytes of p-code by the move.

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
[`STRCTST.EXP.BL`](STRCTST.EXP.BL), eight cases — empty, one character, 200 characters, and guard
strings either side to catch an off-by-one write into the neighbouring block. The trim cases moved
with the trims, to [`STRTST.EXP.BL`](STRTST.EXP.BL).

---


*See also: 4.2 STRINGS.INC.BL -- string helpers, 4.8 STRCASE.INC.BL -- case, in place*

## 4.10 STRUSING.INC.BL -- a number to a template

##### 4.10 `STRUSING.INC.BL` — a number to a template

| Routine | in | out |
|---|---|---|
| `STR.USING` | `STR.USING.NUM` `STR.USING.MASK$` | `STR.USING.STR$`, a field |
| `STR.USING.FIX` | `STR.USING.NUM` `STR.USING.DP` | `STR.USING.STR$`, digits only |

```basic
#INCLUDE "STRUSING.INC.BL"

STR.USING.NUM = 1234.5 : STR.USING.MASK$ = "#,##0.00"
GOSUB STR.USING
PRINT STR.USING.STR$                    ' 1,234.50
```

Pure BASIC. It needs no `#SYMFILE` and depends on no other module, so a program can take it
without taking `STRINGS.INC.BL` (§4.2) — and the other way round.

| In the mask | Means |
|---|---|
| `#` | a digit position, **space** if the number does not reach it |
| `0` | a digit position, **zero** if the number does not reach it |
| `.` | the decimal point everything aligns on |
| `,` | anywhere in the mask, groups the integer part in threes |
| `+` | first character only: a sign column, `+` or `-` |
| `-` | first character only: a sign column, `-` or a space |

`PRINT USING`'s mask, from BASIC 7.0, less the four characters that earn nothing here: `$`
floating currency, a trailing sign, `^^^^` exponential, and `=` / `>` — those last two justify a
**string**, which is `STR.PADC` and `STR.PADL` (§4.2).

**The result is exactly `LEN(STR.USING.MASK$)` characters, right justified**, so a column of them
lines up on the point. Everything after the point prints, so `#` and `0` do not differ there. A
point with no digit positions after it is ignored.

```
"###0.00"    12.5    ->  "  12.50"        "#,##0.00"   1234.5  ->  "1,234.50"
"0000.00"    12.5    ->  "0012.50"        "+##0.00"      -1.5  ->  "-  1.50"
"##000"        42    ->  "  042"          "##0"         12345  ->  "***"
```

**Too wide fills the whole field with `*`.** That is deliberate and visible; overflowing the width
instead would push the rest of the row along and misalign every column after it. A negative value
with **no** sign column spends one digit position on its minus, and stars when there is none to
spend — `"##0"` holds `-12` but not `-123`.

**Rounding is half away from zero**, done on the absolute value before the sign goes back on.
`INT` alone floors toward minus infinity, which rounds `-1.5` and `1.5` in opposite directions.
`-0.004` to two places is `"0.00"`, not `"-0.00"`: a signed zero in a column reads as a real
negative.

**WARNING: the value must scale to under 1,000,000,000.** The digits are built by multiplying up
by `10 ^ DP` and rounding, and `STR$` turns over to E notation at 1e9 — so two decimal places
reach `9,999,999.99` and five reach `9,999.99999`. Past that the field fills with `*` rather than
printing something wrong.

`STR.USING.FIX` is the same digits with no field over them: `STR.USING.NUM` to `STR.USING.DP`
places, sign attached, no leading space. Right justify it with `STR.PADL` if you want a column.

**The digits do not come out of `STR$`'s fraction, and cannot.** `STR$` trims trailing zeros, so
`12.30` comes back as `"12.3"`; it drops the leading zero of a pure fraction, so a half is `" .5"`;
and it takes *significant digits*, never decimal places — `FloatToString` records that a
fixed-decimal mode was tried and printed `12345678.9` as `12345678.8984375`. So a scaled integer is
the only exact route, and the 1e9 ceiling above is its price.

Cost: **726 bytes** of p-code, of which `STR.USING.FIX` alone is **205**. Its own module rather
than a routine in `STRINGS.INC.BL` for that reason — a program wanting `STR.PADL` and a split
should not carry a mask parser.

Example: [`STRUSING.EXP.BL`](STRUSING.EXP.BL). Regression test:
[`USINGT.EXP.BL`](USINGT.EXP.BL), thirty-nine cases — both entry points, every mask character,
the rounding traps, the sign column and both overflows. Text and length are compared every time:
the result is a field, so a right answer in the wrong number of columns still breaks the table.

---


*See also: 4.2 STRINGS.INC.BL -- string helpers, 4.10 STRUSING.INC.BL -- a number to a template*

## GUI.INC.BL -- four dialogs, in a box that puts the screen back.


*From the banner header of `GUI.INC.BL`.*

```
  BASIC crunched.

      GUI.SAY      something to say, and one way out
      GUI.YN       a question, and a Y or N answer
      GUI.MENU     a question, and a row chosen from a list
      GUI.INPUT    a question, and a line of typed text

  Requires, and #INCLUDEs none of them, in this order:
      GPB.INC.BL        GP.BOX, GP.FILL, GP.PRINTAT, GP.CALL
      STASH.INC.BL      saves the covered cells; wants a #SYMFILE
      THEME.INC.BL      GOSUB THEME.SELECT first
      MENUVERT.INC.BL   GUI.MENU
      LINEINPUT.INC.BL  GUI.INPUT
  All five, whichever dialog you call: BASLOAD resolves every label in the
  file, so leaving one out is LABEL NOT FOUND.

      THEME.ID = 0 : GOSUB THEME.SELECT
      GUI.BANK = 8
      GUI.MSG$ = "Delete the file?"
      GOSUB GUI.YN
      IF GUI.ANSWER THEN <yes>

   in   GUI.MSG$        the question. "" for none
        GUI.MSG2$       a second line. "" for none, and then no gap
        GUI.TITLE$      a name in the top edge. "" for none
        GUI.BANK        a spare RAM bank for the covered cells. 0 does not
                        save, and the box is still on screen on return.
                        Over GUI.MAXCELLS does not save either
        GUI.STYLE       0 is the rounded single line. 1 to 3 are GP.BOX's
        GUI.PANEL.IN    the box background, and the message lines' colour.
                        0 takes THEME.TEXT
        GUI.BORDER.IN   the frame's attribute. 0 takes THEME.BORDER
        GUI.GLYPH       non-zero frames from the caller's six glyphs, and
                        GUI.STYLE is not consulted. Tile indices:
                            GUI.EDGE.H      the horizontal run
                            GUI.EDGE.V      the vertical run
                            GUI.CORNER.TL   .TR  .BL  .BR
        GUI.PLACE       0 centres. Non-zero uses GUI.X, GUI.Y
        GUI.X  GUI.Y    top left, when GUI.PLACE says so
        GUI.ROW.OFFSET  added to the box's row. VSCROLL/8 under hardware
                        scrolling, 0 otherwise

   out  GUI.KEY         the key that ended it, whichever call
        GUI.STASHED     -1 if the covered cells were saved
        GUI.LEFT GUI.TOP GUI.WIDTH GUI.HEIGHT   where the box went

  WARNING: upper case, on the default charset. GP.PRINTAT converts PETSCII
  and BASLOAD passes literals through as source bytes, so charset 2 lands
  lower case on the graphics half of the font. ISO mode fixes the text and
  breaks the frame, GP.BOX's $40-$7D being letters. Upper case with a
  frame, mixed case without one, or re-order the font and set GUI.GLYPH.

  GUI.LISTBOX.* is GUI2.INC.BL, its own #INCLUDE.
```

*See also: STASH.INC.BL -- save a text rectangle, and put it back., 4.1 THEME.INC.BL -- named colour roles, 4.6 MENUVERT.INC.BL -- a vertical menu, 4.4 LINEINPUT.INC.BL -- a positioned entry field, GUI2.INC.BL -- a listbox, single or multi select.*

## GUI2.INC.BL -- a listbox, single or multi select.


*From the banner header of `GUI2.INC.BL`.*

```

      GUI.LISTBOX   a window onto a list longer than the box, and
                    optionally more than one answer

  Separate from GUI.INC.BL: nothing else in the library wants a scrolling
  window or a set of marks. #INCLUDE it only when you want a listbox.

  Requires, and #INCLUDEs none of them, in this order:
      GPB.INC.BL        GP.FILL, GP.PRINTAT, GP.STRPTR, GP.SELECT
      STASH.INC.BL      via GUI.OPEN; wants a #SYMFILE
      THEME.INC.BL      GOSUB THEME.SELECT first
      MENUVERT.INC.BL   MENUVERT.ROW draws the rows
      GUI.INC.BL        GUI.OPEN and GUI.CLOSE are the box

      DIM MENUVERT.ITEM$(200)
      ... fill 1..N ...
      GUI.LISTBOX.COUNT = N : GUI.LISTBOX.ROWS = 8 : GUI.LISTBOX.MULTI = 1
      GUI.MSG$ = "PICK FILES" : GUI.BANK = 8
      GOSUB GUI.LISTBOX
      IF GUI.LISTBOX.SEL = 0 THEN <cancelled>

   in   GUI.LISTBOX.COUNT   how many items. 0 or less returns cancelled
        MENUVERT.ITEM$()    the items, 1..COUNT, and the caller DIMs it
        GUI.LISTBOX.ROWS    rows visible at once. 0 takes 10, and it is
                            cut to COUNT and to what the screen holds
        GUI.LISTBOX.MULTI   0 chooses one row. 1 marks a set with SPACE
        GUI.LISTBOX.MARKS$  multi only, in as well as out: COUNT
                            characters, "1" marked. Any other length --
                            "" included -- starts with none marked
        GUI.LISTBOX.SEL     the item to start on. 0 starts at 1
        plus everything GUI.OPEN reads: GUI.MSG$, GUI.MSG2$, GUI.TITLE$,
        GUI.BANK, GUI.STYLE, GUI.GLYPH, GUI.PLACE and the rest

   out  GUI.LISTBOX.SEL     the item under the highlight, 1..COUNT, or 0
                            if cancelled. In multi that is where the cursor
                            was, not the answer -- the marks are the answer
        GUI.LISTBOX.MARKS$  multi only: COUNT characters, "1" marked
        GUI.LISTBOX.MARKED  multi only: how many are marked
        GUI.KEY             13 accepted, 27 or 3 cancelled

  Keys: up and down move, PgUp and PgDn page, HOME and END jump, SPACE
  toggles a mark in multi, RETURN accepts, ESC and STOP cancel.

  The bottom frame edge is "2 SELECTED OF 20" in multi, "20 ITEMS" for a
  single list too long to see at once, and blank for one that fits.

  The hint row is GUI.INPUT's, in GUI.INPUT's words and at its two
  offsets. It costs the body a spacer row and a hint row, and the box a
  minimum width of 26.

  The marks are one string, toggled in place through GP.STRPTR, so SPACE
  POKEs a byte and allocates nothing. WARNING: that caps the list at 250
  items, which is what a string holds.

  The window is MENUVERT.SCROLL: screen row R draws ITEM$(SCROLL + R), so
  the drawing is MENUVERT.ROW unchanged and this file only decides what
  SCROLL is.

  In multi the rows are indented two columns and the mark column belongs
  to this file, so the caller's array is never touched.

  WARNING: no #DEFINEs and no include guard in here. BASLOAD rejects a
  digit in a #DEFINE or #IFNDEF name, so a GUI.LISTBOX.* constant cannot
  exist. The numbers are written where they are used. #INCLUDE this once.
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

  A separate file rather than a flag on MENUVERT: there is no dead code
  elimination, so a horizontal path inside MENUVERT would be carried by every
  vertical menu.

  IT SHARES MENUVERT'S ARRAY AND COLOURS -- MENUVERT.ITEM$, .ATTR, .HIATTR,
  .HOTATTR, .HOT$ -- so a program with a bar and a dropdown has one convention.

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
  MENUBAR.WIDTH. That is the difference from MENUVERT.

  UP AND DOWN ARE OPTIONAL EXITS, off by default: a bar over dropdowns wants DOWN
  to end it so the caller can open the panel, and a bar that is only a bar wants
  it ignored. Off means an arrow across the grain does nothing.
```

*See also: 4.6 MENUVERT.INC.BL -- a vertical menu*

## STASH.INC.BL -- save a text rectangle, and put it back.


*From the banner header of `STASH.INC.BL`.*

```

      STASH.SAVE      copy a rectangle of the screen into a RAM bank
      STASH.RESTORE   copy it back, where it was or somewhere else

  The same rectangle through a FILE is STASHFILE.INC.BL, built on this.

  The program needs a #SYMFILE, before the includes and named after the source
  PRG. The assembly reaches BASIC's variables through {VAR} and BASLOAD crunches
  every name first; without one the compile stops with "NO SYMBOL FILE FOR {}".

      #SAVEAS "@:MYPROG.PRG"
      #SYMFILE "@:MYPROG.SYM"
      #INCLUDE "GPB.INC.BL"
      #INCLUDE "STASH.INC.BL"

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

        STASH.SLOT     byte offset into the bank. Default 0, which is what
                       every caller that never heard of it holds

   out  STASH.OK       -1 if it fitted and was saved, 0 if not
        STASH.NEXT     the offset just past what was written

  RESTORE needs only the bank: four header bytes go in first -- w, h, x, y --
  so the rectangle describes itself. STASH.MOVE = 1 with STASH.X / STASH.Y
  pastes it somewhere else instead.

  A bank is 8,192 bytes and a cell is two, so 4,094 cells fit -- 63x63, and
  NOT a whole 80x60 screen. Too big is refused before the first write, with
  STASH.OK = 0.

  MORE THAN ONE RECTANGLE IN A BANK. Feed STASH.NEXT back in as the next
  STASH.SLOT and the bank holds a stack of them, which is what nested
  dialogs want -- one bank for the lot rather than one bank a level. That
  is a bump allocator in two variables, and release is LIFO by remembering
  the offset. STASHVRAM.INC.BL allocates the same way.

  RESTORE READS THE SLOT IT IS GIVEN. Nothing checks that two saves do not
  overlap and nothing records which is which: the header describes a
  rectangle's SIZE, not its identity, so restoring the wrong offset
  restores whatever is there. The offsets are the caller's to keep
  straight, the same way the bank number already is.

  A row's address is worked out in BASIC, once a row, and the row is copied in
  assembly. That keeps the assembly free of any pointer needing zero page: a blob
  runs with the interpreter live, so codePtr, zTemp0, NSStatus and the mantissas
  must survive it. The destination goes into the OPERAND of the store instead.

  #REM 1 is load bearing: without it BASLOAD strips the body and the block reaches
  the compiler empty, refused as "block mismatch". #REM 0 restores the default.
```

*See also: STASHFILE.INC.BL -- a saved text rectangle, through a file., STASHVRAM.INC.BL -- screen rectangles and byte blobs, kept in VRAM.*

## STASHFILE.INC.BL -- a saved text rectangle, through a file.


*From the banner header of `STASHFILE.INC.BL`.*

```

      STASH.FILE.SAVE   a rectangle of the screen, out to a file
      STASH.FILE.LOAD   a saved file, back where it came from
      STASH.FILE.PUT    a saved file, pasted somewhere else

  Requires, and does not #INCLUDE for you:
      GPB.INC.BL      GP.ASM
      STASH.INC.BL    which does the copying, and wants a #SYMFILE

  Usage:
      STASH.BANK = 8 : STASH.FILE$ = "PANEL.BIN"
      STASH.X = 10 : STASH.Y = 4 : STASH.W = 30 : STASH.H = 8
      GOSUB STASH.FILE.SAVE
      ...
      GOSUB STASH.FILE.LOAD

   in   STASH.FILE$    the name
        STASH.DEV      the device. 0 means 8
        STASH.BANK     the bank to stage through
        and, for SAVE, the geometry STASH.SAVE wants

  The four header bytes go out with the cells, so loading one back needs
  nothing but the name.

  BSAVE's end address is EXCLUSIVE, so this writes the header and the cells
  and no padding. The length is w * h * 2 + 4.
```

*See also: STASH.INC.BL -- save a text rectangle, and put it back.*

## BANKMGR.INC.BL -- who owns which RAM bank.


*From the banner header of `BANKMGR.INC.BL`.*

```
  FYI: File has been semi crunched to save some bytes

      BANKMGR.INIT     ask the machine how many banks it has
      BANKMGR.CLAIM    take a named one, or fail
      BANKMGR.ALLOC    take the lowest free one
      BANKMGR.RELEASE  give one back
      BANKMGR.COUNT    how many exist, how many are free

  For a program with several owners of banked RAM, none of which can see
  the others' numbers. Requires GPB.INC.BL, and does not #INCLUDE it.

  Usage, and the order matters:
      GOSUB BANKMGR.INIT
      BANKMGR.WANT = 2 : GOSUB BANKMGR.CLAIM
      IF BANKMGR.OK = 0 THEN <bank 2 was already taken>
      GOSUB BANKMGR.ALLOC
      IF BANKMGR.BANK = 0 THEN <none left>

   in   BANKMGR.WANT    the bank CLAIM or RELEASE acts on

   out  BANKMGR.BANKS   how many the machine has, 64 or 256
        BANKMGR.BANK    what ALLOC handed out. 0 MEANS NONE LEFT
        BANKMGR.OK      -1 if CLAIM took it, 0 if taken or out of range
        BANKMGR.SPARE   what COUNT found free

  0 is not a bank. It is the KERNAL's, reserved by INIT, and it is what
  ALLOC returns for "none left".

  WARNING: MEMTOP RETURNS $00 ON A 2MB MACHINE. The count is one byte and 256
  does not fit, so 512K reads $40 = 64 and 2MB reads $00, meaning 256. INIT
  reads 0 as 256. A manager that took 0 at face value would report no banks on
  exactly the larger machine. Values that are not a multiple of 8 are legal --
  the reference names $42 -- and mean some banked RAM is bad.

  It tracks, it does not select. Nothing here executes BANK. A claim is a
  promise between the program's own modules, and an accessor still sets its
  own bank on every access.
```

## FILEDIR.INC.BL -- a directory, into a bank or into low RAM.


*From the banner header of `FILEDIR.INC.BL`.*

```

      FILE.DIR.INIT   once, before anything else here
      FILE.DIR.OPEN   read the whole listing into the buffer
      FILE.DIR.NEXT   the next entry out of it

  Requires GPB.INC.BL and FILEIO.INC.BL, and #INCLUDEs neither.

  THE THREE ENTRY POINTS ARE SPELLED .BODY HERE, and the names above are the
  shims in LIBBANK.INC.BL. This copy of the module lives in a GP.BANKED region
  -- MENUVERT.INC.BL beside it is written the same way for the same reason. A
  program that wants it in low memory calls the .BODY labels directly and needs
  no shim.

  A shim leaves ITS bank selected on return, by LIBBANK's design, so a banked
  build does not preserve the caller's RAM bank across a call here. The blobs
  preserve the bank they are entered with; the shim in front of them does not.

      #SYMFILE "@:MYPROG.SYM"   <- required, before the #INCLUDEs.

   in   FILE.DIR.BANK     the bank to read into, or 0 for low RAM
        FILE.DIR.PTR      the low RAM buffer, when BANK is 0
        FILE.DIR.CAP      how many bytes that buffer holds
        FILE.DIR.PATTERN$  a name pattern, or empty for all
        FILE.DIR.ONLY     FILE.DIR.ALL, FILE.DIR.FILES, FILE.DIR.DIRS
        FILE.DEVICE       the drive, from FILEIO. 0 means 8

   out  FILE.DIR.GOT      bytes read. 0 is an empty or failed listing
        FILE.DIR.FULL     the buffer filled before the listing ended
        FILE.DIR.SLOW     1 if the device had no MACPTR and the read
                          fell back to CHRIN a byte at a time
        FILE.DIR.MORE     -1 while NEXT produced an entry, 0 at the end
        FILE.NAME$        the entry
        FILE.BLOCKS       its size in blocks
        FILE.TYPE$        PRG, SEQ or DIR

  internal  FILE.DIR.AT FILE.DIR.ASK$ FILE.DIR.ADDR% FILE.DIR.ROOM%
            FILE.DIR.OFF% FILE.DIR.BYTES% FILE.DIR.CNT% FILE.DIR.BLK%
            FILE.DIR.OK% FILE.DIR.SLOW% FILE.DIR.LFN% FILE.DIR.NAMEA%
            FILE.DIR.WAS% FILE.DIR.BNK%
            FILE.DIR.TYPEA%

  Two destinations, one code path: the reader takes an address and a size.

      a bank    FILE.DIR.BANK = BANKMGR.BANK
                8,192 bytes at $A000, about 250 entries

      low RAM   FILE.DIR.BANK = 0
                DIM FD.BUF%(1022)
                FILE.DIR.PTR = GP.ARRPTR(FD.BUF%())
                FILE.DIR.CAP = 1023 * 2

  WARNING: a % array is TWO bytes an element, not six. The recipe here said
  six until 07/09/26 and sized a 682-byte buffer as 2,046 -- a caller
  following it handed the assembly three times the room it had, and the
  reader would have run 1,364 bytes off the end of the array and into
  whatever the workspace put after it. An untyped array is the six.

  FILE.DIR.BANKBASE and FILE.DIR.BANKROOM are the hardware window, not an
  allocation: every bank appears at $A000 and every bank is 8,192 bytes.
  The bank NUMBER is the resource. Take it from BANKMGR.ALLOC and put it in
  FILE.DIR.BANK. This module claims no bank and executes no BANK statement.

  THE WINDOW IS SWITCHED IN ASSEMBLY, NOT IN BASIC, and that is what lets this
  module live in a GP.BANKED region. The two blobs take the data bank at entry
  and put the caller's back on every exit; no BASIC line here ever runs with a
  foreign bank selected. A BANK statement in banked p-code is refused by the
  compiler, and one either side of a GOSUB would leave the return fetching its
  next byte from the data bank. FILE.DIR.BNK% carries the bank to the assembly
  because {VAR} on the untyped FILE.DIR.BANK would read a float's mantissa.

  The drive does the filtering. Do not write a pattern matcher.

      FILE.DIR.PATTERN$ = "GAME*"
      FILE.DIR.ONLY = FILE.DIR.FILES

  A listing arrives as a fake BASIC program: two bytes of load address, then
  per entry a two byte link, a two byte line number that is the block count,
  the text, and a NUL. The blocks-free line at the end carries no quoted
  name, so running out of quotes is the end. FILE.DIR.AT starts at 4.

 ---- traps ----

  Read once, walk many times. Going back to the drive to scroll or filter is
  the cost, not the parsing.

  The disk name is not an entry. Every listing opens with the volume line,
  which parses exactly like a file. FILE.DIR.OPEN swallows it.

  FILE.NAME$ and FILE.TYPE$ are written in place, not assigned. Do not
  assign either after FILE.DIR.INIT: an assignment reallocates and the block
  the assembly holds goes stale.

  FILE.NAME$ is shared with FILEIO, so any FILEIO call destroys a walk in
  progress. Copy the name out per entry.

  FILE.DIR.NAMEMAX is the name length and the assembly has the same number
  as a literal. Change both.

  MACPTR is asked for at most 255 bytes a call, so its returned count fits
  one byte. It can return fewer than asked for. Carry set means the device
  has no MACPTR and the read falls back to CHRIN, setting FILE.DIR.SLOW;
  that path is untested, no device here refuses MACPTR.

  MACPTR wraps banks by itself and leaves the new one selected. This module
  stops at the end of its one bank, so a listing cannot spill into a bank it
  does not own.
```

*See also: FILEIO.INC.BL -- the drive: status, files, directories., LIBBANK.INC.BL -- the low memory front door to a banked library., 4.6 MENUVERT.INC.BL -- a vertical menu*

## FILEIO.INC.BL -- the drive: status, files, directories.


*From the banner header of `FILEIO.INC.BL`.*

```

      FILE.STATUS     read the command channel
      FILE.EXISTS     is FILE.NAME$ on the drive
      FILE.DELETE     scratch it, pattern allowed
      FILE.RENAME     FILE.NAME$ -> FILE.NEW$
      FILE.COPY       one drive only
      FILE.MKDIR      make a subdirectory
      FILE.CHDIR      change to one
      FILE.UP         change to the parent
      FILE.CURDIR     the current directory, into FILE.PATH$
      FILE.SAVEARRAY  FILE.LINE$() out to a SEQ file
      FILE.LOADARRAY  and back

  Requires GPB.INC.BL, and does not #INCLUDE it.

      #SYMFILE "@:MYPROG.SYM"   <- required, before the #INCLUDEs.

  FILE.TOPET is GP.ASM and reaches FILE.PETP% through {VAR}. Without a
  #SYMFILE the compile stops at NO SYMBOL FILE FOR {}.

   in   FILE.NAME$     the file acted on
        FILE.NEW$      the second name, RENAME and COPY
        FILE.DEVICE       the drive. 0 means 8
        FILE.ISO       non-zero folds names to PETSCII on the way out
        FILE.N         rows to write, SAVEARRAY
        FILE.MAX       rows that fit, LOADARRAY. 0 means 10
        FILE.LINE$()   the rows. The caller owns the DIM

   out  FILE.ERR       error number. Under 20 is success
        FILE.MSG$      the drive's text
        FILE.TRK       FILE.SEC   the two trailing fields
        FILE.OK        FILE.EXISTS
        FILE.N         rows read, LOADARRAY
        FILE.PATH$     FILE.CURDIR

  internal  FILE.CMDSTR$ FILE.OUT$ FILE.RAW$ FILE.ROW$ FILE.ST FILE.KEEP
            FILE.I FILE.PETP%

  FILE.ERR is DS and FILE.MSG$ is DS$. The X16 has neither.

  FILE.N is an input to SAVEARRAY and an output from LOADARRAY.
  FILE.LINE$() is the caller's DIM, like MENUVERT.ITEM$. Left alone the
  implicit DIM gives 0..10.

  This module takes logical file 14 and secondary address 14. Not 2 or 3:
  those belong to the editor, GPC-HELP and the cruncher. The two are equal
  so a later FILE.SEEK needs no reopen -- see the P and T note below.

  Error under 20 is success. 0 is OK. 1 is "files scratched" and carries
  the count in FILE.TRK. 62 is FILE NOT FOUND, 63 FILE EXISTS, 26 WRITE
  PROTECT.

 ---- WARNING: ST IS NOT A DISK STATUS ----

  LINPUT# on a channel whose OPEN found nothing returns CHR$(0) with
  ST = 66, and keeps doing so.

  ST is 64 before a program's first statement: LOAD leaves bit 6 set.

 ---- traps ----

  Read the command channel or the next OPEN misbehaves. The drive holds
  its error state until channel 15 is read. Every routine here ends by
  reading it.

  FILE.RENAME onto a name that exists returns 62, not 63, which is what a
  missing source also returns. Test with FILE.EXISTS first.

  FILE.COPY is one drive. C:new=old cannot cross devices. It takes a comma
  list, so it also concatenates.

  FILE.SAVEARRAY overwrites, with @: on the open.

  FILE.DELETE takes a pattern. S:*.BAK scratches every match.

  The last row of a file arrives with ST already set, so a row is stored
  before the loop ends. A blank final line is indistinguishable from end
  of file and is dropped.

 ---- random access ----

  CMDR-DOS has no REL files. Use ,M open mode with P and T on channel 15:

      OPEN 1,8,2,"LEVEL.DAT,S,R"
      OPEN 15,8,15,"P"+CHR$(2)+CHR$(0)+CHR$(1)+CHR$(0)+CHR$(0)

  T returns the position and the file size. The data channel's secondary
  address must equal the P or T channel argument. VAL("$"+MID$(A$,10)) from
  the manual returns 0 here: VAL stops at the first non-numeric character,
  so parse the eight hex digits by hand.
```

## KB.INC.BL -- the keyboard buffer, emptied.


*From the banner header of `KB.INC.BL`.*

```

      KB.CLEARKB     throw away whatever is already typed

  Requires GPB.INC.BL, and does not #INCLUDE it for you.
```

## LIBBANK.INC.BL -- the low memory front door to a banked library.


*From the banner header of `LIBBANK.INC.BL`.*

```

      THEME.SELECT
      MENUVERT.RUN    MENUVERT.DRAW   MENUVERT.ROW
      MENUBAR.RUN     MENUBAR.DRAW    MENUBAR.ITEM
      MENUBAR.MARK    MENUBAR.WHERE
      LINEINPUT.GET   LINEINPUT.ASK
      GUI.SAY         GUI.YN          GUI.MENU        GUI.INPUT
      GUI.OPEN        GUI.CLOSE       GUI.LISTBOX

  Eighteen shims. Each selects the code bank and calls the body, which lives
  at $A000 in that bank under a .BODY name. A banked routine cannot select
  its own bank -- by its first instruction fetch the window is already wrong
  -- so something in low memory has to.

  Usage:
      #INCLUDE "LIBBANK.INC.BL"        ' before the region
      GOTO MY.LIBEND
      GP.BANKED LIB.CODEBANK
      #INCLUDE "THEME.INC.BL"
      #INCLUDE "MENUVERT.INC.BL"
      #INCLUDE "MENUBAR.INC.BL"
      #INCLUDE "LINEINPUT.INC.BL"
      #INCLUDE "GUI.INC.BL"
      #INCLUDE "GUI2.INC.BL"
      GP.ENDBANKED
      MY.LIBEND:

  Claim the bank as well, or something else will hand it out:
      BANKMGR.WANT = LIB.CODEBANK : GOSUB BANKMGR.CLAIM

  All seven modules are required, even by a program that calls one of them.
  This file shims every entry point and BASLOAD resolves every label in a
  file, so leaving MENUBAR out stops the build with LABEL NOT FOUND.

  Order inside the region is the order the modules already want: THEME
  first, MENUVERT before MENUBAR, both before GUI.

  FILEDIR IS SHIMMED BY LIBBANKFD.INC.BL, not by this file, and that split
  is not tidiness: BASLOAD resolves every label in every file it reads, so
  a FILE.DIR shim here stops the build with LABEL NOT FOUND in any program
  that does not also include FILEDIR. Include both when you bank a
  directory reader, and FILEDIR goes last inside the region.

  The GOTO over the region is not optional. Falling in through the bridge
  GP.BANKED leaves works at program start and stops working the day
  anything selects another bank first.

  WARNING: LIB.CODEBANK is not GUI.BANK. That one is scratch, where
  GUI.OPEN stashes the cells a dialog covers. Point both at one bank and
  the dialog writes the screen over its own code.

  WARNING: anything holding a BANK, BLOAD or BSAVE stays in low memory --
  the compiler refuses them inside a region, because code fetched from the
  window cannot be running when the window changes. That is STASH and
  STASHFILE here. The GUI reaches both by an ordinary GOSUB downwards,
  which works because low memory does not care which bank is selected.

  A call leaves the code bank selected, and the shims do not put the
  caller's back. A single holding variable would be overwritten by a nested
  call. Low memory callers do not care; a caller inside ANOTHER region
  does, and cannot fix it, since a region may not contain BANK.
```

*See also: 4.1 THEME.INC.BL -- named colour roles, 4.6 MENUVERT.INC.BL -- a vertical menu, MENUBAR.INC.BL -- a horizontal menu, in BASIC., 4.4 LINEINPUT.INC.BL -- a positioned entry field, GUI.INC.BL -- four dialogs, in a box that puts the screen back., GUI2.INC.BL -- a listbox, single or multi select., LIBBANKFD.INC.BL -- the low memory front door to a banked FILEDIR.*

## LIBBANKFD.INC.BL -- the low memory front door to a banked FILEDIR.


*From the banner header of `LIBBANKFD.INC.BL`.*

```

      FILE.DIR.INIT   FILE.DIR.OPEN   FILE.DIR.NEXT

  Three more shims of exactly the kind LIBBANK.INC.BL holds, and they are
  in a file of their own for one reason: BASLOAD resolves every label in
  every file it reads, so a shim naming FILE.DIR.OPEN.BODY stops the build
  with LABEL NOT FOUND in any program that does not also include FILEDIR.
  They lived in LIBBANK for a day and GPBMODS -- which banks the same seven
  modules and has no use for a directory reader -- could not be tokenised
  at all.

  #IFDEF cannot answer it either: LIBBANK's whole body is already inside
  an #IFNDEF and BASLOAD does not nest them.

  Usage, beside LIBBANK and before the region:
      #INCLUDE "LIBBANK.INC.BL"
      #INCLUDE "LIBBANKFD.INC.BL"
      #INCLUDE "FILEIO.INC.BL"        ' FILEDIR reaches it by variables
      GOTO MY.LIBEND
      GP.BANKED LIB.CODEBANK
      ...the seven modules...
      #INCLUDE "FILEDIR.INC.BL"       ' last -- see LIBBANK's header
      GP.ENDBANKED
      MY.LIBEND:

  LIB.CODEBANK comes from LIBBANK, so that has to be included first.

  FILEIO STAYS IN LOW MEMORY. FILEDIR reaches it through variables only,
  never by a call, which is what lets the two be split -- and it has to be
  split, because FILEIO holds file statements the compiler refuses inside a
  region.
```

*See also: LIBBANK.INC.BL -- the low memory front door to a banked library., FILEIO.INC.BL -- the drive: status, files, directories., FILEDIR.INC.BL -- a directory, into a bank or into low RAM.*

## STASHVRAM.INC.BL -- screen rectangles and byte blobs, kept in VRAM.


*From the banner header of `STASHVRAM.INC.BL`.*

```

      SV.INIT      once, before anything else here
      SV.SAVE      a screen rectangle -> a handle
      SV.RESTORE   a handle -> the screen
      SV.PUT       low RAM -> a handle
      SV.GET       a handle -> low RAM
      SV.FREE      give one back
      SV.RESET     give them all back

  NO GP.ASM, AND SO NO #SYMFILE. The cells never leave VRAM: one data port
  reads, the other writes, and the KERNAL's memory_copy moves between them
  without stepping either. That is what STASH.INC.BL cannot do, and the
  reason to reach for this one.

  It also executes no BANK, so unlike STASH it may live inside a
  GP.BANKED region.

  Requires GPB.INC.BL, and #INCLUDEs it not.

   in   SV.BASE SV.TOP   the VRAM window, in bytes. Rounded in to whole
                         256-byte pages. Defaults $04000 and $1AFFF
        SV.MAX           how many handles. THE CALLER DIMS THE TWO ARRAYS
                         to it: DIM SV.PAGE%(n), SV.PAGES%(n)
        SV.X SV.Y SV.W SV.H   the rectangle, for SV.SAVE
        SV.MOVE          SV.RESTORE puts it back where it came from when
                         0, at SV.X SV.Y when not -- as STASH.MOVE
        SV.ADDR SV.LEN   low RAM address and count, for SV.PUT and SV.GET
        SV.HND           the handle, for RESTORE, GET and FREE

   out  SV.HND           1..SV.MAX, or 0 if it did not fit
        SV.OK            -1 done, 0 refused
        SV.ERROR$        why, when something is refused. "" otherwise

  ALLOCATION IS A BUMP POINTER ON 256-BYTE PAGES, released LIFO. Panels
  nest and close in reverse and a log is append-only, so a hole only
  appears if a caller frees out of order -- and then STASHVRAMGC.INC.BL
  closes it. Pages, rather than bytes, are what let a handle's address
  live in an ordinary %: a page number reaches 511 where a VRAM address
  is 17 bits and would not.

  WARNING: there is one allocator and it is this one. SV.BASE and SV.TOP
  are the caller's contract, checked only against the layer 1 map and the
  charset. BMX.STASH defaults to $13000, INSIDE the default window -- a
  program using both must move one of them.

  A screen-mode change re-uploads the charset and can re-lay the map.
  Held handles do not survive it; call SV.RESET after one.
```

*See also: STASH.INC.BL -- save a text rectangle, and put it back., STASHVRAMGC.INC.BL -- close the holes in a STASHVRAM store.*

## STASHVRAMGC.INC.BL -- close the holes in a STASHVRAM store.


*From the banner header of `STASHVRAMGC.INC.BL`.*

```

      SV.COMPACT   slide every live block down, and rewrite the table

  ITS OWN FILE BECAUSE A BASL MODULE HAS NO DEAD CODE ELIMINATION. A
  compactor nobody calls would otherwise be compiled into every program
  that includes the store. #INCLUDE this one only if something in the
  program calls it, and NEVER call it automatically.

  Requires STASHVRAM.INC.BL, and #INCLUDEs it not.

  IT IS NOT A GARBAGE COLLECTOR. Liveness is known from the handle table
  rather than discovered, so there is no mark phase and nothing traces
  anything: the live blocks are read off in page order, each is slid down
  to the low-water mark, and the table is rewritten as it goes.

  HANDLES SURVIVE IT. A block's page number changes; the handle that
  names it does not. Anything holding a raw VRAM address across a call
  here is holding a stale one -- but nothing outside the table has one,
  which is the whole reason the store is addressed by handle.

   out  SV.MOVED   how many blocks actually moved, 0 if it was already
                   tight -- which is what LIFO release leaves behind
        SV.OK      -1 done

  The slide is downward, so a block's destination is always below its
  source. That the overlap is safe at the hardware is measured, not
  assumed -- work/stashvram/SVGATE.BASL, G06B.
```

*See also: STASHVRAM.INC.BL -- screen rectangles and byte blobs, kept in VRAM.*

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

`GPB.INC.BL` defines no variables. It is 27 keyword declarations and nothing else.

```basic
GP.A = 5          ' SYNTAX ERROR — GP.A is a keyword
X = GP.A          ' correct
```

The value words are `GP.A` `GP.X` `GP.Y` `GP.C`, the registers after `GP.CALL`, and that is all of
them. They are keywords rather than variables because nothing in the runtime can write a BASIC
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
| `STR.USING.` | `STRUSING.INC.BL` | a number to a template, kept apart from the rest of `STR.` |
| `THEME.` | `THEME.INC.BL` | colour roles |
| `APPSYS.` | `APPSYS.INC.BL` | screen save/restore, panels to disk |
| `LINEINPUT.` | `LINEINPUT.INC.BL` | entry fields |
| `KB.` | `KB.INC.BL` | the keyboard drain |
| `MENUVERT.` | `MENUVERT.INC.BL` | vertical menus |
| `BMX.` | `BMX.INC.BL` | BMX bitmap loading |
| `BMXK.` | `BMX.INC.BL` | its KERNAL/VERA constants, kept apart from its variables |
| `FILE.` | `FILEIO.INC.BL` | the drive: status, exists, delete, rename, directories |
| `FILE.DIR.` | `FILEDIR.INC.BL` | reading a directory, kept apart from the rest of `FILE.` |
| `SV.` | `STASHVRAM.INC.BL` | the VRAM store. `SVGC.` is `STASHVRAMGC.INC.BL`'s one constant |

Pick anything else for your own program. `AIRLIFT.`, `GAME.`, `MAP.` — a prefix costs nothing at
runtime because BASLOAD crunches every identifier down to a short BASIC variable, so a long
readable name and a two-letter one compile to exactly the same thing.

Do not reuse a taken prefix for a name the module has not defined. `THEME.MINE` looks
free today; it is one library update away from not being.

---


*See also: 2. Using it, 4.2 STRINGS.INC.BL -- string helpers, 4.10 STRUSING.INC.BL -- a number to a template, 4.1 THEME.INC.BL -- named colour roles, 4.3 APPSYS.INC.BL -- start politely, leave it as you found it, 4.4 LINEINPUT.INC.BL -- a positioned entry field, KB.INC.BL -- the keyboard buffer, emptied., 4.6 MENUVERT.INC.BL -- a vertical menu, 4.5 BMX.INC.BL -- a BMX bitmap into VERA, FILEIO.INC.BL -- the drive: status, files, directories., FILEDIR.INC.BL -- a directory, into a bank or into low RAM., STASHVRAM.INC.BL -- screen rectangles and byte blobs, kept in VRAM.*

## 2. GP.* is keywords, not variables -- and the difference bites

#### 2. `GP.*` is keywords, not variables — and the difference bites

`GPB.INC.BL` defines no variables. It is 31 keyword declarations and nothing else. Everything
spelled `GP.something` is a BASIC *keyword*, so:

```basic
GP.A = 5          ← SYNTAX ERROR. GP.A is a keyword; you cannot assign to it.
X = GP.A          ← correct. It reads the accumulator after the last GP.CALL.
```

The value words are `GP.A`, `GP.X`, `GP.Y` and `GP.C` — the registers after `GP.CALL`, and now the
whole list of them. They are keywords rather than variables because nothing in the runtime can write
a BASIC variable by name, so a command that returns a value has to
hand it back through a keyword. X16's own `ST`, `MX` and `MY` exist for the same reason.

The full keyword list lives in `GPC-BASIC/GPB.INC.BL`, and the byte values mirror `getGP()` in
`source/common-scripts/c64tokens.py`.

---


## 3. The modules

#### 3. The modules

Each table is **in** (set before the `GOSUB`), **out** (read after it), and **internal** (do not
read, do not write, do not rely on).

##### `THEME.INC.BL`

| | |
|---|---|
| in | `THEME.ID` — 0 x16, 1 dark, 2 light, 3 gray, 4 custom, read by `THEME.LOAD`<br>`THEME.ATTR` — a packed attribute, for `THEME.SET` and `THEME.HI` |
| out | `THEME.CLR(role)` — the colour array, `DIM`med to `THEME.SLOTS`<br>`THEME.INV` — the inverse attribute, from `THEME.HI` |
| internal | `THEME.READY` |
| constants | `THEME.PAGE` `THEME.TEXT` `THEME.TITLE` `THEME.BORDER` `THEME.HILITE` `THEME.DIMMED` `THEME.WARN` `THEME.SLOTS` `THEME.COUNT` |

`THEME.CLR` is the array this module `DIM`s. Do not `DIM` it yourself — the module owns it, and
`DIM`ming an array GPC has already dimensioned is an error.

##### `APPSYS.INC.BL`

| | |
|---|---|
| in | `APPSYS.FILE$` `APPSYS.BANK` `APPSYS.X` `APPSYS.Y` `APPSYS.W` `APPSYS.H` `APPSYS.DEV` — the panel routines |
| out | `APPSYS.MODE` `APPSYS.COLS` `APPSYS.ROWS` `APPSYS.COLOUR` — set by `APPSYS.STARTUP`<br>`APPSYS.IS.EMULATOR` — set by `APPSYS.ISEMU` |
| internal | `APPSYS.LAST` |
| constants | `APPSYS.SCRMODE` `APPSYS.COLREG` `APPSYS.SETCHR` `APPSYS.CHRREG` `APPSYS.EMUSIG` |

Lay the screen out from `APPSYS.COLS` and `APPSYS.ROWS`. Do not assume 80x60 —
the X16 boots there but `SCREEN 0` is 40×30, and someone who prefers larger text is running one.

##### `STRINGS.INC.BL`

| | |
|---|---|
| in | `STR.STR$` — the string, in and out<br>`STR.WIDTH` — field width, the pad routines<br>`STR.DELIM$` `STR.MAX` — `SPLIT` (`MAX` 0 means 10)<br>`STR.FIND$` `STR.REPL$` — `REPLACE`<br>`STR.PET` — a PETSCII code, `PET2SCR`<br>`STR.AT` `STR.CUT` `STR.SUB$` — `SPLICE`, and `AT`/`CUT` are CLAMPED in place<br>`STR.PTR` — `GP.STRPTR` of the string, the three trims |
| out | `STR.STR$` — padded, or replaced, in place<br>`STR.N` — how many fields `SPLIT` found, always ≥ 1<br>`STR.FIELD$(1..N)` — the fields themselves<br>`STR.SCR` — the screen code from `PET2SCR`<br>`STR.STR$` — spliced, when it was `SPLICE` that was called |
| internal | `STR.GAP` `STR.HALF` `STR.REST$` `STR.AT` `STR.LIM` `STR.OUT$`<br>`STR.ADDR%` `STR.OP%` `STR.KEEP%` — the `{VAR}` slots the trim blob reads |

`STR.FIELD$` is the one array the library does not `DIM`. Left alone, GPC's implicit `DIM` gives
0..10. For more, `DIM` it before the first call and set
`STR.MAX` to match — `DIM`ming an array GPC has already auto-dimensioned is an error, so it is
one or the other. This is the opposite of `THEME.CLR`, which the module owns outright; the two are
worth keeping straight.

##### `STRUSING.INC.BL`

| | |
|---|---|
| in | `STR.USING.NUM` — the value, both routines<br>`STR.USING.MASK$` — the template, `STR.USING`<br>`STR.USING.DP` — decimal places, `STR.USING.FIX` |
| out | `STR.USING.STR$` — the result: a field from `STR.USING`, digits from `STR.USING.FIX`<br>`STR.USING.OVR` — −1 when the value scaled past 1e9 and the digits are unusable<br>`STR.USING.SGN` — −1 when the ROUNDED value is negative |
| internal | `STR.USING.INT$` `STR.USING.FRC$` `STR.USING.SIGN$` `STR.USING.OUT$` `STR.USING.C$`<br>`STR.USING.IW` `STR.USING.ZW` `STR.USING.Z` `STR.USING.W` `STR.USING.F`<br>`STR.USING.GRP` `STR.USING.PT` `STR.USING.I` `STR.USING.V` |

**`STR.USING.DP` is an output of `STR.USING` and an input to `STR.USING.FIX`.** The mask carries
the decimal count, so `STR.USING` overwrites whatever was there. A program alternating the two
routines must set `STR.USING.DP` again before every `FIX`.

`STR.USING.INT$` and `STR.USING.FRC$` survive a call and are the two halves of the digits, without
sign, point or field. They are listed internal because their width is the routine's business, not
the caller's — read `STR.USING.STR$`.

The prefix is `STR.USING.`, a sub-prefix of `STRINGS.INC.BL`'s `STR.`, on the same footing as
`FILE.DIR.` inside `FILE.`. Nothing here is written by `STRINGS.INC.BL` and nothing there is
written by this module, so either can be included alone.

##### `KB.INC.BL`

| | |
|---|---|
| out | — |
| internal | `KB.K$` |

One routine, `KB.CLEARKB`, and one variable it drains into. Nothing else is in the prefix.

##### `LINEINPUT.INC.BL`

| | |
|---|---|
| in | `LINEINPUT.X` `LINEINPUT.Y` — top left of the field<br>`LINEINPUT.LEN` — how many characters fit<br>`LINEINPUT.ATTR` — packed attribute<br>`LINEINPUT.TEXT$` — the starting value<br>`LINEINPUT.MASK` — non-zero shows asterisks<br>`LINEINPUT.ALLOW$` — the only characters accepted<br>`LINEINPUT.DENY$` — characters refused<br>`LINEINPUT.LABEL$` — `LINEINPUT.ASK` only |
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

##### `FILEIO.INC.BL`

Needs a `#SYMFILE` — `FILE.TOPET` is a `GP.ASM` blob.

| | |
|---|---|
| in | `FILE.NAME$` — the file every routine acts on<br>`FILE.NEW$` — the second name, `RENAME` and `COPY`<br>`FILE.DEVICE` — the drive; 0 means 8<br>`FILE.ISO` — non-zero converts names to PETSCII on the way out<br>`FILE.N` — rows to write, `SAVEARRAY`<br>`FILE.MAX` — rows that will fit, `LOADARRAY`; 0 means 10<br>`FILE.LINE$()` — the rows; **the caller owns the `DIM`** |
| out | `FILE.ERR` `FILE.MSG$` `FILE.TRK` `FILE.SEC` — the command channel<br>`FILE.OK` — `FILE.EXISTS`<br>`FILE.N` — rows read, `LOADARRAY`<br>`FILE.PATH$` — `FILE.CURDIR` |
| internal | `FILE.CMDSTR$` `FILE.OUT$` `FILE.RAW$` `FILE.ROW$` `FILE.ST` `FILE.KEEP` `FILE.I` `FILE.PETP%` |
| constants | `FILE.OKMAX` `FILE.NOTFOUND` `FILE.EXISTSERR` `FILE.PROTECTED` `FILE.CHAN` |

**This module is the missing `DS` and `DS$`.** `FILE.ERR` is `DS` and `FILE.MSG$` is `DS$`. `ST` is
*not* a disk status — it is the KERNAL's serial bus status and cannot report `FILE NOT FOUND`.

`FILE.N` is both an input and an output, the way `MENUVERT.SEL` is. `FILE.LINE$()` is the caller's
`DIM`, like `MENUVERT.ITEM$` and unlike `THEME.CLR`.

##### `FILEDIR.INC.BL`

Needs `FILEIO.INC.BL`, and a `#SYMFILE` — it is two `GP.ASM` blobs.

**It executes no `BANK` statement**, which is what lets it live in a `GP.BANKED` region: the two
blobs take the data bank at entry and put the caller's back at every exit, so no BASIC line here
ever runs with a foreign bank selected. `FILE.DIR.BNK%` carries the bank number to the assembly —
`{FILE.DIR.BANK}` would read a float's mantissa, and `FILE.DIR.WAS%` is the blobs' save slot.

| | |
|---|---|
| in | `FILE.DIR.BANK` — the bank to read into, or 0 for low RAM<br>`FILE.DIR.PTR` `FILE.DIR.CAP` — the low-RAM buffer, when `BANK` is 0<br>`FILE.DIR.PATTERN$` — a name pattern, or empty<br>`FILE.DIR.ONLY` — `FILE.DIR.ALL`, `.FILES` or `.DIRS` |
| out | `FILE.DIR.GOT` — bytes read<br>`FILE.DIR.FULL` — the buffer filled before the listing ended<br>`FILE.DIR.MORE` — −1 while `NEXT` produced an entry<br>`FILE.NAME$` `FILE.BLOCKS` `FILE.TYPE$` — the entry itself |
| internal | `FILE.DIR.AT` `FILE.DIR.ASK$` `FILE.DIR.ADDR%` `FILE.DIR.ROOM%` `FILE.DIR.OFF%` `FILE.DIR.BYTES%` `FILE.DIR.CNT%` `FILE.DIR.BLK%` `FILE.DIR.OK%` `FILE.DIR.SLOW%` `FILE.DIR.LFN%` `FILE.DIR.NAMEA%` `FILE.DIR.TYPEA%` `FILE.DIR.WAS%` `FILE.DIR.BNK%` |
| constants | `FILE.DIR.ALL` `FILE.DIR.FILES` `FILE.DIR.DIRS` `FILE.DIR.NAMEMAX` `FILE.DIR.BANKROOM` `FILE.DIR.BANKBASE` |

`FILE.DIR.INIT` must run once before anything else: it sizes `FILE.NAME$` and `FILE.TYPE$` for the
assembly to write into, and creates every `{VAR}` slot. **Do not assign `FILE.NAME$` or
`FILE.TYPE$` afterwards** — an assignment reallocates and the block the assembly holds goes stale.

`FILE.NAME$` is shared with `FILEIO` on purpose: the name a picker chose is the name `FILE.EXISTS`
and `FILE.DELETE` want.

##### `STASHVRAM.INC.BL`

Needs `GPB.INC.BL`, and **no `#SYMFILE`** — there is no `GP.ASM` in it. The cells never leave
VRAM: one data port reads, the other writes, and `memory_copy` moves between them without
stepping either.

**It executes no `BANK`**, so it can live in a `GP.BANKED` region — measured, `work/stashvram/SVB.BASL`.
That is the difference from `STASH.INC.BL`, which cannot.

| | |
|---|---|
| in | `SV.BASE` `SV.TOP` — the VRAM window in bytes. Default `$04000`/`$1AFFF`<br>`SV.MAX` — how many handles. **The caller `DIM`s `SV.PAGE%` and `SV.PAGES%` to it**<br>`SV.X` `SV.Y` `SV.W` `SV.H` — the rectangle, for `SV.SAVE`<br>`SV.MOVE` — non-zero restores at `SV.X` `SV.Y` rather than where it came from<br>`SV.ADDR` `SV.LEN` — low RAM address and count, for `SV.PUT` and `SV.GET`<br>`SV.HND` — the handle, for `RESTORE`, `GET` and `FREE` |
| out | `SV.HND` — 1..`SV.MAX`, or 0 if it did not fit<br>`SV.OK` — −1 done, 0 refused<br>`SV.ERROR$` — why, when something is refused<br>`SV.MOVED` — `SV.COMPACT` only: how many blocks moved |
| arrays | `SV.PAGE%()` `SV.PAGES%()` — the handle table, `DIM`med by the caller |
| internal | `SV.READY` `SV.NEXT` `SV.BASEPG` `SV.TOPPG` `SV.I` `SV.PG` `SV.NP` `SV.N` `SV.BYTES` `SV.MAPW` `SV.MAPBASE` `SV.STRIDE` `SV.ROW` `SV.CELL` `SV.SRC` `SV.DST` `SV.VA` `SV.ADR` `SV.BNK` `SV.REST` `SV.MID` `SV.LO` `SV.MODE` `SV.RX` `SV.RY`<br>`SV.COMPACT` adds `SV.PICK` `SV.BEST` `SV.J` `SV.TO` `SV.GCS` `SV.GCD` `SV.LEFT` `SV.CH` |
| constants | `SV.VLO` `SV.VMID` `SV.VHI` `SV.DATA` `SV.VCTRL` `SV.LCONFIG` `SV.LMAPBASE` `SV.PORTLO` `SV.PORTLO.B` `SV.PORTHI` `SV.MEMCOPY` `SV.UP` `SV.HEADER` `SVGC.CHUNK` |

`SV.INIT` must run once before anything else, and the two arrays must be `DIM`med before it.

**Blocks are whole 256-byte pages**, which is what lets a handle's address live in an ordinary
`%`: a page number reaches 511 where a VRAM address is 17 bits and would not.

**WARNING: `BMX.STASH` defaults to `$13000`, inside the default window.** A program using both
must move one of them. There is one allocator and no collision check.

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


*See also: 4.1 THEME.INC.BL -- named colour roles, 4.3 APPSYS.INC.BL -- start politely, leave it as you found it, 4.2 STRINGS.INC.BL -- string helpers, 4.10 STRUSING.INC.BL -- a number to a template, KB.INC.BL -- the keyboard buffer, emptied., 4.4 LINEINPUT.INC.BL -- a positioned entry field, 4.5 BMX.INC.BL -- a BMX bitmap into VERA, FILEIO.INC.BL -- the drive: status, files, directories., FILEDIR.INC.BL -- a directory, into a bank or into low RAM., STASHVRAM.INC.BL -- screen rectangles and byte blobs, kept in VRAM., STASH.INC.BL -- save a text rectangle, and put it back., 4.6 MENUVERT.INC.BL -- a vertical menu*

## 4. Labels are global too

#### 4. Labels are global too

Every `NAME:` in every module is a jump target in one flat space, including the ones you were never
meant to call. `BMX.STREAM.MORE`, `LINEINPUT.REDRAW`, `THEME.LOAD.DARK` and most of `MENUVERT.*` are
internal, and a `GOSUB` to one will do something, just not something useful.

`MENUVERT` is the module with the most of them, because driving a menu is mostly branching:
**`MENUVERT.RUN`, `MENUVERT.DRAW`, `MENUVERT.ROW` and `MENUVERT.HOTFIND` are the four you may call.**
`MENUVERT.WAIT`, `.KEYED`, `.SETTLE`, `.WRAPTOP`, `.WRAPBOT`, `.CANCEL`, `.HOTKEY`, `.PADKEY`,
`.PADREAD` and the three `FOLD` helpers are not.

`FILE.*` has a great many, because most of the module is one routine feeding another: **the
callable names are `FILE.STATUS`, `EXISTS`, `DELETE`, `RENAME`, `COPY`, `MKDIR`, `CHDIR`, `UP`,
`GETPATH`, `SAVEARRAY` and `LOADARRAY`, plus `FILE.DIR.INIT`, `.OPEN` and `.NEXT`.**
`FILE.CMD`, `.DONE`, `.PETNAME`, `.PETNEW`, `.TOPET`, `.PATHWALK`, `.WRITEROWS`, `.READROWS`,
`.ROWREAL`, `.ROWDROP`, `.KEEPROW`, `FILE.DIR.WHERE`, `.LOWRAM`, `.ASKFOR`, `.SUCK`,
`.SKIPDISK`, `.FILL` and `.STEP` are not. `FILE.DIR.FILL` and `FILE.DIR.STEP` are the two
assembly blobs and enter with no arguments set up at all.

`STRINGS` has three of its own. **`STR.SPLIT.NEXT`** and **`STR.REPLACE.NEXT`** are loop
continuations rather than entry points: enter either directly and you resume a loop whose
accumulators were never initialised. **`STR.TRIM.GO`** is the shared body of the three trims and
runs with whatever `STR.OP%` last held. The callable names are `STR.PADR`, `PADL`, `PADC`,
`SPLIT`, `REPLACE`, `PET2SCR`, `TRIM`, `LTRIM`, `RTRIM` and `SPLICE`.

Each module also has a skip label it jumps over itself with — `THEME.SKIP`, `APPSYS.SKIP`,
`STR.SKIP`, `BMX.MODULE.END`, `LINEINPUT.MODULE.END`, `MENUVERT.MODULE.END`. Those exist so an
include can sit anywhere in the file, the top included. **Do not branch to one.**

BASLOAD refuses a name used as both a label and a variable (`BASLOAD.MD:319`). `BMX.SKIP` is the
byte-skip counter, so the module's skip label had to
be `BMX.MODULE.END` — a name is either a label or a variable, never both.

---


## 5. TRUE IS -1

#### 5. TRUE IS -1

**Every flag the library hands back is -1 for true and 0 for false**, and anything written
against it should be too. `GUI.OK` `GUI.ANSWER` `GUI.STASHED` `STASH.OK` `SORT.OK`
`MENUVERT.HOTHIT` `FILE.OK` `BANKMGR.OK` `APPSYS.IS.EMULATOR` — all of them.

That is what a comparison in this compiler evaluates to, so a flag and a test read the same
way, and it is the value `NOT` wants: `NOT` is `-x-1`, so `NOT -1` is 0 while `NOT 1` is -2,
which is still true. `IF` itself tests non-zero, so `IF FLAG THEN` works either way and
`IF FLAG = 1 THEN` is the spelling that breaks.

```basic
IF GUI.OK THEN <accepted>            ' yes
IF NOT GUI.OK THEN <cancelled>       ' yes
IF GUI.OK = 0 THEN <cancelled>       ' yes
IF GUI.OK = 1 THEN <accepted>        ' NO -- it is -1
```

**A flag the CALLER sets is read as non-zero**, so `LINEINPUT.MASK = 1` and `STASH.MOVE = 1`
still work. Write -1 in new code all the same.

**Printing one needs `STR$` whole.** The `MID$(STR$(N), 2)` idiom strips the leading space
`STR$` puts on a positive number; -1 has no leading space, so that idiom eats the minus and
prints `1`.


## 6. Two more naming rules that are not about collisions

#### 6. Two more naming rules that are not about collisions

**`#DEFINE` takes an INT16** (`BASLOAD.MD:313`). A constant above 65535 is
`ERROR: INVALID PARAMETER`, not a warning — which is why `BMX.PALBASE` (VRAM `$1FA00`, 129536) is an
ordinary variable and not a `#DEFINE`. Every VRAM address past `$FFFF` has the same problem.

**A dotted name whose tail is a reserved word is fine.** `MENUVERT.COUNT`, `THEME.CLR`,
`LINEINPUT.LEN` and `LINEINPUT.RETURN` all contain keywords and all work, because BASLOAD matches the whole identifier. An
*undotted* one does not: `POS`, `MB`, `ST`, `LEN` and `CHAR` cannot be variables at all. This is the
main reason the library is dotted throughout.

One rule applies only outside BASL: BASLOAD gives 64 significant characters, the built-in BASIC
gives two. Write the same code as a hand-typed `.bas` for the PC-side converter and
`THEME.CLR` and `THEME.COUNT` become the same variable. That is a silent wrong answer — it cost two
test cycles during tier 6, both times looking exactly like a compiler bug. Inside BASL you are safe;
in a raw `.bas`, give every variable a distinct first two characters.

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
| a variable called `LEN`, `ST`, `POS`, `MB` or `CHAR` | the name is a reserved word on its own | dot it — BASLOAD matches the whole identifier, so `LINEINPUT.LEN` works |

---


*See also: 4.7 SORT.INC.BL -- shell sort a string array*

---

# MEMORY AND LIMITS

## 7. Memory, and what the compiler tells you

#### 7. Memory, and what the compiler tells you

##### The line GPC prints when it finishes

```
OK CODE 10734 FREE 10496 RT 13311 GP-BASIC IN
OK CODE 1234 FREE 19200 RT SHARED RT
```

| | |
|---|---|
| `CODE` | the p-code. What the program *is*, in bytes |
| `FREE` | what is left above it for variables, strings and arrays. **This is the number that runs out.** It already excludes the 4K frame stack, which is reserved rather than available |
| `RT` | the runtime bytes carried inside the object, or `SHARED` when the program loads `GPC.RT.nnn.BIN` at run time instead. `SHARED RC` asks for the core alone, `SHARED RT` for the core and the `GP.` handlers |
| `GP-BASIC` | embedded builds only. `IN` if a `GP.` keyword reached the 1,024-byte handler block and it had to go in the object, `OUT` if `ScanGPUsage` dropped it |

Two different budgets come off one figure, so read it twice:

- **`FREE` is the workspace** the running program has for its data.
- **`FREE` minus 4,096 is how much more p-code will fit.** `WriteObjectCode` refuses to leave less
  than 4K of workspace, so a build reporting `FREE 4096` is one page from `PROGRAM TOO BIG`.

A program can be comfortable on one and out of room on the other. `CODE 17406 FREE 4096` has 4K to
run in and nowhere left to grow; `CODE 10734 FREE 10496` has both.

##### `OUT OF MEMORY`

Everything the program allocates comes out of the one `FREE` pool: scalars, arrays, and the string
heap. There is no separate heap to run out of.

- **A `DIM` costs its full size whether the entries are used or not.** `DIM A$(120)` is 121 string
  slots from the moment it runs. Five arrays dimensioned to the same 120 is 1,210 bytes gone before
  a single row exists.
- **A string block never shrinks.** Assigning a shorter string to a variable that already holds a
  longer one reuses the block it has; assigning a longer one allocates a new block and abandons the
  old. The abandoned blocks are reclaimed by the heap scavenger when one of the right size is
  wanted again, not immediately.
- **What fails is therefore a high-water mark, not a total.** The allocation that raises
  `OUT OF MEMORY` is rarely the large one — it is an ordinary one that arrives after the heap has
  been churned. The same key on the same screen can work or not depending on what was visited
  first, which is what makes it read as intermittent.

The error itself comes from the runtime library and names an address in it, not a line in your
program: `OUT OF MEMORY @ $03A5 library`. It tells you the allocator refused, and nothing about
which of your strings was asking.

##### Staying inside it

- **Quote `FREE` when you change anything.** It is one line of build output and it is the only
  early warning; `PROGRAM TOO BIG` arrives once it is already too late.
- **Size a `DIM` to what is used, not to a round number.** The cost is paid on the first line of
  the program, forever.
- **Put bulk in a RAM bank.** A bank is 8,192 bytes that cost the workspace nothing. Anything held
  from start to finish and read a row at a time — a file's worth of text, a table, a screen — is
  better in a bank with an offset table at the front, read back with `PEEK` under `BANK`. See §4.5
  and `STASH.INC.BL` for the pattern.
- **A big temporary cannot be built and then freed.** Freeing is not a thing that happens on
  demand: build it in a bank, or in pieces.

*See also: 4.5 BMX.INC.BL -- a BMX bitmap into VERA, STASH.INC.BL -- save a text rectangle, and put it back.*

