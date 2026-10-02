# GUI-FIELD-EDIT

This sample is the checkout form of REWIND CITY VIDEO, a made-up video rental
store. One 80x30 form holds 26 controls and two buttons.

## Files

| File | What |
|---|---|
| `GUI-FIELD-EDIT.PRG` | `GUI-FIELD-EDIT.BASL`, compiled. 18,305 bytes. |
| `GUI-FIELD-EDIT.OVL` | The banked code and text. 26,893 bytes. |
| `GUI-FIELD-EDIT.BASL` | Source. |
| `GFE.TEXT.INC.BL` | Source. Every string the program shows. |
| `README.md` | This file. |

`GUI-FIELD-EDIT.PRG` is compiled EMBEDDED. It carries its own runtime, so no
runtime file is needed beside it.

`GUI-FIELD-EDIT.PRG` reads `GUI-FIELD-EDIT.OVL` when it starts. The name is
fixed when the program is compiled, and the file is opened from the current
folder of drive 8. Keep both files in one folder under these names, and run
the program from that folder. A missing or short `.OVL` stops the program
with `?OVL`.

## Run it

Start in the release root.

| Step | Type | Result |
|---|---|---|
| 1 | `DOS"CD:SAMPLES"` | Changes to `SAMPLES`. |
| 2 | `DOS"CD:GUI-FIELD-EDIT"` | Changes to `SAMPLES/GUI-FIELD-EDIT`. |
| 3 | `LOAD "GUI-FIELD-EDIT.PRG",8` | Loads the program. |
| 4 | `RUN` | Reads the `.OVL` and opens the form. |

| When | The screen |
|---|---|
| After `RUN` | `SCREEN 1`, 80x30, and the form. The focus is on `MEMBER #`. |
| `RENT`, a check fails | A box names the problem. `OK` reopens the form. |
| `RENT`, the checks pass | A `RENTAL DONE` box, then `START A NEW RENTAL?` |
| | `YES` opens an empty form. `NO` ends the program. |
| `CANCEL` or ESC | `CLOSE THE STORE FOR THE NIGHT?` |
| | `YES` ends the program. `NO` opens the form again. |

After a failed check or a `NO` to closing, the form opens again with every
answer as it was. Between forms, the boxes stand on a page headed
`REWIND CITY VIDEO` and `A GPC-BASIC FORM SAMPLE`.

On exit the program puts back the text colour, screen mode and charset it
found.

## The form

The form fills the screen. Its title is
`REWIND CITY VIDEO - THE RENTAL COUNTER`. The buttons `RENT` and `CANCEL` are
under the controls, and `RENT` is the default.

A line runs down between the two columns. A line across each column
separates its sections, and joins the line down.

The left column holds the member.

| Label | Control | Size or items |
|---|---|---|
| `MEMBER #` | Field | 6 characters |
| `FIRST NAME` | Field | 16 characters |
| `LAST NAME` | Field | 16 characters |
| `PHONE` | Field | 12 characters |
| `STREET` | Field | 22 characters |
| `CITY` | Field | 16 characters |
| `STATE` | Combo | TX, OH, ME, ID, CA, NY, FL, WA, AZ, CO |
| `ZIP` | Field | 5 characters |
| `LEVEL` | Combo | BASIC, SILVER, GOLD, PLATINUM |
| `ID CHECKED` | Check box | |
| `AGE 18 OR OVER` | Check box | |
| `MAILING LIST` | Check box | |
| `RENT FOR` | Radio group | 1 NIGHT, 3 NIGHTS, 7 NIGHTS |
| `PAY BY` | Combo | CASH, CHECK, CREDIT CARD, STORE CREDIT |
| `CLERK` | Combo | DANA, MARCUS, PRIYA, LEE |
| `COUPON` | Field | 8 characters |
| `NOTES` | Field | 22 characters |

The right column holds the rental and its bill.

| Label | Control | Size or items |
|---|---|---|
| `TITLES` | List, multi-select | 18 titles, 10 rows showing |
| `FORMAT` | Radio group | VHS, BETAMAX, LASERDISC |
| `BE KIND, REWIND PLEDGE` | Check box | |
| `RATE`, `QUANTITY`, `SUBTOTAL` | Value | Read only |
| `DISCOUNT`, `TAX`, `TOTAL DUE` | Value | Read only |

TAB visits the controls in the order of these tables, left column first, then
`RENT` and `CANCEL`. It skips the six values. After `CANCEL` it goes back to
`MEMBER #`.

A new rental starts with every field empty and each combo on its first item.
`RENT FOR` is on `3 NIGHTS`, `FORMAT` is on `VHS` and no title is marked. Only
`BE KIND, REWIND PLEDGE` is ticked.

## Keys

These work on every control except where a table below says otherwise.

| Key | Does |
|---|---|
| TAB | Moves to the next control. |
| SHIFT+TAB | Moves to the previous control. |
| RETURN | Presses `RENT`. |
| ESC | Ends the form, as `CANCEL` does. |
| R, C | Press `RENT` or `CANCEL`. Not in a field or a combo. |

In a field:

| Key | Does |
|---|---|
| Typing | Inserts at the caret. A full field refuses more. |
| LEFT, RIGHT | Move the caret. |
| HOME, END | Move the caret to the start or the end. |
| DEL | Deletes the character before the caret. |
| DOWN, UP | Move to the next or the previous control. |
| ESC | Restores the text the field had on entry. Ends the form. |

In a combo:

| Key | Does |
|---|---|
| RETURN, SPACE, DOWN | Open the dropdown. |
| UP | Moves to the previous control. |

In an open dropdown, UP and DOWN move and stop at the ends. RETURN picks the
item. ESC closes the dropdown and keeps the old item.

In a check box:

| Key | Does |
|---|---|
| SPACE | Ticks or clears the box. |
| X | Ticks the box. |
| DEL | Clears the box. |
| RIGHT, DOWN | Move to the next control. |
| LEFT, UP | Move to the previous control. |

In a radio group:

| Key | Does |
|---|---|
| UP, DOWN | Move the choice. Past the first or last item, leave the group. |
| RIGHT | Moves to the next control. |
| LEFT | Moves to the previous control. |

In the `TITLES` list:

| Key | Does |
|---|---|
| UP, DOWN | Move the bar one title. |
| PGUP, PGDN | Move the bar 10 titles. |
| HOME, END | Move the bar to the first or the last title. |
| SPACE | Marks or unmarks the title under the bar. |

A marked title shows `*` in front of it.

On a button:

| Key | Does |
|---|---|
| RETURN, SPACE | Press the button. |
| RIGHT, DOWN | Move to the next control. |
| LEFT, UP | Move to the previous control. |

A box with one `OK` button closes on RETURN, SPACE, O or ESC. In a `YES` and
`NO` box, Y and N answer. TAB and the cursor keys move between the two
buttons, and RETURN or SPACE presses the one with the focus. The focus starts
on `YES`. ESC answers `NO`.

## The bill

The six values are worked out again after every change to the form. A
field's change counts when the focus leaves it.

| Value | Worked out as |
|---|---|
| `RATE` | The format's price times the `RENT FOR` factor, to the cent. |
| `QUANTITY` | The number of titles marked. |
| `SUBTOTAL` | `RATE` times `QUANTITY`. |
| `DISCOUNT` | The level's percent of `SUBTOTAL`, to the cent. |
| `TAX` | 8.25% of `SUBTOTAL` less `DISCOUNT`, to the cent. |
| `TOTAL DUE` | `SUBTOTAL` less `DISCOUNT`, plus `TAX`. |

Coupon `BEKIND` adds $1.00 to `DISCOUNT`. `DISCOUNT` is never more than
`SUBTOTAL`. Each amount shows as `$` and `##0.00`, so the points line up.

| Control | Item | Value |
|---|---|---|
| `FORMAT` | `VHS` | $2.99 |
| | `BETAMAX` | $1.99 |
| | `LASERDISC` | $3.99 |
| `RENT FOR` | `1 NIGHT` | x1 |
| | `3 NIGHTS` | x1.5 |
| | `7 NIGHTS` | x2.5 |
| `LEVEL` | `BASIC` | 0% off |
| | `SILVER` | 5% off |
| | `GOLD` | 10% off |
| | `PLATINUM` | 20% off |
| `COUPON` | `BEKIND` | $1.00 off |

The figures are set at the top of the program, in `GFE.BASE()`,
`GFE.STRETCH()`, `GFE.PERCENT()`, `GFE.TAXRATE` and `GFE.COUPONOFF`.

## RENT

`RENT` ends the form and checks the rental. If more than one check fails, the
box shows the first in this order.

| Fails when | Message |
|---|---|
| No title is marked. | `PICK AT LEAST ONE TITLE.` |
| `LAST NAME` is empty. | `TYPE THE MEMBER'S LAST NAME.` |
| `ID CHECKED` is not ticked. | `TICK ID CHECKED BEFORE RENTING.` |

When every check passes, the `RENTAL DONE` box shows three lines.

```
MEMBER <member #>  <first name> <last name>
<n> TITLES ON <format> FOR <rent for>
TOTAL DUE $<total>, PAID BY <pay by>
```

For one title the second line reads `1 TITLE ON`.

`PHONE`, `STREET`, `CITY`, `STATE`, `ZIP`, `AGE 18 OR OVER`, `MAILING LIST`,
`CLERK`, `NOTES` and `BE KIND, REWIND PLEDGE` are kept with the rental.
Nothing checks or prices them, and the `RENTAL DONE` box does not show them.

## How the form is built

The form verbs are in `GUI-DIALOGS.INC.BL`. `GFE.BUILD.FORM` calls them.

| Verb | In this program |
|---|---|
| `FORM.BEGIN` | The title, 24 rows of controls, 74 cells wide, two buttons. |
| `FORM.ITEMS` | The item store, in bank `GFE.ITEMBANK%`. |
| `FORM.FIELD` | A field. |
| `FORM.COMBO` | A combo. Its items follow it. |
| `FORM.CHECK` | A check box. |
| `FORM.RADIO` | A radio group. Its items follow it. |
| `FORM.LIST` | The `TITLES` list. Its items follow it. |
| `FORM.ITEM` | One item of the last combo, radio group or list. |
| `FORM.COLUMN` | The right column, 37 cells right of the left one. |
| `FORM.VALUE` | A read-only value. |

The first argument of a control verb is its row, 0 up from the first line
inside the box. A control's number is its place in the order it was added, 1
up. The controls are added in the order of the `GFE.C.*` defines, so each
define is its control's number. A form holds 32 controls, its buttons
included. This one has 28.

`GFE.TEXT$()` and `GFE.CHOICE%()` keep each control's answer under its
number. `GFE.TAKE.FORM` reads them after the run and before `FORM.END`, with
`FORM.TEXT`, `FORM.SEL` and `FORM.CHECKED`. The next form is built from them.

WARNING: `FORM.SEL` of a check box is not its tick. Read a check box with
`FORM.CHECKED`.

The `TITLES` marks are a string of `0` and `1`, one a title, read with
`FORM.TEXT`. `FORM.SETTEXT` puts them back only once a control after the list
is added, so `GFE.BUILD.FORM` sets them last.

`GFE.RUN.FORM` runs the form a change at a time.

```
GP.DO
    GFE.ANSWER% = GP.FN(FORMTO.EVENT)
    IF GFE.ANSWER% < 1 THEN GP.EXITDO
    GOSUB GFE.PRICE.RENTAL
GP.LOOP
GOSUB GFE.PRICE.RENTAL
```

`FORMTO.EVENT` returns -1 for `RENT`, 0 for `CANCEL` or ESC, or n when
control n changed. Called again, it carries on with the form.
`GFE.PRICE.RENTAL` writes the six values with `FORM.SETTEXT`. A field typed
in and left with RETURN changes and ends the form on one key, so the bill is
worked out once more after the loop.

## Banks

The library runs from `GP.BANKED` regions, and the program's text is a
`GP.BANKEDSTR` bank. All of it is in `GUI-FIELD-EDIT.OVL`.

| Bank | Define | Holds | Pages |
|---|---|---|---|
| 4 | `GFE.UTILCODE` | APPSYS, BANKMGR, STASHVRAM, THEME, STRUSING | 15 |
| 5 | `GFE.MENUCODE` | MENU.INC.BANKED, MENU, MENUPULL | 15 |
| 6 | `GFE.GUICODE` | LINEINPUT, GUI | 24 |
| 7 | `GFE.FORMCODE` | COMBO, CHECK, GUI-DIALOGS | 19 |
| 8 | `GFE.TEXTBANK` | `GFE.TEXT.INC.BL` | 6 |
| 62 | `MENU.TEXTBANK` | The menu store's text | 26 |

The Pages column is each bank's size in the `.OVL`. A page is 256 bytes, and
the last page of a bank is padded.
Bank 62 is the default `MENU.TEXTBANK` in `MENU.INC.BANKED.BL`. A combo's
dropdown is the menu builder's popup slot.

`GPB.INC.BL` and `STASH.INC.BL` are included above the regions and stay in
low RAM with the program. `STASH.INC.BL` holds a `BANK` statement, and a
region may not run one.

A plain `GOSUB`, `GP.SUB` or `GP.FN` calls into a region. The call selects
the region's bank and the return puts the caller's back.

`GOTO GFE.LIBEND`, above the regions, steps over them and the text. Keep the
bank defines at the top. BASLOAD resolves a `#DEFINE` only after it has read
it.

At start the program claims banks 4 to 8 in `GFE.CLAIM.BANKS`. The first
`MENU.BEGIN` claims bank 62. Then `BANKMGR.GET.FREE.BANK` gives two more: one
for `DLGRESET`, where a box saves the cells it covers, and one for the form's
item store. Claim before asking for a free bank, or the free bank can be one
the program already uses. A new bank in the source needs a claim in
`GFE.CLAIM.BANKS`.

## The text

`GFE.TEXT.INC.BL` holds every string the program shows, in `GP.BANKEDSTR`
groups in bank 8. `GP.BSTR(group, n)` reads string n, 0 up.
`GP.BSTRCOUNT(group)` is the number of strings, and the item loops in
`GFE.BUILD.FORM` run to it.

A string added to `GFE.TEXT.STATES`, `GFE.TEXT.PAYMENTS`, `GFE.TEXT.CLERKS`
or `GFE.TEXT.TITLES` is a new item with no change to the BASL. A combo opens
to 32 items at most. An item added to `GFE.TEXT.FORMATS`, `GFE.TEXT.NIGHTS`
or `GFE.TEXT.LEVELS` also needs its figure in `GFE.BASE()`, `GFE.STRETCH()`
or `GFE.PERCENT()`, and that array's `DIM` raised to match.

## Rebuilding

The sample cannot be rebuilt in `SAMPLES/GUI-FIELD-EDIT/`. The `#INCLUDE`
lines in `GUI-FIELD-EDIT.BASL` need a `GPC-BASIC/` folder beside the source,
and that folder has none. The compiler is not there either. See the release
root's `README.md`, section "Compiling a program".

<!-- release: the rest is for the source tree -->

## In the repository

### Run it

`USER-RUNS\gui-field-edit-demo.bat` runs `GUI-FIELD-EDIT.PRG` in the
emulator, with the sample folder as the drive. It takes no arguments. It
stops if `GUI-FIELD-EDIT.PRG` or `GUI-FIELD-EDIT.OVL` is not built.

### Build

From the repository root:

```
python source\gpc\samplesbuild.py GUI-FIELD-EDIT
```

### Files

- `GPC-BASIC/` holds the 15 modules `GUI-FIELD-EDIT.BASL` includes:
  `GPB.INC.BL`, `STASH.INC.BL`, `APPSYS.INC.BL`, `BANKMGR.INC.BL`,
  `STASHVRAM.INC.BL`, `THEME.INC.BL`, `STRUSING.INC.BL`,
  `MENU.INC.BANKED.BL`, `MENU.INC.BL`, `MENUPULL.INC.BL`,
  `LINEINPUT.INC.BL`, `GUI.INC.BL`, `COMBO.INC.BL`, `CHECK.INC.BL` and
  `GUI-DIALOGS.INC.BL`.
- `GPC.BIN`, `GPC.PRG`, `BASLOAD-GPC.PRG` and `BASLOAD-GPC.BIN` are the
  compiler and tokeniser, for building on the machine.
- `GPC.IMG.131.BIN`, `GP1.IMG.131.BIN` and `*.RT.131.BIN` are the runtime
  images the compiler embeds.
- `GPC.INPUT` names the last compile's files. `GPC.PRG` writes it on every
  compile and `GPC.BIN` reads it.

### Build outputs

| File | Written by | Bytes | Ships |
|---|---|---|---|
| `GUI-FIELD-EDIT.SRC.PRG` | BASLOAD | 38,911 | No |
| `GUI-FIELD-EDIT.SRC.SYM` | BASLOAD | | No |
| `GUI-FIELD-EDIT.PRG` | GPC | 18,305 | Yes |
| `GUI-FIELD-EDIT.MAP` | GPC | | No |
| `GUI-FIELD-EDIT.OVL` | GPC | 26,893 | Yes |
