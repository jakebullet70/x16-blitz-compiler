# Sample — GPB-MODS-TESTING

The GPC-BASIC library under a menu bar. Development harness for the modules, and the one program
that holds all of them at once.

`PLAN.md` is the design; this file is how to build and drive it.

## Keys

```
 DIALOG  LISTS  INPUT  SCREEN  STRINGS  DATA  THEME  ABOUT
```

`<-` `->` walk the bar, DOWN or RETURN opens the dropdown under the marked item, and `<-` `->` with
one open move to the next dropdown without going back up. UP and DOWN walk the rows, RETURN chooses.
ESC closes a dropdown; ESC on the bar leaves the program and puts the screen back.

Each bar item also answers to a letter: **D**IALOG, **L**ISTS, **I**NPUT, **S**CREEN,
STRIN**G**S, D**A**TA, **T**HEME, A**B**OUT. SCREEN and STRINGS both start with S, so STRINGS
answers to G — a hotkey need not be an item's initial, and `MENUVERT.HOTATTR` tints whichever
letter it finds.

## Every panel is a stub

A chosen row opens `GUI.SAY` naming itself. What is real is the shell, and the shell is already a
test of four modules: `MENUBAR` drives the bar, `MENUVERT` every dropdown, `STASH` puts the screen
back under a closed one, and `GUI` draws the stub.

Banks 2 and 3 are used — 2 for the cells a dropdown covers, 3 for the cells a dialog covers. Both
are written whole. Nothing else in the program touches banked RAM.

## Build

The drive is `testing/`, not this folder: the object is compiled shared and loads the resident
`GPC.RT.<ver>.BIN`, which lives there.

```
copy samples\GPB-MODS-TESTING\GPBMODS.BASL       testing\
copy samples\GPB-MODS-TESTING\GPC-BASIC\*.INC.BL testing\
python source\gpc\build_basl.py     GPBMODS.BASL     GPBMODS.SRC.PRG
python source\gpc\compile_shared.py GPBMODS.SRC.PRG  GPBMODS.PRG  GPBMODS.MAP
```

Then `gpbmods-demo.bat` from the project root.

**The SYM is named after the source PRG, not after the program.** `#SAVEAS "@:GPBMODS.SRC.PRG"`
needs `#SYMFILE "@:GPBMODS.SRC.SYM"`. Get it wrong and the tokenise succeeds, the SYM is written,
and the compile stops with `NO SYMBOL FILE FOR {} @ 98` — a line in `STASH.INC.BL`, saying nothing
about the file name.

## Where the bytes go

Built 2026-09-05 with all twelve modules: `OK CODE 10047 FREE 9472`.

| | p-code |
|---|---:|
| the twelve modules | 7,506 |
| the shell and its stubs | 1,943 |
| | |
| room left for panels (`FREE - 4096`) | **5,376** |

`PLAN.md` §3 has the per-module breakdown and how it was measured.

## The modules

`GPC-BASIC/` here is the **working copy**. Root `GPC-BASIC/` is the release copy. A module is edited
and proved here, then copied whole into the root — never merged by hand, and the root copy is what
`samples/GPC-HELP` and `samples/editor` build against.

Twelve of the fourteen are included. `BMX` is out: it needs a bitmap file and a screen-mode change
and is not GUI, and `GPC-BASIC/BMXVIEW.EXP.BL` already covers it. `GPB.INC.BL` is the keyword ABI
and is not edited here.
