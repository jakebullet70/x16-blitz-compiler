# GPC.ERR: from an address to a source line

Handoff document. Phase 1, the compiler change, is built and verified. The rest is not started. It
rewrites `source/gpc/GPC.ERR.BASL` from a two-prompt text helper into a GUI tool that answers with a
file name, a source line and the text of the offending statement.

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

Which is why section 4.4 exists.

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
  names       N6 = HELP.ROW, first seen at line 186
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

The current tool asks the programmer to type a map name, and rejects it silently against a naming
convention that is not consistent in this tree:

| spelling | written by | example |
|---|---|---|
| `M.<source>` | `GPC.BASL`, on the machine | `testing/M.GPC.ERR` |
| `M.<source>.SRC.PRG` | the same, when the source name carries the suffix | `samples/GPC-HELP/M.GPB.HELP.SRC.PRG` |
| `<name>.MAP` | `source/gpc/samplesbuild.py`, headless | `samples/GPC-HELP/GPB.HELP.MAP` |

Settle on `<name>.MAP`. It is what every headless build already writes, it is what the samples
carry, and it is the only one of the three spellings `FILEPICK` can filter on, because `FILEPICK`
matches suffixes. `GPC.BASL:73-93` decides the `M.`+`SRC$` naming and is the one place that changes.

A suffix filter cannot reach the `M.` spellings at all. `M.GPC.ERR` has the suffix `ERR` and
`M.GPB.HELP.SRC.PRG` has `PRG`. An old map is reachable only by the typed name in section 9, or by
taking decision 1.

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
blob should match it statement for statement.

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

Two candidates. Write the loader first.

| blob | what it does | why |
|---|---|---|
| bank loader | pull `NAME.MAP` and `NAME.SRC.SYM` into banked RAM once | 76 KB across the two files. The current `SCAN` reads the map a byte at a time with `GET#` and re-reads it on every lookup. A debugging session is many lookups. |
| line fetch | walk `NAME.SRC.PRG` to a line number and render it | The walk is a link chase and the render is the table above. Both are plain BASL work. |

The detokeniser is the part the request named, but the loader is the part the tool cannot be used
without. A byte-at-a-time pass over 57 KB of SYM on every lookup is not a tool a programmer reaches
for twice.

Cheaper first step, no assembly at all: `LINPUT#` instead of `GET#`. It is already used at
`GPC-BASIC/FILEIO.INC.BL:330`, and it is about ten times faster than the `GET#` loop on the same
file. Do that before deciding the loader is necessary, and measure.

`GPB.HELP` already reads a topic into a bank through a `GP.ASM` blob and paints out of it. That is
the pattern to copy, not to invent.

### 4.6 A window, not a line

Show three lines either side of the offending one, the offending one marked. A deferred SYNTAX error
is often caused by the line above it, and the walk through `SRC.PRG` passes those lines anyway.

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
| 2 | The GUI shell, `FILEPICK` for the map, MAP lookup and SYM `LABELS` lookup. An address gives a BASIC line, a file name and the nearest label, shown in the window. `LINPUT#` replaces the `GET#` loops, measured. Size measured against the ceiling. | none |
| 3 | `SRC.PRG` walk and detokenise. The statement is shown. Table generated from `#TOKEN`. | the render |
| 4 | SYM `VARIABLES` reverse lookup. Crunched names become real names with their source lines. | none |
| 5 | Bank loader, if phase 2's measurement says `LINPUT#` is not enough. | the loader |

Phase 2 gives the file and the window. Phases 3 and 4 give the statement and the real names. Phase 5
is conditional on a number, not on taste.

## 7. Testing, on this code

`samples/GPC-HELP` is the fixture. It has all three files from the build of 2026-09-24, and a known
answer.

| in | out |
|---|---|
| `$34A7` | `GPB.HELP.BASL`, `HELP.BOOT` at line 147, BASIC line 1669, `HELP.ROW$ = "..."`, `N6 = HELP.ROW` first seen at line 186 |
| `SYNTAX ERROR @ $34A7` | the same; the parser takes the text after the last `$` |
| `$0006` | the first mapped line, BASIC line 1 |
| `$4ABC` | compiler setup, not a source line |
| `$0001` | before the first mapped line |
| `$FFFF` | past the last record; answers on the last real line, not the 65535 one |
| BASIC line `1653` entered directly | `GPB.HELP.BASL`, `HELP.BOOT`, line 147, delta 0 |
| BASIC line `2` entered directly | `GPC-BASIC/THEME.INC.BL`, `THEME.SELECT` at line 101 |

A second fixture with one library module and a small master is worth making, so a failure in the
`FILE:` walk is visible rather than hidden by thirteen correct boundaries.

There is a host-side resolver in the session scratchpad that produces the first row of that table.
It is not in the repo and is not part of this work. Rebuild it if a reference answer is wanted while
the BASL version is being written.

## 8. Constraints the build has to respect

- Compile SHARED, and in the main directory. `source/gpc/Makefile`'s `release` target does it:
  `build_basl.py GPC.ERR.BASL GPC.ERR.PRG` then
  `compile_shared.py GPC.ERR.PRG C.GPC.ERR.PRG M.GPC.ERR`. A standalone build is the wrong program,
  not a worse one. `scratchpad/edbuild.py` builds standalone and its output must never overwrite the
  tracked binary.
- It needs the GPB runtime, `GPB.RT.nnn.BIN`, not the core-only `GPC.RT.nnn.BIN`, because it uses
  the GP block handlers throughout.
- The SHARED p-code ceiling is RTBASE, 22,016 bytes. GPC.ERR is 1,751 bytes today. `GPB.HELP`, which
  pulls in the same GUI modules this plan adds, is 19,935. Headroom exists but it is not large, and
  the GUI modules are most of the cost. Measure at phase 2, not after it. They land before any of
  the resolver work, so the headroom is known before the parts that use it are written.
- `release/TMP` currently holds no `*.RT.124.BIN`. Both PRGs staged there are SHARED and cannot
  start without the runtime beside them. Unrelated to this work, but it will bite anyone testing a
  staged build.
- The directives come before the `#INCLUDE`s in `GPC.ERR.BASL`, and that is not style. `STRCASE`
  reaches BASIC's variables through `{VAR}` and the compiler resolves those from `#SYMFILE`, which
  has to exist before the include that needs it.

## 9. Decisions still open

1. Map naming. Section 4.2 recommends `<name>.MAP` and names the one place that changes.
2. Whether GPC.ERR keeps a typed-name fallback when `FILEPICK` finds nothing. A programmer on real
   hardware may have the map on another drive, and the typed name is the only way to reach it.

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
