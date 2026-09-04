# GPC-HELP

The GP.BASIC and BASL reference, on the machine. A scrolling master index over 38 topics, written
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
| RETURN | open the topic | follow a cross reference |
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

Reads `GPC-BASIC/` and writes `H001.HLP`…`H038.HLP`, `HELP.IDX` and `GPC-HELP.md` beside itself.
`--src` and `--out` move either end; `--maxpage` changes where a long topic is split.

**It exits non-zero if a character had no ASCII mapping**, listing the code points. That check
exists because `−1` (U+2212, not the ASCII hyphen) shipped as `?1` — a substitution no eye catches
in 90 KB of generated text.

## Rebuilding the program

`BASLOAD` resolves `#INCLUDE` off the drive and `build_basl.py` uses `testing\` as the emulator's
filesystem root, so everything stages there first. `python` and `make` are off PATH; see
`documents/local.make`.

```
copy samples\GPC-HELP\HELP.BASL           testing\
copy samples\GPC-HELP\GPC-BASIC\*.INC.BL  testing\
copy samples\GPC-HELP\*.HLP               testing\
copy samples\GPC-HELP\HELP.IDX            testing\
python source\gpc\build_basl.py      HELP.BASL HELP.SRC.PRG
python source\gpc\compile_shared.py --embedded HELP.SRC.PRG HELP.PRG
```

then copy `HELP.PRG` back here. **EMBEDDED, not shared**, so this directory stands on its own
without a `GPB.RT.nnn.BIN` whose name carries a build number. 22,603 bytes.

**No `#AUTONUM`.** With `STRCASE.INC.BL` included it resolves label targets against the wrong step
and the compile stops with `UNKNOWN LINE NUMBER`.

## The four decisions, and the measurements behind them

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

### The screen is the page buffer

A topic is read straight from its file to the screen and **not kept**. Only the index is resident.

That is a memory decision, not a style one. Blitz's string heap costs **about 1.67 bytes per
character** (measured: 88 strings of 38 characters cost 5,280 bytes), and a program carrying this
much of the GUI library has only a few KB of workspace to spend:

| | object bytes |
|---|---:|
| `GPB.INC.BL` alone | 12,331 |
| `+ THEME + STASH + MENUVERT + LINEINPUT + GUI` | 17,399 |
| `+ STRCASE + APPSYS` | 17,688 |
| `+ GUI2` (the listbox) | 19,306 |

The index alone is ~4,900 bytes of heap. Holding a 120-line topic as well would have been another
~7,000, and the first build died with `OUT OF MEMORY` doing exactly that. Since scrolling now
re-reads, and an open plus 27 lines is 4 jiffies, nothing is lost.

`GUI2.INC.BL` went for the same reason: the section and cross-reference pickers are at most 12
items, which fit a screen, so `GUI.MENU` does the job and the listbox's 1,618 bytes buy nothing.

### A one-line scroll slides the text; it does not repaint it

Reading the topic again on every keypress is cheap. **Repainting the whole screen was not** — not in
total time so much as in what it looked like: `GP.FILL` blanked all 30 rows and the 27 lines came
back one at a time, so a held-down cursor key flickered.

`HELP.PAGE.SHIFT` slides the text region up or down a row with `STASH` instead, and the read pass is
then allowed to draw exactly one row — the one the slide exposed. `HELP.ONLY` carries which.

**The bars are outside the rectangle, so they do not move and are not repainted.** The window is
screen rows 1–27; the title is row 0 and the status line is row 29, and neither is in the stash.

Two details that are not free to get wrong:

- **Bank 9, not `HELP.BANK`.** Bank 8 is `GUI.BANK` and holds the cells underneath an open dialog.
- **The clamp runs before the move is classified**, so a PgDn landing one line short of the bottom
  arrives as a delta of 1 and takes the fast path too.

`STASH` refuses a rectangle it cannot fit and says so in `STASH.OK`, so there is a way back: the
full repaint. Slower, never wrong.

Cost: **227 bytes** of object, 22,032 → 22,259.

Verified by reaching the same offset two ways and comparing the screens cell by cell — five
single-line slides against one full repaint at that offset, and ten down plus ten back up against
the same. **Rows 1–27 are byte-identical, characters and attributes.** The only row that differs is
29, which the full repaint blanks and the slide leaves alone, which is the point.

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

`HELP.BASL` carries a headless harness behind one flat symbol. **Comment out `#DEFINE
HELP.RELEASE 1`** and build as above; it runs instead of the viewer, prints to the log, and stops.
A BASL module has no dead code elimination, so leaving it in would be p-code every user carries.

**Do not stack another check on top of it.** The self-check build ends with about 1,000 bytes of
workspace, and adding a second harness beside it dies with `OUT OF MEMORY` partway through — which
reads like a product fault and is not one. Measured in the shipping configuration: **2,408 bytes
free** after the biggest topic, twenty slides, a dialog and a menu, and FRE does not move across the
slides, so the slide leaks nothing. Extra harnesses go in their own build.

It asserts the thing that cannot be checked by looking — that every row in `HELP.IDX` still reaches
the topic `MKHELP.PY` meant it to:

```
INDEX ROWS 89                     ROWS WHOSE LENGTH DISAGREES 0
ROWS WITHOUT A TOPIC OR LENGTH 0  SECTIONS PAST THE END 0
ROWS OPENED 84                    LINES READ 6381
ROWS WITH NO TOPIC RECORD 0       CROSS REFERENCES RESOLVED 194
```

Every one of the 84 selectable rows opens a file whose line 1 is a topic record, every line count in
the index matches the file, and all 194 cross references resolve to a row that is a topic. Get any
of those wrong by one and **the viewer shows the wrong page rather than failing**, which is the
failure nobody notices.

The interactive loop is driven too, by pushing keys through the KERNAL's `kbdbuf_put` the way
`GPC-BASIC/MENUTST.EXP.BL` does — down, RETURN, PgDn, ESC, ESC, Y — through `HELP.INDEX` itself,
not a test double.

## Files

| | |
|---|---|
| `HELP.BASL` | the viewer |
| `HELP.PRG` | compiled, embedded, 22,603 bytes — what `help-demo.bat` runs |
| `MKHELP.PY` | the content build |
| `HELP.IDX` | the master index, 89 rows |
| `H001.HLP`…`H038.HLP` | one topic each |
| `GPC-HELP.md` | the same content, for a PC |
| `GPC-BASIC/` | the eight modules a rebuild needs, so it needs nothing from the master |
