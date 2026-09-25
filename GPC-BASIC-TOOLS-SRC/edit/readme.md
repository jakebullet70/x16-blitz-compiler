# Sample — GPC EDIT, a text / Markdown editor

An MS-DOS-EDIT-styled text editor for the Commander X16, written in **BASLOAD** and compiled by
**GPC**. It is here because it is a genuinely useful program that also leans on the one thing an
interpreted BASIC is worst at: **repainting a whole screen of text quickly**.

Both of its renderers are **inline 65C02 assembly**, written as `GP.ASM` blocks inside the BASIC
source. That is the point of the sample, and the numbers below are what it bought.

## Files

| File | What it is |
| --- | --- |
| `EDIT.BASL` | the editor â€” startup/restore, theme, render, key loop, editing, find |
| `ED-FONT.BASL` | `#INCLUDE`d font: charset 3 re-ordered into ASCII order in VRAM, and the box glyphs rescued out of the way |
| `ED-MISC.BASL` | `#INCLUDE`d forks of the library modules it uses: APPSYS and STRCASE |
| `ED-MENUS.BASL` | `#INCLUDE`d forks of MENU, MENUPULL and MENUKEY, plus the editor's own bar, dropdowns and dispatch |
| `ED-DIALOG.BASL` | `#INCLUDE`d dialogs: the adapter between the editor's call sites and the standard GUI verbs |
| `ED-STORE.BASL` | `#INCLUDE`d storage: a banked bump allocator and a 3-byte-per-line pointer table |
| `GPB.INC.BL` | the library's keyword list, the one file taken from `GPC-BASIC`. It defines `#TOKEN`s, not code |
| `EDIT.SRC.PRG` | the tokenised program â€” the input you feed to the compiler |
| `EDIT.SRC.SYM` | **BASLOAD's symbol file, and it is not optional** â€” see below |
| `EDIT.PRG` | the compiled program, built EMBEDDED, so it carries the runtime |
| `EDIT.OVL` | the banked code regions and the editor's banked text, read at startup. It ships with `EDIT.PRG` |
| `TEST.MD` | the document the editor opens, and the fixture the self-check searches |
| `bench/` | the four benchmarks, each holding old and new in **one** program: `BENCHROWS` renderer against renderer, `LOADBEN` loader against loader, `SLOTBEN` and `SLOTTST` for the line table |

The editor runs the library from RAM banks. THEME, BANKMGR, STASHVRAM, MENU, MENUPULL, LINEINPUT,
GUI, COMBO, CHECK and GUI-DIALOGS are `#INCLUDE`d unchanged inside three `GP.BANKED` regions in
`EDIT.BASL`, so none of them is in low memory. What is still forked is what could not be banked or
had to be changed: APPSYS and STRCASE in `ED-MISC.BASL`, the font work in `ED-FONT.BASL`, and the
editor's own bar, dropdowns and dispatch in `ED-MENUS.BASL`. STASH stays in low memory because it
executes `BANK`, which a region may not, and MENUKEY because it reads the keyboard layout under
bank 0.

**The editor's own literal text is in a bank too.** A string constant costs `2 + LEN` bytes of
p-code wherever it is written and `GP.BSTR` costs 5, so text of five characters or more is
cheaper read from the bank. `ED.TEXTBANK` is bank 12, and five `GP.BANKEDSTR` groups share it:
`BS.MENU` in `ED-MENUS.BASL` for the bar and dropdown labels, and `BS.MSG`, `BS.DLG`, `BS.ABOUT`
and `BS.BAR` at the top of `EDIT.BASL` for the status line, the dialogs and the About box. Every
string has a `#DEFINE` for its index, because the index is positional and a line added to a group
shifts every number after it. The `"BANK ... FAILED"` message stays a literal on purpose: it
prints when a bank could not be claimed, which is the one moment the text bank may not be the
editor's.

The banks, in order: 1 the runtime's, 2-4 the line table, 5 the undo log, 6 the menu and theme
code, 7 the menu rows, 8 the GUI engine, 9 the dialog verbs, 10 the cells a dialog covers, 11 the
clipboard, 12 the editor's text, and 13 up to the top of RAM the document arena.

> **`EDIT.SRC.SYM` ships for a reason.** `{VAR}` reaches a BASIC variable through BASLOAD's own
> `#SYMFILE` record, because BASLOAD renames every variable (`ED.ASM.VIS%` becomes something like
> `A7%`) while storing REM text byte for byte â€” so the assembly says one name and the code uses
> another. The compiler reads the mapping from `EDIT.SRC.SYM`, which must sit beside
> `EDIT.SRC.PRG` under the matching name. Delete it and the compile stops with
> `{} NEEDS #SYMFILE`.

## The speed story

The editor already drove VERA the fast way and it was still slow, which is the whole lesson: **the
VERA method was never the problem — the loop around it was.** A `POKE` is a push-address,
push-value, dispatch and bank-save-restore through the p-code VM, and at two `POKE`s a cell that is
most of a full-screen repaint.

`bench/BENCHROWS.BASL` measures it. Both versions of both renderers live in **one program**, render the
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
- **`APPSYS` and `THEME` cost 1733 bytes of p-code and no runtime bytes** — 7911 → **9644**, THEME, APPSYS and the menu module of the time together. Both are
  BASIC library modules, so they are paid for in the p-code of the program that includes them and
  nowhere else. `APPSYS.STARTUP`/`RESTORE` lean on `GP.CALL`/`GP.A`/`GP.X`/`GP.Y`, which are GP block
  keywords — already bought and paid for by the `GP.SELECT` above, so they add nothing to `RT`.
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
   addressed at map row `screen_row + ED.MAP.TOP%`, where `ED.MAP.TOP% = VSCROLL/8`. The map is 64
   rows tall (probed from `L1_CONFIG`, so it self-adapts) and `ED.MAP.TOP%` is bounded to
   `[0, MAP.H − SCREEN.ROWS%]` = `[0, 34]`, so the window never crosses the map's bottom edge — the
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

Two things an application on somebody else's machine owes them, both forked into `ED-MISC.BASL`
rather than hand-rolled here.

**Give the screen back.** `ED.APPSYS.STARTUP` is the *first* thing `ED.INIT` does — before any screen
mode or colour of the editor's own — because it records the state as it finds it, so anything changed
beforehand is what the user would be left with. `ED.QUIT` calls `ED.APPSYS.RESTORE`, which puts back the
mode, the **charset** and the text colour. The editor runs 80x30, and someone who prefers 40x30 gets
40x30 back.

**The charset is restored from `$0372`, not from a KERNAL call.** `$FF62` only *sets* a charset,
and there is no "get" call. `$0372` holds the charset number outright, reading `2` at boot and
reading back exactly what was last set, 1 to 7. That is probed, not documented.

Restoring the charset does double duty here: it is what the user chose, *and* re-uploading it is what
undoes `ED.PETFONT`'s re-ordering, so the `BYE.` prints in the right glyphs. Nothing may be `PRINT`ed
before that line — see the PETSCII section above for why.

**Colours are named roles, not literals.** They are the roles the `THEME` section of
`ED-MISC.BASL` defines, held in `ED.THEME.CLR()`:

| role | is | role | is |
|---|---|---|---|
| `TEXT` | the document | `TITLE` | the menu titles |
| `BAR` | menu bar, status row, messages | `BORDER` | the hot key letter in a menu title |
| `HILITE` | caret, active title | `DIMMED` | the line-number gutter, disabled rows |
| `WARN` | errors | | |

`PAGE` and `FOCUS` are in every palette and this editor reads neither.

**The names are free.** `#DEFINE` substitutes at translation time, so
`ED.THEME.CLR(ED.THEME.TITLE)` compiles to `ED.THEME.CLR(2)` — no variable, no lookup, a one-byte
constant index. An attribute is
`background * 16 + foreground`, which is what VERA's colour byte and every GP drawing command already
take.

`ED.THEME.SELECT` fills the slots from one of five palettes, chosen by `ED.THEME.ID` at the top of
`EDIT.BASL`. **The roles are what is shared, not the colours** — which is the entire point of
having roles.

One trap worth knowing: every palette writes the same array rather than `DIM`ming its own. **GPC
rejects a second `DIM` of the same array even when only one of them can ever run** —
`ARRAY REDEFINED`, at compile time.

## The menus, and the flag that makes the GP drawing commands usable

The menus are `ED-MENUS.BASL`'s forks of `MENU`, `MENUPULL` and `MENUKEY`. The bar is the bar slot,
drawn by `ED.MENU.DRAWBAR` and never run: ALT+letter is the editor's key and opens a dropdown at
once, while ALT on its own lights the bar without opening one. ESC opens nothing — it only backs out
of a dropdown that is already open. `ED.MENUS.SETUP` builds the bar and all three dropdowns once at startup, and
`ED.MENUTO.PULLDOWN` runs the one under the chosen title, saving the cells under it in VRAM and
putting them back after. LEFT and RIGHT come back as `ED.MENU.NEXTBAR`; a letter no row claims is
tried against the titles with `ED.MENU.HOTROW`, so a letter is a row's hot key first and a title's
second. `ED.MENU.KEYS.ON` asks `ED.MENU.HOTROW` too, for the keymap.

`ED.MENUTO.PULLDOWN` paints the bar item and the panel from one set of colours, and here the bar is
blue while the panel is the page. So the bar is drawn in its own colours first with the title
already lit, and the dropdown's highlight is the bar's: the relight changes nothing.

Every key goes through `ED.MENUS.KEY` before the editor sees it, and `ED.MENUS.PICK%` is `-1` when
the menus did not take it. A chosen row lands in `ED.MENUS.DISPATCH`, which turns it into an
`ED.CMD.*` call in `EDIT.BASL`.

### The frame is the rescued glyphs

`GP.BOX`'s own line styles border with screen codes `$40-$7D`, which is precisely the run
`ED.PETFONT` overwrites with ASCII letters — a single-line box comes out as `p @ @ ... B`, measured.
`ED.PETFONT` copies the six line glyphs up to `$C0-$C5` before the re-order, `ED.GUI.SETUP` packs
them into `ED.STYLE$`, and `ED.MENU.DROPSTYLE` hands that string's address to `GP.BOX` as a custom
style. Frame and rows are `ED.THEME.CLR(ED.THEME.TEXT)`, the document's own white on black, so the
panel reads as a framed hole in the page; only the highlight breaks it.

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

## The dialog box

Every question the editor asks -- a file name, a search, a line number, a save-or-discard -- is a
verb of `GUI-DIALOGS.INC.BL`, called where the question is asked. The editor draws none of it:

    ED.INPUT$ = GP.FN(INPUTBOXEX, "Find", "Find text:", "", "", ED.FIND$, ED.DLG.WIDTHDEFAULT, 0)
    ED.SAVE.ANSWER% = GP.FN(ASK3, ED.CONFIRM.TITLE$, "Save changes?", "&Save", "Do&n't Save", "&Cancel", 1, 3)

`ASK3` was written for this editor and added to the library, because a row of three buttons is what
every program needs and a yes/no can only ever offer two of them. `INPUTBOXEX` answers with the
typed text and leaves the OK or Cancel in `GUI.OK`.

`ED-DIALOG.BASL` holds what the library has no verb for, and nothing else -- 56 lines where the
editor's own dialog engine was 455:

| Call | In | Out |
| --- | --- | --- |
| `GP.FN(ASKTEXT2, ...)` | title, two prompts, two starting strings, field width | non-zero on OK, and the text in `ED.DLG.TEXT1$` and `ED.DLG.TEXT2$` |
| `GOSUB ED.DLG.WAITKEY` | | a told-not-asked box held until a key |

`ASKTEXT2` is `FORM.BEGIN`, two `FORM.FIELD`s, `FORMTO.RUN` and `FORM.END`. It gives its answers
back in two variables rather than as its result, because a verb returns one value and both fields
have to be read before `FORM.END` takes the form down. It belongs in the library, and will move
there once a second program wants it.

**Restoring the box costs no repaint.** `GUI.OPEN` stashes the cells the box covers into the bank
`DLGRESET` was given -- bank 10 here, named in `ED.GUI.SETUP` -- and `GUI.CLOSE` puts them back, so
the document underneath is never redrawn.

The frame is the editor's own rescued glyphs: `ED.GUI.SETUP` builds `ED.STYLE$` once and hands it to
both `MENU.DROPSTYLE` and `GUI.GLYPH$`, so a dropdown and a dialog are drawn with the same eight
characters. Colours come from the theme on every open, the shadow included -- `DLGSHADOWCLR` takes
`THEME.SHADOW` there.

**One stash handle, not two.** `ED.SV.MAX` is 1 in `ED.INIT`: the dropdown still saves its cells
through `STASH`, and a dialog opened over it saves into its own RAM bank instead.

## Build

BASLOAD resolves `#INCLUDE` off the drive, so the six sources, `GPB.INC.BL` and `TEST.MD` have to
sit together on it. Then:

1. **Tokenise.** `BASLOAD "EDIT.BASL"` at the ROM prompt. The source's own `#SAVEAS` and
   `#SYMFILE` write `EDIT.SRC.PRG` and `EDIT.SRC.SYM`. Both are already here, so skip this
   unless you edit the source — **and if you do edit it, re-tokenise, because a stale `.SYM`
   resolves `{VAR}` to the wrong slot.**

2. **Compile, EMBEDDED.** The runtime goes inside the object, and the three code regions and the
   menu store's text go into `EDIT.OVL` beside it. Run `GPC.PRG` and answer `EDIT.SRC.PRG` /
   `EDIT.PRG` / a map / embedded.

3. **Run.** `LOAD "EDIT.PRG",8 : RUN`. It opens `TEST.MD`. `EDIT.OVL` has to be on the same
   drive, or it stops with `?OVL`.

Headless, from the repository root:

```
python source/gpc/build_basl.py --drive GPC-BASIC-TOOLS-SRC/edit EDIT.BASL EDIT.SRC.PRG
python source/gpc/compile_shared.py --drive GPC-BASIC-TOOLS-SRC/edit --embedded EDIT.SRC.PRG EDIT.PRG EDIT.MAP
```

`build_basl.py` does not notice an edited `#INCLUDE`, so delete `EDIT.SRC.PRG` before
re-tokenising.

**On a fresh clone the embedded compile stops with `NO RUNTIME IMAGE`.** An embedded object
carries the runtime, and the engine streams it from `GPC.IMG.<build>.BIN` with
`GP1.IMG.<build>.BIN` beside it — build-numbered so a stale image is *absent* rather than
silently wrong. Both are gitignored (`GPC-BASIC-TOOLS-SRC/*/GP*.IMG.*.BIN`), so they do not come with a
clone. Copy the current pair in from `source/drive/`:

```
copy source\drive\GPC.IMG.*.BIN GPC-BASIC-TOOLS-SRC\edit\
copy source\drive\GP1.IMG.*.BIN GPC-BASIC-TOOLS-SRC\edit\
```

The `GPB/GPC/GP1.RT.<build>.BIN` runtimes already here are the *shared* ones and are not
what an embedded build reads.

`bench/BENCHROWS.BASL` builds the same way and **must be run at real speed** — under `-warp` its numbers are
nonsense.

## What is not done

- **No syntax highlighting, no word wrap, no undo, no block operations.** It is an editor, not *the*
  editor.
- **The store never frees a single record.** Deleting a line leaks its content until the next save;
  reclamation is bulk, by reloading. Fine for a sample, and it is why the allocator is 30 lines.
- **There is no self-check harness.** The build is verified by compiling and running it, not by a
  test mode inside the source.
- **A line is capped at 250 characters** on load. A menu row is not capped: the forked store is a
  string array.
- **The editor claims its banks from `BANKMGR`**, in `ED.CLAIM.FIXED.BANKS` and
  `ED.CLAIM.ARENA.BANKS`. Bank 1 is the runtime's. 2—4 are the line-pointer table, 5 is undo and redo,
  6 is the first code region, 7 is the menu store's text, 8 and 9 are the two GUI code regions, 10
  is where a dialog saves the cells it covers, and the document arena runs from 13 to the top of
  RAM. A code region is only code to the compiler: to `BANKMGR` it is a bank like the rest, which
  is why each one is claimed. When the arena is full a line is stored empty rather than written
  into a bank the editor does not own, and the status row says `DOCUMENT FULL`.
- **Files are assumed to be PETSCII on disk.** Opening something authored on the host — which will be
  ASCII — shows every letter case-swapped. Detecting the encoding on load is the obvious fix, and no
  byte in `$61-$7A` is a fair PETSCII tell, since in PETSCII that run is graphics. `TEST.MD` ships
  converted rather than left as the exception.
