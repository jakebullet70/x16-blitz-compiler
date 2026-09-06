# Commodore BASIC 7.0 and 3.5 — what is worth taking

Reviewed 6th September 2026, in the shape of [SIMONS-BASIC.REVIEW.md](SIMONS-BASIC.REVIEW.md). BASIC
3.5 (C16, Plus/4, 1984) and BASIC 7.0 (C128, 1985) are the same line of work — 7.0 is 3.5 plus
sprites, sound and the C128's own hardware — so they are reviewed together. BASIC 4.0's disk verbs
are included where 7.0 inherited them.

This is the disposition against the X16 ROM's extended keywords, the `GP.*` table in
`source/common-scripts/c64tokens.py`, and the BASL modules in `GPC-BASIC/`.

Keyword lists: <https://en.wikipedia.org/wiki/Commodore_BASIC> and
<https://www.c64-wiki.com/wiki/BASIC_7.0>.

These are ROM dialects rather than an add-on cartridge, so the yield is different from Simons'. Most
of the graphics and sound is what the X16 ROM already does its own way. What is worth having is the
**structure**: this is the family that solved error handling and formatted output for 8-bit BASIC, and
neither reached this machine.

## 1. Take

### 1.1 `TRAP`, `ER`, `EL`, `RESUME` — error trapping

The headline, and the reason to read these two dialects at all. A compiled program here has no error
trap: a disk error inside an application ends it.

**This design fits a compiler where Simons' `ON ERROR` and `CGOTO` do not.** `TRAP` names a target
that exists at compile time, so it resolves exactly as a `GOTO` does and `FixBranches` already knows
how to place it. `ER` and `EL` are value words in the shape of `GP.A`.

Specced in TODO.md under *Error trapping, BASIC 3.5 style*, including the split that makes it
shippable in halves: `TRAP` with a `GOTO` out of the handler first, `RESUME` — which needs the p-code
IP of the failing statement — second and separately.

### 1.2 `PRINT USING` — the mask syntax for `STR.USE`

`STR.USE` is already on the TODO list from Simons' `USE`. Do not invent a template language for it:
take this one, which every 8-bit programmer who has met a Commodore already knows.

| In the mask | Means |
|---|---|
| `#` | a digit position |
| `.` | the decimal point everything aligns on |
| `,` | group the thousands |
| `$` | a currency sign, floating up against the first digit |
| `+` `-` | the sign column, leading or trailing |
| `^^^^` | print it in exponential |
| `=` `>` | centre or right-justify a string field |

A value too wide for its mask fills the field with `*` rather than pushing the row along, which is
the behaviour the TODO entry already calls for.

**Skip `PUDEF`.** It redefines the fill, comma, point and currency characters for the whole program —
a fifth input that no caller in this tree would ever set, and a global at that.

### 1.3 `DS` and `DS$` — the disk status as values

BASIC 4.0's, kept by 3.5 and 7.0, and the thing this compiler most obviously lacks: *there is no `DS`
in this compiler*, and the X16's `DOS` keyword prints where a program needs a variable.

Specced in TODO.md as `FILE.STATUS` in the `FILES.INC.BL` entry, along with the `SCRATCH`, `RENAME`
and `COPY` verbs from the same family. BASL, zero runtime bytes.

### 1.4 `DEC()` — a hex string to a number

X16 BASIC has `HEX$` and not its inverse, so a program that reads `"$A000"` out of a config file or an
entry field has to walk it by hand. Six lines of BASL over `GP.INSTR` into `"0123456789ABCDEF"`.

Lane: BASL, in `STRINGS.INC.BL` beside `STR.USE`. Not a keyword — nothing types hex fast enough to
need machine code.

## 2. Idioms, and which of them a composite could hold

The rule is in the header of `source/compiler/source/evaluate/term/gpcomposite.asm`: each argument
used exactly once, no branch, no loop.

| BASIC 7.0 | Write instead | Composite? |
|---|---|---|
| `XOR(A,B)` | `(A OR B) - (A AND B)` | No, both arguments twice. 7.0 having `XOR` confirms what the Simons' review found: the X16 ROM has `AND`, `OR`, `NOT` and no XOR, and it is the one gap in that group that would cost runtime bytes. |
| `DO WHILE c` / `LOOP UNTIL c` | `GP.DO` / `IF c THEN GP.EXITDO` / `GP.LOOP` | No. A test at either end of the loop needs a branch offset, so a system token from the scarce unshifted range — `GP.EXITDO` already spends one. One extra line covers it. |
| `BEGIN` / `BEND` | `GP.IF` … `GP.ENDIF` | Present. |
| `RREG` | `GP.A` `GP.X` `GP.Y` `GP.C` | Present, and reads what a plain `SYS` left too. |
| `FRE(1)` | `FRE(0)` | The X16 has one heap to ask about, not the C128's two. |

## 3. Open

### `RECORD` and relative files

7.0's `DOPEN`/`RECORD` give random access by record number, which is the difference between "possible"
and "not" for any program holding a table of data. `STASHFILE` writes a rectangle and the editor
writes lines; nothing in the tree seeks.

**Answer one question before designing anything: does the X16's DOS support `REL` files at all?** If
it does, this is `DOPEN`/`RECORD` in BASL over the command channel. If it does not, the equivalent is
fixed-length records inside a `SEQ` file plus a seek, which is a different design with a different
cost. The TODO entry says the same thing.

### `WINDOW` — a clip rectangle

7.0's `WINDOW` sets a region that `PRINT` respects. Here, *nothing is clipped*: `GP.PRINTAT` past the
right edge wraps onto the next row and `GP.FILL` past the bottom writes past the end of the screen
map, which is the trap behind the `GUI.SHADOW` entry and behind every "why is my title on two rows"
question.

A real clip rectangle costs a test per row in `GP.FILL` and `GP.BOX` and per character in
`GP.PRINTAT`, plus the runtime state to hold it — in the block every GP program pays for. Worth
deciding deliberately rather than drifting into: today every caller clamps its own coordinates, and
mostly gets it right.

## 4. Reject

| BASIC 7.0 / 3.5 | Reason |
|---|---|
| `GETKEY` | As a shared BASL routine it does less than the loop it replaces. Every wait in this library does something while waiting — `LINEINPUT` blinks off `TI`, the menus repaint, `GUI2` scrolls — so it would need a callback, and BASL has none. The keyboard **drain** that came out of the same look is worth having; see TODO. |
| `SSHAPE` / `GSHAPE` | **No caller wants it.** On the C128 it was software sprites — `GSHAPE` stamps a saved shape back with `OR`/`AND`/`XOR`, so a shape moves over a bitmap and lifts off again — and this machine has 128 hardware sprites. Its other use, holding several saved rectangles at once as named values, is real where `STASH` allows one per bank, but nothing here has wanted two alive at the same time. If something ever does, the cap decides it: 255 bytes is 127 cells, and string blocks never shrink. |
| `SPRDEF`, `MONITOR`, `TRON`, `TROFF`, `AUTO`, `RENUMBER`, `DELETE`, `HELP`, `KEY` | Editor and monitor aids. Wrong side of a compiler. |
| `FAST`, `SLOW` | The C128 switches its CPU between 1 and 2 MHz. The X16 has no such control. |
| `GO64`, `BOOT`, `DCLEAR` | Machine-specific, or one `DOS` line. |
| `HEADER`, `BACKUP` | Destructive, and one `DOS` line behind a confirm. Not core-module material. |
| `COLLISION` | Interrupt-driven sprite collision. An IRQ handler is `GP.ASM`, not a keyword. |
| `PEN`, `POT` | No light pen and no paddles. `MX` / `MY` are the mouse. |
| `GRAPHIC`, `SCALE`, `BOX`, `CIRCLE`, `PAINT`, `DRAW`, `CHAR`, `RDOT`, `RGR`, `RCLR` | The X16 ROM covers this ground its own way. `PAINT` is the one real gap and the Simons' review rejects it for the same reason: heavy assembly, outside a text-mode library's remit. |
| `SPRITE`, `SPRSAV`, `SPRCOLOR`, `MOVSPR`, `BUMP`, `RSPPOS` | The ROM's `SPRITE`, `SPRMEM` and `MOVSPR` are compiled already. |
| `SOUND`, `PLAY`, `TEMPO`, `ENVELOPE`, `FILTER`, `VOL` | The `FM*` and `PSG*` keywords. |

## 5. Already covered

| BASIC 7.0 / 3.5 | Already |
|---|---|
| `DO` / `LOOP` / `EXIT` | `GP.DO` / `GP.LOOP` / `GP.EXITDO` |
| `BEGIN` / `BEND`, `ELSE` | `GP.IF` / `GP.ELSEIF` / `GP.ELSE` / `GP.ENDIF` |
| `INSTR` | `GP.INSTR` |
| `HEX$`, `JOY`, `POINTER`, `SLEEP`, `BANK` | The X16 ROM has all five |
| `RREG` | `GP.A` `GP.X` `GP.Y` `GP.C` |
| `SWAP`, `STASH`, `FETCH` | The C128's RAM-expander verbs. Banked RAM plus `STASH.INC.BL` is the same operation, and the rectangle move on the TODO list is the general form. |
| `DLOAD`, `DSAVE`, `DVERIFY` | `LOAD`, `SAVE`, `BVERIFY` |
| `DIRECTORY`, `CATALOG` | `DOS`, and `FILE.DIR` on the TODO list for the value-returning version |
| `SCRATCH`, `RENAME`, `COPY`, `COLLECT` | Specced as `FILE.DELETE`, `FILE.RENAME`, `FILE.COPY`, `FILE.VALIDATE` |
| `LOCATE`, `COLOR`, `WIDTH` | `LOCATE`, `COLOR`, `SCREEN` |
| `PUDEF` | Deliberately not taken — see §1.2 |
