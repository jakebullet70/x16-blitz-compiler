# GPC-BASIC

The GP.BASIC library: the BASLOAD includes and the example programs for GPC's `GP.*` keyword
extension. The design lives in [docs/blitz/GP-BASIC.TIERS.md](../docs/blitz/GP-BASIC.TIERS.md)
(build plan) and [docs/blitz/GP-BASIC.PLAN.md](../docs/blitz/GP-BASIC.PLAN.md) (background).

**Before naming a variable in a program that includes any of this, read
[docs/blitz/GP-BASIC.GLOBALS.md](../docs/blitz/GP-BASIC.GLOBALS.md)** — BASL has one flat namespace,
so every module's variables are visible to your program and a collision is a wrong answer rather
than an error.

## Naming

Flat folder, **UPPERCASE** names, role carried in the extension:

| Pattern | Role |
|---|---|
| `XXX.INC.BL` | include — `#TOKEN`/`#DEFINE` declarations, `#INCLUDE`d by other sources |
| `XXX.EXP.BL` | example — a runnable program, one feature each |

Uppercase because these files live on the X16's drive, where BASLOAD reads them.

Current contents:

| File | Covers |
|---|---|
| `GP.INC.BL` | the keyword tokens — every BASL source using `GP.*` must `#INCLUDE` it |
| `STRHELP.INC.BL` | string helpers in BASL (`STRHELP.PADR`/`PADL`/`PADC`/`SPLIT`). Unlike `GP.INC.BL` it contains *code*, called with `GOSUB` |
| `LOOPS.EXP.BL` | `GP.DO` / `GP.LOOP` / `GP.EXITDO` |
| `MLCALL.EXP.BL` | `GP.CALL` and the `GP.A`/`GP.X`/`GP.Y`/`GP.C` value words |
| `STRINGS.EXP.BL` | `GP.INSTR`, `GP.STRPTR`, `GP.TRIM`/`LTRIM`/`RTRIM`, `GP.UPPER`/`LOWER` |
| `SPLITT.EXP.BL` | `STRHELP.SPLIT`, the BASL tokeniser |
| `ARRAYS.EXP.BL` | `GP.SORT`, `GP.COMP`, `GP.ARRPTR` |
| `SCREEN.EXP.BL` | `GP.BOX`, `GP.FILL`, `GP.PRINTAT`, `GP.STASH`/`GP.RESTR` |
| `THEME.INC.BL` | colour roles, light and dark. Data, not code — no tokens, no runtime bytes |
| `APPHELP.INC.BL` | `APPHELP.STARTUP`/`RESTORE` (leave the user's screen as you found it) and panels saved to disk |
| `MENU.EXP.BL` | `GP.MENU` + `GP.SEL`, with the theme and app helpers — a whole small application |
| `SELECT.EXP.BL` | `GP.SELECT` / `GP.CASE` / `GP.ELSE` / `GP.ENDSEL`, and where it beats `ON x GOSUB` |
| `INPHELP.INC.BL` | a positioned, length-limited entry field — what `INPUT`/`LINPUT` cannot do on a drawn screen |
| `FORM.EXP.BL` | three fields you can move between: `INPHELP` with the theme and app helpers |
| `BMX.INC.BL` | load a BMX bitmap into VERA — `GP.STRPTR` + `GP.CALL MACPTR` streaming straight at the data port |
| `BMXVIEW.EXP.BL` | the viewer built on it: prompt, header, picture |

### Names — BASL is safe, a hand-written `.bas` is not

**BASLOAD gives 64 significant characters; the built-in BASIC gives TWO** (`BASLOAD.MD:57`). So in a
BASL source `PANEL.COL` and `PANEL.ROW` are genuinely different variables, and the readable names
these examples use cost nothing.

Write the same test as a `.bas` for the host tokeniser and the two-character rule is back: `R30`,
`R31` and `R32` are all `R3`, and `BASE` is the same variable as `BA`. That is a **silent wrong
answer, not an error** — it cost two test cycles while building tier 6, both times looking exactly
like a compiler bug. Give raw `.bas` variables distinct first-two characters, or write BASL.

Dotted names also dodge the keyword-collision trap (`POS`, `MB`, `ST`, `CHAR`), which BASL does *not*
save you from — a reserved word cannot be an identifier at all.

## Why the includes exist at all

**Two tokenisers have to learn every GP keyword, and only one of them does it by itself.**

| | learns GP keywords from | needs `GP.INC.BL` ? |
|---|---|---|
| `bin/tokenise.zip` (host, for `.bas`) | `source/common-scripts/c64tokens.py`, at build time | no |
| BASLOAD (on the X16, for BASL sources) | nothing — it knows only ROM keywords | **yes** |

So a BASL source saying `GP.DO 5` is a syntax error until `#INCLUDE "GP.INC.BL"` has declared the
token. That include is the *only* thing standing between BASL sources and the GP keyword set.

## Staging — read this before moving files

The copies here are the **masters**. BASLOAD resolves `#INCLUDE "GP.INC.BL"` by **bare filename off
the emulator's drive**, and `testing/` is that drive, so to build anything:

- edit the master here
- copy `GP.INC.BL` and the source you are building into `testing/`
- `python source/gpc/build_basl.py XXX.EXP.BL XXX.PRG`, then compile the PRG with `GPC.BLITZ.BIN`

Do not point a program at `GPC-BASIC/...` — that path does not exist from the X16's side.

## The drift hazard

`GP.INC.BL` restates the token values from `getGP()` in `source/common-scripts/c64tokens.py`. Adding a
keyword in one place and not the other produces a **BASLOAD syntax error** — loud, but a wasted
debugging session. Generating this file from `c64tokens.py` at build time would remove the hazard, and
is worth doing before the keyword list grows past a handful.

Token values are decimal because `#TOKEN <name> <int16>` takes an int16 (`testing/MSEDIT/BASLOAD.MD`).
They are allocated **downward from `$CE7F`** and never renumbered.

## Note on the tokens

A `.PRG` containing a `$CE7x` byte is **compile-only**: the ROM cannot `LIST` or `RUN` it, because
there is no BASIC handler behind those tokens. That is expected, not a fault.
