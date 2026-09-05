# What is in GPC

Every file that comes with the compiler, and what each one is for. When one of them is missing the
error names the symptom rather than the file, so the list is worth having.

This page is generated into the on-machine help by `MKHELP.PY`. Correct it here, not there.

---

## 1. What has to be on the drive to compile

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

`GPC.ERR.PRG` turns a runtime error's `@ $XXXX` into a source line, using the debug map the
compiler writes when `MAKE A DEBUG MAP?` is answered yes. Without the map the address cannot be
resolved.

`BASLOAD` is not a file here; it is built into the R49 ROM. It reads `.BASL` source — BASIC with
long names, labels instead of line numbers, `#INCLUDE` and `#DEFINE` — and writes the `.PRG` that
GPC compiles. Every `.INC.BL` and `.EXP.BL` in this folder is BASLOAD source.

---

## 4. `GPC-BASIC/` — the library

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

## 5. `GPC-BASIC/` — the examples

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

| | |
|---|---|
| `GP-BASIC.md` | the manual — the keyword reference and the module reference |
| `GP-BASIC.GLOBALS.md` | every global name each module owns, and the prefixes you may not use |
| `GP-BASIC.FILES.md` | this page |
| `README.md` | how to run the compiler, and what its answers mean |
| `SRC/` | the BASLOAD source of the tools. Reference only — nothing in it is needed to run |

The library's documents live beside the includes they describe, in this folder, so a relative link
works both in the repository and in an unzipped release.
