# Sample — GPB-MODS-TESTING

A development harness for the GPC-BASIC library: a menu bar whose dropdowns reach every public
entry point, and the one program that holds all seventeen modules at once.

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
what it came back with also lands on the LAST line at the foot of the page. The shell itself is a
test of three modules before any row is chosen: `MENUBAR` drives the bar, `MENUVERT` every
dropdown, and `STASH` puts the screen back under a closed one.

`GMX.DISPATCH` is one `GP.SELECT` on the bar item and nothing else. Each item has a router of its
own — `GMX.DIALOG`, `GMX.LISTS`, `GMX.INPUT`, `GMX.SCREEN`, `GMX.STRINGS`, `GMX.DATA`, `GMX.THEME`,
`GMX.ABOUT`, `GMX.FILES` — which selects on `MENUVERT.SEL` and ends by repainting the chrome. Two
shallow selects rather than one nested on both coordinates.

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

Built 2026-09-09 with all seventeen modules and every panel written. `GPBMODS.PRG` is 14,287
bytes, `GPBMODS.B04` 6,914, `GPBMODS.B05` 7,682, `GPBMODS.B06` 3,330 and `GPBMODS.B07` 4,866 —
**four overlay files, because the source names four banks.** One `.Bnn` is written per bank, not per some
size threshold: the two `GP.BANKED` regions make `.B04` and `.B07`, and the two `GP.BANKEDSTR`
banks make `.B05` and `.B06`. Each is loaded to `$A000` in its own bank, which is why none counts
against low RAM or the file ceiling.

P-code bytes, differenced out of `testing/GPBMODS.MAP` against `testing/GPBMODS.SRC.SYM` — all
three places p-code can live, which is why the total is far larger than the resident object:

| low RAM | p-code | | bank 4 `.B04` | p-code | | bank 7 `.B07` | p-code |
|---|---:|---|---|---:|---|---|---:|
| `STASH` | 431 | | `THEME` | 479 | | `APPSYS` | 114 |
| `STASHFILE` | 171 | | `MENUVERT` | 1,104 | | `BANKMGR` | 586 |
| `SHIM.GUIBANK` | 184 | | `MENUBAR` | 826 | | `STRCASE` | 54 |
| `SHIM.FUTILBANK` | 34 | | `LINEINPUT` | 780 | | `STRINGS` | 511 |
| `SHIM.UTILBANK` | 359 | | `GUI` | 1,857 | | `STRUSING` | 726 |
| `GPBMODS.BASL` | 11,537 | | `GUI2` | 1,360 | | `SORT` | 189 |
| | | | `FILEDIR` | 431 | | `STASHVRAM` | 1,681 |
| | | | | | | `FILEIO` | 1,007 |
| **12,716** | | | **6,837** | | | **4,868** | |

**Six entries in the left column against fifteen on the right is the point of bank 7.** What is left in low RAM is what could
not go: `STASH` and `STASHFILE` hold `BANK` statements, which `CommandBankGuard` refuses inside a
region, and the three `LIB*` files are the shim layer that reaches the other two columns. Nothing
else disqualified anything — `FILEIO`'s `OPEN`, `INPUT#` and `CLOSE` leave `$00` alone (measured
for `FILEDIR`, banked since 2026-09-07), a `GP.ASM` blob's body never occupies a region either
way, and `BANKMGR` names banks without ever selecting one.

**Two regions and not one**, because a region may not call another: both live at `$A000`, so the
branch has no distance to travel and `GPBankMakeOffset` refuses it. They are independent here —
the only call the GUI bank makes downwards is to `STASH`, which is in low memory.

Bank 5 **filled**, and `BS.G.SAY` was moved to bank 6 to answer it — the overlay went 8,194 ->
7,682 and bank 6 1,794 -> 3,330. Which bank a group is in costs the call site nothing, so moving
one is the whole of the fix. It is a hard wall rather than a budget: `BStrPoolWrite` stops the
compile with `.error_memory` when a pool fills, so an overrun cannot pass silently, and the next
group of text to be added belongs in bank 6. `ABOUT / MODULE SIZES` carries the module table on screen, and the
numbers there are only true of the build they were taken from.

**This is the program that needed the compiler line table doubled.** It marks 2,156 lines and the
table held 2,048 — one 8K bank at 4 bytes an entry — so the compile stopped with
`PROGRAM TOO BIG @ 3055`, naming a limit that had nothing to do with the size of the program. The
table runs on two banks now and holds 4,096; see `STRPageLine` in
`source/compiler/source/storage/mark_line.asm`.

`PLAN.md` §3 has how the measurement is done, and the method is in
`docs/memory/measure-pcode-per-module.md`. **Charge each module by the difference between its own
first label and the next module's, WITHIN one region** — a naive walk down the map charges a
module the padding at its region's end, which made `FILEIO` read 1,106 rather than 853.

## The room it has to RUN in, which is the tighter budget

**A shared program's workspace is what is left between its own p-code and the resident runtime**,
and for this one that is `$4800`..`$6600` -- **7,680 bytes**, all of it read straight out of the
built `.PRG`: the bootstrap carries the two page numbers as the operands of `ldx`/`ldy` at
`BBBasePage`, and the first p-code opcode is `.varspace`, whose operand says how much of the
workspace the scalars take. Here that is **2,652**, leaving about 5,030 for the string arrays
(2 bytes an element) and the whole string heap.

**That is the number FILES/DIR OPEN ran out of.** It builds twenty-four listbox rows of ~38
characters, and a concrete block is `length x 1.5 + 3`, so the rows alone want ~1,440 bytes --
against a heap that was 1,660 before this was fixed. It reported `OUT OF MEMORY @ $056B`, which
the map places inside `STR.PADR`: the pad is where the last temporary was asked for, not where the
memory went. `StringInitialise` refuses once the heap ceiling comes within 512 bytes of the arrays,
so the failure lands on whatever allocates next.

The fix was not in this program. `FrameStackPages` (`source/common-source/source/common.inc`) was
**16 pages, 4K** -- nearly as big as the whole workspace, for a stack nothing here nests more than
a dozen frames deep. It is 8 now, and every shared program gets those 2,048 bytes back.

**Bank 7 was the second half of it, and it is this program's own doing.** Every include that
could go, went: `APPSYS`, `BANKMGR`, `STRCASE`, `STRINGS`, `SORT` and `FILEIO` first, then
`STRUSING` and `STASHVRAM` as they were added. The shims cost 359 bytes of low RAM and the region
holds 4,868, so the resident object fell 15,254 -> 14,001 **while gaining two modules and three
panels**, and the workspace rose 6,656 -> 7,680.

**Where it stands now.** The panels written since put the object at 14,287, which costs a page:
the workspace starts at the page after the object plus the 8-page frame stack, so it is
`$4900`..`$6600` = **7,424**, and 208 bytes off the object would put it back to `$4800` and
**7,680**. Inside that, `.varspace` — every scalar, plus one pointer slot an array — is **2,812**,
and the rest is arrays and the string heap.

**Typing costs nothing and a float costs six bytes.** `AllocateBytesForType` gives an untyped
scalar 6 bytes and an `%` or `$` one 2, and an undimensioned array is 0..10 whatever it holds. The
harness's own 45 small integers are `%`, and its four `LINEINPUT` field arrays are dimensioned to
the three fields they hold rather than left implicit: 380 bytes of string heap between them, for
no change to what the program does. `FOR` will not take an `%` index — `for.asm` refuses it, as
stock BASIC does — so loop counters stay float.

## The modules

`GPC-BASIC/` here is the **working copy**. Root `GPC-BASIC/` is the release copy. A module is edited
and proved here, then copied whole into the root — never merged by hand, and the root copy is what
`samples/GPC-HELP` and `samples/editor` build against.

**EIGHT OF THEM CAN NO LONGER BE COPIED TO ROOT AS THEY STAND, and that is the price of bank 7.**
`APPSYS`, `BANKMGR`, `STRCASE`, `STRINGS`, `STRUSING`, `SORT`, `STASHVRAM` and `FILEIO` have had
their public entry points renamed to `.BODY` so `SHIM.UTILBANK.INC.BL` can own the plain names — the
same surgery `SHIM.GUIBANK.INC.BL` already did to the seven GUI modules, and the same surgery any program
banking them would have to repeat. A program that wants them in low memory wants the root copies;
a program that wants them banked wants these. `STRCASE` is the one that changed shape as well as
name: its two `GP.DEFPROC` declarations moved into `SHIM.UTILBANK.INC.BL`, because a verb's call site is
compiled into a jump to the body and a jump out of low memory has to select the bank first.

Port a fix by hand in either direction, and mind that `FILEIO.INC.BL` does not exist in root at
all yet — this is the only copy, and it has a `FILE.RMDIR` the older notes say it lacks.

**Seventeen are in the shell**, `STRUSING` and `STASHVRAM` being the two most recently added —
`STRINGS` gained a `STR.USING` and a `STR.USING.FIX` row, and `SCREEN` a `STASHVRAM` row that
does the same demonstration as the `STASH` row above it so the two can be read against each
other. `BMX` is out: it needs a bitmap file and a screen-mode change and is not GUI, and
`GPC-BASIC/BMXVIEW.EXP.BL` already covers it. `KB` is newer than the shell — it sits in the
folder, it has its own test, and no panel calls it yet. `GPB.INC.BL` is the keyword
ABI and is not edited here; `SHIM.GUIBANK.INC.BL` and `SHIM.FUTILBANK.INC.BL` are this sample's own front
door to the banked library, not library modules; `SHIM.UTILBANK.INC.BL` is the same thing for bank 7.

`THEME.INC.BL` here has **diverged from the root copy** and is not a straight overwrite either
way: this one renames `THEME.LOAD` to `THEME.SELECT` and carries the comments swept down in
`377dd7c`, while the root copy keeps the old name and is what `samples/editor`,
`samples/color-test` and `samples/GPC-HELP` build against. Port a fix across by hand.

`SHIM.FUTILBANK.INC.BL` is separate from `SHIM.GUIBANK.INC.BL` because BASLOAD resolves every label in
every file it reads, so a `FILE.DIR` shim in `SHIM.GUIBANK.INC.BL` stops the build with `LABEL NOT FOUND` in any program
that does not also include `FILEDIR` — which is `PICKDEMO` and `SPIKE`. `GPBMODS`
includes both.
