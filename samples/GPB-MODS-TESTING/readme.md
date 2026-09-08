# Sample — GPB-MODS-TESTING

The GPC-BASIC library under a menu bar. Development harness for the modules, and the one program
that holds all of them at once.

`PLAN.md` is the design; this file is how to build and drive it.

## Keys

```
 DIALOG  LISTS  INPUT  SCREEN  STRINGS  DATA  THEME  ABOUT  FILES
```

`<-` `->` walk the bar, DOWN or RETURN opens the dropdown under the marked item, and `<-` `->` with
one open move to the next dropdown without going back up. UP and DOWN walk the rows, RETURN chooses.
ESC closes a dropdown; ESC on the bar asks whether to leave, and only YES does.

Each bar item also answers to a letter: **D**IALOG, **L**ISTS, **I**NPUT, **S**CREEN,
STRIN**G**S, D**A**TA, **T**HEME, A**B**OUT, **F**ILES. SCREEN and STRINGS both start with S, so
STRINGS answers to G — a hotkey need not be an item's initial, and `MENUVERT.HOTATTR` tints
whichever letter it finds.

That tint is `THEME.WARN`, which is why the GRAY theme has WARN as **light** red rather than red:
GRAY is the only theme with a dark grey page, and plain red on it is barely legible. The hotkey is
where that shows up first, long before any actual warning.

**FILES writes to the drive.** Four of its rows do. Everything they make is named `GPBFILE.*` or
`GPBDIR`, and the two files are scratched by the row that made them; the directory is not, because
`FILEIO` has no RMDIR.

## Every panel is real

There are no stubs left. A chosen row makes the library call it names and shows what came back, and
what it came back with also lands on the LAST line at the foot of the page. The shell itself is a
test of three modules before any row is chosen: `MENUBAR` drives the bar, `MENUVERT` every
dropdown, and `STASH` puts the screen back under a closed one.

`GMX.DISPATCH` is one `GP.SELECT` on the bar item and nothing else. Each item has a router of its
own — `GMX.DIALOG`, `GMX.LISTS`, `GMX.INPUT`, `GMX.SCREEN`, `GMX.STRINGS`, `GMX.DATA`, `GMX.THEME`,
`GMX.ABOUT`, `GMX.FILES` — which selects on `MENUVERT.SEL` and ends by repainting the chrome. Two
shallow selects rather than one nested on both coordinates, which is also how BANK MAP is simply
named by the two routers that both list it.

**Six banks.** Three are named by the compiler: 4 holds the banked library, 5 and 6 the program's
own literal text. Three more are allocated at run time — the cells a dropdown covers, the cells a
dialog covers, and `FILEDIR`'s directory buffer. All six are CLAIMED from `BANKMGR`, and the first
three have to be: the compiler picks them while the object is written, so the manager is told
rather than asked.

**The text is in a bank.** Every string the shell says is in a `GP.BANKEDSTR` block in front of
the routine that says it, read back with `GP.BSTR` — 443 strings in 66 named groups, buying 9,705
bytes of low RAM. See §3.10 of `GP-BASIC.md`.

It takes two banks because one pool is a hard 8,192 bytes and the first one filled. `GP.BANKEDSTR`
allows sixteen, and which one a group sits in costs the call site nothing — `GP.BSTR` names the
GROUP — so the split is a budget decision and nothing else. The FILES text is in bank 6, everything
else in bank 5.

**Every menu is a block of its own**, index 0 the dropdown's title (the bar's hotkey string), 1
upwards the rows. So a menu is edited in one place and one place only: `MENUVERT.COUNT` comes
from `GP.BSTRCOUNT` and the rows are read by a loop, so adding a row means adding a line to the
block and nothing else — and no other menu moves.

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

Built 2026-09-08 with all fifteen modules and every panel written. `GPBMODS.PRG` is 15,209 bytes,
`GPBMODS.B04` 6,658, `GPBMODS.B05` 8,194 and `GPBMODS.B06` 1,794 — **three overlay files, because
the source names three banks.** One `.Bnn` is written per bank, not per some size threshold:
`GP.BANKED LIB.CODEBANK` makes `.B04`, and the two `GP.BANKEDSTR` banks make `.B05` and `.B06`.
Each is loaded to `$A000` in its own bank, which is why none counts against low RAM or the file
ceiling.

P-code bytes, differenced out of `testing/GPBMODS.MAP` against `testing/GPBMODS.SRC.SYM` — low RAM
and the banked region together, which is why the total is larger than the resident object:

| | p-code | | | p-code |
|---|---:|---|---|---:|
| `BANKMGR` | 578 | | `THEME` | 479 |
| `APPSYS` | 114 | | `MENUVERT` | 1,104 |
| `STASH` | 431 | | `MENUBAR` | 826 |
| `STASHFILE` | 171 | | `LINEINPUT` | 762 |
| `STRCASE` | 66 | | `GUI` | 1,647 |
| `STRINGS` | 511 | | `GUI2` | 1,360 |
| `LIBBANK` | 184 | | `FILEDIR` | 431 |
| `LIBBANKFD` | 34 | | | |
| `SORT` | 189 | | `GPBMODS.BASL` | 10,495 |
| `FILEIO` | 839 | | **total** | **20,221** |

Bank 5 is the tight one: **7,999 of 8,192 used, 193 free**, against bank 6 at 1,706. It is a hard
wall rather than a budget — `BStrPoolWrite` stops the compile with `.error_memory` when a pool
fills, so an overrun cannot pass silently. `ABOUT / MODULE SIZES` carries the same table on screen,
and the numbers there are only true of the build they were taken from.

**This is the program that needed the compiler line table doubled.** It marks 2,156 lines and the
table held 2,048 — one 8K bank at 4 bytes an entry — so the compile stopped with
`PROGRAM TOO BIG @ 3055`, naming a limit that had nothing to do with the size of the program. The
table runs on two banks now and holds 4,096; see `STRPageLine` in
`source/compiler/source/storage/mark_line.asm`.

`PLAN.md` §3 has how the measurement is done. The script is in
`docs/memory/measure-pcode-per-module.md`.

## The modules

`GPC-BASIC/` here is the **working copy**. Root `GPC-BASIC/` is the release copy. A module is edited
and proved here, then copied whole into the root — never merged by hand, and the root copy is what
`samples/GPC-HELP` and `samples/editor` build against.

**Fifteen are in the shell.** `BMX` is out: it needs a bitmap file and a screen-mode change and
is not GUI, and `GPC-BASIC/BMXVIEW.EXP.BL` already covers it. `KB` is newer than the shell — it
sits in the folder, it has its own test, and no panel calls it yet. `GPB.INC.BL` is the keyword
ABI and is not edited here; `LIBBANK.INC.BL` and `LIBBANKFD.INC.BL` are this sample's own front
door to the banked library, not library modules.

`THEME.INC.BL` here has **diverged from the root copy** and is not a straight overwrite either
way: this one renames `THEME.LOAD` to `THEME.SELECT` and carries the comments swept down in
`377dd7c`, while the root copy keeps the old name and is what `samples/editor`,
`samples/color-test` and `samples/GPC-HELP` build against. Port a fix across by hand.

`LIBBANKFD` is separate from `LIBBANK` because BASLOAD resolves every label in every file it
reads, so a `FILE.DIR` shim in `LIBBANK` stops the build with `LABEL NOT FOUND` in any program
that does not also include `FILEDIR` — which is every program here but `GPBFILES`.
