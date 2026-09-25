# GPC.ERR: from an address to a source line

Handoff document. Phases 1 to 4 are built and verified. Phase 5 is not needed. It rewrites
`testing/GPC.ERR.BASL` from a two-prompt text helper into a GUI tool that answers with a file name,
a source line and the text of the offending statement.

The name does not change. `release.sh` stages `testing/C.GPC.ERR.PRG` as `GPC.ERR.PRG` and that
stays true.

## 1. The problem it solves

GPC.ERR today answers `$34A7` with `IS ON/NEAR BASIC LINE 1669`, and 1669 is useless on its own.
BASLOAD inlines every `#INCLUDE` before the master, so the number counts lines in the merged
program. For `GPB.HELP` the thirteen library modules fill lines 1 to 1652, and the master's own
first label, `HELP.BOOT`, is BASIC line 1653. Every number the tool prints is about 1,650 too large
to look up in the `.BASL` the programmer has open, and it lands on a real but unrelated line, which
is worse than landing on nothing.

The answer is already on disk. `NAME.SRC.SYM`, which BASLOAD writes beside the tokenised program,
carries the file boundaries and the crunched-name table. Nothing reads it today.

### 1.1 Why this is worth building

The errors that need it are the ones the compiler declined to report.

`source/compiler/source/main/compiler.asm:247`, `DeferStatementToRuntime`, replaces a statement that
failed with a SYNTAX error by a `PCD_CMD_DEFERROR` throw-stub and carries on at the next line. The
compile then says `OK LOW CODE`. The stub raises `SYNTAX ERROR` at an address, and only if execution
reaches it. A clean compile is not a clean program. The compiler names the BASIC line above the
banner, section 5. At run time the address is the only evidence there is.

Two cases in this repo:

- `GP.UPPER` and `GP.LTRIM` left the runtime for `STRCASE.INC.BL`. BASLOAD no longer had a `#TOKEN`
  for them, crunched them to ordinary variable names, and the compiler deferred. Two files had been
  broken since `15d90eb` with nobody noticing. Cost two hours on 01/09/26. The note is at
  `compiler.asm:207-218`.
- `HELP.ROW$ = SPC(HELP.IXWIDE)` in `GPB.HELP.BASL`. `SPC(` is a PRINT-parser construct and a
  `GP.BANKEDSTR` body marker, not an expression. It compiled to exit 0 and threw
  `SYNTAX ERROR @ $34A7` on the first run.

`$34A7` is the worked example used throughout this document and in the test plan in section 7.

## 2. The three files it reads

All three sit beside the program, written by the same build.

### 2.1 NAME.MAP, address to BASIC line

Written by the compiler when the programmer asks for a debug map. ASCII, LF only, no CR. One record
a line, `"HHHH N\n"`: four hex digits of code offset, a space, the BASIC line in decimal.

Records ascend. There is one address space: a program with banked regions still produces a single
ascending map, so the "largest offset at or below the target" rule is sound and needs no change.

`GPB.HELP.MAP` is 18,911 bytes, 1,976 records, `$0006` to `$4ABC`. The last two records are lines
65024 and 65535, which are compiler setup and not source. GPC.ERR already special-cases those.

The map holds fewer records than the program has lines, because a line that emits no code gets no
record: 1,976 records for 2,268 BASIC lines.

### 2.2 NAME.SRC.SYM, BASIC line to file, and crunched name to real name

Written by BASLOAD. Two sections, `LABELS` then `VARIABLES`, each a run of `FILE:` headings with
records under them. A record is a six-digit line number in that file, the symbol, and the value:

```
FILE: GPB.HELP.BASL

 000147 HELP.BOOT                                           =1653;
 000204 HELP.IDXLOAD                                        =1677;
```

Under `LABELS` the value is the BASIC line the label became. Under `VARIABLES` it is the crunched
name:

```
 000186 HELP.ROW                                            =N6;
```

The `VARIABLES` line number is where the symbol was first seen, not every place it is used. For a
variable touched in twenty routines it is a hint, not a location. For a label it is exact.

`GPB.HELP.SRC.SYM` is 57,639 bytes. The `FILE:` order is the `#INCLUDE` order, master last.

### 2.3 NAME.SRC.PRG, the statement itself

The tokenised program. Standard BASIC layout: two bytes of load address, then per line a two-byte
link, a two-byte line number, the tokenised text, and a `$00`.

`GPB.HELP.SRC.PRG` is 35,302 bytes, 2,268 lines, last line number 2268.

The names in it are crunched. Line 1669 detokenises to:

```
1669  N6$="                                                                        "
```

Which is why section 4.4 exists. The `VARIABLES` half of the symbol file turns `N6$` back into
`HELP.ROW$`, first seen at source line 186, and section 4.7 is that lookup.

## 3. The resolution chain

```
$34A7
  -> MAP, largest offset <= target       $34A6, BASIC line 1669
  -> SRC.PRG, walk to line 1669          N6$="..."
  -> SYM LABELS, largest =N; <= 1669     GPB.HELP.BASL, nearest label HELP.BOOT
  -> SYM VARIABLES, reverse N6           HELP.ROW, GPB.HELP.BASL:186
```

The last step is what makes the tool worth using. `N6$` means nothing; `HELP.ROW$` is the line the
programmer wrote, and the `VARIABLES` record supplies the source line number directly.

Where the statement's leading symbol is a label rather than a variable, the `LABELS` record supplies
the same thing exactly.

Report both anchors and let the programmer judge:

```
$34A7  is $34A6 + 1, the first opcode of the line

  BASIC line 1669
  file        GPB.HELP.BASL
  near        HELP.BOOT, source line 147
  statement   HELP.ROW$ = "    ...    "
  names       N6$ = HELP.ROW$, LINE 186
```

The `+1` matters. An address at the start of a line is a statement that failed. An address inside a
line is a statement that ran part way.

## 4. What gets built

### 4.1 A GUI program, not a prompt

GPC.ERR is a GUI program from the first phase that touches it. It has a menu bar, dialogs for input
and a window for the answer. There is no text mode and no `INPUT` prompt. Every later phase fills a
pane in a window that already exists rather than adding one. The GUI modules are the largest part of
the program and they land first, so the size measurement in section 8 comes at phase 2.

### 4.2 The map file, found not typed

The map is picked off the drive. The tool used to ask for a typed name and reject it silently
against a naming convention that was not consistent in this tree. Three spellings are on disk:

| spelling | written by | example |
|---|---|---|
| `M.<source>` | `GPC.BASL`, on the machine | `testing/M.GPC.ERR` |
| `M.<source>.SRC.PRG` | the same, when the source name carries the suffix | `samples/GPC-HELP/M.GPB.HELP.SRC.PRG` |
| `<name>.MAP` | `source/gpc/samplesbuild.py`, headless | `samples/GPC-HELP/GPB.HELP.MAP` |

Map naming is `<name>.MAP`, section 9. It is what every headless build already writes, it is what
the samples carry, and it is the only one of the three spellings `FILEPICK` can filter on, because
`FILEPICK` matches suffixes. `testing/GPC.BASL` builds the name and was the one place that changed.
`samplesbuild.py` and `modsbuild.py` already wrote `<stem>.MAP`.

A suffix filter cannot reach the `M.` spellings at all. `M.GPC.ERR` has the suffix `ERR` and
`M.GPB.HELP.SRC.PRG` has `PRG`. An old map is reachable only by the typed name, which GPC.ERR reads
and turns into a symbol file name the same way.

The scan is library work, not new code. `GPC-BASIC/FILEPICK.INC.BL` has three entry points:

```
GP.SUB PICKBANKS, listbank, dirbank      once, before the first pick
GP.SUB PICKSCAN, ext$                    the read, without the box
F$ = GP.FN(PICKFILE, title$, ext$)       "" is a cancel
```

`PICKSCAN "MAP"` fills `FILEPICK.COUNT`. One match opens it without asking. More than one calls
`PICKFILE` for the box. `PICKFILE` returns an empty string on a cancel.

`FILEPICK` needs `STASH`, `GUI`, `GUI-DIALOGS`, `FILEIO` and `FILEDIR` beside it, and two banks from
`BANKMGR`.

### 4.3 Two ways in

The GUI offers both, because both have the same second half.

- An address, from a running program. Enter `$34A7`, or paste the whole error line. The existing
  `PARSE.ADDR` already takes the text after the last `$` and its leading hex digits, and folds case
  and trims. Keep it.
- A BASIC line number, from a compile error. Skips the map and enters the chain at the SYM step.
  One extra field, no extra resolver.

### 4.4 Detokenising, in assembly

The format is small enough to state completely:

- A byte below `$80` is a character, copied out.
- `$CE` is the only two-byte prefix. Take the next byte with it. `$CE80` and up is the GP.\* range.
- Any other byte at `$80` or above is a single-byte token.
- After a `"` byte, copy bytes literally until the next `"` or the line's `$00`. A token number
  inside a string is text.

Reference implementation: `source/tools/detokenise/detokenise.py:35-66`. It is thirty lines and the
blob should match it statement for statement. `ERR.SRC.SEEK.ASM`'s output matches that reference
byte for byte on `GPBMODS.SRC.PRG`.

WARNING: the link must not be followed. It holds the address a line had in a program loaded at
`$0801`, so it wraps on a source over 63 KB. 1,304 of the 4,791 links in `testing/GPBMODS.SRC.PRG`
point backwards. The walk scans to each line's closing zero instead, which is what
`source/tools/detokenise/detokenise.py` does.

The keyword table is two parts: the stock BASIC keywords, and the 41 `#TOKEN` lines in
`GPC-BASIC/GPB.INC.BL` that name the GP.\* set, which are `$CE`-prefixed. `#TOKEN GP.BANKED 52823`
is `$CE57`. Generate the table from those `#TOKEN` lines at build time rather than transcribing it,
so it cannot drift when a keyword is added. The build script reads those lines out of the file the
build already ships and writes the table into the GPC.ERR source. Nothing in BASLOAD changes.
`GP.BANKEDSTR` puts the table in a bank and off the workspace.

`GP.BSTRSET` is listed out of id order beside `GP.BSTR`, because `GP.BSTR` is a prefix of it. The
generator must sort by id, not by appearance. The note is at `source/common-scripts/c64tokens.py:171`.

### 4.5 The blobs, and which one earns its place

This is `GP.ASM` inline, not a 64tass source, because the host is a BASL program. That is settled.

One blob is written.

| blob | what it does | why |
|---|---|---|
| line fetch | walk `NAME.SRC.PRG` to a line number and copy its bytes out | A lookup crosses the whole file. `ERR.SRC.SEEK.ASM` in `GPC-BASIC/ERRSRC.INC.BL` is the blob. |
| bank loader | not written | `BLOAD` pulls the whole tokenised source into consecutive banks in one call. |

The render is BASIC. The keyword text is a `GP.BANKEDSTR` group and only BASIC can read one, so the
blob copies bytes and BASIC turns them into text.

`BLOAD` fills a bank and steps to the next, so the banks have to be consecutive. Taking them one at
a time from `BANKMGR` does not give a run: `BANKMGR` hands out the lowest free bank, and GPC.ERR
leaves bank 6 free with 7 and 8 taken. `ERR.SRC.CLAIM` looks for a run the size of the file and
claims it by number, handing every bank back when the run comes up short.

`NAME.MAP` and `NAME.SRC.SYM` are read with `LINPUT#` on each lookup. Section 6 has the timing.

`GPB.HELP` already reads a topic into a bank through a `GP.ASM` blob and paints out of it. That is
the pattern to copy, not to invent.

### 4.6 A window, not a line

The window is seven rows: the line the lookup landed on and the three either side. A deferred SYNTAX
error is often caused by the line above it, and the walk through `SRC.PRG` passes those lines anyway.
The frame is 24 rows: the seven source rows, and the names block under them, section 4.7.

The row the lookup landed on carries a `>` in its first column and is drawn in the theme's
`THEME.TEXT` colour. The other six are drawn in `THEME.DIMMED`.

### 4.7 Crunched names to real names

The names are cut out inside the renderer, in `ERR.SRC.WORDS$`. The renderer has the token bytes
and the text it writes does not. A keyword renders with no space around it, so `NGAND2` is the
variable `NG`, the keyword `AND` and the number 2, and nothing reading the finished text can tell
where the name stops. Everything after a `REM` token is comment text and is not collected.

`ERR.NAMES.WANT` splits that string and cuts the `$` or `%` type suffix off each name for the
lookup, because BASLOAD's table holds `HELP.ROW` for a variable the source writes as `HELP.ROW$`.
The suffix goes back on for the display.

`ERR.SYM.SCAN` reads both halves of the symbol file in one pass and stops as soon as the last wanted
name is found. With no name wanted it stops at `VARIABLES`.

Six names show, two to a row, in a `NAMES` block under the source window. A name the symbol file
does not carry gets its row and says `NOT A SYMBOL`. A seventh name sets a flag and the block's
title becomes `NAMES, THE FIRST 6`. A row is 36 columns, and a name too long for one is cut while
its line number is kept whole.

BASIC line 1139 of `GPB.HELP` renders as:

```
IFI4$<>""THENI5%=GV+INT((GW-LEN(I4$)-2)/2):GP.PRINTATI5%,HE," "+I4$+" ",A1(2)
```

and the six names come back as:

```
I4$ = GUI.TITLE$, LINE 534        I5% = GUI.TITLE.LEFT%, LINE 534
GV = GUI.LEFT, LINE 199           GW = GUI.WIDTH, LINE 199
HE = GUI.TOP, LINE 305            A1 = THEME.CLR, LINE 103
```

WARNING: a `VARIABLES` line number is where the symbol was first seen, not where the failing line
uses it. Section 2.2 has the rule. The six lines above are declarations, not uses of line 1139.

### 4.8 A working display

A lookup reads three files. `NAME.MAP` is 18,911 bytes and 1,976 records for `GPB.HELP`. The
tokenised source comes next, through `BLOAD`. `NAME.SRC.SYM` is the third.

`ERR.BUSY.OPEN` clears the frame interior and prints `WORKING` at the top of it. `ERR.ASK.ADDRESS`
and `ERR.ASK.LINE` both call it once the input has been accepted.

`ERR.BUSY.STEP` prints one step name on its own row. A lookup names three steps:
`READING THE MAP`, `FINDING THE SOURCE LINE` and `READING THE SYMBOLS`. `ERR.MAP.SCAN`, `ERR.SOURCE.FIND` and
`ERR.SYM.SCAN` are the callers, and each calls past its own guards, so a step that is skipped is
never named.

`ERR.BUSY.TICK` prints one dot on the current step's row, one every 24 records, up to 32 dots. The
`LINPUT#` loops in `ERR.MAP.SCAN` and `ERR.SYM.SCAN` call it. `ERR.SRC.OPEN` is a single `BLOAD`
with no loop, so the source step shows its name and no dots.

The next `ERR.PAINT` overwrites the whole display. There is nothing to clean up.

### 4.9 The GUI refactor

The screen is three boxes, every one `GP.BOX` style 2 with rounded corners. All three start at
column 0 and are `ERR.COLS` wide, so their edges line up. Rows 0 to 2 are the header, and the menu
bar draws on row 1. Rows 3 to 26 are the answer frame, `ERR.FRAME.ROWS` 24. Rows 27 to 29 are the
footer. The theme is fixed at 3 and the `THEME` bar item is gone.

The bar is three items: `FILE`, `SEARCH`, `HELP`. It starts at column 2, `ERR.BAR.COL`. Each item
string carries its own padding, `" &FILE "`, `" &SEARCH "` and `" &HELP "`, and `MENU.GAP` is 0, so
an item is as wide as its text. `ESC` or `ALT` opens a dropdown. `FILE` / `QUIT` is the only way
out, and it sets `ERR.QUIT`.

`ERR.MENU.SETUP` builds every menu once at boot: the bar in slot `MENU.BAR`, then the three
dropdowns in `MENU.DROP + 1`, `+ 2` and `+ 3`. `MENU.BEGIN` on the bar slot empties every dropdown,
so the bar goes in first and nothing rebuilds it afterwards. `ERR.PAINT.HEAD` redraws the bar with
`MENU.DRAWBAR` and touches no rows.

`ERR.MAIN` is the program's key loop. It `GET`s a key, passes it to
`ERR.ROW = GP.FN(MENU.KEY, ERR.KEY)` and calls `ERR.DISPATCH` when `ERR.ROW` is above 0. `MENU.KEY`
owns the bar and the dropdowns together: with one open, `LEFT` and `RIGHT` walk from dropdown to
dropdown, a bar hot key jumps to its own, and `ESC` closes. `ERR.DISPATCH` selects on `MENU.PICKBAR`
and calls `ERR.FILE.PICK`, `ERR.SEARCH.PICK` or `ERR.HELP.PICK`, each of which reads `ERR.ROW`. It
repaints the screen after, unless `ERR.QUIT` is set.

`FILE` drops down `LOAD MAP`, `BROWSE MAP`, a separator and `QUIT`. `LOAD MAP` asks for the name in
an input box, and the drive's answer is already in the box when the drive holds exactly one `.MAP`
file. `BROWSE MAP` is the `FILEPICK` box of section 4.2. Both routes end in `ERR.TAKE.MAP`. `QUIT`
sets `ERR.QUIT`.

`SEARCH` drops down `BY ADDRESS` and `BY LINE`. `ERR.SEARCH.PICK` reads `ERR.ROW` and calls
`ERR.ASK.ADDRESS` and `ERR.ASK.LINE`.

`HELP` drops down `HOW TO` and `ABOUT`. `ERR.HELP.PICK` reads `ERR.ROW` and calls `ERR.HOWTO` and
`ERR.ABOUT`.

`ERR.HOWTO` shows three lines through `MSGBOXEX`, titled `HOW TO USE GPC.ERR`:

```
LOAD MAP UNDER FILE READS THE .MAP AND .SYM OF A COMPILE.
SEARCH BY ADDRESS TAKES THE HEX PC A RUNTIME ERROR PRINTS.
SEARCH BY LINE TAKES A LINE FROM STATEMENTS NOT COMPILED.
```

The three are a `GP.BANKEDSTR` group, `ERR.HOWTO.TEXT` in `ERR.TOKENBANK`, bank 61. That is the
bank `ERRTOKEN.INC.BL` declares and `ERR.CLAIM.BANKS` claims. `ERR.HOWTO` reads the lines back with
`GP.BSTR`.

`ABOUT` is three lines: `ERROR ADDRESS LOOKUP HELPER`,
`FOR THE X16 GPC-BASIC COMPILER (C)SADLOGIC - 2026`, and a memory line in the shape
`TOTAL BANKS 64   UNUSED 45   BYTES FREE 6320`. The two bank counts come from `BANKMGR.COUNT` and
the free figure from `FRE(0)`, all three read when the box opens. `ERR.ABOUT` builds the lines,
measures the longest of the three into `ERR.ABOUT.WIDE` and runs the first two through `PADC`. The
margin is part of the string because `MSGBOXEX` draws every line left to right from one column.
`PADC` pads to the longest of the three, so that line still sets the box width.

`MENUKEY.INC.BL` is in low RAM and not a region. It reads the keyboard layout under `BANK 0` and
leaves that bank selected, which a `GP.BANKED` region may not do. `ERR.BOOT` runs
`GOSUB ERR.MENU.SETUP` and then `GOSUB MENU.KEYS.ON`, which writes each bar hot key into the ALT
half of the PETSCII and the ISO layout tables. `ERR.SHUTDOWN` runs `GOSUB MENU.KEYS.OFF` first,
because the layout outlives the program. A headless run reports six bytes rewritten, the three hot
keys in each of the two tables. ALT with a bar item's hot key then reaches `MENU.KEY` as that letter
and opens that item's dropdown.

Every popup is shadowed and rounded. `MENU.SHADOW` is set at boot. The dropdown's frame comes from
`MENU.DROPSTYLE`, set to `ERR.BOX.STYLE` in `ERR.MENU.SETUP`. The shadow colour is
`THEME.CLR(THEME.SHADOW)`, 0 in `GPC-BASIC/THEME.INC.BL` and in its copies in the tree, so every
menu and dialog shadow is black.
The canned dialogs take their frame from `DLGSTYLE`, a verb in `GPC-BASIC/GUI-DIALOGS.INC.BL` that
sets the frame every dialog in that module draws with.

The footer carries the project the loaded map belongs to: the map's base name, `FILES`,
`SOURCE LINES` and `COMPILED LINES`. `ERR.PAINT.FOOT` pads the line to `ERR.COLS - 2` with `PADC`
and prints it at column 1, which centres it on row 28. A `+` after the file count says the project
has more files than `ERR.FILES.MOST`, which is 40, so the line total is short.

Loading a map profiles it, and the profile is two full file reads. `ERR.SYM.PROFILE` reads the
symbol file end to end: the file count comes off the `LABELS` run of `FILE:` headings, and the line
total is the highest source line seen in each file, summed. `ERR.CODE.PROFILE` counts the records in
the map. Both use the working display of section 4.8, and their step names are `COUNTING THE SOURCE`
and `COUNTING THE MAP`.

On the `GPB.HELP` fixture the two reads take 566 jiffies, which is 9.4 seconds, and answer 13 files,
4,761 source lines and 1,976 compiled lines. An independent pass over the same symbol file gives the
same three numbers.

`STASHVRAM.INC.BL` and `MENUPULL.INC.BL` are a sixth region, `ERR.PULLCODE` in bank 5.
`MENUPULL.OPEN` is what opens the dropdown, and `MENU.KEY` calls it. `STRINGS.INC.BL` joins
`APPSYS`, `THEME`, `STRCASE` and `BANKMGR` in `ERR.UTILCODE`, bank 7, and
`PADC` is the only verb the program calls out of it. The compiler drops the routines nothing calls,
so its 14,817 bytes of source cost 768 bytes of overlay and no resident p-code. The regions are
banks 4, 5, 7, 8, 10 and 12, and banks 61 and 62 still hold the keyword table and the menu rows. The
source is twenty-two modules, seventeen of them banked.

The lookup itself did not change. A map scan is still 650 jiffies, and the three fixture lookups
answer with the same lines, files and names as before.

`C.GPC.ERR.PRG` is 10,197 bytes SHARED, against 7,760 before the refactor, so the GUI work cost
2,437 bytes of p-code. The cap is 22,016 bytes, so 11,819 are left. `C.GPC.ERR.OVL` is 28,433
bytes, against 24,847. `testing/GPC.ERR.PRG`, the tokenised source, is 62,494 bytes, against
51,155.

## 5. The compiler side

A statement that fails to compile is not in the program. The compiler replaces it with a one-byte
stub and still prints its success banner. It keeps the BASIC line of each statement it drops and
prints the list on the line above the banner.

### 5.1 The sites

The compiler and the application are two builds. `source/compiler/source` becomes
`bin/compiler.library`, and `source/application/source` links it. The application reads compiler
storage symbols directly, which is how `memreport.asm` reads `objPtr` and `gpBankStart` and how the
print routine reads the count and the table.

- `source/compiler/source/main/compiler.asm`, the storage section, just before `.send storage`.
  `DEFER_MAX = 16` is the table's capacity. `deferCount` is one byte, the statements this pass lost.
  `deferLines` is `2*DEFER_MAX` bytes, one BASIC line number an entry. The section is uninitialised
  RAM, a `.dsection` at `$0400`.
- `source/compiler/source/main/compiler.asm`, `RecordDeferredLine`, immediately after
  `DeferStatementToRuntime`. `DeferStatementToRuntime` opens with `jsr RecordDeferredLine`, so the
  line is taken before the stub is written. The routine writes an entry only while `deferCount` is
  below `DEFER_MAX`, then increments the count whether it wrote one or not, saturating at 255 rather
  than wrapping to none. The line comes from `jsr GetLineNumber`
  (`source/compiler/source/helpers/api.asm`), which returns it in YA and leaves X alone, so the
  table index survives the call. The stack is already unwound to `stmtRecoverSP`, which is
  statement-dispatch level, so a `jsr` here is safe.
- `source/compiler/source/main/compiler.asm`, `ResetPassState`. `stz deferCount` sits beside the
  existing `stz deferErrors`.
- `source/application/source/compiler/start.asm`, the print. `jsr PrintDeferredLines` sits between
  `jsr WriteDeadList` and the `lda #"O"` that starts the banner, so the banner itself is untouched.
- `source/application/source/compiler/memreport.asm`, `PrintDeferredLines`. It returns without
  printing when `deferCount` is zero. The two strings `NotCompiled1Text` and `NotCompiledText` sit
  beside `CodeText`. It prints through `PrintDecimal` in the same file and `PrintMessage` at
  `source/application/source/file-io/control.asm:207`.

### 5.2 What it prints

One line, above the banner, naming the count and the BASIC line numbers. One dropped statement takes
the singular:

```
1 STATEMENT NOT COMPILED: 1669
2 STATEMENTS NOT COMPILED: 1669 1702
```

The space leads each number rather than following it, so the line has no trailing space. A return
ends it.

Those numbers are what GPC.ERR takes at its BASIC-line entry, section 4.3. The table holds sixteen.
Past sixteen the count keeps rising and the line numbers stop, so the count is always true.

The word `ERROR` stays out of the line. `compile_shared.py` harvests the log between the banner and
the `READY.` after it when a compile fails.

### 5.3 Passes

`ResetPassState` runs once a pass, and there are up to three passes: pass zero only when dead-code
removal is on, then one and two. The table is rebuilt each pass and the last pass's table is the one
printed. Dead-code removal can leave a deferred line out of the program. At most one entry a source
line: after a defer the rest of the line is dropped and the next line is read.

### 5.4 Size and rebuild

`GPC.BIN` grew from 32,271 bytes to 32,438, which is 167 bytes. The compiler's storage section grew
33 bytes: `StorageEnd` moved from `$0678` to `$0699`, against a ceiling of `$07F0`, which is
`GPBSTRBANKS`. The guard is a `.cerror` in `source/common-source/source/common.inc`.

`make libs` rebuilds `compiler.library`. The application make does not do it. Installing the runtime
is a separate step again.

WARNING: the banner is `OK LOW CODE`. `start.asm:88-92` prints `OK ` a character at a time through
`$FFD2`, and `PrintMemoryReport` at `memreport.asm:52` prints `LOW CODE ` from `CodeText`.
`compile_shared.py:163` tests for the literal `OK LOW CODE` and on nothing else, so a headless build
that no longer prints it runs to its timeout.

`OASIS/tmp-test/build.py` passes `OK CODE` as its stop condition at line 119 and filters on the same
string at line 123. Neither can match `OK LOW CODE`, so that script waits out its 240-second timeout
on every compile and prints an empty size line. `OASIS` is scratch and is not committed. Not part of
this work.

### 5.5 How it was verified

Three headless compiles of scratch sources, each through `source/gpc/build_basl.py` and then
`source/gpc/compile_shared.py`:

- one failed statement prints `1 STATEMENT NOT COMPILED: 2`
- two failed statements print `2 STATEMENTS NOT COMPILED: 2 4`
- twenty failed statements print `20 STATEMENTS NOT COMPILED:` followed by sixteen line numbers, 2
  through 17, and stop

`BSTRA.SRC.PRG` compiles clean and prints no such line. `OK LOW CODE` follows in every one of the
four cases.

The test sources were scratch and have been deleted. They are not in the repo.

## 6. Phases

Each phase leaves a tool that works.

| phase | what lands | assembly |
|---|---|---|
| 1 | Done. A failed statement's BASIC line is kept and printed above the banner. Section 5 has the code. | the capture and the print |
| 2 | Done. The GUI shell, `FILEPICK` for the map, the MAP lookup and the SYM `LABELS` lookup. An address or a BASIC line gives a file name, a BASIC line and the nearest label with its source line, shown in a framed window under a menu bar. `LINPUT#` replaced the `GET#` loops. | none |
| 3 | Done. `GPC-BASIC/ERRSRC.INC.BL` pulls `NAME.SRC.PRG` into a run of RAM banks with `BLOAD`, and `ERR.SRC.WINDOW` returns a line and the three either side, rendered. `GPC-BASIC/ERRTOKEN.INC.BL` holds the keyword text as two `GP.BANKEDSTR` groups in bank 61: 274 slots, 199 keywords, a slot no keyword uses being an empty string. `source/gpc/gen_err_tokens.py` generates it from the 41 `#TOKEN` lines in `GPC-BASIC/GPB.INC.BL` and the stock tables in `source/common-scripts/c64tokens.py`, and stops if the two token sources disagree. | the walk and the copy |
| 4 | Done. `GPC-BASIC/ERRSRC.INC.BL` gained `ERR.SRC.WORDS$`, which cuts the names out of the line as it renders it, because a keyword renders with no space around it and the finished text no longer says where a name stops. `ERR.NAMES.WANT` splits them and cuts the `$` or `%` type suffix for the lookup. `ERR.SYM.SCAN` reads both halves of the symbol file in one pass and stops once the last wanted name is found. Six names show, two to a row, in a `NAMES` block under the source window. The working display landed with it, and a lookup names each step on screen as it runs. Sections 4.7 and 4.8 have the rest. | none |
| 5 | Not needed. Phase 5 is a bank loader for the tokenised source. `BLOAD` pulls that file into consecutive banks in one call. Size is the second reason, with 12,872 bytes left under the ceiling. | none |

`C.GPC.ERR.PRG` is 9,144 bytes SHARED against the 22,016 byte ceiling, so 12,872 bytes are left.
The library runs from banked regions, so the resident p-code is the shell and the resolvers.
`C.GPC.ERR.OVL` is 28,433 bytes and holds the six code regions and the two text banks. It has to
travel with the `.PRG`. `testing/GPC.ERR.PRG`, the tokenised source, is 60,710 bytes. Phase 3 cost
1,930 bytes of p-code and 2,306 bytes of overlay, and the GUI refactor of section 4.9 cost 1,384
bytes of p-code.

`LINPUT#` reads `GPB.HELP.MAP`, 18,911 bytes and 1,976 records, in 615 jiffies, which is 10.3
seconds. With `ERR.BUSY.TICK` in the loop it is 647 jiffies, so the feedback costs 5 percent. A
second scan in the same run takes the same time, so the figure is not a cold start. The working
display of section 4.8 covers that wait. The symbol file read is a second wait on top of it.

Reading the map into a bank and scanning it in memory is the open route to a faster lookup. It is
not decided.

WARNING: the map and the symbol file are LF only and `LINPUT#` defaults to delimiter 13. Every
`LINPUT#` in GPC.ERR names 10.

WARNING: file I/O reached from inside a `GP.DO` key loop stops the program with
`INPUT/OUTPUT ERROR @ $005B`. Output to channel 0 clears it, so every `CLOSE` in GPC.ERR is followed
by a space to channel 0.

Phase 4 gave the real names and took 1,410 of those bytes. It cost nothing in the overlay, because
none of its code is in a `GP.BANKED` region. Phase 5's bank loader is not needed for size either.

## 7. Testing, on this code

`samples/GPC-HELP` is the fixture. It has all three files from the build of 2026-09-24, and a known
answer.

| in | out |
|---|---|
| `$34A7` | `GPB.HELP.BASL`, `HELP.BOOT` at line 147, BASIC line 1669, `HELP.ROW$ = "..."`, `N6$ = HELP.ROW$, LINE 186` |
| `SYNTAX ERROR @ $34A7` | the same; the parser takes the text after the last `$` |
| `$0006` | the first mapped line, BASIC line 1 |
| `$4ABC` | compiler setup, not a source line |
| `$0001` | before the first mapped line |
| `$FFFF` | past the last record; answers on the last real line, not the 65535 one |
| BASIC line `1653` entered directly | `GPB.HELP.BASL`, `HELP.BOOT`, line 147, delta 0 |
| BASIC line `2` entered directly | `GPC-BASIC/THEME.INC.BL`, `THEME.SELECT` at line 101 |

All eight rows are verified: the BASIC line, the file, the nearest label with its source line, the
statement text and the names.

The harness is `testing/GPCERRT.BASL`. It holds GPC.ERR's own resolver routines copied unchanged
with a different caller, compiles SHARED and runs headless. It is a throwaway in `testing/` and is
not tracked. Its answers matched a host-side reference computed from the same three files.

Two rows need a rule the chain in section 3 does not state. An address that lands on a setup record
is reported as setup code. An address past the whole map is reported as past the map and answered on
the last real line. `$4ABC` and `$FFFF` resolve to the same record and differ for that reason.

`testing/SRCTEST.BASL` prints `ERR.SRC.WORDS$` for every window it shows. The names it printed were
checked against a host-side model of the same cut, byte for byte, on seven lines across
`BMXVIEW.SRC.PRG` and `GPBMODS.SRC.PRG`. `GPBMODS` line 304 renders as
`C8=GP.INSTR(CC$,C2$,CB%(C4))` and gives `C8 CC$ C2$ CB% C4`, which exercises the `$CE` two-byte
token path.

`testing/ERRSELF.BASL`, a generated fixed-answer variant of the real program, drove the whole chain
on `GPB.HELP` and printed the right answer for three lines. 1669 gives one name,
`N6$ = HELP.ROW$, LINE 186`. 968 gives six and sets the flag that retitles the block, because the
line holds seven names and one had no slot. 1139 gives six and does not set it, because the words
past the sixth are repeats.

A second fixture with one library module and a small master is worth making, so a failure in the
`FILE:` walk is visible rather than hidden by thirteen correct boundaries.

## 8. Constraints the build has to respect

- Compile SHARED, and in the main directory. `source/gpc/Makefile`'s `release` target does it:
  `build_basl.py GPC.ERR.BASL GPC.ERR.PRG` then
  `compile_shared.py GPC.ERR.PRG C.GPC.ERR.PRG GPC.ERR.MAP`. A standalone build is the wrong program,
  not a worse one. `scratchpad/edbuild.py` builds standalone and its output must never overwrite the
  tracked binary.
- It needs the GPB runtime, `GPB.RT.nnn.BIN`, not the core-only `GPC.RT.nnn.BIN`, because it uses
  the GP block handlers throughout.
- The SHARED p-code ceiling is RTBASE, 22,016 bytes. `C.GPC.ERR.PRG` is 9,144 bytes, so 12,872
  bytes are left. The library runs from banked regions and its 28,433 byte `C.GPC.ERR.OVL` has to
  be beside the `.PRG` at run time.
- `release/TMP` currently holds no `*.RT.124.BIN`. Both PRGs staged there are SHARED and cannot
  start without the runtime beside them. Unrelated to this work, but it will bite anyone testing a
  staged build.
- The directives come before the `#INCLUDE`s in `GPC.ERR.BASL`, and that is not style. `STRCASE`
  reaches BASIC's variables through `{VAR}` and the compiler resolves those from `#SYMFILE`, which
  has to exist before the include that needs it.

## 9. Decisions

1. Map naming is `<name>.MAP`. `testing/GPC.BASL` builds it from the source name, cutting `.PRG` and
   `.SRC` and adding `.MAP`, so `GPB.HELP.SRC.PRG` gives `GPB.HELP.MAP`. GPC.ERR reads the older
   `M.<name>` shape as well, because the tree is full of maps under that name. GPC.ERR derives the
   symbol file from the map's name: `<base>.SRC.SYM` first, `<base>.SYM` if that is absent.
2. The typed name and the picker are separate items, `LOAD MAP` and `BROWSE MAP`, section 4.9.
   `LOAD MAP` starts with the drive's answer in the box when exactly one `.MAP` file is there. Both
   routes end in `ERR.TAKE.MAP`.

## 10. An exact source line without any of this

GPC.ERR can read the `.BASL` source itself and count. From a SYM label anchor, which gives an exact
source line and an exact BASIC line, count forward over only the source lines that emit a BASIC line
until the count reaches the target. A blank line does not emit. A `#` directive does not emit. A
bare label, a name ending in a colon with no space in it, does not emit. A `REM` emits only while
`#REM 1` is in force. Everything else emits. Tracking the `#REM` state is what makes it correct,
because a `GP.ASM` body is written as `REM` lines inside `#REM 1`.

Tested against every consecutive label pair in the `GPB.HELP` build, thirteen library modules and
the master: 262 pairs, 262 exact, 0 mismatches. The worked example resolves to source line 186
exactly.

It needs the `.BASL` beside the tool, and it is wrong if the source changed after the build. The
self-check is free: count on to the next label and compare with that label's SYM delta. A mismatch
means the source moved, and the tool reports that rather than a wrong number.

Not in the phases. Recorded because the measurement is done.
