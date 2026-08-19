# GP.BASIC — the manual

The complete reference for GPC's `GP.*` keyword extension and the BASL library built on it:
**every command, every routine, every variable name they take.**

`GP` is **Greased Piglet** — GPC is the Greased Piglet Compiler, GP.BASIC (GPB) the Greased
Piglet BASIC, and `GPC SQUEALING...` on the compiler's first line is the same joke rather than
an odd choice of verb.

| If you want | Read |
|---|---|
| what a command does and how to write it | §3 and §4, here |
| what names are already taken before you invent one | §5 here, then [GP-BASIC.GLOBALS.md](GP-BASIC.GLOBALS.md) for the full register |
| why a thing was built the way it was | `docs/blitz/GP-BASIC.TIERS.md` — the build plan and every measurement, in the source repository |
| the original design argument | `docs/blitz/GP-BASIC.PLAN.md`, in the source repository |
| the files themselves | beside this one, listed in [README.md](README.md) |

---

## 1. What GP.BASIC is

Two halves, and the split is deliberate.

**The keywords** — 27 of them, `GP.DO` through `GP.ENDSEL` — are compiled into p-code and handled by
assembly in the runtime. They exist because BASIC is bad at what they do: searching a string a
character at a time, sorting an array, pushing bytes at VERA. **1,970 bytes** of assembly, which
page alignment rounds to the **2,048** a program actually pays.

Those bytes are spent only by a program that uses at least one GP keyword. One that uses none has
the whole block left out of its object, and gets the 2,048 back as workspace as well.

**The library** — seven `.INC.BL` modules and fourteen `.EXP.BL` examples, beside this file — is
ordinary BASL, called with `GOSUB`. Menus, panels, themes, entry fields, BMX loading. **Zero runtime
bytes**: only a program that `#INCLUDE`s one pays for it, and it pays in its own p-code.

> **The rule that decides which side a thing goes on:** assembly gets what runs in a loop or moves
> bulk data. Everything else is BASIC. `INPHELP.GET` waits on a *human*, so the speed argument that
> puts sorting in assembly does not apply to it — and it saved 166 bytes of runtime for every program
> ever compiled.

---

## 2. Using it

Every BASL source that uses a `GP.` keyword must declare the tokens:

```basic
#INCLUDE "GP.INC.BL"
```

**BASLOAD knows only the ROM's keywords.** Without that line `GP.DO 5` is a syntax error. (The
host-side tokeniser for hand-written `.bas` needs nothing — it learns the same tokens from
`c64tokens.py` at build time.)

### Where the library lives

Keep `GPC-BASIC/` as a folder beside your own sources and include from it by path:

```basic
#INCLUDE "/GPC-BASIC/GP.INC.BL"
```

**`#INCLUDE` takes a path, not just a bare filename** — verified on R49, both absolute
(`/GPC-BASIC/GP.INC.BL`) and relative (`GPC-BASIC/GP.INC.BL`). Prefer the leading slash: it is
absolute from the drive root, so it still resolves when your own program sits in a subdirectory.
`../` and `//` are not understood by the X16's filesystem, so a path goes down from somewhere,
never up.

Earlier versions of this manual said the include had to be a bare filename and told you to copy the
library next to every program. That was wrong, and it meant twenty-odd files in your working folder
for no reason.

Then it is BASLOAD and GPC as usual: `BASLOAD "MYPROG.BL"`, then compile the PRG with `GPC.PRG`.

### A `.PRG` with GP tokens is compile-only

A `$CE7x` byte has no BASIC handler behind it, so the ROM cannot `LIST` or `RUN` the tokenised
program. That is expected, not a fault. Compile it and run the object.

---

## 3. Command reference

27 keywords, tokens `$CE7F` down to `$CE63`, allocated downward and **never renumbered** — `$CE67`
and `$CE68` are holes, freed when `GP.SEL` and `GP.MENU` were withdrawn, and are not reused. The token
values are the ABI.

### At a glance — the whole library, both halves

Everything GP.BASIC gives you, and **which half it comes from**. The rest of §3 is the ASM keywords;
the BASIC modules are written up in §4.

- **ASM** — a keyword the compiler knows, run by machine code in the runtime. Costs runtime bytes,
  and a program that uses one GP keyword pays for the whole block. Written in §3.
- **BASIC** — a `.INC.BL` module of ordinary BASL, called with `GOSUB`. Costs **nothing** unless you
  `#INCLUDE` it, and then only its own p-code. Written in §4.

| | | |
|---|---|---|
| **Loops** | ASM | `GP.DO` `GP.LOOP` `GP.EXITDO` |
| **Multi-way branch** | ASM | `GP.SELECT` `GP.CASE` `GP.ELSE` `GP.ENDSEL` |
| **Machine code** | ASM | `GP.CALL` `GP.A` `GP.X` `GP.Y` `GP.C` |
| **Strings** | ASM | `GP.INSTR` `GP.STRPTR` `GP.TRIM` `GP.LTRIM` `GP.RTRIM` `GP.UPPER` `GP.LOWER` `GP.COMP` |
| **Arrays** | ASM | `GP.SORT` `GP.ARRPTR` |
| **Screen** | ASM | `GP.STASH` `GP.RESTR` `GP.BOX` `GP.FILL` `GP.PRINTAT` |
| **Colour roles** | BASIC | `THEME.INC.BL` — `THEME.LOAD`, `THEME.CLR()` · §4.1 |
| **String helpers** | BASIC | `STRHELP.INC.BL` — `PADR` `PADL` `PADC` `SPLIT` · §4.2 |
| **Screen etiquette, panels** | BASIC | `APPHELP.INC.BL` — `STARTUP` `RESTORE` `PANEL.SAVE/LOAD/PUT` · §4.3 |
| **Entry fields** | BASIC | `INPHELP.INC.BL` — `INPHELP.GET`, `INPHELP.ASK` · §4.4 |
| **Bitmaps** | BASIC | `BMX.INC.BL` — `BMX.SHOW`, `BMX.RESTORE` · §4.5 |
| **Menus** | BASIC | `MENUHELP.INC.BL` — `MENUHELP.RUN`, `MENUHELP.DRAW` · §4.6 |

**The rule that decides the side** is in §1: assembly gets what runs in a tight loop or moves bulk
data, BASIC gets everything else. A menu waits on a human, so it is BASIC — it used to be the
`GP.MENU` keyword and cost every GPB program 462 bytes whether it had a menu or not.

---

The keywords, in detail. Square brackets mean optional, and **optionals cannot be skipped over** —
`GP.BOX X,Y,W,H,,7` is a syntax error; write the style you are defaulting.

### 3.1 Loops

```
GP.DO [count]
    ...
GP.LOOP
```

Counted loop, modelled on prog8's `repeat`. **Count 0 or omitted loops forever.** Nesting works.

```
GP.EXITDO
```

Leave the innermost `GP.DO` early, closing its stack frame on the way. **This is the leak-free exit** —
a `GOTO` out of a `GP.DO` abandons the frame, and the frames do not get reclaimed.

```basic
GP.DO
  TICK = TICK + 1
  IF TICK = 9 THEN GP.EXITDO
GP.LOOP
```

Example: [`LOOPS.EXP.BL`](LOOPS.EXP.BL)

---

### 3.2 Multi-way branch

```
GP.SELECT <expr>
GP.CASE <expr> [,<expr> ...]
    ...
GP.ELSE
    ...
GP.ENDSEL
```

The selector is evaluated **once**; each `GP.CASE` compares against it in the order written, and the
first match wins. `GP.ELSE` is optional. **Nothing matching with no `GP.ELSE` is not an error** — the
whole select is simply skipped.

Case values are ordinary numeric **expressions**, not just constants — which is a step past prog8's
`when`, whose choices must be compile-time integers.

**`GP.ENDSEL` is required**: it is what releases the selector's stack frame.

> **Do not `GOTO` out of a select.** Jumping past `GP.ENDSEL` leaves the frame open, and in a loop that
> leaks one per pass. Set a flag and test it after `GP.ENDSEL` — one comparison, and it cannot leak.
> `INPHELP.GET` does exactly this and the comment there says why. `GP.EXITDO` out of a loop that
> *contains* a select is fine; it cleans up on the way.

**This does not replace `ON x GOTO/GOSUB`**, which is a real skip table and remains the right answer
for a dense `1..n` index. `GP.SELECT` is for the **sparse** selector — key codes, state machines,
bit depths — where `ON` cannot go.

```basic
GP.SELECT BMX.DEPTH
    GP.CASE 8
    GP.CASE 1, 2, 4
        BMX.ERROR$ = "NEEDS ANOTHER SCREEN MODE"
    GP.ELSE
        BMX.ERROR$ = "BAD BIT DEPTH"
GP.ENDSEL
```

An empty case body — the `8` above — is the cheapest possible "this one is fine": the match falls
straight out of the select.

Example: [`SELECT.EXP.BL`](SELECT.EXP.BL)

---

### 3.3 Machine code

```
GP.CALL address [,a] [,x] [,y] [,carry]
GP.A   GP.X   GP.Y   GP.C
```

Calls machine code with the registers set. **All four arguments are optional and default to 0.** The
four value words read the results back afterwards.

They are **keywords, not variables** — `X = GP.A` reads, `GP.A = 5` is a syntax error. They share
`SYS`'s `$030C`–`$030F`, so they also read what a plain `SYS` left behind.

```basic
GP.CALL $FF5F, 0, 0, 0, 1          ' KERNAL screen_mode, carry set = report
COLS = GP.X : ROWS = GP.Y
```

> **Put your machine code in banked RAM (`$A000`–`$BFFF`), not `$0400`.** Stock X16 BASIC leaves
> `$0400` free for the user; **a compiled GPC program does not** — that page holds runtime state
> (`stringHighMemory`, `storeStartHigh`, `variableStartPage`), and POKEing code over it corrupts the
> program silently.

Example: [`MLCALL.EXP.BL`](MLCALL.EXP.BL)

---

### 3.4 Strings

| Form | Does |
|---|---|
| `GP.INSTR(hay$, needle$ [,start])` | position of `needle$`, 1-based; **0 = not found**. `start` is where to begin |
| `GP.COMP(a$, b$)` | compare **ignoring case**: −1 before, 0 same, 1 after |
| `GP.STRPTR(a$)` | address of the string's `[ActLen][Data]` block |
| `GP.TRIM a$` | strip spaces from **both** ends, in place |
| `GP.LTRIM a$` | from the left only |
| `GP.RTRIM a$` | from the right only |
| `GP.UPPER a$` | A–Z to upper, in place |
| `GP.LOWER a$` | A–Z to lower, in place |

`GP.INSTR` is the gap that matters: **GPC has no string search of any kind** without it.

`GP.COMP` gives you a case-blind equality test — `IF GP.COMP(A$,B$) = 0` — which plain `=` cannot do,
and the comparator for ordering names. Length breaks a tie, so `"abc"` sorts before `"ABCD"`.

**The five in-place statements take a string VARIABLE**, never a literal or an expression; the
compiler rejects those. Case conversion leaves digits, punctuation and PETSCII graphics untouched.

**There is no `GP.PAD`.** Padding *grows* a string, and an in-place handler receives only the string's
block, never the variable slot — so it can never reallocate past the capacity the string was born
with. Use `STRHELP.PADR` / `PADL` / `PADC` (§4.2), which are plain BASIC assignment and reallocate.

#### `GP.STRPTR` and the address-splitting trap

The address is of `[ActLen][Data]`: **length at that address, first character at +1**, and the
block's capacity at −2. With `GP.CALL` that lets machine code fill a BASIC string in place and set
its length — something stock BASIC cannot do at all.

> **Splitting the address, do NOT write `P AND 255`.** `AND` is **16-bit signed** in GPC and the string
> heap lives above 32767, so it raises `OUT OF RANGE` rather than masking. Write:
> ```basic
> H = INT(P / 256) : L = P - H * 256
> ```
> This applies to `GP.ARRPTR` and to every VRAM address past the top eighth of the screen too.

Example: [`STRINGS.EXP.BL`](STRINGS.EXP.BL)

---

### 3.5 Arrays

```
GP.SORT a$() [,descending] [,foldcase]
GP.ARRPTR(a())
```

Shell sort in place. Both options default to 0 (ascending, case-sensitive); any non-zero turns them
on. **Maximum `DIM` bound 254** (255 items). Never-assigned elements count as empty strings and sort
to the front.

> **The empty parentheses are required.** In BASIC `A$` and `A$()` are different variables, so
> `GP.SORT A$` finds the scalar and sorts nothing.

`GP.ARRPTR` returns the address of **element zero** — the header is already skipped — so machine code
reached by `GP.CALL` can work on the array in bulk. **Stride is yours to add:** 2 bytes per element
for a string array (each element is a *pointer* to the string's block — follow it, and see
`GP.STRPTR` for the layout), 6 for a numeric one. Multi-dimensional arrays are rejected, and
`GP.ARRPTR(A(3))` is a syntax error — add `3*2` or `3*6` yourself.

Example: [`ARRAYS.EXP.BL`](ARRAYS.EXP.BL)

---

### 3.6 Screen — stash and restore

```
GP.STASH bank, x, y, w, h
GP.RESTR bank [,x ,y]
```

Copies a text rectangle into a banked RAM bank and back. The stash carries a **4-byte header**
(w, h, x, y), so the restore needs only the bank — `GP.RESTR bank` puts it back where it came from,
and `GP.RESTR bank,x,y` pastes it somewhere else. That makes a saved panel a reusable stamp.

> **A bank is 8K and a cell is 2 bytes, so at most 4094 cells fit.** A full 80×60 screen is 9,600
> bytes and will **not**. Stash panels, not screens. The limit is checked per row, before the write
> that would cross out of the bank — too large is an error, never a corrupted next bank.

---

### 3.7 Screen — drawing

```
GP.BOX x, y, w, h [,style] [,col]
GP.FILL x, y, w, h, char [,col]
GP.PRINTAT x, y, text$ [,col]
```

Written **straight into VERA** — no KERNAL, which is why it is several times faster than `PRINT`
(GPC's character output makes two KERNAL calls per character, and `BSOUT` carries scroll, quote mode
and cursor work).

`GP.BOX` draws the frame only. Styles: **0** solid, **1** dither, **2** single line, **3** rounded,
**4** thick, **5** thick shaded. `char` in `GP.FILL` is PETSCII, e.g. `ASC(" ")`.

**The colour is optional and defaults to whatever `COLOR` last set** — the same colour a `PRINT`
would have used, read out of the KERNAL's `$0376`. Supplied, it is one byte packed exactly as the X16
packs it: `background * 16 + foreground`. **255 is a real colour here** (light grey on light grey),
not a "leave it alone" marker.

> **These do not move the cursor `PRINT` uses.** Nothing here calls the KERNAL, so a plain `PRINT`
> after a `GP.PRINTAT` carries on from wherever the KERNAL still thinks the cursor is — *not* after
> the text just drawn. Use `LOCATE` before `PRINT`, or stay in one world or the other.

**Nothing is clipped.** Off the right edge wraps to the next row; off the bottom writes past the end
of the screen map. Zero width or height draws nothing, which is the case a computed size reaches by
accident.

Example: [`SCREEN.EXP.BL`](SCREEN.EXP.BL)


---

## 4. Module reference — the BASL library

Called with `GOSUB`. Arguments go in named variables first, results come back in named variables
after. **Every one of these files is position-independent** (each jumps over itself), so `#INCLUDE`
it anywhere, the top of the program included.

### 4.1 `THEME.INC.BL` — named colour roles

| Routine | in | out |
|---|---|---|
| `THEME.LOAD` | `THEME.DARK` (0 light, non-zero dark) | fills `THEME.CLR()` |
| `THEME.SET` | `THEME.ATTR` | issues `COLOR` — makes it the colour `PRINT` uses |
| `THEME.HI` | `THEME.ATTR` | `THEME.INV`, the inverse attribute |

Roles, for indexing `THEME.CLR()`: `THEME.PAGE` `THEME.TEXT` `THEME.TITLE` `THEME.BORDER`
`THEME.HILITE` `THEME.DIMMED` `THEME.WARN`, and `THEME.SLOTS` = 7.

```basic
THEME.DARK = 1 : GOSUB THEME.LOAD
GP.BOX 4,2,30,8, 2, THEME.CLR(THEME.BORDER)
GP.PRINTAT 6,3, "TITLE", THEME.CLR(THEME.TITLE)
```

The values are **packed attributes** — `background * 16 + foreground` — because that is exactly what
`GP.BOX`, `GP.FILL` and `GP.PRINTAT` take. For `COLOR`, which wants the halves separately, use
`THEME.SET`.

`#DEFINE` substitutes at translation time, so `THEME.CLR(THEME.TITLE)` compiles to `THEME.CLR(2)` —
the readable name costs no variable, no lookup, and a one-byte constant index.

**`THEME.CLR` is `DIM`med by the module. Do not `DIM` it yourself.**

### 4.2 `STRHELP.INC.BL` — string helpers

| Routine | in | out |
|---|---|---|
| `STRHELP.PADR` | `STRHELP.STR$` `STRHELP.WIDTH` | `STRHELP.STR$` left-justified |
| `STRHELP.PADL` | same | right-justified |
| `STRHELP.PADC` | same | centred (odd gap goes right) |
| `STRHELP.SPLIT` | `STRHELP.STR$` `STRHELP.DELIM$` `STRHELP.MAX` | `STRHELP.N`, `STRHELP.FIELD$(1..N)` |
| `STRHELP.PET2SCR` | `STRHELP.PET` | `STRHELP.SCR` |

All three pad routines **leave a string already at or past the width alone. They pad; they never
truncate** — use `GP.RTRIM` to go the other way.

`SPLIT` reads `STRHELP.STR$` without modifying it. `STRHELP.MAX` of 0 means 10. **Empty fields are
preserved**, which is what makes it safe for data rows: `"A,,C"` is three fields, `"A,"` is two.
Splitting an empty string gives one empty field, never zero. Reaching the limit is not an error and
loses nothing — the last field gets the whole unsplit remainder, delimiters and all.

**`STRHELP.FIELD$` is the one array the library deliberately does NOT `DIM`.** Left alone, GPC's
implicit `DIM` gives 0..10. Want more, `DIM` it yourself **before the first call** and set
`STRHELP.MAX` to match. `DIM`ming an array GPC has already auto-dimensioned is an error, so it is one
or the other. **This is the opposite of `THEME.CLR`** — worth keeping straight.

`PET2SCR` converts a PETSCII code to the screen code the tile map holds, for `TILE`, `TDATA` and
`VPOKE`. `GP.PRINTAT` and `GP.FILL` already do it internally.

Examples: [`SPLITT.EXP.BL`](SPLITT.EXP.BL)

### 4.3 `APPHELP.INC.BL` — start politely, leave it as you found it

| Routine | in | out |
|---|---|---|
| `APPHELP.STARTUP` | — | `APPHELP.MODE` `APPHELP.COLS` `APPHELP.ROWS` `APPHELP.COLOUR` |
| `APPHELP.RESTORE` | those | screen mode and colour put back |
| `APPHELP.PANEL.SAVE` | `APPHELP.FILE$` `.BANK` `.X` `.Y` `.W` `.H` [`.DEV`] | a file |
| `APPHELP.PANEL.LOAD` | `APPHELP.FILE$` `.BANK` | back where it came from |
| `APPHELP.PANEL.PUT` | `APPHELP.FILE$` `.BANK` `.X` `.Y` | pasted somewhere else |

```basic
GOSUB APPHELP.STARTUP
' ... the application, laid out with APPHELP.COLS / APPHELP.ROWS ...
GOSUB APPHELP.RESTORE : END
```

**Call `STARTUP` first, before any `SCREEN` or `COLOR` of your own** — it records the state as it
finds it, so anything you change beforehand is what gets restored.

**Lay out from `APPHELP.COLS` / `APPHELP.ROWS` rather than assuming 80×60.** The X16 boots 80×60 but
`SCREEN 0` is 40×30, and someone who prefers larger text is running one.

`APPHELP.DEV` defaults to 8. The panel file is **self-describing** — `GP.STASH`'s 4-byte header goes
in it — so loading needs nothing but the name.

### 4.4 `INPHELP.INC.BL` — a positioned entry field

| Routine | in | out |
|---|---|---|
| `INPHELP.GET` | `INPHELP.X` `.Y` `.LEN` `.ATTR` `.TEXT$` `.MASK` | `INPHELP.TEXT$` `INPHELP.KEY` |
| `INPHELP.ASK` | the same plus `INPHELP.LABEL$` | the same; `INPHELP.X` restored |

```basic
INPHELP.X = 10 : INPHELP.Y = 6
INPHELP.LEN = 20
INPHELP.ATTR = THEME.CLR(THEME.TEXT)
INPHELP.TEXT$ = ""
GOSUB INPHELP.GET
IF INPHELP.KEY = 27 THEN GOTO CANCELLED
```

**This is what `INPUT` and `LINPUT` cannot do.** Both own the whole bottom of the screen, scroll it,
echo in whatever colour is current, and accept any length — all four fatal on a drawn screen. A field
stays where you put it, in the colour you give it, and stops at the width you allow.

`INPHELP.KEY` is the key that ended it, and it is what makes a **multi-field form** possible:

| | |
|---:|---|
| 13 | RETURN — finished |
| 27 / 3 | ESC / STOP — cancelled, and `INPHELP.TEXT$` is put back to what it was |
| 17 / 145 / 9 | cursor down / up / TAB — left the field, **text kept** |

So a form is a loop over fields, not a sequence of prompts, and the user can go back and fix the
first one without starting again.

`INPHELP.MASK` non-zero shows asterisks while holding the real string. The field never scrolls: when
full, further characters are refused and the cursor **inverts the last character** rather than
sitting off the end. The cursor blinks off `TI` rather than a delay loop, because a delay loop would
swallow keys pressed during it.

Example: [`FORM.EXP.BL`](FORM.EXP.BL) — three fields, one masked, in a themed panel.

### 4.5 `BMX.INC.BL` — a BMX bitmap into VERA

| Routine | in | out |
|---|---|---|
| `BMX.OPEN` | `BMX.FILE$` | `BMX.ERROR$`, and the header — `BMX.WIDTH` `.HEIGHT` `.DEPTH` `.VERSION` `.PALUSED` `.PALFIRST` `.DATAOFF` `.PACKED` |
| `BMX.PAINT` | an open file | palette and pixels in VRAM, file closed |
| `BMX.SHOW` | `BMX.FILE$` | both of the above |
| `BMX.CLOSE` | — | abandons a file opened by `BMX.OPEN` |
| `BMX.RESTORE` | — | puts the machine's own palette back |

`BMX.ERROR$` empty means it worked.

```basic
BMX.FILE$ = "TITLE.BMX"
SCREEN 128
GOSUB BMX.SHOW
IF BMX.ERROR$ <> "" THEN PRINT BMX.ERROR$
```

The careful form, when you want the size before committing to a screen mode, or want to report a bad
file without the display already torn down:

```basic
BMX.FILE$ = F$
GOSUB BMX.OPEN
IF BMX.ERROR$ <> "" THEN GOTO COMPLAIN
' ... BMX.WIDTH, BMX.HEIGHT, BMX.PALUSED readable here ...
SCREEN 128
GOSUB BMX.PAINT
```

> **Set the screen mode BEFORE `BMX.PAINT`, not after.** `SCREEN` reloads the default palette, so a
> mode change after painting throws the image's colours away — right pixels, wrong colours, which
> reads as a corrupt file rather than a mistake.

**The palette is borrowed, not taken.** `BMX.PAINT` writes the picture's colours over the
machine's, and nothing on the X16 puts them back — not `SCREEN`, not the KERNAL's `screen_mode`. So
`BMX.PAINT` stashes all 256 entries in spare VRAM first, and `BMX.RESTORE` writes them back:

```basic
BMX.FILE$ = "TITLE.BMX"
SCREEN 128
GOSUB BMX.SHOW
' ... the title screen ...
GOSUB BMX.RESTORE
```

A program that owns the machine can simply never call it. One that hands the machine back — to
BASIC, or to the next program in a chain — calls it and is done. It is safe at any time: nothing
kept means nothing to do, so a program whose picture failed to load can still call it on the way
out. All 256 entries are kept rather than the range the file claims, and kept **once per run**,
which is what makes a slideshow restore what the machine had rather than the previous picture's
leftovers.

`BMX.STASH` is where they go — VRAM `$13000` by default, free above the 320×240 framebuffer in the
mode this module paints into. A caller with tiles, sprites or a second bitmap up there must move it,
or switch it off with `BMX.STASH = -1`. It is checked rather than trusted: a stash inside the bitmap
or running into the PSG registers is reported, and nothing is painted.

> **`-1` and not `0` to switch it off.** Zero is what the variable holds before anyone has touched
> it, and `BMX.INIT` runs at the first `BMX.OPEN` — long after a caller would have set it — so `0`
> has to keep meaning "never set".

**8 bits per pixel, uncompressed**, which is what `SCREEN 128` shows without a decompressor. Anything
else is reported, not attempted. The image is centred; larger than 320×240 is clipped.

Examples: [`BMXVIEW.EXP.BL`](BMXVIEW.EXP.BL), and [`BMXPAL.EXP.BL`](BMXPAL.EXP.BL) for the palette

### 4.6 `MENUHELP.INC.BL` — a vertical menu

| Routine | in | out |
|---|---|---|
| `MENUHELP.RUN` | the variables below | `MENUHELP.SEL` `MENUHELP.KEY` |
| `MENUHELP.DRAW` | the same | draws the menu without driving it |
| `MENUHELP.ROW` | `MENUHELP.DRAWROW` `MENUHELP.DRAWATTR` | one row, in the attribute you name |

**This replaces the `GP.MENU` and `GP.SEL` keywords**, withdrawn at RT_ABI 20. They were 462 bytes of
assembly plus 11 of storage, in a block every GPB program carried whether it had a menu or not. The
assembly existed because the highlight had to move without the runtime knowing what text was
underneath it, so it swapped the cell's attribute nibbles instead of redrawing. A menu written in
BASIC **owns the item array**, so it can simply print the row again — and the whole reason for the
assembly goes with it.

It is not slower in any way a person can see. The nibble swap was 59 cycles a cell; `GP.FILL` is 31
and `GP.PRINTAT` 94, so redrawing two rows costs about a millisecond against the swap's half, against
a 16.7 ms frame.

| in | |
|---|---|
| `MENUHELP.X` `.Y` | top left of the **first row**, not of a frame — draw the border yourself with `GP.BOX`, so the menu owes nothing to one style of border |
| `MENUHELP.WIDTH` | cells wide. This is the width of the **highlight**, so it is the width of the menu whatever the text happens to do |
| `MENUHELP.COUNT` | how many rows |
| `MENUHELP.ITEM$()` | the rows, `1..COUNT` — **the caller owns the `DIM`**, see below |
| `MENUHELP.ATTR` | packed attribute, `background * 16 + foreground` |
| `MENUHELP.HIATTR` | the same for the highlighted row. **0 means invert `MENUHELP.ATTR`**, which is what `GP.MENU` always did |
| `MENUHELP.HOT$` | one character a row, `""` for none |
| `MENUHELP.HOTATTR` | paint the hotkey letter in this attribute. **0 is off, and off is the default** |
| `MENUHELP.FLAGS` | added together, below |
| `MENUHELP.SEL` | the row to start on; 0 starts at 1 |

| out | |
|---|---|
| `MENUHELP.SEL` | `1..COUNT`, or **0 if cancelled** |
| `MENUHELP.KEY` | the key that ended it — 13 chose, 27 cancelled, or the hotkey itself |

```basic
MENUHELP.X = 8 : MENUHELP.Y = 6
MENUHELP.WIDTH = 24 : MENUHELP.COUNT = 4
MENUHELP.ITEM$(1) = " NEW GAME"           ' ... and so on
MENUHELP.ATTR = THEME.CLR(THEME.TEXT)
MENUHELP.HIATTR = THEME.CLR(THEME.HILITE)
MENUHELP.HOT$ = "NLOQ"
GOSUB MENUHELP.RUN
IF MENUHELP.SEL = 0 THEN GOTO CANCELLED
```

| Key | |
|---|---|
| cursor up / down | move |
| RETURN | choose |
| ESC or STOP | cancel |
| a hotkey | chooses its row at once |

| flags, added together | |
|---:|---|
| 1 | **must select** — ESC does not cancel |
| 2 | **keep mark** — leave the chosen row highlighted on the way out |
| 4 | **no wrap** — stop at the ends instead of wrapping round |
| 8 | **gamepad** — drive it from the SNES pad in port 1 as well as the keyboard |

The constants `MENUHELP.MUSTSEL`, `.KEEPMARK`, `.NOWRAP` and `.GAMEPAD` are defined for you; add
those rather than writing the numbers.

**A hotkey chooses its row, it does not merely move to it** — which is the entire point of having
one. `MENUHELP.HOT$` is one character per row in order, matched without case; it may be shorter than
`MENUHELP.COUNT`, in which case the later rows have none.

**`MENUHELP.HOTATTR` makes the shortcut visible** instead of leaving it a secret. The letter is found
in the row's own text — the first match for that row's `MENUHELP.HOT$` character, without case — so
nothing extra is passed in, and `" START"` with hotkey `S` needs no markup. A row whose text does not
contain its own hotkey is left alone rather than treated as an error, because the hotkey still works.
Only rows in the **normal** attribute are tinted: on the selected row the highlight *is* the message,
and a second colour inside the bar is noise.

> **The caller owns the `DIM`, deliberately.** A module cannot be handed an array in BASIC, so it has
> to name one — and if it `DIM`med that array itself it would have to guess a bound, then fail on the
> caller who wanted more. Leave `MENUHELP.ITEM$` undimensioned and GPC's implicit `DIM` gives you
> 0..10, a ten-row menu for free; `DIM` it yourself for more. **What you must not do is both.**

#### The gamepad flag

With flag 8, up and down move the highlight and **B or Start** chooses. Cancel stays on the
keyboard — ESC and STOP have no pad equivalent that would not be a guess, and a *must select* menu
has no cancel anyway.

**Port 1, the physical pad — not port 0.** Port 0 is the keyboard presented as a joystick, and the
menu already reads the keyboard directly, so reading both would move the highlight *twice* for one
press of a cursor key. Port 0 is also the unreliable half of the pair: it reports "absent" on roughly
half of all reads (measured in AlienAirlift — 2,060 negative against 2,057 valid over 14 seconds).

**One step per press, no auto-repeat.** The wait loop spins as fast as the CPU allows, so the pad is
edge-triggered; holding a direction moves once. A menu is short, and a wrong guess at a repeat rate
is worse than no repeat. A button still held from whatever *opened* the menu is not read as a fresh
press either, so a menu cannot answer itself on the way in.

With no pad plugged in the flag costs nothing and changes nothing — the pad is consulted only when
the keyboard is quiet, and an absent pad reads as "nothing held". In the emulator a real pad needs
`-joy1`, which binds physical hardware and does **not** map the keyboard.

Examples: [`MENUDEMO.EXP.BL`](MENUDEMO.EXP.BL) on its own, [`MENU.EXP.BL`](MENU.EXP.BL) inside a
whole small application, and [`MENUTST.EXP.BL`](MENUTST.EXP.BL) for the 21-case regression test.

---

## 5. Variables

**BASL has one flat namespace and nothing else.** No locals, no scoping, no parameters. Every
variable in every `#INCLUDE`d module is visible to your program and vice versa, and nothing warns
you: **a collision is a wrong answer, not an error.**

> **One module, one dotted prefix, and nothing writes outside its own.**

### Prefixes already taken

| Prefix | Owner |
|---|---|
| `GP.` | keywords, **not variables** — see below |
| `STRHELP.` | `STRHELP.INC.BL` |
| `THEME.` | `THEME.INC.BL` |
| `APPHELP.` | `APPHELP.INC.BL` |
| `INPHELP.` | `INPHELP.INC.BL` |
| `MENUHELP.` | `MENUHELP.INC.BL` |
| `BMX.` / `BMXK.` | `BMX.INC.BL` (variables / its KERNAL constants) |

Pick anything else for your own program — `GAME.`, `MAP.`, `AIRLIFT.`. **A prefix costs nothing at
runtime**, because BASLOAD crunches every identifier down to a short BASIC variable: a long readable
name and a two-letter one compile to exactly the same thing.

**Do not reuse a taken prefix even for something the module has not defined.** `THEME.MINE` looks
free today; it is one library update away from not being.

### `GP.*` is keywords, not variables

`GP.INC.BL` defines **no variables at all** — 27 `#TOKEN` lines and nothing else.

```basic
GP.A = 5          ' SYNTAX ERROR — GP.A is a keyword
X = GP.A          ' correct
```

The value words are `GP.A` `GP.X` `GP.Y` `GP.C` — the registers after `GP.CALL`, and now the whole
list of them. They are tokens rather than variables for a hard reason: **nothing in the runtime
can write a BASIC variable by name**, so a command that hands a value back has to hand it back
through a keyword. X16's own `ST`, `MX` and `MY` exist for the same reason.

### Nothing here is re-entrant

A module's parameters **are** its globals; there is nowhere else to put them. So `INPHELP.GET` cannot
be called from inside itself, `BMX.OPEN` cannot nest, and a `GOSUB` from inside a module into code
that calls the same module corrupts it silently. In practice this only bites if you write a callback
— copy the values you care about into your own variables first. `THEME.*` is the exception:
`THEME.LOAD` only writes.

### Labels are global too

Every `NAME:` is a jump target in the same flat space, internal ones included —
`BMX.STREAM.MORE`, `INPHELP.REDRAW`, `THEME.LOAD.DARK`. Each module also has a skip label it jumps
over itself with (`THEME.SKIP`, `APPHELP.SKIP`, `STRHELP.SKIP`, `BMX.MODULE.END`,
`INPHELP.MODULE.END`). **Do not branch to one.**

**BASLOAD refuses a name used as both a label and a variable** (`BASLOAD.MD:319`) — which is why
`BMX`'s skip label is `BMX.MODULE.END` and not `BMX.SKIP`: that name was already the byte-skip
counter.

**→ The complete per-module in / out / internal register is [GP-BASIC.GLOBALS.md](GP-BASIC.GLOBALS.md),
with a script in §7 for re-checking it after a change.**

---

## 6. The traps, collected

Every one of these has cost a debugging session at least once.

| Trap | What happens | Do this |
|---|---|---|
| `P AND 255` on a heap or VRAM address | `AND` is **16-bit signed**; above 32767 it raises `OUT OF RANGE` instead of masking | `H = INT(P/256) : L = P - H*256` |
| `$0400` for machine code | stock BASIC leaves it free, **a compiled GPC program does not** — runtime state lives there, and it corrupts silently | banked RAM, `$A000`–`$BFFF` |
| `PRINT` after `GP.PRINTAT` | GP drawing never calls the KERNAL, so the cursor is wherever it was | `LOCATE` first, or stay in one world |
| `GOTO` out of a `GP.SELECT` | `GP.ENDSEL` releases the frame; jumping past it leaks one per pass | a flag, tested after `GP.ENDSEL` |
| `GOTO` out of a `GP.DO` | abandons the loop frame | `GP.EXITDO` |
| `GP.SORT A$` | `A$` and `A$()` are different variables — it sorts the scalar, i.e. nothing | `GP.SORT A$()` |
| `GP.BOX X,Y,W,H,,7` | optionals cannot be skipped over | `GP.BOX X,Y,W,H,0,7` |
| `SCREEN` after `BMX.PAINT` | reloads the default palette and throws the image's colours away | set the mode first |
| `DIM THEME.CLR(...)` | the module owns it; re-`DIM`ing is an error | leave it alone |
| `STRHELP.FIELD$` wanted bigger | auto-`DIM`ed at 0..10 on first use, and you cannot `DIM` it after | `DIM` it **before** the first call, set `STRHELP.MAX` |
| `#DEFINE X 129536` | `#DEFINE` takes an **INT16** — `ERROR: INVALID PARAMETER` | an ordinary variable |
| `RPT$(c, 0)` | raises `ILLEGAL QUANTITY` — it does not return `""` | guard the zero case |
| a `GP.` keyword in a hand-written `.bas` | the ROM cannot `LIST` or `RUN` a `$CE7x` token | expected — compile it |
| readable names in a hand-written `.bas` | **the built-in BASIC gives TWO significant characters** — `THEME.CLR` and `THEME.COUNT` become one variable, silently | write BASL, or give every variable a distinct first two characters |

The last one is worth its own sentence. **Inside BASL you are safe** — 64 significant characters, so
`PANEL.COL` and `PANEL.ROW` are genuinely different variables and the readable names cost nothing.
Write the same test as a raw `.bas` for the host tokeniser and the two-character rule is back. It
cost two test cycles during tier 6, both times looking exactly like a compiler bug.

Dotted names also dodge the keyword-collision trap: `MENUHELP.COUNT`, `THEME.CLR`, `INPHELP.LEN` and
`INPHELP.RETURN` all contain reserved words and all work, because BASLOAD matches the whole
identifier. An **undotted** one does not — `POS`, `MB`, `ST`, `LEN`, `CHAR` cannot be variables at
all. That is the main reason the library is dotted throughout.
