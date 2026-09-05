# GPB.HELP

The GP.BASIC and BASL reference, on the machine. A scrolling master index over 43 topics, written
in GP.BASIC and built from `GPC-BASIC/` — the manual, the name register and the module banner
headers — by a script, so the help cannot drift from the library it documents.

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
| `?` | about | |
| ESC | quit | back — one link at a time, then the index |

**Find is case-insensitive and searches the index, not the text.** It runs against what is
already in memory, so it costs no disk at all; `STRCASE.GO` folds a *copy* of each entry, because
folding in place would rewrite the index itself.

**`X` writes ASCII, not a program.** It pulls the `:` lines out of the topic — the syntax block and
every example in it — and writes them with a header naming where they came from. `BASLOAD` it.

## What is in it

| category | topics | from |
|---|---:|---|
| Getting started | 2 | `GP-BASIC.md` §1–2 |
| GP.* core keywords | 11 | `GP-BASIC.md` §3 |
| BASL modules | 15 | `GP-BASIC.md` §4, plus the banner headers of `GUI`, `GUI2`, `MENUBAR`, `STASH` and `STASHFILE` |
| Globals and naming | 9 | `GP-BASIC.GLOBALS.md` |
| The traps | 1 | `GP-BASIC.md` §6 |

The five banner-only modules matter: **none of them appear in `GP-BASIC.md`'s tables**, so without
that pass they would be missing from the help entirely.

Each keyword topic gets the same card — **SYNTAX**, **WHAT IT COSTS** (ASM / BASIC / COMPOSITE, and
what that buys you), **DESCRIPTION**, **EXAMPLE PROGRAM**, **SEE ALSO** — because the tier is the
distinction the library is built on and it belongs next to the keyword, not in a table three
screens away.

[`GPC-HELP.md`](GPC-HELP.md) is the same content in one file, for reading on a PC. Also generated.

## Rebuilding the content

```
python samples/GPC-HELP/MKHELP.PY
```

Reads `GPC-BASIC/` and writes `HELP-TXT/H001.HLP`…`H043.HLP` and `HELP-TXT/GPB.HELP.IDX`, plus
`GPC-HELP.md` beside itself. **Everything the viewer reads is in the one subfolder**, opened
through the CMD path syntax `//HELP-TXT/:NAME` — what CMDR-DOS documents, and what a real SD
card wants; the emulator would also take a plain `HELP-TXT/NAME`, which is the form that would
not port. A run that produces fewer topics than the last one deletes the orphans.
`--src` and `--out` move either end; `--maxpage` changes where a long topic is split.

**It exits non-zero if a character had no ASCII mapping**, listing the code points. That check
exists because `−1` (U+2212, not the ASCII hyphen) shipped as `?1` — a substitution no eye catches
in 90 KB of generated text.

## Rebuilding the program

`BASLOAD` resolves `#INCLUDE` off the drive and `build_basl.py` uses `testing\` as the emulator's
filesystem root, so everything stages there first. `python` and `make` are off PATH; see
`documents/local.make`.

```
copy samples\GPC-HELP\GPB.HELP.BASL       testing\
copy samples\GPC-HELP\GPC-BASIC\*.INC.BL  testing\
xcopy /e /i samples\GPC-HELP\HELP-TXT     testing\HELP-TXT
python source\gpc\build_basl.py      GPB.HELP.BASL GPB.HELP.SRC.PRG
python source\gpc\compile_shared.py --embedded GPB.HELP.SRC.PRG GPB.HELP.PRG
```

then copy `GPB.HELP.PRG` back here. **EMBEDDED, not shared**, so this directory stands on its own
without a `GPB.RT.nnn.BIN` whose name carries a build number. 23,563 bytes.

**No `#AUTONUM`.** With `STRCASE.INC.BL` included it resolves label targets against the wrong step
and the compile stops with `UNKNOWN LINE NUMBER`.

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
the reading was free. So there is now nothing to skip — 38 files, and every open is the same price.

### The topic lives in a bank, and it is read once

A topic is read once, into RAM bank 9, and every repaint comes out of that. Only the index is on
the string heap.

Not the heap, because there is no room on it. Blitz's string heap costs **about 1.67 bytes per
character** (measured: 88 strings of 38 characters cost 5,280 bytes), and a program carrying this
much of the GUI library has about a kilobyte of workspace left over:

| | object bytes |
|---|---:|
| `GPB.INC.BL` alone | 12,331 |
| `+ THEME + STASH + MENUVERT + LINEINPUT + GUI` | 17,399 |
| `+ STRCASE + APPSYS` | 17,688 |
| `+ GUI2` (the listbox) | 19,306 |

The index alone is ~5,000 bytes of heap. A 120-line topic beside it is another ~7,000, and the
first build died with `OUT OF MEMORY` doing exactly that. A bank costs the workspace nothing.

**The line table is in the bank too**, at the front: four bytes a line — offset low, offset high,
length, kind — and the text above it, truncated at 78 characters because no row can show more.
Three BASIC arrays of 140 entries would have been 840 bytes of workspace, which is most of what
there is. Bank 9 is `HELP.TBANK`; bank 8 is `GUI.BANK` and holds the cells under an open dialog.

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
  changed the time not at all — 62/59 against 60/61. It stayed in regardless: it is about five
  fewer heap allocations a line, and the self-check build runs a kilobyte from `OUT OF MEMORY`.
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
cell. **Rows 1–28 are byte-identical, characters and attributes.** `STASH` was the first
implementation and is worth one warning if it ever comes back: `STASH.SAVE` and `STASH.RESTORE`
each select their own bank and do not put it back, so the row painter read the stash buffer as
text and the screen filled with `#G#U#I#`. `HELP.PAGE.ROW` re-selects `HELP.TBANK` every time for
that reason.

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
colour. Header `16`, footer `192`, worked out once at boot rather than per draw, because both are
painted on every page turn. Section headers inside a page are still white on black.

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

## `GPC-BASIC/` here has diverged, on purpose

`GPC-BASIC/GUI.INC.BL` in this directory draws the answers as **buttons** — `< OK >` in the panel's
own attribute with the nibbles swapped — where the library still prints a dimmed hint line with one
letter lit. `GUI.BUTTON`, `GUI.BUTTON.SIZE`, `GUI.BUTTON.WIDE`, `GUI.BUTTON.ROW` and `GUI.BTN.PAIR` are the
new routines. `GUI.YN.MARK` went the other way: the hint line it repainted no longer exists here.

It is here rather than in the master `GPC-BASIC/` so the look can be seen running before every
dialog in the tree changes; nothing else compiles against this copy. See TODO.md, "Buttons — decide
whether the library adopts them". The one thing it takes away is `GUI.YN`'s `GUI.HINT$`: "the first
Y and the first N in the line are lit as the keys" has nothing to light when the row is two buttons.

`GUI.SAY` — a message and one way out — **is** in the master library, and is what the three
"wrote 34 lines" / "not found" / "nothing to export" boxes use.

## The self-check

`GPB.HELP.BASL` carries a headless harness behind one flat symbol. **Comment out `#DEFINE
HELP.RELEASE 1`** and build as above; it runs instead of the viewer, prints to the log, and stops.
A BASL module has no dead code elimination, so leaving it in would be p-code every user carries.

**IT NO LONGER FINISHES, and that is the harness running out and not the viewer.** The `WHAT IS IN
GPC` category added six topics and seven index rows, and the check build — which carries its harness
on top of everything the viewer holds — now dies with `OUT OF MEMORY` partway through. The release
build has about 2,100 bytes free and is unaffected.

Two things make it run further, and the first is enough to reach the assertions that matter:

- **Build the check with a smaller `HELP.MAXIX`.** A row costs ten bytes of workspace whether it is
  used or not, so 120 against today's 95 is 250 bytes of headroom the check cannot spare. At 96 it
  gets through the whole index-and-topics pass. This is legitimate rather than a fudge: the check
  verifies the index that EXISTS, and the headroom is a release concern.
- **Do not stack another check on top of it.** Extra harnesses go in their own build.

Even at 96 it stops before the cross-reference and slide passes. **The fix is the standing one** —
move the index text into a bank the way the topic already is, which ends the workspace pressure
rather than trading against it. Until then the check proves the part that catches real damage.

It asserts the thing that cannot be checked by looking — that every row in the index still reaches
the topic `MKHELP.PY` meant it to:

```
INDEX ROWS 95                     ROWS WITH NO TOPIC RECORD 0
ROWS WITHOUT A TOPIC OR LENGTH 0  ROWS WHOSE LENGTH DISAGREES 0
ROWS OPENED 89                    LINES READ 6681
```

Every one of the 89 selectable rows opens a file in `HELP-TXT/` whose line 1 is a topic record, and
every line count in the index matches the file. Get any of those wrong by one and **the viewer shows
the wrong page rather than failing**, which is the failure nobody notices. The cross-reference and
search assertions come after this point and are where the memory runs out today.

The interactive loop is driven too, by pushing keys through the KERNAL's `kbdbuf_put` the way
`GPC-BASIC/MENUTST.EXP.BL` does — down, RETURN, PgDn, ESC, ESC, Y — through `HELP.INDEX` itself,
not a test double.

## Files

| | |
|---|---|
| `GPB.HELP.BASL` | the viewer |
| `GPB.HELP.PRG` | compiled, embedded, 23,563 bytes — what `help-demo.bat` runs |
| `MKHELP.PY` | the content build |
| `HELP-TXT/GPB.HELP.IDX` | the master index, 95 rows |
| `HELP-TXT/H001.HLP`…`H043.HLP` | one topic each |
| `GPC-HELP.md` | the same content, for a PC |
| `GPC-BASIC/` | the eight modules a rebuild needs, so it needs nothing from the master |
