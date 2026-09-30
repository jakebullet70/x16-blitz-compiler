# Sample — GPB-MODS-TESTING

A development harness for the GPC-BASIC library: a menu bar whose dropdowns reach nearly every
public entry point, and the one program that holds twenty-four of the library's modules at once.

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
STRINGS answers to G. A hotkey need not be an item's initial. The `&` in the item's text marks
it, and `MENU.HOTATTR` tints it in `THEME.TITLE`.

The GRAY theme has WARN as **light** red rather than red: GRAY is the only theme with a dark grey
page, and plain red on it is barely legible.

**FILES writes to the drive.** Four of its rows do. Everything they make is named `GPBFILE.*` or
`GPBDIR`, and every one of them is removed by the row that made it -- the files with
`FILE.DELETE`, the directory with `FILE.RMDIR` once the drive has come back up out of it.

## Every panel is real

There are no stubs left. A chosen row makes the library call it names and shows what came back, and
what it came back with also lands on the LAST line at the foot of the page. Two modules have no
row at all, and *The modules* names them. Nothing that is on screen is pretending. The shell itself is a
test of the menu builder before any row is chosen: `MENUTO.BAR` drives the bar,
`MENUTO.PULLDOWN` every dropdown, and `STASH` puts the screen back under a closed one.

`GMX.DISPATCH` is one `GP.SELECT` on the bar item and nothing else. Each item has a router of its
own: `GMX.DIALOG`, `GMX.LISTS`, `GMX.INPUT`, `GMX.SCREEN`, `GMX.STRINGS`, `GMX.DATA`, `GMX.THEME`,
`GMX.ABOUT` and `GMX.FILES`. Each router selects on the dropdown's row and ends by repainting the
chrome. Two shallow selects rather than one nested on both coordinates.

**Sixteen banks.** Thirteen are named at compile time and claimed from `BANKMGR`. The compiler
picks them while the object is written, so they are claimed rather than allocated. `GPBMODS.BASL`
claims twelve at startup with `BANKMGR.CLAIM.BANK`: **4** the GUI (`GUI` and `LINEINPUT`), **5**
and **6** the program's own literal text, **7** the utilities, **8** the file modules (`FILEIO` and
`FILEDIR`), **9** `THEME`, **10** the combo and check box, **11** the two biggest dropdown handlers
(`GMX.STRINGS` and `GMX.FILES`, this program's own code), **12** the menu builder (`MENU` and
`MENUPULL`), **13** the dialog verbs (`GUI-DIALOGS`), **14** the list test's text (`GM.LISTBANK`,
one `GP.BSTR` group of 40 strings that `LIST.BANK` reads) and **15** `FILEPICK`. The thirteenth is
bank **62**, `MENU.TEXTBANK`, which holds `MENU`'s own text. `MENU` claims it on its first
`MENU.BEGIN`. `MENU.INC.BL` sets it to 62 unless the program defines `MENU.TEXTBANK` first, and
`GPBMODS.BASL` does not. Three more banks are allocated at run time: the cells a dropdown covers,
the cells a dialog covers, and `FILEDIR`'s directory buffer.

**The text is in a bank.** Every string the shell says is in a `GP.BANKEDSTR` block in front of
the routine that says it, read back with `GP.BSTR`. `GPBMODS.BASL` and `GPB-MENUS.BASL` hold 587
strings in 76 named groups. They fill 13,312 bytes across two pools, 7,936 in bank 5 and 5,376 in
bank 6, and none of it is in low RAM. See §3.10 of `GP-BASIC.md`.

It takes two banks because one pool holds at most 8,192 bytes. `GP.BANKEDSTR` allows sixteen
pools. `GP.BSTR` names the group, so which pool a group sits in costs the call site nothing. Bank 6
holds 26 groups, the FILES text among them. Bank 5 holds the other 50.

**Every menu is a block of its own**, index 0 the dropdown's title (the bar's hotkey string), 1
upwards the rows. So a menu is edited in one place and one place only: the row count comes
from `GP.BSTRCOUNT` and the rows are read by a loop into `MENU.ITEM`, so adding a row means adding a line to the
block and nothing else. No other menu moves.

## Build

This folder is the drive. The `#INCLUDE` lines name `GPC-BASIC/NAME.INC.BL`, so the build reads
this folder's `GPC-BASIC/` copies. `GPB-MENUS.BASL` sits beside `GPBMODS.BASL` and is included by
name.

The object is compiled embedded. `GPBMODS.PRG` and `GPBMODS.OVL` run with no runtime file beside
them, and the two files travel together.

```
python source\gpc\samplesbuild.py GPBMODS
```

That is the whole build. It bumps the `BUILD nnn` literal in `GPBMODS.BASL`, then tokenises and
compiles in this folder. A stage that fails partway can leave a plausible file behind, so the build
reads each stage's exit status, not whether an output file exists. A WARNING about `GPB.INC.BL` is
covered under The modules.

By hand, from the repository root:

```
python source\gpc\build_basl.py     --drive GPC-BASIC-TOOLS-SRC\GPB-MODS-TESTING GPBMODS.BASL GPBMODS.SRC.PRG
python source\gpc\compile_shared.py --drive GPC-BASIC-TOOLS-SRC\GPB-MODS-TESTING --embedded GPBMODS.SRC.PRG GPBMODS.PRG GPBMODS.MAP
```

Then `USER-RUNS\gpbmods-demo.bat`, which mounts this folder.

**The SYM is named after the source PRG, not after the program.** `#SAVEAS "@:GPBMODS.SRC.PRG"`
needs `#SYMFILE "@:GPBMODS.SRC.SYM"`. Get it wrong and the tokenise succeeds, the SYM is written,
and the compile stops with `{} NEEDS #SYMFILE @ 98` — a line in `STASH.INC.BL`, saying nothing
about the file name.

## Where the bytes go

Measured on the embedded build of 2026-09-30. `GPBMODS.PRG` is **28,033** bytes and carries the
11,775-byte runtime. One `GPBMODS.OVL` of **45,851** bytes comes with it and holds thirteen
sections:

| bank | what is in it | bytes |
|---:|---|---:|
| 7 | the utilities: ten modules | 5,632 |
| 9 | `THEME` | 512 |
| 12 | the menus: `MENU` `MENUPULL` | 3,840 |
| 4 | the GUI: `LINEINPUT` `GUI` | 5,120 |
| 10 | the form controls: `COMBO` `CHECK` | 1,536 |
| 13 | the dialog verbs: `GUI-DIALOGS` | 2,304 |
| 8 | the file modules: `FILEIO` `FILEDIR` | 1,792 |
| 15 | the file picker: `FILEPICK` | 768 |
| 11 | `GMX.STRINGS` and `GMX.FILES`, this program's own code | 3,840 |
| 62 | literal text: the menu rows and hints (`MENU.TEXTBANK`) | 6,656 |
| 5 | literal text, pool one (`GM.TEXTBANK`) | 7,936 |
| 6 | literal text, pool two (`GM.TEXTBANKB`) | 5,376 |
| 14 | a list's text (`GM.LISTBANK`), which `LIST.BANK` reads | 512 |

**Each section is one bank.** Nine are `GP.BANKED` code regions and four are `GP.BANKEDSTR` text
pools. Each section is a bank number and a page count followed by the pages, and a `$01` byte ends
the file. Every section loads to `$A000` in its own bank, so none of it counts against low RAM or
the file ceiling. The code payloads total 25,344 bytes and the text payloads 20,480.

P-code bytes, differenced out of `GPBMODS.MAP` against `GPBMODS.SRC.SYM` in this folder. The table
covers low memory and all nine regions:

| where | module | p-code |
|---|---|---:|
| low | `GPBMODS.BASL` | 9,328 |
| low | `MENUKEY` | 917 |
| low | `GPB-MENUS.BASL` | 701 |
| low | `STASH` | 444 |
| low | `STASHFILE` | 167 |
| low | the eight `GP.ENDBANKED` lines | 33 |
| | **low RAM total** | **11,590** |
| bank 7 | `STASHVRAM` | 1,891 |
| bank 7 | `STRUSING` | 755 |
| bank 7 | `STRINGS` | 704 |
| bank 7 | `BANKMGR` | 599 |
| bank 7 | `STASHVRAMGC` | 304 |
| bank 7 | `BITS` | 269 |
| bank 7 | `SORT` | 189 |
| bank 7 | `APPSYS` | 114 |
| bank 7 | `STRCASE` | 54 |
| bank 7 | `KB` | 27 |
| bank 7 | bridges and page padding | 726 |
| | **bank 7 payload** | **5,632** |
| bank 9 | `THEME` | 460 |
| bank 9 | bridges and page padding | 52 |
| | **bank 9 payload** | **512** |
| bank 12 | `MENU` | 2,902 |
| bank 12 | `MENUPULL` | 899 |
| bank 12 | bridges and page padding | 39 |
| | **bank 12 payload** | **3,840** |
| bank 4 | `GUI` | 4,298 |
| bank 4 | `LINEINPUT` | 780 |
| bank 4 | bridges and page padding | 42 |
| | **bank 4 payload** | **5,120** |
| bank 10 | `COMBO` | 910 |
| bank 10 | `CHECK` | 578 |
| bank 10 | bridges and page padding | 48 |
| | **bank 10 payload** | **1,536** |
| bank 13 | `GUI-DIALOGS` | 2,243 |
| bank 13 | bridges and page padding | 61 |
| | **bank 13 payload** | **2,304** |
| bank 8 | `FILEIO` | 1,092 |
| bank 8 | `FILEDIR` | 434 |
| bank 8 | bridges and page padding | 266 |
| | **bank 8 payload** | **1,792** |
| bank 15 | `FILEPICK` | 690 |
| bank 15 | bridges and page padding | 78 |
| | **bank 15 payload** | **768** |
| bank 11 | `GMX.STRINGS`, `GMX.FILES` and what they call | 3,724 |
| bank 11 | bridges and page padding | 116 |
| | **bank 11 payload** | **3,840** |

Module p-code in the nine regions totals 23,916 bytes. Banks 62, 5, 6 and 14 hold no p-code, only
literal text.

**Three library modules are in low memory, against twenty-one in regions.** `STASH` and
`STASHFILE` hold `BANK` statements, which `CommandBankGuard` refuses inside a region. `MENUKEY`
reads the keyboard layout under `BANK 0`, which a region may not do. It runs the bar from the
shell's key loop. The rest of low RAM is this program's own `GPBMODS.BASL` shell and
`GPB-MENUS.BASL`. Nothing else keeps a module out of a region. `FILEIO`'s `OPEN`, `INPUT#` and
`CLOSE` leave `$00` alone, a `GP.ASM` blob's body never occupies a region either way, and
`BANKMGR` names banks without selecting one.

**Nine regions, not one.** A region holds at most 8,192 bytes, and the GUI takes 5,120 of its own.
A call from one region into another compiles to `.bgosub`, which selects the other bank, and
`RETURN` puts the caller's back.

**A region rounds up to a whole page.** Bank 9 holds 460 bytes of `THEME` in a 512-byte section.
The entry bridge, the alignment padding and the exit bridge are part of what has to fit.

**A text pool holds at most 8,192 bytes.** Bank 5 has 256 bytes free, with 7,936 used. Bank 6 has
2,816 free, with 5,376 used. `BStrPoolWrite` stops the compile with `.error_memory` when a pool
fills, so an overrun cannot pass silently. Moving a group to another bank costs the call site
nothing. The next group of text belongs in bank 6.

`ABOUT / BANK MEMORY` and `ABOUT / MODULE SIZES` show figures typed into `GP.BANKEDSTR` blocks.
They are a hand-entered snapshot and are out of date against these tables. Their number fields are
a fixed width, so correcting a figure changes no size.

**The compiler's line table spans two banks and holds 4,096 lines**, at 4 bytes an entry and 2,048
to an 8K bank. This build's map lists **3,402** lines. See `STRPageLine` in
`source/compiler/source/storage/mark_line.asm`.

`PLAN.md` §3 has how the measurement is done, and the method is in
`docs/memory/measure-pcode-per-module.md`. The map writes a region line's address as `bb:AAAA`,
for example `07:A000`, and a low-memory line as a bare hex address starting at `0006`. Group the
rows by that bank prefix before differencing anything. Difference within each space, charge each
module from its own first label to the next module's first label, and give each region's bridges
and tail padding a row of their own. Each region's rows then sum to its overlay payload. A few
rows of 4 or 5 bytes land on the module before a region boundary. They are the `GP.BANKED` and
`GP.ENDBANKED` lines, and the tables count them in the bridges rows and the low-RAM
`GP.ENDBANKED` row.

## The room it has to RUN in, which is the tighter budget

**The workspace is `LOW FREE` in the compiler's report**: `$7400`..`$9F00`, **11,008 bytes**. The
report for the current build is:

```
OK LOW CODE 13824, EMBEDDED GPBASIC RUNTIME 11775 LOW FREE 11008, FRAME STACK 2048
```

The same source compiled shared reports `LOW FREE 9984`, so embedded leaves 1,024 bytes more. The
runtime sits in low memory either way: shared loads it at the top, embedded carries it at the
bottom of the object. The first p-code opcode is `.varspace`, whose operand says how much of the
workspace the scalars take. The rest holds the string arrays (2 bytes an element) and the whole
string heap.

**That is the number FILES/DIR OPEN ran out of once.** It builds twenty-four listbox rows of ~38
characters, and a concrete block is `length x 1.5 + 3`, so the rows alone want ~1,440 bytes --
against a heap that was 1,660 before this was fixed. It reported `OUT OF MEMORY @ $056B`, which
the map placed inside `STR.PADR`: the pad is where the last temporary was asked for, not where the
memory went. `StringInitialise` refuses once the heap ceiling comes within 512 bytes of the arrays,
so the failure lands on whatever allocates next.

The fix was not in this program. `FrameStackPages` (`source/common-source/source/common.inc`) was
**16 pages, 4K** -- nearly as big as the whole workspace, for a stack nothing here nests more than
a dozen frames deep. It is 8 now, and every program gets those 2,048 bytes back.

**The nine regions hold 23,916 bytes of p-code that would otherwise have to be in low memory.**
Low memory holds 11,590 bytes of p-code, alongside the runtime and the 11,008-byte workspace given
above. Moving code into a bank moves no scalars, because a banked routine's variables are the same
workspace variables low memory sees.

**Typing costs nothing and a float costs six bytes.** `AllocateBytesForType` gives an untyped
scalar 6 bytes and an `%` or `$` one 2, and an undimensioned array is 0..10 whatever it holds. The
harness's own 47 small integers are `%`, and its four `LINEINPUT` field arrays are dimensioned to
the three fields they hold rather than left implicit: 380 bytes of string heap between them, for
no change to what the program does. `FOR` will not take an `%` index. `for.asm` refuses it, as
stock BASIC does, so loop counters stay float.

## The modules

`GPC-BASIC/` here holds the working copies. Root `GPC-BASIC/` is the release copy. A module is
edited and proved here, then copied whole into root. A fix made in root is ported back here by
hand.

**A module is one file, and the program decides where it goes.** `STRINGS.INC.BL` holds `STR.PADR`
whether its `#INCLUDE` is in low memory or inside a `GP.BANKED` region. A call into a region
selects the region's bank and `RETURN` puts the caller's back (`GP-BASIC.md` §3.12), so no module
has a banked twin and no call needs a shim. Twenty-one of the twenty-four modules are in a region
here. `STASH` and `STASHFILE` hold `BANK` statements and `MENUKEY` reads under `BANK 0`, so those
three stay in low memory.

`STRCASE` declares `STR.UCASE` and `STR.LCASE` with `GP.DEFPROC` on the line above each body, and
`FILEIO` declares `FILE.SIZE` the same way. None of the three has a label: a label with a verb's
name is `DUPLICATE SYMBOL`.

To lift a bank into another program, take the `.INC.BL` files between its `GP.BANKED` and
`GP.ENDBANKED` in `GPBMODS.BASL`, and the `#DEFINE` that names its bank.

**`GPB.INC.BL` is the exception that runs the other way.** It is the keyword ABI, and root's
`GPC-BASIC/GPB.INC.BL` is upstream for it. The build reads this folder's `GPC-BASIC/GPB.INC.BL`, so
a stale copy here downgrades the build without an error. `samplesbuild.py` prints a WARNING when
this folder's copy differs from root's. Copy root's over this one; never copy this one outward.

**Twenty-four modules are included, and twenty-two are exercised.** `KB` and `STASHVRAMGC` are
compiled in, but nothing calls `KB.CLEARKB` or `SV.COMPACT`, so nothing on screen drives them: 331
bytes of banked p-code, `STASHVRAMGC` 304 and `KB` 27. `COMBO` and `CHECK` share bank 10, and
DIALOG > CHECK BOX + COMBO drives both.

`GPBMODS.BASL` leaves out `BMX`, `DOS`, `ERRSRC`, `ERRTOKEN`, `KV`, `MATH` and `MEM`. `BMX`
needs a bitmap file and a screen-mode change and is not GUI, and `GPC-BASIC/BMXVIEW.EXP.BL`
covers it.
