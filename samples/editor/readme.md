# Sample — GPC EDIT, a text / Markdown editor

An MS-DOS-EDIT-styled text editor for the Commander X16, written in **BASLOAD** and compiled by
**GPC**. It is here because it is a genuinely useful program that also leans on the one thing an
interpreted BASIC is worst at: **repainting a whole screen of text quickly**.

Both of its renderers are **inline 65C02 assembly**, written as `GP.ASM` blocks inside the BASIC
source. That is the point of the sample, and the numbers below are what it bought.

## Files

| File | What it is |
| --- | --- |
| `EDITOR.BASL` | the editor — startup/restore, theme, render, key loop, editing, find |
| `ED-STORE.BASL` | `#INCLUDE`d storage: a banked bump allocator and a 3-byte-per-line pointer table |
| `ED-MENUS.BASL` | `#INCLUDE`d menus: the same idea at fixed stride — the menu **text** lives in a bank |
| `EDITOR.PRG` | the tokenised program — the input you feed to the compiler |
| `EDITOR.SYM` | **BASLOAD's symbol file, and it is not optional** — see below |
| `TEST.MD` | the document the editor opens, and the fixture the self-check searches |
| `EDBENCH.BASL` | the benchmark: BASIC renderer against assembly renderer, in one program |
| `GPC-BASIC/` | the library it `#INCLUDE`s, shipped beside it: `GPB` `THEME` `APPSYS` and the rest |

> **`EDITOR.SYM` ships for a reason.** `{VAR}` reaches a BASIC variable through BASLOAD's own
> `#SYMFILE` record, because BASLOAD renames every variable (`ED.ASM.VIS%` becomes something like
> `A7%`) while storing REM text byte for byte — so the assembly says one name and the code uses
> another. The compiler reads the mapping from `EDITOR.SYM`, which must sit beside `EDITOR.PRG`
> under the matching name. Delete it and the compile stops with `NO SYMBOL FILE FOR {}`.

## The speed story

The editor already drove VERA the fast way and it was still slow, which is the whole lesson: **the
VERA method was never the problem — the loop around it was.** A `POKE` is a push-address,
push-value, dispatch and bank-save-restore through the p-code VM, and at two `POKE`s a cell that is
most of a full-screen repaint.

`EDBENCH.BASL` measures it. Both versions of both renderers live in **one program**, render the
**same** 79-character line into the **same** screen row, and are timed off `TI` inside the machine at
**real speed** — never `-warp`, which decouples the jiffy IRQ and makes the numbers meaningless. The
empty rep loop is measured at each rep count and subtracted, so what is reported is the render and
not the `FOR`/`NEXT` around it. After each variant the cells are read back with `VPEEK` and the row
is **blanked**, so the next variant has to write it itself — an elided render reads back as zero.

Jiffies (1/60 s) per **1000 renders of one 80-cell row**, X16 at 8 MHz:

| | BASIC | `GP.ASM` | | cycles/cell |
| --- | --: | --: | --: | --: |
| **text row** — VERA FX cache write, 2 cells a flush | 2320 | **18.8** | **123×** | 3867 → 31 |
| **chrome field** — +1 auto-increment, char + attribute | 2538 | **23.3** | **109×** | 4230 → 39 |

Read back after the timed runs, the two agree cell for cell: row `char 66, attr 1` at cell 0 and
`char 66` at cell 78 from both; field `char 84, attr 1` and a padded `char 32` from both.

**What that is in a repaint.** A full screen is 28 text rows plus the menu bar and the status line:

| | BASIC | `GP.ASM` |
| --- | --: | --: |
| full-screen repaint | ~70 jiffies — **1.2 s** | ~0.6 jiffies — **~10 ms** |

That is the lag the sample was built around, gone. A plain cursor move was already O(1) and was never
the problem; what this fixes is every *structural* repaint — PageUp/PageDown, Go-to-line, Find,
opening a file, and any edit that reflows the screen.

### It is now faster than the native-compiled editor it was measured against

The open question this sample was shelved on was "why does prog8's `x16-MSEDIT` render faster?"
[`docs/blitz/inline-asm-feasibility.md`](../../docs/blitz/inline-asm-feasibility.md) settled the
*cause* — same VERA path, the gap was pure codegen — by timing MSEDIT's real render loop under the
same protocol. Against that number:

| render of one 80-cell row | jiffies / 1000 |
| --- | --: |
| hand-written native 6502, raw-write floor | 13 |
| **GPC + `GP.ASM`, what this sample ships** | **18.8** |
| prog8 — MSEDIT's real loop | 67 |
| GPC compiled BASIC — what it replaced | 2320 |

`GP.ASM` lands **3.6× faster than prog8's editor** and within 1.4× of an idealised hand-assembled
floor that does no bounds check and no space-padding — which this renderer does, per cell. The
question is closed.

> **The old table in the shelved notes said 48 jiffies/100 for the FX row render, not 232.** Both
> are real and they measure different things: 48 was the *bare* FX flush with no per-cell source
> fetch, and the same notes recorded that the realistic loop — conditional `PEEK`, address
> arithmetic, flush — came out ~4.5× heavier. 2320/1000 is that realistic loop, which is the code
> the editor actually ran. The comparison above is like for like: same program, same work, one
> difference.

### The assembly costs nothing. Something else costs 2 KB.

OK CODE 9644 FREE 10752 RT 14079 GP-BASIC IN
OK CODE 8572 FREE 11776 RT 14079 GP-BASIC IN
```

- **`GP.ASM` is free, and the p-code got *smaller* for using it** — 7190 bytes before the rewrite,
  **7101** after. A block lowers to five bytes of p-code plus your instructions, every handler it
  uses is already in every compiled program, and the two `FOR` loops it removed were bigger than the
  ~250 bytes of assembly that replaced them. On its own it kept the editor `GP-BASIC OUT`.
- **`GP-BASIC IN` is the key dispatch, not the renderers.** `ED.DISPATCH.KEY` uses `GP.SELECT`, a core
  keyword, and **one** core keyword pulls in the whole 2 KB GP block: `RT 12031 → 14079`, object
  19,134 → 21,647 bytes, and max p-code down from 18,432 to 16,384. The select itself is **9 bytes**
  of p-code; the block is the price of admission. It is a readability trade, made knowingly — take
  the select out and the editor is `GP-BASIC OUT` again.
- **The self-check is NOT compiled into a release build any more, and that was worth 3,615
  bytes.** It used to be: `DEBUG.MODE` is tested at run time, so every assertion sat in the
  object either way -- and in this compiler p-code comes out of the same 25,600 bytes as the
  runtime workspace, so the shipped editor was paying for its own tests twice over. With the
  harness behind `#IFNDEF` the release build is **12,882 bytes with 8,192 of workspace**,
  against 16,497 and 4,608 when it carried them.
- **PETSCII cost 345 bytes of p-code and nothing at run time** — 7566 → **7911**. That is the charset
  re-ordering plus the two conversions at the disk boundary and the one at the keyboard. The
  renderers did not change by a single byte, so every render figure above still stands as measured.
- **`APPSYS` and `THEME` cost 1733 bytes of p-code and no runtime bytes** — 7911 → **9644**, THEME, APPSYS and MENUVERT together. Both are
  BASIC library modules, so they are paid for in the p-code of the program that includes them and
  nowhere else. `APPSYS.STARTUP`/`RESTORE` lean on `GP.CALL`/`GP.A`/`GP.X`/`GP.Y`, which are GP block
  keywords — already bought and paid for by the `GP.SELECT` above, so they add nothing to `RT`.
- **Driving `MENUVERT` properly gave 5 bytes back** — 9650 → **9645**. The hand-rolled loop over
  `MENUVERT.ROW` was not only wrong, it was bigger than `GOSUB MENUVERT.DRAW`.
- **The two new assertions cost 168 bytes** — 9645 → 9713 for `DDROWS`, and → **9813** for the 600
  menu opens. Compiled into every build because `ED.SELFCHECK` is, exactly like the rest of the
  self-check above. Worth it: between them they are the checks that would have caught a panel of
  the wrong height, and a frame leak that nothing on screen would ever show.
- **`ED.MENU.LOOP` became `GP.DO` + `GP.SELECT`**, the same shape as the main loop and its dispatch.
  It replaced a label with six `GOTO`s back to it, two of which jumped *forward* into
  `ED.MENU.SELECT` and `ED.MENU.CANCEL` and leaned on **their** `RETURN` to leave
  `ED.OPEN.MENUBAR` — so the two ways out of the menu were invisible from the loop that owned them.
  Both are now `GP.EXITDO` from inside a `GP.CASE`, which is allowed and *does* close the selector's
  frame on the way past. That last part is measured, not taken on trust: `MENU 600 OPENS` drives
  `ED.OPEN.MENUBAR` six hundred times through `kbdbuf_put`, and a leak of even the selector's
  7 bytes alone would overflow the 4 KB frame stack before it finished.

## How it renders

Everything — text area **and** chrome — goes straight into VERA's text map (bank 1, base `$B000`,
cell = `45056 + row*256 + col*2` → `[char, attr]`, `attr = bg*16 + fg`). Three things are
load-bearing, and only the third is new:

1. **O(1) caret movement.** A plain arrow key restores the old caret cell and inverts the new one —
   about two cells, not a repaint. Only a real scroll or a structural edit touches more.

2. **Hardware vertical scroll.** A one-line scroll bumps VERA `L1_VSCROLL` (`$9F39/$9F3A`, map
   pixels, +8 a text row) and repaints **3 rows**, not 28: the menu bar (which must stay put while
   the map slides under it), the newly exposed text row, and the status bar. Every write is
   addressed at map row `screen_row + ED.MAP.TOP`, where `ED.MAP.TOP = VSCROLL/8`. The map is 64
   rows tall (probed from `L1_CONFIG`, so it self-adapts) and `ED.MAP.TOP` is bounded to
   `[0, MAP.H − SCREEN.ROWS]` = `[0, 34]`, so the window never crosses the map's bottom edge — the
   code **never relies on VERA's vertical wrap**; at the bound it rewinds and repaints.

3. **Both renderers in `GP.ASM`.** `ED.RENDER.ROW` keeps the FX 32-bit cache write — one `DATA0`
   write flushes 4 VRAM bytes = 2 cells, with the row's uniform attribute loaded into the cache's
   two attr slots once. `ED.PUT.FIELD` keeps +1 auto-increment and streams char, attr, char, attr.
   The VERA registers, the cell loop and the teardown are all inside the one block, because at
   ~650 cycles a `POKE` even the eight-register prologue would have cost more than the whole
   native loop.


## PETSCII, and where the encoding boundary is

The editor runs on **charset 3, PET upper/lower** — PETSCII glyphs, both cases. That is not free,
because the renderers write document bytes straight into VERA and **a VERA tile index is a *screen*
code, not a character code**. Under ISO it never showed: the ISO font happens to be in ASCII order,
so the index and the character code were the same number and nothing had to be translated.

**So the font moves, not the text.** `ED.PETFONT` re-orders the 2 KB charset in VRAM at `$1:F000` so
that glyph *N* is the glyph for code *N*. A document byte is then its own tile index again, and
**both `GP.ASM` blocks are untouched — zero cycles a cell**. Translating inside the renderer instead
costs `TAX` + `LDA table,X` = 6 cycles on a 31-cycle cell, about 19% of the render, on every
character of every repaint. (The runtime's own arithmetic `pet2scr` is ~29 cycles and was never in
the running.)

**It is re-ordered to ASCII, not to PETSCII, and that is the part worth copying.** BASLOAD writes
string literals through as the bytes that were in the source file, so every literal here — menu
names, prompts, messages — is ASCII, and no directive changes that. Order the font by PETSCII and
they all render case-swapped *and* find stops matching its own needles. Hence the rule:

> **PETSCII on disk. ASCII everywhere above it.**

The conversions sit on that boundary and never in a loop over cells: `DOC.LOADFILE` converts per
character on the way in, `DOC.TOPETSCII` per line on the way out, and `ED.KEY.RANGE` per keystroke —
`GET` hands back `$41-$5A` for a lower-case letter and `$C1-$DA` for an upper-case one, which is why
an ASCII `32..126` printable test silently drops every capital.

**In ASCII order the permutation is also tiny.** Charset 3 already holds `$20-$3F` and the capitals
`$41-$5A` exactly where ASCII wants them, so only 38 glyphs move — chiefly `a-z`, from screen
`$01-$1A`. Two moves read from a run that another one writes, so `$60` goes before `$40` and
`$7B-$7F` before `$5B-$5F`; but nothing forms a cycle, so no staging buffer is needed. A
*PETSCII*-ordered permutation does need one — its block map contains `6←2, 2←0, 0←4, 4←6`.

**One thing the KERNAL forces.** Anything `PRINT`ed after the re-order comes out wrong, because
CHROUT converts to a screen code first and then indexes a font that is no longer in screen-code
order. Here that is only `ED.QUIT`, which reloads the stock charset with `POKE 780, 3 : SYS 65378`
before saying `BYE.` — the `SYS` rather than `CHR$(14)`, which may be a no-op when the charset is
already selected.

Verified rather than argued: all 256 glyphs re-indexed with **zero** mismatches, read back out of
VRAM; and a load→save round trip byte-for-byte identical to the original, apart from `PRINT#`

## Startup, restore, and theming

Two things an application on somebody else's machine owes them, both from the shipped library rather
than hand-rolled here.

**Give the screen back.** `APPSYS.STARTUP` is the *first* thing `ED.INIT` does — before any screen
mode or colour of the editor's own — because it records the state as it finds it, so anything changed
beforehand is what the user would be left with. `ED.QUIT` calls `APPSYS.RESTORE`, which puts back the
mode, the **charset** and the text colour. The editor runs 80x30, and someone who prefers 40x30 gets
40x30 back.

**The charset had to be taught to `APPSYS`**, and it is worth knowing why it was missing. `$FF62`
only *sets* a charset — there is no "get" call — so it looked unrecoverable. It is not: **`$0372`
holds the charset number outright**, reading `2` at boot and reading back exactly what was last set,
1 to 7. That is probed, not documented. Without it `ED.QUIT` hardcoded charset 3, so anyone who
started the editor in upper case — which is the machine's default — was dropped into lower case on
the way out.

Restoring the charset does double duty here: it is what the user chose, *and* re-uploading it is what
undoes `ED.PETFONT`'s re-ordering, so the `BYE.` prints in the right glyphs. Nothing may be `PRINT`ed
before that line — see the PETSCII section above for why.

**Colours are named roles, not literals.** They used to be numbers scattered through the chrome — `97`
here, `240` there, `33` for an error — with no way to restyle short of hunting them all down. They are
now the seven roles `THEME.INC.BL` defines, held in `THEME.CLR()`:

| role | is | role | is |
|---|---|---|---|
| `PAGE` | the dropdown panel | `TITLE` | menu bar, status bar, messages |
| `TEXT` | the document | `BORDER` | the hotkey letter in a menu title |
| `HILITE` | caret, active title | `DIMMED` | prompts |
| `WARN` | errors | | |

**The names are free.** `#DEFINE` substitutes at translation time, so `THEME.CLR(THEME.TITLE)`
compiles to `THEME.CLR(2)` — no variable, no lookup, a one-byte constant index. An attribute is
`background * 16 + foreground`, which is what VERA's colour byte and every GP drawing command already
take.

`ED.THEME` sets the editor's *own* palette rather than using `THEME.LOAD`'s. The library default is a
blue-page application look; this is DETOK's, which is what the sample has always drawn. **The roles
are what is shared, not the colours** — which is the entire point of having roles. Flip `ED.DARK` at
the top of the file for the dark variant.

One trap worth knowing: `ED.THEME` calls `THEME.LOAD` and then overwrites the slots, rather than
doing its own `DIM`. **GPC rejects a second `DIM` of the same array even when only one of them can
ever run** — `ARRAY REDEFINED`, at compile time.
writing CR where the fixture had LF.

## The menus, and the flag that makes the GP drawing commands usable

The dropdown is drawn by `MENUVERT.DRAW` — `GP.FILL` for each row, `GP.PRINTAT` for its text —
inside a `GP.BOX` frame. Neither worked at first, for two quite separate reasons: the re-ordered
font, below, and a caller that was not really calling the library at all.

### Use the whole interface, or you are guessing at it

`ED.DRAW.DROPDOWN` first set `MENUVERT.X`, `.Y` and `.WIDTH` — three fields of nine — and then
hand-rolled its own `FOR` loop poking `.DRAWROW` and `.DRAWATTR` into **`MENUVERT.ROW`, the module's
lowest entry point**, leaving `.COUNT`, `.ATTR` and `.HIATTR` at zero. It drew a panel of the wrong
height with rows missing, and the library got the blame for a session.

It was never the library. `GPC-BASIC/MENUDEMO.EXP.BL` is MENUVERT's own example; built headlessly
with `MENUVERT.RUN` swapped for `MENUVERT.DRAW` and the tile map read back out of VERA, it renders
five items in five rows with the frame exactly where it belongs. **The difference between MENUDEMO's
nine assignments and this sample's three was the whole bug**, and it was visible in a side-by-side
read of the two files long before any emulator was involved.

`MENUVERT.ROW` reads `MENUVERT.ATTR` itself — it is the test at the routine's tail that decides
whether a row gets its hotkey tinted — so a caller that never sets it is not calling the routine,
it is guessing at it. Setting the documented inputs and calling `MENUVERT.DRAW` is also **5 bytes
smaller** than the hand-rolled loop: `OK CODE 9650` → `9645`. The shipping build is `9713`,
the extra 68 being the `DDROWS` assertion below.

The self-check was green throughout, which is its own lesson: it asserted **one** `VPEEK` of the
panel, and one sampled cell cannot see a wrong height or a skipped row. It now walks the whole
shape — frame row, every item row, frame row — as `DDROWS`.

### The frame colour is picked, not derived

`GP.BOX` style 0 borders with `$A0`, a **reverse** space, so the cell is entirely *foreground*: only
the low nibble of the attribute is ever seen. Deriving that nibble from `THEME.PAGE` collided twice
— its foreground is black, on the black document; its background is the panel's own grey, on the
panel. The frame is `THEME.CLR(THEME.TEXT)`, whose low nibble is the document's own white, and that
reads against both.

**`GP.PRINTAT` converts PETSCII to a screen code before writing.** Against an ASCII-ordered font that
is one conversion too many: measured, `GP.PRINTAT 0,5,"Ab"` wrote tiles `1` and `66`, which render as
`aB`. Every letter in the wrong case.

**The fix is to stop lying to the system.** Bit 6 of `$0372` means "text is ASCII, not PETSCII", and
after `ED.PETFONT` that is simply true, so `ED.INIT` sets it. With the flag on, the same call writes
`65` and `98` — the raw bytes. It is poked directly rather than via `CHR$(15)`, because `CHR$(15)`
would also upload the ISO font and throw away the PETSCII glyphs that are the point.

Three things follow from the flag, and all three are wanted: the **keyboard** returns ASCII, so
`ED.KEY.RANGE` no longer case-swaps a keystroke; `CHR$()` and `PRINT` stop translating, so KERNAL
output lands on the right glyphs; and the GP drawing commands work.

**The box style is not a free choice.** Styles 2 to 4 border with line glyphs from screen codes
`$40-$7F`, which is precisely the run `ED.PETFONT` overwrites with ASCII lower case — a single-line
box comes out as `p @ @ ... B`, measured. **Style 0 borders with `$A0` alone**, which sits outside that
run and survives untouched. `$A0` is a reverse space, so it paints in the *foreground* colour, which
is why the frame is drawn in `THEME.PAGE`s *background* nibble: painting it in `THEME.PAGE` itself put a black frame on a black text area, present and invisible.

That is the same limitation the GP-BASIC manual already records for `GP.BOX` in ISO mode, arrived at
from the other direction.
## The key dispatch

The main loop is a bare `GP.DO` whose whole body is the `GET` wait; the table lives in
`ED.DISPATCH.KEY` as a `GP.SELECT`.
Three things about it are worth reading before copying the shape:

- **`GP.SELECT`, not `ON x GOSUB`.** `ON` is a real skip table and stays right for a dense `1..n`
  index. These key codes are `2, 4, 13, 17, 19, 20, 25, 27, 29, 130, 134, 137, 145, 148, 157` — a
  skip table over that span is 158 entries holding fifteen destinations. Sparse selectors are what
  `GP.SELECT` is for.
- **Nothing jumps out of the select.** `GP.ENDSEL` is what releases the selector's stack frame, so a
  `GOTO` past it leaks one — in a key loop, one per keystroke for the life of the session. Every
  case falls through and the single `GOTO` back to the top is *after* `GP.ENDSEL`. The self-check
  runs 400 dispatches back to back to prove it.
- **The two ranged keys are not cases.** `GP.CASE` takes a list of expressions, not a range, and
  Commodore+letter (161..191) and printable (32..126) cover 126 codes between them. They sit in
  `ED.KEY.RANGE` off `GP.OTHER`. They used to be at the *front* of the `IF` ladder where order
  mattered; it turns out it never did — no single-code case falls inside either range, so neither
  could ever shadow the other.

**Two things in the assembly are worth stealing.** There is no expression syntax in `GP.ASM` — no
`LABEL+1` — so the source address is written **into the operand** of the instruction that reads it:
`STA RGA,X` with `X=1` patches the low byte and `X=2` the high, and `RGA: LDA $FFFF,Y` then reads
through it. And a BASIC string is reached by dereferencing its slot: `{A$}` is the **slot**, the slot
holds the block address, and the text starts 3 bytes in (`[MaxLen][control][ActLen][text…]`).

## Build

BASLOAD resolves `#INCLUDE` off the drive, so the sources and `GPB.INC.BL` have to sit together on
it. From the repo, copy `EDITOR.BASL`, `ED-STORE.BASL`, `TEST.MD` and `GPC-BASIC/GPB.INC.BL` into
`testing/` (the emulator's drive), then:

1. **Tokenise.** `BASLOAD "EDITOR.BASL"` at the ROM prompt. The source's own `#SAVEAS` and
   `#SYMFILE` write `EDITOR.PRG` and `EDITOR.SYM`. Both are already here, so skip this unless you
   edit the source — **and if you do edit it, re-tokenise, because a stale `.SYM` resolves `{VAR}`
   to the wrong slot.**

2. **Compile.** Run `GPC.PRG` and answer `EDITOR.PRG` / `C.EDITOR.PRG` / no map / not shared; or
   write a `GPC.INPUT` directly:

   ```
   EDITOR.PRG
   C.EDITOR.PRG
   ```

3. **Run.** `LOAD "C.EDITOR.PRG",8 : RUN`. It opens `TEST.MD`.

`EDBENCH.BASL` builds the same way and **must be run at real speed** — under `-warp` its numbers are
nonsense.

## The self-check

THREE BUILD MODES, chosen by the three `#DEFINE`s at the top of `EDITOR.BASL` -- BASLOAD does
not nest `#IFNDEF`, so they are flat symbols rather than one switch:

| mode | comment out | `DEBUG.MODE` | code / workspace |
| --- | --- | --- | --- |
| release (as committed) | nothing | 0 | 12,882 / 8,192 |
| core tests | `ED.RELEASE`, `ED.NOCORE` | 1 | 13,749 / 7,424 |
| optional tests | `ED.RELEASE`, `ED.NOOPT` | 1 | 15,887 / 5,120 |

**The harness is split in two because it no longer fits beside itself.** The core half keeps
the screen geometry, the theme and ALT-key tables, the hardware VSCROLL and the end-to-end
walk; the optional half has find, the menu bar and dropdown, the render and gutter checks,
key dispatch, the 600-open menu stress test and the GUI dialogs. Both end in `M4 OK`, and
`ED.TESTDOC` -- the 40-line L0..L39 fixture -- sits outside both guards because both need it.

It runs headless instead of interactively,
driving the model and the dispatch programmatically (an `ED.SIM.*` hook stands in for the
interactive prompts) and `PRINT`ing markers a watcher can grep. It ends in `M4 OK`. It checks:

- go-to-line, find, find-next, a wrapping case-insensitive find, and a miss;
- the discard-confirm both ways — declining leaves the document alone, accepting resets it;
- **the renderers, by reading the cells back out of VRAM**: menu bar, dropdown, message line, two
  text rows and two mid-field cells, each verified for char *and* attribute;
- caret place and restore;
- **the key dispatch** — `ED.DISPATCH.KEY`'s `GP.SELECT` table driven with real key codes: cursor
  moves, Home/End, the insert/overwrite toggle, a printable character reaching `ED.DO.INSERT`
  through `GP.OTHER` and the 32..126 range, backspace undoing it, an unbound code changing nothing,
  and **400 consecutive dispatches** — which is what would catch a leaked selector frame;
- hardware VSCROLL — register writes, the map-offset render, and the rewind at the bound;
- end to end: a 40-line document, the cursor walked down 35 lines through 8 hardware scrolls, then
  the right document lines confirmed at the map rows VSCROLL is actually displaying.

The key **dispatch** is now tested, which it was not before: the main loop is only the `GET` wait, and
the table it calls is a routine, so the self-check can drive it directly. What is still untested is
**menu navigation** — that has its own `GET` loop inside `ED.OPEN.MENUBAR`, and key injection into a
running program is flaky — but the commands it dispatches to are each driven directly above.

## What is not done

- **No syntax highlighting, no word wrap, no undo, no block operations.** It is an editor, not *the*
  editor.
- **The store never frees a single record.** Deleting a line leaks its content until the next save;
  reclamation is bulk, by reloading. Fine for a sample, and it is why the allocator is 30 lines.
- **A line is capped at 250 characters** on load, and a banked menu string at 31.
- **The editor owns banks 1 upward**: 1–3 the line-pointer table, 4 the cells a dialog covers
  (`GUI.BANK`), 5 the menu text, 6 and up the document arena. Nothing else in a program using this
  store may touch them.
- **Files are assumed to be PETSCII on disk.** Opening something authored on the host — which will be
  ASCII — shows every letter case-swapped. Detecting the encoding on load is the obvious fix, and no
  byte in `$61-$7A` is a fair PETSCII tell, since in PETSCII that run is graphics. `TEST.MD` ships
  converted rather than left as the exception.
