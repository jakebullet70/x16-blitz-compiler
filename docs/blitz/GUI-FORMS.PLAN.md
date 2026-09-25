# GUI forms -- dBASE `@ SAY ... GET ... READ`, on a page or in a popup

Two separate pieces of work that share a spelling:

1. **The canned dialogs become one-liners.** `GUI.SAY`, `GUI.YN`, `GUI.MENU`,
   `GUI.INPUT`, `GUI.LISTBOX` and `FILEPICK.RUN` each get a `GP.DEFPROC` verb.
   Nothing inside them changes.
2. **A page form**, built the way dBASE II / III+ and Clipper built one: a line
   per field, then one call that runs the lot.

The two are independent. (1) can ship without (2).

---

## 1. Why this is being done

The library is driven by sticky globals. A call site sets some of roughly
twenty-two variables across five namespaces -- `GUI.`, `CHECK.`, `COMBO.`,
`MENUVERT.`, `LINEINPUT.` -- and the ones it does not set carry over from the
last call. `GPBMODS.BASL` carries `GMX.D.RESET`, eight lines clearing all
twenty-two, written in the application because the library does not offer it,
and every dialog call site calls it first.

So a dialog call is a paragraph of assignments with a `GOSUB` at the end, and
nothing in that paragraph says which assignments were required.

`GP.DEFPROC` is already the house answer -- `FILEIO`, `STRINGS`, `STRCASE` all
carry verbs, and the p-code is the assignments and the `GOSUB` written out by
hand, so a compiled program pays nothing over the long spelling.

---

## 2. The rule that makes the one-liners work

**A verb resets the optional globals itself.** `GMX.D.RESET` moves out of the
application and into `GUI.INC.BL` as `GUI.DEFAULTS`, and every dialog verb calls
it before assigning its formals. Sticky-by-default becomes clean-by-default.

Without that rule, a one-liner silently inherits the previous dialog's title,
shadow and placement, which trades a visible mess for an invisible one.

Two verbs per dialog: a short one for the common case, a wide one taking
everything. No pending state, no modifier verbs, nothing hidden.

### 2.1 The dialog verbs

| verb | wraps | call | reads back |
|---|---|---|---|
| `MSGBOX` | `GUI.SAY` | `GP.SUB MSGBOX, "DISK FULL"` | `GUI.KEY` |
| `MSGBOXEX` | `GUI.SAY` | `GP.SUB MSGBOXEX, title$, m$, m2$, m3$, btn$` | `GUI.KEY` |
| `ASKYN` | `GUI.YN` | `IF GP.FN(ASKYN, "DELETE IT?") THEN` | `GUI.ANSWER` |
| `ASKOK` | `GUI.YN`, okcancel | `IF GP.FN(ASKOK, "PROCEED?") THEN` | `GUI.ANSWER` |
| `ASKYNEX` | `GUI.YN` | `GP.FN(ASKYNEX, title$, m$, m2$, dflt, okc)` | `GUI.ANSWER` |
| `ASKTEXT` | `GUI.INPUT` | `F$ = GP.FN(ASKTEXT, "FILE NAME?", 16)` | `GUI.TEXT$`, `""` = cancelled |
| `INPUTBOX` | `GUI.INPUT` | `GP.FN(INPUTBOX, prompt$, start$, len)` | `GUI.TEXT$`, test `GUI.OK` |
| `INPUTBOXEX` | `GUI.INPUT` | `+ title$, mask` | `GUI.TEXT$` |
| `PICKMENU` | `GUI.MENU` | `N = GP.FN(PICKMENU, msg$, count, sel)` | `GUI.SEL`, 0 = cancelled |
| `LISTBOX` | `GUI.LISTBOX` | `N = GP.FN(LISTBOX, msg$, count, rows)` | `GUI.LISTBOX.SEL` |
| `LISTBOXM` | `GUI.LISTBOX` multi | `N = GP.FN(LISTBOXM, msg$, count, rows)` | `.MARKED`, `.MARKS$` |
| `PICKFILE` | `FILEPICK.RUN` | `F$ = GP.FN(PICKFILE, "BASL,BL", bank)` | `FILEPICK.NAME$`, `""` = none |
| `ASKLINE` | `LINEINPUT.ASK` | `T$ = GP.FN(ASKLINE, x, y, "NAME: ", 16)` | `LINEINPUT.TEXT$` |
| `DLGRESET` | new | `GP.SUB DLGRESET, bank` | -- |
| `KBCLEAR` | `GUI.CLEARKB` | `GP.SUB KBCLEAR` | -- |

`ASKTEXT` answering `""` on cancel is deliberate: it matches `FILEPICK`'s
existing "empty means no file", and it is what makes the call one line.
`INPUTBOX` is the honest version for a form where `""` is a legal answer.

`PICKMENU` and `LISTBOX` still need `MENUVERT.ITEM$()` filled first. An array
cannot be a formal, so the fill stays; the verb removes the geometry and the
reset.

---

## 3. The form model

dBASE:

```
@ 2, 1 SAY "First name" GET m->fname   PICTURE "@!" VALID .NOT. EMPTY(m->fname)
@ 3, 1 SAY "Retired"    GET m->retired PICTURE "Y"
READ
```

Six properties, and five of them map straight onto what is already here:

1. **One line is one field** -- the label and the input together.
2. **`@ ... GET` appends to a pending list** (Clipper's `GetList`), `READ`
   activates it, `CLEAR GETS` empties it. That is `GUI.FORM.BEGIN` /
   `GUI.FORM.ADD.*` / `GUI.FORM.RUN` already. The architecture is right; only
   the spelling is wrong.
3. **Absolute coordinates, painted immediately.** `@ SAY` printed as it
   executed; `READ` only ran the GETs. The box was a separate `@ 1,1 TO 10,40`
   that the GETs knew nothing about.
4. **`GET` binds by reference** -- the variable is loaded into the field and
   written back when READ ends.
5. **`PICTURE`** carried type, mask and case in one string.
6. **ESC aborts the whole READ** and leaves every variable untouched.

### 3.1 What BASIC cannot do, and the stand-in

Property 4 is the only real gap. Clipper did it with a code block,
`{|x| iif(x==NIL, var, var:=x)}` -- a getter/setter pair handed to the form.
BASIC has neither references nor closures.

**A KV key is the same indirection.** A control stores an eight-character key;
the form reads through it and writes back through it.

KV sits at the **edges**, not in the loop:

* `FORMREAD` starts -- one read per bound control, into the slot's value field
* editing happens in the store
* OK -- values are already in the store, and are what the caller reads back
* ESC -- the store is rolled back from the snapshot taken at `FORMREAD`

The key is **optional**. Pass `""` and the value is read back by control number
with `FORMGET` instead. That keeps the form module from hard-depending on the
KV copy.

### 3.2 Decided against

* **`PICTURE`** -- with `INPUTLINE` / `CHECKBOX` / `DROPDOWN` as separate verbs
  it is not needed for type, and `STRCASE` and `STRUSING` already exist for case
  and masks. Record bytes reserved, not built.
* **`VALID`** -- Clipper's is a code block per field. BASIC has no indirect
  `GOSUB`, so the honest version is one hook for the whole form with
  `ON n GOSUB`. Not built. `LINEINPUT.ALLOW$` / `LINEINPUT.DENY$` do the work
  instead, named per field but shared -- see 5.1.

---

## 4. Coordinates

**Absolute, 1,1 at the top left, and the page does not scroll.**

That is dBASE's model and it removes the hardest problem in the design. A
builder that measures its own box would have to collect every control, measure,
open the box, *then* paint -- because the frame is stashed and cannot grow once
drawn. Absolute coordinates mean controls paint as they are added and nothing
is deferred.

Not scrolling buys three more things: the row and column in the record are the
final screen cells, the form loop never has to scroll a control into view before
giving it the focus, and `GUI.SCREEN.COLS` / `GUI.SCREEN.ROWS` are already read
from `GUI.SCRMODE`, so an off-screen control can be refused at the line that
wrote it.

**The box offset is applied once, not per line.** `PAGE` sets the origin to
1,1; `POPUP` opens a box and sets the origin to its inner top-left. Every field
line in between is identical either way.

`POPUP` takes its width and height, because nothing is measuring for it. That is
the price of painting as you go, and it is the price dBASE paid too.

---

## 5. The store -- one slot is one control and one bound variable

A copy of `KV.INC.BL`, renamed. KV's geometry is kept exactly: base `$A000`,
128 bytes a slot, 64 slots, which is 8,192 and so one whole bank. Slot 0 is the
header, leaving **63 controls**.

The first 88 bytes are byte-for-byte KV's existing layout, so `KV.FIND`,
`KV.SCAN`, `KV.FREE`, `KV.READ.KEY` and `KV.CHECK` come across unchanged. The
form fields are an extension into the bytes KV was not using -- its value ran to
119 and ours stops at 79.

```
+0..7      key, space padded. $00 at +0 is a free slot     | KV, unchanged
+8         value length                                     | KV, unchanged
+9..87     value, 79 bytes                                  | KV's field, shortened
---------------------------------------------------------- the extension
+88        control type      GUI.CT.FIELD, .CHECK, .COMBO, .BUTTON, .LIST
+89        row               absolute screen cell
+90        column            the FIELD's column, label width already added
+91        field width
+92        flags             GUI.CF.DEFAULT / .NOFOCUS / .CHECKED
+93        accelerator key   0 for none
+94        aux               combo item count, or its index in the item store
+95        maximum length    distinct from +8, which is what is in there now
+96        filter set        an index into FORM.FILTER$(). 0 is no filter
+97        case              FORM.C.ASIS / .UPPER / .LOWER / .PROPER
+98..127   spare, 30 bytes
```

The label is **not** stored. It is drawn once at ADD time and the screen holds
it from then on -- see section 6.

### 5.1 Filters are shared by index. Case is not a filter

An earlier draft gave each slot its own `ALLOW$` and `DENY$`, 11 characters
each in bytes +104..127. That was wrong twice over: 24 bytes a slot is 1,512 of
the bank spent on something most fields do not use, and **11 characters is not
enough** -- `"ABCDEFGHIJKLMNOPQRSTUVWXYZ "` is 27.

Filters are shared instead. One byte at +96 indexes `FORM.FILTER$()`, a small
string array the caller DIMs and the module pre-fills with the standard sets.
Fields that want the same rule name the same index. Any length, 1 byte a slot
rather than 24, and 23 bytes handed back to the spare area.

**An index, not a pointer.** A `GP.STRPTR` in the record would be two bytes and
would look like the same idea, but the runtime marks a block dead when the
variable stops referencing it and `StringConcrete`'s scavenger hands that block
out again. Blocks are not moved, so a filter string assigned once and never
touched would in fact survive -- but nothing enforces "never touched", and the
failure mode is a stale pointer reading whatever got the block next. Silent, and
at a random later time. One byte cannot go stale.

**One index, not two.** `LINEINPUT` asks `ALLOW$` first and skips `DENY$`
entirely when it is set ([LINEINPUT.INC.BL:195-196](../../GPC-BASIC-TOOLS-SRC/GPB-MODS-TESTING/GPC-BASIC/LINEINPUT.INC.BL#L195)),
so a field only ever uses one of the two. A new flag bit -- `GUI.CF.DENY`, 8 --
says which kind the index names. Default is an allow set.

Standard sets worth shipping:

```
FORM.F.ANY      0  no filter. Anything the keyboard makes
FORM.F.NUM      1  "0123456789"                    digits only
FORM.F.NUMSGN   2  "0123456789.-+="                a signed number, and =
FORM.F.ALPHA    3  letters and space
FORM.F.ALNUM    4  letters, digits and space
FORM.F.FNAME    5  ",:=*?"   a filename -- a DENY set, so passed as -5
```

Index 0 costs nothing to name: a slot that was never given a filter already
holds 0, so `FORM.F.ANY` is the zero the record starts at rather than an entry
in the array.

Those are compile-time literals, so if the heap cost ever matters they can move
to a `GP.BANKEDSTR` group and be read with `GP.BSTR` -- not needed at this size,
but the option is there.

**Case is a transform, not a filter, and needs its own byte.** A membership
test can reject a character; it cannot change one. `"UPPER CASE ONLY"` written
as an allow set of `A-Z` does not force upper case, it refuses every unshifted
letter -- the typist holds shift for the whole field or the key does nothing.
Proper case cannot be expressed as a set at all, because whether a letter is
capitalised depends on the character before it.

So byte +97 is a separate one-byte transform, applied after the filter says the
character is acceptable:

```
FORM.C.ASIS     0  whatever was typed
FORM.C.UPPER    1  a-z -> A-Z
FORM.C.LOWER    2  A-Z -> a-z
FORM.C.PROPER   3  upper after a space or at position 1, lower elsewhere
```

`LINEINPUT` has no case handling today -- grep the file and the only `CASE` in
it is `GP.CASE`. This adds `LINEINPUT.CASE` beside `LINEINPUT.ALLOW$` and
`LINEINPUT.DENY$`, and the transform goes at the accept point, immediately after
[LINEINPUT.INC.BL:195-196](../../GPC-BASIC-TOOLS-SRC/GPB-MODS-TESTING/GPC-BASIC/LINEINPUT.INC.BL#L195).
Per keystroke, not on exit: dBASE's `!` picture showed the capital as it was
typed, and a field that silently rewrites itself on TAB reads as a glitch.
`PROPER` is the only one that needs to look at anything but the key -- it tests
the character to the left of `LINEINPUT.POS`, which is already in hand.

`STRCASE` is not the tool here. `GP.FN(UCASE, A$)` cases a whole string and
returns a copy; this is one character, already in `LINEINPUT.K$`, and an
`ASC`/`AND $DF` in place is smaller than a verb call. `STRCASE` stays what it
is -- the bulk operator.

### 5.2 KV gaps to close in the copy

* `KV.PUTNUM` and `KV.GETNUM` are stubs today: `KV.OK = 0`, no bank selected.
  A numeric field needs them.
* `KV.READ.VALUE` and `KV.WRITE` move strings a character at a time in BASIC,
  `KV.VALUE$ = KV.VALUE$ + CHR$(PEEK(...))` in a `FOR`. Every concat allocates
  a string block. On the form's path that runs once per focus change, roughly
  40 iterations per TAB, which is very likely fine. **Measure a TAB before
  optimising it.** A `GP.ASM` memcpy pair -- bank to string and back, one
  `LEFT$(BLANKS$, n)` allocation then a copy through `GP.STRPTR` -- is about
  twenty lines if the measurement says it is wanted.

### 5.3 Bank 2 -- the dropdown item store

`COMBO.OPEN` reads its items from `MENUVERT.ITEM$()`, **which is also the menu
bar's array**. `XBASE.GUI.TEST.BASL` documents the consequence: the chosen row's
text has to be taken before the screen is redrawn, because redrawing refills
that array with the bar's own items.

That is a data bug, not a picture bug, so saving and restoring the screen does
not touch it. Bank 2 gives the form its own item store -- at 32 bytes an item
that is 256 items across every dropdown on the page -- and dropdowns stop
sharing an array with the menu bar.

---

## 6. Painting -- the screen is the store

A rebuild-from-store `FORMPAINT` is not needed, and the cases that looked like
they needed one are already covered:

* **a dropdown over a field** -- `COMBO.OPEN` already stashes and restores its
  own cells. "NO SAVE, NO DROPDOWN": a missing or full bank means the control
  does not open at all.
* **a dialog over the page** -- `GUI.OPEN` / `GUI.CLOSE` already stash.
* **the whole page, while something else uses the screen** -- `STASHVRAM`.

**`STASHVRAM`, not `STASH`, for a whole page.** STASH caps at 4,094 cells and an
80x60 screen is 4,800, so a full-page save is refused outright. STASHVRAM keeps
cells in VRAM instead: the default window `$04000`-`$1AFFF` is about 94 KB,
roughly nine full screens, and the KERNAL's `memory_copy` moves them VRAM to
VRAM with no BASIC loop. It costs **no banks**, needs no `GP.ASM` and so no
`#SYMFILE`, and it executes no `BANK`, which means it may live inside a
`GP.BANKED` region.

Restoring puts back the attributes, the frame, the shadow and anything else
drawn on that page -- not only the controls the form knows about. That is
strictly more than a rebuild could do.

### 6.1 What save and restore does not cover

It restores the picture as it was. If a bound value changed while the page was
away, the page shows stale text.

So `FORMPAINT` does not die, it shrinks into **`FORMSHOW`: redraw the field
contents only.** No labels, no box, no geometry. It is the one place values come
out of the store in bulk, and it is called deliberately rather than on every
repaint.

---

## 7. The form verbs

```
GP.SUB PAGE                                     ' empty list, origin 1,1
GP.SUB SAYAT,     1, 1, "CUSTOMER RECORD"       ' a label, no control
GP.SUB INPUTLINE, "FIRST NAME", 3, 1, "FNAME", 20
GP.SUB CHECKBOX,  "RETIRED",    4, 1, "RETIRED"
GP.SUB DROPDOWN,  "STATE",      5, 1, "STATE", 12, 4
GP.SUB FILTER,    FORM.F.NUM, FORM.C.ASIS      ' clause: applies to the last control
GP.SUB BUTTONS,   7, 1, "&OK", "&CANCEL"
IF GP.FN(FORMREAD) THEN <saved>
```

| verb | what it does |
|---|---|
| `PAGE` | empty the list, origin 1,1, no box |
| `POPUP` | `title$, w, h` -- open a box, origin = its inner top left |
| `SAYAT` | `row, col, text$` -- a label, no control |
| `INPUTLINE` | `label$, row, col, key$, len` |
| `CHECKBOX` | `label$, row, col, key$` |
| `DROPDOWN` | `label$, row, col, key$, w, count` |
| `BUTTONS` | `row, col, one$, two$` |
| `FILTER` | `set, case` -- a FORM.FILTER$() index and a FORM.C.* transform, applied to the control added last. Negative `set` means a DENY set |
| `FORMREAD` | run it. RETURNS -1 saved, 0 cancelled. Closes the box if `POPUP` opened one |
| `FORMSHOW` | redraw the field contents only |
| `FORMGET` | `n` RETURNS the text of control n, for unbound controls |
| `PAGESAVE` | `SV.SAVE` the whole screen, RETURNS a handle |
| `PAGEBACK` | `SV.RESTORE` it |

Argument order is **label, row, col**. dBASE's own order was row, col, label;
this is the other way round and the only thing that matters is that all thirteen
agree.

`FILTER` as a following statement rather than another formal on every field
verb is deliberate: it is the shape of a dBASE clause, and it keeps the common
call -- a field with no filter at all -- from carrying an argument for it.
Filter and case ride the same clause because they are set together or not at
all, and one clause line is cheaper than two.

---

## 8. Constraints and traps

* **`GP.DO` is taken.** It is the loop opener, with `GP.LOOP` and `GP.EXITDO`.
  The verb callers are `GP.SUB` and `GP.FN`.
* **`READ` is a BASIC keyword.** Hence `FORMREAD`.
* **A verb may not share a spelling with a label**, and it may not carry `$` or
  `%`. That is why the dialog verbs drop the `GUI.` prefix, the way `STRCASE`
  keeps `STR.UCASE:` for the label and `UCASE` for the verb.
* **A verb must be compiled before any call to it** -- the call carries an
  address, not a line number.
* **Formals are ordinary globals.** Two verbs that share a formal clobber each
  other if one's body calls the other. The dialogs do not call each other, but
  `COMBO.OPEN` reaches into `MENUVERT`, so if `MENUVERT` ever gets verbs that is
  the pair to check.
* `PROC_MAXFORMALS` is 12. The widest verb here takes 6.
* **The KV copy cannot live inside a `GP.BANKED` region** -- it executes `BANK`
  and the compiler refuses that there. The form logic can be banked; the store
  access cannot. STASHVRAM has no such problem.
* `GUI.FORM.MAX` is 8 today. The form path uses the banked store instead, so
  the existing arrays either go or are raised for the dialogs that still use
  them -- decide when the store lands.

---

## 9. Build order

1. `GUI.DEFAULTS` in `GUI.INC.BL`, and delete `GMX.D.RESET` from `GPBMODS.BASL`.
2. The fifteen dialog verbs. Independent of everything below.
3. The KV copy: rename, shorten the value to 79, add the extension bytes, build
   `PUTNUM` and `GETNUM`.
4. `PAGE` / `SAYAT` / `INPUTLINE` / `BUTTONS` / `FORMREAD` -- the smallest form
   that runs.
5. Measure a TAB. Decide on the memcpy blobs.
6. `CHECKBOX`, `DROPDOWN`, `FILTER`.
7. The bank 2 item store, and `COMBO` off `MENUVERT.ITEM$()`.
8. `POPUP`, `FORMSHOW`, `PAGESAVE` / `PAGEBACK`.

---

## 10. Still open

* Is 63 controls enough? A two-column page on 80x60 can exceed it. A second
  bank of slots is a `#DEFINE` and no redesign, but bank 2 is spoken for by the
  item store, so it would be a third.
* `GUI.CT.LIST` -- the scrolling list -- has no form verb yet. It is a control
  type the form already supports; it just has no one-liner.
* Numeric fields: `KV.PUTNUM` / `GETNUM` decide the on-disk format, and
  `STRUSING` decides how one is displayed. Not specified here.
