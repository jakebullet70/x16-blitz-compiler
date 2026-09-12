# GUI refactor — a CUA focus model

**Phases 1 and 2 are built. Phases 3, 4 and 5 are still plan.** §8's questions have been
answered by building them rather than by argument; the answers are written back into §8.

The dialogs in `GUI.INC.BL` and `GUI2.INC.BL` each own a private key loop. They agree on how a box
is drawn and on nothing else: `GUI.INPUT` throws TAB away, `GUI.YN` has no focus at all, and
`GUI.LISTBOX` answers with a footer hint rather than buttons. This plan replaces the four private
loops with one, and gives every control a focus.

## 0. What is decided

Five answers, settled 2026-09-09, that the rest of this file assumes.

| | decision |
|---|---|
| **Focus model** | Full CUA. Every control is focusable; TAB and Shift-TAB cycle; a focused button is drawn differently from the default button, because CUA has both and they move independently |
| **Structure** | `GUI.FORM` — a control list plus one dispatcher. `GUI.SAY` / `GUI.YN` / `GUI.INPUT` / `GUI.LISTBOX` become thin wrappers that fill the list |
| **Accelerators** | Bare letter, live only when the focused control does not eat printable keys. No ALT |
| **GPBMODS' bank budget** | Not a design input. It is a demo that loads every module at once; a real application does not |
| **Banking** | **One bank holds the GUI and everything it calls**, and a routine is duplicated into it rather than called across a boundary |

Six more, settled the same day when the plan was read back and the holes found:

| | decision |
|---|---|
| **`MENUBAR`** | Joins the GUI bank. It calls `MENUVERT.ROW`, so it had no choice |
| **Regions** | **Three**, not two. `FILEDIR` gets its own, which is what pays for `MENUBAR` joining |
| **The keyboard drain** | `GUI.FORM` gets a **private** one under its own name. Not a copy of a call that exists |
| **`GUI.LISTBOX`** | Keeps its own scroller and its multi-select. It becomes a control; it is not replaced by `MENUVERT.RUN` |
| **`GUI.FORM.INIT`** | Called by `GUI.FORM.RUN` behind a flag, never by an application |
| **Accelerators in `GUI.INPUT`** | Marked but inert until the field loses focus. Accepted |

## 1. The GUI bank

`GP.BANKED SHIM.GUIBANK` holds the whole user interface and its supporting code:

    THEME  LINEINPUT  MENUVERT  MENUBAR  GUI  GUI2  GUI.FORM

plus a **private** keyboard drain, `GUI.CLEARKB`, at about 30 bytes.

**Why duplication is the right answer here and not laziness.** A region cannot call another bank and
survive the return
([`docs/memory/gp-banked-call-out-loses-the-bank.md`](../../docs/memory/gp-banked-call-out-loses-the-bank.md)),
so today every cross-module call inside the GUI goes out to a low-memory shim that re-selects the
bank and comes back. That works only because the caller and the callee happen to be in the *same*
bank; the moment one of them moves, the call is a silent wrong-bank jump rather than an error. A
self-contained bank makes the shims unnecessary for internal calls, and makes the failure impossible
instead of merely absent. Thirty bytes is a good price.

The shims stay for the **public** entries — an application in low RAM still reaches `GUI.YN` through
`LIBBANK.INC.BL`. What goes away is the GUI calling *itself* through low memory.

**`MENUBAR` is in the bank because it has to be.** [`MENUBAR.INC.BL:222`](GPC-BASIC/MENUBAR.INC.BL)
does `GOSUB MENUVERT.ROW` to paint the bar, so `MENUBAR` and `MENUVERT` cannot be split across two
regions at all — the compiler refuses the call. Duplicating `MENUVERT.ROW` was the alternative and it
is far more than thirty bytes. `MENUBAR` being the application's frame rather than a dialog control
is a true statement about what it is for, and it does not survive contact with what it calls.

It is the **only** such call in the set. `FILEDIR` is self-contained, and `LINEINPUT` and `THEME`
call nothing outside themselves, so `FILEDIR` can be moved anywhere without touching a line of it.

**`GUI.CLEARKB` is a new routine, not a duplicated call.** `KB.INC.BL` exists but `GPBMODS.BASL` does
not include it, and nothing in the tree calls `KB.CLEARKB` — so there is no existing call to
duplicate, and the "a fix has to land twice" cost is not being paid yet. It also cannot be got by
including `KB.INC.BL` a second time: the file guards itself with `#IFNDEF KB.DEFS`, so a second
`#INCLUDE` produces nothing. The drain is written out inside the GUI bank under its own label.
`KB.INC.BL` stays the public one for an application in low RAM. Each header names the other.

## 1a. Three regions

`FILEDIR` moves out on its own:

    GP.BANKED SHIM.UTILBANK    APPSYS BANKMGR STRCASE STRINGS STRUSING SORT STASHVRAM
    GP.BANKED SHIM.GUIBANK     THEME LINEINPUT MENUVERT MENUBAR GUI GUI2 GUI.FORM GUI.CLEARKB
    GP.BANKED SHIM.FUTILBANK   FILEIO FILEDIR

It ended up as five, not three. THEME and COMBO each took one of their own once
the GUI region reached the 8K a region may hold:

    GP.BANKED SHIM.UTILBANK    7   APPSYS BANKMGR KB STRCASE STRINGS STRUSING SORT
                                   STASHVRAM STASHVRAMGC
    GP.BANKED SHIM.GUIBANK     4   LINEINPUT MENUVERT MENUBAR GUI GUI2
    GP.BANKED SHIM.FUTILBANK   8   FILEIO FILEDIR
    GP.BANKED SHIM.THEMEBANK   9   THEME
    GP.BANKED SHIM.COMBOBANK  10   COMBO

Two regions was a habit, not a limit: `GPBANK_MAXREGIONS = 63` in
[`source/compiler/source/commands/gpbank.asm`](../../source/compiler/source/commands/gpbank.asm) —
every bank a 512K X16 has, bank 0 being the KERNAL's. Every region gets its own `.Bnn` overlay file
([`docs/memory/region-overlay-ovl-file.md`](../../docs/memory/region-overlay-ovl-file.md)), so a
third costs one more file and one more `BANKMGR.CLAIM`.

Nothing has ever been built with three, so phase 1 confirms it rather than assuming it — see §8. It
is expected to work, and the arithmetic needs it: bank 4 holds 7,424 bytes today, `MENUBAR` is
joining and `GUI.FORM` is new, so `FILEDIR` leaving is not a tidy-up, it is the space.

## 2. The control block

Parallel arrays — one index is one control, and each array holds one of its attributes. BASIC has no
record type; this is how a record is spelled.

    GUI.CTRL.N          how many controls, 1..N
    GUI.CTRL.TYPE(n)    1 button, 2 field, 3 list
    GUI.CTRL.X(n)       where it starts
    GUI.CTRL.Y(n)
    GUI.CTRL.W(n)       how wide it is drawn
    GUI.CTRL.TEXT$(n)   a button's label, with its "&"; unused by the others
    GUI.CTRL.KEY(n)     the accelerator's code, 0 if the label marked none
    GUI.CTRL.FLAGS(n)   1 = the default button, 2 = takes no focus
    GUI.FOCUS           which one has it, 1..N
    GUI.FORM.HIT        which one ended the form. 0 is a cancel
    GUI.FORM.KEY        the key that ended it

`GUI.INPUT` fills three of them:

     n  TYPE  X   Y   W  TEXT$      KEY  FLAGS
     1   2    12   4  20  ""          0    0     the field
     2   1    12   6   8  "&OK"      79    1     the default button
     3   1    22   6  12  "&CANCEL"  67    0

`GUI.FOCUS` is an index into that, and so is `GUI.FORM.HIT` on the way out — which is how a wrapper
learns what happened without the dispatcher knowing what a dialog is.

`%` arrays for the numbers — two bytes an element against six for an untyped one
([`docs/memory/array-element-sizes-measured.md`](../../docs/memory/array-element-sizes-measured.md)).
Eight controls is a generous ceiling for a dialog and costs well under 200 bytes all told.

**`GUI.FORM.INIT` runs once for the whole program.** `DIM` cannot run twice on the same array, so it
sets `GUI.FORM.DIMMED` and returns immediately when that is already set. `GUI.FORM.RUN` calls it on
the way in, so no application ever does, and §6's promise that the wrappers keep their interfaces
holds without a new call in every caller. What resets per dialog is `GUI.CTRL.N`, not the arrays.

**The default and the focus are two different things**, which is the point of the model: `FLAGS`
bit 0 says which button RETURN presses when focus is somewhere that does not want RETURN for
itself, and `GUI.FOCUS` says where the eye is. They start on the same control and separate the
moment you press TAB.

## 3. The dispatcher

One loop, and the reason it stays small is that the three control types do not each get their own
navigation logic — they translate a key into the **same six verdicts** and hand it back:

    GUI.FORM.NAV   0 stay      the control consumed the key
                   1 next      TAB, and the arrows that mean forward
                   2 prev      Shift-TAB, and the arrows that mean back
                   3 press     the focused control
                   4 default   the default button, wherever focus is
                   5 cancel    ESC or STOP

    GUI.FORM.RUN.BODY:
        GOSUB GUI.FORM.INIT
        GOSUB GUI.FORM.DRAW
    GUI.FORM.LOOP:
        GOSUB GUI.FORM.STEP
        IF GUI.FORM.DONE = 0 THEN GOTO GUI.FORM.LOOP
        RETURN

    GUI.FORM.STEP:
        GP.SELECT GUI.CTRL.TYPE(GUI.FOCUS)
            GP.CASE 2 : GOSUB GUI.FORM.DO.FIELD
            GP.CASE 3 : GOSUB GUI.FORM.DO.LIST
            GP.OTHER  : GOSUB GUI.FORM.DO.BUTTON
        GP.ENDSEL
        GOSUB GUI.FORM.ACT
        RETURN

`GUI.FORM.ACT` is where the movement is written, once. `GUI.FORM.MOVE` skips any control whose
`FLAGS` bit 1 is set, and wraps at both ends.

The three translators, and what each already gives us:

- **`DO.FIELD`** calls `LINEINPUT.GET` and reads `LINEINPUT.KEY`. This is nearly free: `LINEINPUT`
  already exits on TAB (9), UP (145) and DOWN (17) **keeping its text**, and its own header says
  *"a form is a loop: call the field, look at `LINEINPUT.KEY`, move the focus."* It was written for
  this and has been waiting. TAB and DOWN → next, UP → prev, RETURN → default, ESC → cancel.
- **`DO.LIST`** calls the listbox's **own** scroller, not `MENUVERT.RUN`. `GUI.LISTBOX` today drives
  `MENUVERT.ROW` a row at a time and owns everything above it — the scroll (`.FOLLOW`, `.REPAINT`,
  `.PAINT.ROW`) and the multi-select marks (`GUI.LISTBOX.MARKS$`, `.MARKED`, `.MULTI`, `.TOGGLE`)
  that `MENUVERT` has no equivalent for. Handing the list to `MENUVERT.RUN` would delete multi-select
  to buy nothing. So the existing loop is cut in half instead: the half that paints and scrolls stays
  exactly as it is, and the half that decides when it is finished returns a verdict. Arrows and SPACE
  stay inside the list; TAB → next, Shift-TAB → prev, RETURN → default, ESC → cancel.
- **`DO.BUTTON`** is the only genuinely new key loop. TAB and RIGHT → next, LEFT → prev, RETURN and
  SPACE → press, ESC → cancel, anything else → scan `GUI.CTRL.KEY()` for an accelerator.

## 4. Focus rendering — shape is the default, colour is the focus

The two states are independent, so they need two independent cues. Both already exist:

| state | button |
|---|---|
| plain | `< OK >` in `GUI.BTN.ATTR` |
| the default | `<<OK>>` — the doubled bracket, built 2026-09-09 |
| focused | drawn in `THEME.FOCUS` |
| both | `<<OK>>` in `THEME.FOCUS` |

The doubling takes the padding space rather than a new cell, so a default button is exactly as wide
as a plain one and no width anywhere has to know which is which. Colour on top of it is orthogonal
and costs no cells at all. **This is why the earlier colour-only default failed and this will not:**
one cue was carrying two meanings, in the accelerator's own colour, on buttons that all had
brackets already.

**`THEME.FOCUS` is a role of its own, and `THEME.HILITE` could not do the job.** This was
tried first, as §8 asked, and the first build drew a focused button identical to an unfocused
one — because `HILITE` is the text colour reversed in three of the four palettes, and a plain
button is *already* the panel reversed. Slot 7 was free and already inside `DIM THEME.CLR`, so
the role cost four palette lines and no memory. It is yellow-backed in every theme, because
nothing else in any of them is.

The marked letter needed a second answer with it: `WARN`'s foreground is light green, and light
green on yellow is legible in the palette and invisible on the screen. On a focused button the
mark is the button's own two colours **swapped** for that one cell — guaranteed to contrast,
whatever a palette does.

A **field** shows focus with the cursor `LINEINPUT` already blinks. Unfocused it needs a static
paint — `GUI.FIELD.DRAW`, text and frame, no cursor, no loop — which does not exist yet and is the
one genuinely new drawing routine.

A **list** shows focus with its selection bar in `MENUVERT.HIATTR`; unfocused, the bar drops to a
dimmer attribute so the current row is still readable but plainly not live. The marks of a
multi-select list are drawn the same either way — a mark is a fact about the row, not about focus.

## 5. Accelerators

`&OK` answers to O and o, as now. The rule that makes it safe:

> An accelerator is live only while the focused control does not consume printable keys.

Fields consume them, and so do lists, because `MENUVERT.HOTKEY` already claims the first letter of
every row. Buttons do not. So accelerators work while focus is on the button row and are off
elsewhere — one sentence, and it resolves the field collision and the list collision with the same
words.

**What this buys:** `GUI.INPUT` can finally label its buttons `&OK` and `&CANCEL`. It carries no `&`
today, and its comment says why — *"every printable key belongs to the field, so an O could not close
the dialog."* Under the focus rule that stops being true.

**Marked but inert on open, and that is accepted.** `GUI.INPUT` opens with focus in the field, so at
the moment the dialog appears the O of `&OK` is already marked and pressing O types an O. The
accelerator wakes when the field loses focus. The alternative — marking the letter only while the
button row has focus — makes the mark honest but repaints both buttons on every TAB, and teaches the
mark as a focus cue when it is a key cue. Mark constantly, act only on the buttons.

**What it costs beyond that:** an accelerator does not work from inside a field, where CUA's
ALT+letter would. ALT is not available cheaply — in ISO mode the X16 sends nothing for ALT+letter,
and it needs the keymap table at `$A000` bank 0 rewritten
([`docs/memory/gpc-editor-alt-keys-need-the-keymap.md`](../../docs/memory/gpc-editor-alt-keys-need-the-keymap.md)),
which is bank-0 surgery underneath an open dialog. Not in this refactor.

## 6. What happens to each dialog

| dialog | becomes | interface |
|---|---|---|
| `GUI.SAY` | one button | unchanged |
| `GUI.YN` | two buttons | unchanged; `GUI.DEFAULT` still picks which |
| `GUI.INPUT` | field + two buttons | unchanged, and its buttons gain accelerators |
| `GUI.LISTBOX` | list + two buttons | gains a real button row in place of the footer hint; multi-select kept as it is |
| `GUI.MENU` | **left alone** | it is a menu, not a form — one control, no buttons, nothing to TAB to |

The wrappers keep their existing inputs and outputs. Nothing forces that —
[`docs/memory/no-backward-compatibility-needed.md`](../../docs/memory/no-backward-compatibility-needed.md)
says a break costs nothing — but `GPBMODS`, `samples/editor` and the two `.EXP.BL` examples all call
these, and a refactor that also rewrites every call site cannot be bisected when it goes wrong.

## 7. Phases

Each phase ends in a build and a screenshot. None of them leaves the demo unrunnable.

1. **DONE — the banks, first and alone.** Three regions: `FILEDIR` out on its own, `THEME` / `LINEINPUT` /
   `MENUVERT` / `MENUBAR` / `GUI` / `GUI2` into `SHIM.GUIBANK`, `GUI.CLEARKB` written. No behaviour
   changes at all. This is the phase most likely to break in a way that is hard to read, so it gets a
   build to itself and the BANK MAP panel is the check.
2. **DONE — the control block and the dispatcher, on buttons only.** `GUI.SAY` and `GUI.YN` rebuilt on
   `GUI.FORM`. Visible change: TAB moves between YES and NO. The two simplest dialogs prove the
   dispatcher before a field or a list is involved.
3. **DONE -- the field.** `GUI.INPUT` rebuilt; `GUI.FIELD.DRAW` written; accelerators returned to
   its buttons. `GUIFRMT` grew to fifteen assertions and all fifteen pass. This is the phase the
   screenshot that started this asks for.
4. **DONE — the list.** `GUI.CT.LIST` got its two routines and its two arms, and the
   scrolling list moved out of `GUI2` and in beside the field: `GUI.FORM.ADD.LIST`,
   `GUI.LIST.DRAW`, `GUI.FORM.DO.LIST`. What is left in `GUI2` is the dialog around it. The hint
   row naming ENTER and ESC became a real `<<OK>> <CANCEL>` row. `GUIFRMT` grew to twenty-four
   assertions and all twenty-four pass, multi-select included.
5. **Demo panels, `GP-BASIC.GLOBALS.md`, and the help text.** Including the rows already owed for
   `GUI.MSG3$`, `GUI.DEFAULT`, `GUI.BTN.DEF` and the `GUI.BTN.*` set.

## 8. To verify before building, not assumed

- **Does a third region build? YES.** `GPBMODS` writes five overlays, `.B04` to `.B08`, and
  `FILEIO` + `FILEDIR` live in `SHIM.FUTILBANK` at bank 8. The build that proved it also found the
  compiler's 37,632-byte object ceiling, fixed in `58c635b`.
- **Does the X16 send a distinct code for Shift+TAB? STILL OPEN, and no longer blocking.** The
  Editor's own key table gives `$18`, and `GUI.FORM.DO.BUTTON` treats 24 as PREV — `GUIFRMT`'s T4
  proves the dispatcher handles the code, and proves nothing about what a keyboard sends, because
  `kbdbuf_put` sets no modifiers. LEFT and UP also mean PREV, so reverse navigation works either
  way. **This one needs a human at a real keyboard**; it is a three-line `GET` program.
- **Does the listbox's scroller survive being one control among several? YES, and it needed no
  arbitration.** It only ever writes inside `GUI.INNER` and the bottom frame edge, and nothing else
  on the form touches those cells. The one real coupling is `MENUVERT.SCROLL`, which is global and
  which `MENUBAR` aims sideways — so whoever runs the form still puts it back to 0 on the
  way out. The move cost no new dependency either: `GUI.INC.BL` already required `MENUVERT` for
  `GUI.MENU`, and the editor and GPC-HELP — the two programs that include `GUI` without
  `GUI2` — already include `MENUVERT` as well.
- **Does `THEME` need a slot for "focused"? YES, and `THEME.HILITE` was not enough.** Not because
  a palette made it unreadable — because it made it *identical*. See §4. The fear that a role
  touches every module was misplaced: only the GUI reads this one, so it is four palette lines,
  two `#DEFINE`s and one row in `GPBMODS`' theme panel.
- **What is actually in `SHIM.GUIBANK`? MEASURED, and it is tighter than the plan assumed.**

  | | `GPBMODS.B04` | pages | `GUIFRMT.B04` |
  |---|---:|---:|---:|
  | after phase 1 | 7,170 | 28 | —— |
  | after phase 2 | 7,682 | 30 | —— |
  | after phase 3 | 7,938 | 31 | 7,854 |
  | after phase 4 | 8,194 | 32 | 8,035 |

  **READ THE `GUIFRMT` COLUMN, NOT THE `GPBMODS` ONE.** A region that is not the topmost is padded
  to a whole page, and `GPBMODS` has five, so its `.B04` only ever reports a PAGE COUNT: every
  figure in that column is a multiple of 256 and says nothing about the bytes inside the last page.
  `GUIFRMT` has one region, is not padded, and holds the same six modules — so it is the
  one that measures. That also retires the "`GUIFRMT` builds it 84 bytes smaller" line that used to
  sit here: the two builds are the same region byte for byte, and the 84 was the padding.

  So, minus the 2-byte load address, **the region is 8,033 bytes and the ceiling is 8,188** —
  `gpbank.asm:582` refuses a 33rd page, and the four bytes of bridges are counted into it.
  **155 bytes free**, and phase 5 adds no code to this bank. The list cost 181 bytes, measured. The
  earlier phases were only ever measured to the page, so the "each phase takes half the room"
  reading of them was the padding talking, and there is more room here than that predicted. If
  something does have to move out, the next one is `MENUBAR` — but it cannot go alone,
  see §1.

## 9. What this does not do

- No ALT accelerators. See §5.
- No mouse. Nothing in the library reads one today.
- No multi-field forms as a public feature. The control block makes them possible and phase 3 will
  prove the machinery, but no dialog in this plan has two fields, and a `GUI.FORM` that callers fill
  in themselves is a separate decision with its own documentation cost.
- No change to `GUI.OPEN` / `GUI.CLOSE` / `GUI.SIZE` / the shadow. The box is not what is wrong.
