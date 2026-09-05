# GPB-MODS-TESTING — plan

**Nothing is built. This file is the plan only.**

A permanent development harness for the `GPC-BASIC` library modules: a menu bar with dropdowns that
reaches every public entry point in the library, driven from one program. Modules are edited and
proved here, then copied into `GPC-BASIC/` for release.

## 1. Direction of copy

`samples/GPB-MODS-TESTING/GPC-BASIC/` is the working copy. Root `GPC-BASIC/` is the release copy.
Work happens here; a module goes to the root when it passes its panel.

Drift is already real and is the reason to state the direction. `samples/editor/GPC-BASIC/` holds
`GUI.INC.BL` at 23,339 bytes against the root's 25,663, and `MENUVERT.INC.BL` at 18,893 against
18,843. Neither is the release copy and neither is marked.

Rules:

- A module is copied whole, never merged by hand.
- The root copy is what `samples/GPC-HELP` and `samples/editor` build against. Copy to the root and
  those two must still build.
- `GPB.INC.BL` is the keyword ABI. It is not edited here.

## 2. The bar

Eight bar items, one dropdown each. The shape is itself a test: `MENUBAR` drives the bar,
`MENUVERT` drives every dropdown, and the two cross-axis flags join them.

| bar item | dropdown | modules exercised |
|---|---|---|
| `DIALOG` | SAY · YN · MENU · TEXT · LISTBOX single · LISTBOX multi · OPEN/CLOSE panel · box styles 0-5 | `GUI`, `GUI2` |
| `LISTS` | MENUVERT.RUN · .DRAW · .ROW · MENUBAR.RUN · .DRAW · .ITEM · hotkeys · NOWRAP · MUSTSEL · KEEPMARK · GAMEPAD | `MENUVERT`, `MENUBAR` |
| `INPUT` | LINEINPUT.GET · .ASK · three-field form · length and insert limits | `LINEINPUT` |
| `SCREEN` | GP.BOX styles · GP.FILL · GP.PRINTAT · GP.DRAW · STASH save/restore · STASH move · STASHFILE save/load/put | `STASH`, `STASHFILE`, `GPB` |
| `STRINGS` | STR.PADR/PADL/PADC · STR.SPLIT · STR.REPLACE · STR.PET2SCR · STRCASE 5 modes | `STRINGS`, `STRCASE` |
| `DATA` | SORT.RUN on a fixture · array set · BMX.SHOW · BANKMGR alloc/free/claim | `SORT`, `BMX`, `BANKMGR` |
| `THEME` | the five themes live · THEME.NEXT · THEME.SET · THEME.HI · colour readout | `THEME` |
| `ABOUT` | FREE, p-code size, build number, per-module byte table, the bank map | `BANKMGR` |

Bar and dropdown join through `MENUBAR.DOWNEXIT` (DOWN ends the bar so the caller opens the panel)
and `MENUVERT.KEYEXIT` (LEFT and RIGHT end the dropdown so the caller walks the bar).
`MENUBAR.SELX` and `.SELW` place the panel under its item. Both modules share `MENUVERT.ITEM$`,
`.ATTR`, `.HIATTR`, `.HOT$` and `.HOTATTR`, so each routine reloads the array before it draws.

WARNING: `MENUBAR.ITEM` writes `MENUVERT.Y`. Set the dropdown's X, Y, WIDTH and COUNT fresh after
drawing the bar. Empty `MENUVERT.HOT$` for a dropdown whose letters mean bar items.

Every panel returns to the bar. `APPSYS.STARTUP` and `APPSYS.RESTORE` bracket the program.

## 3. The budget -- MEASURED 2026-09-05, and it is not binding yet

Shared mode: p-code runs from `PCODE_PAGE $0900` to `RTGPBASE $6600`, 23,808 bytes, less the 4K
frame stack and the 4K minimum workspace. **15,616 bytes of p-code is the ceiling.**

The shell was built with all twelve modules and a stub driver: **`OK CODE 10047 FREE 9472`**.
Per-module bytes, differenced out of `GPBMODS.MAP` against `GPBMODS.SRC.SYM` -- exact, no
experimental builds:

| module | p-code |
|---|---:|
| `GUI.INC.BL` | 1,667 |
| `GUI2.INC.BL` | 1,460 |
| `MENUVERT.INC.BL` | 1,122 |
| `MENUBAR.INC.BL` | 826 |
| `LINEINPUT.INC.BL` | 704 |
| `THEME.INC.BL` | 480 |
| `STRINGS.INC.BL` | 430 |
| `STASH.INC.BL` | 376 |
| `SORT.INC.BL` | 199 |
| `STASHFILE.INC.BL` | 128 |
| `APPSYS.INC.BL` | 88 |
| `STRCASE.INC.BL` | 26 |
| **library total** | **7,506** |
| the stub driver | 1,943 |
| map total | 9,459 |

`BANKMGR.INC.BL` was added after this measurement: **590 bytes**, taking the library to 8,114, the
shell to 2,126 and the object to `OK CODE 10838 FREE 8704`. Room for panels is now **4,608**.

`GPB.INC.BL` is keyword definitions and costs nothing. Map total is under the object's 10,047; the
rest is headers and tables.

**The estimates in the first draft of this plan were high by 1,800.** `GUI` came in at 1,667 against
the 2,147 measured on GPC-HELP's older copy, `GUI2` 1,460 against 1,618, `STRINGS` 430 against ~560.
`THEME` went the other way -- 480 against 226, because it carries five themes now and that
measurement predates three of them.

**Headroom is `FREE - 4096` = 5,376 bytes for the panels**, with every module already in. GPC-HELP's
whole driver is 5,148 bytes for five modules, so:

- **The flat `#IFNDEF` guards are not needed.** They stay in reserve. If they are ever wanted the
  rule is one symbol a bar item, flat -- `GMT.NODIALOG`, `GMT.NOLISTS`, and so on -- because
  **BASLOAD does not nest `#IFNDEF`**: a guard inside a guard reports `ENDIF WITHOUT IF` and writes
  a 6-byte PRG that then "compiles" clean.
- **`BMX` stays out.** It needs a bitmap file and a screen-mode change and is not GUI;
  `BMXVIEW.EXP.BL` covers it. Its ~1,250 bytes are a third of what is left.
- **The banked GUI is not what unblocks this program.** It remains the point of the project, but the
  wall it is aimed at is further off than this plan first assumed. See §6 and §8.

Re-measure after each panel: `compile_shared.py SRC OBJ MAP` writes the map, and differencing it
against the `#SYMFILE` output costs nothing.

## 4. Files

```
samples/GPB-MODS-TESTING/
    PLAN.md          this file
    readme.md        written when the shell runs
    GPBMODS.BASL     the shell and the panels
    GPC-BASIC/       the working copies of every module under test,
                     including BANKMGR.INC.BL, which is written here first
```

Preamble, in this order, or the build fails in ways that name neither the file nor the cause:

```
#SAVEAS "@:GPBMODS.PRG"
#REM 0
#SYMFILE "@:GPBMODS.SYM"
```

`#SYMFILE` comes **before** the `#INCLUDE`s, and it is not optional: `STASH.INC.BL` uses `{VAR}`
operands in `GP.ASM`, and without it GPC stops with `NO SYMBOL FILE FOR {} @ <line>` and falls out
to BASIC with a `?STRING TOO LONG ERROR`.

WARNING: THE SYM IS NAMED AFTER THE SOURCE PRG, NOT AFTER THE PROGRAM. `SymBuildName` replaces the
source's `.PRG` with `.SYM`, so a `#SAVEAS "@:GPBMODS.SRC.PRG"` needs `#SYMFILE
"@:GPBMODS.SRC.SYM"`. Naming it `GPBMODS.SYM` tokenises clean, writes the file, and then fails the
compile with the message above -- which names a line in `STASH.INC.BL` and says nothing about the
file name. It cost the first build of this project. `samples/color-test/COLORTST.BASL` has the same
mismatch and only gets away with it because it uses no `{VAR}`.

No `#AUTONUM`. It sets the STEP, and only the default 1 survives `STRCASE`.

## 5. Build and run

The drive is `testing/`, as `color-demo.bat` does, because the object is compiled shared and
`GPC.RT.<ver>.BIN` lives there.

```
copy samples/GPB-MODS-TESTING/GPBMODS.BASL       -> testing/
copy samples/GPB-MODS-TESTING/GPC-BASIC/*.INC.BL -> testing/
python source/gpc/build_basl.py     GPBMODS.BASL     GPBMODS.SRC.PRG
python source/gpc/compile_shared.py GPBMODS.SRC.PRG  GPBMODS.PRG  GPBMODS.MAP
```

Shared, not `--embedded`: the object's byte count is then the p-code, which is the number this
project watches.

A `gpbmods-demo.bat` at the root, on the pattern of `color-demo.bat`, runs the built object visibly.

Headless, for the build cycle: stop the tokenise on `SAVING`, stop the compile on `OK CODE` and
nothing else, and read the raw log rather than a filtered summary. Interactive panels cannot be
driven by paste; push keys through `kbdbuf_put` the way `MENUTST.EXP.BL` does, and accept that ALT
and CTRL combinations cannot be tested that way.

## 6. Banked and low

One rule generates the whole list: **code fetched from `$A000-$BFFF` cannot be running when the bank
register changes.** The runtime findings behind each entry are in `TODO.md`, *How much of the GUI
library fits in a bank?*

### Safe banked, no runtime change

| what | |
|---|---|
| arithmetic, `IF`, `FOR`/`NEXT`, `GP.DO`, `GP.SELECT`, `GP.IF` | frames sit on the frame stack, 4K below the workspace in low RAM |
| variables, arrays, the string heap, `DIM` | all in the low-RAM workspace |
| `GOSUB`/`RETURN` inside the module | PC-relative, and the module is contiguous |
| calls out to low-RAM routines, and back | the low-RAM routine banks freely; `RETURN` restores from the frame |
| `GP.BOX`, `GP.FILL`, `GP.PRINTAT`, `GP.DRAW`, `GP.TILE` | runtime handlers, resident in low RAM |
| `VPEEK`/`VPOKE`, direct VERA at `$9F2x` | VERA is not in the window |
| string functions, `GP.INSTR`, `GP.COMP`, `GP.STRPTR` | operate on heap pointers |
| `PRINT`, `GET`, `GETKEY`, joystick | subject to the KERNAL question below |

### Banked after a named fix

| what | the fix |
|---|---|
| `PEEK`/`POKE` after `BANK` | `CommandBank` writes the hardware register. It must set `ramBank` only. `PEEK`/`POKE` already select and restore around each access, so they keep working and banked code reaches any bank. |
| `GP.ASM` blobs | the blob is always in low RAM -- the pool is appended after the p-code's `$FF` marker -- so it may bank freely, but it must restore the code bank before its `RTS`. |
| `GP.CALL` / `SYS` to an address | same rule: the target restores the bank |
| an entry reached by `GOTO` | there is no frame to restore the bank from. Banked entries are `GOSUB`-only, which makes the `GOTO <mod>.MODULE.END` skip-over at the top of every module wrong in a banked file. |

### Low always

| what | |
|---|---|
| `DATA` / `READ` / `RESTORE` | the read cursor is `objPtr`, a bare 16-bit pointer, and a bare `RESTORE` re-bases it to the low-RAM p-code base. Banked `DATA` is unreachable. No library module uses `DATA` today. |
| `BLOAD` / `BSAVE` into a bank | the KERNAL advances the bank itself and the handler leaves it there |
| the `GP.ASM` pool | structural -- it is the object tail |
| the error handler, any `ON ERROR` target | reached by a longjmp that carries no bank |
| a string literal whose pointer outlives the call | `.string` pushes a bare pointer INTO the p-code. Assignment concretes it onto the heap, so `A$ = "x"` and `PRINT "x"` are fine; handing the raw pointer to something that stores it is not. |
| `BANKMGR` | it hands out the code bank, so it cannot live in one |

### Per module

| module | verdict | |
|---|---|---|
| `GUI` | banked | no `BANK`, no `GP.ASM`, no `DATA`. `STASH.BANK = GUI.BANK` is an assignment, not a switch |
| `GUI2` `MENUVERT` `MENUBAR` `LINEINPUT` `STRINGS` `THEME` `APPSYS` | banked | clean on all three counts |
| `STRCASE` `SORT` | banked once their blobs restore the bank | 26 and ~100 bytes of p-code, so there is little in it |
| `STASH` | low | the only module that executes `BANK`, three sites, and its blobs write into the window |
| `STASHFILE` | low | `BLOAD` / `BSAVE` with a bank argument |
| `BMX` | low | file I/O across banks. Its `BMX.BANK` is a VERA bank bit, not RAM |
| `BANKMGR` | low | see below |

Banked total: `GUI` 2,147 + `GUI2` 1,618 + `MENUVERT` 1,122 + `MENUBAR` ~900 + `LINEINPUT` 704 +
`STRINGS` ~560 + `THEME` 226 + `APPSYS` 88 = **~7,365 bytes, one bank with 800 to spare.**

**THE KERNAL QUESTION IS ANSWERED, 2026-09-05: `$00` IS PRESERVED.** `BANK 5`, then a `GP.ASM`
blob reading the live register after each call, on R49. `CHROUT`, `GETIN`, a 40-line screen-editor
scroll, `CLS` and `screen_mode` all came back 5, as did `GP.FILL` and `GP.PRINTAT`, which call no
KERNAL routine. Banked p-code is not blocked by the KERNAL.

It had to be measured in assembly: GPC's `PEEK`/`POKE` save `$00`, select `ramBank`, access and
restore, so `PEEK(0)` reports the bank it was told to use and never the hardware one. A probe
written with `PEEK` passes regardless and proves nothing.

## 7. BANKMGR.INC.BL -- the bank manager

A new low-RAM module. It owns which banks are in use, so nothing else hard-codes a number.

State: a 32-byte bitmap, one bit per bank, 256 banks. Not an array -- an array comes out of the
workspace, and 32 `POKE`d bytes in low RAM is the cheaper shape.

| entry | |
|---|---|
| `BANKMGR.INIT` | read the real bank count, reserve bank 0, mark everything above the count unavailable |
| `BANKMGR.CLAIM` | take a named bank, fail if taken. The code bank claims itself here, first |
| `BANKMGR.ALLOC` | the lowest free bank, or 0 for none |
| `BANKMGR.FREE` | give one back |
| `BANKMGR.COUNT` | how many exist, how many free |

**The count comes from `MEMTOP` (`$FF99`) with carry set**, which returns it in `A` -- a `GP.CALL`
with `GP.C` set and `GP.A` read back, the shape `MLCALL.EXP.BL` demonstrates. An X16 is 512K or 2MB
and nothing else, so there are exactly two answers.

WARNING: `MEMTOP` RETURNS `$00` ON A 2MB MACHINE. The count is a byte and 256 does not fit, so 512K
reads `$40` = 64 banks and 2MB reads `$00`, meaning 256. A manager that treats 0 as "no banks"
fails on exactly the larger machine. The reference also notes other values are possible on a system
with bad banked RAM.

Two things it absorbs rather than breaks:

- **The editor already hard-codes a map** -- banks 1-3 line table, 4 GUI stash, 5 menus, 6+ document
  arena, written into `ED-STORE.BASL` as constants. Those become `BANKMGR.CLAIM` calls, or the
  manager is a second source of truth.
- **`GUI.BANK = 0` already means "do not save the screen"**, so 0 is load-bearing as a not-a-bank
  value. `BANKMGR.ALLOC` returning 0 for "none free" agrees with it, and that agreement is
  deliberate.

## 8. What this project is for

The measured case for moving library p-code into a RAM bank is in `TODO.md`, *How much of the GUI
library fits in a bank?*, together with the runtime findings. This program is the proving ground for
it, in three ways:

- It is the first program that holds the **whole** library at once, so it produces real per-module
  numbers instead of GPC-HELP's five-module subset.
- It is the first program that hits the wall from the library side rather than from its own driver,
  which is the case the banking work is aimed at.
- Each panel is an isolated caller of one module, so a module can be moved to a bank and its panel
  re-run without anything else in the program changing.

Two banks are spent: one for banked module p-code, one for `GUI.BANK`'s screen stash. Both come
from `BANKMGR`, and the code bank is claimed first. A 512K machine has 63 usable; a 2MB machine 255.

## 9. The banked GUI, and why there is no linker

**A linker is not needed and should not be written.** A linker exists to resolve symbols between
separately compiled units. There are no separately compiled units here and no symbols to resolve:
this stays ONE compilation unit, `FixBranches` still sees every branch, and the line-number table
still resolves every `GOTO` and `GOSUB` target. What is needed is RELOCATION, and only in one place.

**Reachability is already unlimited.** `STRMakeOffset` is a plain 16-bit `target - objPtr` and
`PerformGOTO` the matching 16-bit add, both wrapping. Low RAM to `$A000` is `+$9600`; `$A000` back
is `+$6A00`. Every source reaches every target, so there is nothing to link around.

**The one thing that breaks.** Offsets are computed in BUFFER addresses, which works because every
byte in the buffer has the same delta to its runtime address, and the deltas cancel in the
subtraction. A banked region has a DIFFERENT delta -- buffer to `$A000` rather than buffer to
`$0900 + n` -- so branches WITHIN either region stay correct and only branches ACROSS the boundary
come out wrong, by exactly the difference of the two deltas. `FixBranches` has to know which side
each end is on. That is the whole compiler change.

### The shape, and its precedent

**`GP.ASM`'s blob pool already does this.** `AsmFlushPool` appends the pool to the object AFTER the
`$FF` end marker, records where it landed, and `AsmPatchAll` fixes the references once both bases
are known. A banked region is the same mechanism with the payload going to a sidecar file instead of
to the object tail.

It must be emitted AFTER all low-RAM code for the same reason the pool is: removing it from the
object must not shift anything below it.

### What it costs, staged

| | |
|---|---|
| `GP.BANK <n>` / `GP.ENDBANK` marking a region | compiler, a block keyword on `GP.ASM`'s pattern |
| the region emitted at `$A000`, to a `.BNK` sidecar | compiler / object writer |
| `FixBranches` computing cross-boundary offsets from runtime addresses | compiler, one delta test |
| `BLOAD` the sidecar into the bank at startup | THE PROGRAM. No runtime change |
| every routine that changes the bank puts it back | THE LIBRARY. `STASH` is the only one |

**No new opcode, no frame change, no `CommandBank` change**, provided the code bank is selected as a
program-wide invariant. The spike confirms the invariant survives what matters: it selected bank 7,
and after the banked `RETURN` landed in low RAM the bank was still 7 and nothing cared, because low
RAM is not banked.

**The sidecar is the real cost.** A second file to ship and to have deleted. Shared mode already
needs `GPC.RT.nnn.BIN` beside the object, so it is the same shape rather than a new one.

### Built so far

**Increment 1, 2026-09-05: `GP.BANKED` / `GP.ENDBANKED` exist and record a region.** Tokens 52823
and 52822, `commands.def` with no `T` on either so `ScanGPUsage` cannot see them, handlers in
`source/compiler/source/commands/gpbank.asm`. They emit nothing: the object built with the markers
was byte for byte the object built without them, MD5 `28f13f2d…`, 346 bytes both ways.

**Increment 2, 2026-09-05: the region moves to the end of the object.** `GPBankRelocate`, called
from `SaveCodeAndExit` after the `$FF` end marker and BEFORE `FixBranches`, so every branch is still
an unresolved line number.

The move is a ROTATION done in place -- shift the region and everything after it up by three, then
reverse the region, reverse the tail, and reverse the pair -- and it is spliced back into the flow
with two ordinary `GOTO`s to ordinary line numbers. That is the whole trick: the region begins on
the `GP.BANKED` line's marker byte and ends on the `GP.ENDBANKED` line's, so both lines have a
line-table entry pointing exactly at a boundary. Correct the table and `FixBranches` -- which runs
next and knows nothing about any of this -- resolves both bridges by the path it resolves every
other `GOTO`. **No new opcode, no absolute operand, no back-patching.** Six bytes, and a program
without a `GP.BANKED` pays none of them.

Three things hold a buffer ADDRESS rather than a line number and had to be corrected by hand: the
line-number table, `.fngosub` (a `DEF FN` body, absolute until `FixBranches` makes it an offset),
and `GP.ASM`'s blob-call fixups, whose target is where in the buffer the `.word` operand sits.

Both markers must be the FIRST statement on their line -- that byte is the boundary -- and both must
be outside every `GP.DO` and `GP.SELECT`, because a `GOTO` written after compilation has no
`.unwind` in front of it. All three ways to get it wrong are `BLOCK MISMATCH`.

Eleven tests in `testing/BANK*.BASL`, each marked program run against an identical unmarked control:
a region mid-code entered and left by fall-through; a region after `END` holding only subroutines,
one of which calls back out (the library shape); `GOTO` into, within and out of a region; a `DEF FN`
body and a `GP.ASM` blob inside one with a second blob after it. Same output every pair, objects six
bytes apart. `GPC.BIN` 16,409 → 17,269.

**The map file is no longer sorted by offset** for a program with a region -- every entry is right,
but the region's lines carry the highest offsets while sitting in source position. Noted in
`WriteMapFile`.

**Increment 3a, 2026-09-05: `GP.BANKED <n>`, the region past the pool, page aligned.** The bank is
a decimal constant read by the handler, not an expression -- it is patched into the bootstrap, so
there is nothing at run time to evaluate it. Bank 0 is refused: it is the KERNAL's.

The layout the region ends up in, and why:

```
[A][GOTO in][C][$FF][GP.ASM pool][pad][B the region][GOTO out][$FF]
 \_________ low RAM, $0900 _________/  \___ bank n, $A000 ___/
```

**The pool stays in low memory and the region goes above it.** A blob is 65C02 code, and a blob
that changes the RAM bank -- `STASH` does -- must not itself be executing out of one. Putting the
pool below is also what will let the region's low-memory copy be reclaimed: the workspace can start
where the region starts, because everything still needed is underneath it.

**The region is page aligned**, so the bootstrap's copy is a page loop -- source page, page count,
bank, three patched bytes. There are 33 spare bytes in the bootstrap page and a byte loop does not
fit in them. The padding costs nothing at run time: the workspace start is a page number anyway.

**Two object walkers now hop over the pool** -- `FixBranches`' main loop and its unwind-depth walk,
and `ScanGPUsage`. Both stopped at the `$FF` that ends the low code, which is now in the middle.
`GPBankHop` returns carry clear when it has hopped; a program with no region always gets carry set,
so nothing changes for it.

**One real regression, caught by the tests.** Moving `AsmFlushPool` ahead of `FixBranches` was not
free: **`FixBranches` destroys `objPtr`**, rewinding to the start and walking to the end marker, so
it returns pointing at the `$FF`. That used to be the end of the object because the pool went on
afterwards. With the pool written first, `objPtr` -- which is the length `WriteObjectCode` streams
-- cut every pool off the file: a program with an inline blob compiled OK and jumped into nothing at
the first call. `SaveCodeAndExit` now holds the real end in `objectEnd` across the call.

Thirteen tests, `testing/BANK*.BASL`. `GPC.BIN` 17,269 -> 17,694.

### Still to do for 3b

The cross-boundary branch correction, the bootstrap's copy loop, and the workspace trim. Nothing
runs from a bank yet: the region still executes where it lands, which is why 3a can be tested at
all.

**Increment 3, 2026-09-05: the region RUNS FROM THE BANK.** `GP.BANKED <n>` takes the bank as a
decimal constant, refuses bank 0 (the KERNAL's), and three things landed together because the
correction miscompiles until the region really is at `$A000`:

- **The cross-boundary correction is ONE BYTE.** An offset is target minus source in buffer
  addresses, which works because both ends share a buffer-to-run delta that cancels. The region's
  delta is different, so only a branch with one end each side is wrong -- by `$A0` minus the page
  the region would have run at. Both bases are page aligned, so that is a whole number of pages and
  lands entirely in the offset's high half. `GPBankMakeOffset` replaces `STRMakeOffset` in
  `FixBranches`' two patch tails and does nothing at all when the ends match, which is every branch
  in a program with no region and almost every branch in one that has.
- **The bootstrap copies it in, and there is no second file.** 33 bytes at `$08DF..$08FF`, which
  fitted after reclaiming 4 elsewhere (`stz abs,x` for the magic wipe, and letting `BBLoadX` fall
  through into `BBTryLoad`). Three patched bytes: source page, page count, bank -- and the source
  page is patched straight into an instruction OPERAND, which is what keeps it inside the padding.
- **ONCE PER LOAD, NOT PER RUN.** The workspace starts where the region was, so on a second `RUN`
  those bytes are variables. The bootstrap zeroes its own page count, so the second run skips the
  copy and uses what is already in the bank.

**PROVEN, not inferred.** The region is still present at its old low-memory address in the loaded
image, so a branch that wrongly pointed back at the low copy would work too until the workspace grew
over it. `BANKP` reads the answer out instead: a blob inside the region reports **codePtr `$A0xx`
(160) and bank 5**, against `$09xx` from low memory. And the workspace start is **page 26 for a
293-byte marked program and page 26 for its 101-byte control** -- the region's low-memory copy is
fully reclaimed.

**SHARED MODE ONLY.** Embedded has no bootstrap to do the copying, and the run base is not known
while the crossing branches are being resolved, so a region there is `NOT IMPLEMENTED` against its
line rather than guessed at.

`GPC.BIN` 17,694 -> 17,949. **Runtime unchanged, still zero bytes** -- every runtime source is
identical to HEAD but for two comment lines and two unreferenced token equates.

### The bank discipline, and how it is enforced

Banked p-code is FETCHED from `$A000`, so the code bank has to be selected at every fetch inside the
region. Two programs settle what that costs: `BANKR` does `BANK 3` in low memory and then calls into
the region -- it compiles clean, prints two lines and hangs. `BANKS` is the same program with the
code bank put back before the call, and runs to the end.

- **`PEEK` and `POKE` need no thought.** They save the selected bank, switch, access and restore, so
  they work from banked code unchanged.
- **`BANK` inside a region is refused at compile time** -- `NOT IMPLEMENTED`, against the `BANK`.
  It writes the hardware register and leaves it, so it would kill not itself but whatever followed
  it, which is the worst possible place to be told. BUILT.
- **The library selects its own bank on the way in**, with a low-memory shim per public entry point.
  That is what makes the application's banking a non-issue. See TODO.md; it is library work and goes
  in when the GUI is banked.
- **`STASH` puts the bank back.** The shim closes the way in; this is the way out. `STASH` is the
  only routine in `GPC-BASIC` that leaves a bank selected.

**`BANK` KEEPS ITS SEMANTICS.** Making it set the `PEEK`/`POKE` target without touching the hardware
was considered and dropped: it is invisible to BASIC and would have closed `BANK`, but `BLOAD`,
`BSAVE` and `BVERIFY` write the register directly and would still have leaked -- so it bought one of
four cases at the price of changing a shipped statement.

Nineteen test sources in `testing/BANK*.BASL`. Thirteen are the pass/fail suite; the rest are the
one-off proofs named above.

### What is NOT settled

- `#INCLUDE` granularity. A module is a file and the region wants to be a whole file, so the marker
  probably belongs around the `#INCLUDE` rather than inside the module -- which BASLOAD does not
  currently allow.
- What happens on a runtime error inside banked code. The handler is low RAM and is reached by a
  longjmp, so it runs; whether the bank it leaves behind matters has not been checked.

## 10. Steps

1. **Measure. DONE 2026-09-05** -- the table in §3 is the result, and the shell built to compile it
   is `GPBMODS.BASL`. Method: `compile_shared.py SRC OBJ MAP` writes an address-per-line map;
   difference it against the `#SYMFILE` output. Two parsing notes for the next run -- the SYM's
   `LABELS` section reuses the previous file's `FILE:` header for the main program, so the boundary
   is where the source line number DROPS; and `GPB.INC.BL` never appears, having no labels.
2. **The KERNAL bank question. DONE 2026-09-05 -- PASSED.** Seven checks, all returning the bank
   that was set: baseline, `CHROUT`, `GETIN`, a 40-line scroll, `GP.FILL`/`GP.PRINTAT`, `CLS`, and
   `screen_mode`. The probe must be a `GP.ASM` blob; `PEEK(0)` cannot see the hardware register.
   The gate on the banked design is clear.
3. **`BANKMGR.INC.BL`. DONE 2026-09-05** -- 590 bytes, in the shell, claiming banks 2 and 3 at
   startup, read out by ABOUT / BANK MAP. Eleven assertions pass headlessly: `BANKS 64` on the
   emulator, free 61 after two claims, a re-claim refused, `ALLOC` returning 1 then 4 around them,
   `ALLOC` returning 2 again after a `RELEASE`, bank 0 and bank 64 both refused, bank 63 taken, and
   a drain of exactly 58 more before it returns 0. NOT YET COPIED to the root `GPC-BASIC/` -- the
   panel has not been watched on screen.
4. **The shell.** Bar, dropdowns, cross-axis exits, `APPSYS` bracket, ABOUT panel. One module under
   test — `MENUBAR` — and the shell is its panel.
5. **The panels**, one bar item at a time, each behind its flat guard. `DIALOG` first: it is the
   biggest, and it decides whether the guards are needed at all.
6. **The regression pass.** Every panel run once against the current root modules. Anything that
   fails is a defect in the module or in the panel, recorded before any refactor starts.
7. **The banked GUI**, against a harness that already proves the before state.

**PROVEN 2026-09-05, ahead of the panels: p-code executes from a RAM bank.** `SPIKE.BASL` in this
folder does it with two `GP.ASM` blobs and a copy loop, changing nothing -- no ABI change, no
runtime change, no compiler change. `GOSUB SPIKE.CAPTURE` runs `SPIKE.MARK = 111 : RETURN` in low
RAM while a blob records `codePtr + Y`; 64 bytes are copied to bank 7 at `$A000` with the `111`
patched to `222`; a second blob points `codePtr` at the window; `MARK` comes back **222**.

Two things it settled that the design needs:

- **Leaving a banked routine needs no bank restore.** `RETURN` pops the entering `GOSUB`'s frame and
  puts `codePtr` back in low RAM, below `$A000`, where banking does not apply. A bank byte in the
  frame is about RE-ENTERING a banked routine, not about leaving one.
- **A blob cannot set Y by loading it.** `CommandSYS` restores Y from the 6502 stack after the call,
  so a blob must write the saved copy at `$0103 + S` (`tsx`, then `sta $0103,x`). That stack offset
  is why `SPIKE.BASL` is a spike: it depends on `CommandSYS`'s exact prologue, which a real opcode
  would not.

`codePtr` is `$28`, and `objPtr` `$2A`, `zTemp0` `$2C` follow it.

## 11. Open

- Whether the bar fits eight items at 80 columns with readable padding. An item's width is its text,
  so `" DIALOG "` and not `"DIALOG"`.
- Whether `SORT` and `BMX` belong here at all, or stay as their own `.EXP.BL` examples.
- Whether the 22 `GPC-BASIC/*.EXP.BL` files are retired into panels or kept beside them. Each is a
  working single-module example, and `MENUDEMO.EXP.BL` has already settled one false library bug on
  its own.
- The variable count. Every module's name space is live at once, the compiler's variable list has
  its own bank, and `PROGRAM TOO BIG` has three raise sites of which only one is the object.
- Whether `BANKMGR` belongs in the release library or stays a harness module. The editor and
  GPC-HELP both hard-code their banks today and neither is broken by leaving it here.
