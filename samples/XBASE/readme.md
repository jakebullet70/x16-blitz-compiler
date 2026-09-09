# XBASE -- the skeleton

**Nothing here has been compiled or run.** The files exist so the shape is visible. The design is in
[PLAN.md](PLAN.md); this file says what was written, what was not, and where the two disagree.

## 1. The files

| file | what it is |
|---|---|
| `PLAN.md` | the design |
| `readme.md` | this |
| `XBASE.BASL` | the admin: screen, key loop, and one label per menu item |
| `XBMENUS.BASL` | the bar, the dropdowns, the enable rules, the dispatch |
| `MKFIX.BASL` | builds `PARTS.DBF` and `SUPPLR.DBF`, and is the first test |
| `GPC-BASIC/DBFILE.INC.BL` | channels, `P` and `T`, block read and write |
| `GPC-BASIC/DB.INC.BL` | schema, field arrays, navigate, split and join, find, pack |
| `GPC-BASIC/DBFORM.INC.BL` | one record on the screen |
| `GPC-BASIC/DBBANK.INC.BL` | the shims that move the engine into bank 5 |

## 1a. What is in a bank

| bank | what | claimed by |
|---|---|---|
| 4 | `THEME`, `MENUVERT`, `MENUBAR`, `LINEINPUT`, `GUI`, `GUI2` -- everything that draws | `BANKMGR.CLAIM` at startup, as `LIB.GUIBANK` |
| 5 | the record keeper, at step 6 | not yet -- `DBBANK.INC.BL` is not included |
| 6 | the v2 index | not yet |
| 8 | the cells a dialog covers, as `XB.GUIBANK` | `BANKMGR.CLAIM` at startup |

The GUI region is `GOTO`'d over in `XBASE.BASL`, the way `GPBMODS.BASL` does it. **What stays in low
memory is not a leftover.** `STASH` holds the `STASH` statement and a region may not contain one, so
`GUI.OPEN` reaches it by an ordinary `GOSUB` downwards. `STRINGS` stays because `DB.JOIN` calls it on
every record and a region cannot call another region. `DBFORM` stays because it calls `LINEINPUT`,
which is in the region. The engine stays because it is not tested yet.

A call through a shim leaves bank 4 selected and the shims do not put the caller's back. Nothing in
low memory cares. A caller inside another region would, and could not fix it -- which is the thing
step 6 has to get right, not this.

`XBMENUS.BASL` is `#INCLUDE`d by `XBASE.BASL` at the bottom, the way `ED-MENUS.BASL` is by
`EDITOR.BASL`. They share one global symbol table.

The modules under `GPC-BASIC/` are working copies. Nothing goes to the root library until it passes.

## 2. The admin is DBU

Clipper's `DBU`, not dBASE III PLUS's Assistant. The source is
`github.com/ibarrar/clipper/tree/master/CLIPPER5/SOURCE/DBU`, and `DBU.PRG` lines 241 to 330 are the
whole menu.

Three things made it the model.

- Eight bar titles, short enough that the whole bar fits one row. `DBU` makes each one a function
  key as well, drawn ten columns apart by `show_keys()`; **the function keys are not copied here**.
  ESC opens the bar and the arrows walk it, which is what `EDITOR.BASL` does, and there is no
  keyboard shortcut for anything on it.
- Dropdowns of two to six items. Short enough to draw under a title without a layout pass.
- **An enable rule per item.** `DBU` keeps a parallel boolean array beside every menu array:
  `open_b[2] = "sysfunc = 0 .AND. .NOT. box_open .AND. .NOT. EMPTY(cur_dbf)"`, so File Index cannot
  be reached until a database is open. That is exactly what two work areas need.

The Assistant builds a command line at the bottom of the screen out of the dropdown choices. That is
a lot of machinery to arrive at a verb the bar already named.

**The bar**

| title | items |
|---|---|
| File | Database, Index\*, Close, Exit |
| Create | Database\*, Index\* |
| Save | Struct\* |
| Browse | Table, Record |
| Utility | Copy\*, Append, Replace\*, Pack, Zap |
| Move | Seek\*, Goto, Locate, Skip |
| Set | Relation\*, Filter\*, Fields\*, Area |
| Help | About, Keys |

\* is present and does nothing but say why.

Five changes from `DBU`'s own list. `DBU` calls the first title Open and puts Help first; here the
first title is File and Help is last, which is where every bar-menu program written since puts it.
File gains Close and Exit, because `DBU` closes files and leaves from its view screen and this has no
view screen to do either from. Open View, Save View and Browse View go, because there is no `.VEW`
file. Utility Run goes, because there is no shell.

**Leaving is File Exit, and that is the only way out.** The dropdown item, the dispatch entry and
the `XB.CMD.QUIT` routine all sit in the File section of `XBASE.BASL`; the key loop binds ESC, TAB
and the two arrows and nothing else.

**A disabled item is still drawn and still selectable**, and says why when it is chosen. `MENUVERT`
has no notion of a dead row, and giving it one is a library change rather than a change here.

## 3. What is written

`DBFILE.INC.BL` and `DB.INC.BL` are written out in full. `DBFORM.INC.BL` is written out in full.
`XBASE.BASL` and `XBMENUS.BASL` are written out in full apart from the nine commands marked above.

Not written, and each says so on the screen:

| command | what it needs first |
|---|---|
| Create Database | the structure editor. `DBUSTRU.PRG` is 1,346 lines of exactly this. `MKFIX.BASL` stands in. |
| Save Struct | a fourth channel. 12, 13 and 15 are all held while a database is open. |
| Utility Copy | Set Fields, or it copies every field and is `DB.CREATE` plus a loop. |
| Utility Replace | a filter, or it is a loop nobody would run. |
| Set Filter | an expression parser. |
| Set Fields | a flag per field and a column list. Browse and Copy both read it. |
| File Index, Create Index, Move Seek, Set Relation | the v2 index. |

Set Relation is not faked, for the reason PLAN.md section 7 gives: a relation without an index is a
full child scan on every parent move. Move Locate in the other area is the honest version until then.

## 4. Where this disagrees with PLAN.md

Five things came out differently once the code was written. PLAN.md has not been changed.

**There are no function keys and no keyboard shortcuts.** PLAN.md section 7 gives F1 as help on the
highlighted option, and `DBU` names every bar title after one. Both are out. ESC opens the bar, the
arrows walk it, and File Exit is how the program ends.

**`DB.COUNT` is the physical record count, not the live one.** PLAN.md section 2 calls it the live
count and then checks it against `(filesize / stride) - DB.DATA0`. Those are two different numbers
the moment a record is deleted. The file size can only ever check the physical count, so that is what
the header holds. A live count is a scan and is not stored.

**The schema arrays are two dimensional and `DB.CREATE` reads them.** PLAN.md section 5 gives
`DB.CREATE` a separate set of one dimensional inputs -- `DB.FNAME$()`, `DB.FLEN()`, `DB.FDEC()`.
There is no need for a second set: `DB.NAME$(area, field)`, `DB.TYPE$()`, `DB.WID%()` and `DB.DEC%()`
are the arrays `DB.OPEN` fills in, and `DB.CREATE` is the one place they are an input instead of an
output.

**`DBFILE.CREATE` exists.** PLAN.md does not mention making the file. A channel opened for write is
not a channel that can be positioned backwards, so creation is `,S,W`, close, reopen `,M`.

**`DB.PACK` does not shorten the file.** CMDR-DOS cannot truncate one. Navigation is bounded by
`DB.COUNT`, so the records left past the new end are invisible and `DB.NEW` appends over them.

## 5. Before any of it runs

The four measurements in PLAN.md section 8 are still unanswered, and two of them decide whether the
format works at all.

1. **Does a write in `,M` overwrite in place, or truncate?** `MKFIX.BASL` answers it: it writes four
   records, reads them back in reverse, and checks the stored count against the file size.
2. **What does one `P` seek plus one `BINPUT#` cost?** It decides whether the `MACPTR` scan blob in
   PLAN.md section 6 is needed.
3. The byte cost of a string array element, against the `DIM DB.FLD$(1, 31)` budget.
4. Whether a 16-bit signed path anywhere in the `P` argument caps the file at 32,767 bytes, which
   would be 511 records at stride 64.

WARNING: `DBFILE.SEEK` sends `CHR$(0)` inside a `PRINT#` string whenever an offset byte is zero,
which is most of them. Whether a NUL reaches the command channel unchanged is part of measurement 2,
and nothing in the design survives the answer being no.

## 6. Build

Nothing is built. When it is:

**The library modules come from `samples/GPB-MODS-TESTING/GPC-BASIC/`, not from the root library.**
That is where the banked copies live: their entry points are renamed to `.BODY` and `LIB.GUIBANK.INC.BL`
carries the eighteen low memory shims. The root copies are the unbanked, expanded ones and have
neither. `GPB.INC.BL` is the one exception, and it goes the other way -- the root copy is the newer,
and it is the only one with the `#TOKEN` lines for `GP.DEFPROC`, `GP.SUB`, `GP.FN` and `RETURNS`,
which step 6 needs.

```
copy GPB.INC.BL                                        from GPC-BASIC/
copy BANKMGR.INC.BL APPSYS.INC.BL KB.INC.BL
     STRINGS.INC.BL STASH.INC.BL LIB.GUIBANK.INC.BL
     THEME.INC.BL MENUVERT.INC.BL MENUBAR.INC.BL
     LINEINPUT.INC.BL GUI.INC.BL GUI2.INC.BL           from GPB-MODS-TESTING/GPC-BASIC/
copy DBFILE.INC.BL DB.INC.BL DBFORM.INC.BL             from XBASE/GPC-BASIC/
copy XBASE.BASL XBMENUS.BASL MKFIX.BASL                from XBASE/
                                                       into testing/

python source/gpc/build_basl.py MKFIX.BASL MKFIX.PRG
python source/gpc/build_basl.py XBASE.BASL XBASE.PRG
```

Then compile each `.PRG` with `GPC.BIN`, SHARED. `MKFIX` first: it makes the fixtures `XBASE` opens,
and it is the measurement.

`STASH.INC.BL` is in the list because `GUI.OPEN` calls it, not because anything here does.
`GUI2.INC.BL` is in it because `LIB.GUIBANK.INC.BL` shims `GUI.LISTBOX` and BASLOAD resolves every label
in a file it reads, so leaving it out stops the build with LABEL NOT FOUND. Nothing here calls it.
`MKFIX.BASL` needs none of the screen modules -- `GPB`, `STRINGS`, `DBFILE` and `DB`, and no bank.

Every `GOSUB` and `GOTO` target resolves across the eleven files here plus the thirteen library
modules named above, banked set included. That is the only check that has been run on any of this.

No `#AUTONUM` in either file. The directive sets the step between generated line numbers, and the
default step of 1 is the only one `STRCASE.INC.BL` survives.

## 7. Order of work

1. Run the four measurements. `MKFIX.BASL` is the first two.
2. Fix whatever `MKFIX` says is wrong about `DBFILE` and `DB`.
3. `XBASE.BASL` against the fixtures: open, browse, edit, delete, pack.
4. The structure editor, which unblocks Create Database and Save Struct.
5. Set Fields, which unblocks Copy and makes Browse readable on a wide record.
6. Move the engine into bank 5 behind `DBBANK.INC.BL`. The engine banks last -- a region that
   misbehaves is a silent hang with no line number, and the engine is the part with no screen on it.
   The GUI is already banked, and it is the safer half to have done first: when a dialog stops
   drawing, it is visible.
7. v2: the index in bank 6, `DB.SEEK`, the `MACPTR` scan blob, `DB.RELATE`.

`DBBANK.INC.BL` is not usable yet. Its shims call `DB.*.BODY` and `DB.INC.BL` defines plain `DB.*`
labels; renaming them is part of step 6. `#INCLUDE` it before then and the build stops with LABEL NOT
FOUND.
