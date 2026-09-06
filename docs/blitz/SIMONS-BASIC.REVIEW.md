# Simons' BASIC — what is worth taking

Reviewed 6th September 2026. Simons' BASIC (David Simons, Commodore, 1983) adds 114 keywords to C64
BASIC 2.0. This is the disposition of all 114 against three things already in the tree: the X16 ROM's
own extended keywords, the `GP.*` table in `source/common-scripts/c64tokens.py`, and the BASL modules
in `GPC-BASIC/`.

Keyword list and grouping: <https://en.wikipedia.org/wiki/Simons%27_BASIC>. The manual is not
vendored here.

The lane for anything taken follows §1 of [GP-BASIC.TIERS.md](GP-BASIC.TIERS.md): ASM owns what a
human cannot wait for, BASL owns what a human is already waiting on, and a composite owns anything
that is only a spelling of keywords already present. Two further constraints apply to everything
below.

- The GP block is 1,970 B against a 1,536 B target, and every program with one `GP.` keyword pays for
  all of it. A new keyword has to earn that; a `GP.ASM` blob inside a `.INC.BL` module does not.
- Unshifted p-code opcodes are the scarce currency, and anything carrying an inline operand must be a
  system token from that same range.

## 1. Take

Six items. None of them is a new keyword.

### 1.1 `MOVE`, `LEFT`, `RIGHT`, `UP`, `DOWN` — copy and scroll a screen rectangle

Simons' spends five keywords on one operation: move a rectangle of the text screen by a signed row
and column delta. One routine covers all five.

There is no `GP.SCROLL` and no rectangle copy. `docs/memory/scrolling-a-screen-region.md` records
three workarounds: a `STASH` saved and restored at an offset, a per-row VERA-to-VERA `memory_copy`,
and a masked hardware `VSCROLL`. `samples/GPC-HELP` uses the first, `samples/editor` the third.

Lane: `GP.ASM` in a new module. VERA-to-VERA `memory_copy` at `$FEE7`, one call per row, source and
destination on ADDR0 and ADDR1. `BMX.PALCOPY` in `GPC-BASIC/BMX.INC.BL` is the worked example.
`STASH.WALK` has the row-address arithmetic, which asks VERA for `L1_CONFIG` and `L1_MAPBASE` rather
than assuming the mode.

Traps: rows must be copied in the direction that does not overwrite the source, and the newly exposed
row is the caller's to fill. Verify by reaching one position two ways, sliding and repainting, then
comparing cells with `VPEEK` including attributes.

### 1.2 `FCOL` and `INV` — recolour a rectangle, invert a rectangle

`GP.FILL` writes the character and the colour together, so neither of these can be spelled with it.
Both are writes to the odd plane only, address `x * 2 + 1`, stride 2. `INV` swaps the two nibbles of
each attribute byte.

This is the highest value per byte in the list. Every menu highlight, selected editor row and
disabled item wants exactly one of the two.

Lane: `GP.ASM` in the same module as 1.1. Estimate 60-100 B.

### 1.3 `USE` — format a number to a template

`USE "###0.00"` and its relatives. X16 BASIC has no `PRINT USING` and neither does GP.BASIC.
`STR.PADL` aligns a column; it does not align a decimal point, pad with leading zeros, group
thousands or reserve a sign column.

Lane: BASL, `STR.USE` in `GPC-BASIC/STRINGS.INC.BL`, in `STR.NUM` and `STR.MASK$`, out `STR.STR$`.
Costs nothing to a program that does not include the module.

### 1.4 `FETCH` — filtered input

`LINEINPUT` already positions the field, edits it and returns it. What it has no form of is the
restriction: maximum length, the set of accepted characters, the terminator.

Lane: BASL, an added `LINEINPUT.ALLOW$` input on the existing routine rather than a second module.
An empty `ALLOW$` keeps today's behaviour.

### 1.5 `DESIGN` and `@` — author character and sprite shapes in source

Simons' writes a shape as rows of dots and reads them back as bytes. The X16 gives `SPRITE`,
`SPRMEM`, `TILE` and `TDATA` and no way to write the data.

Two places in this tree hand-roll it already: `GP.BOX`'s style-256-and-above form takes eight screen
codes from a caller table, and `samples/editor` builds a re-ordered font.

Lane: BASL, in strings of `"..XX..XX"` and out as bytes `POKE`d at an address. Zero runtime bytes.

### 1.6 `INSERT` and `INST` — insert and overwrite a substring at a position

`STR.REPLACE` replaces by content and `STR.SPLIT` cuts by delimiter. Neither edits at an index, and
this BASIC has no `MID$` assignment.

Lane: BASL, two short routines in `STRINGS.INC.BL`. Add them when a caller exists, not before.

## 2. Idioms, and which of them a composite could hold

The rule is in the header of `source/compiler/source/evaluate/term/gpcomposite.asm`: a composite is a
keyword with no `T` in its `.def` entry, so it emits a sequence of tokens that already exist and costs
the runtime nothing. It can only hold a rearrangement that uses **each argument exactly once**. The
p-code stack has `SWAP` and no `DUP`, so an argument wanted twice cannot be had, and a branch or a
loop is out for the same reason.

| Simons' | Spelling | Composite? |
|---|---|---|
| `DIV(A,B)` | `INT(A / B)` | Mechanically yes, the shape of `GP.HIBYTE`. Not worth a token: `GP.HIBYTE` earned one because `n AND 255` is a live bug, and `INT(A/B)` has no such trap. |
| `EXOR(A,B)` | `(A OR B) - (A AND B)` | No. Both arguments appear twice. A keyword needs a real handler in the GP block, 6 B fixed before any code. X16 BASIC has `AND`, `OR`, `NOT` and no XOR, so this is the one item here that would cost runtime bytes. The expression is exact for non-negative integers. |
| `FRAC(A)` | `A - INT(A)` | No, `A` twice. `MOD(A,1)` uses it once, but `UnaryMOD` goes through `Int32Divide` — measure before believing it returns a fraction. |
| `MOD(A,B)` | `MOD(A,B)` | Already present. `x16_unary.def` has `MOD (#,#) T N`, the token table carries `$CEDE`, and `samples/editor` calls it. |
| `DUP` | `RPT$` | Already present, and used inside `STRINGS.INC.BL`. |
| `CENTRE` | `STR.PADC` then `GP.PRINTAT` | No. The pad is a BASL loop, not a sequence of existing keywords. |
| `LIN` | `PEEK` the KERNAL cursor row | A zero-argument composite would fit. Not worth a token. |
| `TEST(x,y)` | `VPEEK` the bitmap byte and mask the bit | No. `x` is needed twice, once for the address and once for the mask. |
| `$FF`, `%1010` | — | Lexer, not keywords. X16 BASIC has both literal forms and the Blitz lexer rejects both. Conformance gap, not a feature — see `docs/memory/gpc-x16-basic-coverage.md`. |

## 3. Open, and large

Two items are worth thinking about and are not small enough to start on a whim.

### `ON ERROR`, `OUT`, `NO ERROR`

A compiled program has no error trap. A disk error inside an application ends the program. This needs
a compiler-side handler target, a runtime vector taken by the error path, and a defined answer to
where execution resumes. It is the largest item in this document.

### `LOCAL` and `GLOBAL`

Every variable in a BASL module is global. `GPC-BASIC/GP-BASIC.GLOBALS.md` and the prefix registry in
§5 of `GPC-BASIC/GP-BASIC.md` exist for that reason alone. Renaming at compile time costs no runtime
bytes and touches the symbol table everywhere.

## 4. Reject

| Simons' | Reason |
|---|---|
| `CGOTO` | Line numbers do not survive compilation. |
| `ON KEY`, `DISABLE`, `RESUME` | Needs a poll between statements. The cost lands on every program. |
| `DETECT`, `CHECK` | X16 sprite collision is an IRQ status bit. Reading it needs an interrupt handler, which is `GP.ASM` and not a keyword. |
| `PAINT` | No flood fill exists in the X16 `GRAPH_` set, so the gap is real. GP.BASIC is a text-mode library and the fill is heavy assembly. |
| `ARC`, `ANGL`, `DRAW`, `ROT` | Bitmap drawing beyond what `OVAL` and `RING` cover. Same remit problem as `PAINT`. |
| `FLASH`, `OFF`, `BFLASH`, `BCKGNDS` | VIC-II raster and extended-background behaviour with no VERA equivalent. |
| `POT` | No paddle input. `PENX` and `PENY` are `MX` and `MY`. |
| `HRDCPY`, `COPY` | An open channel to device 4 and a print loop. |
| `AUTO`, `RENUMBER`, `OLD`, `MERGE`, `FIND`, `PAGE`, `OPTION`, `DELAY`, `KEY`, `DISPLAY`, `COLD`, `DIR` | Editor and monitor aids. Wrong side of a compiler. |
| `TRACE`, `RETRACE`, `DUMP` | The three aids with a compiled meaning. They belong to a debug build, not the GP block. |
| `DISAPA`, `SECURE` | A program holding a `GP.` keyword is already compile-only and the ROM cannot `LIST` it. |

## 5. Already covered

Everything not named above resolves to something present.

| Simons' | Already |
|---|---|
| `LOOP`, `EXIT IF`, `END LOOP` | `GP.DO`, `GP.EXITDO`, `GP.LOOP` |
| `REPEAT`, `UNTIL` | `GP.DO` with `IF cond THEN GP.EXITDO`. A condition on `GP.LOOP` would need an operand, so a system token from the scarce range. |
| `ELSE`, `RCOMP` | `GP.IF`, `GP.ELSEIF`, `GP.ELSE`, `GP.ENDIF` |
| `PROC`, `END PROC`, `CALL`, `EXEC` | BASLOAD labels and `GOSUB` |
| `PLACE` | `GP.INSTR` |
| `PRINT AT` | `GP.PRINTAT` |
| `FCHR`, `FILL` | `GP.FILL` |
| `REC`, `BLOCK` | `FRAME`, `RECT`, and `GP.BOX` in text mode |
| `PLOT`, `LINE`, `CIRCLE`, `CHAR`, `TEXT` | `PSET`, `LINE`, `OVAL`, `RING`, `CHAR` |
| `HIRES`, `MULTI`, `NRM`, `CSET`, `MEM` | `SCREEN` and the KERNAL charset calls |
| `COLOUR`, `LOW COL`, `HI COL` | `COLOR` |
| `SCRSV`, `SCRLD` | `STASHFILE.INC.BL` |
| `MOB SET`, `MMOB`, `RLOCMOB`, `CMOB`, `MOB OFF` | `SPRITE`, `SPRMEM`, `MOVSPR`, all three compiled |
| `MUSIC`, `PLAY`, `VOL`, `WAVE`, `ENVELOPE`, `SOUND` | The `FM*` and `PSG*` keywords |
| `JOY` | `JOY` |
| `INKEY` | `GET` |
| `DISK` | `DOS` |
| `PAUSE` | `SLEEP` |
| `RESET` | `RESTORE` |
| `GRAPHICS` | Reserved VIC-II address. No equivalent and none wanted. |
