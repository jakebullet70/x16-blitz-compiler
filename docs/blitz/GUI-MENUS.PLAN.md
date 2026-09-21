# GUI menus -- dBASE `@ ... PROMPT` / `MENU TO`, on one builder

A menu is built a line at a time and run by one call. The vertical list and the
horizontal bar are the same list; only the runner differs.

    GP.SUB MENU.BEGIN,  MENU.POPUP
    REM ------------------- ITEM ------------- HINT --------------------- ON
    GP.SUB MENU.ITEMX, "&ADD RECORD", "Add a new record",           MENU.ON
    GP.SUB MENU.ITEMX, "&DEL RECORD", "Delete the highlighted row", MENU.OFF
    GP.SUB MENU.ITEM,  "-"
    GP.SUB MENU.ITEM,  "&QUIT"
    GP.SUB MENU.SELECTED, 2
    N = GP.FN(MENUTO.VERT, 5, 20, 1)

This is the companion to `GUI-FORMS.PLAN.md` and follows its rules. Read that
first: the clean-by-default rule, the short/wide verb pair and the reasoning
about `PICTURE` and `VALID` all apply here unchanged.

---

## 1. Why this is being done

**There are four menu surfaces and they all read one array.**

| surface | file | what it is |
|---|---|---|
| `MENUBAR.RUN` | `MENUBAR.INC.BL:104` | horizontal, item width = text width |
| `MENUVERT.RUN` | `MENUVERT.INC.BL:174` | vertical, no frame, no scroll |
| `GUI.MENU` | `GUI.INC.BL:1143` | `MENUVERT` inside a measured box |
| `GUI.LISTBOX` | `GUI2.INC.BL:82` | the scrolling one, plus multi-select |

`COMBO.OPEN` is a fifth reader of the same array. Four of the five are a
framing decision around one engine, written as four engines.

**The array is shared, and that is a data bug.** `GMX.BAR.LOAD` reloads the
bar's items on every use of either module -- its own comment says so -- and
`GM.BARN%` exists only because `MENUVERT.COUNT` is the dropdown's by the time
`GMX.DROP` walks sideways off one. `GMX.DD.LOAD` empties `MENUVERT.HOT$`
because the bar's letters are otherwise still in it. `XBASE.GUI.TEST.BASL`
documents the `COMBO` consequence: the chosen row's text has to be taken
before the screen is redrawn. Saving and restoring the screen does not touch
any of it.

**Twenty-six sticky input globals** -- twenty-one on `MENUVERT.`, five more on
`MENUBAR.`. **169 lines of `GPBMODS.BASL` touch them**, against 11 in
`GUIFRMT.BASL` and 4 in `PICKDEMO.BASL`.

**Two properties are kept as hand-aligned parallel strings.**
`MENUVERT.HOT$` is one character a row and `MENUVERT.DIS$` another. Nothing
checks that either lines up with the text, and `DIS$` is read once and cleared
by `RUN` and `DRAW` alike, so a redraw silently loses it.

**The bar and its dropdown are joined in the application.** `MENUBAR.DOWNEXIT`
and `MENUVERT.KEYEXIT` are a deliberately minimal contract between two modules
that do not know each other exists -- that part is right. The loop that joins
them is not in the library: `GMX.DROP` is about 110 lines of stash, measure,
frame, run, restore and walk-sideways, written by hand, and every program that
wants a menu bar writes it again. dBASE users wrote a `DO WHILE .T.` around
`MENU TO` and a submenu `PROCEDURE`.

---

## 2. The rule

The same rule as the forms plan: **a verb resets the optional globals itself**
before assigning its formals. A call site says what it means and nothing
carries over from the last call.

Two verbs where a wide one would be mostly defaults -- a short one for the
common case, a wide one taking everything -- exactly as `MSGBOX`/`MSGBOXEX`
and `INPUTBOX`/`INPUTBOXEX` do.

---

## 3. The verbs

| verb | formals | what it does |
|---|---|---|
| `MENU.BEGIN` | slot | empties one slot and makes it the one being built |
| `MENU.ITEM` | text$ | appends one row to it |
| `MENU.ITEMX` | text$, hint$, on | appends one row with its hint and enabled flag |
| `MENU.SELECTED` | n | the row the next run starts on |
| `MENUTO.VERT` | row, col, style | runs a slot vertically, returns 1..N or 0 |
| `MENUTO.BAR` | row, col, style | runs the bar slot horizontally |
| `MENUTO.PULLDOWN` | barnum, style | runs the working slot under bar item `barnum` |

out: `MENU.EXITKEY`, the key that ended the run -- `GP.FN` returns one value and
the sideways walk needs both. `MENU.BARNUM`, the bar slot's own count, which
retires `GPBMODS`'s `GM.BARN%`.

`MENU.BEGIN` is `GUI.FORM.BEGIN` by another name. The architecture is already
in the library; only this spelling is missing.

**Argument order is position, then style**, in both runners:

    N = GP.FN(MENUTO.VERT,     5, 20, 1)
    N = GP.FN(MENUTO.PULLDOWN, 3,     1)

`BARNUM` is the position. The forms plan committed to `label, row, col`, so
position-before-style here keeps one habit rather than two.

### 3.1 A pulldown is a vertical menu that knows where it goes

`MENUTO.VERT` is a menu by itself and takes coordinates. `MENUTO.PULLDOWN`
takes a bar item number instead, and derives the rest: `MENUBAR.WHERE` sets
`MENUBAR.SEL` and calls `MENUBAR.COLUMN`, which walks the item list to find
where item N starts, so the column is already known and the row is the bar's
plus one. Clamping to `APPSYS.COLS` comes with it.

They also differ in behaviour and not only in geometry, which is what makes
them two verbs rather than one with a flag: a dropdown runs with
`MENUVERT.KEYEXIT` set so LEFT and RIGHT hand back for the sideways walk, and a
standalone menu does not.

**`MENU.SELECTED` is the one input the builder does not carry in a row.** It
says where the highlight sits when the menu opens, and both engines already
take it: `MENUVERT.SEL` and `MENUBAR.SEL` are documented in, "the row to start
on; 0 starts at 1" (`MENUVERT.INC.BL:84`, `MENUBAR.INC.BL:40`). The verb stores
it and the runner copies it across in one line.

    GP.SUB MENU.SELECTED, 2
    N = GP.FN(MENUTO.VERT, 5, 20, 1)

It is a verb and not a fourth formal on the runners because the runners are at
three already, it is wanted on maybe one menu in five, and a formal costs its 3
bytes at every call site whether or not the caller has anything to say (§5).

**`MENU.BEGIN` clears it and the runner clears it again on the way out.** That
is the clean-by-default rule: a menu opens on row 1 unless the line above it
says otherwise, and a remembered position never leaks into the next menu. The
cost is that resuming a bar where the user left it is explicit --
`GP.SUB MENU.SELECTED, MENU.BARNUM` before re-running the bar in the sideways
walk. One visible line beats a global that is sometimes stale.

The engine clamps to 1..COUNT itself, so an out-of-range row is not an error
here either.

**A row whose text is one hyphen is a separator**, as `MENUVERT` already has
it. The row still counts, so `MENU TO`'s numbering is unchanged.

**`&` marks the hotkey**, as `GP.SUB BUTTONS, 7, 1, "&OK", "&CANCEL"` already
does in the forms plan. The builder strips it, records the letter and the
column, and `MENUVERT.HOT$` dies. This is strictly better than what the engine
does now: today `HOTFIND` scans the row text for the character, so an item
`"SAVE AS"` with hotkey `A` tints the wrong one. With `&` the column is known.

**The enabled flag replaces `DIS$`** the same way, and being a formal it is
reset per row rather than read once and cleared.

    #DEFINE MENU.ON  1
    #DEFINE MENU.OFF 0

The verb tests `<> 0`, so a hand-written `-1` and a `MENU.ON` both work and
nobody has to remember which. §5 says why these cannot be `-1`.

**The last argument is the box style, passed to `GP.BOX` verbatim**, and the
four frames the ROM font draws get names:

    #DEFINE MENU.SOLID 0         solid block
    #DEFINE MENU.THIN  1         single line
    #DEFINE MENU.ROUND 2         rounded
    #DEFINE MENU.THICK 3         thick
    #DEFINE MENU.NOBOX 255

255 is the one gap in that range. 256 or more is an address, eight screen codes
of the caller's own, so a menu still carries a custom frame for free -- the
names cover the built-in four and any other number goes through untouched.

`GUI.LINEBOX 2` (`GUI.INC.BL:112`) is the only box-style name in the library
today and it names the same 2. These are the menu's own spelling, not a
replacement for it; whether `GUI.INC.BL` grows the matching set is that file's
question, not this plan's.

`MENUTO.BAR` takes the same list because the builder is axis-neutral. That is
what lets `MENUTO.PULLDOWN` exist at all.

---

## 4. The store

**Menus get their own item store.** This is the point of the refactor; a
builder that appends into `MENUVERT.ITEM$()` fixes the spelling and keeps the
bug.

**Superseded 2026-09-18:** text and hints are two `GP.BANKEDSTR` groups in
bank 62, claimed from `BANKMGR` (see step 1 in §7). Flags, hot keys and
columns stay private strings in low RAM. Originally: plain private arrays,
not a bank, in **two slots**:

    #DEFINE MENU.BAR   0         16 items -- the bar, stays resident
    #DEFINE MENU.POPUP 1         32 items -- the working list

| | | bytes |
|---|---|---:|
| `MENU.TEXT$(47)` | item text, both slots | 48 x 2 = 96 |
| `MENU.HINT$(47)` | hint line | 48 x 2 = 96 |
| `MENU.FLAG$`, `MENU.HOTCOL$` | one char an item | ~100 heap |
| | | **~290** |

A string array is **2 bytes an element** -- each element points at the block
(`GPB.INC.BL:96`).

**Two slots and not one, because `MENUTO.PULLDOWN` needs the bar's list while
the dropdown is open.** One slot would mean `MENU.BEGIN` for the dropdown
emptying the list `MENUBAR.COLUMN` is about to walk, and the dropdown would
position itself against its own items. That is this refactor's own bug
reappearing inside the new store: `GM.BARN%` exists in `GPBMODS` today for
exactly this reason, because `MENUVERT.COUNT` is the dropdown's by the time the
bar is walked sideways.

The slot number is the only thing standing between this and the full
"declare every menu once" model -- see §8.

This is **workspace**, not p-code -- the budget `DIM` raises OUT OF MEMORY
against, not the p-code cap.

Beside the arrays sits one scalar, `MENU.SEL%` -- what `MENU.SELECTED` set,
0 for none. It is not per slot: it is read and cleared by the next runner to
go, so there is never a second value waiting.

**The flags stay as one-character-per-item strings** and that is not a
relapse. The parallel strings were only dangerous when a human kept them
aligned; here `MENU.ITEMX` appends to text, hint and flags in one call, so
they cannot drift. It is also the cheapest storage of the three options.

**`MENUVERT.ITEM$(32)` does not go away in phase 1.** `COMBO.OPEN`,
`GUI.LISTBOX` and `FILEPICK` still read it. The private store is additive
until the engines unify, and only then does that 66 bytes come back.

### 4.1 Text and hints may live in a bank, and the library never knows

**Superseded 2026-09-18: the library now owns bank `MENU.TEXTBANK` (62).** A
caller still passes ordinary strings, `GP.BSTR` ones included; what follows
was the reasoning before the store moved into a bank.

**`MENU.INC.BL` declares no bank, names no bank and has no `#DEFINE` for one.**
`GP.BSTR` is a unary GP operator evaluated at the *call site*: by the time
`MENU.ITEMX` runs, its formals hold ordinary strings, and the verb cannot tell
a banked one from a literal. So the answer to "can item text bank the way hint
text does" is that there is no difference between them -- both are just the
string the caller passed, and §4.2's loop already banks both.

That is the layering, and it is what keeps this generic. The store holds
strings. Where the caller got them is the caller's business: literals, banked
text, a disk read, or text it built at runtime.

**A `GP.BANKEDSTR` bank number cannot come from `BANKMGR`.** The number in the
header is a decimal constant the compiler reads while it writes the object;
nothing about it survives into the runtime, so there is no `BANKMGR.ALLOC` to
ask. The manager is *told*, not asked, and that line belongs to the program
that owns the group, above its first `ALLOC`:

    BANKMGR.WANT = <the number in the GP.BANKEDSTR header>
    GOSUB BANKMGR.CLAIM

Skipping it leaves the bank marked free and a later `ALLOC` hands the program's
own literal text to a scratch user. That rule already applies to every banked
group a program has; menus add no new case of it.

The economics, for a caller deciding whether to bank a menu at all: a literal
costs `2 + N` bytes of low RAM, a banked reference costs **5**. Per string the
bank takes `1 + N` and low RAM saves `N - 3`, so it pays from four characters
up -- which every menu row and every hint clears. Only the open menu's strings
are live in the heap, and the scavenger takes them back on the next build.

### 4.2 The loop shape

A group name is resolved at compile time and never reaches the object, so it
cannot be passed as a formal. It does not need to be:

    GP.SUB MENU.BEGIN, MENU.POPUP
    FOR GM.I = 1 TO GP.BSTRCOUNT(BS.DD.DIALOG) - 1
      GP.SUB MENU.ITEMX, GP.BSTR(BS.DD.DIALOG, GM.I), GP.BSTR(BS.HH.DIALOG, GM.I), MENU.ON
    NEXT GM.I
    N = GP.FN(MENUTO.VERT, 5, 20, 1)

Five lines for a menu of any size, and the count is derived from the group so
it cannot drift from the list it counts. `GP.BSTR` is a unary GP operator, not
another verb, so it nests inside `GP.SUB` arguments without the formal-clobber
problem.

**Index 0 of the hint group carries the enable mask**, the way `BS.BAR.LOAD`
already keeps its hotkey string `"DLISGATBF"` at index 0. Then
`MID$(GP.BSTR(BS.HH.DIALOG, 0), GM.I, 1)` is the flag and one loop shape serves
every menu.

**Two groups and not one interleaved group.** Text and hints parallel-indexed
keep the loop above at one `FOR` and one `GP.BSTRCOUNT`; packing them into one
group alternating text, hint, text, hint would halve the group count against
`BSTR_MAX_GROUPS` (128) at the price of index arithmetic in every line. No
program is near 128 groups for menus alone. If one ever is, the library does
not change -- only the two expressions inside the `GP.SUB`.

A caller with no hints calls `MENU.ITEM` and reads one group. The hint group is
not a parallel structure the library maintains; it is one the caller may or may
not have.

---

## 5. What shaped this

**Arity is exact, both directions.** `ProcCompileArguments` jumps to
`ProcArity` when a comma is missing where a formal is expected, and again on
one comma too many: `ARGUMENTS DO NOT MATCH THE GP.DEFPROC`
(`gpdefproc.asm:337`). So there are no optional trailing arguments, and
`MENU.ITEM` and `MENU.ITEMX` must be two verbs.

That is not an oversight. Every argument is evaluated before any is stored,
waiting on the frame stack, so a nested call finishes before the outer call
writes a formal -- without it `GP.FN(AREA,2,GP.FN(AREA,3,4))` silently
computes 36 for what the longhand makes 24. Optional formals would mean
"whatever the last call left there", which is the disease being cured.

**An array cannot be a formal.** `ACHOICE(t,l,b,r,aItems)` cannot be spelled
literally. The builder is the answer: one item a line, which is the dBASE
spelling anyway.

**Each formal costs 3 bytes of code section per call site.** A six-formal item
verb on a twelve-item menu is ~216 bytes of nothing. So `MENU.ITEMX` stops at
three, and any further property goes in a following clause verb, the shape the
forms plan already uses for `FILTER`.

**`#DEFINE` takes unsigned values only, and a negative one fails silently.**
`define_val` calls `option_get_int`, which has no sign handling and ends in
`util_str_to_bcd`, which does `sbc #48` per character and branches to `invalid`
on anything below `'0'`. `-` is 45. So `#DEFINE MENU.NOBOX -1` gives
`ERROR: INVALID PARAMETER`, a 6-byte PRG, and a passing `OK CODE 11` -- the
same misleading signature as a nesting failure. Hence 255, and hence
`MENU.ON 1` rather than `MENU.ON -1`.

**A pulldown cannot be one call.** `GMX.DROP` does nine things and eight are
mechanical -- re-mark the bar, `MENUBAR.WHERE`, measure the widest row, clamp
to `APPSYS.COLS`, `STASH.SAVE`, fill and box the frame, run with `KEYEXIT`,
`STASH.RESTORE`. The ninth is `GOSUB GMX.DD.LOAD`, a `GP.SELECT` on the bar
item that fills the list from a different bank group for each dropdown. That is
a callback -- "give me the items for bar item N" -- and there is no indirect
`GOSUB` to reach it. So the library takes the eight and the application keeps
the one, which is the part that is genuinely its own.

**No callback.** `ACHOICE`'s `cUserFunction` needs an indirect `GOSUB`, which
this BASIC does not have -- the same wall the forms plan hit with `VALID` and
declined to build. `MENUVERT.KEYEXIT` already covers the case that matters:
the runner hands the key back and the caller decides.

**We are ahead of Clipper on two things and should not lose them.** Disabled
items are a real property here where Clipper had only workarounds -- a parallel
`aEnabled` array tested after the call. Hotkeys and separators likewise.

**A flag is tested at run time.** `MENUBAR` is a separate file from `MENUVERT`
on the stated grounds that a flag would keep a horizontal path inside every
vertical menu even after dead-code elimination. Merging the engines has to
answer that, which is why §7 leaves it last.

---

## 6. What it costs

| | |
|---|---:|
| arrays (workspace) | ~290 B |
| bank, per banked string | `1 + N` B |
| low RAM saved, per banked string | **`N - 3` B** |

P-code is not estimated here. Per item it should be near neutral -- a scalar
formal store and an `FNGOSUB` against today's array store, and array stores
carry index arithmetic. The real reduction is `GMX.DROP` collapsing into
`MENUTO.PULLDOWN`. **Measure it at step 6, do not predict it.**

---

## 7. Build order

1. `MENU.INC.BL`: the store, `MENU.BEGIN`, `MENU.ITEM`, `MENU.ITEMX`, and the
   `&` strip. No runner yet; a test that builds a list and reads it back.
   **Written 2026-09-18, not built.** Test is `MENUBUILD.EXP.BL`, compiled
   SHARED. Text and hints are the `GP.BANKEDSTR` groups `MENU.TEXTS` (48 x
   `SPC(30)`) and `MENU.HINTS` (48 x `SPC(50)`) in bank `MENU.TEXTBANK` 62,
   written with `GP.BSTRSET`, read with `GP.BSTR`, index
   `slot * 16 + row - 1`. The first `MENU.BEGIN` claims the bank from
   `BANKMGR`; `MENU.OK` 0 means it was taken and every row is dropped.
   Needs `GPB.INC.BL`, `BANKMGR.INC.BL` and `BANKMGR.INIT`. Added past §4:
   `MENU.HOTKEY$(slot)` (the letter); `MENU.FLAG$` / `MENU.HOTCOL$` are
   per-slot low-RAM strings; `MENU.FLAG$` "1" is disabled, as
   `MENUVERT.DIS$`. Row count is `LEN(MENU.FLAG$(slot))`. `MENU.SEL%` is
   left to step 2. For step 2: tint from `MENU.HOTCOL$`, not `HOTFIND`;
   assign `MENUVERT.DIS$` every run; `MENU.COUNT` is taken in root
   `MENU.EXP.BL`.
2. `MENUTO.VERT` over the existing `MENUVERT.RUN`, feeding it from the private
   store. `MENUVERT.HOT$` and `.DIS$` are filled by the builder, not the
   caller. `MENU.SELECTED` lands here, as one line into `MENUVERT.SEL`.
   **Written 2026-09-18, not built.** Demo is `MENUTO.EXP.BL`, run by hand.
   Runs the popup slot; rows are copied into `MENUVERT.ITEM$()`, so the
   caller still DIMs it past ten. `MENUVERT` gained `HOTCOL$`, read once and
   cleared like `DIS$`, which replaces `HOTFIND`'s search. The style goes to
   `GP.BOX` verbatim with the frame in `SEPATTR` (else `ATTR`), so step 5's
   256+ tables already pass; `MENU.NOBOX` 255 skips it. `MENU.EXITKEY` is
   set here. Hints and `MENUVERT.HINTW` are left to step 4.
3. `MENUTO.BAR` over `MENUBAR.RUN`, same list.
   **Written 2026-09-18, not built.** Same demo, passes 4 and 5. Runs the
   bar slot and sets `MENU.BARNUM`; the box is one row high and as wide as
   the items plus `MENUBAR.GAP` between them. The row copy and the frame
   are shared with `MENUTO.VERT` (`MENU.LOAD`, `MENU.FRAMEBOX`).
   `MENUBAR.RUN` / `.DRAW` now take `MENUVERT.DIS$` and `.HOTCOL$` the way
   `MENUVERT` does. `MENU.INC.BL` now needs `MENUBAR.INC.BL` included too,
   even for a program with no bar. A disabled bar item is stepped over
   by LEFT and RIGHT, and its hot key, RETURN and the cross-axis exits
   are refused on it.
4. Hints: `MENU.ITEMX`, the hint row, and the index-0 enable mask. No bank
   here -- the bank, if any, is the sample's at step 7.
   **Written 2026-09-18, not built.** Same demo, passes 1 to 3. With
   `MENUVERT.HINTW` set, `MENUTO.VERT` copies the popup's hints into
   `MENUVERT.HINT$()` (`MENU.LOADHINTS`) and `MENUVERT` draws them as it
   always has; with it 0 the array is never touched. The bar gets none. The
   index-0 mask is a caller convention, documented in the header, with no
   library code: the caller passes `VAL(MID$(GP.BSTR(HH, 0), I, 1))` as `on`.
5. The box style argument through to `GP.BOX`, including 256+ glyph tables.
   **Written 2026-09-18, not built.** No library change: `MENU.FRAMEBOX`
   has passed the style to `GP.BOX` verbatim since step 2. Same demo, pass
   3 now frames the popup from `T.GLYPH$ = "++++--!!"`, passed as
   `GP.STRPTR(T.GLYPH$) + 1`. The rows are copied into `MENUVERT.ITEM$()`
   between the call and `GP.BOX`; that is safe because the string heap
   reuses dead blocks and never moves a live one.
6. `MENUTO.PULLDOWN`, and `MENU.EXITKEY` / `MENU.BARNUM` out of it -- absorb the
   eight mechanical steps of `GMX.DROP`. Measure p-code before and after.
   **Written 2026-09-18, not built.** In its own file, `MENUPULL.INC.BL`,
   so a program with no dropdown does not carry `STASH` or its `#SYMFILE`.
   Reloads the bar slot, refuses a disabled `barnum`, unmarks the item
   `MENU.MARKED` says is lit and marks `barnum`, then places the popup at
   `MENUBAR.SELX`, `MENUBAR.Y + 1`, pulled left off the screen edge (columns
   from the KERNAL's `screen_mode`, not `APPSYS`). Saves under it into
   `MENU.STASHBANK` (the caller's, or one from `BANKMGR.GET.FREE.BANK` on
   first use), runs with `KEYEXIT` added to the caller's flags, and restores
   the screen. Returns a row only for RETURN or a hot key: under `KEYEXIT`
   any other key leaves `MENUVERT.SEL` standing, and `GMX.DROP` dispatches on
   it today. Added past §3: `MENU.NEXTBAR`, the bar item LEFT or RIGHT walks
   to with disabled items skipped by `MENUBAR.SKIPDIS`, so the caller's walk
   is `B = MENU.NEXTBAR` and `GM.BARN%` has nothing left to do. `MENUTO.BAR`
   sets `MENU.MARKED` from `KEEPMARK`. No fill before the frame: the rows
   cover the inside, as in `MENUTO.VERT`, and there is no `GMX.DROP`'s
   one-cell pad. Demo pass 6 in `MENUTO.EXP.BL`, which now needs a
   `#SYMFILE`. The p-code measurement is owed at step 7, when `GMX.DROP`
   is actually replaced.
7. Convert `GPBMODS`'s nine dropdowns and its bar to the loop shape of §4.2.
   Walk every one on screen: a wrong `GP.BSTRCOUNT` shows as a menu one row
   short and only the running program shows it.
   **Written 2026-09-18, not built.** `MENU.INC.BL` and `MENUPULL.INC.BL` are
   a seventh region, `GM.MENUCODE` 12, claimed with the others. The bar is
   built once at startup, before the free banks are asked for, because its
   first `MENU.BEGIN` claims bank 62. Its hot keys moved from the index-0
   string `"DLISGATBF"` into `&` marks, and index 0 is now a title as in the
   dropdowns. The shell is `GMX.BAR` then `GMX.DROP`, which is
   `GMX.DD.LOAD`, `MENUTO.PULLDOWN`, dispatch on a row, else
   `GM.SEL% = MENU.NEXTBAR` and round again. `GM.BARN%`, `GM.BARWAS%`,
   `GM.OPEN%`, `GM.DODROP%`, `GM.DD*%`, `GM.LEFT`/`RIGHT` and
   `GMX.BAR.LOAD` are gone. `GM.DDBANK%` is preset into `MENU.STASHBANK`, so
   `GMX.S.STASH` still borrows the same bank. `GMX.DISPATCH` sets
   `MENUVERT.SEL` from the returned row, so the nine routers are unchanged.
   Colours come from `GMX.MENUCOLS`, with the dropdown frame in `SEPATTR`.
   Added past §3: `GP.SUB MENU.DRAWBAR, row, col, style`, the bar drawn
   without running it and `MENU.MARKED` lit, which `GMX.CHROME` needs to
   repaint the bar under a panel. It shares `MENU.BARPLACE` with
   `MENUTO.BAR`. Visible change: no one-cell pad right of the longest
   dropdown row. **Built 2026-09-18**: `GPBMODS.PRG` 11,515 B SHARED,
   `.OVL` 39,701 B. The GUI region was over 8K, so `MENUBAR` moved to the
   menu region. `modsbuild.py` now copies every `.BL`, for
   `MENU.INC.BANKED.BL`. Owed: the walk, the p-code measurement.
8. `GUI.MENU` becomes `MENUTO.VERT` with a frame. `PICKMENU` in the forms plan
   is then the same call and one of the two should go.
   **Written 2026-09-18, not built.** `GUI.MENU` keeps its question box; its
   rows are the popup slot, built by the caller, and it runs `MENUTO.VERT`
   with `MENU.NOBOX` inside the box. `GUI.COUNT` and `MENUVERT.ITEM$()` are
   no longer its input, `MENU.SELECTED` replaces `GUI.SEL` in, and `&` hot
   keys are tinted in `GUI.BORDER`. The highlight is as wide as the widest
   row, not the box. `GUI.INC.BL` now needs `MENU.INC.BL`, so in `GPBMODS`
   the menu region (now with `MENUVERT` in it too) moved ahead of the GUI
   region, for the `#DEFINE`s. Also done: the LISTS dropdown's six demos
   run on the builder (`MENUTO.VERT`, box styles, `MENU.ITEMX`, `MENUTO.BAR`,
   `&` hot keys, flags); the `MENUVERT.DRAW` and `.ROW` demos are gone. The
   nine routers dispatch on `GM.ROW%`, not `MENUVERT.SEL`.
9. **Rip out `MENUVERT` and `MENUBAR`.** Decided 2026-09-18, refined the same
   day: it may go a part at a time, but both files are deleted at the end and
   every program that names them is moved. One part a turn:
   1. The vertical engine moves into `MENU.INC.BL` and reads the store
      directly: no `ITEM$` copy, no `HOT$`, `DIS$`, `HOTCOL$` or `HOTFIND`.
      Its inputs become `MENU.*` (colours, flags, hint field).
      **Written 2026-09-18; `MENUTO.EXP` built (7,879 B SHARED), GPBMODS
      not built.** `MENU.VRUN` runs the popup slot straight from the
      store. Its inputs are `MENU.ATTR`, `.HIATTR`, `.HOTATTR`,
      `.DISATTR`, `.SEPATTR`, `.SEPCHR`, `.FLAGS` and `.HINTX/Y/W/ATTR`,
      and its flags are `MENU.MUSTSEL` and the rest, with the same values
      as before. The store's flag string now gives a separator `"2"`. The
      old `MENU.LOAD` copies only the bar slot into `MENUVERT`, colours
      included, for `MENUBAR`, and goes in part 2. `MENU.MEASURE` gives
      the count and widths without a copy. `MENU.LOADHINTS` is gone.
      `MENUPULL`, `GUI.MENU`, `GMX.MENUCOLS`, the LISTS demos and
      `MENUTO.EXP` have moved to the new names.
   2. The bar engine the same way. `MENUBAR.INC.BL` is deleted.
      **Written 2026-09-18, not built.** One engine, `MENU.RUN`, runs both
      slots under `MENU.RUNFLAGS`: on the bar slot `MENU.TURN` makes LEFT
      and RIGHT move as UP and DOWN do, and DOWN or UP choose under
      `MENU.DOWNEXIT` (16) or `MENU.UPEXIT` (32). `MENU.SPOT` places a row:
      down the popup, or across the bar at its text's width plus
      `MENU.GAP`. The bar's inputs are `MENU.GAP` and `MENU.BARFLAGS`; its
      outputs add `MENU.SELX` and `MENU.SELW`. `MENU.LOAD` is gone, and
      `MENUPULL` no longer names `MENUVERT`. RETURN on a dead row now does
      nothing in both slots, and the pad's LEFT and RIGHT are read in both.
      `MENUTO.EXP`, `MENUBUILD.EXP`, `GPBMODS` and `GUIFRMT` have moved;
      neither `.EXP` includes `MENUVERT` any more. Still naming `MENUBAR`:
      the GPBMODS sizes panel (a measured table, redone with the p-code
      measurement), the root `GPC-BASIC/` copy, and the private copies in
      `samples/edit`, `XBASE` and `GPC-GUI-HELPER`.
   3. `COMBO` keeps its rows itself and runs them through the popup slot.
      **Written 2026-09-18, not built.** The caller DIMs and fills
      `COMBO.ITEM$()`. `COMBO.OPEN` draws its own box, loads the popup slot
      from the array (each item cut to the box, the first padded out to it so
      every row lights full width), and runs `MENUTO.VERT` with
      `MENU.NOBOX`; the `MENU.*` colours, flags and `HINTW` it sets are put
      back. The popup slot is the combo's after it opens, and an item is a
      menu row, so `&` and `-` mean what they do there. `GPBMODS` DIMs
      `COMBO.ITEM$(4)` for its form demo. `GUIFRMT` and `PICKDEMO` are
      deleted (2026-09-18). Still reading the old way: the root
      `GPC-BASIC/` copy (with `GUI.EXP.BL` and `GUI2TST.EXP.BL`), and the
      private copies in `GPC-GUI-HELPER`, `GPC-HELP` and `XBASE`.
   4. The GUI list control and `GUI.LISTBOX` get a row painter of their own
      over their own array -- the old step 9, with scrolling.
      **Written 2026-09-18, not built.** `GUI.LIST.PAINT.ROW` fills the row and
      prints `GUI.LIST.ITEM$(GUI.LIST.SCROLL + row)` cut to `GUI.LIST.W`; a
      row past `COUNT` is blank, so `FILEPICK.BLANK` is gone. The window is
      `GUI.LIST.SCROLL`, zeroed by `GUI.FORM.ADD.LIST`, so neither `GUI.LISTBOX`
      nor `FILEPICK` resets it on the way out. The caller DIMs
      `GUI.LIST.ITEM$()`; `GPBMODS` DIMs 24 and no longer includes
      `MENUVERT.INC.BL`. `GUI`, `GUI2`, `FILEPICK` and `GPBMODS` no longer
      name `MENUVERT`, except the sizes panel's label.
   5. `MENUVERT.INC.BL` is deleted; `FILEPICK`, the `GPB.INC.BL` example and
      the tests that name it are fixed.
      **Done 2026-09-18, not built.** The file is deleted from the working
      copy. The `GPB.INC.BL` example now builds a popup with `MENU.INC.BL`;
      `STASHVRAM.EXP.BL`'s comment and the `readme.md` prose no longer name it.
      No test or build script named it. Left for a build: the `GPBMODS` sizes
      panel and the readme's byte tables, which still list `MENUVERT` and
      `MENUBAR` with their 2026-09-15 figures and are re-measured together.
      Left for later: the root `GPC-BASIC/` copy, where both files and
      `MENU.EXP.BL`, `MENUDEMO.EXP.BL` and `MENUTST.EXP.BL` still use them, and
      the private copies in `samples/edit`, `GPC-GUI-HELPER`, `GPC-HELP`
      and `XBASE`.
   6. The editor moves onto the library: a bar and every dropdown declared
      once, and one call per key.
      **Written 2026-09-19, not built.** `MENU.INC.BL` has the slots
      `MENU.DROP + n`, one per bar item, in a 64-row text pool after the
      popup (no hints), taken in build order and emptied by a `MENU.BEGIN`
      on the bar. The bar has its own `MENU.BARATTR`, `.BARHI` and
      `.BARHOT`. `MENUPULL` gained `MENU.SAVESCREEN`: `MENU.SAVE.VRAM`
      (STASHVRAM, the default, started on first use) or `MENU.SAVE.BANK`
      (STASH), so it now needs `STASHVRAM.INC.BL` too. The new
      `MENUKEY.INC.BL` has `MENU.KEY` (-1, 0 or a row, with
      `MENU.PICKBAR`), `MENU.THEME`, and the ALT keymap patch with
      `MENU.KEYS.OFF`. It runs `BANK 0`, so it stays out of a region.
      `ED-MENUS.BASL` uses all of it. `EDITOR.BASL` lost `ED.READ.MODS`,
      `ED.ALTKEYS`, `ED.MENU.ACTIVE` and the ESC case, runs `ED.THEME`
      before the menus, and starts the VRAM window past layer 0's map.
      Still on the old shape: `GPBMODS`, whose bank save now needs
      `GP.SUB MENU.SAVESCREEN, MENU.SAVE.BANK`, and the demos.

---

## 8. Still open

* **Accelerators -- a closed-menu `^Q`, shown right-aligned in the row.** Cut
  from the build order; nothing in the library or `GPBMODS` has them today. Two
  reasons it is not free. The library cannot dispatch one: with the menu closed
  the application's own key loop sees the key, and there is no indirect `GOSUB`
  for the library to call back through, so it could only store the text,
  right-align it and hand it back. And right-aligning changes the measure step,
  because the widest row is then text plus gap plus accelerator. If it comes
  back it is `MENU.ACCEL`, never `MENU.KEY` -- `&` is already the key.

* **`MENU.TEXT$()` and `MENU.HINT$()` in a `GP.BANKEDSTR` group.** The store
  starts as arrays (§4). A group is possible since `GP.BSTRSET` landed:
  `GP.BSTRSET NAME, n, A$` writes slot *n* cut to the slot's capacity,
  `GP.BSTR(NAME, n)` reads it back, both take a run-time *n*, and both restore
  the caller's bank, so they are safe inside a `GP.BANKED` region. An empty
  slot reads `""`, which is what a blank row is today.

  Because the store is private, the change stays inside `MENU.INC.BL`: the
  builder writes with `GP.BSTRSET`, the runners read with `GP.BSTR`, and no
  caller of `MENU.ITEM` sees a difference.

  What it costs:

  1. **The library names a group, and the program declares it.** The bank
     number is a compile-time constant that cannot come from `BANKMGR` (§4.1),
     so every program using menus carries the declaration and its
     `BANKMGR.CLAIM`. That breaks §4.1's "the library names no bank".
  2. **One `SPC(n)` line per slot**, 48 of them for both slots, written out.
  3. **Overlong text is cut, silently.** Size the width with room; it costs
     bank bytes only.
  4. **Every read allocates a temporary and copies.** `MENUBAR.COLUMN` sums
     every item before the one it wants, so a bar draw copies about n^2 / 2
     strings -- small at 16 items, but measure it.
  5. **The saving is small.** It is heap, and it scales with length, not count
     ([[banking-strings-scales-with-length]]). Short menu items net about 6-15 B
     each, about 0.5 KB for a full 32-row list.

  **Done 2026-09-18, cost 1 accepted:** the library picks bank 62 and claims
  it. The flag strings are one character an
  item and gain nothing from a bank either way.

  Banking the shared `MENUVERT.ITEM$()`, which `FILEPICK` also fills, is a
  separate job and is in `TODO.md` under banked scratch strings.

* **More than two slots -- the full dBASE model, where every dropdown is
  declared up front and a pulldown really is one call.** The slot number
  already makes this a sizing change and not a redesign: with all ten lists
  resident there is no callback left to make, so `GMX.DD.LOAD` goes too. Cost
  is every item resident at once -- `GPBMODS`'s nine dropdowns are ~63 items
  plus 10 on the bar, so ~1,450 bytes of heap against ~200 today. Affordable
  (`FREE 9,728` after the text went into banks) but not free, and step 6 should
  land first so the saving is measured against something.

* **Whether `ACHOICE` and `MENUTO.VERT` are both spellings of the same verb.**
  `ACHOICE` is authentic and opaque to anyone who never used Clipper. An alias
  costs a verb name and nothing else.
* **Whether the bar gets hints.** dBASE put the message line under a bar as
  readily as under a list, and nothing in `MENUBAR` reads `HINT$` today.
* **`MENU.HINT$()` as text or as an index.** Text is what §4.2 assumes and it
  is ~350 bytes of transient heap. An index would hold one hint in low RAM at a
  time, but the group cannot be a formal, so it would mean a flat pool index
  and a second way to spell a hint. Not worth it unless a menu gets large.
* **Where the `MENUVERT.SCROLL` offset goes** once step 9 gives the engine its
  own loop. It is an input today that `RUN` deliberately does not drive.
* **The 33-item ceiling.** It is `GPBMODS`'s existing `DIM` and its peak is 10.
  A program with a longer menu raises its own `DIM`; the library should say so
  in the header rather than pick a number.
