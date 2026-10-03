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

### Overview

GP.BASIC (GPB) is the keyword extension GPC compiles with BASLOAD-formatted X16 BASIC: 40 `GP.*`
keywords and a library of BASL modules written on them.

The keywords are not a preprocessor pass. `GPB.INC.BL` declares the 40 names to BASLOAD with
`#TOKEN`, plus `RETURNS` for `GP.FN`'s clause. BASLOAD encodes them as byte pairs and GPC
compiles them to p-code. BASLOAD knows only the ROM's keywords, so a source without
`#INCLUDE "GPB.INC.BL"` fails on the first `GP.` line. §2 has the setup.

The library is separate. A module is ordinary BASL source that uses the keywords, `#INCLUDE`d by
name. Including one costs p-code in the including program and nothing in the keyword runtime.

### Architecture

The 40 keywords split by whether they need a runtime handler.

**Core: 30 keywords.** These compile to p-code and are handled by assembly in the runtime.

    GP.DO GP.LOOP GP.EXITDO
    GP.IF GP.ELSEIF GP.ELSE GP.ENDIF
    GP.SELECT GP.CASE GP.OTHER GP.ENDSEL
    GP.INSTR GP.COMP GP.STRPTR GP.ARRPTR
    GP.BOX GP.FILL GP.PRINTAT
    GP.CALL GP.A GP.X GP.Y GP.C
    GP.FN
    GP.BANKEDSTR GP.ENDBANKEDSTR GP.BSTR GP.BSTRSET
    GP.BANKED GP.ENDBANKED

Their handlers are one block, `GPBase $3000` to `ObjectBase $3600`: 1,536 bytes, page aligned, all
or nothing. `ScanGPUsage` walks the finished p-code and drops the block from the object when
nothing in it is reached.

**Composite: 10 keywords.** These expand into opcodes that already exist. They take no handler and
no vector slot.

    GP.ASM GP.ENDASM GP.CHAR GP.CONTAINS GP.ISEMPTY
    GP.HIBYTE GP.LOBYTE GP.BSTRCOUNT GP.DEFPROC GP.SUB

Whether the block comes in is the expansion's business, and the edge case is `GP.CHAR`: it runs
`GP.FILL`'s handler, so it pulls the block in. `GP.ASM`, `GP.ENDASM`, `GP.DEFPROC` and `GP.SUB`
leave it out.

The compile report names the outcome in its last word. `GPBASIC` means the block is linked, `CORE`
means it is not. A program whose only GP.BASIC keywords are composite ones that leave the block out
reports `CORE`. §7 reads the whole report.

### Requirements

| Needs | When |
|---|---|
| `#INCLUDE "GPB.INC.BL"` | every source using a `GP.` keyword |
| `GPB.RT.nnn.BIN` and `GP1.RT.nnn.BIN` | shared build, report says `GPBASIC` |
| `GPC.RT.nnn.BIN` and `GP1.RT.nnn.BIN` | shared build, report says `CORE` |
| nothing further | embedded build: the runtime is in the object |

`nnn` is the runtime build number, not the compiler build number. The bootstrap looks for the
runtime files in the current directory, then in `/GPC/`, then at the root of the SD card.
`GP1.RT.nnn.BIN` must sit in the same place as the runtime that loaded. An embedded build carries
the runtime and needs no `.BIN`.

A source that uses a `GP.` keyword is compiler input only. BASLOAD encodes the keywords as byte
pairs the ROM has no handler for, so stock BASIC can neither `LIST` nor `RUN` BASLOAD's output.
§2 covers the consequence.

### Components

`GPC-BASIC/` holds 31 `.INC.BL` modules, 28 `.EXP.BL` examples, and `GPB.INC.BL`, which is the
keyword declaration rather than a module. The modules cover menus, bars and dropdowns, panels,
themes, entry fields, check boxes, combo boxes, in-place case, trim and splice, `PRINT USING`,
shell sort, a screen rectangle to a RAM bank or a file, and BMX images into VERA.

Call a module with `GOSUB`, or with a `GP.SUB` / `GP.FN` verb where it offers one.

`STASH.INC.BL`, `SORT.INC.BL`, `STRCASE.INC.BL` and `STRINGS.INC.BL` are written in `GP.ASM`. They
are modules rather than keywords, so their bytes land in the including program and not in the
block.

§4 documents each module. §5 lists the names they take.

### Usage

```basic
#INCLUDE "GPB.INC.BL"
#INCLUDE "STRCASE.INC.BL"

A$ = "hello"
GP.SUB STRCASE.APPLY, GP.STRPTR(A$), STRCASE.UPPER
PRINT A$
END
```

### Limits

Maximum low p-code, in bytes:

| mode | CORE | GPBASIC |
|---|---|---|
| embedded | 22,528 | 20,992 |
| shared | 22,016 | 19,968 |

A shared program with a banked region loses a further 256: 19,712. `LOW FREE` in the compile
report, less 4,096, is how much more p-code will fit.

Low memory is what runs out. A program short of it can put a module's `#INCLUDE` inside a
`GP.BANKED` region and run it from a RAM bank, with no change to its callers. §3.12 has the rules.

---

## 2. Using it

Every BASL source that uses a `GP.` keyword must declare the keyword set:

```basic
#INCLUDE "GPB.INC.BL"
```

BASLOAD knows only the ROM's keywords. Without that line `GP.DO 5` is a syntax error.

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

40 keywords, encoded `$CE7F` down to `$CE4D` and allocated downward. Eleven of the fifty-one slots
are holes and stay holes: the byte values are the ABI and are never renumbered.

### At a glance — where each part comes from

Three implementations, and what each costs:

- **ASM** — a keyword run by machine code in the runtime. Costs runtime bytes, and one GP keyword
  anywhere in a program pays for the whole 1,536-byte block. Documented in §3.
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
| **Inline assembly** | COMPOSITE | `GP.ASM` `GP.ENDASM` — free, and leaves the block out, see §3.9 |
| **Strings** | ASM | `GP.INSTR` `GP.STRPTR` `GP.COMP` |
| **Strings** | COMPOSITE | `GP.CONTAINS` `GP.ISEMPTY` — free, see §3.4 |
| **Addresses** | COMPOSITE | `GP.HIBYTE` `GP.LOBYTE` — free, see §3.3.1 |
| **Arrays** | ASM | `GP.ARRPTR` |
| **Banked text** | ASM | `GP.BANKEDSTR` `GP.ENDBANKEDSTR` `GP.BSTR` `GP.BSTRSET` · `GP.BSTRCOUNT` is COMPOSITE — see §3.10 |
| **Routine calls** | COMPOSITE | `GP.DEFPROC` `GP.SUB` — free, and leaves the block out, see §3.11 |
| **Routine calls** | ASM | `GP.FN` — the same call as a value, and it brings the GP block in |
| **Screen** | ASM | `GP.BOX` `GP.FILL` `GP.PRINTAT` |
| **Screen** | COMPOSITE | `GP.CHAR` — free, one cell in `GP.PRINTAT`'s shape running `GP.FILL`'s handler |
| **Colour roles** | BASIC | `THEME.INC.BL` — `THEME.SELECT`, `THEME.CLR%()` · §4.1 |
| **String helpers** | BASIC+ASM | `STRINGS.INC.BL` — `PADR` `PADL` `PADC` `SPLIT` `REPLACE` `SPLICE` `PET2SCR` `TRIM` `LTRIM` `RTRIM` · §4.2 |
| **Screen etiquette, panels** | BASIC | `APPSYS.INC.BL` — `STARTUP` `RESTORE` `PANEL.SAVE/LOAD/PUT` `ISEMU` · §4.3 |
| **Entry fields** | BASIC | `LINEINPUT.INC.BL` — `LINEINPUT.GET`, `LINEINPUT.ASK` · §4.4 |
| **Bitmaps** | BASIC+ASM | `BMX.INC.BL` — `BMX.OPEN` `PAINT` `SHOW` `CLOSE` `RESTORE`, `BMX.LOAD` a verb · §4.5 |
| **Menus** | BASIC | `MENU.INC.BL` — `MENU.BEGIN` `ITEM` `ITEMX` `SELECTED` `DRAWBAR`, `MENUTO.VERT` `MENUTO.BAR` · §4.6 |
| **Menus** | BASIC | `MENUPULL.INC.BL` — `MENUTO.PULLDOWN`, a dropdown under a bar item · §4.9 |
| **Dialogs** | BASIC | `GUI.INC.BL` — `GUI.SAY` `GUI.YN` `GUI.MENU` `GUI.INPUT` `GUI.OPEN` `GUI.CLOSE` · §4.11 |
| **Dialogs** | BASIC | `GUI-DIALOGS.INC.BL` — every dialog as a one-line verb · §4.12 |
| **Dialogs** | BASIC | `COMBO.INC.BL` — `COMBO.ADD`, a drop-down that folds into one row · §4.17 |
| **Dialogs** | BASIC | `CHECK.INC.BL` — `CHECK.ADD`, a check box, `[X]` or `[ ]` · §4.21 |
| **Dialogs** | BASIC | `GUI-LITE.INC.BL` — `MSGBOX` `PICKMENU` `CLOSEBOX`, in low memory, nothing banked · §4.24 |
| **Code in a bank** | ASM | `GP.BANKED` `GP.ENDBANKED` — p-code at `$A000`, out of the low-memory budget, see §3.12 |
| **Bank ownership** | BASIC | `BANKMGR.INC.BL` — `INIT` `CLAIM` `GET.FREE.BANK` `RELEASE` `COUNT` `SPACE` · §4.13 |
| **Key-value store** | BASIC | `KV.INC.BL` — `INIT` `GET` `PUT` `DEL` `FIND` `AT` `WIPE` `SAVE` `LOAD`, strings in one RAM bank · §4.20 |
| **Key-value store** | BASIC | `KVBIN.INC.BL` — `CREATE` `INFO` `GET` `PUT` `DEL` `AT` `FIRST` `NEXT` `STOP` `EXPAND`, strings in one file that every program shares · §4.26 |
| **Keyboard** | BASIC | `KB.INC.BL` — `KB.CLEARKB` · §4.14 |
| **The drive** | BASIC | `FILEIO.INC.BL` — `STATUS` `EXISTS` `SIZE` `DELETE` `RENAME` `COPY` `MKDIR` `CHDIR` `SAVEARRAY` `LOADARRAY` · §4.15 |
| **The drive** | BASIC | `FILEDIR.INC.BL` — `FILE.DIR.INIT` `OPEN` `NEXT`, into a bank or low RAM · §4.16 |
| **The drive** | BASIC | `DOS.INC.BL` — `DOSX` `DOSX.EXISTS`, the smaller alternative to `FILEIO` · §4.25 |
| **Screen — stash** | BASIC | `STASHVRAM.INC.BL` — `SV.SAVE` `SV.RESTORE` `SV.PUT` `SV.GET`, kept in VRAM · §4.18 |
| **Screen — stash** | BASIC | `STASHVRAMGC.INC.BL` — `SV.COMPACT` · §4.19 |
| **Numbers** | BASIC | `MATH.INC.BL` — `MATH.MIN` `MATH.MAX` · §4.22 |
| **Memory** | BASIC | `MEM.INC.BL` — `MEM.COPY` `MEM.FILL`, the KERNAL's block move · §4.23 |

The rule is in §1: assembly for tight loops and bulk data moves, BASIC for everything else, and a
composite for anything that is only a spelling of keywords already present.

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
GP.SELECT ED.KEY%
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
GP.CALL $FF5F, 0, 0, 0, 1 : REM KERNAL screen_mode, carry set = report
COLS = GP.X : ROWS = GP.Y
```

Put machine code in banked RAM, `$A000`–`$BFFF`, not at `$0400`. Stock X16 BASIC leaves `$0400`
free for the user; a compiled GPC program does not. That page holds runtime state
(`stringHighMemory`, `storeStartHigh`, `variableStartPage`), and code POKEd over it corrupts the
program without raising an error.

Example: [`MLCALL.EXP.BL`](MLCALL.EXP.BL)

For anything longer than a few bytes use `GP.ASM` (§3.9) instead of `GP.CALL` and a POKE loop. It
assembles into the program: no bank to reserve, and no list of numbers to keep in step with a
comment.

#### 3.3.1 `GP.HIBYTE` / `GP.LOBYTE` — split an address into two bytes

```entry
  Syntax    GP.HIBYTE(n)   GP.LOBYTE(n)
  Returns   GP.HIBYTE: INT(n / 256), the 256-byte page.
            GP.LOBYTE: MOD(n, 256), the offset within that page.
  Kind      COMPOSITE. Expands to INT(n/256) and MOD(n,256). No
            runtime code, and neither needs the GP block.
  Notes     n is 0-65,535, which covers every address on the machine.
            Everything that consumes an address takes eight bits at a
            time: GP.CALL's registers, VERA's $9F20/$9F21. The
            addresses to split come from GP.STRPTR (§3.4.5) and
            GP.ARRPTR (§3.5).
  WARNING   Never write P AND 255 for the low byte. AND is 16-bit
            signed and any address worth splitting is above 32,767,
            so it raises OUT OF RANGE instead of masking. GP.LOBYTE
            is built on MOD, which uses the full 32-bit divide.
  Example
```
```basic
            P = GP.STRPTR(A$)
            GP.CALL $A000, GP.LOBYTE(P), GP.HIBYTE(P)
```

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
            With GP.CALL (§3.3), machine code can fill a string in
            place and set its length. Stock BASIC cannot do that.
  WARNING   Split the address with GP.LOBYTE / GP.HIBYTE (§3.3.1),
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

Sorting a string array is `SORT.INC.BL` (§4.7). It takes the address `GP.ARRPTR` returns, because
a BASL subroutine cannot be passed an array.

`GP.ARRPTR` returns the address of element zero; the header is already skipped. Machine code called
through `GP.CALL` can then work on the array in bulk. Add the stride yourself: 2 bytes per element
for a string array (each element is a pointer to the string block — see `GP.STRPTR` for its layout),
6 for a numeric array. Multi-dimensional arrays are rejected, and `GP.ARRPTR(A(3))` is a syntax
error; write `3*2` or `3*6` into the address.

Example: [`ARRAYS.EXP.BL`](ARRAYS.EXP.BL)

---

### 3.6 Screen — stash and restore

Stashing a rectangle is `STASH.INC.BL`, written in `GP.ASM`. It writes a 4-byte self-describing
header and holds at most 4,094 cells: a bank is 8K and a cell is two bytes, so a full 80x60 screen
at 9,600 bytes does not fit.

```
#SYMFILE "@:MYPROG.SYM"
#INCLUDE "STASH.INC.BL"
STASH.BANK = 8 : STASH.X = 10 : STASH.Y = 4 : STASH.W = 30 : STASH.H = 8
GOSUB STASH.SAVE
...
GOSUB STASH.RESTORE
```

`STASHFILE.INC.BL` is the same rectangle through a file. It is a separate module because, unless
the compile removes dead code (§7), everything a module holds is compiled into every program that
includes it, called or not.

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
ISO.GLYPH$ = "++++--||" : REM TR TL BR BL TOP BOTTOM LEFT RIGHT
GP.BOX 50, 26, 4, 3, GP.STRPTR(ISO.GLYPH$) + 1, 1
```

`GP.STRPTR` returns the address of the string block and the text starts at +1, so a string literal
is the cheapest way to carry the eight bytes. This costs no runtime bytes; the pointer form already
exists, and `GPC-BASIC-TOOLS-SRC/edit` uses the same mechanism to draw frames from a re-ordered font.

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

| Part | Rule |
|---|---|
| `GP.IF` | one per block, alone on its line, `THEN` required |
| `GP.ELSEIF` | any number of them, `THEN` required |
| `GP.ELSE` | optional, at most one |
| `GP.ENDIF` | required; without it the compile stops on `STRUCTURE IMBALANCE` |
| condition | a numeric expression |

The first true condition runs and nothing below it does, so there is no break to omit. A block whose
conditions are all false and which has no `GP.ELSE` is skipped, which is not an error.

There is no one-line form. `GP.IF X > 5 THEN PRINT` is a syntax error. Stock `IF ... THEN` is
unchanged and is the one-line form.

Blocks nest freely: inside each other, inside a `GP.CASE` body (§3.2) and inside a `GP.DO` loop
(§3.1). Use `GP.SELECT` (§3.2) where one value is compared against each alternative, and a block IF
where each branch tests a different condition.

A `GOTO` out of a block is safe. The condition is evaluated and consumed on the line it is written,
so `GP.ENDIF` releases nothing. The block costs 14 runtime bytes.

```basic
GP.IF N < 0 THEN
    PRINT "NEGATIVE"
GP.ELSEIF N = 0 THEN
    PRINT "ZERO"
GP.ELSE
    PRINT "POSITIVE"
GP.ENDIF
```

Example: [`IF.EXP.BL`](IF.EXP.BL)

---

### 3.9 Inline assembly

```
#REM 1
GP.ASM
REM <instruction>
...
GP.ENDASM
#REM 0
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
#REM 1
GP.ASM
REM inc a
REM inx
REM iny
GP.ENDASM
#REM 0
```

It costs no runtime bytes. A block is five bytes of p-code plus the assembled instructions, and
every handler it uses is already in every compiled program. A program whose only GP.BASIC keyword is
`GP.ASM` compiles without the 1.5 KB block: measured `EMBEDDED CORE` and `RUNTIME 12031`, the same
as a program using no GP keyword.

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
#REM 1
GP.ASM
REM ldx #5
REM loop: lda #42
REM jsr $ffd2
REM dex
REM bne loop
GP.ENDASM
#REM 0
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
| `{} NEEDS #SYMFILE` | no `#SYMFILE`, or it is not beside the PRG under the matching name |
| `UNKNOWN VARIABLE IN {}` | the name is not a variable of this program |

`{VAR}` never creates a variable, unlike an ordinary BASIC reference. Assign the variable once in
BASIC first, even `M% = 0`. A name that does not exist otherwise resolves to a slot BASIC never
reads, and the block runs, stores, and changes nothing observable.

#### In a `GP.BANKED` region

A block inside a `GP.BANKED` region (§3.12) is assembled into the region's bank, after the region's
p-code, and runs from there with that bank selected. Its bytes count against the region's 8,192 and
not against low memory.

`GP.ASM LOW` keeps a block in low memory inside a region. Outside a region the word changes nothing.

```
#REM 1
GP.ASM LOW
REM <instruction>
...
GP.ENDASM
#REM 0
```

Use `LOW` for a block that writes `$00`, the RAM bank register. A block running from a bank cannot
select another: the next instruction is fetched from the bank it selected. `FILEDIR.INC.BL` (§4.16)
writes both of its blocks this way.

`LOW` needs a `#SYMFILE`. BASLOAD crunches `LOW` like any name, and the compiler reads it back
through the symbol file.

A block inside a region without `LOW` is checked for a store to `$00`: `STA`, `STX`, `STY` or `STZ`
to `$00` or `$0000`. The check does not see an indexed or indirect store, or a `JSR` to code that
changes the bank. Those compile, and the program fetches its next instruction from the wrong bank.

Two compile-time errors, both naming the line:

| | means |
|---|---|
| `GP.ASM LOW NEEDS #SYMFILE` | no `#SYMFILE`, or it is not beside the PRG under the matching name |
| `BANKED GP.ASM WRITES $00, USE GP.ASM LOW` | a block inside a region, without `LOW`, stores to `$00` |

#### What is not there

No expressions: `{N%}+1` and `LABEL+2` are not understood. Use an index register.

Zero page or absolute is decided by the operand. `$34` is zero page, `$0034` is absolute, and a
decimal under 256 is zero page. Every 65C02 addressing mode is available, including the two the NMOS
6502 lacks — `LDA ($34)` and `JMP ($1234,X)` — except `BBR`, `BBS`, `RMB` and `SMB`.

Registers come back through `GP.A` / `GP.X` / `GP.Y` / `GP.C` as they do from `GP.CALL`; a block
uses the same `$030C`–`$030F` slots. Those four are GP block keywords, so reading one pulls in the
1.5 KB block that `GP.ASM` alone avoids. `{VAR}` does not.

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
  SPC(20)
GP.ENDBANKEDSTR

  A$ = GP.BSTR(<NAME>, n)
  N  = GP.BSTRCOUNT(<NAME>)
  GP.BSTRSET <NAME>, n, A$
```

Moves a program's literal text out of low RAM and into a RAM bank, at compile time. A string
constant costs `2 + LEN` bytes of p-code wherever it appears; `GP.BSTR(NAME, n)` costs **5**, so
text of four characters or more is cheaper read from the bank than written in the line. Over half
of a menu-driven program's own code is usually literal text, and text is the one thing in a
program with no reason to be resident: it is never executed, never indexed, and read one item at a
time.

**The body is quoted lines and `SPC(n)`.** One item a line, nothing else on the line. A quoted
line passes through byte for byte, with its case, leading spaces and trailing spaces kept. `SPC(n)`
declares an empty slot of capacity `n`, and `n` is a decimal constant of 0 to 255. Both kinds count
as body lines, so a block of nothing but `SPC(n)` is not an empty block. Body lines are not `REM`
lines and must not be: BASLOAD upper-cases `REM` text.

**Blocks are named, and you may write as many as you like.** Each is indexed from zero within
itself, so inserting a line in one group moves nothing outside it. A block names the bank its text
goes in, written on each block rather than only the first so a block can be read where it sits.
Groups that name the same bank share it and fill it in the order the compiler reads them.

**The name costs nothing at run time.** It is resolved while the program compiles, into the
group's first index, and the compiler adds that to your index for you. No letter of the name
reaches the object, which is the whole reason the lookup is not in the bank.

`GP.BSTRCOUNT(NAME)` is a composite: it compiles to a plain number, so
`FOR I = 0 TO GP.BSTRCOUNT(BS.FILE) - 1` costs no more than writing the count out.

```basic
#DEFINE GM.TEXTBANK 5

GP.BANKEDSTR GM.TEXTBANK BS.FILE
  " OPEN "
  " SAVE "
  " QUIT "
GP.ENDBANKEDSTR

GP.BANKEDSTR GM.TEXTBANK BS.EDIT
  " CUT "
  " PASTE "
GP.ENDBANKEDSTR

  FOR I = 0 TO GP.BSTRCOUNT(BS.EDIT) - 1
    PRINT GP.BSTR(BS.EDIT, I)
  NEXT I
```

**Claim the bank**, exactly as a `GP.BANKED` code region's bank is claimed. The compiler picks it
while the object is written, so `BANKMGR` has to be told rather than asked:

```basic
BANKMGR.WANT = GM.TEXTBANK : GOSUB BANKMGR.CLAIM
```

**Either build.** Both put the text in one `NAME.OVL` file beside the program: the bootstrap
reads it for a shared build and `StartCode` reads it for an embedded one, so an embedded
program with banked text is a `.PRG` and a `.OVL` together. The runtime finds which bank a slot went to in a
sixteen-byte table at `$07F0`, in the low-memory hole both builds leave alone — the bootstrap
extension page writes it there for a shared program, and `StartCode` copies it out of the
image for an embedded one.

**A group name is not a variable.** No `$`, no `%`, no `(` — any of those is a syntax error rather
than something quietly ignored. A name that no block declared is a syntax error at the line that
used it, and so is a second block claiming a name already taken. An empty block is refused too: a
group of no strings would make `GP.BSTRCOUNT` zero and every `GP.BSTR` on it read the next group's
text.

**There is no run-time bounds check.** The compiler knows every index it emits and nothing a
program does can produce one out of range, so an index past the end of a group reads whatever
follows it. That is the same bargain the array fast path makes.

**`GP.BSTRSET <NAME>, n, A$` writes a slot.** It takes the same name and index pair as
`GP.BSTR(<NAME>, n)`, with no bracket. A record in the bank is
`[capacity][length][capacity bytes]`, and the capacity is fixed at compile time. A quoted body
line's capacity is its own length, so a quoted line can only ever be overwritten by something the
same length or shorter. `SPC(n)` is the way to get a slot with room in it.

**The write is cut to fit.** A string longer than the slot keeps its first `capacity` characters.
No error is raised. The next record is never touched. An index not below the bank's string count
writes nothing and raises nothing, and a slot whose bank is not present writes nothing.

**A program may have more than one text bank.** Sixteen of them, which is the range of the slot
field a group carries and the length of the table at `$07F0` — `BSTR_MAX_BANKS` in
`source/common-source/source/common.inc`. That matters when a library already owns one: `MENU`
keeps its rows in `MENU.TEXTBANK`, so a program using it and wanting a pool of its own names a
second bank rather than crowding into `MENU`'s. The other limits are 8 KB a bank, 128 groups a
program and 4,096 strings a bank.

Each text bank is a region, so it counts toward the 127 regions (§3.12) and no two regions may
share a bank.

`GP.BSTR` and `GP.BSTRSET` are ordinary GP keywords, so they pull in the 1.5 KB GP block; the two
block keywords do not, and neither does `GP.BSTRCOUNT`.

Reading it from inside a `GP.BANKED` region works: the handler puts the caller's bank back before
it returns. Writing from inside one works too. The compiler copies a string literal out of the
region first, because the text bank is the one at `$A000` while the write runs.

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
  inner call runs and finishes before the outer writes `A.W`. The values wait on the frame
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
            GP.FN (§3.11.3) reads after the call. Its type is the
            type of the call. Without it the verb is callable with
            GP.SUB (§3.11.2) only.
            Call the verb with GP.SUB as a statement, or with GP.FN
            inside an expression. Every call sits below the
            GP.DEFPROC that declares it.
  WARNING   An array or an array element cannot be a formal, and it
            cannot be the RETURNS variable either. A module whose
            arguments are array elements takes the verb and no
            formals, and its caller sets the array first.
  Example
```
```basic
            DB.SELECT:
              GP.DEFPROC DBSELECT, DB.A
              DB.ROW = DB.A : GOSUB DB.READ
              RETURN

            AREA:
              GP.DEFPROC AREA, A.W, A.H RETURNS A.R
              A.R = A.W * A.H
              RETURN

            REM calling them, anywhere below the declarations
              GP.SUB DBSELECT, 1
              PRINT "AREA "; GP.FN(AREA, 3, 4)
```

#### 3.11.2 `GP.SUB` — call a verb

```entry
  Syntax    GP.SUB verb [, expression ...]
  Does      Assigns each expression to the matching formal, in order,
            then calls the routine.
  Kind      COMPOSITE. Expands to an assignment per formal and a
            GOSUB.
  Notes     The count and the types must match the declaration. For
            the same call inside an expression use GP.FN (§3.11.3).
            A call into a GP.BANKED region selects its bank. A call
            into or out of a region comes back with the caller's
            bank selected.
  WARNING   The call must sit below its GP.DEFPROC (§3.11.1). It
            carries an address and not a line number, so a forward
            call is refused rather than compiled.
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
            A string result costs 3 bytes more: it is copied into a
            temporary, so two calls to one verb may share an
            expression.
  WARNING   The call must sit below its GP.DEFPROC (§3.11.1), as
            GP.SUB's (§3.11.2) does.
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
            PRINT GP.FN(TAG, "AB") + GP.FN(TAG, "CD")
            PRINT GP.FN(AREA, 2, GP.FN(AREA, 3, 4))
```

---

### 3.12 Code in a bank

```
GP.BANKED <bank>
    ... p-code ...
GP.ENDBANKED
```

Marks a run of p-code as belonging at `$A000` in that RAM bank rather than in low memory. Both
keywords are alone on their line and the bank is a decimal constant.

**They are compile-time markers and select nothing.** `BANK` is the statement that selects a bank,
and these are deliberately not spelled like it. Nothing happens at run time where the `GP.BANKED`
line is.

This is how a program gets past the shared p-code ceiling. Low-memory p-code has to fit under the
runtime — about 17,920 bytes, §7 — and a region does not count against it. Every region of the
program goes into one overlay file, `NAME.OVL`, written beside the `.PRG` and read in at startup.
That is true of an EMBEDDED build as well, so a banked program is two files in either mode.

```basic
#DEFINE MY.GUICODE 4
GOTO MY.LIBEND
GP.BANKED MY.GUICODE
#INCLUDE "MENU.INC.BANKED.BL"
#INCLUDE "MENU.INC.BL"
#INCLUDE "LINEINPUT.INC.BL"
#INCLUDE "GUI.INC.BL"
#INCLUDE "COMBO.INC.BL"
#INCLUDE "CHECK.INC.BL"
#INCLUDE "GUI-DIALOGS.INC.BL"
GP.ENDBANKED
MY.LIBEND:
```

**The `GOTO` over the region is not optional.** Falling in through the bridge `GP.BANKED` leaves
works at program start and stops working the day anything selects another bank first. The compiler
does not catch a fall-in.

**`#DEFINE` the bank above the `GP.BANKED` line.** BASLOAD replaces a name only once it has read its
`#DEFINE`, and the number is then fixed when the program compiles.

**Claim the bank**, or something else hands it out:

```basic
BANKMGR.SET.BANK% = MY.GUICODE : GOSUB BANKMGR.CLAIM
```

#### What fits

**32 pages — the whole of `$A000`–`$BFFF`, 8,192 bytes.** The entry bridge, the alignment padding,
the exit bridge, the end marker and every `GP.ASM` block in the region are part of what has to fit,
so the usable payload is a little under the window. Past it the compiler stops and names the region's `GP.BANKED` line, not the line
it happened to be on when it ran out.

**Banks 2 to 255, and at most 127 regions.** Bank 0 is the KERNAL's and bank 1 is reserved for the
runtime; the compiler refuses both. A 512 K X16 has banks up to 63 and a 2 MB one up to 255, and a
program that names a bank the machine does not have prints `?RAM` and returns to `READY` before it
loads anything. `GP.BANKEDSTR` banks count toward the 127: one region over it stops the compile
with `TOO MANY GP.BANKED REGIONS`, and one text bank over it with
`NO REGION LEFT FOR GP.BANKEDSTR TEXT`. **No two regions may share a bank**: the second would
land at `$A000` on top of the first.

#### What a region may not contain

**`BANK` is the one statement refused inside a region.** Code fetched from the window cannot be
running when the window changes, and `BANK` changes it and leaves it changed. `PEEK` and `POKE`
put the bank back after each access, and `BLOAD` and `BSAVE` are not refused. A `BANK` statement
keeps `STASH` and `STASHFILE` in low memory; `STASHVRAM` (§4.18) has none, so it goes in.

`GP.BANKEDSTR` (§3.10) inside a region is free: it emits no p-code at all, so a text group costs the
region nothing.

A `GP.ASM` block inside a region goes into the region's bank. A block that writes `$00`, the RAM
bank register, must be `GP.ASM LOW` (§3.9). The compiler refuses a direct store to `$00` without it.

#### Calling in, and calling out

**A call into a region selects the region's bank.** A `GOSUB`, `GP.SUB`, `GP.FN` or `FN` whose
target is inside a region, from anywhere outside that region, compiles to `.bgosub`. It keeps the
selected bank, selects the region's, and `RETURN` selects the kept one again. The caller may be in
low memory or in another region, and the calls nest like any `GOSUB`. A call that stays inside one
region is an ordinary `GOSUB`.

**A call out of a region to low memory is a banked call too.** A `GOSUB`, `GP.SUB`, `GP.FN` or `FN`
from inside a region to a target in low memory compiles to `.bgosub` with the region's own bank.
`RETURN` selects that bank again, so a low routine that executes `BANK` returns into the region
under the right bank.

**A `GOTO` selects nothing, so a `GOTO` into a region from outside it is refused** with
`NOT IMPLEMENTED`, from low memory or from another region. `IF ... GOTO`, `IF ... THEN <line>` and
`ON ... GOTO` are refused the same way. Enter a region by a call. A `GOTO` that stays inside one
region, or leaves one for low memory, compiles.

**`ON ... GOSUB` makes no banked call.** An `ON` entry is three bytes and a `.bgosub` is four.
`ON ... GOSUB` compiles when the caller and every target are in low memory, or all in the same
region. Into a region, out of a region to low memory, or from one region to another, the compile
stops with `ON GOSUB IN OR OUT OF GP.BANKED`. Write a `GP.SELECT` or one `IF ... GOSUB` a case
instead. A plain `GOSUB` makes the banked call.

**A call between a region and anywhere outside it costs a byte and two bank switches.** `.bgosub` is
a `GOSUB` with the bank after the address. Put a module called inside a tight loop in the same place
as the loop.

**A runtime error inside a region names its bank.** It prints the bank in hex, a colon, and the
address the p-code runs at: `DIVIDE BY ZERO @ $14:A048`. The debug map lists the region's lines in
the same form, and `GPC.ERR.PRG` reads both.

#### The overlay file

Every region of a program goes into one file, `NAME.OVL`, and the file says what is in it. Each
region is introduced by two bytes — the bank it belongs in, then how many pages of it follow — and
those pages come next. Then the next region, and so on to end of file. So **a region costs its
padded page count plus two bytes**, the padding rather than the p-code in it, and the banks may be
in any order with any gaps between them.

The overlay ships beside the `.PRG`, in both builds. The program reads it once per load, not once
per `RUN`, and a missing or truncated one stops it with `?OVL`; a region for a bank the machine does not
have stops it with `?RAM`. Nothing pairs a `.OVL` to its `.PRG`, so a stale one is read. §7 lists
every file a program ships.

**Reading it costs time at startup.** The bootstrap reads the file a byte at a time, at roughly
26,000 bytes a second, so a program with 32K of regions waits about a second and a quarter before
its first line runs. Nothing else in the program pays it.

---

## 4. Module reference — the BASL library

Called with `GOSUB`. Arguments go into named variables before the call, results come back in named
variables after it. Every module is position-independent — each jumps over itself — so `#INCLUDE` it
anywhere, including the top of the program.

**Any of them can run from a RAM bank.** Put its `#INCLUDE` between `GP.BANKED` and
`GP.ENDBANKED` (§3.12). A call into the region selects its bank, so the `GOSUB`s in this section
read the same either way.

`STASH` and `STASHFILE` are the two that cannot: both execute `BANK`, and a `GP.BANKED` region may
not contain that statement. `STASHVRAM` (§4.18) is the one to reach for inside a region. See
[BANKED-OR-NOT.md](BANKED-OR-NOT.md) and [GP-BASIC.GLOBALS.md](GP-BASIC.GLOBALS.md) §4.

### Low memory or a bank — what differs

A module is one file. `#INCLUDE "X.INC.BL"` puts it in low memory, and the same line between
`GP.BANKED` and `GP.ENDBANKED` puts it in a RAM bank. The `GOSUB` at the call site is the same
either way.

Low memory is the one that runs out. A SHARED program has about 17,920 bytes of p-code under the
runtime and every `#INCLUDE` spends it; a region spends 8,192 bytes of a RAM bank the program was
not using. Bank what you can. A module called inside a loop goes where the loop is: a call between
a region and anywhere outside it switches the bank twice.

The banked form works in either build, and both write the same `NAME.OVL` beside the program.
A SHARED program's bootstrap opens it; an EMBEDDED program opens it itself, at startup, before
the runtime begins. **So the first banked module makes an EMBEDDED program two files**: ship
the `.OVL` with the `.PRG`, and a program that cannot find it stops with `?OVL`. A program with
no region at all has no `.OVL` and is one file as before. Either way it loads with `LOAD` and
`RUN`.

The regions are never in the file the loader reads, so nothing caps them but the banks the
machine has; a region asking for a bank that is not there stops with `?RAM`. A banked embedded
program does carry the whole runtime rather than the smaller core, whether or not it calls a
GP.BASIC keyword.

`GPC-BASIC-TOOLS-SRC/GPB-MODS-TESTING/PICKDEMO.BASL` is a complete program in this shape, in 99 lines.

Banking a module makes room in either build, and it used to make room in only one. An embedded
object once carried its regions appended to the `.PRG`, so a byte moved into a region was still
a byte in the file and the last byte landed where it always had. The regions go in the `.OVL`
now, which the loader never reads, so a banked module leaves low memory and leaves the file
with it. Splitting the modules across more regions costs two header bytes a region and nothing
else. What a region does not buy is a smaller `.OVL`: the bytes are still shipped, in the file
beside the program rather than inside it.

| | low memory | a RAM bank |
|---|---|---|
| Include | `#INCLUDE "X.INC.BL"` | the same, inside `GP.BANKED` |
| Entry label | `THEME.SELECT` | `THEME.SELECT` |
| Costs per call | one `GOSUB`; from a region, one byte more and two bank switches | from outside the region, one byte more and two bank switches |
| Low memory used | the whole module | none |

```basic
#DEFINE MY.GUICODE 4
#DEFINE MY.THEMECODE 9
GOTO MY.LIBEND
GP.BANKED MY.THEMECODE
#INCLUDE "THEME.INC.BL"
GP.ENDBANKED
GP.BANKED MY.GUICODE
#INCLUDE "MENU.INC.BANKED.BL"
#INCLUDE "MENU.INC.BL"
#INCLUDE "LINEINPUT.INC.BL"
#INCLUDE "GUI.INC.BL"
#INCLUDE "COMBO.INC.BL"
#INCLUDE "CHECK.INC.BL"
#INCLUDE "GUI-DIALOGS.INC.BL"
GP.ENDBANKED
MY.LIBEND:
```

**A region is 8,192 bytes, and that is the whole of the grouping.** The GUI modules fill one, so
`THEME` has its own. `THEME` comes first because the GUI modules read its `#DEFINE`s. A call from
one region to the other costs the same bank switches as a call from low memory.

**Include a module once.** One `#INCLUDE` in low memory and another in a region is
`DUPLICATE SYMBOL` where the module has no `#IFNDEF` guard. Where it has one, the module lands at
the first `#INCLUDE` and the second produces nothing.

§3.12 has the rules, what a region may not contain, and the `.OVL` file a banked program ships.

### 4.1 `THEME.INC.BL` — named colour roles

| Routine | in | out |
|---|---|---|
| `THEME.SELECT` | `THEME.ID%` | fills `THEME.CLR%()` |
| `THEME.NEXT` | `THEME.ID%` | the following theme, loaded |
| `THEME.RESET` | `THEME.ID%` | the selected theme's shipped values, reloaded |
| `THEME.SET` | `THEME.ATTR%` | issues `COLOR` — makes it the colour `PRINT` uses |
| `THEME.HI` | `THEME.ATTR%` | `THEME.INV%`, the inverse attribute |

Five themes, `THEME.COUNT` of them:

| `THEME.ID%` | | |
|---:|---|---|
| 0 | `X16` | blue page, white text, cyan headings. The default |
| 1 | `DARK` | black page, light grey text |
| 2 | `LIGHT` | white page, black text |
| 3 | `GRAY` | dark grey page, light blue frames. From the XFMGR file manager |
| 4 | `CUSTOM` | whatever `THEME.CLR%()` already holds |

`THEME.NEXT` moves to the following one and wraps, which is what a program binds to a key. A cached
attribute does not follow it: work out anything derived from `THEME.CLR%()`, a reversed bar included,
after every load.

**`CUSTOM` loads nothing.** Selecting it leaves `THEME.CLR%()` as it stands, so a program that lets
the user change colours carries those changes into `CUSTOM` rather than discarding them. The one
exception is a cold start — `CUSTOM` selected before any other theme has been loaded — where there
is nothing to keep and it takes `X16`'s values. `THEME.RESET` goes back to those.

`GPC-BASIC-TOOLS-SRC/color-test` edits the roles against a mock of the GUI and prints the `THEME.CLR%()` lines
to paste back in here. **It carries its own `GPC-BASIC` folder and is still at nine roles**, so it
offers `THEME.FOCUS` and `THEME.BAR` but not `THEME.SHADOW`.

Roles, for indexing `THEME.CLR%()`: `THEME.PAGE` `THEME.TEXT` `THEME.TITLE` `THEME.BORDER`
`THEME.HILITE` `THEME.DIMMED` `THEME.WARN` `THEME.FOCUS` `THEME.BAR` `THEME.SHADOW`, and
`THEME.SLOTS` = 10.

`THEME.FOCUS` is the eighth: what a focused control wears while `GUI.FORM` has the keyboard
(§4.11). It is a separate role from `THEME.HILITE` because a dialog shows both at once — the
highlighted row of a list, and the control the TAB key has landed on. `THEME.BAR` is the ninth,
the band a menu bar or status line sits on, and `THEME.SHADOW` the tenth and newest, the colour
a drop shadow is filled with.

The module's own scalars are int16: `THEME.ID%`, `THEME.ATTR%` and `THEME.INV%`. `THEME.CLR%()`
is not — it stays an untyped array, and it is `DIM`med to `THEME.SLOTS - 1`, which is the last
role and no element beyond it.

Usage is `THEME.ID%`, one `GOSUB THEME.SELECT`, then `THEME.CLR%(role)` wherever an attribute is
wanted:

```basic
THEME.ID% = 1 : GOSUB THEME.SELECT
GP.BOX 4,2,30,8, 2, THEME.CLR%(THEME.BORDER)
GP.PRINTAT 6,3, "TITLE", THEME.CLR%(THEME.TITLE)
```

The values are packed attributes, `background * 16 + foreground`, which is what `GP.BOX`, `GP.FILL`
and `GP.PRINTAT` take. For `COLOR`, which takes the halves separately, use `THEME.SET`.

`#DEFINE` substitutes at translation time, so `THEME.CLR%(THEME.TITLE)` compiles to `THEME.CLR%(2)`.
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
variables through `{VAR}`; without a symbol file the compile stops with `{} NEEDS #SYMFILE`.

#### How a routine takes its string

The pads, `SPLIT`, `REPLACE` and `SPLICE` take the text by value in `STR.STR$` and hand the result
back in it. The three trims take an ADDRESS in `STR.PTR`, from `GP.STRPTR` (§3.4.5), and rewrite
the block in place.

WARNING: never pass a literal to a trim. `GP.STRPTR("hello")` is an address inside the p-code.

#### The pads

`STR.WIDTH` is the target width. A string already at or past it is returned unchanged: the pads
never truncate. Use `STR.RTRIM` to shorten.

#### `STR.SPLIT`

Reads `STR.STR$` and does not modify it. `STR.MAX` of 0 means 10. Empty fields are kept, so `"A,,C"`
is three fields and `"A,"` is two. An empty string gives one empty field, never zero. Reaching the
limit is not an error: the last field takes the unsplit remainder, delimiters included.

`STR.FIELD$` is the one array the library does not `DIM`. Left alone, GPC's implicit `DIM` gives
0..10. For more, `DIM` it before the first call and set `STR.MAX` to match. `DIM`ming an array GPC
has already auto-dimensioned is an error, so it is one or the other.

#### `STR.REPLACE`

Swaps every occurrence of `STR.FIND$` for `STR.REPL$` in `STR.STR$`. The replacement may be shorter,
longer, or `""` to delete. It is case sensitive: `GP.INSTR` (§3.4.1) compares raw bytes. A
replacement that contains the search text terminates — `"A"` to `"AA"` doubles the As. An empty
`STR.FIND$` leaves the string unchanged.

#### `STR.SPLICE`

Replaces `STR.CUT` characters at `STR.AT` with `STR.SUB$`, so one routine inserts, overwrites and
deletes: `STR.CUT` of 0 inserts, `LEN(STR.SUB$)` overwrites, an empty `STR.SUB$` deletes. `STR.AT`
is 1-based. Past the end appends, below 1 clamps to 1, and a cut running past the end takes the rest
of the string. `STR.AT` and `STR.CUT` are clamped in place, so read them back after the call.

#### `STR.PET2SCR`

Converts the PETSCII code in `STR.PET` to the screen code the tile map holds, in `STR.SCR`, for
`TILE`, `TDATA` and `VPOKE`. `GP.PRINTAT` and `GP.FILL` do this conversion themselves.

#### Limitation

The pads, `REPLACE` and `SPLICE` are not length checked. A longer replacement can push the result
past 255 characters.

Examples: [`SPLITT.EXP.BL`](SPLITT.EXP.BL), [`STRINGS.EXP.BL`](STRINGS.EXP.BL). Regression test:
[`STRTST.EXP.BL`](STRTST.EXP.BL), thirty-three cases.

### 4.3 `APPSYS.INC.BL` — start politely, leave it as you found it

| Routine | in | out |
|---|---|---|
| `APPSYS.STARTUP` | — | `APPSYS.MODE` `APPSYS.COLS` `APPSYS.ROWS` `APPSYS.COLOUR` |
| `APPSYS.RESTORE` | those | screen mode and colour put back |
| `APPSYS.ISEMU` | — | `APPSYS.IS.EMULATOR` — -1 under x16emu, 0 otherwise |

```basic
A screen rectangle through a file is `STASH.FILE.SAVE` / `.LOAD` / `.PUT` in `STASHFILE.INC.BL`.

GOSUB APPSYS.STARTUP
REM ... the application, laid out with APPSYS.COLS / APPSYS.ROWS ...
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
LINEINPUT.ATTR = THEME.CLR%(THEME.TEXT)
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

`BMX.LOAD` is `BMX.OPEN` as a verb. It is declared with `GP.DEFPROC`, takes the file name and
returns the error string, so the open is one statement:
`IF GP.FN(BMX.LOAD, F$) <> "" THEN GOTO COMPLAIN`. Everything else in the table is a plain `GOSUB`.

**The `#SYMFILE` is required, above the program's `#INCLUDE`s**, and named after the source PRG.
The compiler derives the name it expects from the PRG it compiles, so the directive must match it.
`BMX.MOVE` is `GP.ASM` and reaches BASIC's variables through `{VAR}`. Without a symbol file the
compile stops with `{} NEEDS #SYMFILE @ <line>`, then falls out to BASIC with a
`?STRING TOO LONG ERROR` that names neither the file nor the cause. A `#SYMFILE` after the
`#INCLUDE`s stops BASLOAD with `SYMFILE NOT ALLOWED IN <file>:<line>`.

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
REM ... BMX.WIDTH, BMX.HEIGHT, BMX.PALUSED readable here ...
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
REM ... the title screen ...
GOSUB BMX.RESTORE
```

A program that keeps the machine need never call it. A program that returns the machine to BASIC or
chains to another calls it once. It is safe to call at any time: with nothing stashed there is
nothing to do, so a program whose image failed to load can still call it on the way out. All 256
entries are kept, not the range the file claims, and they are kept once per run — so a slideshow
restores the machine's own palette rather than the previous image's.

`BMX.STASH` is the VRAM address they go to, `$13000` by default, which is free above the 320x240
framebuffer in the mode this module paints into. A caller using tiles, sprites or a second bitmap
there must move it or switch it off with `BMX.STASH = -1`. The address is checked. A stash inside
the bitmap reports `"BMX.STASH IS INSIDE THE BITMAP"`, one overlapping the PSG registers reports
`"BMX.STASH RUNS INTO THE PSG REGISTERS"`, and neither paints.

Use `-1` to switch it off, not `0`. Zero is what the variable holds before it is set, and `BMX.INIT`
runs at the first `BMX.OPEN`, after a caller would have set it, so `0` has to keep meaning unset.

The module handles 8 bits per pixel, uncompressed, which is what `SCREEN 128` displays without a
decompressor. Anything else is reported rather than attempted. The image is centred, and anything
larger than 320x240 is clipped.

**It can run from a RAM bank.** Put its `#INCLUDE` between `GP.BANKED` and `GP.ENDBANKED` (§3.12).
A call from outside the region selects the region's bank and `RETURN` puts the caller's back, so a
caller is written the same either way. Its `MACPTR` reads land in VRAM and in low-memory string
blocks, never in `$A000-$BFFF`, so `MACPTR`'s own bank stepping cannot reach a banked copy of the
code. See [BANKED-OR-NOT.md](BANKED-OR-NOT.md).

Examples: [`BMXVIEW.EXP.BL`](BMXVIEW.EXP.BL) is a viewer, [`BMXPAL.EXP.BL`](BMXPAL.EXP.BL) answers
the palette question, and [`BMXSPD.EXP.BL`](BMXSPD.EXP.BL) times both paths, the one-block path and
the centred row-at-a-time path.

### 4.6 `MENU.INC.BL` — menus built a row at a time

| Routine | in | out |
|---|---|---|
| `GP.SUB MENU.BEGIN, slot` | `MENU.BAR` or `MENU.POPUP` | the slot emptied; the rows that follow go into it |
| `GP.SUB MENU.ITEM, text$` | the row's text | a row appended, with no hint, enabled |
| `GP.SUB MENU.ITEMX, text$, hint$, on` | the text, the hint, and `on`, tested `<> 0` | a row appended |
| `GP.SUB MENU.SELECTED, n` | the row the next run opens on | — |
| `R = GP.FN(MENU.HOTROW, slot, key)` | a slot and a key code | `R`, the first live row with that hot key, matched without case, or 0 |
| `N = GP.FN(MENUTO.VERT, row, col, style)` | the popup slot, and the inputs below | `N`, 1 to the row count, or 0 for ESC. `MENU.EXITKEY%` |
| `N = GP.FN(MENUTO.BAR, row, col, style)` | the bar slot, `MENU.GAP%` `MENU.BARFLAGS%` | `N` `MENU.EXITKEY%` `MENU.BARNUM%` `MENU.SELX%` `MENU.SELW%` `MENU.MARKED%` |
| `GP.SUB MENU.DRAWBAR, row, col, style` | the bar slot, `MENU.MARKED%` | the bar on screen, not run, with `MENU.MARKED%` lit |

```basic
#INCLUDE "GPB.INC.BL"
#INCLUDE "BANKMGR.INC.BL"
#INCLUDE "THEME.INC.BL"
#DEFINE MENU.TEXTBANK 62
#INCLUDE "MENU.INC.BANKED.BL"
#INCLUDE "MENU.INC.BL"

GOSUB BANKMGR.INIT
MENU.ATTR% = 6 * 16 + 1
MENU.HOTATTR% = 6 * 16 + 7
MENU.DISATTR% = 6 * 16 + 12
GP.SUB MENU.BEGIN, MENU.POPUP
GP.SUB MENU.ITEMX, "&ADD RECORD", "APPEND A BLANK RECORD", MENU.ON
GP.SUB MENU.ITEMX, "&DEL RECORD", "", MENU.OFF
GP.SUB MENU.ITEM, "-"
GP.SUB MENU.ITEM, "&QUIT"
N = GP.FN(MENUTO.VERT, 4, 10, MENU.ROUND)
IF N = 0 THEN <cancelled>
```

Requires `GPB.INC.BL`, `BANKMGR.INC.BL` and `THEME.INC.BL`, with `BANKMGR.INIT` run before the first
`MENU.BEGIN`, and a SHARED compile. `#DEFINE MENU.TEXTBANK`, then `#INCLUDE "MENU.INC.BANKED.BL"`
straight before `MENU.INC.BL`. Its groups are banked, so the program gets a `NAME.OVL` beside its `.PRG`.
Ship both.

A menu is built into a slot, then run from it. There are two slots, so the bar survives while its
dropdown is built:

| slot | rows |
|---|---|
| `MENU.BAR` | 16 |
| `MENU.POPUP` | 32 |

A row past the slot's size is dropped, and so is a row added before any `MENU.BEGIN`. The sizes
are `MENU.BAR.MAX`, `MENU.POPUP.MAX`, `MENU.POOL.MAX` and `MENU.POOLBASE`, declared in
`MENU.INC.BL`. A group in `MENU.INC.BANKED.BL` holds one `SPC` line per row it counts, so raising
a define means adding lines to the group to match. A define that does not match its lines silently
loses rows off the end of a menu. `MENU.POOLBASE` is `MENU.BAR.MAX + MENU.POPUP.MAX`.

The text and hints are kept in bank `MENU.TEXTBANK`, which the first `MENU.BEGIN` claims from
`BANKMGR` (§4.13). It has no default: the program writes `#DEFINE MENU.TEXTBANK n` before
`#INCLUDE "MENU.INC.BANKED.BL"`. Nothing else may use that bank. If another owner has claimed it,
`MENU.OK%` is 0 and every row is dropped.
Text is cut to 30 characters and a hint to 50. `MENU.FLAG$()`, `MENU.HOTKEY$()` and
`MENU.HOTCOL$()` are the module's own arrays, `DIM`med on the first `MENU.BEGIN`. Do not `DIM` them.

`MENU.SELECTED` sets the row the next run opens on. The next `MENU.BEGIN` or run clears it, and
without it a run opens on row 1.

`MENU.HOTROW` looks a key up the way a run does. Use it on a key a `MENU.KEYEXIT` run handed back,
to open the bar item with that letter, or for an ALT+letter the program reads itself.

#### Rows

`&` marks the hot key: `"SAVE &AS"` is stored as `SAVE AS` with hot key A at column 6. Only the
first `&` counts, `&&` is a literal `&`, and a trailing `&` stays in the text. A hot key is matched
without case, the first live row with it wins, and it chooses the row at once. A shifted PETSCII
letter, 193 to 218, pairs with 65 to 90 as well.

A row whose text is one hyphen, `"-"`, is a separator. It draws as a line of `MENU.SEPCHR`, still
counts as a row, and the cursor steps over it.

`MENU.ITEMX` with `on` 0 adds a disabled row. The cursor steps over it, its hot key and RETURN are
refused, and it draws in `MENU.DISATTR%`.

A caller keeping its rows in `GP.BANKEDSTR` groups (§3.10) can put the enable mask at index 0 of
the hint group, `"1"` for on and `"0"` for off a row, and pass `VAL(MID$(GP.BSTR(HH, 0), I, 1))`
as `on`.

#### Colours, hints and the gap

Set once by the caller, and read by every run:

| in | |
|---|---|
| `MENU.ATTR%` | the rows, `background * 16 + foreground` |
| `MENU.HIATTR%` | the highlighted row. 0 inverts `MENU.ATTR%` |
| `MENU.HOTATTR%` | the hot key letter. 0 leaves it untinted. Only rows drawn in `MENU.ATTR%` are tinted |
| `MENU.DISATTR%` | a disabled row. 0 is `MENU.ATTR%` |
| `MENU.SEPATTR%` | separator lines and the frame. 0 is `MENU.ATTR%` |
| `MENU.SEPCHR` | the separator glyph. 0 is `MENU.LINE`, 192, the stroke `GP.BOX` style 1 draws with |
| `MENU.FLAGS%` | the popup's flags, added together |
| `MENU.BARFLAGS%` | the bar's flags |
| `MENU.GAP%` | cells between bar items. 0 is none |
| `MENU.HINTX%` `MENU.HINTY%` `MENU.HINTW%` `MENU.HINTATTR%` | the hint field. `MENU.HINTW%` 0 turns hints off |

A hint is shown only when the highlight moves, never on opening. The field is cleared to
`MENU.HINTATTR%` first, and a hint longer than `MENU.HINTW%` is cut.

#### The frame

Both runners draw a `GP.BOX` with its corner at `row`, `col`, one cell bigger all round than the
rows, in `MENU.SEPATTR%`. `style` is `MENU.SOLID` 0, `MENU.THIN` 1, `MENU.ROUND` 2, `MENU.THICK` 3,
or 256 and up for the address of an eight-character glyph table:

```basic
T.GLYPH$ = "++++--!!"
N = GP.FN(MENUTO.VERT, 4, 10, GP.STRPTR(T.GLYPH$) + 1)
```

`MENU.NOBOX`, 255, draws no frame and puts the first row at `row`, `col`.

A popup row, and its highlight, is as wide as the widest row. A bar item is as wide as its own text,
with `MENU.GAP%` cells between items, so spaces inside the text are how a bar item gets padding.

#### Keys and flags

| Key | |
|---|---|
| UP, DOWN | move, on the popup |
| LEFT, RIGHT | move, on the bar |
| RETURN | choose a live row |
| ESC or STOP | cancel, and return 0 |
| a hot key | choose its row at once |

| flag | value | |
|---|---:|---|
| `MENU.MUSTSEL` | 1 | ESC and STOP do not cancel |
| `MENU.KEEPMARK` | 2 | the chosen row stays lit. On the bar, `MENUTO.BAR` sets `MENU.MARKED%` to it |
| `MENU.NOWRAP` | 4 | stop at the ends instead of wrapping |
| `MENU.GAMEPAD` | 8 | the SNES pad in port 1 as well: directions move, B or START chooses |
| `MENU.DOWNEXIT` | 16 | bar only: DOWN chooses the item |
| `MENU.UPEXIT` | 32 | bar only: UP chooses the item |
| `MENU.KEYEXIT` | 64 | a key the menu has no use for ends the run, and the row it was on is returned |
| `MENU.HINTMID` | 128 | centre the hint in its field |

On the bar, UP and DOWN do nothing unless `MENU.UPEXIT` or `MENU.DOWNEXIT` is set.

The pad acts on new presses only, one step a press. Cancel is keyboard only. With no pad connected
the flag changes nothing; in the emulator a pad needs `-joy1`.

`MENU.EXITKEY%` is the key that ended the run: 13 for RETURN, 27 for ESC, 3 for STOP, the hot key,
or the key `MENU.KEYEXIT` handed back. A pad press is reported as the key it stands for.

`MENU.BARNUM%` is the bar's row count. `MENU.SELX%` and `MENU.SELW%` are the chosen bar item's column
and width, for placing a panel under it. `MENU.MARKED%` is the bar item left lit by `MENU.KEEPMARK`
or by `MENUTO.PULLDOWN` (§4.9). `MENU.DRAWBAR` redraws the bar with it lit, to repaint a bar that a
panel has covered.

Examples: [`MENUTO.EXP.BL`](MENUTO.EXP.BL) runs a popup, a bar and a dropdown by hand, and
[`MENUBUILD.EXP.BL`](MENUBUILD.EXP.BL) builds both slots and reads them back.

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
mapping the compile stops with `{} NEEDS #SYMFILE`.

Example: [`ARRAYS.EXP.BL`](ARRAYS.EXP.BL). Regression test: [`SORT.EXP.BL`](SORT.EXP.BL), eight
cases including a 200-element array — element 128 is where the doubled index stops fitting in a
byte. Every case checks content as well as order: a sort that reads the wrong element leaves the
array in order with a string duplicated.

---

### 4.8 `STRCASE.INC.BL` — case, in place

| Routine | in | out |
|---|---|---|
| `STRCASE.GO` | `STRCASE.PTR` `STRCASE.MODE` | *(the string itself)* |
| `STR.UCASE` `STR.LCASE` | a string — **a verb, not a `GOSUB`** | a cased copy |

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

**`STR.UCASE` and `STR.LCASE` are verbs** (§3.11), declared with `GP.DEFPROC`, so they are called
with `GP.FN` or `GP.SUB` and not with a `GOSUB`. Each takes a string and gives back a cased copy, so
`A$ = GP.FN(STR.UCASE, A$)` is what changes `A$`. A literal is safe in them: the argument is copied
into `STRCASE.S$` and the copy is what gets rewritten. That copy is the heap traffic `STRCASE.GO`
avoids, so a loop over many strings wants `STRCASE.GO`. The verbs need `GPB.INC.BL` above this file.

One blob, with the mode tested once at entry rather than inside the loop, where the byte count is
the whole cost.

The argument is an address because a BASL subroutine cannot be passed a variable. Copying the
caller's string in and back out would be two allocations and two copies per call — the heap traffic
this module exists to avoid. `GP.STRPTR` gives the block and the assembly rewrites it in place.

**`TRIM`, `LTRIM` and `RTRIM` were here** and are `STR.TRIM` / `STR.LTRIM` / `STR.RTRIM` in
`STRINGS.INC.BL` (§4.2) now. They are string editing rather than case work, and every other
string routine already lived in that one module. A program that only trims does not need this file
at all; one that only folds case saves 113 bytes of p-code by the move.

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

### 4.9 `MENUPULL.INC.BL` — a dropdown under a bar item

| Routine | in | out |
|---|---|---|
| `N = GP.FN(MENUTO.PULLDOWN, barnum, style)` | the popup slot, the bar `MENUTO.BAR` or `MENU.DRAWBAR` last drew | `N` `MENU.EXITKEY%` `MENU.NEXTBAR%` `MENU.BARNUM%` `MENU.SELX%` `MENU.SELW%` |
| `GP.SUB MENU.SAVESCREEN, mode` | `MENU.SAVE.VRAM`, the default, or `MENU.SAVE.BANK` | where the screen under a dropdown is kept |

```basic
MENU.BARFLAGS% = MENU.DOWNEXIT
B = GP.FN(MENUTO.BAR, 0, 0, MENU.NOBOX)
GP.DO
    IF B = 0 THEN GP.EXITDO
    GOSUB MY.FILL
    N = GP.FN(MENUTO.PULLDOWN, B, MENU.ROUND)
    B = MENU.NEXTBAR%
GP.LOOP
```

`MY.FILL` is the caller's: `MENU.BEGIN MENU.POPUP` and the rows for bar item `B`.

Requires `MENU.INC.BL` (§4.6), `STASH.INC.BL` (§3.6) and `STASHVRAM.INC.BL` (§4.18), included by
the caller, `BANKMGR.INC.BL` above this file, and a `#SYMFILE` for `STASH`. A program with no
dropdown leaves this file out and does not carry `STASH`.

`MENUTO.PULLDOWN` marks bar item `barnum`, opens the popup slot under it and runs it. A `barnum`
out of range or disabled returns 0 and draws nothing. The bar is the one last drawn, where it was
drawn, read with `MENU.GAP%` and `MENU.BARFLAGS%` as they are now. The item the last call marked is
unmarked and `barnum` is marked. It stays marked on the way out, in `MENU.MARKED%`.

The dropdown's corner is the item's column on the row under the bar, moved left if the box would
run off the screen. The screen width comes from the KERNAL's `screen_mode`. The style and colours
are `MENUTO.VERT`'s (§4.6), and the run adds `MENU.KEYEXIT` to `MENU.FLAGS%`.

| out | |
|---|---|
| `N` | the row, for RETURN or a hot key. Any other exit is 0 |
| `MENU.EXITKEY%` | the key that ended it |
| `MENU.NEXTBAR%` | the bar item LEFT or RIGHT walks to, stepping over disabled items as the bar does. With no live neighbour it is `barnum`. 0 for any other exit |
| `MENU.BARNUM%` | the bar's row count |
| `MENU.SELX%` `MENU.SELW%` | the item's column and width |

The screen under the dropdown is saved first and put back after. `MENU.SAVESCREEN` sets where.

`MENU.SAVE.VRAM` keeps it in VRAM with `STASHVRAM`, and runs `SV.START` (§4.18) if nothing has. A
program that uses `STASHVRAM` itself sets `SV.MAX%` with a handle to spare for the menu.

`MENU.SAVE.BANK` keeps it with `STASH` in `MENU.STASHSIZE%` bytes at `MENU.STASHADDR` in bank
`MENU.STASHBANK%`. A dropdown takes `4 + 2 * w * h` bytes, frame and shadow included. Set all three
before the first call. Bank 0 at the first call takes `MENUPULL.SAVEBYTES`, 4,096 bytes, from
`BANKMGR.SPACE` (§4.13).

If there is no room either way, the dropdown still runs and the screen is not put back.

WARNING: `MENUTO.PULLDOWN` sets `STASH.BANK`, `STASH.SLOT`, `STASH.MOVE`, `STASH.X`, `STASH.Y`,
`STASH.W` and `STASH.H`. Set them again before the caller's own next `STASH` call.

Example: pass 6 of [`MENUTO.EXP.BL`](MENUTO.EXP.BL).

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
PRINT STR.USING.STR$ : REM 1,234.50
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

### 4.11 `GUI.INC.BL` — the box that puts the screen back, and the form in it

| Routine | in | out |
|---|---|---|
| `GUI.OPEN` | `GUI.BODY.ROWS%` `GUI.BODY.WIDTH%` | `GUI.INNER.LEFT%` `.TOP` `.WIDTH` — the box on its own |
| `GUI.CLOSE` | — | the screen as it was |

**The dialogs are not here.** They are one-line verbs in `GUI-DIALOGS.INC.BL`, §4.12, and a program
calls those. This file is what they are built out of: the box, the control block, and `GUI.FORM`,
the loop that runs a mix of controls under one focus.

```basic
GP.SUB PANELOPEN, " READY ", "", 4, 30
GP.PRINTAT GUI.INNER.LEFT%, GUI.INNER.TOP%, "MY OWN ROWS", THEME.CLR%(THEME.TEXT)
GP.SUB PANELCLOSE
```

Requires `GPB.INC.BL`, `STASH.INC.BL`, `STASHVRAM.INC.BL` (§4.18), `THEME.INC.BL`,
`BANKMGR.INC.BL`, `MENU.INC.BL`, `LINEINPUT.INC.BL`, `COMBO.INC.BL` and `CHECK.INC.BL`, and
`#INCLUDE`s none of them. All of them are needed whichever dialog you call: BASLOAD resolves every
label in the file, so leaving one out is `LABEL NOT FOUND`. `STASH.INC.BL`, `STASHVRAM.INC.BL` and
`MENU.INC.BL` go in before `GUI.INC.BL`. `COMBO.INC.BL` and `CHECK.INC.BL` go in after it. It wants
a `#SYMFILE`, because `STASH` does.

`PICKMENU` runs the popup slot inside its box. Build the rows with `MENU.BEGIN MENU.POPUP` and
`MENU.ITEM` first. `&` hot keys are tinted in `GUI.BORDER%`, and the highlight is as wide as the
widest row.

Everything the box takes is listed in full in [GP-BASIC.GLOBALS.md](GP-BASIC.GLOBALS.md) §3: three
message lines, a title, the style, the placement, the shadow, the frame glyphs, and where the
covered cells are saved.

`GUI.SAVEMODE%` sets where a box keeps the cells it covers. `GUI.SAVE.VRAM` (1), or 0, the default,
keeps them in `STASHVRAM` and runs `SV.START` if nothing has. `GUI.SAVE.BANK` (2) keeps them with
`STASH` in `GUI.STASHSIZE%` bytes at `GUI.STASHADDR` in bank `GUI.BANK%`. A box that is not saved
is still on screen when the call returns. In VRAM mode that is a box with no free handle or no room
in the window. In bank mode it is a box with `GUI.BANK% = 0`, or one that needs more than
`GUI.STASHSIZE%` bytes.

`GUI.FORM.RUN` drops the keys queued before a box opens and the keys left when it closes.
`GUI.TYPEAHEAD%` non-zero keeps them. Set it in a program that queues a box's keys ahead of it.

**Every control has a focus, and TAB moves it.** A dialog states its controls and `GUI.FORM` runs
them. A control is a button, a field, a list, a combo (§4.17) or a check box (§4.21); it hands back
one of six verdicts — stay, next, previous, press, default, cancel — and the dispatcher is one loop
whatever the mix.

**The default button and the focused control are different things.** The default is what RETURN
presses from anywhere and is drawn `<<LIKE THIS>>`; the focus is where TAB has got to and is drawn
in `THEME.FOCUS`. `INPUTBOX` opens with the default on OK and the focus in the field — which is
the point of keeping the two apart, and `GUI.DEFAULT%` sets only the first.

**The answers are buttons.** `GUI.BTN.ONE$` and `GUI.BTN.TWO$` carry them, and `&` marks the
accelerator: `"&CANCEL"` lights the C. **An accelerator is live only while the focused control does
not eat printable keys**, so C presses CANCEL from the button row or from inside a list, and types
a C in a field.

The typing dialog's answer is `GUI.TEXT$`, and the verb is `INPUTBOX`. BASLOAD will not have a
label and a variable of one name, and the `$` does not separate them.

#### Fields on a form

| Routine | in | out |
|---|---|---|
| `GUI.FORM.ADD.FIELD` | `LINEINPUT.X` `.Y` `.LEN` `.TEXT$` and the rest of `LINEINPUT`'s inputs | `GUI.CTRL.N%` — the field's control number |

```basic
LINEINPUT.X = GUI.INNER.LEFT% : LINEINPUT.Y = GUI.INNER.TOP%
LINEINPUT.LEN = 20 : LINEINPUT.TEXT$ = "UNTITLED"
GOSUB GUI.FORM.ADD.FIELD
NAME.CTRL = GUI.CTRL.N%
REM ... run the form ...
PRINT GUI.CTRL.TEXT$(NAME.CTRL)
```

**The text belongs to the control**, in `GUI.CTRL.TEXT$(n)`. `LINEINPUT` has one buffer, so a field
copies its text in when it takes the focus and back out when it leaves. Read `GUI.CTRL.TEXT$(n)`
after `GUI.FORM.RUN`. That is what lets one form carry several fields.

The field is painted as soon as it is added, so a field that never takes the focus is still drawn.

**Upper case, on the default charset.** `GP.PRINTAT` converts PETSCII and BASLOAD passes literals
through as source bytes, so charset 2 lands lower case on the graphics half of the font. ISO mode
fixes the text and breaks the frame, `GP.BOX`'s `$40`–`$7D` being letters. Upper case with a frame,
mixed case without one, or re-order the font and set `GUI.GLYPH%`.

Example: [`GUI.EXP.BL`](GUI.EXP.BL).

---

### 4.12 `GUI-DIALOGS.INC.BL` — every dialog as a verb

A dialog is a call with its arguments in it. Nothing is set up in globals first. Every dialog runs
`GUI.DEFAULTS` before it sets anything, so no title, placement or button from one dialog carries
into the next. The setup verbs' settings are kept: the `DLGSAVESCREEN` mode, the `DLGRESET` space,
the `DLGLABELS` labels, and the `DLGSHADOW`, `DLGSHADOWCLR`, `DLGSTYLE` and `DLGGLYPH` settings.

| Routine | in | out |
|---|---|---|
| `DLGSAVESCREEN mode` | `GUI.SAVE.VRAM`, the default, or `GUI.SAVE.BANK` | where every box after it keeps the cells it covers |
| `DLGRESET bank, addr, size` | the `GUI.SAVE.BANK` space: `size` bytes at `addr` in `bank` | every other input back to its default |
| `DLGSHADOW on` · `DLGGLYPH on` | non-zero | the shadow and the frame glyphs, for every box after it |
| `DLGSHADOWCLR attr` | a packed colour | the shadow's own colour; 0, the default, is black on black |
| `DLGSTYLE style` | a `GP.BOX` style (§3.7); 0, the default, draws style 2, single line with rounded corners | the frame every box after it draws; `DLGGLYPH` overrides it |
| `DLGLABELS ok$, cancel$, yes$, no$` | a label for each; `""` keeps the library's own | the buttons every dialog after it names itself |
| `KBCLEAR` | — | the keyboard buffer emptied |
| `MSGBOX msg$` | | one button; `GUI.KEY%` is the key that closed it |
| `ASKYN msg$` · `ASKOK msg$` | | -1 for yes, or OK |
| `ASK3 t$, m$, b1$, b2$, b3$, dflt, esc` | | the button pressed, 1..3; `esc` is the one ESC means, and `b3$` `""` leaves two |
| `ASKTEXT msg$, len` | | the typed line, `""` when cancelled |
| `INPUTBOX msg$, start$, len` | | the text either way; `GUI.OK%` says which |
| `PICKMENU msg$, sel` | the popup slot of `MENU.INC.BL` (§4.6) | the row, 1..N, or 0 cancelled |
| `LISTBOX msg$, count, rows` | `GUI.LIST.ITEM$()` | the row, or 0 cancelled |
| `LISTBOXM msg$, count, rows` | the same | how many are marked; `GUI.LISTBOX.MARKS$` which |
| `ASKLINE x, y, label$, len` | | a line typed in place, no box; `LINEINPUT.KEY` 27 cancelled |
| `PANELOPEN t$, m$, rows, width` · `PANELCLOSE` | | an empty box at `GUI.INNER.LEFT%` and `.TOP`, and the screen back |

```basic
GP.SUB MSGBOX, "DISK FULL"
IF GP.FN(ASKYN, "DELETE THE FILE?") THEN GOSUB DELETEIT
F$ = GP.FN(ASKTEXT, "FILE NAME?", 16)
```

`DLGSAVESCREEN` sets where every dialog keeps the cells it covers. `GUI.SAVE.VRAM` keeps them in
`STASHVRAM` (§4.18), and a box runs `SV.START` if nothing has. A program that uses `STASHVRAM`
itself sets `SV.MAX%` with a handle to spare for each box open at once.

`GUI.SAVE.BANK` keeps them with `STASH` in the space `DLGRESET` sets. A program calls
`GP.SUB DLGSAVESCREEN, GUI.SAVE.BANK` and `GP.SUB DLGRESET, bank, addr, size` once, at startup. A
box takes `4 + 2 * w * h` bytes, and a combo's dropdown is saved above it in the same space. A box
that does not fit is drawn and not saved. Bank 0 saves none.

`GUI.DEFAULTS` copies the mode into `GUI.SAVEMODE%`, and the space into `GUI.BANK%`,
`GUI.STASHADDR` and `GUI.STASHSIZE%`.

`DLGLABELS` sets the labels of the buttons the library names itself:

- OK of `MSGBOX`, and of `MSGBOXEX` when `btn$` is `""`;
- YES and NO of `ASKYN` and `ASKYNEX`;
- OK and CANCEL of `ASKOK`, `ASKYNEX` with `okc` non-zero, `ASKTEXT`, `INPUTBOX`, `INPUTBOXEX` and
  the listbox verbs.

`ASK3` and `FORM.BEGIN` take their own labels and are not affected. The labels are kept in
`DLG.LABELS.OK$`, `.CANCEL$`, `.YES$` and `.NO$`. `GUI.DEFAULTS` fills a `""` one with the
library's own: `"&OK"`, `"&CANCEL"`, `"&YES"` or `"&NO"`. `DLGLABELS` runs `GUI.DEFAULTS` itself.
The `&` in a label marks the accelerator letter, and that letter is the key that presses the
button. The answer comes from which button was pressed, so a relabelled yes button still answers
-1.

Under charset 5 the library's upper-case PETSCII literals show as lower case. A program that runs
under charset 5 passes its own labels, already converted.

Five verbs have an `EX` form that takes a title and three message lines first, always in that
order, then its own arguments: `MSGBOXEX t$, m$, m2$, m3$, btn$`, `ASKYNEX t$, m$, m2$, m3$, dflt,
okc`, `INPUTBOXEX ... start$, len, mask`, `PICKMENUEX ... sel, flags`, `LISTBOXEX ... count, rows,
multi`. `dflt` 2 makes the second button the default; `okc` non-zero gives OK and CANCEL buttons
in place of YES and NO; `flags` are `MENU.MUSTSEL`, `.NOWRAP` and `.GAMEPAD`.

`#INCLUDE` it after `GPB.INC.BL`, `THEME.INC.BL`, `MENU.INC.BL`, `LINEINPUT.INC.BL`,
`STASH.INC.BL`, `STASHVRAM.INC.BL`, `GUI.INC.BL`, `COMBO.INC.BL` and `CHECK.INC.BL`, and above the
program's code: a verb is compiled before any call to it.

The rows are filled first, because an array cannot be an argument. `PICKMENU` reads the rows built
with `MENU.BEGIN` and `MENU.ITEM`. The listbox verbs read `GUI.LIST.ITEM$(1..count)`, which the
caller `DIM`s.

Up and down move, PgUp and PgDn page, HOME and END jump, and SPACE toggles a mark in multi. TAB
moves to the buttons and back. RETURN in the list presses OK, and on a button presses that button.
ESC and STOP cancel. The marked letter of OK or CANCEL presses that button while the focus is in
the list.

**In multi, `GUI.LISTBOX.SEL%` is not the answer.** It is the row the cursor was left on.
`GUI.LISTBOX.MARKS$` holds the marks: `count` characters, `"1"` for a marked row. The marks are
cleared on every call.

The bottom frame edge reads `2 SELECTED OF 20` in multi, `20 ITEMS` for a single list too long to
see at once, and is blank for one that fits.

#### A list built a step at a time, out of an array or out of a bank

| Routine | in | out |
|---|---|---|
| `LIST.BEGIN title$, rows` | | a list box declared, not yet drawn |
| `LIST.ARRAY count` | `GUI.LIST.ITEM$()` | its rows come from the array |
| `LIST.BANK bank, addr, first, last` | a `GP.BSTR` image at `addr` in `bank` | its rows come from the bank |
| `LISTTO.RUN` | | the row, or 0 cancelled |
| `LIST.ITEM n` | | row `n` as text |
| `LIST.SORT bank, addr, first, last` | | that image's rows in order, in place |

```basic
GP.SUB LIST.BEGIN, " OPEN FILE ", 12
GP.SUB LIST.BANK, MY.BANK%, MY.ADDR, 0, N - 1
SEL = GP.FN(LISTTO.RUN)
IF SEL > 0 THEN F$ = GP.FN(LIST.ITEM, SEL)
```

**A bank list never comes into low memory.** `addr` is where the `GP.BSTR` image starts. The
offset table is at `addr + 2`, one 16-bit offset a string, and each offset counts from `addr`. A
`GP.BANKEDSTR` group's image is at `$A000` when it is the first group declared in its bank.
`GUI.LIST.FETCH` reads one row at a time, as it is drawn. `FILEPICK.INC.BL` shows a directory this
way. `LIST.SORT` moves the two-byte offsets and not the records, so a pointer into a record stays
good and a string number does not. It reaches the bank through `STASH.SELECT`, so the whole module
can sit inside a `GP.BANKED` region.

Example: [`GUI.EXP.BL`](GUI.EXP.BL).

---

### 4.13 `BANKMGR.INC.BL` — who owns which RAM bank

| Routine | in | out |
|---|---|---|
| `BANKMGR.INIT` | — | `BANKMGR.BANKS%` |
| `BANKMGR.CLAIM` | `BANKMGR.SET.BANK%` | `BANKMGR.OK%` |
| `BANKMGR.GET.FREE.BANK` | — | `BANKMGR.BANK%` |
| `BANKMGR.RELEASE` | `BANKMGR.SET.BANK%` | — |
| `BANKMGR.COUNT` | — | `BANKMGR.BANKS%` `BANKMGR.SPARE%` |
| `GP.SUB BANKMGR.SPACE, size` | `BANKMGR.SIZE%`, 1 to 8192 | `BANKMGR.BANK%` `BANKMGR.ADDR` |

```basic
#INCLUDE "BANKMGR.INC.BL"

GOSUB BANKMGR.INIT
BANKMGR.SET.BANK% = MY.GUICODE : GOSUB BANKMGR.CLAIM
IF BANKMGR.OK% = 0 THEN <bank was already taken>
GOSUB BANKMGR.GET.FREE.BANK
IF BANKMGR.BANK% = 0 THEN <none left>
GP.SUB BANKMGR.SPACE, 1200
MYBANK% = BANKMGR.BANK% : MYADDR = BANKMGR.ADDR
```

For a program with several owners of banked RAM, none of which can see the others' numbers. The
order matters: `BANKMGR.INIT` first, and every `CLAIM` before the first `GET.FREE.BANK` or `SPACE`,
or the allocator hands out a bank a compile-time region is already sitting in.

`SPACE` hands out a piece smaller than a bank. The pieces come from the bottom of a bank it takes
from `GET.FREE.BANK`, one after another. None is ever given back. A piece that does not fit in what
is left takes a fresh bank. `BANKMGR.BANK%` is 0 when no bank is left. `BANKMGR.ADDR` is the piece's
first byte, `$A000` to `$BFFF`, and stays a float because `$A000` is past 32,767.

**It tracks, it does not select.** Nothing in this module executes `BANK`. A claim is a promise
between the program's own modules, and an accessor still sets its own bank on every access.

**0 is not a bank.** It is the KERNAL's, reserved by `INIT`, and it is what `GET.FREE.BANK` returns
for *none left*. `INIT` reserves bank 1 as well, for the runtime (§3.12), so `GET.FREE.BANK`
hands out bank 2 or higher.

`BANKMGR.OK%` is `-1` if `CLAIM` took the bank, `0` if it was already taken or out of range.
`BANKMGR.BANKS%` is how many the machine has, 64 or 256. `BANKMGR.SPARE%` is what `COUNT` found free.

**`MEMTOP` returns `$00` on a 2 MB machine.** The count is one byte and 256 does not fit, so 512 K
reads `$40` = 64 and 2 MB reads `$00`, meaning 256. `INIT` reads 0 as 256. A manager that took `$00`
at face value would report no banks at all on exactly the larger machine. Values that are not a
multiple of 8 are legal — the reference names `$42` — and mean some banked RAM is bad.

The bitmap is 32 bytes, eight banks to the byte.

---

### 4.14 `KB.INC.BL` — the keyboard buffer, emptied

| Routine | in | out |
|---|---|---|
| `KB.CLEARKB` | — | — |

```basic
#INCLUDE "KB.INC.BL"

GOSUB KB.CLEARKB
GOSUB GUI.YN
```

Call it before opening a dialog, and after a keystroke that redraws. A dialog opened with a key
still queued reads it, answers itself and closes; a held arrow repeats faster than a page can be
drawn and scrolls on after the key is let go.

**`GUI.INC.BL` carries a private copy, `GUI.CLEARKB`**, from when code inside a `GP.BANKED` region
could not call another bank. Fix one and fix the other. There are only the two, and a second
`#INCLUDE` of this file cannot supply the copy — the `#IFNDEF` guard makes it produce nothing.

---

### 4.15 `FILEIO.INC.BL` — the drive: status, files, directories

| Routine | in | out |
|---|---|---|
| `FILE.STATUS` | — | `FILE.ERR%` `FILE.MSG$` `FILE.TRK%` `FILE.SEC%` |
| `FILE.EXISTS` | `FILE.NAME$` | `FILE.OK%` |
| `FILE.SIZE` | a name — **a verb, not a `GOSUB`** | `FILE.OK%` `FILE.BLOCKS` |
| `FILE.DELETE` | `FILE.NAME$`, pattern allowed | `FILE.ERR%` `FILE.TRK%` |
| `FILE.RENAME` | `FILE.NAME$` `FILE.NEW$` | `FILE.ERR%` |
| `FILE.COPY` | `FILE.NAME$` `FILE.NEW$` | `FILE.ERR%` |
| `FILE.MKDIR` `FILE.RMDIR` `FILE.CHDIR` | `FILE.NAME$` | `FILE.ERR%` |
| `FILE.UP` | — | `FILE.ERR%` |
| `FILE.CURDIR` | — | `FILE.PATH$` |
| `FILE.SAVEARRAY` | `FILE.NAME$` `FILE.ROWS%` `FILE.LINE$()` | `FILE.ERR%` |
| `FILE.LOADARRAY` | `FILE.NAME$` `FILE.MAX.ROWS%` | `FILE.ROWS%` `FILE.LINE$()` |

```basic
#SYMFILE "@:MYPROG.SYM"
#INCLUDE "FILEIO.INC.BL"

FILE.NAME$ = "SCORES.DAT" : GOSUB FILE.EXISTS
IF FILE.OK% THEN N = GP.FN(FILE.SIZE, "SCORES.DAT")
```

**The `#SYMFILE` is required, before the `#INCLUDE`s.** `FILE.TOPET` is `GP.ASM` and reaches
`FILE.PETP%` through `{VAR}`; without a symbol file the compile stops at `{} NEEDS #SYMFILE`.

`FILE.SIZE` is declared with `GP.DEFPROC`, so it is called as a verb —
`GP.SUB FILE.SIZE, "MYFILE.DAT"` or `N = GP.FN(FILE.SIZE, "MYFILE.DAT")` — and not with a `GOSUB`.
Everything else in the table is a plain `GOSUB`.

`FILE.DEVICE%` is the drive and 0 means 8. `FILE.ISO%` non-zero folds names to PETSCII on the way out.
`FILE.LINE$()` is the caller's `DIM`, as `GUI.LIST.ITEM$` is; left alone the implicit `DIM` gives
0 to 10. `FILE.ROWS%` is an input to `SAVEARRAY` and an output from `LOADARRAY`.

**`FILE.ERR%` under 20 is success.** 0 is OK. 1 is *files scratched* and carries the count in
`FILE.TRK%`. 62 is FILE NOT FOUND, 63 FILE EXISTS, 26 WRITE PROTECT. `FILE.ERR%` is `DS` and
`FILE.MSG$` is `DS$` — the X16 has neither.

This module takes logical file 14 and secondary address 14. Not 2 or 3: those belong to the editor,
GPC-HELP and the cruncher. The two are equal so a later seek needs no reopen.

**`ST` is not a disk status.** `LINPUT#` on a channel whose `OPEN` found nothing returns `CHR$(0)`
with `ST = 66`, and keeps doing so. `ST` is 64 before a program's first statement, because `LOAD`
leaves bit 6 set.

The traps, each one measured on the drive:

- **Read the command channel or the next `OPEN` misbehaves.** The drive holds its error state until
  channel 15 is read. Every routine here ends by reading it.
- `FILE.RENAME` onto a name that exists returns 62, not 63 — which is what a missing source also
  returns. Test with `FILE.EXISTS` first.
- `FILE.COPY` is one drive. `C:new=old` cannot cross devices. It takes a comma list, so it also
  concatenates.
- `FILE.SAVEARRAY` overwrites, with `@:` on the open.
- `FILE.DELETE` takes a pattern. `S:*.BAK` scratches every match.
- The last row of a file arrives with `ST` already set, so a row is stored before the loop ends. **A
  blank final line is indistinguishable from end of file and is dropped.**

**CMDR-DOS has no REL files.** For random access use `,M` open mode with `P` and `T` on channel 15:

```basic
OPEN 1,8,2,"LEVEL.DAT,S,R"
OPEN 15,8,15,"P"+CHR$(2)+CHR$(0)+CHR$(1)+CHR$(0)+CHR$(0)
```

`T` returns the position and the file size. The data channel's secondary address must equal the `P`
or `T` channel argument. `VAL("$"+MID$(A$,10))` from the manual returns 0 here — `VAL` stops at the
first non-numeric character, so parse the eight hex digits by hand.

---

### 4.16 `FILEDIR.INC.BL` — a directory, into a bank or into low RAM

| Routine | in | out |
|---|---|---|
| `FILE.DIR.INIT` | — | — |
| `FILE.DIR.OPEN` | `FILE.DIR.BANK%` `FILE.DIR.PTR` `FILE.DIR.CAP%` `FILE.DIR.PATTERN$` `FILE.DIR.ONLY%` | `FILE.DIR.GOT%` `FILE.DIR.FULL%` `FILE.DIR.SLOW%` |
| `FILE.DIR.NEXT` | — | `FILE.DIR.MORE%` `FILE.NAME$` `FILE.BLOCKS` `FILE.TYPE$` |

```basic
#SYMFILE "@:MYPROG.SYM"
#INCLUDE "FILEIO.INC.BL"
#INCLUDE "FILEDIR.INC.BL"

GOSUB BANKMGR.GET.FREE.BANK
FILE.DIR.BANK% = BANKMGR.BANK%
FILE.DIR.PTR = $A000 : FILE.DIR.CAP% = 8192
FILE.DIR.PATTERN$ = "*.BASL" : FILE.DIR.ONLY% = FILE.DIR.FILES
GOSUB FILE.DIR.OPEN
GP.DO
    GOSUB FILE.DIR.NEXT
    IF FILE.DIR.MORE% = 0 THEN GP.EXITDO
    PRINT FILE.NAME$, FILE.BLOCKS, FILE.TYPE$
GP.LOOP
```

Requires `GPB.INC.BL` and `FILEIO.INC.BL`, and `#INCLUDE`s neither. The `#SYMFILE` is required, for
the same reason `FILEIO` needs one.

`FILE.DIR.ONLY%` takes `FILE.DIR.ALL`, `FILE.DIR.FILES` or `FILE.DIR.DIRS`. `FILE.DIR.MORE%` is `-1`
while `NEXT` produced an entry and 0 at the end. `FILE.DIR.GOT%` is bytes read, 0 for an empty or
failed listing. `FILE.DIR.FULL%` says the buffer filled before the listing ended, and
`FILE.DIR.SLOW%` is 1 if the device had no `MACPTR` and the read fell back to `CHRIN` a byte at a
time.

**Two destinations, one code path**: the reader takes a bank, an address and a size.
`FILE.DIR.BANK%` is the bank the buffer is in, 0 for low RAM. `FILE.DIR.PTR` is the buffer's first
byte and `FILE.DIR.CAP%` the bytes it holds.

```basic
REM a whole bank -- 8,192 bytes hold about 250 entries
FILE.DIR.BANK% = BANKMGR.BANK%
FILE.DIR.PTR = $A000
FILE.DIR.CAP% = 8192

REM low RAM
FILE.DIR.BANK% = 0
DIM FD.BUF%(1022)
FILE.DIR.PTR = GP.ARRPTR(FD.BUF%())
FILE.DIR.CAP% = 1023 * 2
```

**In a bank, `FILE.DIR.PTR + FILE.DIR.CAP%` stays at or below `$C000`.** Past `$BFFF`, `MACPTR`
wraps into the next bank. A piece from `BANKMGR.SPACE` (§4.13) keeps to this.

**A `%` array is two bytes an element.** A buffer sized at six bytes an element runs the reader off
the end of the array, into whatever the workspace put after it. An untyped array is six bytes an
element.

This module claims no bank and executes no `BANK` statement. Its two `GP.ASM` blocks write `$00`, so
both are `GP.ASM LOW` (§3.9) and stay in low memory when the module is in a region.

---

### 4.17 `COMBO.INC.BL` — a drop-down list that folds into one row

| Routine | in | out |
|---|---|---|
| `COMBO.ADD` | `COMBO.X%` `COMBO.Y%` `COMBO.W%` `COMBO.SEL%` | `COMBO.CTRL%` |

```basic
GP.SUB FORM.BEGIN, "TITLE", "MSG", "", 6, 40, "&OK", "&CANCEL"
GP.SUB FORM.ITEMS, MY.BANK%, MY.ADDR
STATE = GP.FN(FORM.COMBO, 1, "STATE", 6, 12, 1)
GP.SUB FORM.ITEM, "TEXAS"
GP.SUB FORM.ITEM, "OHIO"
IF GP.FN(FORMTO.RUN) THEN <OK>
SEL = GP.FN(FORM.SEL, STATE)
GP.SUB FORM.END
```

A program reaches a combo through the `FORM.` verbs of `GUI-DIALOGS.INC.BL` (§4.12). `GUI.FORM`
dispatches a `GUI.CT.COMBO` control to `COMBO.DRAW`, `COMBO.KEY` and `COMBO.OPEN` by name.

`COMBO.X%` and `COMBO.Y%` are the closed control's top left, in cells. `COMBO.W%` is the width,
brackets included. 5 is the floor and anything less is raised to it. `COMBO.SEL%` is the item
showing, 1 up. `COMBO.CTRL%` is the control's number, 0 if the form was full.

The items are the form's item store: `GUI.ITEM.CLAIM` after `COMBO.ADD`, then a `GUI.ITEM.ADD` each.
`GUI.ITEM.SEAL` draws the combo once they are in. The choice is `GUI.CTRL.SEL%(COMBO.CTRL%)`.

The dropdown saves the cells it covers where the dialog does, by `GUI.SAVEMODE%` (§4.11). In VRAM
mode it takes a `STASHVRAM` handle of its own and needs no bank. In bank mode it goes in the
dialog's save space, bank `GUI.BANK%` from `GUI.STASHADDR`, above the dialog's own save. Every
combo on the form opens into that one slot, one at a time. If there is no room either way, the
dropdown does not open.

The dropdown is the popup slot of `MENU.INC.BL` (§4.6), loaded from the item store each time it
opens, so whatever the caller last built in that slot is gone after. An item is a menu row: `&`
marks a hot key and `"-"` is a separator. The `MENU.*` colours and flags it sets are put back.

A long list belongs in a list control. The dropdown shows every item at once, 32 at most, and does
not scroll.

**The dropdown is framed like the dialog behind it.** With `GUI.GLYPH%` non-zero it draws from
`GUI.EDGE.H%`, `GUI.EDGE.V%`, `GUI.CORNER.TL%`, `.TR`, `.BL` and `.BR`, the same six a dialog frames
with, so a re-ordered charset gets its own frame here too. With `GUI.GLYPH% = 0` the frame is
`GP.BOX` style 1.

**It is required by `GUI.INC.BL`**, which names `COMBO.DRAW` and `COMBO.KEY`. BASLOAD resolves every
label in a file, so a program that includes the GUI and leaves this one out stops with
`LABEL NOT FOUND` whether it ever draws a combo or not. It needs `MENU.INC.BL`, and what that
requires.

---

### 4.18 `STASHVRAM.INC.BL` — rectangles and blobs, kept in VRAM

| Routine | in | out |
|---|---|---|
| `SV.START` | `SV.MAX%`; 0 gives `SV.START.HANDLES`, 4 | `SV.OK%`, on the first call only |
| `SV.INIT` | `SV.BASE` `SV.TOP` `SV.MAX%` | `SV.OK%` |
| `SV.SAVE` | `SV.X%` `SV.Y%` `SV.W%` `SV.H%` | `SV.HND%` `SV.OK%` |
| `SV.RESTORE` | `SV.HND%` `SV.MOVE%` `SV.X%` `SV.Y%` | `SV.OK%` |
| `SV.PUT` | `SV.ADDR` `SV.LEN` | `SV.HND%` `SV.OK%` |
| `SV.GET` | `SV.HND%` `SV.ADDR` | `SV.OK%` |
| `SV.FREE` | `SV.HND%` | `SV.OK%` |
| `SV.RESET` | — | `SV.OK%` |

```basic
#INCLUDE "STASHVRAM.INC.BL"

SV.MAX% = 16 : GOSUB SV.START
SV.X% = 10 : SV.Y% = 5 : SV.W% = 40 : SV.H% = 12 : GOSUB SV.SAVE
IF SV.HND% = 0 THEN <it did not fit>
REM ... draw over it ...
GOSUB SV.RESTORE
```

**No `GP.ASM`, and so no `#SYMFILE`.** The cells never leave VRAM: one data port reads, the other
writes, and the KERNAL's `memory_copy` moves between them without stepping either. That is what
`STASH.INC.BL` cannot do. It executes no `BANK`, so it may live inside a `GP.BANKED` region.

`SV.START` `DIM`s `SV.PAGE%` and `SV.PAGES%` to `SV.MAX%` and runs `SV.INIT`. Only the first call
does anything. `SV.MAX%` 0 gives `SV.START.HANDLES`, 4: a menu dropdown, a dialog, a combo's
dropdown and a message box over the dialog. `GUI.INC.BL`, `COMBO.INC.BL` and `MENUPULL.INC.BL` call
`SV.START` themselves, so set `SV.MAX%` before the first box or dropdown opens. `SV.INIT` alone
sets a new window with every handle given back.

WARNING: The compiler takes one `DIM` of an array, and it is in `SV.START`. A program never `DIM`s
`SV.PAGE%` or `SV.PAGES%` itself. It sets `SV.MAX%` and calls `GOSUB SV.START`.

`SV.BASE` and `SV.TOP` are the VRAM window in bytes, rounded in to whole 256-byte pages, and default
to `$04000` and `$1AFFF`. `SV.MOVE%` works as `STASH.MOVE` does: `SV.RESTORE` puts the rectangle
back where it came from when 0, at `SV.X%` `SV.Y%` when not. `SV.HND%` is 1 to `SV.MAX%`, or 0 if
it did not fit. `SV.ERROR$` says why when something is refused, and is `""` otherwise.

Allocation is a bump pointer on 256-byte pages, released last in, first out. A hole appears only
when a caller frees out of order, and `STASHVRAMGC.INC.BL` (§4.19) closes it. A page number fits in
a `%` and reaches 511. A 17-bit VRAM address does not fit.

`SV.BASE` and `SV.TOP` are checked only against the layer 1 map and the charset. `BMX.STASH`
defaults to `$13000`, inside the default window. A program that uses both moves one of them.

A screen-mode change re-uploads the charset and can re-lay the map. Held handles do not survive it;
call `SV.RESET` after one.

---

### 4.19 `STASHVRAMGC.INC.BL` — close the holes in a STASHVRAM store

| Routine | in | out |
|---|---|---|
| `SV.COMPACT` | — | `SV.MOVED` `SV.OK%` |

```basic
#INCLUDE "STASHVRAM.INC.BL"
#INCLUDE "STASHVRAMGC.INC.BL"

GOSUB SV.COMPACT
IF SV.MOVED = 0 THEN <it was already tight>
```

**Its own file, so a compactor nobody calls costs nothing.** Unless the compile removes dead code
(§7), it would otherwise be compiled into every program that includes the store. `#INCLUDE` this
one only if something in the program calls it, and **never call it automatically**.

**It is not a garbage collector.** Liveness is known from the handle table rather than discovered,
so there is no mark phase and nothing traces anything: the live blocks are read off in page order,
each is slid down to the low-water mark, and the table is rewritten as it goes.

**Handles survive it.** A block's page number changes; the handle that names it does not. Anything
holding a raw VRAM address across a call here is holding a stale one — but nothing outside the table
has one, which is the whole reason the store is addressed by handle.

`SV.MOVED` is how many blocks actually moved, 0 if it was already tight — which is what LIFO release
leaves behind.

The slide is downward, so a block's destination is always below its source. That the overlap is safe
at the hardware is measured, not assumed.

---

### 4.20 `KV.INC.BL` — keys and values in one RAM bank

| Routine | in | out |
|---|---|---|
| `KV.INIT` | `KV.BANK` | `KV.OK` |
| `KV.FIND` | `KV.KEY$` | `KV.SLOT` |
| `KV.GET` | `KV.KEY$` | `KV.VALUE$` `KV.SLOT` `KV.OK` |
| `KV.AT` | `KV.SLOT` | `KV.KEY$` `KV.VALUE$` `KV.OK` |
| `KV.PUT` | `KV.KEY$` `KV.VALUE$` | `KV.SLOT` `KV.OK` |
| `KV.DEL` | `KV.KEY$` | `KV.OK` |
| `KV.WIPE` | — | `KV.OK` |
| `KV.SAVE` | `KV.FNAME$` | — |
| `KV.LOAD` | `KV.FNAME$` | `KV.OK` |
| `KV.PUTNUM` `KV.GETNUM` | — | `KV.OK`, always 0 |

```basic
#INCLUDE "KV.INC.BL"

GOSUB KV.INIT
KV.KEY$ = "COLOR"
KV.VALUE$ = "RED"
GOSUB KV.PUT
KV.KEY$ = "COLOR"
GOSUB KV.GET
IF KV.OK THEN PRINT KV.VALUE$
KV.FNAME$ = "SETTINGS.KV"
GOSUB KV.SAVE
```

Strings stored by key in RAM bank `KV.BANK`. `KV.INIT` reads a `KV.BANK` of 0 as `KV.DEFBANK`, which
is 40, so a program that sets nothing gets bank 40. A program that wants another bank sets `KV.BANK`
before the first `KV.INIT`. `KV.INIT` runs before any other routine. Every routine is a plain `GOSUB`,
and `KV.OK` is -1 for success and 0 for failure.

`KVBIN.INC.BL` (§4.26) keeps a store in a file that every program on the drive shares.

**Plain BASL.** No `GP.*` keyword and no `GP.ASM`, so it needs neither `GPB.INC.BL` nor a
`#SYMFILE`, and the same source tokenises for stock BASIC.

**`KV.INIT` formats the bank only when slot 0 holds no header.** A bank that already holds a store is
kept, keys and all. A header with another version or slot count is left alone, and `KV.OK` is 0.
`KV.WIPE` formats the bank whatever it holds.

**Keys** are `A`-`Z`, `0`-`9` and `.`, cut to 8 characters. The module checks none of this. A key
compares byte for byte, and `KV.AT` reads a key back up to its first space.

`KV.PUT` refuses an empty key. It rewrites the slot of a key that exists and takes the first free slot
for one that does not. When all 63 slots are in use, `KV.OK` and `KV.SLOT` are 0.

**Values** hold up to 119 characters, and `KV.PUT` cuts a longer one. An empty value is stored and
reads back as `""`. A missing key gives `KV.OK = 0`, `KV.SLOT = 0` and `KV.VALUE$ = ""`.

`KV.FIND` sets `KV.SLOT` and nothing else. Slots never move, so a program can keep a slot number for
the rest of the run and read it with `KV.AT`, which does not scan. A delete frees the slot. `KV.AT`
on every slot lists the store:

```basic
FOR SLOT.NUMBER = 1 TO 63
    KV.SLOT = SLOT.NUMBER
    GOSUB KV.AT
    IF KV.OK THEN PRINT KV.KEY$; " = "; KV.VALUE$
NEXT SLOT.NUMBER
```

**`KV.PUTNUM` and `KV.GETNUM` are stubs.** Each sets `KV.OK = 0` and returns. Store a number as
text: `STR$(N)` with `KV.PUT`, and `VAL(KV.VALUE$)` after `KV.GET`.

**It selects a bank.** Every routine selects `KV.BANK` and ends with `BANK KV.HOMEBANK`. The first
`KV.INIT` sets `KV.HOMEBANK` to 1, the bank selected at startup, and a program that keeps another bank
selected sets it after `KV.INIT`. A call from a `GP.BANKED` region needs nothing: it is a banked
call, and its `RETURN` selects the region's bank again (§3.12). The module cannot go inside a region,
because the compiler refuses `BANK` there.

A program that uses `BANKMGR` (§4.13) claims the bank the store is in. `BANKMGR.CLAIM` refuses bank 0,
and `KV.BANK` is 0 until the program sets it or `KV.INIT` runs. For a fixed bank, set `KV.BANK`, claim
it after `BANKMGR.INIT` and before the first `GET.FREE.BANK`, then call `KV.INIT`:

```basic
KV.BANK = 40
BANKMGR.SET.BANK% = KV.BANK
GOSUB BANKMGR.CLAIM
GOSUB KV.INIT
```

A bank from `GET.FREE.BANK` is already marked taken and needs no claim: `KV.BANK = BANKMGR.BANK%`, then
`KV.INIT`. `BANKMGR.BANK%` is 0 when no bank is left, and `KV.INIT` then uses bank 40.

**`KV.SAVE` writes the whole bank**, all 8,192 bytes, to `KV.FNAME$` on device 8, and replaces a file
of that name. A disk error stops the program.

**`KV.LOAD` returns `KV.OK = 0` for a missing file** and leaves the bank alone. It also returns 0 for a
file that loads but holds no matching header, and then the bank already holds that file: run
`KV.WIPE` before the next `KV.PUT`. It opens logical files 14 and 15 to test for the file and closes
both, so neither may be open when it is called.

The layout, for a program that reads the bank without this module:

```
slot n = $A000 + n*128, n = 0-63
+0..+7    the key, padded with spaces. $00 at +0 is a free slot
+8        the value's length, 0-119
+9..      the value
slot 0    "*KVSTORE", 2, the version (1), the slot count (64)
```

`KV.EXP.BL`, in `GPC-BASIC-TOOLS-SRC/GPB-MODS-TESTING/GPC-BASIC/`, calls every routine.

---

### 4.21 `CHECK.INC.BL` — a check box, `[X]` or `[ ]`

| Routine | in | out |
|---|---|---|
| `CHECK.ADD` | `CHECK.X%` `CHECK.Y%` `CHECK.TEXT$` `CHECK.ON%` | `CHECK.CTRL%` |

```basic
CHECK.X% = GUI.INNER.LEFT% : CHECK.Y% = GUI.INNER.TOP%
CHECK.TEXT$ = "SHOW HIDDEN FILES" : CHECK.ON% = -1
GOSUB CHECK.ADD
HIDDEN = CHECK.CTRL%
REM ... run the form ...
IF (GUI.CTRL.FLAGS%(HIDDEN) AND GUI.CF.CHECKED) <> 0 THEN PRINT "TICKED"
```

**Only `CHECK.ADD` is called by an application.** `CHECK.DRAW` and `CHECK.KEY` are reached by
`GUI.FORM`, which dispatches a `GUI.CT.CHECK` control to them by name. The call goes between
`GUI.FORM.BEGIN` and `GUI.FORM.RUN`.

`CHECK.X%` and `CHECK.Y%` are the cell the `[` goes in, and the caption starts four cells to the
right. `CHECK.TEXT$ = ""` draws a bare box. A non-zero `CHECK.ON%` starts the box ticked.
`CHECK.CTRL%` is the control's number, and 0 when the form is already full.

**The state is a flag on the control**, `GUI.CF.CHECKED` in `GUI.CTRL.FLAGS%()`. Keep `CHECK.CTRL%`
and test the flag after `GUI.FORM.RUN`. One form carries as many boxes as it has controls.

| key | does |
|---|---|
| `X` | ticks the box |
| `DEL` | clears it |
| `SPACE` | flips it |
| `TAB` `RIGHT` `DOWN` | the next control |
| `SHIFT+TAB` `LEFT` `UP` | the previous control |
| `RETURN` | presses the default button |
| `ESC` `STOP` | cancels the form |

Any other key is offered to the buttons' marked letters.

**It is required by `GUI.INC.BL`**, which names `CHECK.DRAW` and `CHECK.KEY`. It goes in after that
file, as `COMBO.INC.BL` does. A program that includes the GUI and leaves this one out stops with
`LABEL NOT FOUND`.

`GPBMODS` (§4.27) runs three boxes and a combo on one form, under DIALOG > CHECK BOX + COMBO.

---

### 4.22 `MATH.INC.BL` — the smaller and the larger of two numbers

| Routine | in | out |
|---|---|---|
| `MATH.MIN` | `MATH.FIRST` `MATH.SECOND` | `MATH.RESULT` |
| `MATH.MAX` | `MATH.FIRST` `MATH.SECOND` | `MATH.RESULT` |

```basic
#INCLUDE "GPB.INC.BL"
#INCLUDE "MATH.INC.BL"

MATH.FIRST = WANTED : MATH.SECOND = AVAILABLE
GOSUB MATH.MIN
ROWS = MATH.RESULT
```

Both routines share all three variables. The verbs are `MATH.MINOF` and `MATH.MAXOF`, so the same
answer comes back from `GP.SUB MATH.MINOF, WANTED, AVAILABLE` or from `GP.FN(MATH.MINOF, WANTED,
AVAILABLE)` inside an expression.

**`GP.FN` brings the GP block in**, 1,536 bytes. `GOSUB` and `GP.SUB` leave it out.

Floats and integers both, and no range check. Equal arguments answer `MATH.FIRST`.

---

### 4.23 `MEM.INC.BL` — a block copied, a block filled

| Routine | in | out |
|---|---|---|
| `MEM.COPY` | `MEM.SOURCE` `MEM.TARGET` `MEM.COUNT` | — |
| `MEM.FILL` | `MEM.TARGET` `MEM.COUNT` `MEM.VALUE` | — |

```basic
#INCLUDE "GPB.INC.BL"
#INCLUDE "MEM.INC.BL"

MEM.TARGET = 4096 : MEM.COUNT = 1000 : MEM.VALUE = 32
GOSUB MEM.FILL
```

The KERNAL's `memory_copy` and `memory_fill`. The verbs are `MEM.BLOCKCOPY` and `MEM.BLOCKFILL`, and
the two routines share `MEM.TARGET` and `MEM.COUNT`.

`MEM.COUNT` is 1 to 65535. It is not checked. A longer block goes a chunk at a time; a chunk size
above `$4000` cannot be a `#DEFINE`, which is signed. `STASHVRAMGC.INC.BL` (§4.19) is the worked
example.

Regions may overlap with the target below the source.

**WARNING: both ends are low RAM below `$9F00`, or a `$9F00-$9FFF` I/O port.** No bank survives the
call, so `$A000-$BFFF` cannot be reached. Move a banked block a window at a time.

An address in `$9F00-$9FFF` is used without being stepped. Point a VERA data port at the start of a
run and pass `$9F23` or `$9F24` to move a whole block in one call. `STASHVRAM.INC.BL` (§4.18) does
that by hand.

Either routine brings the GP block in, 1,536 bytes, because `GP.CALL` lives there.

---

### 4.24 `GUI-LITE.INC.BL` — a message box and a menu, in low memory

Three verbs. `MSGBOX` shows up to four lines over one or two buttons, and closes before it returns.
`PICKMENU` shows a menu and leaves it open. `CLOSEBOX` takes down the box opened last. Each box is
as wide as its text and has a drop shadow. A program calls the three verbs and nothing else.

```basic
#INCLUDE "GPB.INC.BL"
#INCLUDE "THEME.INC.BL"
#INCLUDE "GUI-LITE.INC.BL"

GOSUB THEME.SELECT
C = GP.FN(PICKMENU, 4, 4, "MENU", "ABOUT,QUIT")
IF C = 1 THEN GP.SUB MSGBOX, "ABOUT", "GUI-LITE", "", "", "", "OK", ""
GP.SUB CLOSEBOX
```

`#INCLUDE` it after `GPB.INC.BL` and `THEME.INC.BL`. It includes neither. Every colour is read from
`THEME.CLR`, so `THEME.SELECT` (§4.1) runs before the first box.

It uses `GP.BOX`, `GP.FILL`, `GP.PRINTAT` and `GP.CALL`, so a program that includes it carries the
GP block, 1,536 bytes. It holds no `GP.BANKED`, `GP.BANKEDSTR` or `BANK`, and adds no `.OVL`.

The cells under a box and its shadow go to VRAM bank 0 when the box opens, and come back when it
closes. The first box saves at `GL.SAVE.AT`, and each later box just above the one before. A box W
columns wide and H rows high takes (2W + 4) x (H + 1) bytes. The largest box on an 80x30 screen
takes 5,084 bytes, so four of them end at `$8F70`. The save area must end below `$10000`.

| `#DEFINE` | default | sets |
|---|---|---|
| `GL.SAVE.AT` | `$4000` | the VRAM bank 0 address the first box saves at |
| `GL.MOST.OPEN` | 4 | how many boxes may be open at once |

Define either one before the `#INCLUDE` to change it.

The frame is `THEME.BORDER`, the inside and the menu rows `THEME.TEXT`, the title `THEME.TITLE` and
the shadow `THEME.SHADOW`. The menu bar and the focused button are `THEME.HILITE`, and the other
button is `THEME.BAR`.

The caller keeps every box and its shadow on the screen. The shadow is two columns right of the box
and one row below it.

`GUI-DIALOGS.INC.BL` (§4.12) declares `MSGBOX` and `PICKMENU` too. Include one or the other. With
both, the compile stops at `GP.DEFPROC VERB ALREADY DECLARED`.

`STASHVRAM.INC.BL` (§4.18) starts its window at `$04000`, the default `SV.BASE`. A program that
includes both moves one of them.

The `GUI-LITE` sample, `GPC-BASIC-TOOLS-SRC/GUI-LITE/GUI-LITE.BASL`, calls all three verbs.

#### 4.24.1 `MSGBOX` — lines of text over one or two buttons

```entry
  Syntax    GP.FN(MSGBOX, t$, l1$, l2$, l3$, l4$, b1$, b2$)
            GP.SUB MSGBOX, t$, l1$, l2$, l3$, l4$, b1$, b2$
  Returns   The button chosen, 1 or 2.
  Kind      BASIC. A verb in GUI-LITE.INC.BL. Needs the GP block.
  Notes     All seven arguments are required. Pass "" for a line or a
            button that is not wanted.
            t$ goes in the top edge. "" leaves the edge plain.
            l1$ to l4$ are centred, one a row. A "" line is a blank
            row, and the box ends at the last line that is not "".
            b2$ "" gives one button.
            The box is centred on the screen. It is 6 columns wider
            than the widest of t$, the lines and the button row.
            The focus starts on b1$. LEFT moves it to b1$, RIGHT to
            the last button, TAB to the other one. RETURN chooses
            the button with the focus. ESC chooses the last button.
            The box closes before MSGBOX returns.
  Example
```
```basic
            B = GP.FN(MSGBOX, "QUIT", "LEAVE?", "", "", "", "YES", "NO")
            IF B = 1 THEN GOTO BYE
```

#### 4.24.2 `PICKMENU` — a menu that stays open

```entry
  Syntax    GP.FN(PICKMENU, x, y, t$, items$)
  Returns   The item chosen, counting from 1. 0 for ESC.
  Kind      BASIC. A verb in GUI-LITE.INC.BL. Needs the GP block.
  Notes     x, y is the top-left corner of the box. t$ goes in the
            top edge, and "" leaves it plain.
            items$ is the items separated by commas, one a row. An
            item cannot contain a comma.
            The box is 6 columns wider than the longest of t$ and the
            items, and 2 rows taller than the number of items.
            The bar starts on item 1. UP and DOWN move it and wrap at
            the ends. RETURN chooses.
            The box stays open when PICKMENU returns, so a MSGBOX can
            open over it. GP.SUB CLOSEBOX (§4.24.3) takes it down.
  WARNING   CLOSEBOX writes back the screen as it was when the menu
            opened. Repaint the screen under a menu only after
            CLOSEBOX.
  Example
```
```basic
            C = GP.FN(PICKMENU, 4, 4, "FILE", "OPEN,SAVE,QUIT")
            IF C = 2 THEN GOSUB SAVE.FILE
            GP.SUB CLOSEBOX
```

#### 4.24.3 `CLOSEBOX` — take down the box opened last

```entry
  Syntax    GP.SUB CLOSEBOX
  Does      Takes down the box opened last and puts back the screen
            under it and its shadow.
  Kind      BASIC. A verb in GUI-LITE.INC.BL. Needs the GP block.
  Notes     PICKMENU's box is the one a program closes. MSGBOX closes
            its own.
            Call it only with a box open.
```

---

### 4.25 `DOS.INC.BL` — a drive command, and a test for a file

Two verbs on the drive's command channel. `DOSX` sends a command and reads the drive's answer.
`DOSX.EXISTS` tests whether a file opens. Each also has a `GOSUB` entry that takes its argument in
a variable.

It is the smaller alternative to `FILEIO.INC.BL` (§4.15). A program includes one or the other, not
both. It needs `GPB.INC.BL` ahead of it and includes nothing.

`DOS.DEVICE` is the drive. A call with it 0 uses 8 and leaves it 8.

After either verb, `DOS.ERR` is the drive's error number and `DOS.MSG$` its message. `DOS.ERR` under
`DOS.OKMAX`, 20, is success.

Nothing in the module needs the GP block. `GP.FN` brings it in, 1,536 bytes. `GP.SUB` and `GOSUB`
leave it out (§3.11).

#### 4.25.1 `DOSX` — send a command, read the answer

```entry
  Syntax    GP.SUB DOSX, cmd$
            GP.FN(DOSX, cmd$)
            DOS.CMDSTR$ = cmd$ : GOSUB DOS.CMD
  Returns   DOS.ERR, the drive's error number.
  Kind      BASIC. A verb in DOS.INC.BL. GP.FN needs the GP block.
  Notes     Opens the command channel to DOS.DEVICE as logical file
            15 with cmd$ as the command, reads the answer, and closes
            the file.
            cmd$ "" sends no command and reads the drive's status.
            DOS.MSG$ holds the message. The track and sector are
            read and discarded.
            DOS.ERR under 20 is success.
            DOS.CMDSTR$ is "" afterwards.
  WARNING   Do not call it with logical file 15 open.
  Example
```
```basic
            GP.SUB DOSX, "S:OLD.DAT"
            IF DOS.ERR >= DOS.OKMAX THEN PRINT DOS.ERR; " "; DOS.MSG$
```

#### 4.25.2 `DOSX.EXISTS` — whether a file opens

```entry
  Syntax    GP.FN(DOSX.EXISTS, name$)
            DOS.NAME$ = name$ : GOSUB DOS.DOS.EXISTS
  Returns   -1 if the file opens, 0 if not. DOS.OK holds the same.
  Kind      BASIC. A verb in DOS.INC.BL. GP.FN needs the GP block.
  Notes     Opens the command channel as logical file 15, then
            name$ + ",S,R" as logical file 14, reads the command
            channel while the file is open, and closes both.
            -1 means DOS.ERR came back under 20.
            DOS.ERR and DOS.MSG$ hold the drive's answer, found or
            not.
  WARNING   Do not call it with logical file 14 or 15 open.
  Example
```
```basic
            IF GP.FN(DOSX.EXISTS, "SCORES.DAT") THEN GOSUB LOAD.SCORES
```

---

### 4.26 `KVBIN.INC.BL` — keys and values in one file of fixed records

| Routine | in | out |
|---|---|---|
| `KVBIN.CREATE` | `KVBIN.NEWSLOTS%` | `KVBIN.SLOTS` `KVBIN.OK%` |
| `KVBIN.INFO` | — | `KVBIN.SLOTS` `KVBIN.OK%` |
| `KVBIN.GET` | `KVBIN.KEY$` | `KVBIN.VALUE$` `KVBIN.SLOT%` `KVBIN.OK%` |
| `KVBIN.PUT` | `KVBIN.KEY$` `KVBIN.VALUE$` | `KVBIN.SLOT%` `KVBIN.OK%` |
| `KVBIN.DEL` | `KVBIN.KEY$` | `KVBIN.SLOT%` `KVBIN.OK%` |
| `KVBIN.AT` | `KVBIN.SLOT%` | `KVBIN.KEY$` `KVBIN.VALUE$` `KVBIN.OK%` |
| `KVBIN.FIRST` | — | `KVBIN.SLOT%` `KVBIN.KEY$` `KVBIN.VALUE$` `KVBIN.OK%` |
| `KVBIN.NEXT` | — | `KVBIN.SLOT%` `KVBIN.KEY$` `KVBIN.VALUE$` `KVBIN.OK%` |
| `KVBIN.STOP` | — | — |
| `KVBIN.EXPAND` | `KVBIN.GROWBY%` | `KVBIN.SLOTS` `KVBIN.OK%` |

```basic
#INCLUDE "KVBIN.INC.BL"

KVBIN.FNAME$ = "/SETTINGS.KVB"
GOSUB KVBIN.INFO
IF KVBIN.DOSERR% = 62 THEN GOSUB KVBIN.CREATE
KVBIN.KEY$ = "USER.NAME"
KVBIN.VALUE$ = "STEVE"
GOSUB KVBIN.PUT
KVBIN.KEY$ = "USER.NAME"
GOSUB KVBIN.GET
IF KVBIN.OK% THEN PRINT KVBIN.VALUE$
```

Strings stored by key in one file on the drive, for a few dozen settings that every program on the
drive shares. Every routine is a plain `GOSUB`. There is no init routine. Outside a walk, a routine
opens the file and closes it before it returns.

`KV.INC.BL` (§4.20) keeps its store in one RAM bank inside one program. This store is a file, and
every program that opens it reads and writes the same keys.

**Plain BASL.** No `GP.*` keyword and no `GP.ASM`, so it needs neither `GPB.INC.BL` nor a
`#SYMFILE`. The same source tokenises for ROM BASIC and compiles under GPC unchanged. Under GPC it
needs runtime build 131 or later.

**The file** is `KVBIN.FNAME$`, with its path if it has one, so the store can sit anywhere on the
drive, such as the root. `KVBIN.DEVICE%` is the drive, and 0 is 8. Every routine but `KVBIN.NEXT` and
`KVBIN.STOP` reads both.

**`KVBIN.OK%` is -1 when the call is done and 0 when it is not.** `KVBIN.WHY%` is 0 when it is done.
When it is not, `KVBIN.WHY%` gives the reason:

| `KVBIN.WHY%` | When |
|---|---|
| `KVBIN.WHY.NOFILE`, 1 | The drive refused the open. |
| `KVBIN.WHY.NOTSTORE`, 2 | The file opened, and it does not start with a `*KVBIN` header of version 1, key length 12 and record length 128. |
| `KVBIN.WHY.NOKEY`, 3 | `KVBIN.GET` or `KVBIN.DEL` found no slot with the key, or `KVBIN.AT` read a free slot. |
| `KVBIN.WHY.FULL`, 4 | `KVBIN.PUT` of a new key found no free slot. |
| `KVBIN.WHY.BADKEY`, 5 | `KVBIN.KEY$` is `""` for `KVBIN.GET`, `KVBIN.PUT` or `KVBIN.DEL`. The file is not opened. |

`KVBIN.DOSERR%` and `KVBIN.DOSMSG$` hold the drive's answer to the open. A number under 20 is
success, and a missing file is 62.

**Keys** are cut to 12 characters and hold any byte but `$00`. A key compares byte for byte.

**Values** are cut to 115 characters and hold any byte but `$00`. An empty value is stored and reads
back as `""`. A missing key gives `KVBIN.OK% = 0`, `KVBIN.SLOT% = 0` and `KVBIN.VALUE$ = ""`.

**`KVBIN.PUT` keeps a key's slot.** A new key takes the first free slot. With none free, `KVBIN.WHY%`
is `KVBIN.WHY.FULL` and nothing is written. Call `KVBIN.EXPAND`, then `KVBIN.PUT` again.
`KVBIN.DEL` frees the slot in place, and the other slots do not move.

**`KVBIN.CREATE` makes a store of `KVBIN.NEWSLOTS%` free slots**, 40 when it is 0, and replaces a
file of the same name. `KVBIN.EXPAND` adds `KVBIN.GROWBY%` free slots to the end of the file, 20
when it is 0. Both leave the new count in `KVBIN.SLOTS`. `KVBIN.INFO` reads the count from the
header.

**`KVBIN.AT` reads slot `KVBIN.SLOT%` and does not scan.** The slot is 1 to `KVBIN.SLOTS`, and the
module does not check it. A free slot gives `KVBIN.OK% = 0` and `""` for both strings.

**A lookup scans from slot 1.** `KVBIN.GET`, `KVBIN.PUT` and `KVBIN.DEL` read one key a slot and
stop at the key. A missing key and a new key read every slot. Measured in ROM BASIC on an SD image,
on a store of 40 slots, 60 jiffies to the second: a scan costs about 1 jiffy a slot. `KVBIN.GET`
takes 9 jiffies for a key in slot 3, and 39 to 44 for a key in slot 40 or a missing key. `KVBIN.PUT`
of a new key takes 41. The walk below costs about 5 jiffies a slot.

**`KVBIN.FIRST` and `KVBIN.NEXT` walk every slot in order**, free ones too. A free slot has
`KVBIN.KEY$ = ""`. After the last slot `KVBIN.OK%` is 0, `KVBIN.WHY%` is 0 and the file is closed.
When `KVBIN.FIRST` cannot open the store, `KVBIN.OK%` is 0 and `KVBIN.WHY%` holds the reason.

```basic
GOSUB KVBIN.FIRST
SHOW.SLOT:
    IF KVBIN.OK% = 0 THEN GOTO SHOW.DONE
    IF KVBIN.KEY$ <> "" THEN PRINT KVBIN.KEY$; " = "; KVBIN.VALUE$
    GOSUB KVBIN.NEXT
    GOTO SHOW.SLOT
SHOW.DONE:
```

The file stays open between the calls. `KVBIN.SLOT%` is the walk's place and `KVBIN.SLOTS` its end,
so change neither. Call no other routine in the module until `KVBIN.NEXT` gives `KVBIN.OK% = 0` or
`KVBIN.STOP` has run. `KVBIN.STOP` ends a walk early.

**WARNING: the module uses logical files 12 and 15.** Neither may be open when a routine is called.
A routine opens both and closes both before it returns, and a walk holds both open from
`KVBIN.FIRST` until it ends.

The layout, for a program that reads the file without this module:

```
record n is at byte n*128 of the file, and is 128 bytes
record 0, the header
+0..+5     "*KVBIN"
+6         the version, 1
+7         the key length, 12
+8         the record length, 128
+9, +10    the slot count, low byte first
+11..+127  $00
record n, slot n
+0..+11    the key, padded with $00. $00 at +0 is a free slot
+12..+126  the value, padded with $00
+127       $00, so the value is a zero-terminated string
```

Regression test: [`KVBIN.EXP.BL`](KVBIN.EXP.BL), thirteen cases, every routine but `KVBIN.STOP`. It
writes `KVBT.BIN` and `KVBJUNK.BIN` to the drive, and `KVBNONE.BIN` must not exist there.

`GPC-BASIC-TOOLS-SRC/KV-BIN-STORE/` holds three programs on one `SETTINGS.KVB`: a registry editor in
GP.BASIC (`KV-BIN-STORE.BASL`), a ROM BASIC program (`KVBIN-BASIC.BASL`) and a Prog8 program
(`KVBIN-PROG8.P8`). In a release the folder is `SAMPLES/KV-BIN-STORE/`.

---

### 4.27 `GPBMODS` — the harness that drives every module

`GPC-BASIC-TOOLS-SRC/GPB-MODS-TESTING/GPBMODS.BASL`. A menu bar of nine dropdowns whose rows reach nearly every
public entry point in this section. It is the one program that holds all twenty-one modules at once, and
the worked example of `GP.BANKED`, `GP.BANKEDSTR` and `BANKMGR` in one place.

```
gpbmods-demo.bat
```

The drive is `source/drive/`, not the sample folder. The object is compiled SHARED and loads
`GPB.RT.nnn.BIN` from there.

**No row is a stub.** A chosen row calls the library for real and shows what came back, on the panel
and on the LAST line at the foot of the page. Three modules are under test before any row is chosen:
`MENU` draws the bar, `MENUPULL` every dropdown, and `STASH` puts the screen back under a closed
one.

| | |
|---|---|
| DIALOG — **D** | `GUI` `GUI-DIALOGS` `COMBO` `CHECK` |
| LISTS — **L** | `MENU` |
| INPUT — **I** | `LINEINPUT` |
| SCREEN — **S** | `STASH` `STASHFILE` `STASHVRAM` |
| STRINGS — **G** | `STRINGS` `STRCASE` `STRUSING` |
| DATA — **A** | `SORT` |
| THEME — **T** | `THEME` |
| ABOUT — **B** | `BANKMGR` |
| FILES — **F** | `FILEIO` `FILEDIR` |

`APPSYS` runs at startup and at exit rather than from a row. STRINGS answers to **G** because SCREEN
has taken S: a hot key need not be an item's initial, and `&` marks it, as in `" STRIN&GS "`.

**Twenty-one modules are included and nineteen are driven.** `KB` and `STASHVRAMGC` are compiled
in and have entry points — `KB.CLEARKB`, `SV.COMPACT` — that no panel calls.
`BMX` (§4.5) is not included: it wants a bitmap file and a screen mode of its own, and the
`BMXVIEW` example in `GPC-BASIC/` covers it.

**WARNING: FILES writes to the drive.** Four of its rows do. Everything they make is named
`GPBFILE.*` or `GPBDIR`, and the row that makes each one removes it.

#### Seventeen banks

Thirteen are named at compile time. Twelve are claimed from `BANKMGR` (§4.13) at startup, because
the compiler picks them while the object is written and the manager is told rather than asked. The
thirteenth, 62, is claimed by the first `MENU.BEGIN` when the bar is built, before any bank is
allocated. Four more come from `BANKMGR.GET.FREE.BANK` at startup: the STASH panel's bank, the
cells a dialog covers, `FILEDIR`'s directory buffer, and `FILEPICK`'s list with the form item
store. A dropdown saves the cells it covers in VRAM.

| | |
|---|---|
| bank 4, 5,632 bytes | `LINEINPUT` `GUI` `GUI-DIALOGS` |
| bank 5, 7,936 bytes | literal text, pool one |
| bank 6, 5,120 bytes | literal text, pool two |
| bank 7, 5,120 bytes | `APPSYS` `BANKMGR` `KB` `SORT` `STASHVRAM` `STASHVRAMGC` `STRCASE` `STRINGS` `STRUSING` |
| bank 8, 1,792 bytes | `FILEIO` `FILEDIR` |
| bank 9, 768 bytes | `THEME` |
| bank 10, 1,536 bytes | `COMBO` `CHECK` |
| bank 11, 3,072 bytes | the two biggest dropdown handlers, this program's own code |
| bank 12, 2,816 bytes | `MENU` `MENUPULL` |
| bank 62, 4,352 bytes | the menu store, `MENU.TEXTS` and `MENU.HINTS` |

Seven of those are `GP.BANKED` code regions (§3.12) and three are `GP.BANKEDSTR` text pools
(§3.10). All ten are in one `GPBMODS.OVL`, each behind its own bank and page-count bytes, with a
one-byte end marker. `GPBMODS.PRG` is 11,542 bytes and `GPBMODS.OVL` is 38,165: the ten sections
come to 38,144, the header bytes to 20, and the end marker is the last byte.

**Only what holds a `BANK` statement stays in low RAM.** `STASH` and `STASHFILE` execute `BANK`,
which the compiler refuses inside a region; `STASHVRAM` (§4.18) is the one to reach for from inside
one.

**Seven regions and not one**, because a region holds at most 8,192 bytes and the GUI fills its own.
A region may call another: the call selects the other bank and its `RETURN` puts the caller's back.

**A nearly empty region still costs a whole page count.** Bank 9 holds 502 bytes of `THEME` in
three pages. Below about a page and a half of p-code, a region gives back less than it looks
like. Bank 10 held 705 bytes of `COMBO` in 768 the same way, until `CHECK` moved in beside it.

#### The text is in a bank

542 strings in 72 named groups, 11,776 bytes across two pools, none of it in low RAM. Every string
the shell says sits in a `GP.BANKEDSTR` block in front of the routine that says it and is read back
with `GP.BSTR`. Two pools, because one pool is a hard 8,192 bytes and `BStrPoolWrite` stops the
compile when one fills. Which pool a group is in costs the call site nothing, so moving a group is
the whole of the answer to a full one.

**Every menu is a block of its own**, index 0 the menu's title and 1 upwards the rows. A loop to
`GP.BSTRCOUNT` passes each row to `MENU.ITEM`, so a row is added by adding a line to the block, and
no other menu moves.

The numbers under `ABOUT / BANK MEMORY` and `ABOUT / MODULE SIZES` are typed into `GP.BANKEDSTR`
blocks, so they are only true of the build they were taken from.

#### The room it runs in

The workspace is what is left between the program's own p-code and the resident runtime: `$4000` to
`$6600`, 9,728 bytes. The first p-code opcode is `.varspace` and its operand is what the scalars
take — 3,292 here, leaving about 6,436 for the string arrays and the whole string heap.

**Moving code into a bank moves no scalars.** A banked routine's variables are the same workspace
variables low memory sees, so `.varspace` grows as panels are added whatever bank they run from.

`GPC-BASIC/` inside the sample folder is the library working copy and it is ahead of the root copy.
A module is proved here and copied whole into root. `GPB.INC.BL` runs the other way: root is
upstream for it, and the build copies root's over this folder's every time.

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
| `STR.USING.` | `STRUSING.INC.BL`, kept apart from the rest of `STR.` |
| `THEME.` | `THEME.INC.BL` |
| `APPSYS.` | `APPSYS.INC.BL` |
| `LINEINPUT.` | `LINEINPUT.INC.BL` |
| `KB.` | `KB.INC.BL` |
| `MENU.` | `MENU.INC.BL`, and `MENUPULL.INC.BL`'s variables |
| `MENUTO.` | the runners in `MENU.INC.BL` and `MENUPULL.INC.BL` |
| `MENUPULL.` | `MENUPULL.INC.BL`'s labels |
| `GUI.` | `GUI.INC.BL` |
| `GUI.LISTBOX.` | `GUI-DIALOGS.INC.BL`, kept apart from the rest of `GUI.` |
| `DLG.` | `GUI-DIALOGS.INC.BL`, the dialog verbs’ arguments and internals |
| `GL.` | `GUI-LITE.INC.BL` |
| `STASH.` / `STASH.FILE.` | `STASH.INC.BL` / `STASHFILE.INC.BL` |
| `SORT.` | `SORT.INC.BL` |
| `STRCASE.` | `STRCASE.INC.BL` |
| `BMX.` / `BMXK.` | `BMX.INC.BL` (variables / its KERNAL constants) |
| `FILE.` / `FILE.DIR.` | `FILEIO.INC.BL` / `FILEDIR.INC.BL` |
| `KV.` | `KV.INC.BL` |
| `KVBIN.` | `KVBIN.INC.BL` |
| `DOS.` | `DOS.INC.BL` |
| `SV.` / `SVGC.` | `STASHVRAM.INC.BL` / `STASHVRAMGC.INC.BL` |
| `MATH.` | `MATH.INC.BL` |
| `MEM.` | `MEM.INC.BL`, its two KERNAL constants included |

Use any other prefix for your own program: `GAME.`, `MAP.`, `AIRLIFT.`. A prefix costs nothing at
runtime — BASLOAD crunches every identifier to a short BASIC variable, so a long readable name and a
two-letter one compile to the same thing.

Do not reuse a taken prefix for a name the module has not defined. `THEME.MINE` is free today and is
one library update from not being.

### `GP.*` is keywords, not variables

`GPB.INC.BL` defines no variables. It is 27 keyword declarations and nothing else.

```basic
GP.A = 5 : REM SYNTAX ERROR — GP.A is a keyword
X = GP.A : REM correct
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
| `INPUT` answered with RETURN alone | the variable gets `""`, or 0 for a number, and the program goes on. Stock BASIC keeps the old value. `INPUT#` reads an empty line as `""` | `IF A$ = "" THEN A$ = DEFAULT$` where the old value mattered |
| `PRINT` after `GP.PRINTAT` | GP drawing never calls the KERNAL, so the cursor is wherever it was | `LOCATE` first, or stay in one world |
| `SORT.INC.BL` with no `#SYMFILE` | `{VAR}` cannot resolve a crunched name — `{} NEEDS #SYMFILE` | `#SYMFILE "@:PROG.SYM"`, before the `#INCLUDE`s |
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

### What GPC prints when it finishes

One item a line. `GPBMODS`, built shared:

```
OK LOW CODE 11520, SHARED GPBASIC
LOW FREE 12288, FRAME STACK 2048
LINES 3795
BANK   7 CODE  4864 USED  3328 FREE
BANK   9 CODE   768 USED  7424 FREE
BANK   4 CODE  7680 USED   512 FREE
BANK  10 CODE   768 USED  7424 FREE
BANK   8 CODE  1792 USED  6400 FREE
BANK  11 CODE  3072 USED  5120 FREE
BANK   5 TEXT  7424 USED   768 FREE
BANK   6 TEXT  4352 USED  3840 FREE
TOTAL BANKS 8, 30720 USED
```

An embedded build prints a `RUNTIME` line second. `GPCTEST-E`:

```
OK LOW CODE 969, EMBEDDED GPBASIC
RUNTIME 11775
LOW FREE 23808, FRAME STACK 2048
```

| | |
|---|---|
| `LOW CODE` | the p-code in low memory, in bytes. P-code and `GP.ASM` blocks in a `GP.BANKED` region are not in it |
| `SHARED` `EMBEDDED` | `SHARED` loads a resident runtime file at run time. `EMBEDDED` carries the runtime in the object |
| `GPBASIC` `CORE` | `GPBASIC` when a `GP.` keyword reached the 1,536-byte handler block: shared, the program loads `GPB.RT.nnn.BIN`; embedded, the block is in the object. `CORE` when none did: shared, it loads `GPC.RT.nnn.BIN`; embedded, `ScanGPUsage` dropped the block |
| `RUNTIME` | embedded only. The runtime bytes carried in the object |
| `LOW FREE` | what is left in low memory for variables, strings and arrays. **This is the number that runs out.** It ends at `$9F00` embedded, and at the resident runtime shared |
| `FRAME STACK` | the 2,048 bytes reserved between the p-code and the workspace for `GOSUB` and `FOR` frames. `LOW FREE` does not include them |
| `LINES` | the source lines compiled, the lines of `GP.ASM` and `GP.BANKEDSTR` blocks included. Lines left out as dead code are not counted |
| `DEAD CODE` | printed only when dead code is removed: the source lines left out, and the p-code bytes they would have taken. `LOW CODE` is already without them |
| `BANK` | printed only when the program has a region or banked text. One line a bank: `CODE` for a `GP.BANKED` region, `TEXT` for `GP.BANKEDSTR`, then the bytes used and free of its 8,192. Both are whole pages, so `FREE` is room that is certainly there |
| `TOTAL BANKS` | after the `BANK` lines: how many, and the bytes they use |

Two budgets come off `LOW FREE`:

- **`LOW FREE` is the workspace** the running program has for its data.
- **`LOW FREE` minus 4,096 is how much more low-memory p-code will fit.** `WriteObjectCode` refuses
  to leave less than 4K of workspace, so a build reporting `LOW FREE 4096` is one page from
  `PROGRAM TOO BIG`.

A program can be comfortable on one and out of room on the other. `LOW FREE 4096` is 4K to run in
and nowhere left to grow; `GPBMODS` at `LOW FREE 12288` has both.

### What ships with the program

`nnn` in a runtime name is the runtime build number. A program loads the runtime files carrying the
number of the compiler that built it.

| mode | files |
|---|---|
| EMBEDDED | `NAME.PRG`. The runtime and the bank 1 code are in the object |
| | `NAME.OVL`, holding every `BANK` line's region — only if the program has one |
| SHARED | `NAME.PRG` |
| | `GPB.RT.nnn.BIN` when the report says `GPBASIC`, `GPC.RT.nnn.BIN` when it says `CORE` |
| | `GP1.RT.nnn.BIN`, always |
| | `NAME.OVL`, holding every `BANK` line's region, beside the `.PRG` |

The bootstrap looks for the runtime in the current directory, then in `/GPC/`, then at the root of
the SD card. One copy in `/GPC/` or at `/` serves every program. `GP1.RT.nnn.BIN` must sit in the same place as the runtime
that loaded. A runtime file that is not found prints `?RT`, the third letter of its name and the
build number: `?RTB128` for `GPB.RT.128.BIN`.

`GPC.BIN`, `GPC.IMG.nnn.BIN` and `GP1.IMG.nnn.BIN` are the compiler and its inputs and do not ship.

### Removing dead code

With `REMOVE DEAD CODE?` answered `Y` in `GPC.PRG`, or a file named on line 5 of `GPC.INPUT`, the
compiler leaves out every source line that no path from the first line reaches. It writes the numbers
of those lines to the file, one a line. `GPC.PRG` names it `D.` and the source name. The numbers are
the BASIC line numbers BASLOAD gave, not lines of the `.BASL` file.

The option adds one pass, `PASS 0`. With it off, the passes and the object are unchanged.

A line is reached through:

- `GOTO`, `GOSUB`, `IF ... THEN` a line number, `ON ... GOTO`, `ON ... GOSUB`, `RESTORE` a line number
- `FN`, `GP.SUB` and `GP.FN`
- the line before, unless that line's last statement is `GOTO`, `RETURN`, `END` or `STOP`. A line
  holding `IF ... THEN` and a statement always reaches the next.

Kept although nothing reaches them:

- a line holding `DATA`, `DIM` or `GP.DEFPROC`
- the `GP.BANKED` and `GP.ENDBANKED` lines, and a whole `GP.BANKEDSTR` group
- every line of a `GP.IF`, `GP.DO`, `GP.SELECT` or `GP.ASM` block when any line of it is kept

A variable that only removed lines use is not in the object. If the compiler's tables fill, it prints
`DEAD CODE TABLE FULL, NOTHING REMOVED` and compiles every line.

**A keep region** makes every line between its two marker lines reached.

```basl
#REM 1
REM GP.KEEP
#REM 0
DEBUG.DUMP:
  PRINT A,B
  RETURN
#REM 1
REM GP.ENDKEEP
#REM 0
```

- BASLOAD drops a `REM` unless `#REM 1` is in force. A dropped marker leaves no region and no error.
- BASLOAD-GPC also takes `#GPC KEEP` and `#GPC ENDKEEP`, one line each.
- The words match in either case. The marker lines are judged like any other line.
- A `KEEP` inside a region, an `ENDKEEP` outside one, or a region open at the end of the source stops
  the compile with `BLOCK MISMATCH`.
- With the option off, the markers are ordinary `REM`s.

**`{VAR}` on a removed variable.** A `GP.ASM` `{VAR}` naming a variable that only removed lines
create stops the compile with `UNKNOWN VARIABLE IN {}`. With the option off it compiles. Create the
variable in live code or in a keep region.

### `OUT OF MEMORY`

Everything the program allocates comes out of the one `LOW FREE` pool: scalars, arrays, and the string
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

### A region does not come out of it

`LOW CODE` and `LOW FREE` describe low memory only. **P-code inside a `GP.BANKED` region (§3.12) is
not in either figure**, and neither is a `GP.ASM` block in the region without `LOW`. The region is
reported on its own `BANK` line and written into the program's `NAME.OVL` overlay file. Moving a module into
a region takes its bytes off `LOW CODE` and gives them to `LOW FREE`.

What a region costs instead:

- **A whole bank, and 32 pages is the ceiling.** `$A000`–`$BFFF`, 8,192 bytes, with the bridges,
  the padding and the region's `GP.ASM` blocks counted in. No two regions may share a bank.
- **A byte a call site, and two bank switches a call.** A call into the region from outside it, or
  out of it to low memory, is a `.bgosub`, one byte longer than a `GOSUB`. `RETURN` selects the
  caller's bank again.
- **A file that has to travel.** `NAME.OVL` ships beside the `.PRG`. A program without it, or
  with a truncated one, stops with `?OVL` before it runs.
- **A second or so of startup**, once per load, while the overlay is read in.

Banked text is the same bargain on the data side: a `GP.BANKEDSTR` group (§3.10) is out of the
workspace, and inside a region it costs no p-code at all.

### Staying inside it

- **Quote `LOW FREE` when you change anything.** It is one line of the report and it is the only
  early warning; `PROGRAM TOO BIG` arrives once it is already too late.
- **Size a `DIM` to what is used, not to a round number.** The cost is paid on the first line of
  the program, forever.
- **Put bulk in a RAM bank.** A bank is 8,192 bytes that cost the workspace nothing. Anything held
  from start to finish and read a row at a time — a file's worth of text, a table, a screen — is
  better in a bank with an offset table at the front, read back with `PEEK` under `BANK`. See §4.5
  and `STASH.INC.BL` for the pattern.
- **A big temporary cannot be built and then freed.** Freeing is not a thing that happens on
  demand: build it in a bank, or in pieces.

---

## 8. Known bugs

Three, all live on 12th September 2026 and all reproducible. Each says what happens, what causes
it, and what to do instead. A bug leaves this list when it is fixed, not when it is understood.

### A string never gives memory back

`A$ = ""` frees nothing. A string variable owns its block: the assignment sets the length to zero
and keeps the capacity. The heap scavenger reclaims only a block a string outgrew and abandoned,
never one a variable still holds. A working buffer that has once held a 250-character line is
spoken for until the program ends.

So a big temporary cannot be built and then freed. It has to not be built.

Measured 2026-09-02. The editor's find folded the needle *and every line it scanned* into new
strings and compared with `MID$` per position: **579 bytes gone for the rest of the run**, from a
workspace with 1,489 free, and the GUI dialogs then died on what was left. Rewritten to fold in
place through `GP.STRPTR` with one `GP.INSTR` per line, a find costs **81 bytes**, and the program
came out 59 bytes smaller.

**Do this** — `PRINT FRE(0)` at eight points down the run and read the descent. It is a high-water
ceiling, so it only falls, and the step that falls is the culprit.

### BINPUT# stops at 255 bytes

`BINPUT# n, A$, len` cannot read more than 255 bytes. Three independent caps land on that one
number, so there is no single constant to raise.

| Cap | Where |
|---|---|
| the read buffer is 255 bytes | `ReadBuffer: .fill 255` |
| the count argument is 8 bit, and unchecked | `GetInteger8Bit` takes mantissa byte 0 and returns |
| a BASIC string is 255 characters | nowhere to put a longer record in any case |

The second is the trap. **`BINPUT# 12, A$, 256` sets the count to 0 and hands back an empty
string, silently.** 300 gives 44 bytes.

It is also **not a block read**. It is a `CHRIN` loop, one KERNAL call per byte with an EOF check
on top of that. `BINPUT#` is one statement, not one transfer, so anything costing a `BINPUT#` per
record pays that stride per record.

`LINPUT#` shares the same buffer and stops at 255 too, but runs on to the delimiter afterwards, so
the next read starts at a line boundary.

**Do this** — a record cannot be one string. Make it N strings of 255, or keep it in a bank and
copy out the part that is needed.
