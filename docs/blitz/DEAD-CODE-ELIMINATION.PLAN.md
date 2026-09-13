# Dead-code elimination in GPC

Handoff document. Agreed in principle as a compiler option. Not started. The research, the Prog8
comparison and the measurements are in `DEAD-CODE-ELIMINATION.RESEARCH.md`.

The option removes every source line that no path from the program's first line reaches. It works
on any tokenised program. With the option off, neither the compiler's passes nor the objects they
write change.

## 1. What the programmer writes

### 1.1 Turning it on

`GPC.INPUT` gains a fifth line, the name of the removed-line list. An empty line 5 turns the option
off. A name turns it on, and the compiler writes the numbers of the removed lines into that file, one
decimal number a line.

| line | holds |
|---|---|
| 1 | source |
| 2 | object |
| 3 | debug map name, or empty |
| 4 | `SHARED`, or empty |
| 5 | removed-line list name, or empty |

- `source/application/source/file-io/control.asm:34`: `CFLineCount` goes from 4 to 5.
- `source/application/source/compiler/start.asm:44` reads line 4. Line 5 is read beside it.
- `IODeleteOutputs` scratches the list file with the object and the map.
- `source/gpc/GPC.BASL:73-93` asks `REMOVE DEAD CODE? ` after `SHARED RUNTIME? `, names the list
  `D.`+SRC$ the way the map is `M.`+SRC$, scratches it before the run, and writes line 4 even when it
  is empty so line 5 keeps its slot.

A four-line `GPC.INPUT` reads line 5 as empty. No existing writer has to change:
`compile_shared.py`, the unit-test harnesses, the `fixes/` Makefiles, `release.sh` and `bench/`.

### 1.2 Keeping code on purpose

A keep region makes every line inside it a root. It opens with a `KEEP` marker and closes with an
`ENDKEEP` marker. Each marker has two spellings with the same meaning, and a region may open with one
spelling and close with the other.

The `REM` spelling works with stock BASLOAD, with BASLOAD-GPC, and in a program typed in at the X16's
own editor:

```
#REM 1
REM GP.KEEP
#REM 0
DEBUG.DUMP:
  PRINT A,B
  RETURN
#REM 1
REM GP.ENDKEEP
#REM 0
```

The `#GPC` spelling takes one line a marker, and exists only while BASLOAD-GPC does:

```
#GPC KEEP
DEBUG.DUMP:
  PRINT A,B
  RETURN
#GPC ENDKEEP
```

Whether BASLOAD-GPC stays is not decided. Nothing else in this plan depends on it. The `REM`
spelling is the one the plan relies on; the `#GPC` spelling is a convenience.

What reaches GPC:

| written | tokenised as |
|---|---|
| `REM GP.KEEP`, under `#REM 1` | `$8F`, a space, `GP.KEEP` |
| `#GPC KEEP` | `$8F`, `#GPC KEEP`, no space after the token (`BASLOAD-GPC/README.md:223`) |

- BASLOAD drops every `REM` unless `#REM 1` is in force. `line_option_rem` starts at 0
  (`BASLOAD-GPC/src/line.inc:86`, and the same in `BASLOAD-GPC/upstream/line.inc:82`). A
  `REM GP.KEEP` outside `#REM 1` never reaches GPC, and the region silently does not exist. One
  `#REM 1` at the top of the source serves the whole file.
- Stock and fork copy `REM` text the same way (`remark` in `src/line.inc:788` and
  `upstream/line.inc:763`), byte for byte, with no case change.
- `REM 1` without the `#` is an ordinary comment, not the directive.
- `#GPC` output ignores `#REM` and obeys only `#IFDEF` (`BASLOAD-GPC/src/option.inc:536`).
- A `##` line never reaches GPC with either BASLOAD.

The reader goes in `CommandREM` (`commands/rem.asm`) and runs only with the option on:

1. Skip spaces after the `REM` token.
2. Match `GP.KEEP`, `GP.ENDKEEP`, `#GPC KEEP` or `#GPC ENDKEEP`. In the `#GPC` spellings, one or more
   spaces separate the two words.
3. The byte after the word must be the end of the line, a space or a colon. `GP.KEEPER` is not a
   marker. The rest of the line is not read, so the `:REM nnn` that `#SOURCELINES` appends does not
   matter.
4. Letters match in any case. BASLOAD copies the file's bytes, so a letter can arrive as $41-$5A,
   $61-$7A or $C1-$DA.
5. Anything else is an ordinary comment.

Rules for regions:

- The marker may be any statement on its line, since a `REM` always runs to the end of the line.
- Every line after the `KEEP` marker's line and before the `ENDKEEP` marker's line is a root (2.2).
- The marker lines are not roots. Each is judged on its own, like any other line.
- A `KEEP` inside a region, an `ENDKEEP` outside one, and a region still open at the end of the
  source stop the compile with `.error_structure`.
- With the option off, markers are ordinary `REM`s and nothing checks them.

## 2. Rules

The unit is one source line. A line is kept when it is reached or retained. Every other line is
removed.

### 2.1 Terms

| term | meaning |
|---|---|
| ordinal | the line's position in the source, counting every line read, including lines a statement reads for itself |
| reached | some path from the first line runs it |
| retained | compiled although no path runs it |
| edge | a branch the compiler writes from one line to another |
| structure | a multi-line construct whose inside branches the compiler resolves from its own tables |

### 2.2 Roots

A root is reached from the start.

- the first source line
- every line inside a keep region (1.2)

The implicit-DIM prologue at line `$FFFF` is compiler output, not a source line. It is never removed.

### 2.3 Retained lines

| line | what removing it breaks |
|---|---|
| holds `DATA` | `READ` walks every `DATA` in object order, so every later `READ` returns a different value |
| holds `DIM` | `TakeOverImplicitArray` (`commands/dim.asm`) acts at compile time: an array used live and dimensioned only in unreached code changes from undimensioned to the prologue's default |
| holds `GP.DEFPROC` | `GP.SUB` and `GP.FN` look the verb up by name; the call edge lands on the statement after the declaration, which is on the next line when `GP.DEFPROC` stands alone |
| `GP.BANKED`, `GP.ENDBANKED` | the region markers `RegionSwitch` keys on |
| `GP.BANKEDSTR` through `GP.ENDBANKEDSTR` | a named string group; `GP.BSTR(<name>, n)` reads it by name, which is not an edge |

The edges on a retained line count (2.4). Its fall-through does not (2.5).

### 2.4 Edges

Every line branch leaves through `WriteBranchTo` (`commands/goto.asm:464`). Every address branch
leaves through `WriteBranchToAddress` (`goto.asm:503`). Recording at those two routines covers every
row below.

| statement | reaches the writer through | target |
|---|---|---|
| `GOTO n` | `CommandGOTO` (`goto.asm:50`) | line n |
| `GOSUB n` | `CompileBranchCommand` (`goto.asm:431`, from `gosub.asm:23`) | line n |
| `IF … THEN n` | `CompileBranchCommand` (`if.asm:38`) | line n |
| `ON x GOTO/GOSUB n,…` | `CompileBranchCommand` per target (`on.asm:36`) | each n |
| `RESTORE n` | `CompileBranchCommand` (`restore.asm:29`) | line n |
| `IF … THEN statement` | `CompileGotoEOL` (`if.asm:41`), `PCD_CMD_GOTOCMD_Z` | the next line |
| `DEF FN` | `CompileGotoEOL`, the skip over the body | the next line |
| `FN name(…)` | `evaluate/term/functions.asm:67` | the `DEF FN` line |
| `GP.SUB`, `GP.FN` | `commands/gpdefproc.asm` | the line holding the first statement after `GP.DEFPROC` |
| the prologue jump | `WriteBranchTo`, target `$FFFF` | ignored |

- An edge from a reached or retained line marks its target reached.
- `RESTORE` and `GOTOCMD_Z` may miss an exact line (`goto.asm:475-479`). Their target is the first
  line at or after n.
- `PCD_CMD_GOTOCMD_Z` is written only by `CompileGotoEOL`. It is not stored as an edge. It sets the
  line's falls-through bit.
- An address target is the last line whose pass-zero address is at or below it.
- `FN` and `GP.SUB` must follow their declaration in the source (`functions.asm:39`,
  `gpdefproc.asm`), so the address is known when the call compiles.

### 2.5 Fall-through

A reached line reaches the next ordinal unless its last statement starts with `GOTO` (`$89`),
`RETURN` (`$8E`), `END` (`$80`) or `STOP` (`$90`).

- A line with an `IF … THEN statement` skip falls through whatever its last statement is.
- `GOSUB`, `ON`, `GO TO`, `LOAD`, an implied `LET` and a deferred throw-stub fall through.
- Every line of a structure falls through.
- A retained line that is not reached does not fall through.

### 2.6 Structures

| opener | closer |
|---|---|
| `GP.IF` | `GP.ENDIF` |
| `GP.DO` | `GP.LOOP` |
| `GP.SELECT` | `GP.ENDSEL` |
| `GP.ASM` | `GP.ENDASM` |

- A structure runs from the opener's line through the closer's line.
- If any line of a structure is reached or retained, every line of it is reached.
- A nested structure belongs to the outermost one.
- Structures on adjacent lines may merge into one run. That keeps more lines, never fewer.

`GP.ELSE`, `GP.ELSEIF`, `GP.CASE`, `GP.OTHER`, `GP.EXITDO` and the loop back resolve through the
block tables, not `WriteBranchTo`, so they are not edges. Removing part of a structure breaks
`BlockEndCheck` and the depth counts.

`GP.ASM` reads its own body with `BLC_READIN` (`commands/gpasm.asm`). Those lines get no
`STRMarkLine` in any pass. A line whose statement reads further source lines forms a structure run
over every ordinal it consumed.

A line is in a structure when `blockDepth`, `ifDepth` or `SelectDepth` is non-zero at its start or
its end, when it consumed more than one ordinal, or when `blockCount` or `altCount` changed during
it.

### 2.7 `GP.BANKED` regions

A region is not a structure. Its inner lines are removed like any others, and its marker lines are
retained. A region whose inner lines are all removed is untested. Compile one before relying on it.
If the compiler refuses it, retain every line of a region that has no reached line.

### 2.8 What needs no rule

- `FOR` / `NEXT`: `NEXT` is matched at run time (`commands/next.asm`).
- Variables: `STRReset` rebuilds the list every pass (`main/compiler.asm:431`). A variable used only
  on removed lines does not exist in the object.
- `GP.ASM` blobs cannot name a BASIC line. `gpasm.asm` and `gpasmcode.asm` call neither
  `STRFindLine` nor `WriteBranchTo`. `GP.CALL` takes a machine address.
- String literals on removed lines never reach a `GP.BANKEDSTR` pool.
- A `LOAD` chain starts the next program at its own first line.

### 2.9 Behaviour the option changes

- A reached `GP.ASM` `{VAR}` naming a variable that only removed lines create. `{VAR}` never
  creates a variable (`gpasmcode.asm:1419`), so pass one stops with `UNKNOWN VARIABLE IN {}`. With the
  option off it compiles. See decision 2.
- No other case is known. Section 5.1 is the test that finds one.

### 2.10 Example

```
10 GOSUB 100
20 END
30 PRINT "UNUSED"
40 DATA 5,6
50 GOTO 30
100 IF A=0 THEN RETURN
110 READ X
120 RETURN
200 GOSUB 300
210 RETURN
300 GOSUB 200
310 RETURN
```

| line | result | rule |
|---|---|---|
| 10 | kept | root |
| 20 | kept | `GOSUB` falls through from 10 |
| 30 | removed | 20 ends in `END`; only 50 branches here |
| 40 | kept | retained: `DATA` |
| 50 | removed | 40 is retained, not reached, so it does not fall through |
| 100 | kept | edge from 10 |
| 110 | kept | the `IF` skip on 100 |
| 120 | kept | falls through from 110 |
| 200-310 | removed | they call only each other |

`READ X` returns 5 with the option on and off.

## 3. How the compiler does it

### 3.1 Three passes

| pass | `passNumber` | `dcPass` | work |
|---|---|---|---|
| zero | 0 | 1 | compiles everything as pass one does, records, solves |
| one | 0 | 0 | skips removed lines, lays out |
| two | 1 | 0 | skips removed lines, writes |

With the option off, pass zero does not run and none of the code below executes.

Pass zero is pass one with recording on. It uses the compiler's own target parsing, the
`FindVariable` lookup for `FN` and `GP.SUB`, and the compiler's own block depths. The token scan in
the research document, section 6.3, would have to reimplement all three.

### 3.2 Where pass zero stops

Pass zero leaves `SaveCodeAndExit` (`main/compiler.asm:236`) after the unclosed-block check and
before `GPBankRelocate` (`:287`), `PrepareObjectCode` and the fit check.

- It opens no object file.
- It never refuses a program for size. The stripped program may fit where the whole one does not.
- Every other compile error stops the compile in pass zero, as it does in pass one today.

### 3.3 State pass one must start without

`ResetPassState` (`main/compiler.asm:430`) clears what pass one fills. Pass zero also writes state
that is set once a compile or kept across passes on purpose. Clear each of these between pass zero
and pass one:

- the GP usage scan: `GPScanReset` runs once, before `StartCompiler` (`start.asm:49`); pass zero's
  marks pull GP runtime handlers in for removed code
- the GP.BANKEDSTR slot-to-bank list, which `ResetPassState` leaves alone (`main/compiler.asm:481`)
- the region layout, which pass two inherits from pass one (`main/compiler.asm:488`)
- anything else `CompileCode` or `StartCompiler` sets once: audit both

A missed reset shows only when a line is removed. The identity in 5.1 catches it.

### 3.4 Storage

Two compile-time banks. Add both to the allocation list in
`source/compiler/source/system-specific/x16/x16_storage.inc:61-78` before using them.

| bank | holds | size |
|---|---|---|
| 11 | four bit planes: reached, retained, falls through, structure | 1,024 B each, 8,192 ordinals |
| 11 | swallow list: (entry index, lines consumed) per line that read further lines | 4 B an entry, 1,024 entries |
| 12 | edge list | 4 B an edge, 2,048 edges |

- An edge is two bytes of source ordinal, with the top bit set for an address edge, and two bytes of
  target line number or address.
- The line table indexes marked lines. An ordinal is that entry index plus the lines consumed by
  every swallow-list entry before it.
- A full table, or more than 8,192 ordinals, turns the option off for the compile with a one-line
  notice. Pass one then removes nothing. The compile never fails for it.
- Sizing: the modules in `samples/GPB-MODS-TESTING` hold about 1,000 `GOSUB`, 300 `GOTO`, 930 `IF`,
  30 `RESTORE` and 20 `ON` between them. If 2,048 edges proves short, give the list a second bank
  the way bank 9 extends the line table.

### 3.5 Recording in pass zero

| hook | place | records |
|---|---|---|
| every `BLC_READIN` | `MainCompileLoop`, `commands/gpasm.asm`, and any other handler that reads lines | the ordinal count |
| line start | `MainCompileLoop`, after `GetLineNumber` | depths and counts at the start |
| statement start | `_MCLSameLine` | the statement's first token |
| `DATA`, `DIM`, `GP.DEFPROC`, `GP.BANKED`, `GP.ENDBANKED` | the statement token | retained |
| `GP.BANKEDSTR` open at a line's start or end | `bstrState` | retained |
| `WriteBranchTo`, `WriteBranchToAddress` | before their `passNumber` test | an edge, or the falls-through bit for `GOTOCMD_Z` |
| `KEEP` and `ENDKEEP` markers, both spellings | the reader in 1.2, in `CommandREM` (`commands/rem.asm`) | region state; roots |
| line end | back at `MainCompileLoop` | falls-through from the last token; structure bit; swallow-list entry |

### 3.6 Solving

At the end of pass zero:

1. Rewrite each edge target to an ordinal. A line number goes through `STRFindLine`, with a miss
   allowed. An address goes through a search of the line table, whose addresses rise with the source
   in pass zero. Drop edges to `$FFFF`.
2. Sweep until a sweep changes nothing:
   - each edge whose source is reached or retained marks its target reached
   - each reached line with falls-through set marks the next ordinal reached
   - each structure run holding a reached or retained line marks every line in it reached
3. A line that is neither reached nor retained is removed.

Bits only ever turn on, so the sweep ends. Each backward branch in a chain costs one more sweep.

### 3.7 Skipping in passes one and two

At `MainCompileLoop`, after `GetLineNumber` and the `implicitDimFirst` capture and before
`RegionSwitch` and `STRMarkLine` (`main/compiler.asm:132-144`): if the ordinal is removed,
`jmp MainCompileLoop`.

- A skipped line gets no line-table entry, no line marker, no code and no variables.
- Both passes skip the same lines, so `STRMarkLine`'s compare, the emit sum, `BlockEndCheck` and
  `AsmFlushPool` still agree.
- The first line is a root, so `implicitDimFirst` always names a kept line.
- When a `GP.ASM` line is removed, its body and `GP.ENDASM` lines arrive at `MainCompileLoop` as
  ordinary lines. They carry the same removed bit, so they skip too.

Pass one writes each skipped line's number to the list file as it skips it. The source is selected
for input at that moment. Selecting the list for output deselects the source, and the next read
stops with no error (`docs/memory/two-pass-compiler.md`, "Selecting one direction"). Go through
`IOSelectSource` and an equivalent select for the list, or buffer the numbers in bank 12 and write
them after pass one.

### 3.8 Report

- Pass zero prints `PASS 0` and its dots, as the other passes do.
- The `OK` line gains `DEAD <lines> <bytes>` (`application/source/compiler/memreport.asm`). The bytes
  are pass zero's length less pass one's.
- The debug map needs no change. A removed line has no entry in it.

## 4. Build order

Each step ends with its check passing before the next starts.

1. **Reference set.** `chk.py` and `sweep.py` from the two-pass work are not in the repo. Write a
   script that compiles a fixed list of `testing/` programs and diffs each object against a stored
   copy.
2. **Option plumbing** (1.1). Check: the reference set is byte-identical with line 5 empty.
3. **Pass zero, recording nothing.** Three passes, the early exit, the resets. Nothing is removed.
   Check: the reference set is byte-identical with the option on.
4. **Recording and solving.** Planes, edges, swallow list, sweep. Still nothing is skipped. Print
   the removed marked lines from the solver. Check: those lines against a hand analysis of each
   program in 5.2.
5. **Skipping and the report.** Check: all of section 5.
6. **Keep regions**, both spellings. Check: the keep rows of 5.2.

Compiler changes build with `make libs` (`docs/memory/app-make-does-not-rebuild-compiler-library.md`).
The toolchain is off `PATH` (`docs/memory/build-toolchain-location.md`). Never build PICKDEMO.

## 5. Tests

### 5.1 The identity

For each test program:

1. Compile with the option on. This gives object A and list L.
2. Delete L's lines from the tokenised source and relink it. This needs a new host script, for
   example `source/unit-tests/dcstrip.py`.
3. Compile the stripped source with the option off. This gives object B.

A and B must be byte-identical. Run each program built both ways and compare the output as well.

### 5.2 Programs

One `testing/` program a case, or one program with a section a case.

| case | expected |
|---|---|
| a routine nothing calls | removed |
| two routines that call only each other | both removed |
| `DATA` in an unreached routine, `READ` in live code | `DATA` line kept, value unchanged, the rest of the routine removed |
| `DIM` in an unreached line, the array used live | `DIM` line kept |
| `IF … THEN RETURN` followed by more lines | the next line kept |
| `ON x GOTO` with x out of range | the next line kept |
| `RESTORE n` into an unreached block | line n kept |
| `DEF FN` used, and one unused | kept; removed |
| `GP.DEFPROC` routine used, and one unused | kept; body removed, declaration kept |
| `GOTO` from live code into a `GP.DO` whose opener is unreached | the whole block kept |
| unreached `GP.IF`, `GP.SELECT`, `GP.ASM` | each removed whole |
| unreached lines inside a `GP.BANKED` region | removed; the region still loads and runs |
| a region with every inner line unreached | see 2.7 |
| an unreached `GP.BANKEDSTR` group read live by `GP.BSTR` | kept |
| `REM GP.KEEP` … `REM GP.ENDKEEP` under `#REM 1`, around an unreached routine | kept; both marker lines judged alone |
| the same with `#GPC KEEP` … `#GPC ENDKEEP`, and with one marker of each spelling | kept |
| `REM GP.KEEP` … `REM GP.ENDKEEP` under `#REM 0` | no region; the routine removed |
| `REM GP.KEEPER`; `REM gp.keep`; `PRINT X:REM GP.KEEP:REM 120` | not a marker; a marker; a marker |
| a nested region, an `ENDKEEP` outside a region, a region open at the end | `.error_structure` |
| a reached `{VAR}` on a variable only removed lines create | per decision 2 |
| the edge table forced full | the notice; the object matches option off |

Then run the compiler-runtime `variables` and `arrays` suites, which the bank list in
`x16_storage.inc` requires after any bank change, and `source/unit-tests/banktest3.py`.

### 5.3 Cross-check

Run `source/unit-tests/deadcode.py` on a BASL program. A label block it reports dead that GPC keeps
is a case to look at. GPC may remove more: it works by line and retains only the `DATA` line, not
its whole block.

## 6. Decisions for the user

| # | question | recommended |
|---|---|---|
| 1 | how the option is turned on | `GPC.INPUT` line 5 and the `GPC.BASL` prompt; a source directive later if wanted, with a `REM GP.` spelling so it does not need BASLOAD-GPC |
| 2 | a reached `{VAR}` on a variable only removed lines create | stop with the existing error; the source fix is a keep region or a mention in live code |
| 3 | the marker words | `REM GP.KEEP` / `REM GP.ENDKEEP`, plus `#GPC KEEP` / `#GPC ENDKEEP` while BASLOAD-GPC stays; not `IGNORE_UNUSED`, which in Prog8 silences the messages and removes the code anyway |

If BASLOAD-GPC is dropped, remove the two `#GPC` spellings from the reader in 1.2 and their row in
5.2. The `REM` spelling keeps working unchanged.

## 7. Cost

- Option off: the compiler grows by the new code. Program size is unaffected
  (`docs/memory/compiler-must-not-cap-program-size.md`).
- Option on: one more pass one of compile time, about half again the current compile.
- Two compile-time banks.

## 8. Things not to do

- Do not remove part of a structure.
- Do not treat a string literal that spells a label as an edge. GPC sees only compiled targets.
- Do not stop the compile when a table fills.
- Do not run the fit check in pass zero.
- Do not build PICKDEMO.
