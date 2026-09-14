# GPB.HELP

The GP.BASIC and BASL reference, on the machine. A scrolling master index over 74 topics, written
in GP.BASIC and built from `GPC-BASIC/` — the manual, the name register, the file list and the
module banner headers — by a script, so the help cannot drift from the library it documents.

Run it:

```
help-demo.bat
```

## Using it

The index is one long scroll. Category headings are highlight bars and cannot be selected;
topics are indented under them, sections under those.

| | on the index | in a topic |
|---|---|---|
| up / down | move the highlight | scroll a line |
| PgUp / PgDn | a screen at a time | a screen at a time |
| HOME / END | first entry / last | top / bottom |
| RETURN | open the topic | -- |
| `/` or `F` | find | |
| `N` | find the next match | |
| `L` | | the cross references, as a list |
| `X` | | write this topic's code out as a `.BL` |
| `T` | the next theme | the next theme |
| `?` | about | |
| ESC | quit | back — one link at a time, then the index |

**Find is case-insensitive and searches the index, not the text.** It reads the index out of its
bank and opens no file. `STRCASE.GO` folds a *copy* of each entry, because folding in place would
rewrite the index itself.

**`X` writes ASCII, not a program.** It pulls the `:` lines out of the topic — the syntax block and
every example in it — and writes them with a header naming where they came from. `BASLOAD` it.

## What is in it

| category | topics | from |
|---|---:|---|
| Getting started | 2 | `GP-BASIC.md` §1–2 |
| What is in GPC | 7 | `GP-BASIC.FILES.md` |
| GP.* core keywords | 23 | `GP-BASIC.md` §3 |
| BASL modules | 26 | `GP-BASIC.md` §4, plus the banner headers of `GUI`, `GUI2`, `MENUBAR`, `STASH` and `STASHFILE` |
| Globals and naming | 12 | `GP-BASIC.md` §5 and `GP-BASIC.GLOBALS.md` |
| The traps | 1 | `GP-BASIC.md` §6 |
| Compiler known bugs | 1 | `GP-BASIC.md` §8 |
| Memory and limits | 2 | `GP-BASIC.md` §7 |

A topic longer than 120 lines is split, and each part counts as a topic.

The five banner-only modules matter: **none of them appear in `GP-BASIC.md`'s tables**, so without
that pass they would be missing from the help entirely.

Each keyword topic gets the same card — **SYNTAX**, **WHAT IT COSTS** (ASM / BASIC / COMPOSITE, and
what that buys you), **DESCRIPTION**, **EXAMPLE PROGRAM**, **SEE ALSO** — because the tier is the
distinction the library is built on and it belongs next to the keyword, not in a table three
screens away.

[`GPC-HELP.md`](GPC-HELP.md) is the same content in one file, for reading on a PC.
[`GPC-HELP.WIN.md`](GPC-HELP.WIN.md) is that file with the page splits joined, one contents list,
and the cross references as links. [`GPC-HELP-TESTING.md`](GPC-HELP-TESTING.md) is the PC file
built over the working library in `samples/GPB-MODS-TESTING/GPC-BASIC/` — see below. All three are
generated.

## Rebuilding the content

```
python samples/GPC-HELP/MKHELP.PY
python samples/GPC-HELP/MKHELPWIN.PY
```

`MKHELP.PY` reads `GPC-BASIC/` and writes `HELP-TXT/H001.HLP`…`H074.HLP`, `HELP-TXT/GPB.HELP.IDX`
and `GPC-HELP.md`. `MKHELPWIN.PY` reads `GPC-HELP.md` and writes `GPC-HELP.WIN.md`.

**Everything the viewer reads is in the one subfolder**, opened through the CMD path syntax
`//HELP-TXT/:NAME` — what CMDR-DOS documents, and what a real SD card wants; the emulator would
also take a plain `HELP-TXT/NAME`, which is the form that would not port. A run that produces fewer
topics than the last one deletes the orphans. `--src` and `--out` move either end. `--maxpage`
changes where a long topic is split, 120 lines by default. `--nosections` leaves the section rows
out of the index.

**It exits non-zero if a character had no ASCII mapping**, listing the code points. That check
exists because `−1` (U+2212, not the ASCII hyphen) came out as `?1` — a substitution no eye catches
in generated text.

**WARNING: the committed `.HLP` files carry hand edits the masters lack.** A plain run puts the
longer master text back. To carry a master change into them, render the old masters and the new
into two scratch folders with `--src` and `--out`, `diff -u` the two renders, and `patch` the
committed files. Take a whole file only where the committed copy equals the render of the old
masters.

Thirteen hand-edited topics no longer match their index line counts: H001, H002, H003, H011, H013,
H014, H015, H022, H059, H060, H067, H069 and H071. The viewer's scroll limit and END come from the
index count. H007 is also hand-edited, and its line count still matches the index.

### The PC file, over the working library

```
python samples/GPC-HELP/MKHELP.PY --mods samples/GPB-MODS-TESTING/GPC-BASIC --md-only --md-name GPC-HELP-TESTING.md
```

`--mods` takes the module banner headers from another folder, and writes up **every** `.INC.BL` in
it that the manual does not document — not just the five in `BANNER_ONLY`. That is how a working
module `GP-BASIC.md` does not describe gets an entry. A plain run does not sweep, so the topic
numbering of the `.HLP` files does not move.

`--md-only` writes the Markdown and nothing else: no `.HLP` files, no index. That is the pairing
`--mods` wants: the X16 help stays built from the master library, and the PC file can document a
working copy beside it. `--md-name` picks the file.

Everything except the module entries still comes from `--src`. Splitting is off in `--md-only`,
since the page budget is the viewer's and part two of a split carries no Markdown.

## Rebuilding the program

It builds in this folder, with nothing staged into `testing\`. The source includes its modules as
`GPC-BASIC/NAME.INC.BL`, and `GPC.BIN` and `BASLOAD-GPC.BIN` sit beside it. `python` and `make`
are off PATH; see `docs/BUILDING.md`.

```
python source\gpc\samplesbuild.py GPB.HELP
```

That runs the two steps below, then copies `GPB.RT.nnn.BIN` and `GPC.RT.nnn.BIN` from `testing\`
into this folder. Git ignores the copies.

```
python source\gpc\build_basl.py     --drive samples\GPC-HELP GPB.HELP.BASL GPB.HELP.SRC.PRG
python source\gpc\compile_shared.py --drive samples\GPC-HELP GPB.HELP.SRC.PRG GPB.HELP.PRG GPB.HELP.MAP
```

The object is SHARED: it loads `GPB.RT.nnn.BIN` off the drive when it runs. 14,595 bytes.

**No `#AUTONUM`.** The directive sets the *step* between generated line numbers, not whether lines
are numbered, and the default step of 1 is the only one `STRCASE.INC.BL` survives. At any other step
its label jumps resolve to lines that were never generated: BASLOAD tokenises happily and GPC stops
with `UNKNOWN LINE NUMBER`.

### Removing dead code

`compile_shared.py` never removes dead code. `GPC.PRG` removes it when `REMOVE DEAD CODE?` is
answered `Y`. `GPC.BIN` removes it when line 5 of `GPC.INPUT` names a file. `GPC.INPUT` here is set
up for this program:

```
GPB.HELP.SRC.PRG
C.GPB.HELP.SRC.PRG
M.GPB.HELP.SRC.PRG
SHARED
D.GPB.HELP.SRC.PRG
```

The five lines are source, object, map, `SHARED`, and the removed-line list. Tokenise first, then run
the engine on this folder from the repository root:

```
bin\x16emu\x16emu.exe -rom bin\x16emu\rom.bin -fsroot samples\GPC-HELP -prg samples\GPC-HELP\GPC.BIN -run
```

It removes 74 lines and 646 bytes. `D.GPB.HELP.SRC.PRG` lists the removed BASIC line numbers. Git
ignores the three outputs. `GP-BASIC.md` §7, under Removing dead code, has the rules.

## The decisions, and the measurements behind them

### One `.HLP` per topic, not one per category

The first build packed the topics into five category files and addressed a topic by line number.
Measured on the X16, against a 41 KB `MODS.HLP`:

| skip to line | OPEN + skip | then read 27 lines |
|---:|---:|---:|
| 1 | 0 jiffies | 4 |
| 250 | 44 | 5 |
| 600 | 111 | 9 |
| 1000 | **204** | 7 |

**3.4 seconds to turn to a page near the end, growing with depth.** The skip was the entire cost;
the reading was free. So there is nothing to skip: one file a topic, and every open costs the same.

### The topic and the index live in banks

A topic is read once, into RAM bank 9 (`HELP.TBANK`), and every repaint comes out of that. The index
is read once at startup, into bank 10 (`HELP.IBANK`). Bank 8 is `GUI.BANK` and holds the cells under
an open dialog.

Neither goes on the string heap. Blitz's string heap costs **about 1.67 bytes per character**
(measured: 88 strings of 38 characters cost 5,280 bytes). With a topic on the heap, the first build
died with `OUT OF MEMORY` opening a 120-line topic. With the index on the heap, a twelve-link SEE
ALSO did the same. Moving the index into a bank gave back about 6,400 bytes of workspace for 432
bytes of p-code.

**The topic bank** holds a line table at the front, four bytes a line — offset low, offset high,
length, kind — for up to 140 lines, and the text above it. A line is truncated at 78 characters,
because no row can show more.

**The index bank** holds eight bytes a row at the front — text offset low and high, length, type,
topic, section line, topic length low and high — and the text above them. `HELP.MAXIX` is 250 rows:
2,000 bytes of records and 6,192 for text. Rows past the end are dropped.

`GUI2.INC.BL` went for the same reason: the section and cross-reference pickers are at most 12
items, which fit a screen, so `GUI.MENU` does the job and the listbox's 1,618 bytes buy nothing.

### A one-line scroll slides the text in VRAM; it does not repaint it

Repainting all 28 rows was not so much slow as ugly: `GP.FILL` blanked them and they came back one
at a time, so a held cursor key flickered. `HELP.PAGE.SHIFT` moves the text region up or down a row
instead, and the draw pass is then allowed to paint exactly one row — the one the slide exposed.
`HELP.ONLY` carries which.

The move is VERA to VERA. Both of VERA's data ports are aimed into the tile map, one a row ahead of
the other, and the KERNAL's `memory_copy` ($FEE7) is pointed at `$9F23` and `$9F24`: it does not
step a pointer that lands inside `$9F00`–`$9FFF`, so VERA's own auto-increment walks both ends and
the rectangle moves without a byte crossing the CPU's address arithmetic. Going down, both ports
run backwards (ADDRH bit 3) from the far end so the copy does not eat its own source.

**The bars are outside the rectangle**, so they neither move nor get repainted. The window is
screen rows 1–28; the title is row 0 and the status line row 29.

Measured on the bench in `testing/SCRLTST.BASL`, 50 slides each:

| one scroll step | jiffies |
|---|---:|
| `STASH` the rectangle out and back | 11.0 |
| VERA to VERA | **1.6** |
| painting the exposed row from the bank | 1.0 |

`GP.CHAR` a cell at a time beat building the row as a `CHR$` string and printing it, 1.0 against
1.6 — the concatenation allocates.

### Where the time actually was

The first version of all this made the cells move six times faster and **the scroll did not get
faster**, because the cells were never the cost: the topic was re-read from its file on every
keypress, an OPEN and a LINPUT# of up to 120 lines to find the one line a slide had exposed.

| one scroll step | jiffies |
|---|---:|
| full repaint of the 28 rows | 37.4 |
| slide, then re-read the file for one row | 36.8 |
| slide, then one row out of the bank | **2.6** |

Reading it once moved that cost to the front, where it was worse still — 158 jiffies, 2.6 seconds,
for the longest topic, `POKE`ing a character at a time. `HELP.STORE.ASM` is a `GP.ASM` blob that
copies a line into the bank and writes its four-byte record, with the bank held across both:

| loading the longest topic | jiffies |
|---|---:|
| `POKE` per character, line table in BASIC arrays | 158 |
| the text copied by the blob | 61 |
| the record written by the blob as well | **47** |
| — of which `LINPUT#` itself is | 22 |

**The four-byte record cost 23 jiffies, as much as reading the entire file.** Four banked `POKE`s a
line is 480 bank selects, and splitting the offset into two bytes is a float divide each time; the
blob has the bank already and splits the offset with a byte load.

Three things here were measured because guessing them got them wrong:

- **The per-line string work costs nothing.** Peeling the marker off each line with `LEFT$` and
  `MID$` looked like the obvious next target. Reading it through `GP.STRPTR` with `PEEK` instead
  changed the time not at all — 62/59 against 60/61. It stayed in: it is about five fewer heap
  allocations a line.
- **`memory_copy` cannot do the load**, though it does the slide. It takes no bank argument, and
  `BANK` in BASL applies only around a `PEEK` or a `POKE` — a raw `GP.CALL` runs with whatever
  BASIC left in `$00`. It loaded in 91 jiffies and got 214 of 218 test bytes wrong. Holding a bank
  across a KERNAL call is what `GP.ASM` is for.
- **`GP.STRPTR` points at the length byte**, not the first character. Without the `+ 1` the blob
  copied the length into the text and every line was wrong, but only 14% of them *looked* wrong,
  because a length of 32–126 is itself a printable character. The tell is that the first stored
  byte equals the stored length.

The slide is verified rather than eyeballed: the same offset reached two ways — five single-line
slides against one full repaint, and ten down plus ten back up against the same — compared cell by
cell. **Rows 1–28 are byte-identical, characters and attributes.**

### `&` in a button label marks the key

`"&OK"` draws `< OK >` with the `O` in the key colour and answers to `O` or `o`; `"&CANCEL"` to `C`
or `c`. The `&` is not drawn and **not counted in the width** — get that off by one and the box is a
cell too wide with the buttons off centre in it.

**The label is the only place the key is written down.** `GUI.YN` reads back whatever the drawn
button actually marked, so `GUI.BTN.ONE$ = "&SAVE"` / `"&DISCARD"` answers to S and D with nothing
else to keep in step. Measured: keys 83 and 68, and the two letters carry the highlight attribute.

**`GUI.TEXT` deliberately has no `&`.** Every printable key there belongs to the field, so an `O`
cannot close the dialog — it types an `O`. Marking a letter that does nothing is worse than marking
none.

The marked letter keeps the button's background and takes `THEME.WARN`'s foreground, so it reads as
part of the button rather than a hole in it. If a palette ever made those two equal it falls back to
the panel attribute, which contrasts by construction — the button being the panel reversed.

There is **no escape for a literal `&`**; a label that needs one cannot have an accelerator.

### The bars are reversed

`THEME.HI` trades an attribute's two nibbles, which is what turns white-on-black text into a
black-on-white **bar** — the same thing the buttons in `GPC-BASIC/GUI.INC.BL` do to the panel
colour. The header bar is `THEME.TITLE` reversed and the footer `THEME.DIMMED` reversed. Both are
worked out on a theme change, not at every page turn. `T` cycles CLASSIC, DARK and LIGHT. Section
headers inside a page are not reversed.

### CP437

A reference wants **both cases** (90 KB of prose in capitals is unreadable) and a dialog wants a
**frame**. Only one stock charset gives both for nothing:

| charset | lower case | line drawing | cost |
|---|---|---|---|
| PET upper/graphics (2) | no | yes | none — the machine boots in it |
| PET upper/lower (3) | yes | yes | a byte is not its own tile index, so every BASLOAD literal comes out case-swapped unless the font is re-indexed first — and the re-order buries the frame glyphs. This is what `samples/editor` does |
| ISO-8859-15 (1) | yes | **none** | one control code; frames fall back to `+ - \|` |
| **CP437 (7)** | yes | yes | `SETCHR 7` and one `POKE`. **R47 and later** |

So: charset 7, then `POKE 882, PEEK(882) OR 64` to say "the text is ASCII" — which is *true*, CP437's
low half being ASCII exactly — and `GP.BOX` handed the CP437 code points for its frame. No font
re-ordering anywhere. **`POKE`d, not `PRINT CHR$(15)`**: that control code sets the same bit but
also uploads the ISO font, throwing the line drawing away.

`APPSYS.RESTORE` hands the user's whole `$0372` byte back on the way out — charset number *and* the
flag, because `screen_set_charset` does not clear bit 6 on its own.

## `GPC-BASIC/` here

The ten modules `GPB.HELP.BASL` includes, so a rebuild needs nothing from the master library. The
build reads them from this folder. They are copies and are not kept in step: `MENUVERT.INC.BL` here
lacks the separator rows `GPC-BASIC/MENUVERT.INC.BL` has. Their headers still name `.BANK.INC.BL` twins and
`SHIM.*` files, which the master library no longer has.

## The self-check

`GPB.HELP.BASL` carries a headless harness behind one flat symbol. **Comment out `#DEFINE
HELP.RELEASE 1`** and build as above; it runs instead of the viewer, prints to the log, and stops.
With the symbol defined, the harness is not compiled at all.

It checks that every index row still reaches the topic `MKHELP.PY` meant it to. It opens the file
behind each topic and section row, and prints:

| line | on a pass |
|---|---|
| `INDEX ROWS` | 146 |
| `ROWS WITHOUT A TOPIC OR LENGTH` | 0 |
| `ROWS OPENED` | 138, every row but the eight category headings |
| `ROWS WITH NO TOPIC RECORD` | 0 |
| `ROWS WHOSE LENGTH DISAGREES` | 0 |
| `SECTIONS PAST THE END` | 0 |
| `LINES READ` | the topic lines, summed over every row opened |
| `CROSS REFERENCES RESOLVED` | the cross references, summed the same way |

It then searches the index for `strptr` and prints `FIND STRPTR LANDED ON ROW`, `FRE AT THE END`
and `SELFCHECK DONE`.

A length that disagrees does not stop the viewer. The thirteen hand-edited topics listed under
Rebuilding the content disagree today.

## Files

| | |
|---|---|
| `GPB.HELP.BASL` | the viewer |
| `GPB.HELP.PRG` | compiled SHARED, 14,595 bytes — what `help-demo.bat` runs |
| `GPC-BASIC/` | the ten modules the viewer includes |
| `HELP-TXT/GPB.HELP.IDX` | the master index, 146 rows |
| `HELP-TXT/H001.HLP`…`H074.HLP` | one topic each |
| `MKHELP.PY` | the content build |
| `MKHELPWIN.PY` | `GPC-HELP.md` to `GPC-HELP.WIN.md` |
| `GPC-HELP.md`, `GPC-HELP.WIN.md` | the same content, for a PC |
| `GPC-HELP-TESTING.md` | the PC file, over the working library |
| `GPC.PRG`, `GPC.BIN` | the compiler's front end and engine, for building in this folder |
| `GPC.INPUT` | the engine's five lines for this program, with dead code removed |
| `GPC.ERR.PRG` | turns a runtime error's address into a source line, using the map |
| `GPC.IMG.122.BIN` | the runtime a self-contained object carries |
| `BASLOAD-GPC.PRG`, `BASLOAD-GPC.BIN` | the tokeniser's front end and engine |
| `XT`, `XFMGR/` | the XFMGR file manager, for looking at an export. Dev only, not part of the sample |
| `.gitattributes` | keeps the `.HLP` and `.IDX` bytes as built |

Build outputs, ignored by git: `GPB.RT.nnn.BIN`, `GPC.RT.nnn.BIN`, `GPB.HELP.SRC.PRG`,
`GPB.HELP.SRC.SYM`, and the `C.`, `M.` and `D.` files a dead-code compile writes.
