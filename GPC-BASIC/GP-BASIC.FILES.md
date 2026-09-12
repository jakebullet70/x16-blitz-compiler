# What is in GPC

Every file that comes with the compiler, and what each one is for. When one of them is missing the
error names the symptom rather than the file, so the list is worth having.

This page is generated into the on-machine help by `MKHELP.PY`. Correct it here, not there.

---

## 1. What has to be on the drive to compile

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

## 3. BASLOAD — the tokeniser, and why it is forked

`BASLOAD` is the first thing every build runs. It turns `.BASL` source — labels, long variable
names, `#INCLUDE`, `#DEFINE` — into a tokenised BASIC program with line numbers, which is what the
compiler reads. GPC never sees a label.

**The X16 ships BASLOAD in ROM, and this project does not use that one.** `BASLOAD-GPC.BIN` is the
same program built from the same upstream source as an ordinary PRG, with a handful of changes in
`BASLOAD-GPC/src/`. The build drives that one and stages it into `testing/` beside `GPC.BIN`.

### Why

**The ROM version built the tokenised program in BASIC RAM**, so 38,655 bytes was the ceiling on a
`.BASL` *plus every `#INCLUDE` it pulls in*. Two-pass compilation had just moved GPC's own size
wall; this one was then the next thing in front of it, and
`samples/GPB-MODS-TESTING/GPBMODS.BASL` came within 783 bytes of it.

It also failed badly. Over the ceiling it printed `SAVING` and wrote a short PRG *before* reporting
`ERROR: BASIC RAM FULL`, so the file existed, was not empty, and loaded at `$0801`. GPC then died a
stage later on a label whose line had never been written — `UNKNOWN LINE NUMBER @ nnnn` — naming
neither the file nor the cause.

Changing that looked like it meant shipping a custom `rom.bin` and flashing real hardware. **It does
not.** The upstream source builds and runs as a RAM-resident PRG with no source changes at all, only
a linker config, and that is what made the rest possible.

**The fork streams.** Each line is written to an open file as it is finished, so one line — a
260-byte staging buffer — is all that is ever resident, and the output is bounded by the disk
instead of by BASIC RAM. A source that died at 38,421 bytes now tokenises to 47,765 and compiles.
`GPC.BASL` comes out byte-identical to the ROM's output.

### The two files

| file | what it is | size |
|---|---|---|
| `BASLOAD-GPC.BIN` | the engine. Its only interface is an ABI at `$bf00` | 9,003 bytes, loads `$6000` |
| `BASLOAD-GPC.PRG` | the front end — the thing a person runs | 971 bytes |

The same division as `GPC.BIN` and `GPC.PRG`: the name a person types belongs to the front end. The
front end asks for a source file, hands it to the engine, prints what comes back and asks again; an
empty answer quits. It is plain X16 BASIC rather than GP.BASIC, because it has to run from `READY.`
with nothing on the disk but itself and the engine.

### A failed run deletes its own output

Streaming created one failure the ROM never had. A run that died partway through pass 2 still wrote
the end-of-program link and closed the file, so what stayed on disk was a **structurally perfect
BASIC program that stopped where the error did** — and nothing downstream could tell it from a whole
one. The compiler was handed one and died on the first forward reference past the cut.

The fork now scratches the file when a run fails. Two things it deliberately does not do: it never
runs unless *this* run created the file, so a `FILE EXISTS` failure cannot destroy a previous good
build; and it never reads the drive status afterwards, because that would replace
`LABEL NOT FOUND IN DB.INC.BL:459` with a generic file error and lose the only useful thing the run
produced.

### `#GPC` — a directive channel BASLOAD never has to understand

`#GPC` passes the rest of its line through into the tokenised program as a `REM`, verbatim, and
BASLOAD never learns what any of it means:

```
#GPC OBJECT "GPBMODS.PRG"        ->   1 REM#GPC OBJECT "GPBMODS.PRG"
#GPC SHARED                      ->   2 REM#GPC SHARED
```

**The `#` is kept and there is no space after the `REM` token.** That is what a reader matches on:
`$8f` then `#GPC`, which no ordinary comment produces by accident. One table entry buys the compiler
an unlimited directive namespace, so every future compiler directive is a GPC-side change alone.

### Where the old ceiling still binds

**Anything that types `BASLOAD "X"` at the BASIC prompt uses the ROM, and still stops at 38,655
bytes.** That is the interactive path and the dev harnesses in `work/`. Only the build drives the
fork.

---

## 4. The tools

`GPC.ERR.PRG` turns a runtime error's `@ $XXXX` into a source line, using the debug map the
compiler writes when `MAKE A DEBUG MAP?` is answered yes. Without the map the address cannot be
resolved.

`GPB.HELP.PRG` is this reference, on the machine. It reads `HELP-TXT/` beside it — `GPB.HELP.IDX`
and one `.HLP` per topic — and shows 49 topics at 80x30. Arrows, `PgUp` / `PgDn`, `HOME` and `END`
move. `RETURN` opens the highlighted index row. `/` finds and `N` repeats the search. `L` follows a
topic's cross references, `X` writes its code out as a `.BL` where it has any, `T` cycles the colour
themes, `?` is the about box. `ESC` goes back a step, and quits from the index.

---

## 5. `GPC-BASIC/` — the library

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

## 6. `GPC-BASIC/` — the examples

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

## 7. The documents

| | |
|---|---|
| `GP-BASIC.md` | the manual — the keyword reference and the module reference |
| `GP-BASIC.GLOBALS.md` | every global name each module owns, and the prefixes you may not use |
| `GP-BASIC.FILES.md` | this page |
| `README.md` | how to run the compiler, and what its answers mean |
| `SRC/` | the BASLOAD source of the tools. Reference only — nothing in it is needed to run |

The library's documents live beside the includes they describe, in this folder, so a relative link
works both in the repository and in an unzipped release.
