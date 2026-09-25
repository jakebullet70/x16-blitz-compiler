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
| `STR.USING.` | `STRUSING.INC.BL` | a number to a template, kept apart from the rest of `STR.` |
| `THEME.` | `THEME.INC.BL` | colour roles |
| `APPSYS.` | `APPSYS.INC.BL` | screen save/restore, panels to disk |
| `LINEINPUT.` | `LINEINPUT.INC.BL` | entry fields |
| `KB.` | `KB.INC.BL` | the keyboard drain |
| `MENU.` | `MENU.INC.BL` | menus: the row store, the popup and the bar. `MENUPULL.INC.BL`'s variables too |
| `MENUTO.` | `MENU.INC.BL` `MENUPULL.INC.BL` | the runners, called with `GP.FN` |
| `MENUPULL.` | `MENUPULL.INC.BL` | a dropdown under a bar item: labels and one constant |
| `GUI.` | `GUI.INC.BL` | the box the dialogs sit in, and the form and controls inside it |
| `GUI.LISTBOX.` | `GUI-DIALOGS.INC.BL` | the listbox dialog’s answer, kept apart from the rest of `GUI.` |
| `DLG.` | `GUI-DIALOGS.INC.BL` | the dialog verbs: their arguments, and their internals |
| `STASH.` | `STASH.INC.BL` | a text rectangle into a RAM bank, and back |
| `STASH.FILE.` | `STASHFILE.INC.BL` | the same rectangle through a file, kept apart from the rest of `STASH.` |
| `SORT.` | `SORT.INC.BL` | shell sort a string array in place |
| `STRCASE.` | `STRCASE.INC.BL` | case, rewriting a string in place |
| `BMX.` | `BMX.INC.BL` | BMX bitmap loading |
| `BMXK.` | `BMX.INC.BL` | its KERNAL/VERA constants, kept apart from its variables |
| `FILE.` | `FILEIO.INC.BL` | the drive: status, exists, delete, rename, directories |
| `FILE.DIR.` | `FILEDIR.INC.BL` | reading a directory, kept apart from the rest of `FILE.` |
| `SV.` | `STASHVRAM.INC.BL` | the VRAM store. `SVGC.` is `STASHVRAMGC.INC.BL`'s one constant |
| `KV.` | `KV.INC.BL` | keys and values in one RAM bank |
| `MATH.` | `MATH.INC.BL` | the smaller and the larger of two numbers |
| `MEM.` | `MEM.INC.BL` | a block copied, a block filled, and the two KERNAL constants |

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

The full keyword list lives in `GPC-BASIC/GPB.INC.BL`.

---

## 3. The modules

Each table is **in** (set before the `GOSUB`), **out** (read after it), and **internal** (do not
read, do not write, do not rely on).

### `THEME.INC.BL` — named colour roles

Routines, arguments and examples: §4.1.

| | |
|---|---|
| in | `THEME.ID%` — 0 x16, 1 dark, 2 light, 3 gray, 4 custom, read by `THEME.SELECT`<br>`THEME.ATTR%` — a packed attribute, for `THEME.SET` and `THEME.HI` |
| out | `THEME.CLR(role)` — the colour array, `DIM`med to `THEME.SLOTS - 1`<br>`THEME.INV%` — the inverse attribute, from `THEME.HI` |
| internal | `THEME.READY%` `THEME.FIRST%` |
| constants | `THEME.PAGE` `THEME.TEXT` `THEME.TITLE` `THEME.BORDER` `THEME.HILITE` `THEME.DIMMED` `THEME.WARN` `THEME.FOCUS` `THEME.BAR` `THEME.SHADOW` `THEME.SLOTS` `THEME.COUNT` |

To use it: set `THEME.ID%`, `GOSUB THEME.SELECT`, then index `THEME.CLR()` with a role wherever a
drawing routine wants an attribute. §4.1 is the module's own entry, with the five themes and the
other four routines.

```basic
THEME.ID% = 1 : GOSUB THEME.SELECT
GP.PRINTAT 2, 2, "READY", THEME.CLR(THEME.TEXT)
```

`THEME.CLR` is the array this module `DIM`s. Do not `DIM` it yourself — the module owns it, and
`DIM`ming an array GPC has already dimensioned is an error.

`THEME.FOCUS` is the eighth role: the attribute a focused control wears while `GUI.FORM` has the
keyboard. `THEME.BAR` and `THEME.SHADOW` are the ninth and tenth, so `THEME.SLOTS` is 10, and
`THEME.COUNT` stays 5 — the first is how many roles there are, the second how many themes.

### `APPSYS.INC.BL` — start politely, leave it as you found it

Routines, arguments and examples: §4.3.

| | |
|---|---|
| in | `APPSYS.FILE$` `APPSYS.BANK` `APPSYS.X` `APPSYS.Y` `APPSYS.W` `APPSYS.H` `APPSYS.DEV` — the panel routines |
| out | `APPSYS.MODE` `APPSYS.COLS` `APPSYS.ROWS` `APPSYS.COLOUR` — set by `APPSYS.STARTUP`<br>`APPSYS.IS.EMULATOR` — set by `APPSYS.ISEMU` |
| internal | `APPSYS.LAST` |
| constants | `APPSYS.SCRMODE` `APPSYS.COLREG` `APPSYS.SETCHR` `APPSYS.CHRREG` `APPSYS.EMUSIG` |

Lay the screen out from `APPSYS.COLS` and `APPSYS.ROWS`. Do not assume 80x60 —
the X16 boots there but `SCREEN 0` is 40×30, and someone who prefers larger text is running one.

### `STRINGS.INC.BL` — string helpers

Routines, arguments and examples: §4.2.

| | |
|---|---|
| in | `STR.STR$` — the string, in and out<br>`STR.WIDTH` — field width, the pad routines<br>`STR.DELIM$` `STR.MAX` — `SPLIT` (`MAX` 0 means 10)<br>`STR.FIND$` `STR.REPL$` — `REPLACE`<br>`STR.PET` — a PETSCII code, `PET2SCR`<br>`STR.AT` `STR.CUT` `STR.SUB$` — `SPLICE`, and `AT`/`CUT` are CLAMPED in place<br>`STR.PTR` — `GP.STRPTR` of the string, the three trims |
| out | `STR.STR$` — padded, or replaced, in place<br>`STR.N` — how many fields `SPLIT` found, always ≥ 1<br>`STR.FIELD$(1..N)` — the fields themselves<br>`STR.SCR` — the screen code from `PET2SCR`<br>`STR.STR$` — spliced, when it was `SPLICE` that was called |
| internal | `STR.GAP` `STR.HALF` `STR.REST$` `STR.AT` `STR.LIM` `STR.OUT$`<br>`STR.ADDR%` `STR.OP%` `STR.KEEP%` — the `{VAR}` slots the trim blob reads |

`STR.FIELD$` is the one array the library does not `DIM`. Left alone, GPC's implicit `DIM` gives
0..10. For more, `DIM` it before the first call and set
`STR.MAX` to match — `DIM`ming an array GPC has already auto-dimensioned is an error, so it is
one or the other. This is the opposite of `THEME.CLR`, which the module owns outright; the two are
worth keeping straight.

### `STRUSING.INC.BL` — a number to a template

Routines, arguments and examples: §4.10.

| | |
|---|---|
| in | `STR.USING.NUM` — the value, both routines<br>`STR.USING.MASK$` — the template, `STR.USING`<br>`STR.USING.DP` — decimal places, `STR.USING.FIX` |
| out | `STR.USING.STR$` — the result: a field from `STR.USING`, digits from `STR.USING.FIX`<br>`STR.USING.OVR` — −1 when the value scaled past 1e9 and the digits are unusable<br>`STR.USING.SGN` — −1 when the ROUNDED value is negative |
| internal | `STR.USING.INT$` `STR.USING.FRC$` `STR.USING.SIGN$` `STR.USING.OUT$` `STR.USING.C$`<br>`STR.USING.IW` `STR.USING.ZW` `STR.USING.Z` `STR.USING.W` `STR.USING.F`<br>`STR.USING.GRP` `STR.USING.PT` `STR.USING.I` `STR.USING.V` |

**`STR.USING.DP` is an output of `STR.USING` and an input to `STR.USING.FIX`.** The mask carries
the decimal count, so `STR.USING` overwrites whatever was there. A program alternating the two
routines must set `STR.USING.DP` again before every `FIX`.

`STR.USING.INT$` and `STR.USING.FRC$` survive a call and are the two halves of the digits, without
sign, point or field. They are listed internal because their width is the routine's business, not
the caller's — read `STR.USING.STR$`.

The prefix is `STR.USING.`, a sub-prefix of `STRINGS.INC.BL`'s `STR.`, on the same footing as
`FILE.DIR.` inside `FILE.`. Nothing here is written by `STRINGS.INC.BL` and nothing there is
written by this module, so either can be included alone.

### `KB.INC.BL` — the keyboard buffer, emptied

Routines, arguments and examples: §4.14.

| | |
|---|---|
| out | — |
| internal | `KB.K$` |

One routine, `KB.CLEARKB`, and one variable it drains into. Nothing else is in the prefix.

### `LINEINPUT.INC.BL` — a positioned entry field

Routines, arguments and examples: §4.4.

| | |
|---|---|
| in | `LINEINPUT.X` `LINEINPUT.Y` — top left of the field<br>`LINEINPUT.LEN` — how many characters fit<br>`LINEINPUT.ATTR` — packed attribute<br>`LINEINPUT.TEXT$` — the starting value<br>`LINEINPUT.MASK` — non-zero shows asterisks<br>`LINEINPUT.ALLOW$` — the only characters accepted<br>`LINEINPUT.DENY$` — characters refused<br>`LINEINPUT.LABEL$` — `LINEINPUT.ASK` only |
| out | `LINEINPUT.TEXT$` — what was typed<br>`LINEINPUT.KEY` — the key that ended it |
| internal | `LINEINPUT.SHOW$` `LINEINPUT.WAS$` `LINEINPUT.K$` `LINEINPUT.CELL$` `LINEINPUT.CODE` `LINEINPUT.CX` `LINEINPUT.CA` `LINEINPUT.INV` `LINEINPUT.LIT` `LINEINPUT.TICK` `LINEINPUT.DONE` `LINEINPUT.FILLED` `LINEINPUT.HOME` `LINEINPUT.BAR` |
| constants | `LINEINPUT.RETURN` `LINEINPUT.DELETE` `LINEINPUT.ESCAPE` `LINEINPUT.STOP` `LINEINPUT.DOWN` `LINEINPUT.UP` `LINEINPUT.TAB` `LINEINPUT.SPACE` `LINEINPUT.STAR` `LINEINPUT.BLINK` |

`LINEINPUT.SHOW$` is listed internal but is the one exception worth knowing: it holds what the field
*displayed*, which is what you want if you are repainting a masked field yourself. `FORM.EXP.BL`
uses it for exactly that.

### `BMX.INC.BL` — a BMX bitmap into VERA

Routines, arguments and examples: §4.5.

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

### `FILEIO.INC.BL` — the drive: status, files, directories

Routines, arguments and examples: §4.15.

Needs a `#SYMFILE` — `FILE.TOPET` is a `GP.ASM` blob.

| | |
|---|---|
| in | `FILE.NAME$` — the file every routine acts on<br>`FILE.NEW$` — the second name, `RENAME` and `COPY`<br>`FILE.DEVICE` — the drive; 0 means 8<br>`FILE.ISO` — non-zero converts names to PETSCII on the way out<br>`FILE.ROWS` — rows to write, `SAVEARRAY`<br>`FILE.MAX.ROWS` — rows that will fit, `LOADARRAY`; 0 means 10<br>`FILE.LINE$()` — the rows; **the caller owns the `DIM`** |
| out | `FILE.ERR` `FILE.MSG$` `FILE.TRK` `FILE.SEC` — the command channel<br>`FILE.OK` — `FILE.EXISTS`<br>`FILE.ROWS` — rows read, `LOADARRAY`<br>`FILE.PATH$` — `FILE.CURDIR` |
| internal | `FILE.CMDSTR$` `FILE.OUT$` `FILE.RAW$` `FILE.ROW$` `FILE.ST` `FILE.KEEP` `FILE.I` `FILE.PETP%` |
| constants | `FILE.OKMAX` `FILE.NOTFOUND` `FILE.EXISTSERR` `FILE.PROTECTED` `FILE.CHAN` |

**This module is the missing `DS` and `DS$`.** `FILE.ERR` is `DS` and `FILE.MSG$` is `DS$`. `ST` is
*not* a disk status — it is the KERNAL's serial bus status and cannot report `FILE NOT FOUND`.

`FILE.ROWS` is both an input and an output, the way `KV.SLOT` is. `FILE.LINE$()` is the caller's
`DIM`, like `GUI.LIST.ITEM$` and unlike `THEME.CLR`.

### `FILEDIR.INC.BL` — a directory, into a bank or into low RAM

Routines, arguments and examples: §4.16.

Needs `FILEIO.INC.BL`, and a `#SYMFILE` — it is two `GP.ASM` blobs.

**It executes no `BANK` statement**, which is what lets it live in a `GP.BANKED` region: the two
blobs take the data bank at entry and put the caller's back at every exit, so no BASIC line here
ever runs with a foreign bank selected. Both blobs write `$00`, so both are `GP.ASM LOW` and run
from low memory when the module is in a region. `FILE.DIR.BNK%` carries the bank number to the assembly —
`{FILE.DIR.BANK}` would read a float's mantissa, and `FILE.DIR.WAS%` is the blobs' save slot.

| | |
|---|---|
| in | `FILE.DIR.BANK` — the bank to read into, or 0 for low RAM<br>`FILE.DIR.PTR` `FILE.DIR.CAP` — the low-RAM buffer, when `BANK` is 0<br>`FILE.DIR.PATTERN$` — a name pattern, or empty<br>`FILE.DIR.ONLY` — `FILE.DIR.ALL`, `.FILES` or `.DIRS` |
| out | `FILE.DIR.GOT` — bytes read<br>`FILE.DIR.FULL` — the buffer filled before the listing ended<br>`FILE.DIR.MORE` — −1 while `NEXT` produced an entry<br>`FILE.NAME$` `FILE.BLOCKS` `FILE.TYPE$` — the entry itself |
| internal | `FILE.DIR.AT` `FILE.DIR.ASK$` `FILE.DIR.ADDR%` `FILE.DIR.ROOM%` `FILE.DIR.OFF%` `FILE.DIR.BYTES%` `FILE.DIR.CNT%` `FILE.DIR.BLK%` `FILE.DIR.OK%` `FILE.DIR.SLOW%` `FILE.DIR.LFN%` `FILE.DIR.NAMEA%` `FILE.DIR.TYPEA%` `FILE.DIR.WAS%` `FILE.DIR.BNK%` |
| constants | `FILE.DIR.ALL` `FILE.DIR.FILES` `FILE.DIR.DIRS` `FILE.DIR.NAMEMAX` `FILE.DIR.BANKROOM` `FILE.DIR.BANKBASE` |

`FILE.DIR.INIT` must run once before anything else: it sizes `FILE.NAME$` and `FILE.TYPE$` for the
assembly to write into, and creates every `{VAR}` slot. **Do not assign `FILE.NAME$` or
`FILE.TYPE$` afterwards** — an assignment reallocates and the block the assembly holds goes stale.

`FILE.NAME$` is shared with `FILEIO` on purpose: the name a picker chose is the name `FILE.EXISTS`
and `FILE.DELETE` want.

### `STASHVRAM.INC.BL` — rectangles and blobs, kept in VRAM

Routines, arguments and examples: §4.18.

Needs `GPB.INC.BL`, and **no `#SYMFILE`** — there is no `GP.ASM` in it. The cells never leave
VRAM: one data port reads, the other writes, and `memory_copy` moves between them without
stepping either.

**It executes no `BANK`**, so it can live in a `GP.BANKED` region — measured, `scratch/stashvram/SVB.BASL`.
That is the difference from `STASH.INC.BL`, which cannot.

| | |
|---|---|
| in | `SV.BASE` `SV.TOP` — the VRAM window in bytes. Default `$04000`/`$1AFFF`<br>`SV.MAX` — how many handles. **The caller `DIM`s `SV.PAGE%` and `SV.PAGES%` to it**<br>`SV.X` `SV.Y` `SV.W` `SV.H` — the rectangle, for `SV.SAVE`<br>`SV.MOVE` — non-zero restores at `SV.X` `SV.Y` rather than where it came from<br>`SV.ADDR` `SV.LEN` — low RAM address and count, for `SV.PUT` and `SV.GET`<br>`SV.HND` — the handle, for `RESTORE`, `GET` and `FREE` |
| out | `SV.HND` — 1..`SV.MAX`, or 0 if it did not fit<br>`SV.OK` — −1 done, 0 refused<br>`SV.ERROR$` — why, when something is refused<br>`SV.MOVED` — `SV.COMPACT` only: how many blocks moved |
| arrays | `SV.PAGE%()` `SV.PAGES%()` — the handle table, `DIM`med by the caller |
| internal | `SV.READY` `SV.NEXT` `SV.BASEPG` `SV.TOPPG` `SV.I` `SV.PG` `SV.NP` `SV.N` `SV.BYTES` `SV.MAPW` `SV.MAPBASE` `SV.STRIDE` `SV.ROW` `SV.CELL` `SV.SRC` `SV.DST` `SV.VA` `SV.ADR` `SV.BNK` `SV.REST` `SV.MID` `SV.LO` `SV.MODE` `SV.RX` `SV.RY`<br>`SV.COMPACT` adds `SV.PICK` `SV.BEST` `SV.J` `SV.TO` `SV.GCS` `SV.GCD` `SV.LEFT` `SV.CH` |
| constants | `SV.VLO` `SV.VMID` `SV.VHI` `SV.DATA` `SV.VCTRL` `SV.LCONFIG` `SV.LMAPBASE` `SV.PORTLO` `SV.PORTLO.B` `SV.PORTHI` `SV.MEMCOPY` `SV.UP` `SV.HEADER` `SVGC.CHUNK` |

`SV.INIT` must run once before anything else, and the two arrays must be `DIM`med before it.

**Blocks are whole 256-byte pages**, which is what lets a handle's address live in an ordinary
`%`: a page number reaches 511 where a VRAM address is 17 bits and would not.

**WARNING: `BMX.STASH` defaults to `$13000`, inside the default window.** A program using both
must move one of them. There is one allocator and no collision check.

### `KV.INC.BL` — keys and values in one RAM bank

Routines, arguments and examples: §4.20.

Plain BASL: no `GP.*` keyword and no `GP.ASM`, so it needs neither `GPB.INC.BL` nor a `#SYMFILE`.

| | |
|---|---|
| in | `KV.KEY$` — the key, for `FIND` `GET` `PUT` `DEL`<br>`KV.VALUE$` — the value, for `PUT`<br>`KV.SLOT` — the slot, for `AT`<br>`KV.FNAME$` — the file, for `SAVE` and `LOAD`<br>`KV.HOMEBANK` — the bank every routine selects on its way out. The first `KV.INIT` sets 1 |
| out | `KV.OK` — −1 done, 0 refused<br>`KV.SLOT` — the slot `FIND`, `GET` and `PUT` found, 0 if none<br>`KV.VALUE$` — `GET` and `AT`<br>`KV.KEY$` — `AT`, without its padding |
| internal | `KV.READY` `KV.CODE%()` `KV.HIT` `KV.ADDR` `KV.INDEX` `KV.PADDED$` `KV.LENGTH` `KV.BYTE` `KV.MAGIC$` `KV.ERR` `KV.MSG$` `KV.TRACK` `KV.SECTOR` |
| constants | `KV.BANK` `KV.BASE` `KV.TOP` `KV.SLOTS` `KV.SIZE` `KV.MAXLEN` `KV.VERSION` `KV.DEFS` |

`KV.SLOT` is both an input and an output, the way `FILE.ROWS` is. `KV.AT` writes `KV.KEY$`, so a loop
over the slots keeps its own key in a variable of its own.

### `MENU.INC.BL` — menus built a row at a time

Routines, arguments and examples: §4.6.

| | |
|---|---|
| verbs | `MENU.BEGIN` `MENU.ITEM` `MENU.ITEMX` `MENU.SELECTED` `MENU.DRAWBAR`, called with `GP.SUB`<br>`MENUTO.VERT` `MENUTO.BAR`, called with `GP.FN` |
| in | `MENU.ATTR` — the rows, packed attribute<br>`MENU.HIATTR` — the highlighted row; 0 inverts `MENU.ATTR`<br>`MENU.HOTATTR` — the hot key letter; 0 leaves it untinted<br>`MENU.DISATTR` — a disabled row; 0 is `MENU.ATTR`<br>`MENU.SEPATTR` — separators and the frame; 0 is `MENU.ATTR`<br>`MENU.SEPCHR` — the separator glyph; 0 is `MENU.LINE`<br>`MENU.FLAGS` — the popup's flags<br>`MENU.BARFLAGS` — the bar's flags<br>`MENU.GAP` — cells between bar items<br>`MENU.HINTX` `MENU.HINTY` `MENU.HINTW` `MENU.HINTATTR` — the hint field; `MENU.HINTW` 0 is off<br>`MENU.MARKED` — the bar item `MENU.DRAWBAR` lights |
| out | `MENU.EXITKEY` — the key that ended the run<br>`MENU.BARNUM` — the bar's row count<br>`MENU.SELX` `MENU.SELW` — the chosen bar item's column and width<br>`MENU.MARKED` — the bar item left lit<br>`MENU.OK` — 0 if bank `MENU.TEXTBANK` was already claimed |
| formals | `MENU.SLOT` `MENU.SEL` `MENU.ROWTEXT$` `MENU.ROWHINT$` `MENU.ROWON` `MENU.RUNROW` `MENU.RUNCOL` `MENU.STYLE` `MENU.CHOSEN` |
| arrays | `MENU.FLAG$()` `MENU.HOTKEY$()` `MENU.HOTCOL$()` — `DIM`med by the module on the first `MENU.BEGIN` |
| banked groups | `MENU.TEXTS` `MENU.HINTS`, in `MENU.INC.BANKED.BL` |
| internal | `MENU.ATCOL` `MENU.ATROW` `MENU.BARX` `MENU.BARY` `MENU.BASE` `MENU.BOXH` `MENU.BOXW` `MENU.CAP` `MENU.CODE` `MENU.COUNT` `MENU.CUR` `MENU.DONE` `MENU.DRAWN` `MENU.DRAWX` `MENU.DRAWY` `MENU.EACH` `MENU.EXITBIT` `MENU.FRAME` `MENU.GLYPH` `MENU.HAVE` `MENU.HILITE` `MENU.HINTAT` `MENU.HOTAT` `MENU.HOTCH$` `MENU.HOTHIT` `MENU.INKEY$` `MENU.LEFTW` `MENU.MOVE` `MENU.PADHELD` `MENU.PADNEW` `MENU.PADNOW` `MENU.PADRAW` `MENU.PAINT` `MENU.READY` `MENU.ROW` `MENU.ROWFLAG$` `MENU.ROWIS$` `MENU.ROWW` `MENU.RUNBASE` `MENU.RUNFLAGS` `MENU.RUNSLOT` `MENU.SCAN` `MENU.SHOW$` `MENU.SKIPS` `MENU.SPAN` `MENU.STEP` `MENU.TEXTW` `MENU.TINTAT` `MENU.USE` `MENU.WANT` `MENU.WAS` `MENU.WIDE` |
| constants | `MENU.TEXTBANK` `MENU.BAR` `MENU.POPUP` `MENU.BAR.MAX` `MENU.POPUP.MAX` `MENU.ON` `MENU.OFF`<br>`MENU.SOLID` `MENU.THIN` `MENU.ROUND` `MENU.THICK` `MENU.NOBOX`<br>`MENU.MUSTSEL` `MENU.KEEPMARK` `MENU.NOWRAP` `MENU.GAMEPAD` `MENU.DOWNEXIT` `MENU.UPEXIT` `MENU.KEYEXIT` `MENU.HINTMID`<br>`MENU.DOWN` `MENU.UP` `MENU.LEFT` `MENU.RIGHT` `MENU.ENTER` `MENU.ESC` `MENU.STOP` `MENU.LINE`<br>`MENU.PORT` `MENU.PAD.UP` `MENU.PAD.DOWN` `MENU.PAD.LEFT` `MENU.PAD.RIGHT` `MENU.PAD.B` `MENU.PAD.START` |

The formals are the verbs' arguments. `GP.DEFPROC` formals are ordinary shared variables (§3.11), so a formal holds the last value passed until the next call.

`GUI.INC.BL` sets `MENU.RUNSLOT`, reads `MENU.READY`, `MENU.COUNT` and `MENU.WIDE`, and calls
`MENU.MEASURE`. A program of your own should not.

### `MENUPULL.INC.BL` — a dropdown under a bar item

Routines, arguments and examples: §4.9. Its variables use the `MENU.` prefix; `MENUPULL.` is its
labels and one constant.

| | |
|---|---|
| verbs | `MENUTO.PULLDOWN`, called with `GP.FN` |
| in | `MENU.STASHBANK` — the bank the covered cells go to; 0 takes one from `BANKMGR` on the first call |
| out | `MENU.NEXTBAR` — the bar item LEFT or RIGHT walks to, or 0<br>`MENU.EXITKEY` `MENU.BARNUM` `MENU.SELX` `MENU.SELW` `MENU.MARKED`, as for `MENU.INC.BL` |
| formals | `MENU.PULLAT` `MENU.STYLE` `MENU.CHOSEN` |
| internal | `MENU.COLS` `MENU.EDGE` `MENU.LEFTOF` `MENU.RIGHTOF` `MENU.STASHED`, and `STASH.BANK` `STASH.SLOT` `STASH.MOVE` `STASH.X` `STASH.Y` `STASH.W` `STASH.H`, which it sets |
| constants | `MENUPULL.SCRMODE` |

### `GUI.INC.BL` — four dialogs, in a box that puts the screen back

Routines, arguments and examples: §4.11.

| | |
|---|---|
| in | `GUI.MSG$` `GUI.MSG2$` `GUI.MSG3$` — up to three message lines. `""` for none, and no gap left behind<br>`GUI.TITLE$` — a name in the top edge<br>`GUI.BANK` — a spare RAM bank for the covered cells. 0 does not save<br>`GUI.STYLE` — `GP.BOX` style 0..3<br>`GUI.PANEL.IN` `GUI.BORDER.IN` — attributes. 0 takes `THEME.TEXT` and `THEME.BORDER`<br>`GUI.GLYPH` — non-zero frames from `GUI.EDGE.H` `GUI.EDGE.V` `GUI.CORNER.TL` `.TR` `.BL` `.BR`<br>`GUI.PLACE` `GUI.X` `GUI.Y` `GUI.ROW.OFFSET` — where the box goes<br>`GUI.SHADOW` `GUI.SHADOW.ATTR` — the drop shadow<br>`GUI.BTN.ONE$` `GUI.BTN.TWO$` — the button labels, `&` marking the accelerator<br>`GUI.DEFAULT` — which button is the default. 2 is the second, anything else the first<br>`GUI.FLAGS` — `GUI.MENU`, over the popup slot of `MENU.INC.BL`<br>`GUI.LEN` `GUI.TEXT$` `GUI.MASK` — `GUI.INPUT`<br>`GUI.BODY.ROWS` `GUI.BODY.WIDTH` — `GUI.OPEN`, when you call it yourself |
| out | `GUI.KEY` — the key that ended it, whichever call<br>`GUI.ANSWER` — `GUI.YN`<br>`GUI.OK` — `GUI.INPUT`: -1 accepted, 0 cancelled<br>`GUI.TEXT$` — what was typed<br>`GUI.SEL` — the row chosen, or 0<br>`GUI.STASHED` — -1 if the covered cells were saved<br>`GUI.LEFT` `GUI.TOP` `GUI.WIDTH` `GUI.HEIGHT` — where the box went<br>`GUI.INNER.LEFT` `GUI.INNER.TOP` `GUI.INNER.WIDTH` — the usable area, from `GUI.OPEN`<br>`GUI.PANEL` `GUI.BORDER` — the attributes it settled on |
| internal | `GUI.ADD.W` `GUI.BOTTOM` `GUI.BOX.STYLE` `GUI.CLR.K$` `GUI.FIELD.LEFT` `GUI.GAP.ROWS` `GUI.GLYPH$` `GUI.HEAD.ROWS` `GUI.INDEX` `GUI.MOVE.BY` `GUI.MOVE.TRIES` `GUI.MOVE.WAS` `GUI.OKCANCEL` `GUI.PAINT.N` `GUI.PRESSED$` `GUI.RIGHT` `GUI.SAVE.W` `GUI.SAVE.H` `GUI.SCAN` `GUI.SCREEN.COLS` `GUI.SCREEN.ROWS` `GUI.SH.BW` `GUI.SH.W` `GUI.SH.H` `GUI.STEP.TYPE` `GUI.TITLE.LEFT` `GUI.WAS$`<br>the button row: `GUI.BTN.AMP` `.AT` `.ATTR` `.DEF` `.FOCUSED` `.HEAD$` `.HI` `.KEY` `.KEY.ONE` `.KEY.TWO` `.LC` `.MARK$` `.OF` `.RIGHT` `.TAIL$` `.TEXT$` `.TOTAL` `.UC` `.W.ONE` `.W.TWO` `.WIDE` `.X` `.Y`<br>the form: `GUI.CTRL.TYPE%` `.X%` `.Y%` `.W%` `.FLAGS%` `.KEY%` `GUI.CTRL.TEXT$` `GUI.CTRL.N` `GUI.FOCUS` `GUI.FORM.DIMMED` `.DONE` `.HIT` `.KEY` `.NAV`<br>the list control: `GUI.LIST.ATTR` `.COUNT` `.DIGITS` `.EACH` `.EDGE$` `.HI` `.I` `.MARKED` `.MARKP` `.MARKY` `.NOTE$` `.NOTE.LEFT` `.NOTEW` `.NUM$` `.ROW` `.ROWS` `.SEL` `.W` `.WAS` `.WAS.SCROLL` `.X` `.Y` |
| constants | `GUI.SCRMODE` `GUI.LINEBOX` `GUI.MAXCELLS` `GUI.PADX` `GUI.PADY` `GUI.ESCAPE` `GUI.STOP` `GUI.RETURN` `GUI.SPACE` `GUI.BTN.GAP` `GUI.FORM.MAX`<br>`GUI.CT.BUTTON` `GUI.CT.FIELD` `GUI.CT.LIST` — what a control is<br>`GUI.CF.DEFAULT` `GUI.CF.NOFOCUS` — what is true of it<br>`GUI.NAV.STAY` `.NEXT` `.PREV` `.PRESS` `.DEFAULT` `.CANCEL` — the six verdicts<br>`GUI.K.TAB` `GUI.K.SHTAB` `GUI.K.DOWN` `GUI.K.UP` `GUI.K.RIGHT` `GUI.K.LEFT` |

**`GUI.DEFAULT` and the focus are two different things.** The default button is the one RETURN
presses from anywhere and the one drawn `<<LIKE THIS>>`; the focus is where TAB has got to, and it
is drawn in `THEME.FOCUS`. `GUI.INPUT` opens with the default on OK and the focus in the field, so
neither is the other's shorthand.

**`GUI.BTN.DEF` is not `GUI.DEFAULT`.** It is internal — which button `GUI.BUTTON.ROW` is painting
the double brackets on as it draws — and setting it does nothing, because the row recomputes it
from `GUI.DEFAULT` every time it paints. The near-miss is worth knowing about; the rest of
`GUI.BTN.*` is scratch for one button's text, width and accelerator and is rewritten twice a row.

**`GUI.HINT$` is gone**, and it is the one interface the CUA work took away. The dimmed line naming
two keys became a real button row, and "the first Y and the first N in the line are lit" has nothing
to light when the row is two buttons. Set `GUI.BTN.ONE$` and `GUI.BTN.TWO$` instead.

**The typing dialog and its string swapped names.** It was `GUI.TEXT` returning `GUI.INPUT$`; it is
`GUI.INPUT` returning `GUI.TEXT$`. BASLOAD will not have a label and a variable of one name and the
`$` does not separate them, so `GUI.INPUT` the routine forbids `GUI.INPUT$` the variable. **A
program written against the older library compiles clean and reads the wrong one back** — this is
the one rename here that fails silently.

`GUI.CTRL.*` are the seven parallel arrays that are the control block: one element a control, up to
`GUI.FORM.MAX`. `GUI.INC.BL` `DIM`s them. Do not `DIM` them yourself.

### `GUI-DIALOGS.INC.BL` — every dialog as a verb

Routines, arguments and examples: §4.12.

`MSGBOX`, `ASKYN`, `ASKOK`, `ASKTEXT`, `INPUTBOX`, `PICKMENU`, `LISTBOX` and `LISTBOXM` are the
dialogs, each with an `EX` form that also takes the title and the second and third lines.
`LIST.BEGIN`, `LIST.ARRAY`, `LIST.BANK`, `LISTTO.RUN`, `LIST.ITEM` and `LIST.SORT` build a list box
a step at a time; `PANELOPEN`, `PANELCLOSE` and the `FORM.` verbs do the same for a form.
`DLGRESET`, `DLGSHADOW`, `DLGSHADOWCLR`, `DLGSTYLE` and `DLGGLYPH` set what every dialog starts
from, and `KBCLEAR` throws away what is already typed.

| | |
|---|---|
| in | the arguments, in the call. They land in `DLG.*` and NOT in the `GUI.*` inputs: `GUI.DEFAULTS` runs after they are stored and would clear them<br>`DLGRESET bank` — the RAM bank every dialog saves the screen into, once, before the first one<br>`GUI.LIST.ITEM$()` — the rows, 1..count, for the array-backed list verbs, and **the caller owns the `DIM`** |
| out | `GUI.ANSWER` — `ASKYN`, `ASKOK`<br>`GUI.TEXT$` and `GUI.OK` — `INPUTBOX`<br>`GUI.SEL` — `PICKMENU`<br>`GUI.LISTBOX.SEL` `.MARKS$` `.MARKED` — the listbox verbs<br>`GUI.KEY` — 13 accepted, 27 cancelled |
| internal | the whole of `DLG.*` |

**In a multi-select list `GUI.LISTBOX.SEL` is not the answer** — it is where the cursor was left.
The marks are.

**The scrolling list is not in this module.** It is `GUI.CT.LIST`, one of `GUI.FORM`'s control
types, and lives in `GUI.INC.BL` beside the field. This file is the dialog around it: measure, open,
hand the control its geometry, add a button row, run the form, answer. `GUI.LIST.FETCH`, in
`GUI.INC.BL`, is the one place a row is read, and it reads either the array or a RAM bank holding
the `GP.BSTR` image layout — which is how `LIST.BANK` shows a directory that was never in low
memory.

### `STASH.INC.BL` — save a text rectangle, and put it back

| | |
|---|---|
| in | `STASH.BANK` — the RAM bank to keep the cells in, 1..255, and it is yours: this writes the whole of it<br>`STASH.X` `STASH.Y` `STASH.W` `STASH.H` — the rectangle, in cells, for `STASH.SAVE`<br>`STASH.MOVE` — non-zero pastes to `STASH.X`/`STASH.Y` instead of where it came from |
| out | `STASH.OK` — -1 if it fitted and was saved, 0 if not |
| internal | `STASH.AT` `STASH.BASE` `STASH.BYTES` `STASH.HI` `STASH.MAPW` `STASH.MODE` `STASH.ROW` `STASH.STRIDE`<br>`STASH.DEST%` `STASH.NBYTES%` `STASH.VADDR%` `STASH.VCTRL%` `STASH.WAS%` — the `{VAR}` slots the blobs read |
| constants | `STASH.LCONFIG` `STASH.LMAPBASE` `STASH.WINDOW` `STASH.HEADER` `STASH.MAXBYTES` |

**`STASH.RESTORE` needs only the bank.** Four header bytes — w, h, x, y — go in first, so the
rectangle describes itself and cannot be put back at the wrong size.

A bank is 8,192 bytes and a cell is two, so 4,094 cells fit: 63×63, larger than any dialog and
**not** a whole 80×60 screen. Too big is refused before the first write with `STASH.OK = 0`, rather
than running on into the next bank.

It needs a `#SYMFILE` in your program, because it reads its arguments through `{VAR}` names.
**It restores the caller's RAM bank on the way out** — it did not always, and a caller that worked
around that can stop.

**`STASH.SLOT` and `STASH.NEXT` are not in this copy.** `GP-BASIC.md` §3.6 describes them — a byte
offset into the bank, and the offset just past what was written, so one bank holds a stack of
rectangles instead of one a level. They are in `samples/GPB-MODS-TESTING/GPC-BASIC/STASH.INC.BL`
and have not reached the root library yet. Until they do, one rectangle a bank.

### `STASHFILE.INC.BL` — a saved text rectangle, through a file

`STASH.FILE.SAVE`, `STASH.FILE.LOAD` and `STASH.FILE.PUT`, and **no variables of its own** — it sets
`STASH.*` and calls through. The prefix exists to keep the three routine names apart from the rest
of `STASH.`, not to hold state. Kept a separate `#INCLUDE`: unless the compile removes dead code, the
disk half is 127 bytes a program that never writes one would still carry.

### `SORT.INC.BL` — shell sort a string array

Routines, arguments and examples: §4.7.

| | |
|---|---|
| in | `SORT.PTR` — **`GP.ARRPTR`** of the array, element zero, the 3-byte header already skipped. A BASL subroutine cannot be passed an array, so the caller takes its address and this sorts through that<br>`SORT.DESCEND` — non-zero, largest first<br>`SORT.NOCASE` — non-zero folds case while comparing |
| out | `SORT.OK` — -1 if it sorted, 0 if it refused<br>`SORT.COUNT` — elements found in the array header |
| internal | `SORT.TYPE` — the type byte it read back<br>`SORT.BASE%` `SORT.CHR%` `SORT.CNT%` `SORT.DESC%` `SORT.FOLD%` `SORT.GAP%` `SORT.I%` `SORT.J%` `SORT.LL%` `SORT.LR%` `SORT.RN%` `SORT.TMP%` — every one a `{VAR}` slot |

Note `SORT.COUNT` is an **output**, read out of the array header, not a size you hand in — and
`SORT.PTR` is `GP.ARRPTR`, not `GP.STRPTR` like the rest of the library's pointer arguments. Both
are easy to write the other way round.

Also needs a `#SYMFILE`. **255 elements**, so `DIM A$(254)` is the largest; beyond that `SORT.OK`
is 0 rather than a wrong answer. String arrays only. It moves 2-byte pointers rather than string
data, so a swap is cheap and the array's own storage never moves.

### `STRCASE.INC.BL` — case, in place

Routines, arguments and examples: §4.8.

| | |
|---|---|
| in | `STRCASE.PTR` — `GP.STRPTR` of the string<br>`STRCASE.MODE` — `STRCASE.UPPER` or `STRCASE.LOWER` |
| out | the string itself, rewritten in place |
| verbs | `STR.UCASE` `STR.LCASE` — a string in, a cased copy back, through `STRCASE.S$` |
| internal | `STRCASE.ADDR%` `STRCASE.OP%` `STRCASE.S$` |
| constants | `STRCASE.UPPER` `STRCASE.LOWER` |

**`STR.UCASE` and `STR.LCASE` are the two `STR.` names this file owns.** The rest of `STR.` is
`STRINGS.INC.BL`'s, and the two verbs are named for the module they are to move into.

`#SYMFILE` again. **Do not write `#AUTONUM` in a program that includes this** — it sets the STEP,
and only the default 1 survives.

### `MATH.INC.BL` — the smaller and the larger of two numbers

Routines, arguments and examples: §4.22.

| | |
|---|---|
| in | `MATH.FIRST` `MATH.SECOND` — the two numbers, in either order |
| out | `MATH.RESULT` — the answer, and what `GP.FN` reads back |
| verbs | `MATH.MINOF` `MATH.MAXOF` — the same two routines called in one line |
| internal | — |

All three names are shared by `MATH.MIN` and `MATH.MAX`. The formals of a `GP.DEFPROC` are ordinary
variables, so `GP.SUB MATH.MINOF` writes `MATH.FIRST` and `MATH.SECOND` exactly as a `GOSUB` caller
would.

### `MEM.INC.BL` — a block copied, a block filled

Routines, arguments and examples: §4.23.

| | |
|---|---|
| in | `MEM.SOURCE` — where `MEM.COPY` reads, 0 to 65535<br>`MEM.TARGET` — where either routine writes<br>`MEM.COUNT` — 1 to 65535, refused outside that<br>`MEM.VALUE` — the byte `MEM.FILL` writes, 0 to 255 |
| out | `MEM.OK` — -1 done, 0 refused, and what `GP.FN` reads back |
| verbs | `MEM.BLOCKCOPY` `MEM.BLOCKFILL` |
| internal | — |
| constants | `MEM.MEMORYCOPY` `MEM.MEMORYFILL` — the two KERNAL entry points |

`MEM.TARGET`, `MEM.COUNT` and `MEM.OK` are shared by both routines, so a fill overwrites the target
a copy was set up with.

---

## 4. Labels are global too

Every `NAME:` in every module is a jump target in one flat space, including the ones you were never
meant to call. `BMX.STREAM.MORE`, `LINEINPUT.REDRAW`, `THEME.SELECT.DARK` and most of `MENU.*`
are internal, and a `GOSUB` to one will do something, just not something useful.

`MENU.INC.BL` is called through its verbs, `MENU.BEGIN`, `ITEM`, `ITEMX`, `SELECTED` and `DRAWBAR`
with `GP.SUB` and `MENUTO.VERT` and `MENUTO.BAR` with `GP.FN`, and `MENUPULL.INC.BL` through
`MENUTO.PULLDOWN`. Every label in both files is internal: the `.BODY` labels behind the verbs,
`MENU.RUN`, `.WAIT`, `.KEYED`, `.TURN`, `.MOVED`, `.WRAPTOP`, `.WRAPBOT`, `.CANCEL`, `.KEYHOT`,
`.HOTTAKE`, `.SKIPOFF`, `.SKIPLOOP`, `.LIGHT`, `.DRAWALL`, `.SPOT`, `.DRAWROW`, `.SEPROW`,
`.HINTSHOW`, `.PADKEY`, `.PADREAD`, `.STRIP`, `.CREATE`, `.MEASURE`, `.FRAMEBOX`, `.BARPLACE`, and
`MENUPULL.MARK`, `.BESIDE`, `.PLACE` and `.SAVE`.

`FILE.*` has a great many, because most of the module is one routine feeding another: **the
callable names are `FILE.STATUS`, `EXISTS`, `DELETE`, `RENAME`, `COPY`, `MKDIR`, `CHDIR`, `UP`,
`GETPATH`, `SAVEARRAY` and `LOADARRAY`, plus `FILE.DIR.INIT`, `.OPEN` and `.NEXT`.**
`FILE.CMD`, `.DONE`, `.PETNAME`, `.PETNEW`, `.TOPET`, `.PATHWALK`, `.WRITEROWS`, `.READROWS`,
`.ROWREAL`, `.ROWDROP`, `.KEEPROW`, `FILE.DIR.WHERE`, `.LOWRAM`, `.ASKFOR`, `.SUCK`,
`.SKIPDISK`, `.FILL` and `.STEP` are not. `FILE.DIR.FILL` and `FILE.DIR.STEP` are the two
assembly blobs and enter with no arguments set up at all.

`STRINGS` has three of its own. **`STR.SPLIT.NEXT`** and **`STR.REPLACE.NEXT`** are loop
continuations rather than entry points: enter either directly and you resume a loop whose
accumulators were never initialised. **`STR.TRIM.GO`** is the shared body of the three trims and
runs with whatever `STR.OP%` last held. The callable names are `STR.PADR`, `PADL`, `PADC`,
`SPLIT`, `REPLACE`, `PET2SCR`, `TRIM`, `LTRIM`, `RTRIM` and `SPLICE`.

`GUI.INC.BL` has more internal labels than anything else in the library, because `GUI.FORM` is a
dispatcher and every arm of it is one. **The callable names are `GUI.OPEN` and
`GUI.CLOSE`** — the dialogs themselves are verbs, in `GUI-DIALOGS.INC.BL`. `GUI.FORM` is usable
and undocumented, the module's own. Everything else, the whole of `GUI.FORM.*`, `GUI.BUTTON*`, `GUI.BTN.*`,
`GUI.LIST.*`, `GUI.FIELD.DRAW`, `GUI.FRAME`, `GUI.GLYPHS`, `GUI.SHADOW.*`, `GUI.SIZE`,
`GUI.PLACE.BOX`, `GUI.PLACE.SCROLL` and `GUI.SCREEN`, is not.

### A module in a bank keeps its names

Where a module's `#INCLUDE` sits changes none of its names. `THEME.SELECT` is `THEME.SELECT` in low
memory and inside a `GP.BANKED` region, and a `GOSUB` to it compiles to what reaches it: an ordinary
`GOSUB` from inside the same region, and a `.bgosub` that selects the region's bank from anywhere
else. [BANKED-OR-NOT.md](BANKED-OR-NOT.md) has the rules.

**So a name is callable from anywhere, in any build.** An older library gave some modules a
banked `.BODY` and a low-memory front door, and a program that calls a `.BODY` name stops with
`LABEL NOT FOUND`. What this section calls internal is still internal.

**Include a module once.** One `#INCLUDE` in low memory and another in a region is
`DUPLICATE SYMBOL` where the module has no `#IFNDEF` guard. Where it has one, the module lands at
the first `#INCLUDE` and the second produces nothing.

Each module also has a skip label it jumps over itself with — `THEME.SKIP`, `APPSYS.SKIP`,
`STR.SKIP`, `BMX.MODULE.END`, `LINEINPUT.MODULE.END`, `MENU.MODULE.END`,
`MENUPULL.MODULE.END`, `GUI.MODULE.END`, `GUI.LISTBOX.MODULE.END`, `STASH.MODULE.END`,
`STASHFILE.MODULE.END`, `SORT.MODULE.END` and `STRCASE.MODULE.END`.
Those exist so an include can sit anywhere in the file, the top included. **Do not branch to one.**

BASLOAD refuses a name used as both a label and a variable (`BASLOAD.MD:319`). `BMX.SKIP` is the
byte-skip counter, so the module's skip label had to
be `BMX.MODULE.END` — a name is either a label or a variable, never both.

---

## 5. TRUE IS -1

**Every flag the library hands back is -1 for true and 0 for false**, and anything written
against it should be too. `GUI.OK` `GUI.ANSWER` `GUI.STASHED` `STASH.OK` `SORT.OK`
`MENU.OK` `FILE.OK` `BANKMGR.OK` `APPSYS.IS.EMULATOR` — all of them.

That is what a comparison in this compiler evaluates to, so a flag and a test read the same
way, and it is the value `NOT` wants: `NOT` is `-x-1`, so `NOT -1` is 0 while `NOT 1` is -2,
which is still true. `IF` itself tests non-zero, so `IF FLAG THEN` works either way and
`IF FLAG = 1 THEN` is the spelling that breaks.

```basic
IF GUI.OK THEN <accepted> : REM yes
IF NOT GUI.OK THEN <cancelled> : REM yes
IF GUI.OK = 0 THEN <cancelled> : REM yes
IF GUI.OK = 1 THEN <accepted> : REM NO -- it is -1
```

**A flag the CALLER sets is read as non-zero**, so `LINEINPUT.MASK = 1` and `STASH.MOVE = 1`
still work. Write -1 in new code all the same.

**Printing one needs `STR$` whole.** The `MID$(STR$(N), 2)` idiom strips the leading space
`STR$` puts on a positive number; -1 has no leading space, so that idiom eats the minus and
prints `1`.

## 6. Two more naming rules that are not about collisions

**`#DEFINE` takes an INT16** (`BASLOAD.MD:313`). A constant above 65535 is
`ERROR: INVALID PARAMETER`, not a warning — which is why `BMX.PALBASE` (VRAM `$1FA00`, 129536) is an
ordinary variable and not a `#DEFINE`. Every VRAM address past `$FFFF` has the same problem.

**A dotted name whose tail is a reserved word is fine.** `MENU.COUNT`, `THEME.CLR`,
`LINEINPUT.LEN` and `LINEINPUT.RETURN` all contain keywords and all work, because BASLOAD matches the whole identifier. An
*undotted* one does not: `POS`, `MB`, `ST`, `LEN` and `CHAR` cannot be variables at all. This is the
main reason the library is dotted throughout.

`RETURNS` joined that list on 08/09/26 -- it is `GP.DEFPROC`'s result clause and has a token
of its own, so a bare `RETURNS` is no longer a name. `RETURN` is untouched, and so is anything
dotted.

One rule applies only outside BASL: BASLOAD gives 64 significant characters, the built-in BASIC
gives two. Write the same code as a hand-typed `.bas` for the PC-side converter and
`THEME.CLR` and `THEME.COUNT` become the same variable. That is a silent wrong answer — it cost two
test cycles during tier 6, both times looking exactly like a compiler bug. Inside BASL you are safe;
in a raw `.bas`, give every variable a distinct first two characters.
