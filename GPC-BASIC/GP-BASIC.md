# GP.BASIC — reference manual

Reference for GPC's `GP.*` keyword set and the BASL library built on it: every command, every
routine, and every variable each one reads and writes.

`GP` is Greased Piglet. GPC is the Greased Piglet Compiler, GP.BASIC (GPB) its keyword extension;
`GPC SQUEALING...` on the compiler's first line is the same joke.

| If you want | Read |
|---|---|
| what a command does and how to write it | §3 and §4, here |
| what names are already taken before you invent one | §5 here, then [GP-BASIC.GLOBALS.md](GP-BASIC.GLOBALS.md) for the full register |
| why a thing was built the way it was | `docs/blitz/GP-BASIC.TIERS.md` — the build plan and every measurement, in the source repository |
| the original design argument | `docs/blitz/GP-BASIC.PLAN.md`, in the source repository |
| the files themselves | beside this one, listed in [README.md](README.md) |

---

## 1. What GP.BASIC is

Three layers, innermost first.

**Core keywords.** 30 of them, compiled to p-code and handled by assembly in the runtime:

    GP.DO GP.LOOP GP.EXITDO
    GP.IF GP.ELSEIF GP.ELSE GP.ENDIF
    GP.SELECT GP.CASE GP.OTHER GP.ENDSEL
    GP.INSTR GP.COMP GP.STRPTR GP.ARRPTR
    GP.BOX GP.FILL GP.CHAR GP.PRINTAT
    GP.CALL GP.A GP.X GP.Y GP.C
    GP.ASM GP.ENDASM

They are assembly because BASIC is slow at per-character string scans, screen fills and VERA writes.

The handlers occupy `GPBase $3800` to `ObjectBase $3c00`: 1,024 bytes, page aligned, all or nothing.
`ScanGPUsage` walks the finished p-code and drops the whole block from the object if nothing in it
is reached.

The block costs those 1,024 bytes once. The bytes in the object and the bytes off the workspace
floor are the same bytes — `runtimeEndPage` is a single page number that decides how much of the
runtime image is written out, where the p-code lands, and where the workspace starts. Maximum
p-code is 17,152 bytes with the block and 18,176 without: `ObjectBase` to `$9F00`, less the 4K
frame stack and the 4K minimum workspace.

**Composites.** `GP.CONTAINS`, `GP.ISEMPTY`, `GP.HIBYTE`, `GP.LOBYTE`. The compiler expands each
into opcodes that already exist. No handler, no vector slot, nothing in the block.

**The library.** `GPC-BASIC/`: 14 `.INC.BL` modules, 22 `.EXP.BL` examples. Ordinary BASL,
`#INCLUDE`d by path, called with `GOSUB`. Zero runtime bytes — a module costs its own p-code, in the
programs that include it. Menus vertical and bar, panels, themes, entry fields, in-place case, trim
and splice, shell sort, a screen rectangle to a RAM bank or a file, BMX into VERA.

`STASH.INC.BL`, `SORT.INC.BL`, `STRCASE.INC.BL` and `STRINGS.INC.BL` are `GP.ASM` and still
modules: as keywords their bytes would sit in the block, paid by every GP program. `GP.ARRPTR` and
`GP.STRPTR` are what lets them out — a BASL subroutine takes an address, not an array or a string.

The division is assembly for loops and bulk moves, BASIC for everything else. `LINEINPUT.GET`
waits on the keyboard, so speed does not apply to it; writing it in BASL saved 166 runtime bytes.

---

## 2. Using it

Every BASL source that uses a `GP.` keyword must declare the keyword set:

```basic
#INCLUDE "GPB.INC.BL"
```

BASLOAD knows only the ROM's keywords. Without that line `GP.DO 5` is a syntax error. The
PC-side converter for hand-written `.bas` needs no such declaration; it reads the same keyword
list from `c64tokens.py` at build time.

### Where the library lives

Keep `GPC-BASIC/` as a folder beside your own sources and include from it by path:

```basic
#INCLUDE "/GPC-BASIC/GPB.INC.BL"
```

`#INCLUDE` accepts a path as well as a bare filename. Verified on R49 for both absolute
(`/GPC-BASIC/GPB.INC.BL`) and relative (`GPC-BASIC/GPB.INC.BL`) forms. Use the leading slash: it is
absolute from the drive root and still resolves when the program sits in a subdirectory. `../` and
`//` are not understood by the filesystem, so a path descends and never rises.

Then BASLOAD and GPC as usual: `BASLOAD "MYPROG.BL"`, then compile the resulting PRG with
`GPC.PRG`.

### A program that uses GP.BASIC is compile-only

One GP.BASIC keyword is enough. BASLOAD encodes them as the byte pairs `$CE58`-`$CE7F` and stock
BASIC has no handler behind them, so the ROM can neither `LIST` nor `RUN` the result. It is compiler
input.

Run `GPC.PRG` on BASLOAD's `.PRG`, then run the object it writes.

### Numbers, and what a variable holds

One numeric type on the evaluation stack: a 4-byte mantissa, a 1-byte exponent and a status byte
carrying the sign. Exponent 0 means the value is an exact integer.

| Variable | Bytes | Holds |
|---|---:|---|
| `A` `A()` | 6 | mantissa, exponent, status. Exact integers while the exponent is 0 |
| `A%` `A%()` | 2 | signed 16-bit two's complement, **-32,768 to 32,767** |
| `A$` `A$()` | 2 | a pointer into the string heap |

`%` is smaller, not faster, and it truncates without raising an error. `WriteInteger` stores the
low two bytes of the value on the stack; `ReadInteger` sign-extends the MSB. `A% = 49152` reads back
as -16,384. Use `%` for counters, indices and screen coordinates.

Do not use `%` for an address. Main RAM runs to `$9F00` (40,704), the string heap is above 32,767 by
definition, and a VRAM address is 17 bits (up to 131,071). Hold an address in an untyped variable,
which represents all three exactly, or split it into page and offset.

Numeric literals above 65,535 are accepted. The compiler has a 16-bit fast path for constants;
anything wider compiles through the float encoder. Neither wraps.

`AND` and `OR` are 16-bit signed and raise `OUT OF RANGE` above 32,767; see §6.

---

## 3. Command reference

38 keywords, encoded `$CE7F` down to `$CE50` and allocated downward. Ten of the forty-eight slots
are holes and stay holes: the byte values are the ABI and are never renumbered.

### At a glance — where each part comes from

Three implementations, and what each costs:

- **ASM** — a keyword run by machine code in the runtime. Costs runtime bytes, and one GP keyword
  anywhere in a program pays for the whole 1,024-byte block. Documented in §3.
- **BASIC** — a `.INC.BL` module of ordinary BASL, called with `GOSUB`. Costs nothing unless
  `#INCLUDE`d, and then only its own p-code. Documented in §4.
- **COMPOSITE** — a keyword with no machine code of its own; the compiler expands it into keywords
  that already exist. Costs the runtime nothing. Documented in §3 with the ASM keywords.

| | | |
|---|---|---|
| **Loops** | ASM | `GP.DO` `GP.LOOP` `GP.EXITDO` |
| **Multi-way branch** | ASM | `GP.SELECT` `GP.CASE` `GP.OTHER` `GP.ENDSEL` |
| **Block IF** | ASM | `GP.IF` `GP.ELSEIF` `GP.ELSE` `GP.ENDIF` — see §3.8 |
| **Machine code** | ASM | `GP.CALL` `GP.A` `GP.X` `GP.Y` `GP.C` |
| **Inline assembly** | COMPOSITE | `GP.ASM` `GP.ENDASM` — free, and stays GP-BASIC OUT, see §3.9 |
| **Strings** | ASM | `GP.INSTR` `GP.STRPTR` `GP.COMP` |
| **Strings** | COMPOSITE | `GP.CONTAINS` `GP.ISEMPTY` — free, see §3.4 |
| **Addresses** | COMPOSITE | `GP.HIBYTE` `GP.LOBYTE` — free, see §3.3 |
| **Arrays** | ASM | `GP.ARRPTR` |
| **Banked text** | ASM | `GP.BANKEDSTR` `GP.ENDBANKEDSTR` `GP.BSTR` · `GP.BSTRCOUNT` is COMPOSITE — see §3.10 |
| **Routine calls** | COMPOSITE | `GP.DEFPROC` `GP.SUB` — free, and stays GP-BASIC OUT, see §3.11 |
| **Routine calls** | ASM | `GP.FN` — the same call as a value, and it brings the GP block in |
| **Screen** | ASM | `GP.BOX` `GP.FILL` `GP.PRINTAT` |
| **Screen** | COMPOSITE | `GP.CHAR` — free, one cell in `GP.PRINTAT`'s shape running `GP.FILL`'s handler |
| **Colour roles** | BASIC | `THEME.INC.BL` — `THEME.SELECT`, `THEME.CLR()` · §4.1 |
| **String helpers** | BASIC+ASM | `STRINGS.INC.BL` — `PADR` `PADL` `PADC` `SPLIT` `REPLACE` `SPLICE` `PET2SCR` `TRIM` `LTRIM` `RTRIM` · §4.2 |
| **Screen etiquette, panels** | BASIC | `APPSYS.INC.BL` — `STARTUP` `RESTORE` `PANEL.SAVE/LOAD/PUT` `ISEMU` · §4.3 |
| **Entry fields** | BASIC | `LINEINPUT.INC.BL` — `LINEINPUT.GET`, `LINEINPUT.ASK` · §4.4 |
| **Bitmaps** | BASIC | `BMX.INC.BL` — `BMX.SHOW`, `BMX.RESTORE` · §4.5 |
| **Menus** | BASIC | `MENUVERT.INC.BL` — `RUN` `DRAW` `ROW` `HOTFIND` · §4.6 |
| **Menus** | BASIC | `MENUBAR.INC.BL` — `RUN` `DRAW` `ITEM` `MARK` `WHERE`, the other axis · §4.9 |
| **Dialogs** | BASIC | `GUI.INC.BL` — `GUI.SAY` `GUI.YN` `GUI.MENU` `GUI.INPUT` `GUI.OPEN` `GUI.CLOSE` · §4.11 |
| **Dialogs** | BASIC | `GUI2.INC.BL` — `GUI.LISTBOX`, single or multi select · §4.12 |

The rule is in §1: assembly for tight loops and bulk data moves, BASIC for everything else, and a
composite for anything that is only a spelling of keywords already present. A menu waits on a human,
so `MENUVERT` is BASIC; as a keyword it would cost every GP program 462 bytes whether or not it used
a menu.

---

The keywords in detail. Square brackets mean optional. Optionals cannot be skipped over:
`GP.BOX X,Y,W,H,,7` is a syntax error — write out the default you are passing through.

### 3.1 Loops

```
GP.DO [count]
    ...
GP.LOOP
```

Counted loop, modelled on prog8's `repeat`. A count of 0, or no count, loops forever. Loops nest.

```
GP.EXITDO
```

Leaves the innermost `GP.DO`, closing its stack frame. A `GOTO` out of a `GP.DO` closes its frames
too — see §3.2 — but `GP.EXITDO` is two bytes and needs no branch target.

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
GP.SELECT <var>
GP.CASE <expr> [,<expr> ...]
    ...
GP.OTHER
    ...
GP.ENDSEL
```

The selector must be a plain numeric variable. It is re-read at each `GP.CASE`, the tests run in
the order written, and the first match wins. `GP.OTHER` is optional; if nothing matches and there is
no `GP.OTHER` the select is skipped, which is not an error.

An expression, a constant or an array element is refused at compile time. Assign to a scalar first:
`T = RND(1)*3 : GP.SELECT T`. A scalar is a fixed slot, so the re-read yields the same value every
time. The restriction is what lets the construct compile to core opcodes only — a program whose one
GP keyword is a select does not carry the GP block, as with `GP.IF`.

Case values are numeric expressions, not only constants. prog8's `when` requires compile-time
integers.

`GP.ENDSEL` is required. Nothing needs cleaning up; the requirement is structural. The compiler has
no symbol table, the emitted keywords are the block, and every case branch resolves by scanning
forward to it.

A case body may take its statements on the same line, after a colon:

```basic
GP.SELECT ED.KEY
  GP.CASE 157 : GOSUB ED.MOVE.LEFT
  GP.CASE 29  : GOSUB ED.MOVE.RIGHT
  GP.CASE 27  : MENU.ACTIVE = 0 : GOSUB ED.OPEN.MENUBAR
  GP.OTHER    : GOSUB ED.KEY.RANGE
GP.ENDSEL
```

More than one statement after the colon is allowed, and so is `GP.OTHER`. The body may also go on
the following lines. Both forms compile to the same code.

`GOTO` out of a select is safe: a select holds nothing open. `GP.DO` is the one block that opens a
stack frame, and a `GOTO` leaving one is handled — the compiler emits an `.unwind` before it and
`FixBranches` fills in how many loop frames it closes. No runtime bytes; two p-code bytes at the
`GOTO`. The case it cannot handle is a `GOTO` from inside one `GP.DO` into another at the same
depth: the depth difference is zero, nothing is closed, and the frame survives.

`GP.SELECT` does not replace `ON x GOTO/GOSUB`, which is a jump table and remains correct for a
dense `1..n` index. Use `GP.SELECT` for a sparse selector — key codes, state machines, bit depths —
where `ON` does not apply.

```basic
GP.SELECT BMX.DEPTH
    GP.CASE 8
    GP.CASE 1, 2, 4
        BMX.ERROR$ = "NEEDS ANOTHER SCREEN MODE"
    GP.OTHER
        BMX.ERROR$ = "BAD BIT DEPTH"
GP.ENDSEL
```

An empty case body, `8` above, matches and falls out of the select. It is the cheapest way to say
that a value is acceptable.

Example: [`SELECT.EXP.BL`](SELECT.EXP.BL)

---

### 3.3 Machine code

```
GP.CALL address [,a] [,x] [,y] [,carry]
GP.A   GP.X   GP.Y   GP.C
```

Calls machine code with the registers set. All four arguments are optional and default to 0. The
four value words read the registers back afterwards.

They are keywords, not variables: `X = GP.A` reads, `GP.A = 5` is a syntax error. They share `SYS`'s
`$030C`–`$030F`, so they also read what a plain `SYS` left behind.

```basic
GP.CALL $FF5F, 0, 0, 0, 1          ' KERNAL screen_mode, carry set = report
COLS = GP.X : ROWS = GP.Y
```

Put machine code in banked RAM, `$A000`–`$BFFF`, not at `$0400`. Stock X16 BASIC leaves `$0400`
free for the user; a compiled GPC program does not. That page holds runtime state
(`stringHighMemory`, `storeStartHigh`, `variableStartPage`), and code POKEd over it corrupts the
program without raising an error.

#### Splitting an address — `GP.HIBYTE` / `GP.LOBYTE`

| Form | Does |
|---|---|
| `GP.HIBYTE(n)` | `INT(n / 256)` — which 256-byte page. **Composite** |
| `GP.LOBYTE(n)` | `MOD(n, 256)` — the offset within it. **Composite** |

A 6502 address is sixteen bits and everything that consumes one takes eight bits at a time:
`GP.CALL`'s registers, VERA's `$9F20`/`$9F21`. Every address passed from BASIC to machine code is
therefore split. `GP.STRPTR` and `GP.ARRPTR` produce the addresses to pass:

```basic
P = GP.STRPTR(A$)
GP.CALL $A000, GP.LOBYTE(P), GP.HIBYTE(P)
```

Do not write `P AND 255` for the low byte. `AND` is 16-bit signed in GPC, and any address worth
splitting is above 32,767 (the string heap always is), so it raises `OUT OF RANGE` rather than
masking. `GP.LOBYTE` is built on `MOD`, which uses the full 32-bit divide.

Range is 0–65,535, which covers every address on the machine. Both are composite: no runtime code,
compiling to `INT(n/256)` and `MOD(n,256)`.

Example: [`MLCALL.EXP.BL`](MLCALL.EXP.BL)

For anything longer than a few bytes use `GP.ASM` (§3.9) instead of `GP.CALL` and a POKE loop. It
assembles into the program: no bank to reserve, and no list of numbers to keep in step with a
comment.

---

### 3.4 Strings

Five keywords. `GP.INSTR` is the only string search GPC has; without it there is none.

Trimming, padding, splicing and case folding are modules, not keywords: `STRCASE.INC.BL` (§4.8)
for case, `STRINGS.INC.BL` (§4.2) for everything else. They cost p-code only in the programs that
`#INCLUDE` them and nothing in the GP block. `GP.STRPTR` is the keyword they are built on.

The in-place routines take an ADDRESS, `GP.STRPTR(a$)`, and never a literal: `GP.STRPTR("hello")`
is an address inside the p-code, so trimming it edits the running program. Case conversion leaves
digits, punctuation and PETSCII graphics unchanged.

There is no `GP.PAD`. In-place work cannot grow a string past the capacity it was created with,
which is what decides which side of `STRINGS.INC.BL` a routine lands on: the pads and `STR.SPLICE`
grow, so they are BASIC assignments and reallocate; the trims only shrink, so they are assembly.

Example: [`STRINGS.EXP.BL`](STRINGS.EXP.BL)

#### 3.4.1 `GP.INSTR` — position of a substring

```entry
  Syntax    GP.INSTR(hay$, needle$ [, start])
  Returns   Position of needle$ in hay$, 1-based. 0 if not found.
  Kind      ASM. Needs the GP block.
  Notes     start is the position to begin at. Default 1.
            Case sensitive. It compares raw bytes; §3.4.4 is the
            case-blind test.
            An empty needle$ returns 0.
  Example
```
```basic
            P = GP.INSTR(F$, ".BAS", 1)
            IF P > 0 THEN PRINT "FOUND AT"; P
```

#### 3.4.2 `GP.CONTAINS` — test for a substring

```entry
  Syntax    GP.CONTAINS(hay$, needle$)
  Returns   -1 if needle$ occurs anywhere in hay$, 0 if not.
  Kind      COMPOSITE. Expands to GP.INSTR(hay$, needle$) <> 0, and
            compiles to the same object. Use whichever reads better.
  Notes     Case sensitive, as §3.4.1 is.
            An empty needle$ returns 0, not -1, because GP.INSTR
            reports not-found for one.
  Example
```
```basic
            IF GP.CONTAINS(F$, ".BAS") THEN GOSUB LOAD.IT
```

#### 3.4.3 `GP.ISEMPTY` — test for a zero-length string

```entry
  Syntax    GP.ISEMPTY(a$)
  Returns   -1 if a$ has zero length, 0 if not.
  Kind      COMPOSITE. Expands to LEN(a$) = 0.
  Notes     A string of spaces is not empty. STR.TRIM first if
            that is the intent.
            GP.ISEMPTY(a$), LEN(a$) = 0 and a$ = "" are the same four
            bytes. Use whichever reads better.
```

#### 3.4.4 `GP.COMP` — compare two strings, ignoring case

```entry
  Syntax    GP.COMP(a$, b$)
  Returns   -1 if a$ sorts before b$, 0 the same, 1 after.
  Kind      ASM. Needs the GP block.
  Notes     Case is ignored. GP.COMP(A$, B$) = 0 is the case-blind
            equality test that = cannot do, and the same call orders
            a sort.
            Length breaks a tie: "abc" sorts before "ABCD".
  Example
```
```basic
            IF GP.COMP(N$, "QUIT") = 0 THEN GOTO BYE
```

#### 3.4.5 `GP.STRPTR` — address of a string block

```entry
  Syntax    GP.STRPTR(a$)
  Returns   Address of the string's [ActLen][Data] block.
  Kind      ASM. Needs the GP block.
  Notes     The length byte is at the address, the first character at
            +1, the block capacity at -2.
            With GP.CALL, machine code can fill a string in place and
            set its length. Stock BASIC cannot do that.
  WARNING   Split the address with GP.LOBYTE / GP.HIBYTE (§3.3),
            never with P AND 255. AND is 16-bit signed and the string
            heap is above 32,767, so P AND 255 raises OUT OF RANGE.
            The longhand H = INT(P / 256) : L = P - H * 256 is what
            the keywords compile to. The same applies to §3.5
            GP.ARRPTR and to any VRAM address in the top eighth of
            memory.
  Example
```
```basic
            P = GP.STRPTR(A$)
            GP.CALL $A000, GP.LOBYTE(P), GP.HIBYTE(P)
```

### 3.5 Arrays

```
GP.ARRPTR(a())
```

Sorting is `SORT.INC.BL` (§4.7) rather than a keyword: 408 bytes of the all-or-nothing GP block,
carried by every program whether or not it sorts. `GP.ARRPTR` is a keyword because the module needs
it — a BASL subroutine cannot be passed an array, so an address is the only interface.

`GP.ARRPTR` returns the address of element zero; the header is already skipped. Machine code called
through `GP.CALL` can then work on the array in bulk. Add the stride yourself: 2 bytes per element
for a string array (each element is a pointer to the string block — see `GP.STRPTR` for its layout),
6 for a numeric array. Multi-dimensional arrays are rejected, and `GP.ARRPTR(A(3))` is a syntax
error; write `3*2` or `3*6` into the address.

Example: [`ARRAYS.EXP.BL`](ARRAYS.EXP.BL)

---

### 3.6 Screen — stash and restore

Stashing a rectangle is `STASH.INC.BL`, written in `GP.ASM`, rather than a keyword. It writes a
4-byte self-describing header and holds at most 4,094 cells: a bank is 8K and a cell is two bytes,
so a full 80x60 screen at 9,600 bytes does not fit. As keywords it would take 329 bytes of the
all-or-nothing GP block in every program, stashing or not.

```
#SYMFILE "@:MYPROG.SYM"
#INCLUDE "STASH.INC.BL"
STASH.BANK = 8 : STASH.X = 10 : STASH.Y = 4 : STASH.W = 30 : STASH.H = 8
GOSUB STASH.SAVE
...
GOSUB STASH.RESTORE
```

`STASHFILE.INC.BL` is the same rectangle through a file. It is a separate module because BASL has
no dead code elimination: everything a module holds is compiled into every program that includes it,
called or not.

**More than one rectangle in a bank.** `STASH.SLOT` is a byte offset into the bank, default 0, and
`STASH.NEXT` comes back as the offset just past what was written. Feed one into the other and the
bank holds a stack of rectangles — which is what nested dialogs want, one bank for the lot rather
than one bank a level. Nothing checks that two saves do not overlap: the header describes a
rectangle's size, not its identity, so the offsets are yours to keep straight.

**`STASHVRAM.INC.BL` keeps rectangles in spare VRAM instead**, addressed by handle so a program can
hold many at once without counting offsets. It needs **no `#SYMFILE`**, because there is no
`GP.ASM` in it: the cells never leave VRAM, so one data port reads, the other writes, and
`memory_copy` moves between them. It executes no `BANK` either, so unlike `STASH` it runs inside a
`GP.BANKED` region. `STASHVRAMGC.INC.BL` closes the holes if a caller frees out of order, and is a
third file for the same dead-code reason.

---

### 3.7 Screen — drawing

```
GP.BOX x, y, w, h [,style] [,col]
GP.FILL x, y, w, h, char [,col]
GP.PRINTAT x, y, text$ [,col]
```

All three write directly to VERA and call no KERNAL routine, which is why they are several times
faster than `PRINT`. GPC's character output makes two KERNAL calls per character, and `BSOUT`
carries scroll, quote mode and cursor handling.

`GP.BOX` draws the frame only. Styles: 0 solid block, 1 single line, 2 single line with rounded
corners, 3 thick line. A style of 256 or more is an ADDRESS, not a style: eight screen codes of the
caller's own, in the table's order — see the custom glyph note below. `char` in `GP.FILL` is
PETSCII, e.g. `ASC(" ")`.

The colour argument is optional. Omitted, it uses whatever `COLOR` last set, read from the KERNAL's
`$0376` — the colour a `PRINT` would have used. Supplied, it is one byte packed as the X16 packs it:
`background * 16 + foreground`. 255 is a real colour (light grey on light grey), not a
leave-unchanged marker.

These calls do not move the cursor `PRINT` uses. A `PRINT` after a `GP.PRINTAT` continues from
wherever the KERNAL's cursor was, not after the text just drawn. Use `LOCATE` first, or stay in one
world or the other.

Nothing is clipped. Drawing off the right edge wraps to the next row; off the bottom writes past the
end of the screen map. Zero width or height draws nothing, which is what a computed size reaches
when it collapses.

#### ISO mode is handled for you

In ISO mode — `PRINT CHR$(15)`, or Ctrl+O — the VERA tile index is the character code, so
translating PETSCII to a screen code is wrong rather than merely wasteful: `A` would be written as
`$01`. `GP.PRINTAT` reads the KERNAL's ISO flag (bit 6 of `$0372`) per character and skips the
translation when it is set. A program that switches charset needs no source change and nothing to
declare. The test costs 7 cycles a cell in PETSCII mode and saves 34 in ISO.

`GP.FILL` needs no test: it converts its single character before the loop, and `$20` is a fixed
point of the translation, so a space fill — padding and blanking — is correct in both modes.

`GP.BOX` is the one case that needs the caller to act. It does no translation at all; its glyphs go
to VERA as tile indices, so the four built-in styles are PETSCII screen codes and appear as letters
in ISO mode. Translation cannot fix this, because ISO-8859-15 has no box-drawing characters to
translate to. A style value of 256 or more is instead the address of eight glyphs, and in ISO mode a
tile index is a character code, so ASCII `+ - |` make a usable frame:

```
ISO.GLYPH$ = "++++--||"                        ' TR TL BR BL TOP BOTTOM LEFT RIGHT
GP.BOX 50, 26, 4, 3, GP.STRPTR(ISO.GLYPH$) + 1, 1
```

`GP.STRPTR` returns the address of the string block and the text starts at +1, so a string literal
is the cheapest way to carry the eight bytes. This costs no runtime bytes; the pointer form already
exists, and `samples/editor` uses the same mechanism to draw frames from a re-ordered font.

`ISO.EXP.BL` tests all of this, reading cells back with `VPEEK` rather than trusting the display.
The ISO box corner, top edge and side read back as 43, 45 and 124.

Example: [`SCREEN.EXP.BL`](SCREEN.EXP.BL)


---

### 3.8 Block IF

```
GP.IF <expr> THEN
    ...
GP.ELSEIF <expr> THEN
    ...
GP.ELSE
    ...
GP.ENDIF
```

Each of the four keywords is alone on its line, and `THEN` is required. There is no one-line form:
`GP.IF X > 5 THEN PRINT` is a syntax error. Allowing it would mean a block that swallowed every line
down to the next `GP.ENDIF`. Stock `IF ... THEN` is unchanged and remains the one-line form.

`GP.ELSEIF` may repeat any number of times; `GP.ELSE` is optional. The first true condition wins and
nothing below it runs, so there is no break to omit. If nothing matches and there is no `GP.ELSE`
the block is skipped, which is not an error. Conditions are numeric expressions.

`GP.IF` and `GP.SELECT` cover different cases. A select fetches one value and compares it against
each alternative — a sparse key code, a state machine. A block IF tests a different condition in
every branch: ranges, compound conditions, a string in one arm and a number in the next.

`GP.ENDIF` is required, but unlike `GP.ENDSEL` it does no work: the condition is evaluated and
consumed on the line it is written, so there is no frame to release and a `GOTO` out of a `GP.IF` is
safe. Omitting `GP.ENDIF` stops the compile with `STRUCTURE IMBALANCE`.

```basic
GP.IF N < 0 THEN
    PRINT "NEGATIVE"
GP.ELSEIF N = 0 THEN
    PRINT "ZERO"
GP.ELSE
    PRINT "POSITIVE"
GP.ENDIF
```

IFs nest freely — inside each other, inside a `GP.CASE` body, and inside a `GP.DO` loop.

It costs 14 runtime bytes, none of them code. All four p-code opcodes reuse existing handlers: the
two branches are `.goto.z` and `.goto` under different names, and the two markers share one four-byte
no-op. See §11 of `docs/blitz/GP-BASIC.TIERS.md`.

Example: [`IF.EXP.BL`](IF.EXP.BL)

---

### 3.9 Inline assembly

```
GP.ASM
REM <instruction>
...
GP.ENDASM
```

65C02 assembly, assembled by GPC at compile time, with the bytes placed in the program.

The alternative is to assemble by hand: work out the opcode for each instruction, `POKE` the numbers
into memory nothing else is using, and point `GP.CALL` at that address. These two do the same thing
— increment A, then X, then Y:

```basic
## by hand: 26, 232 and 200 ARE inc a / inx / iny, and ML has to be somewhere safe
POKE ML+0,26 : POKE ML+1,232 : POKE ML+2,200 : GP.CALL ML,10,20,30
```
```basic
## assembled: the bytes land in the program, and there is no address to find
GP.ASM
REM inc a
REM inx
REM iny
GP.ENDASM
```

It costs no runtime bytes. A block is five bytes of p-code plus the assembled instructions, and
every handler it uses is already in every compiled program. A program whose only GP.BASIC keyword is
`GP.ASM` compiles GP-BASIC OUT, without the 1 KB block: measured `RT 12031`, the same as a program
using no GP keyword.

#### `#REM 1` is required

The body rides in REM statements because BASLOAD stores REM text byte for byte. Outside a REM,
`ORA`, `AND`, `EOR` and `ROR` are BASIC keywords and the text is destroyed; inside one it arrives
intact, braces included. Lower case is accepted and upshifted.

`#REM 0` is BASLOAD's default and strips the body before the compiler runs. `GP.ASM` and
`GP.ENDASM` are real keywords rather than REMs so that the block is still found, empty, and GPC
reports `BLOCK MISMATCH` rather than compiling a program that contains no code. Set `#REM 0` again
after `GP.ENDASM`.

#### Labels and branches

A label is `name:`, alone on a line or in front of an instruction; six characters are significant.
Labels belong to their block — the same name in two blocks is two different labels, and neither can
branch to the other.

```basic
GP.ASM
REM ldx #5
REM loop: lda #42
REM jsr $ffd2
REM dex
REM bne loop
GP.ENDASM
```

`BNE`, `BEQ`, `BRA` and the rest take a label, as do `JMP` and `JSR`. A branch further than 127
bytes is `OUT OF RANGE` at compile time, reported on its own line, rather than a wrong address at
run time.

#### `{VAR}` — a BASIC variable's slot

`{VAR}` is the address of the variable's slot, so reading and writing use the same form: `LDA {N%}`
reads it, `STA {N%}` writes it, in the slot BASIC itself uses.

| Form | Is |
|---|---|
| `{N}` `{N%}` `{N$}` | the scalar's slot |
| `{N()}` | the **array's** slot, which holds the base address of its data — an element is two steps, as through `GP.ARRPTR` |

A name is letters, digits and dots, starting with a letter, up to 64 characters — the same limit as
BASLOAD. `{DOC.GOT.OFF}` works, so the dotted names used throughout the library are reachable from
assembly. Underscore is not accepted: BASLOAD allows it in a name, this does not, and `{A_B}` reads
the name as `A`.

`{VAR}` requires `#SYMFILE`. BASLOAD renames variables — `N%` becomes `A%`, which is how it provides
64 significant characters on a two-character BASIC — and it does not rename REM text with them, so
the code says `A%` while the REM still says `{N%}`. `#SYMFILE` is BASLOAD's record of that mapping
and the compiler reads it:

```
#SYMFILE "@:PROG.SYM"
```

Put it at the top of the source, named to match the PRG: compiling `PROG.PRG` reads `PROG.SYM`.
Nothing else changes — `{N%}` is still written with the name as authored.

Two compile-time errors, both naming the line:

| | means |
|---|---|
| `NO SYMBOL FILE FOR {}` | no `#SYMFILE`, or it is not beside the PRG under the matching name |
| `UNKNOWN VARIABLE IN {}` | the name is not a variable of this program |

`{VAR}` never creates a variable, unlike an ordinary BASIC reference. Assign the variable once in
BASIC first, even `M% = 0`. A name that does not exist otherwise resolves to a slot BASIC never
reads, and the block runs, stores, and changes nothing observable.

#### What is not there

No expressions: `{N%}+1` and `LABEL+2` are not understood. Use an index register.

Zero page or absolute is decided by the operand. `$34` is zero page, `$0034` is absolute, and a
decimal under 256 is zero page. Every 65C02 addressing mode is available, including the two the NMOS
6502 lacks — `LDA ($34)` and `JMP ($1234,X)` — except `BBR`, `BBS`, `RMB` and `SMB`.

Registers come back through `GP.A` / `GP.X` / `GP.Y` / `GP.C` as they do from `GP.CALL`; a block
uses the same `$030C`–`$030F` slots. Those four are GP block keywords, so reading one pulls in the
1 KB block that `GP.ASM` alone avoids. `{VAR}` does not.

A body can come from a file. `#INCLUDE` splices it in verbatim, and BASLOAD's `REM #nn-mm`
attribution makes an error inside it name the file:

```basic
#REM 1
GP.ASM
#INCLUDE "MACPTR.ASM"
GP.ENDASM
#REM 0
```

Example: [`ASM.EXP.BL`](ASM.EXP.BL)

### 3.10 Text in a bank

```basic
GP.BANKEDSTR <bank> <NAME>
  "first"
  "second"
GP.ENDBANKEDSTR

  A$ = GP.BSTR(<NAME>, n)
  N  = GP.BSTRCOUNT(<NAME>)
```

Moves a program's literal text out of low RAM and into a RAM bank, at compile time. A string
constant costs `2 + LEN` bytes of p-code wherever it appears; `GP.BSTR(NAME, n)` costs **5**, so
text of four characters or more is cheaper read from the bank than written in the line. Over half
of a menu-driven program's own code is usually literal text, and text is the one thing in a
program with no reason to be resident: it is never executed, never indexed, and read one item at a
time.

**The body is bare quoted lines.** One string a line, nothing else on the line, and they pass
through byte for byte — case, leading spaces and trailing spaces included. They are not `REM`
lines and must not be: BASLOAD upper-cases `REM` text.

**Blocks are named, and you may write as many as you like.** Each is indexed from zero within
itself, so inserting a line in one group moves nothing outside it. All the groups in a program
share one bank, which is why every block names the same one — written on each block rather than
only the first so a block can be read where it sits.

**The name costs nothing at run time.** It is resolved while the program compiles, into the
group's first index, and the compiler adds that to your index for you. No letter of the name
reaches the object, which is the whole reason the lookup is not in the bank.

`GP.BSTRCOUNT(NAME)` is a composite: it compiles to a plain number, so
`FOR I = 0 TO GP.BSTRCOUNT(MENU.FILE) - 1` costs no more than writing the count out.

```basic
#DEFINE GM.TEXTBANK 5

GP.BANKEDSTR GM.TEXTBANK MENU.FILE
  " OPEN "
  " SAVE "
  " QUIT "
GP.ENDBANKEDSTR

GP.BANKEDSTR GM.TEXTBANK MENU.EDIT
  " CUT "
  " PASTE "
GP.ENDBANKEDSTR

  FOR I = 0 TO GP.BSTRCOUNT(MENU.EDIT) - 1
    PRINT GP.BSTR(MENU.EDIT, I)
  NEXT I
```

**Claim the bank**, exactly as a `GP.BANKED` code region's bank is claimed. The compiler picks it
while the object is written, so `BANKMGR` has to be told rather than asked:

```basic
BANKMGR.WANT = GM.TEXTBANK : GOSUB BANKMGR.CLAIM
```

**Compile SHARED.** The text is copied into its bank by the program's bootstrap, and an embedded
program has none — the same rule `GP.BANKED` works to. An embedded build is refused rather than
compiled into a program that reads an empty bank.

**A group name is not a variable.** No `$`, no `%`, no `(` — any of those is a syntax error rather
than something quietly ignored. A name that no block declared is a syntax error at the line that
used it, and so is a second block claiming a name already taken. An empty block is refused too: a
group of no strings would make `GP.BSTRCOUNT` zero and every `GP.BSTR` on it read the next group's
text.

**There is no run-time bounds check.** The compiler knows every index it emits and nothing a
program does can produce one out of range, so an index past the end of a group reads whatever
follows it. That is the same bargain the array fast path makes.

One bank of text a program, up to 8 KB of it, up to 128 groups. `GP.BSTR` is an ordinary GP
keyword, so it pulls in the 1 KB GP block; the two block keywords do not, and neither does
`GP.BSTRCOUNT`.

Reading it from inside a `GP.BANKED` region works: the handler puts the caller's bank back before
it returns.

---

### 3.11 Calling a routine in one statement

Three keywords. `GP.DEFPROC` names a `GOSUB` target and the variables its callers fill in, `GP.SUB`
fills them and calls it in one statement, and `GP.FN` does the same from inside an expression and
gives back a value.

```basic
    DB.A = 1 : GOSUB DB.SELECT

    GP.SUB DBSELECT, 1
```

The two lines compile to the same p-code: an assignment per formal, then the call. A call site
costs what the long spelling costs. A declaration on a line of its own costs one byte, the line
marker every source line emits. Folded onto the routine's own first statement it costs nothing. A
bare label is not a line, so folding onto one costs the byte anyway.

`GP.DEFPROC` and `GP.SUB` have no machine code of their own, so a program whose only GP.BASIC
keywords are those two stays GP OUT and carries none of the GP block. `GP.FN` has two runtime
opcodes and brings the block in.

#### The formals are ordinary variables

A verb's formals and its `RETURNS` variable are plain variables in the program's one variable list.
Every call writes the same ones, and the body can read and write them like any other. That is what
makes the call cost nothing, and it is also the whole of the rule about nesting:

- **A verb may appear inside its own argument list.** `GP.FN(AREA, 2, GP.FN(AREA, 3, 4))` is
  correct, because a call list is evaluated in full before any of it is stored into a formal. The
  inner call runs and finishes before the outer writes `A.W`. The values wait on the 4K frame
  stack while the rest of the list is read, so neither the number of arguments nor the depth of
  any one of them is a limit.
- **A verb's body may not call the verb.** There is one set of formals, so a routine that calls
  itself — directly, or round through another verb — writes over the arguments it is still using.
  Nothing detects this: it compiles, both passes agree, and the answer is wrong.

The refusals, all at compile time:

```
    GP.DEFPROC VERB IS NOT A PLAIN NAME     a $, % or subscript on the verb
    GP.DEFPROC VERB ALREADY DECLARED        a second declaration of that verb
    GP.DEFPROC FORMAL IS NOT A VARIABLE     an array, or something that is not a name
    GP.DEFPROC RETURNS IS NOT A VARIABLE    an array element or a literal after RETURNS
    TOO MANY GP.DEFPROC FORMALS             a thirteenth formal
    GP.SUB BEFORE ITS GP.DEFPROC            the call sits above the declaration
    GP.SUB DOES NOT MATCH ITS GP.DEFPROC    the wrong number of arguments
    GP.FN BEFORE ITS GP.DEFPROC             the call sits above the declaration
    GP.FN NEEDS A VERB DECLARED RETURNS     the verb has no result variable
    ARGUMENTS DO NOT MATCH THE GP.DEFPROC   the wrong number of arguments
    TYPE MISMATCH                           a string for a number, or a number for a string
```

#### 3.11.1 `GP.DEFPROC` — declare a verb and its arguments

```entry
  Syntax    GP.DEFPROC verb [, formal ...] [RETURNS variable]
  Does      Names the routine that follows it, the variables a caller
            fills in, and the one its result comes back in. Emits no
            code.
  Kind      COMPOSITE. Records a position, a formal list and a result
            variable at compile time.
  Notes     The routine starts at the next statement, on the same
            line or on the line below. GOSUB to its label still
            works.
            A verb is a bare name: no $, no %, no subscript. Verbs
            are their own namespace, so a verb and a variable may
            share a name. One verb costs one variable record.
            A formal is a plain scalar variable, numeric or string.
            Up to 12 of them.
            RETURNS names a plain scalar variable too, and it is what
            GP.FN reads after the call. Its type is the type of the
            call. Without it the verb is GP.SUB-only.
  WARNING   An array or an array element cannot be a formal, and it
            cannot be the RETURNS variable either. A module whose
            arguments are array elements takes the verb and no
            formals, and its caller sets the array first.
  Example
```
```basic
            DB.SELECT:
              GP.DEFPROC DBSELECT, DB.A : BANK DB.CODEBANK
              GOSUB DB.SELECT.BODY
              RETURN

            AREA:
              GP.DEFPROC AREA, A.W, A.H RETURNS A.R
              A.R = A.W * A.H
              RETURN
```

#### 3.11.2 `GP.SUB` — call a verb

```entry
  Syntax    GP.SUB verb [, expression ...]
  Does      Assigns each expression to the matching formal, in order,
            then calls the routine.
  Kind      COMPOSITE. Expands to an assignment per formal and a
            GOSUB.
  Notes     The count and the types must match the declaration.
            A call into a GP.BANKED region works, and so does a call
            out of one. The address is corrected in both directions.
  WARNING   The call must sit below its GP.DEFPROC. It carries an
            address and not a line number, so a forward call is
            refused rather than compiled.
  Example
```
```basic
            GP.SUB DBSELECT, 1
            GP.SUB DBFIND, PRICE, "ACME", TRUE
            GP.SUB DBWRITE
```

#### 3.11.3 `GP.FN` — call a verb from inside an expression

```entry
  Syntax    GP.FN(verb [, expression ...])
  Does      Assigns each expression to the matching formal, calls the
            routine, and gives back the variable the declaration
            named after RETURNS.
  Kind      FUNCTION. Two runtime opcodes bracket the call.
  Notes     The verb must be declared RETURNS. Its type is the type
            of the term, so a verb returning a string is a string
            term and concatenates.
            The body may be as long as it likes and may print, read
            files, open blocks and call other verbs. The caller's
            half-built expression and its string temporaries are
            carried across it.
            Costs 5 bytes of p-code at the call site against GP.SUB's
            3, plus the read of the RETURNS variable that the long
            spelling pays anyway, plus 2 bytes for each argument
            after the first -- an argument waits on the frame stack
            until the call, so the number of formals is not a limit.
  WARNING   The call must sit below its GP.DEFPROC, as GP.SUB's does.
            The body must not call its own verb: there is one set of
            formals and it would write over the arguments in use.
            An argument may be as deep an expression as any other,
            and however many there are only one of them is on the
            evaluation stack at a time.
  Example
```
```basic
            PRINT "AREA "; GP.FN(AREA, 3, 4)
            T = A + GP.FN(AREA, 3, 4) * 2
            PRINT "X" + GP.FN(TAG, "AB") + "Y"
            PRINT GP.FN(AREA, 2, GP.FN(AREA, 3, 4))
```

---

## 4. Module reference — the BASL library

Called with `GOSUB`. Arguments go into named variables before the call, results come back in named
variables after it. Every module is position-independent — each jumps over itself — so `#INCLUDE` it
anywhere, including the top of the program.

**Six of them need a front door.** `THEME`, `MENUVERT`, `MENUBAR`, `LINEINPUT`, `GUI` and `GUI2`
are built to run from a RAM bank, and a banked routine cannot select its own bank — so each defines
`THEME.SELECT.BODY` rather than `THEME.SELECT`, and the public name comes from a separate file that
banks and then calls it. `#INCLUDE "LIB.GUIBANK.INC.BL"` to run the library in a bank, or the six
`<MODULE>.PLAIN.INC.BL` files to run it from low memory — **one or the other, never both**, and
only the ones whose modules you actually included. The front doors go before the bodies in the
file, and the `GOSUB`s in this section read identically either way. See
[GP-BASIC.GLOBALS.md](GP-BASIC.GLOBALS.md) §4.

### 4.1 `THEME.INC.BL` — named colour roles

| Routine | in | out |
|---|---|---|
| `THEME.SELECT` | `THEME.ID` | fills `THEME.CLR()` |
| `THEME.NEXT` | `THEME.ID` | the following theme, loaded |
| `THEME.RESET` | `THEME.ID` | the selected theme's shipped values, reloaded |
| `THEME.SET` | `THEME.ATTR` | issues `COLOR` — makes it the colour `PRINT` uses |
| `THEME.HI` | `THEME.ATTR` | `THEME.INV`, the inverse attribute |

Five themes, `THEME.COUNT` of them:

| `THEME.ID` | | |
|---:|---|---|
| 0 | `X16` | blue page, white text, cyan headings. The default |
| 1 | `DARK` | black page, light grey text |
| 2 | `LIGHT` | white page, black text |
| 3 | `GRAY` | dark grey page, light blue frames. From the XFMGR file manager |
| 4 | `CUSTOM` | whatever `THEME.CLR()` already holds |

`THEME.NEXT` moves to the following one and wraps, which is what a program binds to a key. A cached
attribute does not follow it: work out anything derived from `THEME.CLR()`, a reversed bar included,
after every load.

**`CUSTOM` loads nothing.** Selecting it leaves `THEME.CLR()` as it stands, so a program that lets
the user change colours carries those changes into `CUSTOM` rather than discarding them. The one
exception is a cold start — `CUSTOM` selected before any other theme has been loaded — where there
is nothing to keep and it takes `X16`'s values. `THEME.RESET` goes back to those.

`samples/color-test` edits the roles against a mock of the GUI and prints the `THEME.CLR()` lines
to paste back in here. **It carries its own `GPC-BASIC` folder and is still at seven roles**, so it
does not yet offer `THEME.FOCUS`.

Roles, for indexing `THEME.CLR()`: `THEME.PAGE` `THEME.TEXT` `THEME.TITLE` `THEME.BORDER`
`THEME.HILITE` `THEME.DIMMED` `THEME.WARN` `THEME.FOCUS`, and `THEME.SLOTS` = 8.

`THEME.FOCUS` is the eighth and newest: what a focused control wears while `GUI.FORM` has the
keyboard (§4.11). It is a separate role from `THEME.HILITE` because a dialog shows both at once —
the highlighted row of a list, and the control the TAB key has landed on.

**The routine used to be `THEME.LOAD`.** It became `THEME.SELECT` when the library split into
banked bodies and unbanked front doors, and a program still calling the old name stops at
`LABEL NOT FOUND`.

```basic
THEME.ID = 1 : GOSUB THEME.SELECT
GP.BOX 4,2,30,8, 2, THEME.CLR(THEME.BORDER)
GP.PRINTAT 6,3, "TITLE", THEME.CLR(THEME.TITLE)
```

The values are packed attributes, `background * 16 + foreground`, which is what `GP.BOX`, `GP.FILL`
and `GP.PRINTAT` take. For `COLOR`, which takes the halves separately, use `THEME.SET`.

`#DEFINE` substitutes at translation time, so `THEME.CLR(THEME.TITLE)` compiles to `THEME.CLR(2)`.
The readable name costs no variable and no lookup.

`THEME.CLR` is `DIM`med by the module. Do not `DIM` it in your own program.

Formatting a NUMBER into a column is `STRUSING.INC.BL` (§4.10), a separate
module: it needs no `#SYMFILE` and neither module depends on the other.

### 4.2 `STRINGS.INC.BL` — string helpers

| Routine | in | out |
|---|---|---|
| `STR.PADR` | `STR.STR$` `STR.WIDTH` | `STR.STR$` left-justified |
| `STR.PADL` | same | right-justified |
| `STR.PADC` | same | centred (odd gap goes right) |
| `STR.SPLIT` | `STR.STR$` `STR.DELIM$` `STR.MAX` | `STR.N`, `STR.FIELD$(1..N)` |
| `STR.REPLACE` | `STR.STR$` `STR.FIND$` `STR.REPL$` | `STR.STR$`, every occurrence replaced |
| `STR.PET2SCR` | `STR.PET` | `STR.SCR` |
| `STR.SPLICE` | `STR.STR$` `STR.AT` `STR.CUT` `STR.SUB$` | `STR.STR$`, edited at that position |
| `STR.TRIM` | `STR.PTR` | *(the string itself)*, spaces off both ends |
| `STR.LTRIM` | same | spaces off the **leading** end |
| `STR.RTRIM` | same | spaces off the **trailing** end |

**The module needs a `#SYMFILE`, and so does every program that includes it**, before the
`#INCLUDE`s and named after the source PRG. The three trims are `GP.ASM` and reach BASIC's
variables through `{VAR}`; without a symbol file the compile stops with `NO SYMBOL FILE FOR {}`.
This is new — the module was pure BASIC until the trims moved here out of `STRCASE.INC.BL`.

**The two halves take their argument differently, and one question decides which:** does the
routine GROW the string. The pads and `SPLICE` do, so they are BASIC — they take the string by
value in `STR.STR$` and hand it back there, and an assignment reallocates for free. The trims only
ever shrink, so they are assembly — they take its ADDRESS in `STR.PTR` and rewrite the block where
it lies, which is the only way a `GOSUB` can edit a caller's string without two allocations and two
copies a call. Never pass a literal to those: `GP.STRPTR("hello")` is an address inside the
p-code.
The three pad routines leave a string that is already at or past the width unchanged. They pad and
never truncate; use `STR.RTRIM` to shorten.

`SPLIT` reads `STR.STR$` without modifying it. `STR.MAX` of 0 means 10. Empty fields are preserved:
`"A,,C"` is three fields and `"A,"` is two. Splitting an empty string gives one empty field, never
zero. Reaching the limit is not an error and loses nothing — the last field receives the unsplit
remainder, delimiters included.

`STR.FIELD$` is the one array the library does not `DIM`. Left alone, GPC's implicit `DIM` gives
0..10. For more, `DIM` it before the first call and set `STR.MAX` to match. `DIM`ming an array GPC
has already auto-dimensioned is an error, so it is one or the other. Note that this is the reverse
of `THEME.CLR`, which the module `DIM`s.

`REPLACE` swaps every occurrence of `STR.FIND$` for `STR.REPL$`, modifying `STR.STR$` in place. The
replacement may be shorter, longer, or `""` to delete. It is case sensitive, because `GP.INSTR`
compares raw bytes.

A replacement that contains the search text is safe: `"A"` to `"AA"` terminates and doubles the As,
where a naive in-place version would not. The routine builds a new string and never re-scans what it
has emitted. An empty `STR.FIND$` leaves the string unchanged rather than hanging, because
`GP.INSTR` reports not-found for a zero-length needle. Like the pad routines it is not length
checked: a longer replacement can push the result past 255 characters.

`PET2SCR` converts a PETSCII code to the screen code the tile map holds, for `TILE`, `TDATA` and
`VPOKE`. `GP.PRINTAT` and `GP.FILL` do this internally.

The three trims are three entry labels sharing one blob, so there is no mode to forget to set. A
zero-length string and an all-spaces string are not special cases: the walk counts down and
reaching zero is the answer.

`SPLICE` edits by POSITION where `REPLACE` edits by content: it replaces `STR.CUT` characters at
`STR.AT` with `STR.SUB$`. One routine covers all three of insert, overwrite and delete, because
they are the same operation with a different count — `STR.CUT` of 0 inserts, `LEN(STR.SUB$)`
overwrites, and an empty `STR.SUB$` deletes. `STR.AT` is 1-based, matching `GP.INSTR`.

Past the end appends and below 1 clamps to 1, both falling out of `LEFT$` and `MID$` rather than
being tested for; a cut running past the end takes the rest of the string. It is not length
checked, like `REPLACE` and the pads. `SPLICE` clamps `STR.AT` and `STR.CUT` in place, so read them
back rather than assuming what you set survived the call.

It was written in `GP.ASM` first and rewritten in BASIC, which is worth knowing because the reason
generalises: the assembly could overwrite and delete but never insert, because in-place work cannot
grow a string, and it cost about 280 bytes of p-code where the one BASIC line costs about 40.

Examples: [`SPLITT.EXP.BL`](SPLITT.EXP.BL), [`STRINGS.EXP.BL`](STRINGS.EXP.BL). Regression test:
[`STRTST.EXP.BL`](STRTST.EXP.BL), thirty-three cases — the trim edges, every splice mode, both
clamps, appending past the end, splicing an empty string, growing a 200-character string past the
block it was born with, and guard strings either side to catch an off-by-one write into the
neighbouring block.

### 4.3 `APPSYS.INC.BL` — start politely, leave it as you found it

| Routine | in | out |
|---|---|---|
| `APPSYS.STARTUP` | — | `APPSYS.MODE` `APPSYS.COLS` `APPSYS.ROWS` `APPSYS.COLOUR` |
| `APPSYS.RESTORE` | those | screen mode and colour put back |
| `APPSYS.ISEMU` | — | `APPSYS.IS.EMULATOR` — -1 under x16emu, 0 otherwise |

```basic
A screen rectangle through a file is `STASH.FILE.SAVE` / `.LOAD` / `.PUT` in `STASHFILE.INC.BL`.

GOSUB APPSYS.STARTUP
' ... the application, laid out with APPSYS.COLS / APPSYS.ROWS ...
GOSUB APPSYS.RESTORE : END
```

Call `STARTUP` before any `SCREEN` or `COLOR` of your own. It records the state as it finds it, so
anything changed beforehand is what gets restored.

Lay out from `APPSYS.COLS` / `APPSYS.ROWS` rather than assuming 80x60. The X16 boots 80x60, but
`SCREEN 0` is 40x30 and a user who prefers larger text is running one.

`APPSYS.DEV` defaults to 8. The panel routines are implemented in `STASHFILE.INC.BL`. A panel file
is self-describing — it carries the stash's 4-byte header — so loading one needs only its name.

`APPSYS.ISEMU` answers the question a timing loop has to ask. `$9FBE` and `$9FBF` are the last of
the emulator's own I/O registers and read as `"1"` and `"6"` under x16emu, with the debugger on or
off; the routine is those two `PEEK`s and a comparison.

```basic
GOSUB APPSYS.ISEMU
IF APPSYS.IS.EMULATOR THEN PRINT "EMULATED"
IF NOT APPSYS.IS.EMULATOR THEN PRINT "NOT x16emu"
```

**The flag is -1, not 1**, so `NOT` works on it: `NOT` is `-x-1` here, so `NOT -1` is 0 while
`NOT 1` is -2 — still true. -1 is also what a comparison hands back, so the flag reads like one.
`IF` itself tests non-zero, so either value would have worked with the plain form.

**It answers for x16emu and nothing else.** A 0 means "not x16emu" — a real machine, or another
emulator that does not carry those registers. And `$9FA0-$9FBF` is expansion card I/O on the real
machine, so a card at I/O5 could in principle answer `"16"` as well: a 1 is strong, a 0 is
certain.

### 4.4 `LINEINPUT.INC.BL` — a positioned entry field

| Routine | in | out |
|---|---|---|
| `LINEINPUT.GET` | `LINEINPUT.X` `.Y` `.LEN` `.ATTR` `.TEXT$` `.MASK` `.ALLOW$` `.DENY$` | `LINEINPUT.TEXT$` `LINEINPUT.KEY` |
| `LINEINPUT.ASK` | the same plus `LINEINPUT.LABEL$` | the same; `LINEINPUT.X` restored |

```basic
LINEINPUT.X = 10 : LINEINPUT.Y = 6
LINEINPUT.LEN = 20
LINEINPUT.ATTR = THEME.CLR(THEME.TEXT)
LINEINPUT.TEXT$ = ""
GOSUB LINEINPUT.GET
IF LINEINPUT.KEY = 27 THEN GOTO CANCELLED
```

`INPUT` and `LINPUT` cannot be used on a drawn screen: both take the bottom of the screen, scroll
it, echo in the current colour, and accept any length. A `LINEINPUT` field stays at the given
position, in the given colour, and stops at the given width.

`LINEINPUT.KEY` is the key that ended the field, which is what makes a multi-field form possible:

| | |
|---:|---|
| 13 | RETURN — finished |
| 27 / 3 | ESC / STOP — cancelled, and `LINEINPUT.TEXT$` is put back to what it was |
| 17 / 145 / 9 | cursor down / up / TAB — left the field, **text kept** |

A form is therefore a loop over fields rather than a sequence of prompts, and the user can return to
an earlier field without restarting.

`LINEINPUT.MASK` non-zero displays asterisks while holding the real string. The field does not
scroll: when it is full, further characters are refused and the cursor inverts the last character
rather than sitting past the end. The cursor blinks off `TI` rather than a delay loop; a delay loop
would swallow keys pressed during it.

`LINEINPUT.ALLOW$` and `LINEINPUT.DENY$` restrict what may be typed. Both are empty by default, and
the field then takes any printable character, as it always has. `ALLOW$` lists the characters
accepted and `DENY$` the ones refused; a caller that sets both gets `ALLOW$`, and `DENY$` is not
consulted. A refused key changes nothing — not the text, and not the caret.

They compare raw bytes, so a set of LETTERS depends on the charset: PETSCII shifted letters arrive
as `$C1-$DA` and ISO ones as `$41-$5A`, and an `ALLOW$` written for one silently refuses every
capital in the other. Digits are 48-57 in both. Use `ALLOW$` for a closed set short enough to write
out, `DENY$` for everything-except:

| Field | Spelling |
|---|---|
| Digits only | `ALLOW$ = "0123456789"` |
| Number with sign and point | `ALLOW$ = "0123456789.-"` |
| Yes or no | `ALLOW$ = "YyNn"` |
| Letters, no digits | `DENY$ = "0123456789"` |
| Filename, no punctuation | `DENY$ = ",:=*?"` |

Both are sticky, like every other input in the library, so a form sets them on the way into each
field rather than once at the top.

Example: [`FORM.EXP.BL`](FORM.EXP.BL) — three fields, one masked and one digits-only, in a themed panel.

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

Use the long form to read the size before committing to a screen mode, or to report a bad file
before the display is torn down:

```basic
BMX.FILE$ = F$
GOSUB BMX.OPEN
IF BMX.ERROR$ <> "" THEN GOTO COMPLAIN
' ... BMX.WIDTH, BMX.HEIGHT, BMX.PALUSED readable here ...
SCREEN 128
GOSUB BMX.PAINT
```

Set the screen mode before `BMX.PAINT`, not after. `SCREEN` reloads the default palette, so a mode
change after painting discards the image's colours: correct pixels, wrong palette.

`BMX.PAINT` writes the image's colours over the machine's palette, and nothing on the X16 restores
them — not `SCREEN`, not the KERNAL's `screen_mode`. `BMX.PAINT` therefore stashes all 256 entries
in spare VRAM first, and `BMX.RESTORE` writes them back:

```basic
BMX.FILE$ = "TITLE.BMX"
SCREEN 128
GOSUB BMX.SHOW
' ... the title screen ...
GOSUB BMX.RESTORE
```

A program that keeps the machine need never call it. A program that returns the machine to BASIC or
chains to another calls it once. It is safe to call at any time: with nothing stashed there is
nothing to do, so a program whose image failed to load can still call it on the way out. All 256
entries are kept, not the range the file claims, and they are kept once per run — so a slideshow
restores the machine's own palette rather than the previous image's.

`BMX.STASH` is the VRAM address they go to, `$13000` by default, which is free above the 320x240
framebuffer in the mode this module paints into. A caller using tiles, sprites or a second bitmap
there must move it or switch it off with `BMX.STASH = -1`. The address is checked: a stash inside the
bitmap or overlapping the PSG registers is reported and nothing is painted.

Use `-1` to switch it off, not `0`. Zero is what the variable holds before it is set, and `BMX.INIT`
runs at the first `BMX.OPEN`, after a caller would have set it, so `0` has to keep meaning unset.

The module handles 8 bits per pixel, uncompressed, which is what `SCREEN 128` displays without a
decompressor. Anything else is reported rather than attempted. The image is centred, and anything
larger than 320x240 is clipped.

Examples: [`BMXVIEW.EXP.BL`](BMXVIEW.EXP.BL), and [`BMXPAL.EXP.BL`](BMXPAL.EXP.BL) for the palette

### 4.6 `MENUVERT.INC.BL` — a vertical menu

| Routine | in | out |
|---|---|---|
| `MENUVERT.RUN` | the variables below | `MENUVERT.SEL` `MENUVERT.KEY` |
| `MENUVERT.DRAW` | the same | draws the menu without driving it |
| `MENUVERT.ROW` | `MENUVERT.DRAWROW` `MENUVERT.DRAWATTR` | one row, in the attribute you name |
| `MENUVERT.HOTFIND` | `MENUVERT.DRAWROW` `MENUVERT.DRAWTEXT$` | `MENUVERT.HOTAT` — where that row's hotkey letter sits, 1-based, or **0 for "do not tint"** |

The menu is BASIC rather than assembly, which keeps 462 bytes of code and 11 of storage out of the
block every GP program carries. Assembly would only be needed to move the highlight without knowing
the text underneath it, by swapping the cell's attribute nibbles instead of redrawing. A BASIC menu
owns the item array and can reprint the row.

The difference is not visible: a nibble swap is 59 cycles a cell, `GP.FILL` 31 and `GP.PRINTAT` 94,
so redrawing two rows costs about a millisecond against the swap's half, in a 16.7 ms frame.

| in | |
|---|---|
| `MENUVERT.X` `.Y` | top left of the **first row**, not of a frame — draw the border yourself with `GP.BOX`, so the menu owes nothing to one style of border |
| `MENUVERT.WIDTH` | cells wide. This is the width of the **highlight**, so it is the width of the menu whatever the text happens to do |
| `MENUVERT.COUNT` | how many rows |
| `MENUVERT.ITEM$()` | the rows, `1..COUNT` — **the caller owns the `DIM`**, see below |
| `MENUVERT.ATTR` | packed attribute, `background * 16 + foreground` |
| `MENUVERT.HIATTR` | the same for the highlighted row. **0 means invert `MENUVERT.ATTR`** |
| `MENUVERT.HOT$` | one character a row, `""` for none |
| `MENUVERT.HOTATTR` | paint the hotkey letter in this attribute. **0 is off, and off is the default** |
| `MENUVERT.FLAGS` | added together, below |
| `MENUVERT.SEL` | the row to start on; 0 starts at 1 |

| out | |
|---|---|
| `MENUVERT.SEL` | `1..COUNT`, or **0 if cancelled** |
| `MENUVERT.KEY` | the key that ended it — 13 chose, 27 cancelled, or the hotkey itself |

```basic
MENUVERT.X = 8 : MENUVERT.Y = 6
MENUVERT.WIDTH = 24 : MENUVERT.COUNT = 4
MENUVERT.ITEM$(1) = " NEW GAME"           ' ... and so on
MENUVERT.ATTR = THEME.CLR(THEME.TEXT)
MENUVERT.HIATTR = THEME.CLR(THEME.HILITE)
MENUVERT.HOT$ = "NLOQ"
GOSUB MENUVERT.RUN
IF MENUVERT.SEL = 0 THEN GOTO CANCELLED
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

The constants `MENUVERT.MUSTSEL`, `.KEEPMARK`, `.NOWRAP` and `.GAMEPAD` are defined; add those
rather than the numbers.

A hotkey chooses its row rather than moving to it. `MENUVERT.HOT$` is one character per row in
order, matched without case. It may be shorter than `MENUVERT.COUNT`, in which case the later rows
have no hotkey.

`MENUVERT.HOTATTR` paints the hotkey letter in a second attribute. The letter is located in the
row's own text — the first case-insensitive match for that row's `MENUVERT.HOT$` character — so
nothing extra is passed in and `" START"` with hotkey `S` needs no markup. A row whose text does not
contain its hotkey is left untinted rather than reported; the hotkey still works. Only rows in the
normal attribute are tinted: on the selected row the highlight carries the meaning.

The caller owns the `DIM`. A module cannot be passed an array in BASIC, so it names one; `DIM`ming
it inside the module would fix a bound and then fail for a caller who wanted more rows. Leave
`MENUVERT.ITEM$` undimensioned and GPC's implicit `DIM` gives 0..10, a ten-row menu. `DIM` it
yourself for more. Do not do both.

#### The gamepad flag

With flag 8, up and down move the highlight and B or Start chooses. Cancel remains keyboard-only:
ESC and STOP have no unambiguous pad equivalent, and a must-select menu has no cancel.

It reads port 1, the physical pad, not port 0. Port 0 is the keyboard presented as a joystick, and
the menu reads the keyboard directly, so reading both would move the highlight twice for one cursor
key. Port 0 is also unreliable, reporting absent on roughly half of all reads (measured in
AlienAirlift: 2,060 negative against 2,057 valid over 14 seconds).

One step per press, no auto-repeat. The wait loop spins as fast as the CPU allows, so the pad is
edge-triggered and holding a direction moves once. A button still held from whatever opened the menu
is not read as a fresh
press either, so a menu cannot answer itself on the way in.

With no pad connected the flag changes nothing: the pad is read only when the keyboard is quiet,
and an absent pad reads as nothing held. In the emulator a real pad needs `-joy1`, which binds
physical hardware and does not map the keyboard.

Examples: [`MENUDEMO.EXP.BL`](MENUDEMO.EXP.BL) on its own, [`MENU.EXP.BL`](MENU.EXP.BL) inside a
whole small application, and [`MENUTST.EXP.BL`](MENUTST.EXP.BL) for the 21-case regression test.

---

### 4.7 `SORT.INC.BL` — shell sort a string array

| Routine | in | out |
|---|---|---|
| `SORT.RUN` | `SORT.PTR` `SORT.DESCEND` `SORT.NOCASE` | `SORT.OK` `SORT.COUNT` |

```
#SYMFILE "@:MYPROG.SYM"
#INCLUDE "SORT.INC.BL"

SORT.PTR = GP.ARRPTR(NAME$())
SORT.DESCEND = 0 : SORT.NOCASE = 0
GOSUB SORT.RUN
```

Shell sort with Ciura's gap sequence — 132, 57, 23, 10, 4, 1 — moving the 2-byte element pointers
rather than string data. A swap costs the same whatever the strings are: no temporary, no copy, no
heap traffic.

The array is passed as an address because a BASL subroutine cannot be passed an array; `GP.ARRPTR`
is a keyword for this purpose. The empty parentheses in `GP.ARRPTR(A$())` are required — `A$` and
`A$()` are different variables.

`SORT.OK` is -1 when it sorted and 0 if the sort was refused: more than 255 elements, so `DIM A$(254)` is the largest
accepted (`DIM A$(255)` is 256 elements), or an array whose elements are not strings. The element
count and the type are read from the array's own header, three bytes below what `GP.ARRPTR` returns,
so a wrong count cannot be passed in.

Never-assigned elements are empty strings, not garbage. A `DIM A$(20)` with five entries filled
sorts its fifteen empties to the front; a null pointer reads as `""`, as it does elsewhere in the
runtime.

`SORT.DESCEND` and `SORT.NOCASE` are ordinary variables rather than arguments, so they are sticky.
Set both on every call.

The program must have a `#SYMFILE`, placed before the `#INCLUDE`s. The assembly reaches BASIC's
variables through `{VAR}`, and BASLOAD crunches every name before the compiler sees it; without the
mapping the compile stops with `NO SYMBOL FILE FOR {}`.

Example: [`ARRAYS.EXP.BL`](ARRAYS.EXP.BL). Regression test: [`SORT.EXP.BL`](SORT.EXP.BL), eight
cases including a 200-element array — element 128 is where the doubled index stops fitting in a
byte. Every case checks content as well as order: a sort that reads the wrong element leaves the
array in order with a string duplicated.

---

### 4.8 `STRCASE.INC.BL` — case, in place

| Routine | in | out |
|---|---|---|
| `STRCASE.GO` | `STRCASE.PTR` `STRCASE.MODE` | *(the string itself)* |

```
#SYMFILE "@:MYPROG.SYM"
#INCLUDE "STRCASE.INC.BL"

STRCASE.PTR = GP.STRPTR(LINE$)
STRCASE.MODE = STRCASE.UPPER
GOSUB STRCASE.GO
```

| mode | does |
|---|---|
| `STRCASE.UPPER` | a–z → A–Z, everything else untouched |
| `STRCASE.LOWER` | A–Z → a–z, everything else untouched |

One blob, with the mode tested once at entry rather than inside the loop, where the byte count is
the whole cost.

The argument is an address because a BASL subroutine cannot be passed a variable. Copying the
**`TRIM`, `LTRIM` and `RTRIM` were here** and are `STR.TRIM` / `STR.LTRIM` / `STR.RTRIM` in
`STRINGS.INC.BL` (§4.2) now. They are string editing rather than case work, and every other
string routine already lived in that one module. A program that only trims does not need this file
at all; one that only folds case saves 113 bytes of p-code by the move.

caller's string in and back out would be two allocations and two copies per call — the heap traffic
this module exists to avoid. `GP.STRPTR` gives the block and the assembly rewrites it in place.

Do not pass a literal. `GP.STRPTR("hello")` is the address of that text inside the p-code, so
upper-casing it edits the running program, and the edit persists the next time the line runs. The
equivalent keywords could not be misused this way, because the compiler required a string variable
at the call site; a `GOSUB` cannot enforce that.

`STRCASE.MODE` is sticky: an ordinary variable, not an argument, so a call that does not set it
repeats the last operation. Set both inputs every time, as with `SORT.DESCEND` and `STASH.MOVE`.

There is no pad routine here. Padding grows a string, and nothing working on the block alone can
grow one past the capacity it was created with. Use `STR.PADR` (§4.2).

Example: [`STRINGS.EXP.BL`](STRINGS.EXP.BL). Regression test:
[`STRCTST.EXP.BL`](STRCTST.EXP.BL), eight cases — empty, one character, 200 characters, and guard
strings either side to catch an off-by-one write into the neighbouring block. The trim cases moved
with the trims, to [`STRTST.EXP.BL`](STRTST.EXP.BL).

---

### 4.9 `MENUBAR.INC.BL` — a horizontal menu

| Routine | in | out |
|---|---|---|
| `MENUBAR.RUN` | `MENUBAR.X` `MENUBAR.Y` `MENUBAR.GAP` `MENUBAR.FLAGS` `MENUBAR.SEL`, and `MENUVERT.COUNT` `MENUVERT.ITEM$()` `MENUVERT.ATTR` `MENUVERT.HIATTR` `MENUVERT.HOT$` `MENUVERT.HOTATTR` | `MENUBAR.SEL` `MENUBAR.KEY` `MENUBAR.SELX` `MENUBAR.SELW` |
| `MENUBAR.DRAW` | the same | the bar on screen, undriven |
| `MENUBAR.ITEM` | `MENUBAR.FIND` and an attribute | one item, repainted |
| `MENUBAR.MARK` | `MENUBAR.FIND` | that item highlighted |
| `MENUBAR.WHERE` | `MENUBAR.FIND` | `MENUBAR.AT` `MENUBAR.WIDE` |

`MENUVERT` is the vertical menu; this is the other axis. **It reads `MENUVERT`'s items, attributes
and hotkeys rather than defining its own**, because a bar and the dropdown under it are one thing to
the user — so it does not build without `MENUVERT.INC.BL`, and the caller refills
`MENUVERT.ITEM$()` between drawing the bar and opening the menu.

**An item is as wide as its own text.** There is no `MENUBAR.WIDTH` and no column width; the air
goes in the item string, so `" FILE "` is how a highlight gets padding. `MENUBAR.GAP` is the space
*between* two items and defaults to 0 for the same reason.

**Up and down are optional exits, off by default.** `MENUBAR.DOWNEXIT` ends the bar on DOWN and
`MENUBAR.UPEXIT` on UP, handing the key back in `MENUBAR.KEY` so the caller can open the panel
under `MENUBAR.SELX`. A bar that is only a bar leaves both off and arrows across the grain do
nothing. `MENUVERT`'s `MENUHELP.KEYEXIT` is the other half of that handshake.

Flags, added together: `MENUBAR.MUSTSEL` `MENUBAR.KEEPMARK` `MENUBAR.NOWRAP` `MENUBAR.GAMEPAD`
`MENUBAR.DOWNEXIT` `MENUBAR.UPEXIT`.

---

### 4.10 `STRUSING.INC.BL` — a number to a template

| Routine | in | out |
|---|---|---|
| `STR.USING` | `STR.USING.NUM` `STR.USING.MASK$` | `STR.USING.STR$`, a field |
| `STR.USING.FIX` | `STR.USING.NUM` `STR.USING.DP` | `STR.USING.STR$`, digits only |

```basic
#INCLUDE "STRUSING.INC.BL"

STR.USING.NUM = 1234.5 : STR.USING.MASK$ = "#,##0.00"
GOSUB STR.USING
PRINT STR.USING.STR$                    ' 1,234.50
```

Pure BASIC. It needs no `#SYMFILE` and depends on no other module, so a program can take it
without taking `STRINGS.INC.BL` (§4.2) — and the other way round.

| In the mask | Means |
|---|---|
| `#` | a digit position, **space** if the number does not reach it |
| `0` | a digit position, **zero** if the number does not reach it |
| `.` | the decimal point everything aligns on |
| `,` | anywhere in the mask, groups the integer part in threes |
| `+` | first character only: a sign column, `+` or `-` |
| `-` | first character only: a sign column, `-` or a space |

`PRINT USING`'s mask, from BASIC 7.0, less the four characters that earn nothing here: `$`
floating currency, a trailing sign, `^^^^` exponential, and `=` / `>` — those last two justify a
**string**, which is `STR.PADC` and `STR.PADL` (§4.2).

**The result is exactly `LEN(STR.USING.MASK$)` characters, right justified**, so a column of them
lines up on the point. Everything after the point prints, so `#` and `0` do not differ there. A
point with no digit positions after it is ignored.

```
"###0.00"    12.5    ->  "  12.50"        "#,##0.00"   1234.5  ->  "1,234.50"
"0000.00"    12.5    ->  "0012.50"        "+##0.00"      -1.5  ->  "-  1.50"
"##000"        42    ->  "  042"          "##0"         12345  ->  "***"
```

**Too wide fills the whole field with `*`.** That is deliberate and visible; overflowing the width
instead would push the rest of the row along and misalign every column after it. A negative value
with **no** sign column spends one digit position on its minus, and stars when there is none to
spend — `"##0"` holds `-12` but not `-123`.

**Rounding is half away from zero**, done on the absolute value before the sign goes back on.
`INT` alone floors toward minus infinity, which rounds `-1.5` and `1.5` in opposite directions.
`-0.004` to two places is `"0.00"`, not `"-0.00"`: a signed zero in a column reads as a real
negative.

**WARNING: the value must scale to under 1,000,000,000.** The digits are built by multiplying up
by `10 ^ DP` and rounding, and `STR$` turns over to E notation at 1e9 — so two decimal places
reach `9,999,999.99` and five reach `9,999.99999`. Past that the field fills with `*` rather than
printing something wrong.

`STR.USING.FIX` is the same digits with no field over them: `STR.USING.NUM` to `STR.USING.DP`
places, sign attached, no leading space. Right justify it with `STR.PADL` if you want a column.

**The digits do not come out of `STR$`'s fraction, and cannot.** `STR$` trims trailing zeros, so
`12.30` comes back as `"12.3"`; it drops the leading zero of a pure fraction, so a half is `" .5"`;
and it takes *significant digits*, never decimal places — `FloatToString` records that a
fixed-decimal mode was tried and printed `12345678.9` as `12345678.8984375`. So a scaled integer is
the only exact route, and the 1e9 ceiling above is its price.

Cost: **726 bytes** of p-code, of which `STR.USING.FIX` alone is **205**. Its own module rather
than a routine in `STRINGS.INC.BL` for that reason — a program wanting `STR.PADL` and a split
should not carry a mask parser.

Example: [`STRUSING.EXP.BL`](STRUSING.EXP.BL). Regression test:
[`USINGT.EXP.BL`](USINGT.EXP.BL), thirty-nine cases — both entry points, every mask character,
the rounding traps, the sign column and both overflows. Text and length are compared every time:
the result is a field, so a right answer in the wrong number of columns still breaks the table.

---

### 4.11 `GUI.INC.BL` — four dialogs, in a box that puts the screen back

| Routine | in | out |
|---|---|---|
| `GUI.SAY` | `GUI.MSG$` | `GUI.KEY` — something to say, and one way out |
| `GUI.YN` | `GUI.MSG$` | `GUI.ANSWER`, -1 for yes |
| `GUI.MENU` | `GUI.COUNT` `GUI.SEL` `GUI.FLAGS`, over `MENUVERT.ITEM$()` | `GUI.SEL`, or 0 if cancelled |
| `GUI.INPUT` | `GUI.LEN` `GUI.TEXT$` `GUI.MASK` | `GUI.TEXT$` `GUI.OK` |
| `GUI.OPEN` | `GUI.BODY.ROWS` `GUI.BODY.WIDTH` | `GUI.INNER.LEFT` `.TOP` `.WIDTH` — the box on its own, for a dialog of your own |
| `GUI.CLOSE` | — | the screen as it was |

```basic
THEME.ID = 0 : GOSUB THEME.SELECT
GUI.BANK = 8
GUI.MSG$ = "DELETE THE FILE?"
GOSUB GUI.YN
IF GUI.ANSWER THEN <yes>
```

Requires `GPB.INC.BL`, `STASH.INC.BL`, `THEME.INC.BL`, `MENUVERT.INC.BL` and `LINEINPUT.INC.BL`,
and `#INCLUDE`s none of them. **All five, whichever dialog you call** — BASLOAD resolves every
label in the file, so leaving one out is `LABEL NOT FOUND`. It wants a `#SYMFILE`, because
`STASH` does.

Everything the box takes — three message lines, a title, the style, the placement, the shadow, the
frame glyphs, the bank the covered cells go to — is listed in full in
[GP-BASIC.GLOBALS.md](GP-BASIC.GLOBALS.md) §3. `GUI.BANK = 0` does not save the cells, and then the
box is still on screen when the call returns.

**Every control has a focus, and TAB moves it.** The dialogs no longer own their key loops: each
states its controls and `GUI.FORM` runs them. A control is a button, a field or a list; it hands
back one of six verdicts — stay, next, previous, press, default, cancel — and the dispatcher stays
one loop whatever the mix. A caller that never presses TAB sees what it always saw.

**The default button and the focused control are different things.** The default is what RETURN
presses from anywhere and is drawn `<<LIKE THIS>>`; the focus is where TAB has got to and is drawn
in `THEME.FOCUS`. `GUI.INPUT` opens with the default on OK and the focus in the field — which is
the point of keeping the two apart, and `GUI.DEFAULT` sets only the first.

**The answers are buttons.** `GUI.BTN.ONE$` and `GUI.BTN.TWO$` carry them, and `&` marks the
accelerator: `"&CANCEL"` lights the C. **An accelerator is live only while the focused control does
not eat printable keys**, so C presses CANCEL from the button row or from inside a list, and types
a C in a field. That is the whole rule, and `GUIFRMT`'s T14, T15 and T22 are the three assertions
that hold it.

`GUI.HINT$` is gone — the dimmed line naming two keys became the button row, and it is the one
interface this took away.

**The typing dialog and its string swapped names**: it was `GUI.TEXT` returning `GUI.INPUT$`, and it
is `GUI.INPUT` returning `GUI.TEXT$`. BASLOAD will not have a label and a variable of one name and
the `$` does not separate them. A program written against the older library **compiles clean and
reads the wrong one back**.

**Upper case, on the default charset.** `GP.PRINTAT` converts PETSCII and BASLOAD passes literals
through as source bytes, so charset 2 lands lower case on the graphics half of the font. ISO mode
fixes the text and breaks the frame, `GP.BOX`'s `$40`–`$7D` being letters. Upper case with a frame,
mixed case without one, or re-order the font and set `GUI.GLYPH`.

Example: [`GUI.EXP.BL`](GUI.EXP.BL). Regression test: `samples/GPB-MODS-TESTING/GUIFRMT.BASL`,
twenty-four assertions driven by keys pushed into the KERNAL buffer — the only way to drive a `GET`
loop headlessly.

---

### 4.12 `GUI2.INC.BL` — a listbox, single or multi select

| Routine | in | out |
|---|---|---|
| `GUI.LISTBOX` | `GUI.LISTBOX.COUNT` `.ROWS` `.MULTI` `.MARKS$` `.SEL`, over `MENUVERT.ITEM$()` | `GUI.LISTBOX.SEL` `.MARKS$` `.MARKED` `GUI.KEY` |

```basic
DIM MENUVERT.ITEM$(200)
GUI.LISTBOX.COUNT = N : GUI.LISTBOX.ROWS = 8 : GUI.LISTBOX.MULTI = 1
GUI.MSG$ = "PICK FILES" : GUI.BANK = 8
GOSUB GUI.LISTBOX
IF GUI.LISTBOX.SEL = 0 THEN <cancelled>
```

Its own `#INCLUDE` on top of `GUI.INC.BL`, because nothing else in the library wants a set of marks
or a footer counting them. **The caller owns the `DIM`** of `MENUVERT.ITEM$()`.

Up and down move, PgUp and PgDn page, HOME and END jump, SPACE toggles a mark in multi. TAB moves
to the buttons and back, RETURN takes `<<OK>>` from anywhere, ESC and STOP cancel — and O and C
press their buttons while the eye is still in the list, which a list can offer and a typing field
cannot.

**In multi, `GUI.LISTBOX.SEL` is not the answer** — it is where the cursor was left. The marks are:
`GUI.LISTBOX.MARKS$` is `COUNT` characters with `"1"` for marked, and it goes in as well as out, so
a list reopens with its marks. Any other length, `""` included, starts with none.

The bottom frame edge reads `2 SELECTED OF 20` in multi, `20 ITEMS` for a single list too long to
see at once, and is blank for one that fits.

**The scrolling list itself is not in this module.** It is `GUI.CT.LIST`, one of `GUI.FORM`'s three
control types, and lives in `GUI.INC.BL` beside the field; this file is the dialog around it.

Example: [`GUI2TST.EXP.BL`](GUI2TST.EXP.BL).

---

## 5. Variables

BASL has one flat namespace. There are no locals, no scoping and no parameters. Every variable in
every `#INCLUDE`d module is visible to your program and the reverse, and nothing warns you: a
collision is a wrong answer, not an error.

The convention is one dotted prefix per module, and nothing writes outside its own prefix.

### Prefixes already taken

| Prefix | Owner |
|---|---|
| `GP.` | keywords, **not variables** — see below |
| `STR.` | `STRINGS.INC.BL` |
| `THEME.` | `THEME.INC.BL` |
| `APPSYS.` | `APPSYS.INC.BL` |
| `LINEINPUT.` | `LINEINPUT.INC.BL` |
| `MENUVERT.` | `MENUVERT.INC.BL` |
| `MENUBAR.` | `MENUBAR.INC.BL` |
| `GUI.` | `GUI.INC.BL` |
| `GUI.LISTBOX.` | `GUI2.INC.BL`, kept apart from the rest of `GUI.` |
| `STASH.` / `STASH.FILE.` | `STASH.INC.BL` / `STASHFILE.INC.BL` |
| `SORT.` | `SORT.INC.BL` |
| `STRCASE.` | `STRCASE.INC.BL` |
| `BMX.` / `BMXK.` | `BMX.INC.BL` (variables / its KERNAL constants) |

Use any other prefix for your own program: `GAME.`, `MAP.`, `AIRLIFT.`. A prefix costs nothing at
runtime — BASLOAD crunches every identifier to a short BASIC variable, so a long readable name and a
two-letter one compile to the same thing.

Do not reuse a taken prefix for a name the module has not defined. `THEME.MINE` is free today and is
one library update from not being.

### `GP.*` is keywords, not variables

`GPB.INC.BL` defines no variables. It is 27 keyword declarations and nothing else.

```basic
GP.A = 5          ' SYNTAX ERROR — GP.A is a keyword
X = GP.A          ' correct
```

The value words are `GP.A` `GP.X` `GP.Y` `GP.C`, the registers after `GP.CALL`, and that is all of
them. They are keywords rather than variables because nothing in the runtime can write a BASIC
variable by name, so a command that returns a value must return it through a keyword. X16's own
`ST`, `MX` and `MY` work the same way.

The complete per-module in / out / internal register is
[GP-BASIC.GLOBALS.md](GP-BASIC.GLOBALS.md), with a script in §6 of that file for re-checking it
after a change.

---

## 6. The traps, collected

Each of these has cost a debugging session at least once.

| Trap | What happens | Do this |
|---|---|---|
| `P AND 255` on a heap or VRAM address | `AND` is 16-bit signed; above 32,767 it raises `OUT OF RANGE` instead of masking | `H = INT(P/256) : L = P - H*256` |
| an address in an `A%` variable | `%` is signed 16-bit and truncates without error — `A% = 49152` reads back -16,384 | untyped variable, or split into page and offset |
| `$0400` for machine code | stock BASIC leaves it free, a compiled GPC program does not — runtime state lives there, and it is corrupted with no error | banked RAM, `$A000`–`$BFFF` |
| `PRINT` after `GP.PRINTAT` | GP drawing never calls the KERNAL, so the cursor is wherever it was | `LOCATE` first, or stay in one world |
| `SORT.INC.BL` with no `#SYMFILE` | `{VAR}` cannot resolve a crunched name — `NO SYMBOL FILE FOR {}` | `#SYMFILE "@:PROG.SYM"`, before the `#INCLUDE`s |
| `GP.BOX X,Y,W,H,,7` | optionals cannot be skipped over | `GP.BOX X,Y,W,H,0,7` |
| `SCREEN` after `BMX.PAINT` | reloads the default palette and throws the image's colours away | set the mode first |
| `STR.FIELD$` wanted bigger | auto-`DIM`ed at 0..10 on first use, and you cannot `DIM` it after | `DIM` it **before** the first call, set `STR.MAX` |
| `#DEFINE X 129536` | `#DEFINE` takes an INT16 — `ERROR: INVALID PARAMETER` | an ordinary variable |
| `GP.SUB` above its `GP.DEFPROC` | the call carries an address, not a line number — `GP.SUB BEFORE ITS GP.DEFPROC` | declare the routine above every caller |
| an array element as a `GP.DEFPROC` formal | `GP.DEFPROC FORMAL IS NOT A VARIABLE` | plain scalar formals, and set the array before the call |
| a `GP.DEFPROC` body calling its own verb | one set of formals, so it writes over the arguments in use — wrong answer, no error | recursion needs its own saved copies, or a different shape |
| a variable called `LEN`, `ST`, `POS`, `MB` or `CHAR` | the name is a reserved word on its own | dot it — BASLOAD matches the whole identifier, so `LINEINPUT.LEN` works |

---

## 7. Memory, and what the compiler tells you

### The line GPC prints when it finishes

```
OK CODE 10734 FREE 10496 RT 13311 GP-BASIC IN
OK CODE 1234 FREE 19200 RT SHARED RT
```

| | |
|---|---|
| `CODE` | the p-code. What the program *is*, in bytes |
| `FREE` | what is left above it for variables, strings and arrays. **This is the number that runs out.** It already excludes the 4K frame stack, which is reserved rather than available |
| `RT` | the runtime bytes carried inside the object, or `SHARED` when the program loads `GPC.RT.nnn.BIN` at run time instead. `SHARED RC` asks for the core alone, `SHARED RT` for the core and the `GP.` handlers |
| `GP-BASIC` | embedded builds only. `IN` if a `GP.` keyword reached the 1,024-byte handler block and it had to go in the object, `OUT` if `ScanGPUsage` dropped it |

Two different budgets come off one figure, so read it twice:

- **`FREE` is the workspace** the running program has for its data.
- **`FREE` minus 4,096 is how much more p-code will fit.** `WriteObjectCode` refuses to leave less
  than 4K of workspace, so a build reporting `FREE 4096` is one page from `PROGRAM TOO BIG`.

A program can be comfortable on one and out of room on the other. `CODE 17406 FREE 4096` has 4K to
run in and nowhere left to grow; `CODE 10734 FREE 10496` has both.

### `OUT OF MEMORY`

Everything the program allocates comes out of the one `FREE` pool: scalars, arrays, and the string
heap. There is no separate heap to run out of.

- **A `DIM` costs its full size whether the entries are used or not.** `DIM A$(120)` is 121 string
  slots from the moment it runs. Five arrays dimensioned to the same 120 is 1,210 bytes gone before
  a single row exists.
- **A string block never shrinks.** Assigning a shorter string to a variable that already holds a
  longer one reuses the block it has; assigning a longer one allocates a new block and abandons the
  old. The abandoned blocks are reclaimed by the heap scavenger when one of the right size is
  wanted again, not immediately.
- **What fails is therefore a high-water mark, not a total.** The allocation that raises
  `OUT OF MEMORY` is rarely the large one — it is an ordinary one that arrives after the heap has
  been churned. The same key on the same screen can work or not depending on what was visited
  first, which is what makes it read as intermittent.

The error itself comes from the runtime library and names an address in it, not a line in your
program: `OUT OF MEMORY @ $03A5 library`. It tells you the allocator refused, and nothing about
which of your strings was asking.

### Staying inside it

- **Quote `FREE` when you change anything.** It is one line of build output and it is the only
  early warning; `PROGRAM TOO BIG` arrives once it is already too late.
- **Size a `DIM` to what is used, not to a round number.** The cost is paid on the first line of
  the program, forever.
- **Put bulk in a RAM bank.** A bank is 8,192 bytes that cost the workspace nothing. Anything held
  from start to finish and read a row at a time — a file's worth of text, a table, a screen — is
  better in a bank with an offset table at the front, read back with `PEEK` under `BANK`. See §4.5
  and `STASH.INC.BL` for the pattern.
- **A big temporary cannot be built and then freed.** Freeing is not a thing that happens on
  demand: build it in a bank, or in pieces.
