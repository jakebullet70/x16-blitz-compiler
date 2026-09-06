# GP.BASIC — the global name register

BASL has one flat namespace. No locals, no scoping, no parameters. Every
variable in every `#INCLUDE`d module is visible to your program, and every variable in your program
is visible to the modules. Nothing warns you: a collision is a wrong answer, not an error.

This document is the register of what is already taken. Read it before naming anything.

The manual — commands, routines and the traps — is [GP-BASIC.md](GP-BASIC.md); this is its §5 in
full.

The rule the library follows, and that you should follow too:

The convention is one dotted prefix per module, and nothing writes outside its own prefix.

---

## 1. The prefixes that are taken

| Prefix | Owner | What it is |
|---|---|---|
| `GP.` | `GPB.INC.BL` | **keywords, not variables** — see §2, this one is different |
| `STR.` | `STRINGS.INC.BL` | string helpers |
| `THEME.` | `THEME.INC.BL` | colour roles |
| `APPSYS.` | `APPSYS.INC.BL` | screen save/restore, panels to disk |
| `LINEINPUT.` | `LINEINPUT.INC.BL` | entry fields |
| `MENUVERT.` | `MENUVERT.INC.BL` | vertical menus |
| `BMX.` | `BMX.INC.BL` | BMX bitmap loading |
| `BMXK.` | `BMX.INC.BL` | its KERNAL/VERA constants, kept apart from its variables |
| `FILE.` | `FILEIO.INC.BL` | the drive: status, exists, delete, rename, directories |
| `FILE.DIR.` | `FILEDIR.INC.BL` | reading a directory, kept apart from the rest of `FILE.` |

Pick anything else for your own program. `AIRLIFT.`, `GAME.`, `MAP.` — a prefix costs nothing at
runtime because BASLOAD crunches every identifier down to a short BASIC variable, so a long
readable name and a two-letter one compile to exactly the same thing.

Do not reuse a taken prefix for a name the module has not defined. `THEME.MINE` looks
free today; it is one library update away from not being.

---

## 2. `GP.*` is keywords, not variables — and the difference bites

`GPB.INC.BL` defines no variables. It is 31 keyword declarations and nothing else. Everything
spelled `GP.something` is a BASIC *keyword*, so:

```basic
GP.A = 5          ← SYNTAX ERROR. GP.A is a keyword; you cannot assign to it.
X = GP.A          ← correct. It reads the accumulator after the last GP.CALL.
```

The value words are `GP.A`, `GP.X`, `GP.Y` and `GP.C` — the registers after `GP.CALL`, and now the
whole list of them. They are keywords rather than variables because nothing in the runtime can write
a BASIC variable by name, so a command that returns a value has to
hand it back through a keyword. X16's own `ST`, `MX` and `MY` exist for the same reason.

The full keyword list lives in `GPC-BASIC/GPB.INC.BL`, and the byte values mirror `getGP()` in
`source/common-scripts/c64tokens.py`.

---

## 3. The modules

Each table is **in** (set before the `GOSUB`), **out** (read after it), and **internal** (do not
read, do not write, do not rely on).

### `THEME.INC.BL`

| | |
|---|---|
| in | `THEME.ID` — 0 x16, 1 dark, 2 light, 3 gray, 4 custom, read by `THEME.LOAD`<br>`THEME.ATTR` — a packed attribute, for `THEME.SET` and `THEME.HI` |
| out | `THEME.CLR(role)` — the colour array, `DIM`med to `THEME.SLOTS`<br>`THEME.INV` — the inverse attribute, from `THEME.HI` |
| internal | `THEME.READY` |
| constants | `THEME.PAGE` `THEME.TEXT` `THEME.TITLE` `THEME.BORDER` `THEME.HILITE` `THEME.DIMMED` `THEME.WARN` `THEME.SLOTS` `THEME.COUNT` |

`THEME.CLR` is the array this module `DIM`s. Do not `DIM` it yourself — the module owns it, and
`DIM`ming an array GPC has already dimensioned is an error.

### `APPSYS.INC.BL`

| | |
|---|---|
| in | `APPSYS.FILE$` `APPSYS.BANK` `APPSYS.X` `APPSYS.Y` `APPSYS.W` `APPSYS.H` `APPSYS.DEV` — the panel routines |
| out | `APPSYS.MODE` `APPSYS.COLS` `APPSYS.ROWS` `APPSYS.COLOUR` — set by `APPSYS.STARTUP` |
| internal | `APPSYS.LAST` |
| constants | `APPSYS.SCRMODE` `APPSYS.COLREG` `APPSYS.WINDOW` `APPSYS.HEADER` |

Lay the screen out from `APPSYS.COLS` and `APPSYS.ROWS`. Do not assume 80x60 —
the X16 boots there but `SCREEN 0` is 40×30, and someone who prefers larger text is running one.

### `STRINGS.INC.BL`

| | |
|---|---|
| in | `STR.STR$` — the string, in and out<br>`STR.WIDTH` — field width, the pad routines<br>`STR.DELIM$` `STR.MAX` — `SPLIT` (`MAX` 0 means 10)<br>`STR.FIND$` `STR.REPL$` — `REPLACE`<br>`STR.PET` — a PETSCII code, `PET2SCR` |
| out | `STR.STR$` — padded, or replaced, in place<br>`STR.N` — how many fields `SPLIT` found, always ≥ 1<br>`STR.FIELD$(1..N)` — the fields themselves<br>`STR.SCR` — the screen code from `PET2SCR` |
| internal | `STR.GAP` `STR.HALF` `STR.REST$` `STR.AT` `STR.LIM` `STR.OUT$` |

`STR.FIELD$` is the one array the library does not `DIM`. Left alone, GPC's implicit `DIM` gives
0..10. For more, `DIM` it before the first call and set
`STR.MAX` to match — `DIM`ming an array GPC has already auto-dimensioned is an error, so it is
one or the other. This is the opposite of `THEME.CLR`, which the module owns outright; the two are
worth keeping straight.

### `LINEINPUT.INC.BL`

| | |
|---|---|
| in | `LINEINPUT.X` `LINEINPUT.Y` — top left of the field<br>`LINEINPUT.LEN` — how many characters fit<br>`LINEINPUT.ATTR` — packed attribute<br>`LINEINPUT.TEXT$` — the starting value<br>`LINEINPUT.MASK` — non-zero shows asterisks<br>`LINEINPUT.LABEL$` — `LINEINPUT.ASK` only |
| out | `LINEINPUT.TEXT$` — what was typed<br>`LINEINPUT.KEY` — the key that ended it |
| internal | `LINEINPUT.SHOW$` `LINEINPUT.WAS$` `LINEINPUT.K$` `LINEINPUT.CELL$` `LINEINPUT.CODE` `LINEINPUT.CX` `LINEINPUT.CA` `LINEINPUT.INV` `LINEINPUT.LIT` `LINEINPUT.TICK` `LINEINPUT.DONE` `LINEINPUT.FILLED` `LINEINPUT.HOME` `LINEINPUT.BAR` |
| constants | `LINEINPUT.RETURN` `LINEINPUT.DELETE` `LINEINPUT.ESCAPE` `LINEINPUT.STOP` `LINEINPUT.DOWN` `LINEINPUT.UP` `LINEINPUT.TAB` `LINEINPUT.SPACE` `LINEINPUT.STAR` `LINEINPUT.BLINK` |

`LINEINPUT.SHOW$` is listed internal but is the one exception worth knowing: it holds what the field
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

`BMX.STASH` is the one variable here a caller may want to set, and it has to be set before the
first
`BMX.OPEN` — `BMX.INIT` runs then, and fills in the default only if you have not. That is why `-1`
rather than `0` switches the stash off: `0` already means "never set". `BMX.KEPT` is the once-per-run
guard that makes a slideshow restore the *machine's* palette rather than the previous picture's.

### `FILEIO.INC.BL`

Needs a `#SYMFILE` — `FILE.TOPET` is a `GP.ASM` blob.

| | |
|---|---|
| in | `FILE.NAME$` — the file every routine acts on<br>`FILE.NEW$` — the second name, `RENAME` and `COPY`<br>`FILE.DEVICE` — the drive; 0 means 8<br>`FILE.ISO` — non-zero converts names to PETSCII on the way out<br>`FILE.N` — rows to write, `SAVEARRAY`<br>`FILE.MAX` — rows that will fit, `LOADARRAY`; 0 means 10<br>`FILE.LINE$()` — the rows; **the caller owns the `DIM`** |
| out | `FILE.ERR` `FILE.MSG$` `FILE.TRK` `FILE.SEC` — the command channel<br>`FILE.OK` — `FILE.EXISTS`<br>`FILE.N` — rows read, `LOADARRAY`<br>`FILE.PATH$` — `FILE.CURDIR` |
| internal | `FILE.CMDSTR$` `FILE.OUT$` `FILE.RAW$` `FILE.ROW$` `FILE.ST` `FILE.KEEP` `FILE.I` `FILE.PETP%` |
| constants | `FILE.OKMAX` `FILE.NOTFOUND` `FILE.EXISTSERR` `FILE.PROTECTED` `FILE.CHAN` |

**This module is the missing `DS` and `DS$`.** `FILE.ERR` is `DS` and `FILE.MSG$` is `DS$`. `ST` is
*not* a disk status — it is the KERNAL's serial bus status and cannot report `FILE NOT FOUND`.

`FILE.N` is both an input and an output, the way `MENUVERT.SEL` is. `FILE.LINE$()` is the caller's
`DIM`, like `MENUVERT.ITEM$` and unlike `THEME.CLR`.

### `FILEDIR.INC.BL`

Needs `FILEIO.INC.BL`, and a `#SYMFILE` — it is two `GP.ASM` blobs.

| | |
|---|---|
| in | `FILE.DIR.BANK` — the bank to read into, or 0 for low RAM<br>`FILE.DIR.PTR` `FILE.DIR.CAP` — the low-RAM buffer, when `BANK` is 0<br>`FILE.DIR.PAT$` — a name pattern, or empty<br>`FILE.DIR.ONLY` — `FILE.DIR.ALL`, `.FILES` or `.DIRS` |
| out | `FILE.DIR.GOT` — bytes read<br>`FILE.DIR.FULL` — the buffer filled before the listing ended<br>`FILE.DIR.MORE` — 1 while `NEXT` produced an entry<br>`FILE.NAME$` `FILE.BLOCKS` `FILE.TYPE$` — the entry itself |
| internal | `FILE.DIR.AT` `FILE.DIR.ASK$` `FILE.DIR.ADDR%` `FILE.DIR.ROOM%` `FILE.DIR.OFF%` `FILE.DIR.BYTES%` `FILE.DIR.CNT%` `FILE.DIR.BLK%` `FILE.DIR.OK%` `FILE.DIR.SLOW%` `FILE.DIR.LFN%` `FILE.DIR.NAMEA%` `FILE.DIR.TYPEA%` |
| constants | `FILE.DIR.ALL` `FILE.DIR.FILES` `FILE.DIR.DIRS` `FILE.DIR.NAMEMAX` `FILE.DIR.BANKROOM` `FILE.DIR.BANKBASE` |

`FILE.DIR.INIT` must run once before anything else: it sizes `FILE.NAME$` and `FILE.TYPE$` for the
assembly to write into, and creates every `{VAR}` slot. **Do not assign `FILE.NAME$` or
`FILE.TYPE$` afterwards** — an assignment reallocates and the block the assembly holds goes stale.

`FILE.NAME$` is shared with `FILEIO` on purpose: the name a picker chose is the name `FILE.EXISTS`
and `FILE.DELETE` want.

### `MENUVERT.INC.BL`

| | |
|---|---|
| in | `MENUVERT.X` `MENUVERT.Y` — top left of the first row<br>`MENUVERT.WIDTH` — cells wide, which is the width of the highlight<br>`MENUVERT.COUNT` — how many rows<br>`MENUVERT.ITEM$()` — the rows, 1..COUNT; **the caller owns the `DIM`**<br>`MENUVERT.ATTR` — packed attribute<br>`MENUVERT.HIATTR` — the highlighted row; 0 inverts `MENUVERT.ATTR`<br>`MENUVERT.HOT$` — one hotkey character a row<br>`MENUVERT.HOTATTR` — tint for the hotkey letter; 0 is off<br>`MENUVERT.FLAGS` — added together<br>`MENUVERT.SEL` — the row to start on |
| out | `MENUVERT.SEL` — 1..COUNT, or 0 if cancelled<br>`MENUVERT.KEY` — the key that ended it |
| internal | `MENUVERT.SCAN` `MENUVERT.EACH` `MENUVERT.DONE` `MENUVERT.CODE` `MENUVERT.INCHAR$` `MENUVERT.PREVSEL` `MENUVERT.HIGHLIGHT` `MENUVERT.DRAWROW` `MENUVERT.DRAWATTR` `MENUVERT.DRAWTEXT$` `MENUVERT.DRAWY` `MENUVERT.HOTCODE` `MENUVERT.HOTLAST` `MENUVERT.WANTCODE` `MENUVERT.HOTAT` `MENUVERT.HOTWANT` `MENUVERT.HOTHERE` `MENUVERT.HOTSCAN` `MENUVERT.PADNOW` `MENUVERT.PADNEW` `MENUVERT.PADHELD` `MENUVERT.PADRAW` |
| constants | `MENUVERT.MUSTSEL` `MENUVERT.KEEPMARK` `MENUVERT.NOWRAP` `MENUVERT.GAMEPAD` `MENUVERT.UP` `MENUVERT.DOWN` `MENUVERT.ENTER` `MENUVERT.ESCAPE` `MENUVERT.STOP` `MENUVERT.SPACE` `MENUVERT.PORT` `MENUVERT.PAD.UP` `MENUVERT.PAD.DOWN` `MENUVERT.PAD.B` `MENUVERT.PAD.START` |

`MENUVERT.SEL` is both an input and an output: the row to start on going in, and the row
chosen coming out, so a menu reopened without clearing it reopens where it was. That is usually what
you want; set it to 0 when it is not.

`MENUVERT.DRAWROW`, `MENUVERT.DRAWATTR` and `MENUVERT.DRAWTEXT$` are listed internal but are the
documented arguments to `MENUVERT.ROW`, which is public: they are internal to `MENUVERT.RUN`, not to
you. `MENUVERT.HOTFIND` reads the first two and answers in `MENUVERT.HOTAT`.

---

## 4. Labels are global too

Every `NAME:` in every module is a jump target in one flat space, including the ones you were never
meant to call. `BMX.STREAM.MORE`, `LINEINPUT.REDRAW`, `THEME.LOAD.DARK` and most of `MENUVERT.*` are
internal, and a `GOSUB` to one will do something, just not something useful.

`MENUVERT` is the module with the most of them, because driving a menu is mostly branching:
**`MENUVERT.RUN`, `MENUVERT.DRAW`, `MENUVERT.ROW` and `MENUVERT.HOTFIND` are the four you may call.**
`MENUVERT.WAIT`, `.KEYED`, `.SETTLE`, `.WRAPTOP`, `.WRAPBOT`, `.CANCEL`, `.HOTKEY`, `.PADKEY`,
`.PADREAD` and the three `FOLD` helpers are not.

`FILE.*` has a great many, because most of the module is one routine feeding another: **the
callable names are `FILE.STATUS`, `EXISTS`, `DELETE`, `RENAME`, `COPY`, `MKDIR`, `CHDIR`, `UP`,
`GETPATH`, `SAVEARRAY` and `LOADARRAY`, plus `FILE.DIR.INIT`, `.OPEN` and `.NEXT`.**
`FILE.CMD`, `.DONE`, `.PETNAME`, `.PETNEW`, `.TOPET`, `.PATHWALK`, `.WRITEROWS`, `.READROWS`,
`.ROWREAL`, `.ROWDROP`, `.KEEPROW`, `FILE.DIR.WHERE`, `.LOWRAM`, `.ASKFOR`, `.SUCK`,
`.SKIPDISK`, `.FILL` and `.STEP` are not. `FILE.DIR.FILL` and `FILE.DIR.STEP` are the two
assembly blobs and enter with no arguments set up at all.

`STRINGS` has two of its own, both loop continuations rather than entry points:
**`STR.SPLIT.NEXT`** and **`STR.REPLACE.NEXT`**. Enter either one directly and you resume a
loop whose accumulators were never initialised. The callable names are `STR.PADR`, `PADL`,
`PADC`, `SPLIT`, `REPLACE` and `PET2SCR`.

Each module also has a skip label it jumps over itself with — `THEME.SKIP`, `APPSYS.SKIP`,
`STR.SKIP`, `BMX.MODULE.END`, `LINEINPUT.MODULE.END`, `MENUVERT.MODULE.END`. Those exist so an
include can sit anywhere in the file, the top included. **Do not branch to one.**

BASLOAD refuses a name used as both a label and a variable (`BASLOAD.MD:319`). `BMX.SKIP` is the
byte-skip counter, so the module's skip label had to
be `BMX.MODULE.END` — a name is either a label or a variable, never both.

---

## 5. Two more naming rules that are not about collisions

**`#DEFINE` takes an INT16** (`BASLOAD.MD:313`). A constant above 65535 is
`ERROR: INVALID PARAMETER`, not a warning — which is why `BMX.PALBASE` (VRAM `$1FA00`, 129536) is an
ordinary variable and not a `#DEFINE`. Every VRAM address past `$FFFF` has the same problem.

**A dotted name whose tail is a reserved word is fine.** `MENUVERT.COUNT`, `THEME.CLR`,
`LINEINPUT.LEN` and `LINEINPUT.RETURN` all contain keywords and all work, because BASLOAD matches the whole identifier. An
*undotted* one does not: `POS`, `MB`, `ST`, `LEN` and `CHAR` cannot be variables at all. This is the
main reason the library is dotted throughout.

One rule applies only outside BASL: BASLOAD gives 64 significant characters, the built-in BASIC
gives two. Write the same code as a hand-typed `.bas` for the PC-side converter and
`THEME.CLR` and `THEME.COUNT` become the same variable. That is a silent wrong answer — it cost two
test cycles during tier 6, both times looking exactly like a compiler bug. Inside BASL you are safe;
in a raw `.bas`, give every variable a distinct first two characters.
