# CRUNCH — a source cruncher for BASL

Two programs, the same shape as the compiler: `CRUNCH.PRG` asks the questions and writes
`CRUNCH.INPUT`, `CRUNCH.BIN` reads that file and does the work. Both are written in GP.BASIC and
compiled by GPC, so the cruncher is built with the compiler it exists to make room for.

## Why there is anything left to crunch

**BASLOAD is already most of a cruncher.** It strips `REM`s, renames every variable to a
two-character name (`ED.ASM.VIS%` becomes something like `A7%`) and drops all whitespace when it
tokenises. Removing spaces buys nothing — they are gone in the token stream — and so does
shortening names, or writing `?` for `PRINT`. Every classic C64 BASIC cruncher spends its effort
on exactly those things.

What BASLOAD does **not** do is put two statements on one line, and

> **a line costs exactly one byte of p-code**, plus a four-byte entry in the compiler's
> line-number table.

That is the whole job. Measured on `samples/editor/EDITOR.BASL`:

| | tokenised | object | BASIC lines |
|---|---:|---:|---:|
| as written | 29,449 | 26,411 | 1,571 |
| crunched | 28,490 | **26,189** | 1,316 |

**255 lines removed, 255 bytes of object saved — one line, one byte.** Plus 1,020 bytes off the
line-number table, which is the ceiling that raised `PROGRAM TOO BIG @ 2186` before it got its own
bank. A build with `HOIST` and REM-stripping on reaches 26,156, another 33 bytes.

## The three rules it must not break

1. **Everything after `THEN` is conditional.** Appending a statement to a line that ends in an
   `IF` silently makes it conditional. This is THE trap — it compiles, it runs, and it is wrong
   only sometimes. A line carrying an `IF ... THEN` may be joined *to*, never appended *to*.
2. **A label names a line.** A line carrying one cannot fold into its predecessor, and `GP.CASE`
   inside a `GP.SELECT` has the same shape.
3. **The source line limit.** BASLOAD stops at `#MAXCOLUMN`, default 250.

The engine decides two things about every line — may it fold upward (`CANSTART`), and may anything
fold onto it (`CANACCEPT`) — and starts **deliberately conservative**: every `GP.` block keyword
breaks the run both ways, and so does `DATA`, a directive, a kept trailing `REM`, and any
unconditional transfer. A wrong guess there costs joins, never correctness, and each can be
relaxed on its own once measured.

## The transforms

- **JOIN** — pack consecutive statements onto shared lines. The whole win.
- **COLLAPSE** — a `GP.IF` block with a simple body becomes one plain `IF`:

  ```
  GP.IF ED.KEY$ <> "" THEN        IF ED.KEY$ <> "" THEN ED.KEY = ASC(ED.KEY$) : GOSUB ED.READ.MODS
    ED.KEY = ASC(ED.KEY$)     ->
    GOSUB ED.READ.MODS
  GP.ENDIF
  ```

  Three lines become one. It refuses on anything it does not fully understand — `GP.ELSE` or
  `GP.ELSEIF` in the block, a nested block, a label, `DATA`, a `THEN` of its own, a comment, a
  block over 16 lines, or a line that will not fit — and a refused block is written back exactly
  as it arrived. Worth about two bytes a block; `EDITOR.BASL` has one, this cruncher has 85.
  Single-line `GP.IF` is deliberately illegal, so the target is plain BASIC `IF`.
- **REM** — cut trailing `REM`s from code lines, about two bytes each. **Off by default.** A `REM`
  on its own line is free, so only the trailing ones cost anything, and cutting one throws away
  what the author wrote. Asked for, never assumed.

## CRUNCH.INPUT

Eight CR-terminated lines. The engine validates every field itself, because this file can be
written by hand and the engine run on its own — the same reason `GPC.BIN` re-checks `GPC.INPUT`.

```
1  source file          EDITOR.BASL
2  scope                ROOT
3  output               SUFFIX CRU
4  transforms           JOIN COLLAPSE REM
5  max source line      250
6  map file             (empty)
7  comment mode         KEEP | HOIST
8  verify               (empty)
```

Blank fields take the defaults: scope `ROOT`, output `SUFFIX CRU`, transforms `JOIN COLLAPSE`,
250, comment mode `HOIST`.

**Comment mode.** A comment or blank line generates nothing either way; the question is whether it
breaks a join run. `KEEP` breaks it, so every comment stays above the code it describes; `HOIST`
does not, and packs 32 more lines out of `EDITOR.BASL` at the cost of comments drifting above code
that came before them.

**The original is never touched.** `SUFFIX` writes `EDITOR.CRU` beside `EDITOR.BASL`. Scope `TREE`
and `LIST`, output `INPLACE` and `DIR`, the map file and `VERIFY` are specified above but **not
built yet** — the engine refuses them by name rather than ignoring them.

## Running it

`cruncher-demo.bat` in the repo root points the emulator's drive at this directory and runs
`CRUNCH.PRG`, so `DEMO.BASL` is what it can see. `DEMO.BASL` is deliberately loose — one statement
per line — and carries every trap the engine has to survive: a colon inside a string, `THEN` inside
a string and inside an identifier, a real `IF ... THEN`, a label, `DATA`, and three `GP.IF` blocks
of which only some may be collapsed.

To crunch the editor instead, point the drive at `samples\editor` and drop `CRUNCH.PRG` and
`CRUNCH.BIN` in beside `EDITOR.BASL`.

## Rebuilding

BASLOAD resolves `#INCLUDE` off the drive and `build_basl.py` uses `testing\` as the emulator's
filesystem root, so both sources and the two includes stage there first. `python` and `make` are
off-PATH; see `documents/local.make`.

```
copy samples\cruncher\CRUNCH.BASL             testing\
copy samples\cruncher\CRUNCHER.BASL           testing\
copy samples\cruncher\GPC-BASIC\GPB.INC.BL    testing\
copy samples\cruncher\GPC-BASIC\STRCASE.INC.BL testing\
python source\gpc\build_basl.py CRUNCH.BASL    CRUNCH.SRC.PRG
python source\gpc\build_basl.py CRUNCHER.BASL  CRUNCHER.SRC.PRG
python source\gpc\compile_shared.py --embedded CRUNCH.SRC.PRG   CRUNCH.PRG
python source\gpc\compile_shared.py --embedded CRUNCHER.SRC.PRG CRUNCH.BIN
```

then copy `CRUNCH.PRG` and `CRUNCH.BIN` back here. **EMBEDDED, not shared**, so this directory
stands on its own without a `GPB.RT.nnn.BIN` whose name carries a build number. Shared they are
1,990 and 4,657 bytes; the p-code is what that second pair measures.

**No `#AUTONUM`.** With `STRCASE.INC.BL` included it resolves label targets against the wrong step
and the compile stops with `UNKNOWN LINE NUMBER`.

## How it is tested

1. **Flatten and diff.** Both files are reduced to a statement sequence (split on `:` outside
   string literals, comments and blanks dropped) and to the list of `THEN` clauses, with `GP.IF`
   blocks normalised so a collapsed block compares equal to the block it came from. Identical on
   both means no statement moved and nothing changed conditionality. On the editor: **1,317
   statements and 96 THEN clauses, identical.**
2. **The editor's own self-check.** `DEBUG.MODE = 1` headless, crunched against uncrunched. The
   output is **byte-identical**.

The second is the one that matters: a `THEN` mistake passes the first and fails the second.
