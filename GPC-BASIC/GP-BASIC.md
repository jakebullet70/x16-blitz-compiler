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

Three layers, innermost first.

**Core keywords.** 30 tokens, `GP.DO` down to `GP.CHAR`: `GP.DO` `GP.LOOP` `GP.EXITDO`, `GP.IF`
`GP.ELSEIF` `GP.ELSE` `GP.ENDIF`, `GP.SELECT` `GP.CASE` `GP.OTHER` `GP.ENDSEL`, `GP.INSTR` `GP.COMP`
`GP.STRPTR` `GP.ARRPTR`, `GP.BOX` `GP.FILL` `GP.CHAR` `GP.PRINTAT`, `GP.CALL` with `GP.A` `GP.X`
`GP.Y` `GP.C`, `GP.ASM` `GP.ENDASM`. Compiled to p-code, handled by assembly in the runtime. They
are assembly because BASIC is slow at what they do: per-character string scans, screen fills, VERA
writes.

The handlers occupy `GPBase $3800` to `ObjectBase $3c00` — **1,024 bytes**, page aligned, all or
nothing. `ScanGPUsage` walks the finished p-code and drops the whole block from the object if
nothing in it is reached.

**What the block costs is 1,024 bytes, once.** The bytes in the object and the bytes off the
workspace floor are the same bytes: `runtimeEndPage` is one page number, and it decides how much of
the runtime image is written out, where the p-code lands, and where the workspace starts. Max
p-code is **17,152 bytes with the block, 18,176 without** — `ObjectBase` to `$9F00`, less the 4K
frame stack and the 4K minimum workspace.

**Composites.** `GP.CONTAINS`, `GP.ISEMPTY`, `GP.HIBYTE`, `GP.LOBYTE`. The compiler expands each
into opcodes that already exist: no handler, no vector slot, nothing in the block.

**The library.** `GPC-BASIC/`: 14 `.INC.BL` modules, 22 `.EXP.BL` examples. Ordinary BASL,
`#INCLUDE`d by path, called with `GOSUB`. Zero runtime bytes — a module costs its own p-code, in the
programs that include it. Menus vertical and bar, panels, themes, entry fields, in-place case and
trim, shell sort, a screen rectangle to a RAM bank or a file, BMX into VERA.

`STASH.INC.BL`, `SORT.INC.BL` and `STRCASE.INC.BL` are `GP.ASM` and still modules: as keywords their
925 bytes (329, 408, 188) would sit in the block, paid by every GP program. `GP.ARRPTR` and
`GP.STRPTR` are what lets them out — a BASL subroutine takes an address, not an array or a string.

**Which side a thing goes on:** assembly for loops and bulk moves, BASIC for the rest.
`LINEINPUT.GET` waits on the keyboard, so speed is not an argument for it — 166 bytes of runtime
saved by writing it in BASL.

---

## 2. Using it

Every BASL source that uses a `GP.` keyword must declare the tokens:

```basic
#INCLUDE "GPB.INC.BL"
```

**BASLOAD knows only the ROM's keywords.** Without that line `GP.DO 5` is a syntax error. (The
host-side tokeniser for hand-written `.bas` needs nothing — it learns the same tokens from
`c64tokens.py` at build time.)

### Where the library lives

Keep `GPC-BASIC/` as a folder beside your own sources and include from it by path:

```basic
#INCLUDE "/GPC-BASIC/GPB.INC.BL"
```

**`#INCLUDE` takes a path, not just a bare filename** — verified on R49, both absolute
(`/GPC-BASIC/GPB.INC.BL`) and relative (`GPC-BASIC/GPB.INC.BL`). Prefer the leading slash: it is
absolute from the drive root, so it still resolves when your own program sits in a subdirectory.
`../` and `//` are not understood by the X16's filesystem, so a path goes down from somewhere,
never up.

Earlier versions of this manual said the include had to be a bare filename and told you to copy the
library next to every program. That was wrong, and it meant twenty-odd files in your working folder
for no reason.

Then it is BASLOAD and GPC as usual: `BASLOAD "MYPROG.BL"`, then compile the PRG with `GPC.PRG`.

### A program that uses GP.BASIC is compile-only

One GP.BASIC keyword is enough: from there the program is **compiler input**, and the ROM can no
longer `LIST` or `RUN` it. BASLOAD tokenises those keywords into `$CE58`-`$CE7F` and stock BASIC
has no handler behind those bytes.

**GPB is what GPC implements, and it has no existence apart from it.** The keyword set is not an
extension the ROM might one day understand, or a library that could be loaded to make it work:
`GP.DO` means something because the compiler emits code for it, and nowhere else. That is why the
tokenised file is not a program yet — there is nothing to run it with but GPC.

Which is the whole point, not a limitation. Run `GPC.PRG` on the tokenised `.PRG`, and run the
object it writes.

### Numbers, and what a variable holds

One numeric type on the evaluation stack: a 4-byte mantissa, a 1-byte exponent and a status byte
carrying the sign. Exponent 0 means the value is an exact integer.

| Variable | Bytes | Holds |
|---|---:|---|
| `A` `A()` | 6 | mantissa, exponent, status. Exact integers while the exponent is 0 |
| `A%` `A%()` | 2 | signed 16-bit two's complement, **-32,768 to 32,767** |
| `A$` `A$()` | 2 | a pointer into the string heap |

**`%` is not a faster integer, it is a smaller one, and it truncates in silence.** `WriteInteger`
stores the low two bytes of whatever is on the stack and `ReadInteger` sign-extends the MSB back, so
`A% = 49152` reads back as -16,384 with no error. Counters, indices and screen coordinates: yes.
Addresses: no.

**No address fits `%`.** Main RAM runs to `$9F00` (40,704), the string heap is above 32,767 by
definition, and a VRAM address is 17 bits (up to 131,071). Keep an address in an untyped variable,
which holds all three exactly, or split it into page and offset.

Numeric literals above 65,535 are fine. The compiler has a 16-bit fast path for constants and
anything wider compiles through the float encoder instead — no wrap.

`AND` and `OR` are 16-bit signed and raise `OUT OF RANGE` above 32,767; see §6.

---

## 3. Command reference

30 tokens, `$CE7F` down to `$CE58`, allocated downward. Ten of the forty slots are holes, and they
stay holes: the token values are the ABI and are never renumbered.

### At a glance — the whole library, and what each part costs

Everything GP.BASIC gives you, and **where it comes from**. The rest of §3 is the keywords;
the BASIC modules are written up in §4.

- **ASM** — a keyword the compiler knows, run by machine code in the runtime. Costs runtime bytes,
  and a program that uses one GP keyword pays for the whole block. Written in §3.
- **BASIC** — a `.INC.BL` module of ordinary BASL, called with `GOSUB`. Costs **nothing** unless you
  `#INCLUDE` it, and then only its own p-code. Written in §4.
- **COMPOSITE** — a keyword the compiler knows that has **no machine code of its own**. The compiler
  expands it into keywords that already exist, so it reads like a keyword and costs the runtime
  nothing at all. Written in §3 alongside the ASM ones.

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
| **Screen** | ASM | `GP.BOX` `GP.FILL` `GP.PRINTAT` |
| **Screen** | COMPOSITE | `GP.CHAR` — free, one cell in `GP.PRINTAT`'s shape running `GP.FILL`'s handler |
| **Colour roles** | BASIC | `THEME.INC.BL` — `THEME.LOAD`, `THEME.CLR()` · §4.1 |
| **String helpers** | BASIC | `STRINGS.INC.BL` — `PADR` `PADL` `PADC` `SPLIT` `REPLACE` `PET2SCR` · §4.2 |
| **Screen etiquette, panels** | BASIC | `APPSYS.INC.BL` — `STARTUP` `RESTORE` `PANEL.SAVE/LOAD/PUT` · §4.3 |
| **Entry fields** | BASIC | `LINEINPUT.INC.BL` — `LINEINPUT.GET`, `LINEINPUT.ASK` · §4.4 |
| **Bitmaps** | BASIC | `BMX.INC.BL` — `BMX.SHOW`, `BMX.RESTORE` · §4.5 |
| **Menus** | BASIC | `MENUVERT.INC.BL` — `RUN` `DRAW` `ROW` `HOTFIND` · §4.6 |

**The rule that decides the side** is in §1: assembly gets what runs in a tight loop or moves bulk
data, BASIC gets everything else — and anything that is only a *rename* of keywords already present
gets neither, and becomes a composite. A menu waits on a human, so it is BASIC: as a keyword it
would cost every GPB program 462 bytes whether it had a menu or not.

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
GP.SELECT <var>
GP.CASE <expr> [,<expr> ...]
    ...
GP.OTHER
    ...
GP.ENDSEL
```

The selector is a **plain numeric variable**, re-read at each `GP.CASE`; the tests run in the order
written and the first match wins. `GP.OTHER` is optional. **Nothing matching with no `GP.OTHER` is not
an error** — the whole select is simply skipped.

An expression, a constant or an array element is refused at compile time. Assign it to a scalar
first — `T = RND(1)*3 : GP.SELECT T` — which is also what makes the re-read sound: a scalar is a
fixed slot, so reading it seven times is the same value seven times. What the restriction buys is
that the whole construct compiles to core opcodes: **a program whose only GP keyword is a select
does not carry the GP block at all**, exactly like `GP.IF`.

Case values are ordinary numeric **expressions**, not just constants — which is a step past prog8's
`when`, whose choices must be compile-time integers.

**`GP.ENDSEL` is required** — not for cleanup, of which there is none, but for structure: the
compiler has no symbol table, the emitted tokens ARE the block, and every case branch resolves by
scanning forward to it.

**A case body takes its statements on the same line**, after a colon, which is what makes a sparse
dispatch read as the table it is:

```basic
GP.SELECT ED.KEY
  GP.CASE 157 : GOSUB ED.MOVE.LEFT
  GP.CASE 29  : GOSUB ED.MOVE.RIGHT
  GP.CASE 27  : MENU.ACTIVE = 0 : GOSUB ED.OPEN.MENUBAR
  GP.OTHER    : GOSUB ED.KEY.RANGE
GP.ENDSEL
```

More than one statement after the colon is fine, and so is `GP.OTHER`. The body may still go on the
following lines instead — both forms are the same code.

> **`GOTO` out of a select is safe, and trivially so**: a select keeps nothing alive, so there is
> nothing to leak. `GP.DO` is the one block that still opens a stack frame, and a `GOTO` leaving one
> is covered too — the compiler puts an `.unwind` in front of it and `FixBranches` fills in how many
> loop frames it closes. No runtime bytes, two p-code bytes at the `GOTO` itself.
>
> One thing that does not cover, because nothing could: a `GOTO` **sideways**, out of one `GP.DO` and
> into a different one at the same depth. The count comes out zero and the loop frame survives.

**This does not replace `ON x GOTO/GOSUB`**, which is a real skip table and remains the right answer
for a dense `1..n` index. `GP.SELECT` is for the **sparse** selector — key codes, state machines,
bit depths — where `ON` cannot go.

```basic
GP.SELECT BMX.DEPTH
    GP.CASE 8
    GP.CASE 1, 2, 4
        BMX.ERROR$ = "NEEDS ANOTHER SCREEN MODE"
    GP.OTHER
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

#### Splitting an address — `GP.HIBYTE` / `GP.LOBYTE`

| Form | Does |
|---|---|
| `GP.HIBYTE(n)` | `INT(n / 256)` — which 256-byte page. **Composite** |
| `GP.LOBYTE(n)` | `MOD(n, 256)` — the offset within it. **Composite** |

A 6502 address is sixteen bits, and everything that consumes one takes eight at a time — `GP.CALL`'s
registers, VERA's `$9F20`/`$9F21`. So every address that leaves BASIC for machine code gets split,
and `GP.STRPTR` / `GP.ARRPTR` exist in order to hand one over:

```basic
P = GP.STRPTR(A$)
GP.CALL $A000, GP.LOBYTE(P), GP.HIBYTE(P)
```

> **This is the reason they are keywords rather than something you write out.** The spelling that
> looks right — `P AND 255` — is a **live bug** in GPC: `AND` is 16-bit *signed*, and every address
> worth splitting is above 32767 (the string heap always is), so it raises `OUT OF RANGE` instead of
> masking. `GP.LOBYTE` is built on `MOD`, which runs through the full 32-bit divide and is not on
> that path.

Range is 0–65535, which is every address on the machine. Both are **composite** — they add no
runtime code, and compile to exactly `INT(n/256)` and `MOD(n,256)`.

Example: [`MLCALL.EXP.BL`](MLCALL.EXP.BL)

> **For anything longer than a few bytes, write it as assembly instead — §3.9.** `GP.ASM`
> assembles into the program, so there is no bank to reserve, no POKE loop, and no comment to
> keep in step with a list of numbers.

---

### 3.4 Strings

| Form | Does |
|---|---|
| `GP.INSTR(hay$, needle$ [,start])` | position of `needle$`, 1-based; **0 = not found**. `start` is where to begin |
| `GP.CONTAINS(hay$, needle$)` | −1 if `needle$` occurs anywhere in `hay$`, 0 if not. **Composite** — see below |
| `GP.ISEMPTY(a$)` | −1 if `a$` has zero length, 0 if not. **Composite** |
| `GP.COMP(a$, b$)` | compare **ignoring case**: −1 before, 0 same, 1 after |
| `GP.STRPTR(a$)` | address of the string's `[ActLen][Data]` block |

> **Trimming and case folding are `STRCASE.INC.BL`** (§4.8), not keywords: 188 bytes in the GP
> block, which is all or nothing, to serve one caller in the whole tree outside its own example.
> `GP.STRPTR` is here because that is what the module is built on.

`GP.INSTR` is the gap that matters: **GPC has no string search of any kind** without it.

`GP.CONTAINS` is the yes/no spelling of the same question, for when you do not care *where*:
`IF GP.CONTAINS(F$, ".BAS")`. It is **case sensitive** — it compares raw bytes, like `GP.INSTR` —
so reach for `GP.COMP` when you need case-blind. An **empty needle is 0**, not −1, because
`GP.INSTR` reports "not found" for one and this is built on it.

> **`GP.CONTAINS` is the library's first COMPOSITE keyword: it adds no runtime code at all.**
> The compiler expands it into `GP.INSTR(hay$, needle$) <> 0`, and the compiled object is
> byte-for-byte identical to writing that out by hand (verified by compiling both). So it costs
> nothing to use *and* nothing to have — unlike every other `GP.` keyword, whose machine code is
> linked into every GPB program whether you call it or not. If you ever want the position rather
> than a flag, write the `GP.INSTR` out; you are not paying twice for the two spellings.

`GP.ISEMPTY(a$)` is `LEN(a$) = 0` with the question written down instead of implied. **A string of
spaces is not empty** — `STRCASE.TRIM` it first if that is what you meant. It is for readability only:
it compiles to the same four bytes as `LEN(a$)=0`, and `IF a$=""` costs about the same again
(a literal points *into* the p-code, so even the empty string allocates nothing). Do not pick
between the three on size.

`GP.COMP` gives you a case-blind equality test — `IF GP.COMP(A$,B$) = 0` — which plain `=` cannot do,
and the comparator for ordering names. Length breaks a tie, so `"abc"` sorts before `"ABCD"`.

**The five in-place statements take a string VARIABLE**, never a literal or an expression; the
compiler rejects those. Case conversion leaves digits, punctuation and PETSCII graphics untouched.

**There is no `GP.PAD`.** Padding *grows* a string, and an in-place handler receives only the string's
block, never the variable slot — so it can never reallocate past the capacity the string was born
with. Use `STR.PADR` / `PADL` / `PADC` (§4.2), which are plain BASIC assignment and reallocate.

#### `GP.STRPTR` and the address-splitting trap

The address is of `[ActLen][Data]`: **length at that address, first character at +1**, and the
block's capacity at −2. With `GP.CALL` that lets machine code fill a BASIC string in place and set
its length — something stock BASIC cannot do at all.

> **Splitting the address, do NOT write `P AND 255`.** `AND` is **16-bit signed** in GPC and the string
> heap lives above 32767, so it raises `OUT OF RANGE` rather than masking. Write:
> ```basic
> GP.CALL $A000, GP.LOBYTE(P), GP.HIBYTE(P)
> ```
> — see §3.3. The longhand `H = INT(P / 256) : L = P - H * 256` is still correct and is what the
> keywords compile to. This applies to `GP.ARRPTR` and to every VRAM address past the top eighth
> of the screen too.

Example: [`STRINGS.EXP.BL`](STRINGS.EXP.BL)

---

### 3.5 Arrays

```
GP.ARRPTR(a())
```

> **Sorting is `SORT.INC.BL`** (§4.7), not a keyword: 408 bytes of the GP block, which is all or
> nothing, carried by every program that never sorted anything. `GP.ARRPTR` is here because the
> module is built on it — a BASL subroutine cannot be handed an array, so an address is the only
> interface there is.

`GP.ARRPTR` returns the address of **element zero** — the header is already skipped — so machine code
reached by `GP.CALL` can work on the array in bulk. **Stride is yours to add:** 2 bytes per element
for a string array (each element is a *pointer* to the string's block — follow it, and see
`GP.STRPTR` for the layout), 6 for a numeric one. Multi-dimensional arrays are rejected, and
`GP.ARRPTR(A(3))` is a syntax error — add `3*2` or `3*6` yourself.

Example: [`ARRAYS.EXP.BL`](ARRAYS.EXP.BL)

---

### 3.6 Screen — stash and restore

**Stashing a rectangle is `STASH.INC.BL`,** written in `GP.ASM`, not a keyword: a self-describing
4-byte header and a 4,094-cell ceiling — a bank is 8K and a cell is two bytes, so a full 80×60
screen at 9,600 bytes does not fit. As keywords it would be 329 bytes of the GP block, which is all
or nothing, carried by every program that never stashed anything.

```
#SYMFILE "@:MYPROG.SYM"
#INCLUDE "STASH.INC.BL"
STASH.BANK = 8 : STASH.X = 10 : STASH.Y = 4 : STASH.W = 30 : STASH.H = 8
GOSUB STASH.SAVE
...
GOSUB STASH.RESTORE
```

`STASHFILE.INC.BL` is the same rectangle through a **file**, and a separate module because a BASL
module has no dead code elimination: everything it holds is compiled into every program that
includes it, called or not.

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

#### ISO mode is handled for you

In ISO mode — `PRINT CHR$(15)`, or a user pressing Ctrl+O — the VERA tile index **is** the character
code, so translating PETSCII to a screen code is not merely wasted work but wrong: `A` would go in as
`$01`. `GP.PRINTAT` reads the KERNAL's own ISO flag (bit 6 of `$0372`) per character and skips the
translation when it is set, so **a program that switches charset is simply correct, with no source
change and nothing to declare**. It costs 7 cycles a cell in PETSCII mode and *saves* 34 in ISO.

`GP.FILL` needs nothing: it converts its one character before the loop, and `$20` is a fixed point of
the translation, so a space fill — which is what padding and blanking are — is right in both modes.

**`GP.BOX` is the one that needs you to say something, and the custom-glyph form is how.** It does no
translation *at all* — its glyphs go straight to VERA as tile indices — so the four built-in styles
are PETSCII screen codes and come out as letters in ISO mode. No translation can fix that; ISO-8859-15
has no box-drawing characters, so there is nothing to translate *to*. But a style of **256 or more is
an address** of eight glyphs of your own, and in ISO mode a tile index *is* a character code, so ASCII
`+ - |` are a perfectly good frame:

```
ISO.GLYPH$ = "++++--||"                        ' TR TL BR BL TOP BOTTOM LEFT RIGHT
GP.BOX 50, 26, 4, 3, GP.STRPTR(ISO.GLYPH$) + 1, 1
```

`GP.STRPTR` hands over the string's block and the text starts at +1, so a plain string literal is the
cheapest way to carry the eight bytes. **This costs no runtime bytes** — the pointer form already
exists, and it is the same mechanism `samples/editor` uses to draw frames from a re-ordered font.

`ISO.EXP.BL` pins all of this, reading the cells back with `VPEEK` rather than trusting the display —
including the ISO box, whose corner, top edge and side read back as 43, 45 and 124.

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

**Every one of the four is alone on its line, and `THEN` is required.** There is no one-line form:
`GP.IF X > 5 THEN PRINT` is a syntax error, not a short IF. That is deliberate — a mandatory `THEN`
invites the one-line reading, and allowing it would mean a block that silently swallowed every line
down to the next `GP.ENDIF`. Stock `IF ... THEN` is untouched and remains the right answer for a
one-liner.

`GP.ELSEIF` may repeat as often as you like; `GP.ELSE` is optional. The first true condition wins and
nothing below it runs, so there is no "break" to forget. **Nothing matching with no `GP.ELSE` is not
an error** — the whole block is simply skipped. Conditions are numeric expressions, as everywhere
else.

**This is not a worse `GP.SELECT`, it is the other half.** A select fetches **one** value and compares
it against each alternative, which is what you want for a sparse key code or a state machine. A block
IF tests something **different** in every branch — ranges, compound conditions, a string in one arm
and a number in the next. Neither replaces the other.

> **`GP.ENDIF` is required**, but unlike `GP.ENDSEL` it does no work — there is no frame to release,
> because the condition is evaluated and consumed on the same line it is written. **So a `GOTO` out of
> a `GP.IF` is safe**, where one out of a select leaks the selector's frame. Leaving the `GP.ENDIF`
> off stops the compile with `STRUCTURE IMBALANCE` rather than guessing where you meant the block to
> end.

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

**It costs 14 bytes of runtime, and none of them are code.** All four of its p-code opcodes reuse a
handler that already existed: the two branches are the `.goto.z` and `.goto` handlers under different
names, and the two markers share one four-byte no-op. See §11 of `docs/blitz/GP-BASIC.TIERS.md`.

Example: [`IF.EXP.BL`](IF.EXP.BL)

---

### 3.9 Inline assembly

```
GP.ASM
REM <instruction>
...
GP.ENDASM
```

65C02 assembly, assembled by GPC at compile time, with the bytes going **into the program**.

Before this, running your own machine code meant assembling it yourself: work out the opcode for
each instruction, `POKE` the numbers into memory nothing else was using, and point `GP.CALL` at that
address. `GP.ASM` writes the instructions and the compiler works out the bytes. These two do the
same thing — increment A, then X, then Y:

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

**It costs no runtime bytes.** A block is five bytes of p-code plus your instructions, and every
handler it uses is already in every compiled program — so a program whose only GP.BASIC keyword is
`GP.ASM` still compiles **GP-BASIC OUT**, without the 1 KB GP block. Measured: `RT 12031`, the same as a
program using no GP keyword at all.

#### `#REM 1` is required

> The body rides in REM statements, because **BASLOAD stores REM text byte for byte**. Outside a
> REM, `ORA`, `AND`, `EOR` and `ROR` are BASIC keywords and the text is destroyed; inside one it
> arrives intact, braces and all. Lower case is fine — it is upshifted for you.
>
> **`#REM 0` is BASLOAD's default**, and with it the body is stripped before the compiler runs.
> That is why `GP.ASM` and `GP.ENDASM` are real keywords and not REMs: the block is still there to
> be found *empty*, and GPC says `BLOCK MISMATCH` instead of compiling a program that silently
> contains no code. Turn REMs back off after `GP.ENDASM`.

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

`BNE`/`BEQ`/`BRA` and the rest take a label, and so do `JMP` and `JSR`. **A branch further than 127
bytes is `OUT OF RANGE` at compile time**, on the line it is on — not a wrong address at run time.

#### `{VAR}` — a BASIC variable's slot

`{VAR}` is the **address of the variable's slot**, which is what makes reading and writing the same
thing: `LDA {N%}` reads it, `STA {N%}` writes it, in the slot BASIC itself uses.

| Form | Is |
|---|---|
| `{N}` `{N%}` `{N$}` | the scalar's slot |
| `{N()}` | the **array's** slot, which holds the base address of its data — an element is two steps, as through `GP.ARRPTR` |

The name is letters, digits and **dots**, starting with a letter — so `{DOC.GOT.OFF}` works, and the
dotted names the library and the samples use everywhere are reachable from assembly. Underscore is
not: BASLOAD allows it in a name, this does not, and `{A_B}` reads the name as `A`. Up to 64
characters, the same as BASLOAD.

> **`{VAR}` needs `#SYMFILE`, and that is the one thing to remember.** BASLOAD renames variables —
> `N%` becomes `A%`, which is how it gives you 64 significant characters on a two-character BASIC —
> and it does *not* rename REM text with them. So the code says `A%` while the REM still says
> `{N%}`. `#SYMFILE` is BASLOAD's own record of that mapping, and the compiler reads it:
>
> ```
> #SYMFILE "@:PROG.SYM"
> ```
>
> at the top of the source, named to match the PRG — compiling `PROG.PRG` reads `PROG.SYM`. Nothing
> else changes: `{N%}` is still written the way you wrote the variable.
>
> Two errors, both at compile time and both naming the line:
>
> | | means |
> |---|---|
> | `NO SYMBOL FILE FOR {}` | no `#SYMFILE`, or it is not beside the PRG under the matching name |
> | `UNKNOWN VARIABLE IN {}` | the name is not a variable of this program |
>
> `{VAR}` never *creates* a variable, which is the opposite of what an ordinary BASIC reference
> does — so **assign it once in BASIC first**, even `M% = 0`. A name that missed would otherwise
> hand back a slot BASIC never reads, and the block would run, store, and change nothing you can
> see.

#### What is not there

No expressions — `{N%}+1` and `LABEL+2` are not understood; use an index register, which is what
the 6502 wants anyway. Zero page or absolute is decided by the **operand**: `$34` is zero page,
`$0034` is absolute, a decimal under 256 is zero page. Every 65C02 addressing mode is available,
including the two the NMOS 6502 lacks — `LDA ($34)` and `JMP ($1234,X)` — except `BBR`/`BBS`/
`RMB`/`SMB`.

Registers come back through `GP.A` / `GP.X` / `GP.Y` / `GP.C` exactly as they do from `GP.CALL`,
because a block goes through the same `$030C`–`$030F` slots — **but those four are GP block
keywords, so reading one costs the 2 KB the block otherwise saves you.** `{VAR}` does not.

A body can come from a file, which is the same thing spelt differently — `#INCLUDE` splices it in
verbatim, and BASLOAD's own `REM #nn-mm` attribution means an error inside names the file:

```basic
#REM 1
GP.ASM
#INCLUDE "MACPTR.ASM"
GP.ENDASM
#REM 0
```

Example: [`ASM.EXP.BL`](ASM.EXP.BL)

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

### 4.2 `STRINGS.INC.BL` — string helpers

| Routine | in | out |
|---|---|---|
| `STR.PADR` | `STR.STR$` `STR.WIDTH` | `STR.STR$` left-justified |
| `STR.PADL` | same | right-justified |
| `STR.PADC` | same | centred (odd gap goes right) |
| `STR.SPLIT` | `STR.STR$` `STR.DELIM$` `STR.MAX` | `STR.N`, `STR.FIELD$(1..N)` |
| `STR.REPLACE` | `STR.STR$` `STR.FIND$` `STR.REPL$` | `STR.STR$`, every occurrence replaced |
| `STR.PET2SCR` | `STR.PET` | `STR.SCR` |

All three pad routines **leave a string already at or past the width alone. They pad; they never
truncate** — use `STRCASE.RTRIM` (§4.8) to go the other way.

`SPLIT` reads `STR.STR$` without modifying it. `STR.MAX` of 0 means 10. **Empty fields are
preserved**, which is what makes it safe for data rows: `"A,,C"` is three fields, `"A,"` is two.
Splitting an empty string gives one empty field, never zero. Reaching the limit is not an error and
loses nothing — the last field gets the whole unsplit remainder, delimiters and all.

**`STR.FIELD$` is the one array the library deliberately does NOT `DIM`.** Left alone, GPC's
implicit `DIM` gives 0..10. Want more, `DIM` it yourself **before the first call** and set
`STR.MAX` to match. `DIM`ming an array GPC has already auto-dimensioned is an error, so it is one
or the other. **This is the opposite of `THEME.CLR`** — worth keeping straight.

`REPLACE` swaps **every** occurrence of `STR.FIND$` for `STR.REPL$`, modifying
`STR.STR$` in place. The replacement may be shorter, longer, or `""` to delete. **Case
sensitive**, because `GP.INSTR` compares raw bytes.

> **It is safe when the replacement contains the thing being replaced** — `"A"` → `"AA"`
> terminates and gives you twice the As, where a naive in-place version loops forever. The routine
> builds a new string and never re-scans what it has already emitted. An **empty `STR.FIND$`
> leaves the string alone** rather than hanging; that falls out of `GP.INSTR` reporting "not
> found" for a zero-length needle, so no guard is needed. Like the pad routines it is **not length
> checked** — a longer replacement can push the result past 255 characters.

`PET2SCR` converts a PETSCII code to the screen code the tile map holds, for `TILE`, `TDATA` and
`VPOKE`. `GP.PRINTAT` and `GP.FILL` already do it internally.

Examples: [`SPLITT.EXP.BL`](SPLITT.EXP.BL)

### 4.3 `APPSYS.INC.BL` — start politely, leave it as you found it

| Routine | in | out |
|---|---|---|
| `APPSYS.STARTUP` | — | `APPSYS.MODE` `APPSYS.COLS` `APPSYS.ROWS` `APPSYS.COLOUR` |
| `APPSYS.RESTORE` | those | screen mode and colour put back |
| `APPSYS.PANEL.SAVE` | `APPSYS.FILE$` `.BANK` `.X` `.Y` `.W` `.H` [`.DEV`] | a file |
| `APPSYS.PANEL.LOAD` | `APPSYS.FILE$` `.BANK` | back where it came from |
| `APPSYS.PANEL.PUT` | `APPSYS.FILE$` `.BANK` `.X` `.Y` | pasted somewhere else |

```basic
GOSUB APPSYS.STARTUP
' ... the application, laid out with APPSYS.COLS / APPSYS.ROWS ...
GOSUB APPSYS.RESTORE : END
```

**Call `STARTUP` first, before any `SCREEN` or `COLOR` of your own** — it records the state as it
finds it, so anything you change beforehand is what gets restored.

**Lay out from `APPSYS.COLS` / `APPSYS.ROWS` rather than assuming 80×60.** The X16 boots 80×60 but
`SCREEN 0` is 40×30, and someone who prefers larger text is running one.

`APPSYS.DEV` defaults to 8. The panel routines themselves moved to `STASHFILE.INC.BL`; the panel
file is **self-describing** — the stash's 4-byte header goes in it — so loading needs nothing but
the name.

### 4.4 `LINEINPUT.INC.BL` — a positioned entry field

| Routine | in | out |
|---|---|---|
| `LINEINPUT.GET` | `LINEINPUT.X` `.Y` `.LEN` `.ATTR` `.TEXT$` `.MASK` | `LINEINPUT.TEXT$` `LINEINPUT.KEY` |
| `LINEINPUT.ASK` | the same plus `LINEINPUT.LABEL$` | the same; `LINEINPUT.X` restored |

```basic
LINEINPUT.X = 10 : LINEINPUT.Y = 6
LINEINPUT.LEN = 20
LINEINPUT.ATTR = THEME.CLR(THEME.TEXT)
LINEINPUT.TEXT$ = ""
GOSUB LINEINPUT.GET
IF LINEINPUT.KEY = 27 THEN GOTO CANCELLED
```

**This is what `INPUT` and `LINPUT` cannot do.** Both own the whole bottom of the screen, scroll it,
echo in whatever colour is current, and accept any length — all four fatal on a drawn screen. A field
stays where you put it, in the colour you give it, and stops at the width you allow.

`LINEINPUT.KEY` is the key that ended it, and it is what makes a **multi-field form** possible:

| | |
|---:|---|
| 13 | RETURN — finished |
| 27 / 3 | ESC / STOP — cancelled, and `LINEINPUT.TEXT$` is put back to what it was |
| 17 / 145 / 9 | cursor down / up / TAB — left the field, **text kept** |

So a form is a loop over fields, not a sequence of prompts, and the user can go back and fix the
first one without starting again.

`LINEINPUT.MASK` non-zero shows asterisks while holding the real string. The field never scrolls: when
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

### 4.6 `MENUVERT.INC.BL` — a vertical menu

| Routine | in | out |
|---|---|---|
| `MENUVERT.RUN` | the variables below | `MENUVERT.SEL` `MENUVERT.KEY` |
| `MENUVERT.DRAW` | the same | draws the menu without driving it |
| `MENUVERT.ROW` | `MENUVERT.DRAWROW` `MENUVERT.DRAWATTR` | one row, in the attribute you name |
| `MENUVERT.HOTFIND` | `MENUVERT.DRAWROW` `MENUVERT.DRAWTEXT$` | `MENUVERT.HOTAT` — where that row's hotkey letter sits, 1-based, or **0 for "do not tint"** |

**A menu is BASIC here, not assembly**, and that saves 462 bytes of assembly plus 11 of storage in
a block every GPB program would carry whether it had a menu or not. Assembly would be needed only to
move the highlight without knowing what text was underneath it, by swapping the cell's attribute
nibbles instead of redrawing. A menu written in BASIC **owns the item array**, so it can simply
print the row again — and the whole reason for the assembly goes with it.

It is not slower in any way a person can see: a nibble swap is 59 cycles a cell, `GP.FILL` is 31 and
`GP.PRINTAT` 94, so redrawing two rows costs about a millisecond against the swap's half, against a
16.7 ms frame.

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

The constants `MENUVERT.MUSTSEL`, `.KEEPMARK`, `.NOWRAP` and `.GAMEPAD` are defined for you; add
those rather than writing the numbers.

**A hotkey chooses its row, it does not merely move to it** — which is the entire point of having
one. `MENUVERT.HOT$` is one character per row in order, matched without case; it may be shorter than
`MENUVERT.COUNT`, in which case the later rows have none.

**`MENUVERT.HOTATTR` makes the shortcut visible** instead of leaving it a secret. The letter is found
in the row's own text — the first match for that row's `MENUVERT.HOT$` character, without case — so
nothing extra is passed in, and `" START"` with hotkey `S` needs no markup. A row whose text does not
contain its own hotkey is left alone rather than treated as an error, because the hotkey still works.
Only rows in the **normal** attribute are tinted: on the selected row the highlight *is* the message,
and a second colour inside the bar is noise.

> **The caller owns the `DIM`, deliberately.** A module cannot be handed an array in BASIC, so it has
> to name one — and if it `DIM`med that array itself it would have to guess a bound, then fail on the
> caller who wanted more. Leave `MENUVERT.ITEM$` undimensioned and GPC's implicit `DIM` gives you
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

Shell sort, Ciura's gap sequence — 132, 57, 23, 10, 4, 1 — moving the 2-byte element *pointers*
rather than string data, so a swap is a swap whatever the strings are: no temporary, no copying, no
heap traffic. That is what makes it worth assembly.

> **The array goes in as an address, and that is not a style choice.** A BASL subroutine cannot be
> handed an array, so `GP.ARRPTR` — which stayed a keyword for exactly this — turns one into an
> address the module can work through. The empty parentheses in `GP.ARRPTR(A$())` are required: `A$`
> and `A$()` are different variables.

`SORT.OK` is 0 if it refused: more than 255 elements (so **`DIM A$(254)` is the largest**, since
`DIM A$(255)` is 256 of them), or an array whose elements are not strings. The element count and the
type are read back out of the array's own header, three bytes below what `GP.ARRPTR` returns, so a
wrong count cannot be passed in.

**Never-assigned elements are empty strings, not garbage.** A `DIM A$(20)` with five entries filled
sorts its fifteen empties to the front; a null pointer is read as `""`, the same substitution the
runtime makes everywhere else.

`SORT.DESCEND` and `SORT.NOCASE` are ordinary variables, not arguments, so they are **sticky** — set
both on every call rather than inheriting what the last one left behind.

**Your program must have a `#SYMFILE`,** and it goes *before* the `#INCLUDE`s. The assembly reaches
BASIC's variables through `{VAR}` and BASLOAD crunches every name before the compiler sees it;
without the mapping the compile stops with `NO SYMBOL FILE FOR {}`.

Example: [`ARRAYS.EXP.BL`](ARRAYS.EXP.BL). Regression test:
[`SORT.EXP.BL`](SORT.EXP.BL), eight cases including a 200-element array — element 128 is where
the doubled index stops fitting in a byte, and every case is checked for **content** as well as
order, because a sort that reads the wrong element leaves the array beautifully sorted with the same
string in it twice.

---

### 4.8 `STRCASE.INC.BL` — case and trim, in place

| Routine | in | out |
|---|---|---|
| `STRCASE.GO` | `STRCASE.PTR` `STRCASE.MODE` | *(the string itself)* |

```
#SYMFILE "@:MYPROG.SYM"
#INCLUDE "STRCASE.INC.BL"

STRCASE.PTR = GP.STRPTR(LINE$)
STRCASE.MODE = STRCASE.RTRIM
GOSUB STRCASE.GO
```

| mode | does |
|---|---|
| `STRCASE.UPPER` | a–z → A–Z, everything else untouched |
| `STRCASE.LOWER` | A–Z → a–z, everything else untouched |
| `STRCASE.TRIM` | spaces off **both** ends |
| `STRCASE.LTRIM` | spaces off the **leading** end |
| `STRCASE.RTRIM` | spaces off the **trailing** end |

**One blob with the mode tested once**, at entry — never inside a loop, where the byte count is the
whole cost.

> **The argument is an address, and that is the point.** A BASL subroutine cannot be passed a
> variable, and the obvious workaround — copy the caller's string in, work on it, copy it back — is
> two allocations and two copies per call, which is exactly the heap traffic these were written in
> assembly to avoid. `GP.STRPTR` hands over the block and the assembly rewrites it where it lies.

> **Do not pass a literal.** `GP.STRPTR("hello")` is the address of that text inside the *p-code*,
> so upper-casing it edits the running program, and the edit survives to the next time that line
> runs. The keywords could not be misused this way — the compiler required a string *variable* at
> the call site — and a `GOSUB` has no equivalent. This is the one thing the move gives up.

`STRCASE.MODE` is **sticky**: it is an ordinary variable, not an argument, so a call that forgets to
set it silently repeats the last operation. Set both inputs every time, as with `SORT.DESCEND` and
`STASH.MOVE`.

There is still no pad here — padding *grows* a string, and nothing working on the block alone can
grow one past the capacity it was born with. That is `STR.PADR` (§4.2).

Example: [`STRINGS.EXP.BL`](STRINGS.EXP.BL). Regression test:
[`STRCTST.EXP.BL`](STRCTST.EXP.BL), twenty cases — empty, all-spaces, a single space, one
character, a single leading space (the boundary in the slide), 200 characters, and guard strings
either side to catch an off-by-one writing into the neighbouring block.

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
| `STR.` | `STRINGS.INC.BL` |
| `THEME.` | `THEME.INC.BL` |
| `APPSYS.` | `APPSYS.INC.BL` |
| `LINEINPUT.` | `LINEINPUT.INC.BL` |
| `MENUVERT.` | `MENUVERT.INC.BL` |
| `BMX.` / `BMXK.` | `BMX.INC.BL` (variables / its KERNAL constants) |

Pick anything else for your own program — `GAME.`, `MAP.`, `AIRLIFT.`. **A prefix costs nothing at
runtime**, because BASLOAD crunches every identifier down to a short BASIC variable: a long readable
name and a two-letter one compile to exactly the same thing.

**Do not reuse a taken prefix even for something the module has not defined.** `THEME.MINE` looks
free today; it is one library update away from not being.

### `GP.*` is keywords, not variables

`GPB.INC.BL` defines **no variables at all** — 27 `#TOKEN` lines and nothing else.

```basic
GP.A = 5          ' SYNTAX ERROR — GP.A is a keyword
X = GP.A          ' correct
```

The value words are `GP.A` `GP.X` `GP.Y` `GP.C` — the registers after `GP.CALL`, and now the whole
list of them. They are tokens rather than variables for a hard reason: **nothing in the runtime
can write a BASIC variable by name**, so a command that hands a value back has to hand it back
through a keyword. X16's own `ST`, `MX` and `MY` exist for the same reason.

**→ The complete per-module in / out / internal register is [GP-BASIC.GLOBALS.md](GP-BASIC.GLOBALS.md),
with a script in §6 *of that file* for re-checking it after a change.**

---

## 6. The traps, collected

Every one of these has cost a debugging session at least once.

| Trap | What happens | Do this |
|---|---|---|
| `P AND 255` on a heap or VRAM address | `AND` is **16-bit signed**; above 32767 it raises `OUT OF RANGE` instead of masking | `H = INT(P/256) : L = P - H*256` |
| an address in an `A%` variable | `%` is signed 16-bit and truncates silently — `A% = 49152` reads back -16,384 | untyped variable, or split into page and offset |
| `$0400` for machine code | stock BASIC leaves it free, **a compiled GPC program does not** — runtime state lives there, and it corrupts silently | banked RAM, `$A000`–`$BFFF` |
| `PRINT` after `GP.PRINTAT` | GP drawing never calls the KERNAL, so the cursor is wherever it was | `LOCATE` first, or stay in one world |
| `SORT.INC.BL` with no `#SYMFILE` | `{VAR}` cannot resolve a crunched name — `NO SYMBOL FILE FOR {}` | `#SYMFILE "@:PROG.SYM"`, before the `#INCLUDE`s |
| `GP.BOX X,Y,W,H,,7` | optionals cannot be skipped over | `GP.BOX X,Y,W,H,0,7` |
| `SCREEN` after `BMX.PAINT` | reloads the default palette and throws the image's colours away | set the mode first |
| `STR.FIELD$` wanted bigger | auto-`DIM`ed at 0..10 on first use, and you cannot `DIM` it after | `DIM` it **before** the first call, set `STR.MAX` |
| `#DEFINE X 129536` | `#DEFINE` takes an **INT16** — `ERROR: INVALID PARAMETER` | an ordinary variable |

The last one is worth its own sentence. **Inside BASL you are safe** — 64 significant characters, so
`PANEL.COL` and `PANEL.ROW` are genuinely different variables and the readable names cost nothing.
Write the same test as a raw `.bas` for the host tokeniser and the two-character rule is back. It
cost two test cycles during tier 6, both times looking exactly like a compiler bug.

Dotted names also dodge the keyword-collision trap: `MENUVERT.COUNT`, `THEME.CLR`, `LINEINPUT.LEN` and
`LINEINPUT.RETURN` all contain reserved words and all work, because BASLOAD matches the whole
identifier. An **undotted** one does not — `POS`, `MB`, `ST`, `LEN`, `CHAR` cannot be variables at
all. That is the main reason the library is dotted throughout.
