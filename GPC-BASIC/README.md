# GPC-BASIC

The GP.BASIC library — the `GP.*` command set and the BASIC modules built on it, with a runnable
example for each.

**Start at [GP-BASIC.md](GP-BASIC.md)** — the manual: every command, every
routine, every variable name they take, and the traps collected in one table.
[GP-BASIC.GLOBALS.md](GP-BASIC.GLOBALS.md) lists every global each module owns, which
matters because BASL has one flat namespace: a collision is a wrong answer, not an error.

## Using it

Keep this folder as `GPC-BASIC/` beside your own sources and `#INCLUDE` what you need by path:

```basic
#INCLUDE "/GPC-BASIC/GPB.INC.BL"
#INCLUDE "/GPC-BASIC/THEME.INC.BL"
#INCLUDE "/GPC-BASIC/MENUVERT.INC.BL"
```

BASLOAD takes a path, not just a bare filename — **verified on R49**, both `/GPC-BASIC/GPB.INC.BL`
from the root and the relative `GPC-BASIC/GPB.INC.BL`. Prefer the leading slash: it is absolute, so
it keeps working when your program is itself in a subdirectory. (`../` and `//` are *not* understood
by the X16's filesystem, so a path has to go down from somewhere, not up.)

`GPB.INC.BL` comes first and is not optional: it is what makes `GP.DO`, `GP.BOX` and the rest mean
anything to BASLOAD. Without it a line saying `GP.DO 5` is just a syntax error.

Then it is BASLOAD and GPC as usual: `BASLOAD "MYPROG.BL"` to turn the source into a program, and
`GPC.PRG` to compile that.

## Two layers, and the difference matters

| | | costs |
| --- | --- | --- |
| **Core** | `GP.*` commands the **compiler** knows. Machine code in the runtime | runtime bytes, in every program that uses any of them |
| **Extensions** | `XXX.INC.BL` modules written in **BASIC**, called with `GOSUB` | nothing unless you `#INCLUDE` them |
| **Composite** | `GP.*` commands the compiler knows that have **no machine code at all** — it expands them into commands that already exist | **nothing**, ever |

A thing belongs in the core when it is a bulk move or a tight loop — something BASIC is genuinely
bad at. It belongs in an extension when it waits on a human, or is layout, or is data. It is a
composite when it is only a **rename** of something the compiler can already say — those are free,
so use them without thinking about it. A menu is **the `MENUVERT` extension, not a core keyword**,
because it spends all its time waiting for a keypress: assembly there buys nothing a person could
see, and would cost every GPB program 473 bytes whether it had a menu or not.

Examples are `XXX.EXP.BL` — runnable programs, one subject each. Uppercase names throughout,
because these files live on the X16's drive.

### Core — the `GP.*` command set

All of it needs `#INCLUDE "GPB.INC.BL"`, and nothing else.

| Group | Commands | Example |
| --- | --- | --- |
| Loops | `GP.DO` `GP.LOOP` `GP.EXITDO` | `LOOPS.EXP.BL` |
| Block IF | `GP.IF` `GP.ELSEIF` `GP.ELSE` `GP.ENDIF` | `IF.EXP.BL` |
| Multi-way branch | `GP.SELECT` `GP.CASE` `GP.OTHER` `GP.ENDSEL` | `SELECT.EXP.BL` |
| Strings | `GP.INSTR` `GP.STRPTR` `GP.COMP` | `STRINGS.EXP.BL` |
| Strings, composite | `GP.CONTAINS` `GP.ISEMPTY` — free | `STRINGS.EXP.BL` |
| Addresses, composite | `GP.HIBYTE` `GP.LOBYTE` — free; split an address for `GP.CALL` | `ARRAYS.EXP.BL` |
| Arrays | `GP.ARRPTR` — the address of element zero, which is how a BASL module reaches an array | `ARRAYS.EXP.BL` |
| Drawing | `GP.BOX` `GP.FILL` `GP.CHAR` `GP.PRINTAT` | `SCREEN.EXP.BL` |
| Machine code | `GP.CALL` and the `GP.A` `GP.X` `GP.Y` `GP.C` value words | `MLCALL.EXP.BL` |
| Inline assembly | `GP.ASM` `GP.ENDASM` — 65C02 assembled into the program, with labels and `{VAR}` | `ASM.EXP.BL` |

### Extensions — BASIC modules you `#INCLUDE`

| Module | What it gives you | Example |
| --- | --- | --- |
| `STRINGS.INC.BL` | strings: `PADR`/`PADL`/`PADC` pad, `SPLIT` on a delimiter, `REPLACE` every occurrence, `PET2SCR` | `SPLITT.EXP.BL` `STRINGS.EXP.BL` |
| `THEME.INC.BL` | named colour roles, light and dark, so re-skinning is one variable | `MENU.EXP.BL` |
| `APPSYS.INC.BL` | leave the screen as you found it, and **panels to and from disk** | `MENU.EXP.BL` |
| `LINEINPUT.INC.BL` | a positioned, length-limited entry field — what `INPUT` cannot do on a drawn screen | `FORM.EXP.BL` |
| `MENUVERT.INC.BL` | a vertical menu: cursor keys, RETURN, ESC, hotkeys, SNES pad | `MENUDEMO.EXP.BL` |
| `MENUBAR.INC.BL` | the other axis — a horizontal bar, per-item widths taken from the text | — |
| `STASH.INC.BL` | a text rectangle to a RAM bank and back, in `GP.ASM` | — |
| `STASHFILE.INC.BL` | the same rectangle through a **file**, so a panel outlives the program | — |
| `SORT.INC.BL` | shell sort a string array in place, in `GP.ASM` | `ARRAYS.EXP.BL` |
| `STRCASE.INC.BL` | case and trim, in place, in `GP.ASM` | `STRINGS.EXP.BL` |
| `BMX.INC.BL` | a BMX bitmap straight into VERA | `BMXVIEW.EXP.BL` |

**Five of those modules are deliberately not keywords.** The menu, the stash, the sort and the five
in-place string statements would all sit in the GP runtime block, which is **all or nothing**: every
byte of it is written into the object *and* taken off the bottom of the workspace, for any program
that uses one GP keyword. A sort nobody calls and a stash nobody uses would be paid for by every GP
program in the tree. Written in `GP.ASM` and `#INCLUDE`d they cost their own bytes, in the programs
that ask for them, and nothing at all in the ones that do not — which is what keeps the block at
1,024 bytes rather than 2,048.

**`STASHFILE.INC.BL` is the file half of `STASH.INC.BL`,** and a separate file on purpose: a BASL
module has no dead code elimination, so everything it holds is compiled into every program that
includes it, called or not. `STASH.FILE.SAVE` stashes and `BSAVE`s, `STASH.FILE.LOAD` `BLOAD`s and
restores it where it came from, and `STASH.FILE.PUT` drops it somewhere else.

### The rest of the examples

| File | Shows |
| --- | --- |
| `MENU.EXP.BL` | a whole small application — menu, theme, dialog over a stashed screen |
| `MENUTST.EXP.BL` | the menu's regression test, 21 cases |
| `BMXSPD.EXP.BL` | how long a BMX paint really takes, full width against centred |
| `BMXPAL.EXP.BL` | that the picture's palette is borrowed and given back, not taken |
| `ASM.EXP.BL` | inline assembly: labels, branches, and `{VAR}` reaching BASIC's own variables through `#SYMFILE` |
| `UNWIND.EXP.BL` | that a `GOTO` may leave a `GP.SELECT` or `GP.DO` without leaking its frame — and the counts that prove it |
| `ISO.EXP.BL` | that `GP.PRINTAT` follows the screen into ISO mode, with the cells read back by `VPEEK` |

## Naming — BASL is safe, a hand-written `.bas` is not

**BASLOAD gives 64 significant characters; the built-in BASIC gives TWO.** So in a BASL source
`PANEL.COL` and `PANEL.ROW` are genuinely different variables, and the readable names these examples
use cost nothing.

Write the same test as a plain `.bas` and the two-character rule is back: `R30`, `R31` and `R32` are
all `R3`, and `BASE` is the same variable as `BA`. That is a **silent wrong answer, not an error** —
it cost two test cycles while building the drawing commands, both times looking exactly like a
compiler bug. Give raw `.bas` variables distinct first-two characters, or write BASL.

Dotted names also dodge the reserved-word trap (`POS`, `MB`, `ST`, `CHAR`), which BASL does *not*
save you from: a reserved word cannot be an identifier at all.

---

*Working on the compiler rather than with it? The library's internals — how the keyword
declarations are kept in step with the compiler, and how the examples are built from the
development tree — are under "Maintaining the library" in `docs/blitz/GP-BASIC.TIERS.md`, which is
in the source repository and does not ship with the release.*
