# Sample — COLOR-TEST

Edit a `THEME.INC.BL` theme against a mock of the GUI, and read the result back as source.

## Keys

A vertical menu of the seven roles. UP and DOWN choose one, LEFT and RIGHT walk its colour through
the palette, and the mock above repaints on every step. `T` selects the next theme, `R` reloads the
selected theme's shipped values, `Q` restores the screen and ends.

Beside each menu row is the `THEME.CLR` line that row produces, ready to paste into a `THEME.LOAD`
branch in `GPC-BASIC/THEME.INC.BL`.

```
COLOUR    0   1   2   3   4   5   6   7   8   9   A   B   C   D   E   F
                                      ====

 [BACKGROUND  6 BLUE  ]   THEME.CLR(THEME.PAGE)   = 6 * 16 + 6
  TEXT        1 WHITE     THEME.CLR(THEME.TEXT)   = 6 * 16 + 1
  TITLE       3 CYAN      THEME.CLR(THEME.TITLE)  = 6 * 16 + 3
  BOX FRAME  14 LTBLUE    THEME.CLR(THEME.BORDER) = 6 * 16 +14
  HILITE BAR  1 WHITE     THEME.CLR(THEME.HILITE) = 1 * 16 + 6
  DIMMED     12 MDGREY    THEME.CLR(THEME.DIMMED) = 6 * 16 +12
  WARN       13 LTGRN     THEME.CLR(THEME.WARN)   = 6 * 16 +13

UP DN  ROLE   <- ->  COLOUR   T  THEME - X16     R  RESET   Q  QUIT
```

## One colour a role

Every role is a foreground on a background they all share, and `BACKGROUND` — the first menu row —
is that background. It is also `THEME.PAGE`, which is the background twice over.

**`HILITE` is the exception.** It is a filled bar, so its row picks the *bar* colour and the text on
it is the page colour. That is what makes it read as reversed, and it reproduces the shipped `X16`,
`DARK` and `LIGHT` values exactly — 22, 240 and 1, checked against `THEME.CLR()` on the machine. A
bar set to the page colour would vanish, so there the text falls back to black or white.

The one place the model loses fidelity is `GRAY`: XFMGR's `ROW_HILIGHT` is `$E1`, white on light
blue, and one colour a role renders it `$EB`, page-grey on light blue. `THEME.INC.BL` carries the
true `$E1`; the tool re-derives the foreground the moment you edit that row.

## Five themes

`X16`, `DARK`, `LIGHT`, `GRAY` and `CUSTOM`, cycled with `T`. `GRAY` is lifted from the XFMGR file
manager's `src/stree.pb`, `MODULE theme` — `TXT_NORMAL $B1`, `TXT_BRIGHT $B7`, `BOXES $BE`,
`ROW_HILIGHT $E1`. That module has no dimmed or warning colour, so those two are chosen here and are
the ones worth tuning first.

**`CUSTOM` inherits what is on the screen.** `T` writes the roles back to `THEME.CLR()` before
cycling and `CUSTOM` loads nothing, so the theme you step to `CUSTOM` *from* is what it starts as.
The other four do load, so tune after arriving at `CUSTOM`, or tune `GRAY` and press `T` once.
`R` on `CUSTOM` resets it to `X16`.

Renumbering was avoided: `X16` is the old `CLASSIC` at `THEME.ID` 0 and `DARK` is still 1, so the
editor, GPC-HELP and the `.EXP.BL` examples are unaffected — they only ever set 0 or 1. They do now
cycle through five themes rather than three.

## The controls are not drawn in the scheme

Everything below `CT.CHY` is white on black and stays that way. Setting a role to the background
blanks that part of the mock, which is the honest result and worth seeing; painting the instructions
in the same pair would take the way out with it. Verified by reading the cells back: with all seven
roles on 15, the key row still reads attribute 1 and the selected menu row 16.

## Layout

`SCREEN 1` — 80x30, the mode in `CT.MODE`. `APPSYS.STARTUP` runs first, before that `SCREEN`, so
what `APPSYS.RESTORE` puts back on the way out is the screen you started with and not this one. The
size is then asked for again, because `APPSYS.STARTUP` reported the screen the user had rather than
the one just set.

The controls are the bottom 13 rows and the mock gets the rest, so the row anchors follow
`APPSYS.ROWS` and 80x60 works as well. **The columns are laid out for 80 and do not narrow** — a
40-column mode is not supported.

Literals are upper case throughout. `GP.PRINTAT` converts PETSCII and BASLOAD passes literals
through as source bytes, so lower case lands on the graphics half of the default font.

## Build

```
python source/gpc/build_basl.py COLORTST.BASL COLORTST.SRC.PRG
python source/gpc/compile_shared.py COLORTST.SRC.PRG COLORTST.PRG
```

Both run in `testing/`, which needs `COLORTST.BASL` and the three modules in `GPC-BASIC/` beside it.
Shared, so `GPC.RT.nnn.BIN` must be on the drive at run time. 3,011 bytes of p-code.

`color-demo.bat` in the project root builds nothing and just runs it.

## Not here: saving the scheme to a file

An `S` key wrote the lines to `SCHEME.TXT`. The file came out correct every time, and the program
then stopped with `INPUT/OUTPUT ERROR @ $005B`.

It is not the file I/O. `OPEN`/`PRINT#`/`CLOSE` in isolation, inside a `GP.DO`, behind a `GOSUB`,
and behind a `GP.SELECT` all pass; so does the same routine called from the top level of this
program. It reproduces only from inside the `GP.DO` key loop, and it stops reproducing as soon as a
plain `PRINT` follows the `CLOSE` — which points at the channel state a bare `PRINT` resets, not at
the sample.
