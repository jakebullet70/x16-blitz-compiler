# Compiler directives and string defines

Handoff document. Build steps 1 to 7 are done. The runs of the stripped samples (§3.1) are left. Every part is assembly in GPC or in BASLOAD-GPC.

The plan has three parts:
- `#GPC` directives set compiler options from the source.
- Dead-code removal becomes the default.
- BASLOAD-GPC gains `#DEFINE` with a string value.

## 1. The channel

BASLOAD-GPC emits every `#GPC <text>` line as a BASIC line holding `REM#GPC <text>`: the `$8f` token,
then `#GPC` with no space, then the text as written (`BASLOAD-GPC/README.md`, "a directive channel").
ROM BASIC reads the line as a comment, so an interpreted run ignores it. A `#GPC` line inside a hidden
`#IFDEF` block emits nothing.

The compiler reads two directives now, `#GPC KEEP` and `#GPC ENDKEEP` (`DCKeepMarker` in
`source/compiler/source/main/deadcode.asm`). Every directive below is a GPC change only. BASLOAD-GPC
needs no change for them.

## 2. Directives

| directive | does | replaces |
|---|---|---|
| `#GPC SHARED` | compile against the resident runtime | `GPC.INPUT` line 4 |
| `#GPC EMBEDDED` | carry the runtime in the object | `GPC.INPUT` line 4 empty |
| `#GPC OBJECT "NAME.PRG"` | names the object | `GPC.INPUT` line 2 |
| `#GPC MAP "NAME.MAP"` | names the debug map | `GPC.INPUT` line 3 |
| `#GPC NOSTRIP` | turns dead-code removal off | §3 |
| `#GPC DEADLIST "NAME.DEAD"` | names the removed-line list | `GPC.INPUT` line 5 |
| `#GPC KEEP` / `#GPC ENDKEEP` | a keep region | exists |
| `#GPC DEBUG_ON` / `#GPC DEBUG_OFF` | a debug region | §4 |

### 2.1 Rules

- **Program-wide directives come first.** `SHARED`, `EMBEDDED`, `OBJECT`, `MAP`, `NOSTRIP` and
  `DEADLIST` must sit before the first line that is not a REM. A prescan reads them before pass 0,
  because `NOSTRIP` decides whether pass 0 runs. One of them after the first code line stops the
  compile.
- **The source wins.** A directive overrides the matching `GPC.INPUT` line and the answer typed into
  `GPC.PRG`.
- **Region directives go anywhere.** `KEEP`, `ENDKEEP`, `DEBUG_ON` and `DEBUG_OFF` pair up. A close
  without an open stops the compile. So does an open left open at the end of the program.
- **An unknown word stops the compile.** `#GPC STIRP` must not compile as a comment.
- **One spelling a word.** The word may follow any number of spaces. Its letters may be in any
  case. It ends at a space, a colon or the end of the line, the same test `DCKeepMarker` makes.

### 2.2 Where the code goes

- The prescan: `PrescanDirectives` in `source/application/source/compiler/directives.asm`, called
  by `CompileCode` straight after `ReadControlFile`. It reads lines until the first statement that
  is not a REM and writes each directive over its `GPC.INPUT` field. `NOSTRIP` clears line 5.
- The check: `GPCDirectiveCheck` in `source/compiler/source/commands/rem.asm`, called by
  `CommandREM` in every pass. It raises `UNKNOWN DIRECTIVE`, `DIRECTIVE TOO LATE` and, for a bad
  quoted name, `SYNTAX ERROR`. `gpcCodeSeen` is set by the first statement that is not a REM.
- `GPCDirectiveWord` and `GPCDirectiveName` match a word and a quoted name for both. The word table
  is `GPCDirectiveWords`.
- The region directives: `DCKeepMarker` pairs `KEEP` and `ENDKEEP` in pass zero.
  `GPCDirectiveCheck` pairs `DEBUG_ON` and `DEBUG_OFF` in every pass.

## 3. Dead-code removal on by default

Every compile removes dead code unless `#GPC NOSTRIP` or the control file turns it off.

| `GPC.INPUT` line 5 | means |
|---|---|
| empty | removal on, no list written |
| a file name | removal on, the list written to that file |
| `NOSTRIP` | removal off |

- `compile_shared.py`: `--strip FILE` names the list. A new `--nostrip` writes `NOSTRIP`.
- `GPC.PRG` asks `REMOVE DEAD CODE?` with Y as the default.
- `TURBO-GPC/build.py` keeps `--strip TURBO.DEAD`.
- `GPC.GUI` writes `NOSTRIP` when its DEAD setting is N.
- The `ask-before-adding-library-code` rule stays, by the user's decision.

Done. `PrescanDirectives` sets `pdNoStrip` from `#GPC NOSTRIP` or from line 5 reading `NOSTRIP`, and
then clears line 5. `CompileCode` sets `dcEnabled` unless `pdNoStrip` is set. A `#GPC DEADLIST` in
the source replaces line 5 before the test, so it turns removal on over a `NOSTRIP` line.
`dcref.py` and `dctest.py` write `NOSTRIP` for an off compile. GPC.GUI needs a rebuild to pick up
its change.

### 3.1 Before the default changes

1. Done. The `UNKNOWN VARIABLE IN {} @ 2870` stop was not a pass-0 fault: pass 1 stopped there too.
   The tracked `GPBMODS.SRC.PRG` had been tokenised in a different run from `GPBMODS.SRC.SYM`, so
   the SYM named `FILE.PETP` as `UF` and the PRG used `UI`. Retokenised, GPBMODS compiles stripped:
   276 lines and 1,813 bytes removed.
2. Compile every repo program stripped and run it: GPBMODS, TURBO, the samples
   (`samplesbuild.py`), GPC.PRG, GPC.ERR, the unit tests.

   Compiled. `source/scratch/step4.py` runs the `dcstrip.py` identity on each program's current
   tokenised source: the stripped compile must match a plain compile of the source with the listed
   lines deleted. All 15 match.

   | program | lines removed | bytes saved |
   |---|---|---|
   | GPBMODS | 276 | 1,813 |
   | TURBO | 499 | 4,190 |
   | GPC.HELP | 462 | 3,752 |
   | GPC.GUI | 312 | 2,811 |
   | EDIT | 466 | 3,730 |
   | GPC.ERR | 573 | 4,347 |
   | GUI-FIELD-EDIT | 517 | 5,246 |
   | KV-BIN-STORE | 476 | 3,893 |
   | LANDER64 | 46 | 443 |
   | GUI-LITE | 11 | 116 |
   | BMXVIEW | 11 | 82 |
   | COLORTST | 6 | 65 |
   | MANDELASM | 2 | 32 |
   | MANDEL | 0 | 0 |
   | GPC.PRG | 0 | 0 |

   `gpctest.py full`, against the current compiler: the stripped identity holds on 15 of 16
   programs, `dctest` passes DC1-DC12 and `dcstrip` holds on all eight. RGT stops on and off with
   `GP.BANKEDSTR TEXT IN ONE BANK OVER 8K`; its slot 0 is built to sit just under 8K, and the
   09-15 compiler took it. The off and on rows fail against `gpctest/ref`, which predates 30
   compiler commits. Rebuild the reference before it is used again.

   The identity proves the compiler skips exactly the listed lines. It does not prove those lines
   were dead. TURBO, whose build always strips, has been run stripped. So have GPC.HELP and GPC.ERR,
   by hand. The rest are owed a run.
3. Then flip the default. Done.

## 4. DEBUG_ON and DEBUG_OFF

A debug region, written like a keep region:

```
#GPC DEBUG_ON
    PRINT "CURSOR "; CUR.ROW%; CUR.COL%
#GPC DEBUG_OFF
```

This step reserves the two words. The compiler accepts them and checks the pairing. It records
each line inside a region as a debug line. Nothing else changes yet. What a debug line does is
decided when the first debugging feature needs it.

Done. `GPCDirectiveCheck` pairs the two words in every pass, whether or not dead code is removed.
A close without an open, a second open, or a region open at the end is `BLOCK MISMATCH`.
`gpcDebugLine` is nonzero while the compiler reads a line that started inside a region, so the
`DEBUG_OFF` line counts and the `DEBUG_ON` line does not. A debug region and a keep region may
overlap.

## 5. BASLOAD `#IFDEF`, as it is

BASLOAD-GPC has `#DEFINE`, `#IFDEF`, `#IFNDEF` and `#ENDIF` (`BASLOAD-GPC/src/option.inc`).

- `#DEFINE NAME value` takes an unsigned 16-bit number. A digit in the name, or a negative value,
  is refused.
- Every later use of `NAME` is replaced by the number.
- Blocks nest. There is no `#ELSE`. The other branch is a second block with `#IFNDEF`.
- A define comes only from the source. There is no command-line define.

The library uses it for include guards (`#IFNDEF GP.DEFS` in `GPB.INC.BL`). GPBMODS and TURBO use
no conditional blocks.

It needs no compiler work. It combines with `#GPC`, because a hidden block emits nothing:

```
#DEFINE DEBUG 1
#IFDEF DEBUG
#GPC DEBUG_ON
#ENDIF
```

Deleting the `#DEFINE` line removes the directive and every `#IFDEF DEBUG` block with it. Dead-code
removal cannot do that for `DIM` and `DATA` lines, which it always keeps. `#IFDEF` can.

## 6. String defines in BASLOAD-GPC

```
#DEFINE APP.TITLE "TURBO GPC"
#DEFINE SETTINGS.FILE "SETTINGS.KVB"
    PRINT APP.TITLE
    OPEN 1,8,2,SETTINGS.FILE
```

A use of the name emits the quoted text, quotes included. A use inside a string literal is not
replaced.

### 6.1 Done

- `option.inc`, `define_value`: a value that starts with `"` stores the text to the closing quote
  through `symbol_add_text`. A missing closing quote is INVALID PARAMETER.
- The text sits in the symbol table banks (2-9) at the next free symbol spot, as a length byte and
  the text. The 16-bit value holds bits 13-15 the bank less 2, bits 0-12 the offset from `$A000`. A
  full table is SYMBOL TABLE FULL.
- `symbol.inc`: `SYMBOLTYPE_STRING_PASS1` (7) and `_PASS2` (8). Redefinition and `#IFDEF` treat
  them as a number define.
- `line.inc`, `symbol_string`: the quoted text replaces the name in the line, and the line is read
  on from the opening quote. `{codes}` and `\X` work as in a literal.
- A line pushed past the line limit is LINE TOO LONG.
- A `#GPC` line is never searched for a define name.
- A define in the source overrides `GPC.INPUT`.

## 7. Build order

1. Fix the pass-0 `{VAR}` failure (§3.1). Done.
2. The prescan and the program-wide directives (§2). Done.
3. The region directives `DEBUG_ON` and `DEBUG_OFF` (§4). Done.
4. The stripped compiles of every repo program (§3.1). Compiled; the runs are owed.
5. Dead-code removal on by default (§3). Done.
6. String defines in BASLOAD-GPC (§6). Done.
7. Help: the `#GPC` section in `GP-BASIC.md`, the stale "nothing reads these yet" line in
   `BASLOAD-GPC/README.md`, and the `#DEFINE` entry. Done: `GP-BASIC.md` §2 and §7, `GP-BASIC.FILES.md`
   §2, and help rendered.

## 8. Decisions for the user

- The names `NOSTRIP` and `DEADLIST`.
- Whether a directive or the control file wins. The source wins.
