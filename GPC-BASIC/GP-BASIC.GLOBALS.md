# GP.BASIC — the global name register

**BASL has one flat namespace and nothing else.** No locals, no scoping, no parameters. Every
variable in every `#INCLUDE`d module is visible to your program, and every variable in your program
is visible to the modules. Nothing warns you: a collision is a wrong answer, not an error.

This document is the register of what is already taken. Read it before naming anything.

The manual — commands, routines and the traps — is [GP-BASIC.md](GP-BASIC.md); this is its §5 in
full.

The rule the library follows, and that you should follow too:

> **One module, one dotted prefix, and nothing writes outside its own.**

---

## 1. The prefixes that are taken

| Prefix | Owner | What it is |
|---|---|---|
| `GP.` | `GP.INC.BL` | **keywords, not variables** — see §2, this one is different |
| `STRHELP.` | `STRHELP.INC.BL` | string helpers |
| `THEME.` | `THEME.INC.BL` | colour roles |
| `APPHELP.` | `APPHELP.INC.BL` | screen save/restore, panels to disk |
| `INPHELP.` | `INPHELP.INC.BL` | entry fields |
| `MENUHELP.` | `MENUHELP.INC.BL` | vertical menus |
| `BMX.` | `BMX.INC.BL` | BMX bitmap loading |
| `BMXK.` | `BMX.INC.BL` | its KERNAL/VERA constants, kept apart from its variables |

Pick anything else for your own program. `AIRLIFT.`, `GAME.`, `MAP.` — a prefix costs nothing at
runtime because **BASLOAD crunches every identifier down to a short BASIC variable**, so a long
readable name and a two-letter one compile to exactly the same thing.

**Do not reuse a taken prefix even for something the module has not defined.** `THEME.MINE` looks
free today; it is one library update away from not being.

---

## 2. `GP.*` is keywords, not variables — and the difference bites

`GP.INC.BL` defines **no variables at all**. It is 31 `#TOKEN` lines and nothing else. Everything
spelled `GP.something` is a BASIC *keyword*, so:

```basic
GP.A = 5          ← SYNTAX ERROR. GP.A is a keyword; you cannot assign to it.
X = GP.A          ← correct. It reads the accumulator after the last GP.CALL.
```

The value words are `GP.A`, `GP.X`, `GP.Y` and `GP.C` — the registers after `GP.CALL`, and now the
whole list of them. They are tokens rather than variables for a hard reason: **nothing in the
runtime can write a BASIC variable by name**, so a command that needs to hand a value back has to
hand it back through a keyword. X16's own `ST`, `MX` and `MY` exist for the same reason.

The full keyword list lives in `GPC-BASIC/GP.INC.BL`, and the token numbers mirror `getGP()` in
`source/common-scripts/c64tokens.py`.

---

## 3. The modules

Each table is **in** (set before the `GOSUB`), **out** (read after it), and **internal** (do not
read, do not write, do not rely on).

### `THEME.INC.BL`

| | |
|---|---|
| in | `THEME.DARK` — 0 light, non-zero dark, read by `THEME.LOAD`<br>`THEME.ATTR` — a packed attribute, for `THEME.SET` and `THEME.HI` |
| out | `THEME.CLR(role)` — the colour array, `DIM`med to `THEME.SLOTS`<br>`THEME.INV` — the inverse attribute, from `THEME.HI` |
| internal | `THEME.READY` |
| constants | `THEME.PAGE` `THEME.TEXT` `THEME.TITLE` `THEME.BORDER` `THEME.HILITE` `THEME.DIMMED` `THEME.WARN` `THEME.SLOTS` |

`THEME.CLR` is the array this module `DIM`s. **Do not `DIM` it yourself** — the module owns it, and
`DIM`ming an array GPC has already dimensioned is an error.

### `APPHELP.INC.BL`

| | |
|---|---|
| in | `APPHELP.FILE$` `APPHELP.BANK` `APPHELP.X` `APPHELP.Y` `APPHELP.W` `APPHELP.H` `APPHELP.DEV` — the panel routines |
| out | `APPHELP.MODE` `APPHELP.COLS` `APPHELP.ROWS` `APPHELP.COLOUR` — set by `APPHELP.STARTUP` |
| internal | `APPHELP.LAST` |
| constants | `APPHELP.SCRMODE` `APPHELP.COLREG` `APPHELP.WINDOW` `APPHELP.HEADER` |

`APPHELP.COLS` and `APPHELP.ROWS` are the ones to lay your screen out from. **Do not assume 80×60** —
the X16 boots there but `SCREEN 0` is 40×30, and someone who prefers larger text is running one.

### `STRHELP.INC.BL`

| | |
|---|---|
| in | `STRHELP.STR$` — the string, in and out<br>`STRHELP.WIDTH` — field width, the pad routines<br>`STRHELP.DELIM$` `STRHELP.MAX` — `SPLIT` (`MAX` 0 means 10)<br>`STRHELP.FIND$` `STRHELP.REPL$` — `REPLACE`<br>`STRHELP.PET` — a PETSCII code, `PET2SCR` |
| out | `STRHELP.STR$` — padded, or replaced, in place<br>`STRHELP.N` — how many fields `SPLIT` found, always ≥ 1<br>`STRHELP.FIELD$(1..N)` — the fields themselves<br>`STRHELP.SCR` — the screen code from `PET2SCR` |
| internal | `STRHELP.GAP` `STRHELP.HALF` `STRHELP.REST$` `STRHELP.AT` `STRHELP.LIM` `STRHELP.OUT$` |

**`STRHELP.FIELD$` is the one array the library deliberately does NOT `DIM`.** Left alone, GPC's
implicit `DIM` gives you 0..10. If you want more, `DIM` it yourself **before the first call** and set
`STRHELP.MAX` to match — `DIM`ming an array GPC has already auto-dimensioned is an error, so it is
one or the other. This is the opposite of `THEME.CLR`, which the module owns outright; the two are
worth keeping straight.

### `INPHELP.INC.BL`

| | |
|---|---|
| in | `INPHELP.X` `INPHELP.Y` — top left of the field<br>`INPHELP.LEN` — how many characters fit<br>`INPHELP.ATTR` — packed attribute<br>`INPHELP.TEXT$` — the starting value<br>`INPHELP.MASK` — non-zero shows asterisks<br>`INPHELP.LABEL$` — `INPHELP.ASK` only |
| out | `INPHELP.TEXT$` — what was typed<br>`INPHELP.KEY` — the key that ended it |
| internal | `INPHELP.SHOW$` `INPHELP.WAS$` `INPHELP.K$` `INPHELP.CELL$` `INPHELP.CODE` `INPHELP.CX` `INPHELP.CA` `INPHELP.INV` `INPHELP.LIT` `INPHELP.TICK` `INPHELP.DONE` `INPHELP.FILLED` `INPHELP.HOME` `INPHELP.BAR` |
| constants | `INPHELP.RETURN` `INPHELP.DELETE` `INPHELP.ESCAPE` `INPHELP.STOP` `INPHELP.DOWN` `INPHELP.UP` `INPHELP.TAB` `INPHELP.SPACE` `INPHELP.STAR` `INPHELP.BLINK` |

`INPHELP.SHOW$` is listed internal but is the one exception worth knowing: it holds what the field
*displayed*, which is what you want if you are repainting a masked field yourself. `FORM.EXP.BL`
uses it for exactly that.

### `BMX.INC.BL`

| | |
|---|---|
| in | `BMX.FILE$` |
| out | `BMX.ERROR$` — empty means it worked<br>`BMX.WIDTH` `BMX.HEIGHT` `BMX.DEPTH` `BMX.VERSION` `BMX.PALUSED` `BMX.PALFIRST` `BMX.DATAOFF` `BMX.PACKED` — the header, readable after `BMX.OPEN` |
| in, optional | `BMX.STASH` — where `BMX.PAINT` keeps the machine's palette; VRAM `$13000` by default, `-1` to keep nothing |
| internal | `BMX.PTR` `BMX.HEADER$` `BMX.SCRATCH` `BMX.SCRATCH$` `BMX.PALBASE` `BMX.ADDR` `BMX.LO` `BMX.HI` `BMX.BANK` `BMX.REST` `BMX.COUNT` `BMX.CHUNK` `BMX.GOT` `BMX.STEP` `BMX.SKIP` `BMX.ROW` `BMX.ROWS` `BMX.X0` `BMX.Y0` `BMX.BAD` `BMX.KEPT` `BMX.SRC` `BMX.DST` |
| constants | `BMXK.MACPTR` `BMXK.CHKIN` `BMXK.CLRCHN` `BMXK.MEMCOPY` `BMXK.VCTRL` `BMXK.VLO` `BMXK.VMID` `BMXK.VHI` `BMXK.PORTLO` `BMXK.PORTLO.B` `BMXK.PORTHI` `BMXK.LFN` |

`BMX.PTR` doubles as the "have I initialised" flag — it is zero until `BMX.INIT` has run. Zeroing it
yourself would leak a string block and re-allocate.

**`BMX.STASH` is the one variable here you may want to set**, and it has to be set before the first
`BMX.OPEN` — `BMX.INIT` runs then, and fills in the default only if you have not. That is why `-1`
rather than `0` switches the stash off: `0` already means "never set". `BMX.KEPT` is the once-per-run
guard that makes a slideshow restore the *machine's* palette rather than the previous picture's.

### `MENUHELP.INC.BL`

| | |
|---|---|
| in | `MENUHELP.X` `MENUHELP.Y` — top left of the first row<br>`MENUHELP.WIDTH` — cells wide, which is the width of the highlight<br>`MENUHELP.COUNT` — how many rows<br>`MENUHELP.ITEM$()` — the rows, 1..COUNT; **the caller owns the `DIM`**<br>`MENUHELP.ATTR` — packed attribute<br>`MENUHELP.HIATTR` — the highlighted row; 0 inverts `MENUHELP.ATTR`<br>`MENUHELP.HOT$` — one hotkey character a row<br>`MENUHELP.HOTATTR` — tint for the hotkey letter; 0 is off<br>`MENUHELP.FLAGS` — added together<br>`MENUHELP.SEL` — the row to start on |
| out | `MENUHELP.SEL` — 1..COUNT, or 0 if cancelled<br>`MENUHELP.KEY` — the key that ended it |
| internal | `MENUHELP.SCAN` `MENUHELP.EACH` `MENUHELP.DONE` `MENUHELP.CODE` `MENUHELP.INCHAR$` `MENUHELP.PREVSEL` `MENUHELP.HIGHLIGHT` `MENUHELP.DRAWROW` `MENUHELP.DRAWATTR` `MENUHELP.DRAWTEXT$` `MENUHELP.DRAWY` `MENUHELP.HOTCODE` `MENUHELP.HOTLAST` `MENUHELP.WANTCODE` `MENUHELP.HOTAT` `MENUHELP.HOTWANT` `MENUHELP.HOTHERE` `MENUHELP.HOTSCAN` `MENUHELP.PADNOW` `MENUHELP.PADNEW` `MENUHELP.PADHELD` `MENUHELP.PADRAW` |
| constants | `MENUHELP.MUSTSEL` `MENUHELP.KEEPMARK` `MENUHELP.NOWRAP` `MENUHELP.GAMEPAD` `MENUHELP.UP` `MENUHELP.DOWN` `MENUHELP.ENTER` `MENUHELP.ESCAPE` `MENUHELP.STOP` `MENUHELP.SPACE` `MENUHELP.PORT` `MENUHELP.PAD.UP` `MENUHELP.PAD.DOWN` `MENUHELP.PAD.B` `MENUHELP.PAD.START` |

**`MENUHELP.SEL` is both an input and an output** — it is the row to start on going in and the row
chosen coming out, so a menu reopened without clearing it reopens where it was. That is usually what
you want; set it to 0 when it is not.

`MENUHELP.DRAWROW`, `MENUHELP.DRAWATTR` and `MENUHELP.DRAWTEXT$` are listed internal but are the
documented arguments to `MENUHELP.ROW`, which is public: they are internal to `MENUHELP.RUN`, not to
you. `MENUHELP.HOTFIND` reads the first two and answers in `MENUHELP.HOTAT`.

---

## 4. Nothing here is re-entrant, and that is not a bug you can work around

A module's parameters *are* its globals. There is nowhere else to put them. So:

- **You cannot call `INPHELP.GET` from inside `INPHELP.GET`** — no callback out of a field.
- **You cannot nest `BMX.OPEN`** — one file at a time, and `BMXK.LFN` says so too.
- **A `GOSUB` from inside a module into code that calls the same module will corrupt it silently.**

In practice this only bites if you write a callback. If you need one, copy the values you care about
into your own variables first.

`THEME.*` is the exception: `THEME.LOAD` only writes, so calling it from anywhere is safe.

---

## 5. Labels are global too

Every `NAME:` in every module is a jump target in one flat space, including the ones you were never
meant to call. `BMX.STREAM.MORE`, `INPHELP.REDRAW`, `THEME.LOAD.DARK` and most of `MENUHELP.*` are
internal, and a `GOSUB` to one will do something, just not something useful.

`MENUHELP` is the module with the most of them, because driving a menu is mostly branching:
**`MENUHELP.RUN`, `MENUHELP.DRAW`, `MENUHELP.ROW` and `MENUHELP.HOTFIND` are the four you may call.**
`MENUHELP.WAIT`, `.KEYED`, `.SETTLE`, `.WRAPTOP`, `.WRAPBOT`, `.CANCEL`, `.HOTKEY`, `.PADKEY`,
`.PADREAD` and the three `FOLD` helpers are not.

Each module also has a skip label it jumps over itself with — `THEME.SKIP`, `APPHELP.SKIP`,
`STRHELP.SKIP`, `BMX.MODULE.END`, `INPHELP.MODULE.END`, `MENUHELP.MODULE.END`. Those exist so an
include can sit anywhere in the file, the top included. **Do not branch to one.**

One trap found the hard way, worth repeating: **BASLOAD refuses a name used as both a label and a
variable** (`BASLOAD.MD:319`). `BMX.SKIP` is the byte-skip counter, so the module's skip label had to
be `BMX.MODULE.END` — a name is either a label or a variable, never both.

---

## 6. Two more naming rules that are not about collisions

**`#DEFINE` takes an INT16** (`BASLOAD.MD:313`). A constant above 65535 is
`ERROR: INVALID PARAMETER`, not a warning — which is why `BMX.PALBASE` (VRAM `$1FA00`, 129536) is an
ordinary variable and not a `#DEFINE`. Every VRAM address past `$FFFF` has the same problem.

**A dotted name whose tail is a reserved word is fine.** `MENUHELP.COUNT`, `THEME.CLR`,
`INPHELP.LEN` and `INPHELP.RETURN` all contain keywords and all work, because BASLOAD matches the whole identifier. An
*undotted* one does not: `POS`, `MB`, `ST`, `LEN` and `CHAR` cannot be variables at all. This is the
main reason the library is dotted throughout.

**And the rule that only applies outside BASL:** BASLOAD gives 64 significant characters, but the
built-in BASIC gives **two**. Write the same code as a hand-typed `.bas` for the host tokeniser and
`THEME.CLR` and `THEME.COUNT` become the same variable. That is a silent wrong answer — it cost two
test cycles during tier 6, both times looking exactly like a compiler bug. Inside BASL you are safe;
in a raw `.bas`, give every variable a distinct first two characters.

---

## 7. Regenerating this

The tables above were extracted from the sources rather than remembered. To check them after a
change:

```bash
python - <<'PY'
import re, os, glob
for f in sorted(glob.glob("GPC-BASIC/*.INC.BL")):
    s = open(f, encoding="utf-8").read()
    body = "\n".join(l for l in s.split("\n") if not l.strip().startswith("##"))
    body = re.sub(r'"[^"]*"', ' ', body)          # literals are not identifiers
    defines = set(re.findall(r"^#DEFINE\s+([A-Z0-9.$]+)", body, re.M))
    labels  = set(re.findall(r"^([A-Z][A-Z0-9.]*):", body, re.M))
    pref    = os.path.basename(f).split(".")[0]
    idents  = {i for i in re.findall(r"\b([A-Z][A-Z0-9.]*\$?)", body)
               if i.startswith(pref) or i.startswith(pref[:3] + "K")}
    print(os.path.basename(f))
    print("  const :", " ".join(sorted(defines)))
    print("  labels:", " ".join(sorted(labels)))
    print("  vars  :", " ".join(sorted(idents - defines - labels)))
PY
```

It cannot tell **in** from **out** from **internal** — that is a judgement call and lives in each
module's header comment. What it will catch is a variable that has appeared and is not written down
here.
