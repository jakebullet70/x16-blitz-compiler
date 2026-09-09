# XBASE -- plan

**Nothing is built. This file is the plan only.**

A dBase II / XBase-style record keeper for the X16, written in Blitz-X16 BASIC. The data lives on
disk, one record is visible at a time, and the whole database is never loaded. `samples/XBASE/` holds
the demo, which is also the admin: create, browse, edit, delete, pack, from a pull-down bar menu in
the shape of dBASE III PLUS's Assistant.

Target size is a few hundred records. Two databases open at once.

## 1. Random access on CMDR-DOS

There are no REL files. Byte-level random access comes from two command-channel calls, and they work
on any file.

| call | form | returns |
|---|---|---|
| position | `"P" + CHR$(ch) + CHR$(b0) + CHR$(b1) + CHR$(b2) + CHR$(b3)` | `00, OK,00,00` |
| tell | `"T" + CHR$(ch)` | `07,pppppppp ssssssss,00,00` |

The offset is 32-bit little-endian, four **binary** bytes. `T` returns position **and file size**, as
eight hexadecimal digits each. `T` is R48 and later.

The _ch_ argument must equal the data channel's secondary address.

Open mode `,M` is read and write, and is what allows a record to be overwritten in place.

`BINPUT# <n>,<var$>,<len>` reads a whole record in one call. `ST AND 64` is true at end of file.

WARNING: the KERNAL manual parses the `T` reply with `VAL("$" + MID$(A$,10))`. That returns 0. `VAL`
stops at the first non-numeric character. Parse the eight hex digits by hand.

## 2. File format

Every record is the same length, the header included. Record 0 **is** the header, so the byte offset
of record N is `N * DB.STRIDE` with no addition, and `DB.GOTO 0` is legal.

Records 1 to `DB.FIELDS` are the field descriptors, one each. Data starts at `DB.DATA0`.

**Record 0 -- the header**

| off | len | content |
|---|---|---|
| 0 | 1 | delete flag, always `' '` |
| 1 | 4 | `XDB1` magic |
| 5 | 3 | stride |
| 8 | 2 | field count |
| 10 | 3 | first data record |
| 13 | 6 | live record count |
| 19 | 8 | last update, `YYYYMMDD` |
| 27 | .. | title, space padded |

**Records 1..F -- one field descriptor each**

| off | len | content |
|---|---|---|
| 0 | 1 | `' '` |
| 1 | 10 | field name |
| 11 | 1 | type, one of `C N D L` |
| 12 | 3 | width |
| 15 | 2 | decimals |
| 17 | 3 | byte offset inside a data record |

The stored offset makes a field one `MID$`. Without it every access runs a sum over the preceding
widths.

**Data records** -- `' '` live or `'*'` deleted at byte 0, then the fields at fixed width, back to
back, padded out to the stride.

Everything is text. Numbers are right-justified and space-padded, which makes one byte comparison
order any field.

The live count is in the header and the file size comes from `T`. `(filesize / stride) - DB.DATA0`
must equal the stored count. When it does not, the last session died mid-write: trust the file size
and rewrite the header. That is `DB.FIX`.

## 3. Where the code lives

| thing | where | limit |
|---|---|---|
| engine p-code | bank 5, `GP.BANKED` region | -- |
| entry shims | low RAM | ~12 bytes each |
| `DB.FLD$()`, the split arrays | low RAM | BASL strings are always heap |
| schema descriptors | bank 5 | raw 32-byte records, `GP.BSTR` to read one |
| the data | disk | one record at a time |
| GP.ASM blobs | low RAM | the pool never moves into a region |
| v2 index | bank 6 | numbers only, never becomes a string |

Net low-RAM cost of the engine is about 1 KB: shims, globals, the field arrays.

**Bank map**

```
bank 4   LIB.CODEBANK    GUI library region        existing
bank 5   DB.CODEBANK     engine region + schemas   new
bank 6   DB.IDXBANK      index                     v2
bank 7   ---             OBJ_BUF_BANK, never claim
```

Each needs `BANKMGR.SET.BANK = n : GOSUB BANKMGR.CLAIM` before the first ALLOC.

**Modules**

| file | bank | contents |
|---|---|---|
| `DBFILE.INC.BL` | 5 | channels, `P` and `T`, block read and write, header read and write |
| `DB.INC.BL` | 5 | schema, field arrays, navigate, split and join, find, del, pack |
| `DBBANK.INC.BL` | low | one shim per public entry, LIBBANK pattern |
| `DBFORM.INC.BL` | 4 or low | the one-record screen |
| `XBASE.BASL` | low | the admin front end |

Region rules that place these:

- A region may not contain `BANK`. `PEEK` and `POKE` restore the bank around every access and are
  safe. `BLOAD` and `BSAVE` can never be in a region.
- Region to low memory is fine, provided the low routine leaves the bank alone.
- Region to another region is out both ways. The compiler refuses the direct branch, and through a
  shim the return lands under the wrong bank.
- `BANK`, `BLOAD`, `BSAVE` or `STASH` in low memory immediately before a call into a region is
  equally fatal.
- SHARED mode only.

So `DBFORM` cannot be in bank 5: it calls `GUI.INPUT` and `LINEINPUT.GET`. Put it in bank 4 beside
the GUI, or leave it low.

`DBFILE` must not call `FILEIO`, for the same reason and because the lifetimes differ: `FILE.*`
opens, acts and closes, and a database holds its channels open for its whole life. The `P` and `T`
code is duplicated into `DBFILE`.

WARNING: `FILE.STATUS` closes channel 15. Any `FILE.*` call made while a database is open takes the
command channel with it.

Region safety of the file I/O is settled -- FILEDIR is already banked whole and does `OPEN`, `CLOSE`
and directory reads from `$A000`. `BINPUT#` and `PRINT#` are the same shape.

**Channels.** Data channel 12 for area 0, 13 for area 1, command channel 15 shared. `P` and `T` take
the target channel as an argument, so one command channel drives both areas; do not open two. 2 and
3 belong to the editor, GPC-HELP and the cruncher. 14 belongs to FILEIO.

## 4. Talking to a field

A record is an array, not a call. `DB.GOTO` splits the record into `DB.FLD$()`, and `DB.PUT` joins it
back. Between the two, a field is read and written as an array element, in plain BASIC.

```
DIM DB.FLD$(1, 31)          ' area, field -- the record
DIM DB.OFF%(1, 31)          ' byte offset, cached from the descriptor
DIM DB.WID%(1, 31)          ' width, cached from the descriptor
```

Both arrays are DIMmed once, at the dBASE III maximum of 32 fields and two areas. An element that is
never assigned costs nothing -- the runtime hands out a static empty string for it.

Names resolve to indices once, after the open:

```
DB.KEY$ = "PRICE" : GOSUB DB.FINDFLD    ' -> DB.F, 0 if no such field
PRICE = DB.F
```

Then the field is the element:

```
PRINT DB.FLD$(DB.A, PRICE)
DB.FLD$(DB.A, PRICE) = "12.50"
P = VAL(DB.FLD$(DB.A, PRICE))
DB.FLD$(DB.A, PRICE) = STR$(P)
GOSUB DB.PUT
```

`DB.A` is the selected area. Naming it in the subscript is what gives the alias for free -- reading
the other area's buffer is `DB.FLD$(1, SUPPNAME)`, which is dBASE's `SUPP->NAME` and costs one array
index, because the record is already in hand.

Rules:

- The engine writes a field space-padded to its width, so a value straight off disk is form-ready
  and comparable, and the heap block stays the same size on every record. `GOSUB STR.RTRIM` when a
  bare value is wanted.
- An assignment from application code may be short or long. `DB.PUT` pads, truncates and justifies
  per the type as it joins -- text left, numbers right and zero-filled.
- Numbers are `VAL` and `STR$`. `VAL` skips leading spaces, so a right-justified field parses
  directly.
- The 2-D subscript is off the 1-D array fast path. Against a disk round trip it does not count.

WARNING: nothing detects an assignment, so there is no dirty flag. `DB.NEXT` discards an uncommitted
edit without asking. `DB.PUT` before every move.

## 5. Command syntax

House style: GOSUB labels, globals in and out, like `FILE.*`.

**Areas**

```
DB.A = 0 : GOSUB DB.SELECT      ' 0 or 1; every other verb acts on the selection
```

**Open and close**

```
DB.NAME$ = "PARTS.DBF" : DB.DEVICE = 8 : GOSUB DB.OPEN
DB.TITLE$ = "PARTS" : DB.FIELDS = 4 : GOSUB DB.CREATE
GOSUB DB.CLOSE                  ' flushes the header
GOSUB DB.CLOSEALL
GOSUB DB.FIX                    ' count against file size
```

`DB.CREATE` reads the schema out of `DB.FNAME$()`, `DB.FTYPE$()`, `DB.FLEN()` and `DB.FDEC()` and
computes the stride itself.

**Navigate** -- each leaves the record in `DB.FLD$()` and the number in `DB.RECNO`

```
DB.RECNO = 12 : GOSUB DB.GOTO
GOSUB DB.NEXT      GOSUB DB.PREV
GOSUB DB.TOP       GOSUB DB.BOTTOM
```

`DB.EOF` and `DB.BOF` are the flags. `DB.NEXT` skips deleted records unless `DB.SHOWDEL` is true.
That switch is what makes `DB.UNDEL` usable.

**Write**

```
GOSUB DB.PUT        ' join DB.FLD$() and write at DB.RECNO, in place
GOSUB DB.NEW        ' reuse a deleted slot, else append; blank the buffer
GOSUB DB.DEL        GOSUB DB.UNDEL
GOSUB DB.PACK       ' rewrite without the deleted
```

**Search**

```
DB.F = 2 : DB.KEY$ = "SMITH" : DB.EXACT = 0 : GOSUB DB.FIND
```

Scans forward from `DB.RECNO + 1`, sets `DB.OK`, positions on the hit. `DB.SEEK` is the v2 indexed
form, same arguments.

**Sort**

`DB.SORTF` is the field, output is `DB.ORDER%()`, a permutation of record numbers fed to
`SORT.INC.BL`. Every field is text and padded, so one comparison orders any of them. Negative
numbers are the exception and break it.

**Form**

```
GOSUB DBFORM.SHOW       ' labels from the schema, values from DB.FLD$()
GOSUB DBFORM.EDIT       ' LINEINPUT per field, straight into DB.FLD$()
```

`DBFORM` is the `FORM.EXP.BL` loop with the arrays supplied by the engine: `DB.WID%()` is the field
width, the type gives `LINEINPUT.ALLOW$`, and `DB.FLD$()` is both the value in and the value out.

## 6. BASL and ASM

**v1 is entirely BASL. No blobs.**

- A field is one `MID$`. A blob saves microseconds against a disk round trip costing milliseconds.
- The `P` argument is a 32-bit offset. BASL floats are exact to 16,777,215, a 16 MB file, and a
  four-step divide loop builds the `CHR$` string.
- The `T` reply is eight hex digits, parsed in BASL.

ASM pays in one place: the full-file scan, and the win is fewer KERNAL round trips, not faster
comparing. One `MACPTR` blob pulling 255 bytes a call into bank 6, and a second comparing a key at a
fixed offset across every record in the bank, turns 250 seek-and-read pairs into about 63 straight
reads with no seeks. Estimate 0.5-1.2 s down to about 0.2 s.

`MACPTR` rules: set the bank first, point at `$A000`, the KERNAL wraps banks itself; ask for 255
bytes or fewer so the returned count fits one byte; it may return fewer than asked and that is not an
error; carry set means the device has no `MACPTR` and the caller falls back to `ACPTR`; it leaves the
new bank selected; the destination pointer is reset to `$A000` between calls.

A blob called from banked p-code runs from low RAM and may switch banks, provided it restores the
caller's before returning.

Build it when a measurement says the scan is too slow, and agree it first.

## 7. The admin

Eight bar items, after dBASE III PLUS's Assistant.

| bar item | dropdown |
|---|---|
| `SET UP` | open primary, open secondary, close, quit |
| `CREATE` | database file, from structure of another |
| `UPDATE` | append, edit, browse, replace, delete, recall, pack |
| `POSITION` | goto record, find, skip, top, bottom |
| `RETRIEVE` | list, display, count, sum, average |
| `ORGANISE` | sort, copy |
| `MODIFY` | amend structure |
| `TOOLS` | directory, rename, erase, list structure |

Status line carries both open files with the selection marked, and the position:
`>PARTS  SUPPLR   Rec 12/47`. F1 is help on the highlighted option. In EDIT, the arrow keys reach a
field and RETURN accepts.

`MENUBAR` drives the bar and `MENUVERT` every dropdown, joined by `MENUBAR.DOWNEXIT` and
`MENUVERT.KEYEXIT`.

Fixture: `PARTS.DBF` and `SUPPLR.DBF`, both built by `DB.CREATE`.

`SET RELATION` is not faked in v1. A relation without an index is a full child scan on every parent
move. The demo calls `DB.FIND` in area 1 when asked. `DB.RELATE` becomes honest when the index lands,
with no format change.

## 8. Measure first

Two answers are load-bearing and neither is known.

1. **Does a write in `,M` mode overwrite in place, or truncate?** The entire design rests on it.
2. **What does one `P` plus one `BINPUT#` cost?** It decides whether the scan blob is needed at all,
   and whether 250 records can be searched at a speed that feels alive.

Two more are cheap to settle at the same time.

3. The byte cost of a string array element, for the `DIM DB.FLD$(1, 31)` budget.
4. Whether a 16-bit signed path anywhere in the `P` argument caps the file at 32,767 bytes, which
   would be 511 records at stride 64.

## 9. Order of work

1. Measure the four above.
2. `DBFILE.INC.BL`, low and unbanked. Channels, `P` and `T`, block read and write. Prove it against a
   hand-made file.
3. `DB.INC.BL` on top. Schema, field arrays, navigation, split and join.
4. Move both into bank 5 behind `DBBANK.INC.BL`. Banking last -- a region that misbehaves is a silent
   hang with no line number.
5. `DBFORM`, then decide bank 4 or low.
6. `XBASE.BASL`, the bar and the panels.
7. v2: index in bank 6, `DB.SEEK`, the `MACPTR` scan blob, `DB.RELATE`.

Steps 1 to 6 do not constrain step 7. The index is derived data, built by one pass over an unchanged
file.

## 10. Reference

dBASE II source has never been released and would be 8080 assembly. The formats are public.

- dBASE II header: fixed 521 bytes, 32 fields maximum, descriptor `name[11] type length address`.
- dBASE III `.DBF`: offset 10-11 is bytes per record, descriptors from offset 32 at 32 bytes each,
  `0x0D` terminates the list, `0x20` and `0x2A` are the delete flags.
- Clipper's `DBU.EXE` is the ASSIST-equivalent admin, models relations across several open files, and
  ships its source in `CLIPPER5\SOURCE\DBU`.
- PCjs runs dBASE III 1.0 in a browser. archive.org has dBASE III PLUS 1.1 disk images.
- `github.com/carlosrabelo/gobi` is a dBASE II clone in Go with DBF read and write, NDX B-tree
  indexes and a BROWSE editor.
