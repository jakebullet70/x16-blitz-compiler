# Sample — GPB-MODS-TESTING

A development harness for the GPC-BASIC library: a menu bar whose dropdowns reach nearly every
public entry point, and the one program that holds all twenty modules at once.

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
`GPBDIR`, and every one of them is removed by the row that made it -- the files with
`FILE.DELETE`, the directory with `FILE.RMDIR` once the drive has come back up out of it.

## Every panel is real

There are no stubs left. A chosen row makes the library call it names and shows what came back, and
what it came back with also lands on the LAST line at the foot of the page. Three modules have no
row at all yet — see *The modules* — but nothing that is on screen is pretending. The shell itself is a
test of three modules before any row is chosen: `MENUBAR` drives the bar, `MENUVERT` every
dropdown, and `STASH` puts the screen back under a closed one.

`GMX.DISPATCH` is one `GP.SELECT` on the bar item and nothing else. Each item has a router of its
own — `GMX.DIALOG`, `GMX.LISTS`, `GMX.INPUT`, `GMX.SCREEN`, `GMX.STRINGS`, `GMX.DATA`, `GMX.THEME`,
`GMX.ABOUT`, `GMX.FILES` — which selects on `MENUVERT.SEL` and ends by repainting the chrome. Two
shallow selects rather than one nested on both coordinates.

**Eleven banks.** Eight are named by the compiler and are CLAIMED from `BANKMGR` at startup,
because the compiler picks them while the object is written and so the manager is told rather than
asked: **4** the GUI, **5** and **6** the program's own literal text, **7** the utilities, **8** the
file modules, **9** `THEME`, **10** the combo box, and **11** the two biggest dropdown handlers,
which are this program's own code rather than the library's. Three more are allocated at run time —
the cells a dropdown covers, the cells a dialog covers, and `FILEDIR`'s directory buffer.

**The text is in a bank.** Every string the shell says is in a `GP.BANKEDSTR` block in front of
the routine that says it, read back with `GP.BSTR` — 552 strings in 72 named groups, filling 12,032
bytes across two pools and none of it in low RAM. See §3.10 of `GP-BASIC.md`.

It takes two banks because one pool is a hard 8,192 bytes and the first one filled. `GP.BANKEDSTR`
allows sixteen, and which one a group sits in costs the call site nothing — `GP.BSTR` names the
GROUP — so the split is a budget decision and nothing else. Bank 6 holds 23 groups: the FILES text,
and whatever was moved out of bank 5 to make room. Bank 5 holds the other 49.

**Every menu is a block of its own**, index 0 the dropdown's title (the bar's hotkey string), 1
upwards the rows. So a menu is edited in one place and one place only: `MENUVERT.COUNT` comes
from `GP.BSTRCOUNT` and the rows are read by a loop, so adding a row means adding a line to the
block and nothing else — and no other menu moves.

## Build

The drive is `testing/`, not this folder: the object is compiled shared and loads the resident
`GPC.RT.<ver>.BIN`, which lives there.

```
python source\gpc\modsbuild.py GPBMODS
```

That is the whole build. It stages the sources and runs the two stages below, and it reads each
stage's **exit status** rather than asking whether an output file turned up — a stage that fails
partway can still leave a plausible file behind, and one of those once cost the compiler 420
seconds on a source that had never finished tokenising. By hand it is:

```
copy samples\GPB-MODS-TESTING\GPBMODS.BASL       testing\
copy samples\GPB-MODS-TESTING\GPC-BASIC\*.INC.BL testing\
copy GPC-BASIC\GPB.INC.BL                        testing\
python source\gpc\build_basl.py     GPBMODS.BASL     GPBMODS.SRC.PRG
python source\gpc\compile_shared.py GPBMODS.SRC.PRG  GPBMODS.PRG  GPBMODS.MAP
```

**The third copy is not optional, and its direction is the opposite of the other two.**
`GPB.INC.BL` is the keyword ABI and root is upstream for it, so a copy taken from this folder
silently downgrades the build.

Then `gpbmods-demo.bat` from the project root.

`modsbuild.py` takes a list, and two other programs live here: `GUIFRMT.BASL`, twenty-four headless
assertions against `GUI.FORM`'s focus model, and `PICKDEMO.BASL`, `GUI.LISTBOX` in multi-select
with the GUI in a bank.

**The SYM is named after the source PRG, not after the program.** `#SAVEAS "@:GPBMODS.SRC.PRG"`
needs `#SYMFILE "@:GPBMODS.SRC.SYM"`. Get it wrong and the tokenise succeeds, the SYM is written,
and the compile stops with `NO SYMBOL FILE FOR {} @ 98` — a line in `STASH.INC.BL`, saying nothing
about the file name.

## Where the bytes go

Built 2026-09-12 with all twenty modules and every panel written. `GPBMODS.PRG` is **12,885**
bytes and **eight overlay files** come with it, 30,480 bytes between them:

| file | bank | what is in it | bytes |
|---|---:|---|---:|
| `GPBMODS.B04` | 4 | the GUI — `MENUVERT` `MENUBAR` `LINEINPUT` `GUI` `GUI2` | 7,938 |
| `GPBMODS.B05` | 5 | literal text, pool one | 7,426 |
| `GPBMODS.B06` | 6 | literal text, pool two | 4,610 |
| `GPBMODS.B07` | 7 | the utilities — nine modules | 4,354 |
| `GPBMODS.B08` | 8 | the file modules — `FILEIO` `FILEDIR` | 1,538 |
| `GPBMODS.B09` | 9 | `THEME` | 770 |
| `GPBMODS.B10` | 10 | `COMBO` | 770 |
| `GPBMODS.B11` | 11 | `GMX.STRINGS` and `GMX.FILES`, this program's own code | 3,074 |

**One `.Bnn` is written per bank, not per some size threshold.** Six are `GP.BANKED` code regions
and two are `GP.BANKEDSTR` text pools. Each is loaded to `$A000` in its own bank, which is why none
of it counts against low RAM or the file ceiling, and each carries a two-byte load address like any
PRG, so **the payload is the file size less two**.

P-code bytes, differenced out of `testing/GPBMODS.MAP` against `testing/GPBMODS.SRC.SYM` — low
memory and all six regions, which is why the total is far larger than the resident object:

| where | module | p-code |
|---|---|---:|
| low | `GPBMODS.BASL` | 9,454 |
| low | `STASH` | 431 |
| low | `SHIM.UTILBANK` | 376 |
| low | `SHIM.GUIBANK` | 294 |
| low | `SHIM.FUTILBANK` | 235 |
| low | `STASHFILE` | 175 |
| low | `SHIM.THEMEBANK` | 134 |
| low | `SHIM.COMBOBANK` | 114 |
| low | the six region exit bridges | 22 |
| | **low RAM total** | **11,235** |
| `.B04` | `GUI` | 4,472 |
| `.B04` | `MENUVERT` | 1,306 |
| `.B04` | `MENUBAR` | 826 |
| `.B04` | `LINEINPUT` | 780 |
| `.B04` | `GUI2` | 366 |
| `.B04` | entry bridge and page padding | 186 |
| | **bank 4 payload** | **7,936** |
| `.B07` | `STASHVRAM` | 1,681 |
| `.B07` | `STRUSING` | 726 |
| `.B07` | `BANKMGR` | 590 |
| `.B07` | `STRINGS` | 511 |
| `.B07` | `STASHVRAMGC` | 304 |
| `.B07` | `SORT` | 189 |
| `.B07` | `APPSYS` | 114 |
| `.B07` | `STRCASE` | 54 |
| `.B07` | `KB` | 28 |
| `.B07` | entry bridge and page padding | 155 |
| | **bank 7 payload** | **4,352** |
| `.B08` | `FILEIO` | 1,089 |
| `.B08` | `FILEDIR` | 422 |
| `.B08` | entry bridge and page padding | 25 |
| | **bank 8 payload** | **1,536** |
| `.B09` | `THEME` | 502 |
| `.B09` | entry bridge and page padding | 266 |
| | **bank 9 payload** | **768** |
| `.B10` | `COMBO` | 704 |
| `.B10` | entry bridge and page padding | 64 |
| | **bank 10 payload** | **768** |
| `.B11` | `GMX.STRINGS`, `GMX.FILES` and what they call | 2,867 |
| `.B11` | entry bridge and page padding | 205 |
| | **bank 11 payload** | **3,072** |

Banks 5 and 6 hold no p-code at all: 7,424 and 4,608 bytes of payload, all of it literal text.

**Two modules in low memory against eighteen in banks, and that is the point of the regions.**
What is left in low RAM is what could not go: `STASH` and `STASHFILE` hold `BANK` statements, which
`CommandBankGuard` refuses inside a region, and the five `SHIM.*` files are the front doors to the
five library regions — bank 11's front door is in `GPBMODS.BASL` itself, because the code behind it
is the program's own. Nothing else disqualified anything — `FILEIO`'s `OPEN`, `INPUT#` and `CLOSE`
leave `$00` alone (measured for `FILEDIR`, banked since 2026-09-07), a `GP.ASM` blob's body never
occupies a region either way, and `BANKMGR` names banks without ever selecting one.

**Six regions and not one**, because a region may not call another: all six live at `$A000`, so the
branch has no distance to travel and `GPBankMakeOffset` refuses it. Every call between them goes
down through a low-memory shim, which is what the 1,153 bytes of `SHIM.*` in the table buy.

**A region that is nearly empty still costs a whole page count.** Bank 9 holds 502 bytes of `THEME`
in a 768-byte overlay and bank 10 704 bytes of `COMBO` in another 768; the entry bridge, the
alignment padding and the exit bridge are part of what has to fit, and the region is rounded up to
a page. Below about a page and a half of p-code a region gives back less than it looks like.

Bank 5 **filled** once, and groups were moved to bank 6 to answer it. Which bank a group is in
costs the call site nothing, so moving one is the whole of the fix. It is a hard wall rather than a
budget: `BStrPoolWrite` stops the compile with `.error_memory` when a pool fills, so an overrun
cannot pass silently, and the next group of text to be added belongs in bank 6, which still has
3,584 bytes free.

`ABOUT / BANK MEMORY` and `ABOUT / MODULE SIZES` carry these numbers on screen, and **they are
typed into `GP.BANKEDSTR` blocks, so they are only true of the build they were taken from.**
Changing a number changes the program's size, which changes the number — `GPBMODS.BASL:2487-2488`
currently says `RESIDENT P-CODE 12755`, `.B05 8194` and `.B06 3842` against the 12,885, 7,426 and
4,610 above.

**This is the program that needed the compiler line table doubled.** It marked 2,156 lines and the
table held 2,048 — one 8K bank at 4 bytes an entry — so the compile stopped with
`PROGRAM TOO BIG @ 3055`, naming a limit that had nothing to do with the size of the program. The
table runs on two banks now and holds 4,096; this build marks **2,902**. See `STRPageLine` in
`source/compiler/source/storage/mark_line.asm`.

`PLAN.md` §3 has how the measurement is done, and the method is in
`docs/memory/measure-pcode-per-module.md`. **Split the map into its two address spaces before
differencing anything.** Low-memory p-code runs upward from `$0006` and the six regions are laid
out in one block above it — from `$3300` in this build — so the map is not monotonic by line, and a
naive walk down it charges a module the jump between the two spaces. Difference within each space,
charge each module by its own first label to the next module's, and give each region's tail padding
a row of its own; every region column above then sums to its overlay payload exactly.

## The room it has to RUN in, which is the tighter budget

**A shared program's workspace is what is left between its own p-code and the resident runtime**,
and for this one that is `$4500`..`$6600` — **8,448 bytes**, all of it read straight out of the
built `.PRG`. The start page is `PCODE_PAGE` (`$0A`), plus one for the bootstrap extension a banked
program carries, plus the object's p-code page count, plus `FrameStackPages`; `ObjectWriteShared`
computes it and the bootstrap then carries the pair as the operands of `ldx`/`ldy` at `BBBasePage`,
so it can be read back rather than recomputed. The first p-code opcode is `.varspace`, whose
operand says how much of the workspace the scalars take. Here that is **3,436**, leaving about
**5,012** for the string arrays (2 bytes an element) and the whole string heap.

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
on 10, and this program's own two biggest dropdown handlers on 11 — took it from **14,287 to
12,885**, and the workspace from `$4900`..`$6600` (7,424) to `$4500`..`$6600` (**8,448**), while
three modules and several panels were added on top. `.varspace` went the other way, 2,812 -> 3,436:
moving code into a bank moves no scalars, because a banked routine's variables are the same
workspace variables its shim sees.

**Typing costs nothing and a float costs six bytes.** `AllocateBytesForType` gives an untyped
scalar 6 bytes and an `%` or `$` one 2, and an undimensioned array is 0..10 whatever it holds. The
harness's own 47 small integers are `%`, and its four `LINEINPUT` field arrays are dimensioned to
the three fields they hold rather than left implicit: 380 bytes of string heap between them, for
no change to what the program does. `FOR` will not take an `%` index — `for.asm` refuses it, as
stock BASIC does — so loop counters stay float.

## The modules

`GPC-BASIC/` here is the **working copy**. Root `GPC-BASIC/` is the release copy. A module is edited
and proved here, then copied whole into the root — never merged by hand, and the root copy is what
`samples/GPC-HELP` and `samples/editor` build against.

**Every banked module is a twin, and the plain file is untouched.** `STRINGS.INC.BL` holds
`STR.PADR` and goes in low memory; `STRINGS.BANK.INC.BL` holds `STR.PADR.BODY` and goes in a
region, and `SHIM.UTILBANK.INC.BL` owns the plain name in between. Eighteen of the twenty modules
have a `.BANK` twin — every one except `STASH` and `STASHFILE`, which hold `BANK` statements and
cannot be banked at all. **So the plain copy is still a straight overwrite into root**, which the
earlier `.PLAIN` scheme was not: nothing has to be renamed back on the way out.

`STRCASE` is the one that changed shape as well as name: its two `GP.DEFPROC` declarations live in
`SHIM.UTILBANK.INC.BL`, because a verb's call site is compiled into a jump to the body and a jump
out of low memory has to select the bank first.

Copy a twin and it brings its front door with it. To lift a bank into another program, take the
one `SHIM.*BANK.INC.BL` and the `.BANK.INC.BL` files listed under it in `GPBMODS.BASL`, and nothing
else.

**Against root, this folder is ahead.** Six modules do not exist in root at all — `BANKMGR`,
`COMBO`, `FILEDIR`, `FILEIO`, `STASHVRAM`, `STASHVRAMGC` — and ten more differ: `APPSYS`, `GUI`,
`KB`, `MENUVERT`, `SORT`, `STASH`, `STASHFILE`, `STRCASE`, `STRINGS` and `STRUSING`. Four are
identical: `GUI2`, `LINEINPUT`, `MENUBAR` and `THEME`. Port a fix by hand in either direction.

**`GPB.INC.BL` is the exception that runs the other way.** It is the keyword ABI, root is upstream
for it, and `modsbuild.py` copies root's over this folder's on every build. Never copy this one
outward.

**Twenty are included, and seventeen are exercised.** `COMBO`, `KB` and `STASHVRAMGC` are compiled
in and shimmed — `COMBO.ADD`, `KB.CLEARKB` and `SV.COMPACT` all have front doors — but no panel
calls any of them, so nothing on screen drives them. That is 1,036 bytes of banked p-code — `COMBO`
704, `STASHVRAMGC` 304, `KB` 28 — and bank 10 exists for the first of the three alone. Rows for
them are the next thing the shell owes.

`BMX` is out: it needs a bitmap file and a screen-mode change and is not GUI, and
`GPC-BASIC/BMXVIEW.EXP.BL` already covers it.

`SHIM.FUTILBANK.INC.BL` is separate from `SHIM.GUIBANK.INC.BL` because BASLOAD resolves every label
in every file it reads, so a `FILE.DIR` shim in `SHIM.GUIBANK.INC.BL` stops the build with
`LABEL NOT FOUND` in any program that does not also include `FILEDIR` — which is `PICKDEMO` and
`SPIKE`. `GPBMODS` includes both.
