# The page-style form

A plan, not a change. Continues `GUI-CUA-PLAN.md`, which took the library as far as
popups. What is missing is the other half of the same engine: a form drawn on the
screen the program already owns, with no box around it, no stash under it and no close
at the end of it.

The listbox is meant to be one control either way. Embedded on a page, or in a popup
with buttons, it is the same `GUI.FORM.ADD.LIST` and the same `GUI.LIST.DRAW`.


## 1. The measurement that shapes everything

Bank 4 is full. Taken from `testing/XBASE.MAP` paired with `testing/XBASE.SRC.SYM`, by
the method in `docs/memory/measure-pcode-per-module.md` -- no experimental build:

| module in bank 4 | bytes |
|---|---:|
| `GUI.BANK.INC.BL` | 4,453 |
| `MENUVERT.BANK.INC.BL` | 1,100 |
| `MENUBAR.BANK.INC.BL` | 822 |
| `LINEINPUT.BANK.INC.BL` | 776 |
| `THEME.BANK.INC.BL` | 519 |
| `GUI2.BANK.INC.BL` | 386 |
| **total** | **8,056 of 8,192** |

**136 bytes free.** The `.Bnn` file size cannot tell you this any more -- bank 5 took
topmost when the menu text moved, so `XBASE.B04` reports 32 whole pages and nothing
truer. The map is the only honest source now.

`GUI.BANK.INC.BL` emits 4,453 bytes from 486 lines, so this dialect costs about
**9.2 bytes a line** of emitted code. The page engine below is roughly 90 lines:

| change | lines | bytes |
|---|---:|---:|
| `GUI.FORM.MAX` becomes a variable | 2 | 18 |
| per-control field text | 3 | 28 |
| per-field `MASK`, `ALLOW$`, `DENY$` | 6 | 55 |
| the slot tables and their `DIM`s | 12 | 110 |
| per-list state, and `GUI.LIST.AIM` | 25 | 230 |
| `GUI.FORM.MOVE.GRID` | 30 | 276 |
| `GUI.FORM.REPAINT` | 5 | 46 |
| four new verdicts routed in `GUI.FORM.ACT` | 8 | 74 |
| | **91** | **~840** |

So bank 4 needs about 840 bytes and has 136. **Roughly 700 must leave bank 4 before any
of this can be written.**

The cluster cannot be split sideways. `docs/memory/gp-banked-call-out-loses-the-bank.md`
is flat about it: a region may not call another region, and a shim leaves the callee's
bank selected, so the return lands under the wrong one. THEME, MENUVERT, MENUBAR,
LINEINPUT, GUI and GUI2 all call each other, so no pair of them can be pulled apart
into two banks.

**Region to low memory is fine**, though, as long as the low-memory routine leaves the
bank alone -- and low memory calling a region through a shim is the ordinary path every
program already uses. That is the seam. What leaves bank 4 moves *down*, not sideways,
and what moves down is whatever nothing else in bank 4 calls.

Verified: bank 4 calls nothing in `STRINGS`, `APPSYS`, `BANKMGR`, `KB` or `STASHVRAM`,
by `GOSUB` or by verb. Its only call out is `STASH`, which is in low memory already.


## 2. What is already page-ready, and needs no code

Worth writing down, because it is most of the job.

**The form engine barely knows about the box.** `GUI.FORM.*` reads `GUI.LEFT`,
`GUI.TOP`, `GUI.WIDTH` or `GUI.HEIGHT` in exactly two places, both the list footer:
`GUI.INC.BL:638` and `GUI.INC.BL:768`. Everything else that reads the box rectangle is
`GUI.OPEN`, `GUI.SIZE`, `GUI.SHADOW.FIT`, `GUI.SHADOW.DRAW` and `GUI.FRAME`, and a page
calls none of them.

**The footer is already optional.** `GUI.LIST.FOOT` opens with
`IF GUI.LIST.NOTEW = 0 THEN RETURN`. A page skips `GUI.LIST.MEASURE`, `NOTEW` stays 0,
and no footer is drawn. The junk value `GUI.LIST.NOTE.LEFT` picks up on the way past is
never read.

**Buttons already place themselves on a page.** `GUI.BUTTON.ROW` centres on
`GUI.INNER.LEFT` and `GUI.INNER.WIDTH`, which are plain globals rather than anything
derived at call time. A page sets the two to its own rectangle and the row lands in it.

**Several lists can share one item array.** `MENUVERT.ROW` draws
`MENUVERT.ITEM$(MENUVERT.SCROLL + MENUVERT.DRAWROW)`, so a base offset rides in for
free: set `MENUVERT.SCROLL` to base plus scroll at aim time, and list B reads its own
range of the one array.


## 3. Decisions taken

1. **Several lists on a page**, not one.
2. **No yield to the menu bar.** The page form is modal. It returns on a button or on
   ESC, and the program drives the bar itself between runs.
3. **More than two buttons.** `GUI.BUTTON.ROW` and its `GUI.BTN.ONE$` / `GUI.BTN.TWO$`
   pair stay for popups; a page calls `GUI.BUTTON` and `GUI.FORM.ADD.BUTTON` per button
   and places them itself.
4. **Grid navigation, taken from where the controls were added.** No declared rows and
   no declared columns: the engine already stores each control's X and Y, and that is
   the grid. TAB and SHIFT-TAB keep add order.
5. **Per-field `MASK`, `ALLOW$` and `DENY$`.**
6. **The programmer draws all chrome.** No `GUI.PAGE.OPEN`. The program does its own
   `GP.BOX` and `GP.FILL`, sets `GUI.INNER.LEFT`, `GUI.INNER.TOP` and `GUI.INNER.WIDTH`,
   and owns the screen.


## 4. Three defects this fixes on the way past

**A form with two fields is broken today.** `LINEINPUT.TEXT$` is a single global, and
`GUI.FORM.ADD.FIELD` writes `GUI.CTRL.TEXT$(n) = ""` and never reads it back. TAB from
field 1 to field 2 and field 2 shows field 1's text. Every popup has exactly one field,
so nothing has hit it yet. A page with five fields hits it on the first TAB.

**A list loses its place to any menu.** `GUI.FORM.ADD.LIST` aims MENUVERT once, with
the comment *"Nothing else moves it while a dialog is open."* On a page the menu bar is
something else, and `GUI2.INC.BL` already carries the warning: a scroll left behind
makes the next menu draw the rows above the ones it asked for. The rename in phase 4
removes the engine's dependence on `MENUVERT.SCROLL` surviving anything.

**`GUI.FORM.*` is bank-private.** No `GUI.FORM.*` or `GUI.LIST.*` label carries `.BODY`
in `GUI.BANK.INC.BL`, so only bank-4 code -- `GUI.INPUT`, `GUI.LISTBOX`, `GUI2` -- can
reach the form engine. A program in the shared image cannot call it at all.


## 5. The data model

`GUI.FORM.MAX` stops being a `#DEFINE` and becomes a variable, which is the pattern the
library already uses twice: `STR.MAX` with `STR.FIELD$`, and `SV.MAX` with `SV.PAGE%`.
`dim.asm:49` settles that this compiles -- `OutputIndexGroup` emits the subscripts as
expressions and `PCD_DIM` dimensions at run time, so a variable bound is legal.

    GUI.FORM.INIT:
        IF GUI.FORM.DIMMED <> 0 THEN RETURN
        IF GUI.FORM.MAX = 0 THEN GUI.FORM.MAX = 8
        DIM GUI.CTRL.TYPE%(GUI.FORM.MAX)
        ...

The program writes `GUI.FORM.MAX = 32` and that is the whole of it. No `#DEFINE`
ordering trap, no rebuild of the library, and nothing in the shared image.

**It must be set before the first GUI call of any kind.** `GUI.SAY` reaches
`GUI.FORM.BEGIN` reaches `GUI.FORM.INIT`, and `GUI.FORM.DIMMED` locks the size at
whatever the first caller found. A popup opened before the assignment leaves the program
on 8 for the rest of the run.

Fields and lists carry state buttons do not, and a control is never both, so **one index
array serves both tables**:

    GUI.CTRL.SLOT%(GUI.FORM.MAX)    field index or list index, by TYPE

    field table, DIM to GUI.FIELD.MAX, default 8
        GUI.FS.MASK%   GUI.FS.ALLOW$   GUI.FS.DENY$

    list table, DIM to GUI.LIST.MAX, default 2
        GUI.LS.SCROLL%  GUI.LS.ROWS%   GUI.LS.COUNT%
        GUI.LS.BASE%    GUI.LS.SEL%    GUI.LS.MARKED%
        GUI.LS.MARKP                   untyped, not %

`GUI.LS.MARKP` is the one untyped array. A `%` is a signed 16-bit integer, and a string
address above $7FFF reads back negative, which `PEEK` will not take. Six bytes an
element against two, on a table of three.

Per-control text needs no new array. `GUI.CTRL.TEXT$` is a button's label and is unused
for a field, so a field's value goes in the same slot.

Cost, at 2 bytes for a `%` element, 6 untyped, 3 for a string, and MAX+1 elements:

| | controls | field table | list table | total |
|---|---:|---:|---:|---:|
| today, MAX 8 | 135 | -- | -- | **135** |
| MAX 8 | 153 | 72 | 54 | **279** |
| MAX 32 | 561 | 72 | 54 | **687** |

**That comes out of run-side workspace, not the shared p-code headroom.** A page program
at MAX 32 pays 552 bytes more than today, in the space arrays live in.


## 6. Grid navigation

TAB and SHIFT-TAB are unchanged: add order, wrapping, skipping `GUI.CF.NOFOCUS`. That is
`GUI.FORM.MOVE` as it stands.

The arrows become geometric, against the X and Y already stored per control:

- **DOWN** takes the candidate with the smallest Y greater than mine. Ties go to the
  smallest difference in X, then to the lowest index.
- **UP** is the same with the largest Y less than mine.
- **RIGHT** takes the smallest X greater than mine **among controls with the same Y**.
- **LEFT** is the same with the largest X less than mine.
- **Arrows do not wrap.** No candidate means the focus does not move. TAB wraps; that is
  the difference between the two, and it is what CUA does.

Controls share a row when their Y is equal. Exactly equal -- a button a cell off its
neighbours is a row of its own, and that is easier to see on screen than a fuzzy match
is to reason about.

Four new verdicts, `GUI.NAV.UP`, `GUI.NAV.DOWN`, `GUI.NAV.LEFT` and `GUI.NAV.RIGHT`, and
`GUI.FORM.ACT` routes them to `GUI.FORM.MOVE.GRID`. What each control type emits:

| | LEFT and RIGHT | UP and DOWN |
|---|---|---|
| button | grid | grid |
| field | the cursor keeps them | grid |
| list | grid | the list keeps them |

Today a list drops LEFT and RIGHT into `GUI.FORM.ACCEL`. It still should when the grid
finds no candidate, or two lists side by side lose their accelerators.


## 7. The work, in order

**Phase 0 -- make room in bank 4.** Nothing else can start. Move the top-level dialogs
out of bank 4 into low memory: `GUI2` first (386 bytes, and nothing in bank 4 calls
`GUI.LISTBOX`), then `GUI.SAY`, `GUI.YN` and `GUI.MENU`. They call into bank 4 through
the existing shims, which is the ordinary direction. Target is 700 bytes freed; measure
with the map rather than guessing, and stop when it is enough.

This costs the same bytes in shared p-code, which is affordable now -- 14,400 used,
3,520 of headroom -- and phase 6 buys them back several times over.

**Phase 1 -- `GUI.FORM.MAX` as a variable.** Two lines. Independent of everything else,
so it can land and be measured on its own.

**Phase 2 -- the slot tables.** `GUI.CTRL.SLOT%` and the two tables, `DIM`med in
`GUI.FORM.INIT`, allocated in `ADD.FIELD` and `ADD.LIST`, reset in `GUI.FORM.BEGIN`.

**Phase 3 -- per-field text, mask and filters.** `ADD.FIELD` saves them into the slot,
`GUI.FORM.DO.FIELD` loads before `LINEINPUT.GET` and saves after, `GUI.FIELD.DRAW` loads
before `LINEINPUT.RENDER`. Three routines, and it fixes the two-field defect for popups
at the same time.

**Phase 4 -- per-list state.** `MENUVERT.SCROLL` stops being the engine's scroll.
`GUI.LIST.SCROLL` takes over inside `GUI.INC.BL` -- about eight sites, a mechanical
rename -- and a new `GUI.LIST.AIM` sets the whole MENUVERT block from the focused slot,
including `MENUVERT.SCROLL = GUI.LS.BASE%(s) + GUI.LIST.SCROLL`. `GUI.LIST.DRAW` and
`GUI.FORM.ADD.LIST` both call it. The engine's own arithmetic stays base-free, and
nothing it does survives a menu opening over the top of it any more.

**Phase 5 -- grid navigation**, per section 6, plus `GUI.FORM.REPAINT` so a program that
refills a list can redraw the whole form.

**Phase 6 -- a second region, and the low RAM back.** XBase runs one region while
`GPB-MODS-TESTING` runs three. Sitting in low memory and eligible to bank:

| module | bytes |
|---|---:|
| `DB.INC.BL` | 2,726 |
| `STASHVRAM.INC.BL` | 1,677 |
| `STASHVRAMGC.INC.BL` | 635 |
| `BANKMGR.INC.BL` | 570 |
| `STRINGS.INC.BL` | 507 |
| `DBFILE.INC.BL` | 369 |
| `APPSYS.INC.BL` | 110 |
| `KB.INC.BL` | 24 |
| | **6,618** |

`STASH.INC.BL` (433) cannot go: it holds `BANK` statements, which is the one and only
disqualifier. `DBFORM.INC.BL` (503) calls the GUI, so banking it would be region to
region -- it stays in low memory or it joins bank 4, and bank 4 has no room.

Less the new shim file, this is several thousand bytes of low RAM, against the 3,520 of
headroom there is today. It is the phase that makes the rest cheap, and it is worth
doing whether or not the page form is ever written.


## 8. The new file

    LIB.GUIPAGE.INC.BL      unbanked, eight shims, roughly 80 bytes of shared p-code

        GUI.FORM.BEGIN
        GUI.FORM.ADD.FIELD
        GUI.FORM.ADD.LIST
        GUI.FORM.ADD.BUTTON
        GUI.FORM.RUN
        GUI.FORM.REPAINT
        GUI.BUTTON
        GUI.BUTTON.WIDE

Included only by a program that builds pages. A popup-only program leaves it out and
pays nothing -- and this is the only thing it avoids paying, because everything else in
this plan is an edit to a routine that already exists.

`SHIM.GUIBANK.INC.BL` must be included above it: that is where `#DEFINE SHIM.GUIBANK 4`
lives, and BASLOAD substitutes a definition where it stands.

There is no `GUIPAGE.BANK.INC.BL`. Nothing new wants to live in a bank, and if a page
helper ever does it belongs in `GUI.BANK.INC.BL` beside the engine it calls.

The eight labels gain `.BODY` in the banked twin. The unbanked twin keeps its plain
names, as it does for every other module.

The `GUI.CTRL.*` arrays stay readable from the shared image without a shim -- arrays
live in the workspace, not in the bank -- so a program reads `GUI.FORM.HIT` and
`GUI.CTRL.FLAGS%()` after a run exactly as `GUI.INPUT` does today.


## 9. Not in scope

- No `GUI.PAGE.OPEN`, no page chrome, no page stash. Decision 6.
- No yielding to the menu bar from inside a form. Decision 2.
- Nothing propagates to `GPC-BASIC/` or `samples/GPB-MODS-TESTING/GPC-BASIC/` until
  XBase has run it. Those copies still carry the old button colours and the old static
  default marker as it is.


## 10. What could still bite

**Phase 0 is a real refactor, not a preliminary.** Moving four dialogs out of a bank is
the sort of change that finds a call nobody remembered. It wants its own build and its
own run before phase 1 starts.

**`GUI.FORM.MAX` as a variable costs a few bytes in four bounds tests** that are
constants today. Bank 4, not shared, and it is inside the 840 above -- but it lands in
the bank that has no room, so phase 1 goes in after phase 0, not before.

**The list table default of 2 is a guess.** Three lists on one page is not absurd. It is
one variable, `GUI.LIST.MAX`, set the way `GUI.FORM.MAX` is.

**Bank 5 is the menu text pool, and `DBBANK.INC.BL` reserves 5 and 6 for the DB engine.**
A second region in phase 6 needs a bank the compiler leaves alone, and 5 and 6 were the
only two known to be free. Whichever of the three lands last renumbers.
