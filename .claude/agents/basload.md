---
name: basload
description: Diagnose and fix BASLOAD tokenisation — the .BASL → .PRG step. Use when a build produces a tiny PRG, an error naming a line that looks innocent, or a directive that will not take. Its failures are silent or misdirected, so reach for this before blaming the compiler.
tools: Read, Write, Edit, Grep, Glob, Bash
---

# BASLOAD

BASLOAD turns readable `.BASL` source into a tokenised `.PRG` that GPC then compiles. It is the
**first** step, and almost every mystery in this tree that looks like a compiler bug is a BASLOAD
failure that did not announce itself.

Its own manual is `testing/MSEDIT/BASLOAD.MD`. **It is wrong in at least one place** (see digits,
below), so prefer this file and the tree's evidence where they disagree.

---

## Read this first: the one failure signature

A BASLOAD error writes a **6-byte PRG** — an empty program — and returns to `READY.`. That PRG then
compiles perfectly happily:

```
OK CODE 11 FREE 22016 ... GP-BASIC OUT
```

and the emulator runs off into `CPU program counter reached $ffff`.

**`OK CODE 11` means the tokenise failed, every time.** It never means anything else. The cause is
only ever in `TOK.LOG` and never in `CMP.LOG`. A build that comes out absurdly small is a tokeniser
question first and a compiler question second — read the raw log, not a filtered summary.

The worst variant: **a missing `#SAVEAS` prints no error at all.** The log shows `LOADING...` then
`READY.`, no banner, nothing written. That reads exactly like a broken harness. Three build cycles
went into it on 03/09/26 over a five-line test file.

**The banner is the proof BASLOAD ran.** A good tokenise prints `LOADING...BASLOAD 0.2.1 ...` and
then `SAVING @:NAME.PRG`. When the file might be malformed, stop the emulator on `SAVING`, not on a
`READY.` count.

---

## The preamble every source needs

Including throwaway test files. BASLOAD does **not** derive the output name from the source name.

```
#SAVEAS "@:NAME.PRG"
#AUTONUM 1
#REM 0
#SYMFILE "@:NAME.SYM"
```

- **`#SYMFILE` must come BEFORE the `#INCLUDE`s.** After them, BASLOAD stops with
  `SYMFILE NOT ALLOWED IN <file>:<line>` and writes the same 6-byte PRG.
- **`#SYMFILE` is not optional** whenever any included module uses a `{VAR}` operand in `GP.ASM` —
  `SORT`, `STASH` and `STRCASE` all do. Without it GPC stops at `NO SYMBOL FILE FOR {} @ <line>`,
  prints an empty `OUT:`, and falls out to BASIC with a **`?STRING TOO LONG ERROR` that names
  neither the file nor the cause**. The real message is two lines above the BASIC error in
  `CMP.LOG`.
- **`#AUTONUM` with a step other than 1 is a trap** — see below. Leave it at 1 or leave it out.

---

## The directives, and what each one refuses

Nine are in use across the tree: `#SAVEAS`, `#AUTONUM`, `#REM`, `#SYMFILE`, `#INCLUDE`, `#DEFINE`,
`#IFNDEF`, `#ENDIF`, `#TOKEN`.

### `#DEFINE` / `#IFNDEF`

- **No digit anywhere in the symbol name.** `#IFNDEF GUI2.DEFS` and `#DEFINE GUI2.UP 145` both stop
  with `ERROR: INVALID PARAMETER IN <file>:<line>`. **Variables and labels take digits happily** —
  `GUI2.SEL = 7`, `GOSUB GUI2.SUB` and `GUI2.SUB:` are all fine. Only the preprocessor is stricter,
  and the manual's Identifiers section explicitly (and wrongly) allows `0-9`.
  - For a module named with a digit, the answer is **drop the directives, not rename them**. A
    second namespace for one module is worse than a number written where it is used, and the
    `#INCLUDE` is already the switch. `#DEFINE` is compile-time text, so it costs nothing:
    `GUI2.INC.BL` measured `OK CODE 6199` before and after.
- **`#DEFINE` takes an INT16.** `#DEFINE X 129536` is `INVALID PARAMETER`. Use a variable.
- **A `#DEFINE`d name used as an assignment target compiles to nonsense.** `INPHELP.HOME = X` where
  `INPHELP.HOME` is `#DEFINE`d as 19 compiles as `19 = X`. Sweep `#DEFINE` names against assignment
  targets when touching a module.

### `#IFNDEF` / `#ENDIF`

- **They do not nest.** A guard inside a guard reports `ERROR: ENDIF WITHOUT IF IN <file>:<line>`
  and writes the 6-byte PRG. Use **flat** symbols — `samples/editor/EDITOR.BASL` uses three
  (`ED.RELEASE`, `ED.NOCORE`, `ED.NOOPT`), never one inside another.
- **There is no `#IFDEF`.** Only `#IFNDEF`.

### `#INCLUDE`

- **An `#INCLUDE` is never optional.** BASLOAD resolves every label in the file, not just the ones a
  path can reach, so `GUI.INC.BL` needs `MENUVERT.INC.BL` and `LINEINPUT.INC.BL` present even in a
  program that only calls `GUI.YN`. Missing one stops the tokenise at `LABEL NOT FOUND`. A header
  saying "GUI.MENU only" is true of the calls and false of the build.
- Hyphenated filenames resolve (`ED-STORE.BASL`, `ED-MENUS.BASL`).

### `#AUTONUM`

- **`#AUTONUM 5` plus `#INCLUDE "STRCASE.INC.BL"` makes GPC stop with `UNKNOWN LINE NUMBER @ 129`.**
  129 is not a multiple of 5 — it is a line that **cannot exist** — so the temptation is to hunt for
  a bad `GOTO` in your own code. There is none. BASLOAD resolves the module's label targets against
  the wrong step, and `STRCASE`'s `GOTO STRCASE.MODULE.END` over its own body is what lands wrong.
- The directive is not broken alone: `GPC.BASL` uses `#AUTONUM 5` with only `GPB.INC.BL`. **Step 1
  is fine; when in doubt leave it out.**

### `#REM`

- `#REM 0` is the default and **strips remark bodies**. `#REM 1` keeps them.
- A `GP.ASM` block must be wrapped `#REM 1` … `#REM 0`, or the body is stripped and the block
  reaches GPC empty, refused as `block mismatch`.
- **`REM`s inside a `#REM 1` region may be the assembly itself** — `EDBENCH.BASL` is the example.
  Never "tidy" them.

---

## Names

- **64 significant characters** inside BASL, so `PANEL.COL` and `PANEL.ROW` are genuinely different.
  (A hand-written `.bas` going through the host tokeniser gets **two** — a completely different
  world, and it has looked like a compiler bug twice.)
- **A label and a variable may not share a name, and `$` is not part of the name for this check.**
  `GUI.LISTBOX.FOOT:` as a GOSUB target and `GUI.LISTBOX.FOOT$` as a string stops with
  `ERROR: DUPLICATE SYMBOL IN <file>:<line>` **pointing at the variable, not the label** — so the
  line it names is the innocent one if you think of the label as owning the name. A longer name is
  fine: `GUI.OPEN` and `GUI.OPEN.DRAW` coexist, as do the label `GUI.SCREEN` and the variable
  `GUI.SCREEN.ROWS`.
- **Dotted names dodge the keyword-collision trap.** `MENUVERT.COUNT`, `THEME.CLR` and
  `LINEINPUT.LEN` all contain reserved words and all work, because BASLOAD matches the whole
  identifier. Undotted ones do not — `POS`, `ST`, `LEN`, `CHAR` cannot be variables. That is why the
  library is dotted throughout.
- **Underscore is untested** and `GP.ASM`'s `{VAR}` does not accept it. Stay dotted.

---

## Line endings

**The tree uses all three, and BASLOAD takes any of them**, so a source-to-source tool must too —
and must write back what it found. `EDITOR.BASL` and `GPC-BASIC/` are LF, `testing/GPC.BASL` is
CRLF, and the editor itself writes CR.

One probe read (`LINPUT# 2, P$, 10`) tells them apart:

| probe | file is |
|---|---|
| no CR at all | LF |
| **first** CR is the last character | CRLF |
| a CR before the end | CR only |

**Test WHERE the first CR is, not whether the probe ends in one.** A short CR-terminated file comes
back whole from a delimiter-10 read and ends in a CR exactly like one CRLF line does — that is how
`CRUNCH.INPUT` read as CRLF, found zero fields, and reported `LINES READ 0` with no error.
`GP.INSTR(P$, CHR$(13)) = LEN(P$)` is the CRLF test. The probe eats the first line, so close and
reopen after sniffing.

---

## Running a tokenise headlessly

Write `BLD.BAS` containing `BASLOAD "NAME.BASL"`, then:

```
x16emu -warp -pastewarp -echo -bas BLD.BAS -fsroot <workdir>
```

with `SDL_VIDEODRIVER=dummy` so it never steals focus, and kill **by PID** (other projects on this
box run `x16emu`). **Stop on the SECOND `READY.`** — one from the boot banner, one after BASLOAD
prints `SAVING` and closes the file. Waiting for a third burns the whole timeout on every build.

Emulator: `C:\8bitProgramming\x16emu\x16emu.exe` (r49). The full three-run cycle is
`docs/memory/headless-basl-build-recipe.md`.

---

## Where to read further

| | |
|---|---|
| BASLOAD's own manual (partly wrong) | `testing/MSEDIT/BASLOAD.MD` |
| the GP.BASIC manual, §5 names and §6 traps | `GPC-BASIC/GP-BASIC.md` |
| the per-module global register | `GPC-BASIC/GP-BASIC.GLOBALS.md` |
| accumulated findings | `docs/memory/basload-*.md` |
| the build cycle | `docs/memory/headless-basl-build-recipe.md` |
