# Sample — GPB-MODS-TESTING

A development harness for the GPC-BASIC library: a menu bar whose dropdowns reach nearly every
public entry point, and the one program that holds all twenty-one modules at once.

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
STRINGS answers to G — a hotkey need not be an item's initial. The `&` in the item's text marks
it, and `MENU.HOTATTR` tints it in `THEME.TITLE`.

The GRAY theme has WARN as **light** red rather than red: GRAY is the only theme with a dark grey
page, and plain red on it is barely legible.

**FILES writes to the drive.** Four of its rows do. Everything they make is named `GPBFILE.*` or
`GPBDIR`, and every one of them is removed by the row that made it -- the files with
`FILE.DELETE`, the directory with `FILE.RMDIR` once the drive has come back up out of it.

## Every panel is real

There are no stubs left. A chosen row makes the library call it names and shows what came back, and
what it came back with also lands on the LAST line at the foot of the page. Two modules have no
row at all yet — see *The modules* — but nothing that is on screen is pretending. The shell itself is a
test of the menu builder before any row is chosen: `MENUTO.BAR` drives the bar,
`MENUTO.PULLDOWN` every dropdown, and `STASH` puts the screen back under a closed one.

`GMX.DISPATCH` is one `GP.SELECT` on the bar item and nothing else. Each item has a router of its
own — `GMX.DIALOG`, `GMX.LISTS`, `GMX.INPUT`, `GMX.SCREEN`, `GMX.STRINGS`, `GMX.DATA`, `GMX.THEME`,
`GMX.ABOUT`, `GMX.FILES` — which selects on the dropdown's row and ends by repainting the chrome. Two
shallow selects rather than one nested on both coordinates.

**Thirteen banks.** Ten are named by the compiler and are CLAIMED from `BANKMGR` at startup,
because the compiler picks them while the object is written and so the manager is told rather than
asked: **4** the GUI, **5** and **6** the program's own literal text, **7** the utilities, **8** the
file modules, **9** `THEME`, **10** the combo and check box, **11** the two biggest dropdown handlers,
which are this program's own code rather than the library's, **12** the menu builder and **13** the
dialog verbs. Three more are allocated at run time —
the cells a dropdown covers, the cells a dialog covers, and `FILEDIR`'s directory buffer.

**The text is in a bank.** Every string the shell says is in a `GP.BANKEDSTR` block in front of
the routine that says it, read back with `GP.BSTR` — 552 strings in 72 named groups, filling 12,032
bytes across two pools and none of it in low RAM. See §3.10 of `GP-BASIC.md`.

It takes two banks because one pool is a hard 8,192 bytes and the first one filled. `GP.BANKEDSTR`
allows sixteen, and which one a group sits in costs the call site nothing — `GP.BSTR` names the
GROUP — so the split is a budget decision and nothing else. Bank 6 holds 23 groups: the FILES text,
and whatever was moved out of bank 5 to make room. Bank 5 holds the other 49.

**Every menu is a block of its own**, index 0 the dropdown's title (the bar's hotkey string), 1
upwards the rows. So a menu is edited in one place and one place only: the row count comes
from `GP.BSTRCOUNT` and the rows are read by a loop into `MENU.ITEM`, so adding a row means adding a line to the
block and nothing else — and no other menu moves.

## Build

The drive is `drive/`, not this folder: the object is compiled shared and loads the resident
`GPC.RT.<ver>.BIN`, which lives there.

```
python source\gpc\modsbuild.py GPBMODS
```

That is the whole build. It stages the sources and runs the two stages below, and it reads each
stage's **exit status** rather than asking whether an output file turned up — a stage that fails
partway can still leave a plausible file behind, and one of those once cost the compiler 420
seconds on a source that had never finished tokenising. By hand it is:

```
copy samples\GPB-MODS-TESTING\GPBMODS.BASL       drive\
copy samples\GPB-MODS-TESTING\GPC-BASIC\*.INC.BL drive\
copy GPC-BASIC\GPB.INC.BL                        drive\
python source\gpc\build_basl.py     GPBMODS.BASL     GPBMODS.SRC.PRG
python source\gpc\compile_shared.py GPBMODS.SRC.PRG  GPBMODS.PRG  GPBMODS.MAP
```

**The third copy is not optional, and its direction is the opposite of the other two.**
`GPB.INC.BL` is the keyword ABI and root is upstream for it, so a copy taken from this folder
silently downgrades the build.

Then `USER-RUNS\gpbmods-demo.bat`.

`modsbuild.py` takes a list of program names.

**The SYM is named after the source PRG, not after the program.** `#SAVEAS "@:GPBMODS.SRC.PRG"`
needs `#SYMFILE "@:GPBMODS.SRC.SYM"`. Get it wrong and the tokenise succeeds, the SYM is written,
and the compile stops with `{} NEEDS #SYMFILE @ 98` — a line in `STASH.INC.BL`, saying nothing
about the file name.

## Where the bytes go

Built 2026-09-18, after `MENUVERT` and `MENUBAR` were replaced by `MENU` and `MENUPULL`.
`GPBMODS.PRG` is **11,542** bytes, and one `GPBMODS.OVL` of **38,165** bytes comes with it. The
overlay holds ten sections:

| bank | what is in it | bytes |
|---:|---|---:|
| 7 | the utilities: nine modules | 5,120 |
| 9 | `THEME` | 768 |
| 12 | the menus: `MENU` `MENUPULL` | 2,816 |
| 4 | the GUI: `LINEINPUT` `GUI` `GUI2` | 5,632 |
| 10 | the form controls: `COMBO` `CHECK` | 1,536 |
| 8 | the file modules: `FILEIO` `FILEDIR` | 1,792 |
| 11 | `GMX.STRINGS` and `GMX.FILES`, this program's own code | 3,072 |
| 62 | literal text: the menu rows and hints (`MENU.TEXTBANK`) | 4,352 |
| 5 | literal text, pool one | 7,936 |
| 6 | literal text, pool two | 5,120 |

**Each section is one bank.** Seven are `GP.BANKED` code regions and three are `GP.BANKEDSTR`
text pools. Each section is a bank number and a page count followed by the pages, and the file
ends with a `$01` marker. Every section loads to `$A000` in its own bank, so none of it counts
against low RAM or the file ceiling.

P-code bytes, differenced out of `drive/GPBMODS.MAP` against `drive/GPBMODS.SRC.SYM`. The
figures cover low memory and all seven regions, so the total is far larger than the resident
object:

| where | module | p-code |
|---|---|---:|
| low | `GPBMODS.BASL` | 9,874 |
| low | `STASH` | 435 |
| low | `STASHFILE` | 160 |
| | **low RAM total** | **10,469** |
| bank 7 | `STASHVRAM` | 1,681 |
| bank 7 | `STRUSING` | 755 |
| bank 7 | `STRINGS` | 704 |
| bank 7 | `BANKMGR` | 598 |
| bank 7 | `STASHVRAMGC` | 304 |
| bank 7 | `SORT` | 189 |
| bank 7 | `APPSYS` | 114 |
| bank 7 | `STRCASE` | 54 |
| bank 7 | `KB` | 27 |
| bank 7 | bridges and page padding | 694 |
| | **bank 7 payload** | **5,120** |
| bank 9 | `THEME` | 519 |
| bank 9 | bridges and page padding | 249 |
| | **bank 9 payload** | **768** |
| bank 12 | `MENU` | 2,277 |
| bank 12 | `MENUPULL` | 516 |
| bank 12 | bridges and page padding | 23 |
| | **bank 12 payload** | **2,816** |
| bank 4 | `GUI` | 4,453 |
| bank 4 | `LINEINPUT` | 780 |
| bank 4 | `GUI2` | 353 |
| bank 4 | bridges and page padding | 46 |
| | **bank 4 payload** | **5,632** |
| bank 10 | `COMBO` | 918 |
| bank 10 | `CHECK` | 579 |
| bank 10 | bridges and page padding | 39 |
| | **bank 10 payload** | **1,536** |
| bank 8 | `FILEIO` | 1,092 |
| bank 8 | `FILEDIR` | 422 |
| bank 8 | bridges and page padding | 278 |
| | **bank 8 payload** | **1,792** |
| bank 11 | `GMX.STRINGS`, `GMX.FILES` and what they call | 3,016 |
| bank 11 | bridges and page padding | 56 |
| | **bank 11 payload** | **3,072** |

Banks 5, 6 and 62 hold no p-code at all. Their payloads are 7,936, 5,120 and 4,352 bytes, all of it
literal text.

**Two modules in low memory against nineteen in banks, and that is the point of the regions.**
What is left in low RAM is what could not go: `STASH` and `STASHFILE` hold `BANK` statements, which
`CommandBankGuard` refuses inside a region. Nothing else disqualified anything — `FILEIO`'s `OPEN`, `INPUT#` and `CLOSE`
leave `$00` alone (measured for `FILEDIR`, banked since 2026-09-07), a `GP.ASM` blob's body never
occupies a region either way, and `BANKMGR` names banks without ever selecting one.

**Seven regions and not one**, because a region holds at most 8,192 bytes and the GUI fills its own.
A call from one region into another compiles to `.bgosub`, which selects the other bank, and
`RETURN` puts the caller's back.

**A region that is nearly empty still costs a whole page count.** Bank 9 holds 519 bytes of `THEME`
in a 768-byte section; the entry bridge, the
alignment padding and the exit bridge are part of what has to fit, and the region is rounded up to
a page. Below about a page and a half of p-code a region gives back less than it looks like.

Bank 5 **filled** once, and groups were moved to bank 6 to answer it. Which bank a group is in
costs the call site nothing, so moving one is the whole of the fix. It is a hard wall rather than a
budget: `BStrPoolWrite` stops the compile with `.error_memory` when a pool fills, so an overrun
cannot pass silently, and the next group of text to be added belongs in bank 6, which still has
3,584 bytes free.

`ABOUT / BANK MEMORY` and `ABOUT / MODULE SIZES` carry these numbers on screen, and **they are
typed into `GP.BANKEDSTR` blocks, so they are only true of the build they were taken from.**
Their number fields are a fixed width, so correcting a figure after a rebuild changes no size. They
were last corrected on 2026-09-14, to this table and to the 11,619-byte resident object.

**This is the program that needed the compiler line table doubled.** It marked 2,156 lines and the
table held 2,048 — one 8K bank at 4 bytes an entry — so the compile stopped with
`PROGRAM TOO BIG @ 3055`, naming a limit that had nothing to do with the size of the program. The
table runs on two banks now and holds 4,096; this build marks **2,902**. See `STRPageLine` in
`source/compiler/source/storage/mark_line.asm`.

`PLAN.md` §3 has how the measurement is done, and the method is in
`docs/memory/measure-pcode-per-module.md`. **Split the map into its two address spaces before
differencing anything.** Low-memory p-code runs upward from `$0006` and the six regions are laid
out in one block above it, so the map is not monotonic by line, and a
naive walk down it charges a module the jump between the two spaces. Difference within each space,
charge each module by its own first label to the next module's, and give each region's tail padding
a row of its own; every region column above then sums to its overlay payload exactly.

## The room it has to RUN in, which is the tighter budget

**A shared program's workspace is what is left between its own p-code and the resident runtime**,
and for this one that is `$4000`..`$6600` — **9,728 bytes**, all of it read straight out of the
built `.PRG`. The start page is `PCODE_PAGE` (`$0A`), plus one for the bootstrap extension a banked
program carries, plus the object's p-code page count, plus `FrameStackPages`; `ObjectWriteShared`
computes it and the bootstrap then carries the pair as the operands of `ldx`/`ldy` at `BBBasePage`,
so it can be read back rather than recomputed. The first p-code opcode is `.varspace`, whose
operand says how much of the workspace the scalars take. Here that is **3,292**, leaving about
**6,436** for the string arrays (2 bytes an element) and the whole string heap.

**That is the number FILES/DIR OPEN ran out of once.** It builds twenty-four listbox rows of ~38
characters, and a concrete block is `length x 1.5 + 3`, so the rows alone want ~1,440 bytes --
against a heap that was 1,660 before this was fixed. It reported `OUT OF MEMORY @ $056B`, which
the map placed inside `STR.PADR`: the pad is where the last temporary was asked for, not where the
memory went. `StringInitialise` refuses once the heap ceiling comes within 512 bytes of the arrays,
so the failure lands on whatever allocates next.

The fix was not in this program. `FrameStackPages` (`source/common-source/source/common.inc`) was
**16 pages, 4K** -- nearly as big as the whole workspace, for a stack nothing here nests more than
a dozen frames deep. It is 8 now, and every shared program gets those 2,048 bytes back.

**The regions were the other half, and they are this program's own doing.** Every include that
could go, went. On 2026-09-08 one region took eight modules out of low RAM and the object fell
15,254 -> 14,001. Four more regions since — the file modules on bank 8, `THEME` on 9, the combo box
on 10, and this program's own two biggest dropdown handlers on 11 — took it from 14,287 to 12,885.
Deleting the shims, once a call into a region selected the bank itself, took it to **11,619**. The
workspace went from `$4900`..`$6600` (7,424) to `$4000`..`$6600` (**9,728**), while three modules
and several panels were added on top. `.varspace` went from 2,812 to 3,292: moving code into a bank
moves no scalars, because a banked routine's variables are the same workspace variables low memory
sees.

**Typing costs nothing and a float costs six bytes.** `AllocateBytesForType` gives an untyped
scalar 6 bytes and an `%` or `$` one 2, and an undimensioned array is 0..10 whatever it holds. The
harness's own 47 small integers are `%`, and its four `LINEINPUT` field arrays are dimensioned to
the three fields they hold rather than left implicit: 380 bytes of string heap between them, for
no change to what the program does. `FOR` will not take an `%` index — `for.asm` refuses it, as
stock BASIC does — so loop counters stay float.

## The modules

`GPC-BASIC/` here is the **working copy**. Root `GPC-BASIC/` is the release copy. A module is edited
and proved here, then copied whole into the root — never merged by hand, and the root copy is what
`samples/GPC-HELP` and `samples/edit` build against.

**A module is one file, and the program decides where it goes.** `STRINGS.INC.BL` holds `STR.PADR`
whether its `#INCLUDE` is in low memory or inside a `GP.BANKED` region. A call into a region
selects the region's bank and `RETURN` puts the caller's back (`GP-BASIC.md` §3.12), so no module
has a banked twin and no call needs a shim. Eighteen of the twenty modules are in a region here;
`STASH` and `STASHFILE` hold `BANK` statements and stay in low memory. **So a module is still a
straight overwrite into root.**

`STRCASE` declares `STR.UCASE` and `STR.LCASE` with `GP.DEFPROC` on the line above each body, and
`FILEIO` declares `FILE.SIZE` the same way. None of the three has a label: a label with a verb's
name is `DUPLICATE SYMBOL`.

To lift a bank into another program, take the `.INC.BL` files between its `GP.BANKED` and
`GP.ENDBANKED` in `GPBMODS.BASL`, and the `#DEFINE` that names its bank.

**Against root, this folder is ahead.** Five modules do not exist in root at all — `BANKMGR`,
`FILEDIR`, `FILEIO`, `STASHVRAM`, `STASHVRAMGC` — and seven more differ: `APPSYS`, `KB`, `SORT`,
`STASH`, `STASHFILE`, `STRINGS` and `STRUSING`. Three are identical: `LINEINPUT`, `STRCASE` and `THEME`.
`COMBO`, `GUI` and `GUI2` differ because they moved off `MENUVERT` here and root has not. `MENU`, `MENUPULL` and
`DOS` are new here; `MENUBAR` and `MENUVERT` are deleted here and still in root. Port a fix by hand in either direction.

**`GPB.INC.BL` is the exception that runs the other way.** It is the keyword ABI, root is upstream
for it, and `modsbuild.py` copies root's over this folder's on every build. Never copy this one
outward.

**Twenty-one are included, and nineteen are exercised.** `KB` and `STASHVRAMGC` are compiled in,
but no panel calls `KB.CLEARKB` or `SV.COMPACT`, so nothing on screen drives them: 332 bytes of
banked p-code, `STASHVRAMGC` 304 and `KB` 28. `COMBO` and `CHECK` share bank 10, and
DIALOG > CHECK BOX + COMBO drives both.

`BMX` is out: it needs a bitmap file and a screen-mode change and is not GUI, and
`GPC-BASIC/BMXVIEW.EXP.BL` already covers it.
