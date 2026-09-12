# OASIS_MSGPOST -- conversion from BASLOAD BASIC to GPC

`OASIS/OASIS_MSGPOST` is one BASLOAD compilation unit: `MSGPOST.BAS` plus nine includes, about
3,100 lines, **19,723 bytes tokenised** against the interpreter's 38,655-byte ceiling. It is
entered by chain-load from BBSMSG, posts one message, and chain-loads BBSMSG back. State crosses
the `LOAD` through golden RAM at `$0400`-`$0440`.

It converts. One keyword is unsupported, one directive must go, and two things are design work:
the golden-RAM handoff and the 200-slot editor line array.

## 1. What compiles unchanged

Every X16 and CBM keyword in the unit was diffed against `getX16()` in
`source/common-scripts/c64tokens.py` and against the compiler's five keyword tables
(`source/compiler/source/generation/commands.def`, `unary.def`, and the three `x16_*.def`).
Sixteen X16 keywords are rejected by the compiler -- BANNER, BASLOAD, BOOT, CODEX, DOS, EDIT,
EXEC, GEOS, HBLOAD, HELP, KEYMAP, MENU, MON, OLD, REN, TEST. Only `DOS` appears in the source.

Supported, and several already in use:

| feature | where |
|---|---|
| `BINPUT#` | `OASIS.BI:547`, `MSG.BI:335` |
| `LINPUT#`, `GET#`, `CMD`, `OPEN`/`CLOSE`, `PRINT#`/`INPUT#` | throughout |
| `DEF FN` x7, including `FN SW(X)` nested inside `FN Lo.Byte` | `STANDARD.BI:2-12` |
| `BANK PEEK(0), 0` -- the two-argument form | `STANDARD.DEF` |
| `ST`, `TI$` -- real tokens, `PCD_ST` / `PCD_TIDOLLAR`, read-only | `OASIS.BI:494`, `MSGWRITE.BI:130`, `OASIS.BI:621` |
| `RESTORE <label>`, `ON`..`GOTO`, `DATA`/`READ` | `STANDARD.BI` |
| `BLOAD`, `BVLOAD`, `VPOKE`, `RECT`, `CHAR`, `COLOR`, `SCREEN`, `SLEEP`, `CLR`, `WAIT`, `RPT$`, `MOD` | throughout |

`INPUT.BI` needs no changes. There are no label/variable name collisions in the unit, so no
BASLOAD `DUPLICATE SYMBOL`. There is no `#DEFINE` in the unit today, so the digit-rejection trap
does not yet apply -- see §5.1.

## 2. Blocker: DOS, 19 sites

`DOS` compiles clean and throws at run time. `errorhandler.asm` arms `deferErrors` per statement,
rolls the statement back, and emits a throw-stub: `SYNTAX ERROR @ $xxxx`, with no line number and
no keyword name.

WARNING: `OK CODE` is not a passing test for this unit. Run `source/common-scripts/deferscan.py`
on the object and require zero deferrals.

The replacement is already in the unit. `DOS.CMD` at `STANDARD.BI:146`:

    DOS.CMD:
     OPEN 15, DEVICE, 15, COMMAND$
     GOTO GETFCODE
    GETFCODE:
     INPUT#15, FCode, FC$, A, B : CLOSE 15 : RETURN

`POSITION` (`STANDARD.BI:109`) and `KILLFILE` (`STANDARD.BI:115`) already build `COMMAND$` and
`GOTO DOS.CMD`. Each `DOS X$` becomes `COMMAND$ = X$ : GOSUB DOS.CMD`. The only behaviour lost is
DOS's status print to the sysop screen.

Sites:

| file | lines |
|---|---|
| `MSGPOST.BAS` | 109 |
| `MSG.BI` | 328, 380, 446, 496 |
| `MSGWRITE.BI` | 459, 504, 508, 533, 569, 570 |
| `OASIS.BI` | 339, 470, 491, 497, 634, 657, 672, 722 |

Fourteen are `CD:`, four are `S:`, one is `R:`.

## 3. Blocker: golden RAM is the runtime's storage section

`source/runtime/build/code.lbl`:

    StorageEnd   = $5f3
    ldNameLen    = $470

`MemoryStorage = $400` and `CodeStart = $801` (`source/common-source/source/common.inc`). The
runtime's storage section occupies `$0400`-`$05F2` -- `StorageEnd` is the label just past
it. What lands on any given byte inside it changes with each compiler build.

The OASIS map (`OASIS.DEF`), 65 bytes, all of it inside that range:

| address | use | collides with |
|---|---|---|
| `$0400` | `GR.MODE.ADDR` | storage |
| `$0404` | `USER.TERMINAL` | storage |
| `$0407` | `GR.SCREEN.WIDTH.ADDR` | storage |
| `$0408` | `GR.POST.BASE.ADDR` | storage |
| `$040A` | `GR.REPLY.TGT.ADDR` | storage |
| `$040C` | `GR.REPLY.ADV.ADDR` | storage |
| `$0410`-`$041E` | last-caller string | storage |
| `$0421`-`$042F` | username string | storage |
| `$0431`-`$043F` | caller-IP string | storage |

The runtime's own storage destroys the block.

The only free window below the code is `$05F3`-`$0800`, 525 bytes. That is the storage section's
growth room, guarded only by `.cerror StorageEnd > CodeStart`. A handoff pinned there breaks
silently on a compiler build that grows storage.

See §6 for the handoff options.

## 4. Blocker: DIM MSG.LINE$(200) against the string heap

`MSG.LINE.MAX = 200` (`MSG.DEF:94`); `MREC.BODY.SIZE = 5000` (`MSG.DEF`). A GPC concrete string
block is `length * 1.5 + 3` and is never freed -- only flagged dead and re-fitted by the
scavenger. There is no compaction.

A full body across 200 slots wants about **8,100 bytes** of heap.

Workspace budget, from `CodeStart = $801` and `FrameStackPages = 8`:

| p-code | code ends | workspace to `RTBASE $6E00` | less varspace and pointers | heap available |
|---|---|---|---|---|
| 12,200 | `$37A9` | 11,863 | -2,400 -402 | **~9,060** |
| 15,000 | `$4299` | 9,063 | -2,400 -402 | **~6,260** |

Roughly 400 scalars at 6 bytes each is the 2,400; 201 array pointers at 2 bytes is the 402.

It fits at the low end of the p-code estimate and does not fit at the high end, with nothing to
spare either way. `EDIT.DEL` and `EDIT.INS` (`MSGWRITE.BI:341-390`) shift every element,
reassigning up to 200 strings of varying length per command, which is the churn the scavenger
handles worst. The interpreter stores the same body in about 5,600 bytes and garbage-collects it.

**Recommended: fixed-width line slots in a RAM bank.** 200 slots x 80 bytes = 16,000 bytes, two
banks. `MSG.LINE$(n)` becomes a get/put pair. `/D` and `/I` become one KERNAL `MEMORY_COPY`
(`$FEE7`) inside the bank instead of 200 string reassignments -- faster than what it replaces, and
it takes the editor buffer off the heap entirely.

Alternatives: a scratch SEQ file per line, or a lower `MSG.LINE.MAX`. `STASH.INC.BL` is not an
option; it stashes screen rectangles only.

## 5. Free wins

### 5.1 The .DEF files to #DEFINE

The four `.DEF` files assign **239 constants at run time**: STANDARD.DEF 89, VERA.DEF 29,
OASIS.DEF 84, MSG.DEF 37. That is about 1.4 KB of `.varspace` and 1.7 KB of p-code.

**145 of the 239 are never referenced by any `.BI` or `.BAS`.** Neither BASLOAD nor GPC eliminates
dead code, so all 145 are paid for in full. Converting the set to `#DEFINE` recovers all of it.

Trap: `#DEFINE` rejects any digit in the name -- `WIDTH.40`, `LAYER1.ON`, `R0L`. Sixty-five names
carry digits, mostly the unreferenced R0-R15 register aliases. Rename or leave those as variables.

`STANDARD.DEF` and `VERA.DEF` are Tony 3068's, MIT-0, marked not to be modified. A local
`#DEFINE` version is a new file, not an edit to those.

### 5.2 GP.INSTR for the hand-rolled scans

The unit has 74 `MID$` calls, 34 of them in `MSG.BI`, because the interpreter has no `INSTR`.
`GP.INSTR`, `GP.CONTAINS` and `GP.COMP` replace those loops and `STANDARD.BI`'s own `INSTR`,
`UCASE`, `TRIM`, `LTRIM` and `RTRIM`.

Cost: one GP keyword pulls the GP block in and moves the workspace ceiling from `RTBASE $6E00` to
`RTGPBASE $6600` -- **2,048 bytes of workspace**. Against §4 that is not free. Take it for the
speed, and only after §4 is settled and the margin is measured.

### 5.3 The SEND layer

`SEND.STRING` (`OASIS.BI:235`) is per-character `PEEK`/`POKE`/`MID$` over a serial channel, fully
compatible, and the largest speed win in the unit.

`FOR SEND.IDX = 1 TO LEN(SEND.STR$)` has no empty-string guard. `FOR 1 TO 0` runs once in stock
BASIC and in GPC, so an empty string sends one garbage byte. The unit guards this everywhere else
-- the comments read `GUARD (Rule 8)` -- so it is an oversight in both worlds. Fix it while
converting.

### 5.4 GET.LINE

`INPUT.LINE$ = INPUT.LINE$ + CHR$(IL.C)` (`INPUT.BI`) reallocates a heap block per keystroke.
Correct under GPC, and the scavenger re-fits the dead blocks, but a fixed buffer with a length
counter is cheaper if §4 leaves the heap tight.

## 6. The handoff

| option | cost | risk |
|---|---|---|
| Move the block to `$0600` | smallest diff | unreserved storage growth room; breaks silently on a future compiler build |
| **`SVARS.BASL`** | one disk round-trip per hop | none structural |

**Take SVARS.** `OASIS/tmp-test/SVARS.BASL` mirrors the golden-RAM layout one for one: `SV(0..12)`
is the twelve scalars plus a spare, `SV$(0..2)` is the three 15-character strings. It uses logical
file 5, secondary 5, writes one value a line with names in `CHR$(34)` quotes, and reads channel 15
before its first `INPUT#` so a missing file reports 62. It needs no reserved memory at all, and it survives a
power cycle, which golden RAM does not. Its header says the compiler is not involved
yet; everything it uses is supported, so step 1 is a standalone compile to confirm.

Surviving a power cycle is a defect for one flag. `BBSINIT.BAS:198` treats `$0400 = 1` as "I just
reloaded myself", so a file that still reads 1 after a power-on makes a cold boot skip UART init.
That one byte stays in memory at `$0700`, above both builds' `StorageEnd`. See
`FULL-SOURCE.PLAN.md` section 2.5.

There is no third option. GPC's `LOAD` clears memory on entry, the same as the interpreter, so no
variable reaches the next program and nothing this one allocated strands in its heap. `CLR` on
entry is not needed. See `FULL-SOURCE.PLAN.md` section 3.

## 7. Size, and mixed chains

Source-to-object ratio, measured across every `.SRC.PRG`/`.PRG` pair in `samples/` and `testing/`:
region-free programs land at **0.59-0.77**. The closest in size to MSGPOST is GPB.HELP, 23.5 KB
tokenised to 14,595, at 0.62.

19,723 tokenised gives **roughly 12,000-15,000 bytes of p-code** against the shared ceiling of
about 17,920 (`RTBASE`). No banking needed for the code. All the pressure is on the workspace.

**A staged port works, one program at a time.** `Command_LOAD` does not reimplement loading: it
builds a real `10 LOAD "name"` at `$0801` and enters the ROM's `RUN`. A compiled MSGPOST can
chain-load an interpreted `BBSMSG.PRG`, and the reverse. The resident runtime at `$6E00` becomes
dead memory that the interpreted program's string heap overwrites; the next compiled program's
bootstrap finds the magic at `RTBASE` gone and reloads it.

## 8. Steps

1. **Repoint the build.** Work directory with `GPC.BIN` and `GPC.IMG.<ver>.BIN` from `testing/`,
   and `GPB.INC.BL` from the root `GPC-BASIC/`. Flatten the absolute `/BASIC/INCLUDES/` paths in
   the `#INCLUDE`s. Add `#SAVEAS "@:MSGPOST.SRC.PRG"` and `#SYMFILE "@:MSGPOST.SRC.SYM"` before
   the `#INCLUDE`s. Delete `#AUTONUM 10` (`MSGPOST.BAS:36`) -- it sets the step, not whether
   numbering happens, and any step but 1 breaks label resolution in an included module with
   `UNKNOWN LINE NUMBER @ nnn` naming a line that cannot exist.
2. **Kill DOS.** Nineteen sites to `GOSUB DOS.CMD` per §2. Then `deferscan.py` on the object and
   require zero deferrals. This is the compile-clean gate.
3. **Constants to `#DEFINE`** per §5.1. Measure `.varspace` before and after.
4. **SVARS in, golden RAM out.** Compile `SVARS.BASL` standalone first. Then replace the PEEK
   preamble in `MSGPOST.BAS` and the exit `POKE $0400, POST.RET.MODE`.
5. **The editor buffer to a bank** per §4. Design the slot layout and the get/put pair, then
   rewrite `EDIT.DEL`, `EDIT.INS` and `EDIT.SHIFT` as `MEMORY_COPY`. This is the only step that is
   a design change rather than a translation.
6. **Measure, then decide on GP.INSTR** per §5.2. Steps 1-5 give the actual workspace margin,
   which is the number that says whether 2,048 bytes for the GP block is affordable.
7. **Run against an interpreted BBSMSG**, both directions, watching `FRE(0)` on each hop.

Steps 1-4 are mechanical and independent. Step 5 is the one to settle before typing.

## 9. Open items

- The slot width in §4. Eighty bytes covers an 80-column terminal; `SCREEN.WIDTH` is read from
  golden RAM and the editor does not assume 80.
- `MSG.BI:384` does `BLOAD MO.B$, DEVICE, NATIVE.HELPER.BANK, MSGLIB.RECADDR` and then
  `BANK NATIVE.HELPER.BANK`. Which bank the helper claims has to be reconciled with the two banks
  §4 wants, and with `BANKMGR.CLAIM` if any library module is pulled in.
- Whether the other eight OASIS programs move at all. §7 says they do not have to.
