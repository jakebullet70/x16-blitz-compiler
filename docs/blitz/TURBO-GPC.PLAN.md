# TURBO GPC

Plan, 2026-10-02. TURBO GPC is the on-machine IDE for GPC-BASIC. It joins an
editor, BASLOAD-GPC and the GPC compiler into one edit, build and test loop.

The spike is built and measured. The editor is built in part, and Order says how
far. The relay is not built.

## Overview

The editor is a new GP.BASIC program. Its specification is MSEDIT, a Prog8 program
in `dos_tools/x16-MSEDIT`. A measurement spike gates that route. Every path passes
it. The fallback, MSEDIT forked into this repository, is not taken.

The GP.BASIC editor in `GPC-BASIC-TOOLS-SRC/edit` stays a sample. Its kernels and
its library modules carry over to the new editor.

The X16 runs one program at a time. The editor, the tokeniser, the compiler and
the program under test each take low RAM. The IDE is a relay of LOADs.
State crosses each hop in files.

## Decisions

| question | decision |
|---|---|
| name | TURBO GPC |
| editor base | a new GP.BASIC editor on MSEDIT's design, gated by the spike |
| editor base if the spike fails | MSEDIT, Prog8, forked into this repository |
| spike pass bar | each path at 1.5 times MSEDIT's jiffies or less |
| spike shape | one bench program a path; MSEDIT timed in a scratch copy |
| spike kernels | `GP.ASM` blocks in the editor's modules |
| editor source | `GPC-BASIC-TOOLS-SRC/TURBO-GPC/` |
| spike folder | `GPC-BASIC-TOOLS-SRC/TURBO-GPC/bench/`. It holds the benches only. |
| store | MSEDIT's `edoc` and `xarena` layout. The GPC edit sample's store has the same layout. |
| version 1 | three documents with F7 switching, and the relay |
| charset | MSEDIT's scheme: PETSCII in memory, ASCII on disk, an ISO mode per document |
| F5 | build and run, and any failure reloads the editor on the error line |
| other build steps | tokenise, compile and run are separate Build menu rows |
| keys | F5 build and run, F12 go to definition, the rest by ALT letter |
| error hand-back | an error file, with a screen scrape as the fallback |
| return after a run | a debug object chains to the editor on END and on a runtime error; F8 stays armed |
| runtime error to source | an editor region reads the map with the GPC.ERR logic |
| F1 | a viewer region opens the help topic for the word under the cursor |
| project | a `.MAKE` lists `.PDEF` files, the GPC.GUI model |
| project forms | the IDE chains to GPC.GUI and GPC.GUI chains back |
| loose file, no `.PDEF` | the first F5 asks interpreter or compile and offers to write a `.PDEF` |
| tool home | the IDE lives in `/GPC/` with a launcher at the root |
| screen | 80x30 only |
| memory | runs on 512 KB, uses more banks when they are present |
| first slice | the spike |

## Components

| component | language | state |
|---|---|---|
| TURBO GPC editor | GP.BASIC, `GP.ASM` kernels | three documents with open, save, find, go to line, new and quit, the menu bar, the file picker, and selection, cut, copy and paste. `TURBO.PRG` is 7,567 bytes. |
| GPC edit sample | GP.BASIC, `GP.ASM` kernels | 4,291 source lines, `EDIT.PRG` 30,097 bytes, `EDIT.OVL` 28,685 |
| MSEDIT | Prog8 | v0.9.389, 11,499 source lines, `edit.p8` is 5,095 |
| BASLOAD-GPC.PRG | plain BASIC | front end, prompts for one source name |
| BASLOAD-GPC.BIN | 64tass | engine at `$6000`, name poked to `$BF00` in bank 0 |
| GPC.PRG | BASL | front end, prompts and writes `GPC.INPUT` |
| GPC.BIN | 64tass | engine, reads `GPC.INPUT`, stops at READY |
| GPC.GUI | GP.BASIC | `.MAKE` and `.PDEF` forms |
| GPC.ERR | GP.BASIC | runtime address to BASIC line, file and nearest label |
| GPC.HELP | GP.BASIC | indexed topics in `HELP-TXT/` |

### What MSEDIT has

- Three documents. A holds 6,000 lines, B and C 2,500 each.
- An F5 path that saves, writes `.ED.RUN` at the root and chains to the ROM BASLOAD.
- F8 armed through `pfkey` to reload the editor at the same file and line.
- A scrape of the BASLOAD error line off the screen on reload, held in `berr`.
- A per-folder `.EDIT.SESSION` that reopens the three documents.
- A generic chain to another program, `ovl_chain_load` at `edit.p8:410`.
- Overlay banks: picker 8, clipboard 9, misc 10, viewer 11, picker records 12,
  menus 13. Document banks start at 14.

### What MSEDIT lacks

- It calls the ROM BASLOAD. It does not know BASLOAD-GPC or GPC.
- Syntax colouring knows 94 words. It has no `GP.*` word, no `#` directive, no
  label and no `$hex` rule.
- Low RAM has 535 bytes free at v0.9.285. The figure is not re-measured at
  v0.9.389. `misc.ovl` is full. Every new feature is a banked overlay.

## The spike

The spike measures whether GP.BASIC with `GP.ASM` kernels reaches MSEDIT's speed
on the paths an editor spends its time in. The bench programs are throwaway. The
modules they time are the editor's.

### Known costs

| path | plain GP.BASIC | GP.BASIC and `GP.ASM` | MSEDIT |
|---|--:|--:|--:|
| render one 80-cell row, 1,000 times | 2,320 j | 18.8 j | 67 j |
| line table insert, 100 lines, 10 times | 435 j | 5 j | not measured |
| load a 2,432-byte file | 365 j | 35 j | not measured |

The row figures are in `GPC-BASIC-TOOLS-SRC/edit/readme.md`. The other two are
the results of `bench/SLOTBEN.BASL` and `bench/LOADBEN.BASL` in that folder,
recorded in `TODO.md`.

| p-code | cycles |
|---|--:|
| empty `FOR` and `NEXT` | 453 |
| one keyword statement | about 530 |
| one `GOSUB` into a module | about 2,570 |

One jiffy at 8 MHz is 133,333 cycles. That is about 250 statements or 50 calls.

P-code decides and assembly moves bytes. No loop over bytes or over rows is
p-code.

### Paths

| path | the bench does |
|---|---|
| type one character | insert into the edit buffer, paint one row |
| move inside the pane | open the next line in the edit buffer, paint two rows, status numbers |
| scroll one line | open the next line in the edit buffer, slide the pane one row, paint two rows, status numbers |
| page | open the line a pane away, paint 28 rows, status numbers |
| RETURN | split a line, insert a slot, repaint from the cursor row down |
| delete line | delete a slot, repaint from the cursor row down |
| load | 2,000 lines into the store |
| save | 2,000 lines to a file |
| find | one needle across 2,000 lines, a match on the last line |

A bench does the whole path: the p-code that decides, the store access and the
render. No bench times the assembly alone.

### Method

- The bench programs are in `GPC-BASIC-TOOLS-SRC/TURBO-GPC/bench/`. The modules
  they time are the editor's, in the folder above.
- A BASLOAD `#INCLUDE` cannot name `../`. `spike.py` copies the editor's modules,
  `TGKEYS.BIN` and `GPC-BASIC/` into `bench/` for a build. After the run it
  removes them, with everything the build and the run wrote. `--keep` leaves them.
- `python spike.py NAME` builds a bench, runs it at real speed with syntax
  colouring off and prints `NAME.RES`. `NAME colour` runs it with colouring on.
  `NAME both` builds once and runs with colouring off, then on.
- `SCROLLBEN` times the move and the scroll. The cursor-down key takes both paths.
  `PAGEBEN` times the page keys. `EDITBEN` times the edit and file paths in one
  run. `CLASSBEN` checks the colouring and times nothing.
- `UNDOBEN` checks the undo records and times undo and redo.
- `KEYBEN` checks the key map and the edit keys, and times the keys the other
  benches do not. `keymodel.py` writes its keys and holds a model of what they do.
- `TURBOTEST` checks the program and times nothing. `spike.py` makes
  `TURBOTEST.BASL` from `TURBO.BASL` with nine replacements: the `#SAVEAS` and
  `#SYMFILE` names, the three `#GPC` output names, the empty-key line of
  `TURBO.KEY.WAIT`, the exit, the settings store's name and one `#INCLUDE`. It
  stops unless each occurs once. `TURBOTEST-DRIVER.BASL` puts groups of keys from
  `TURBOTEST.KEY` into the KERNAL key buffer with `kbdbuf_put`, `$FEC3`, 10 keys a
  group at most. The program's `GET` loop and `LINEINPUT`'s read them.
  `turbomodel.py` writes the groups and holds what the program must do with them.
- The fixture is `FIX2000.TXT`. It is 2,000 lines of BASL source in 92,048 bytes,
  with CRLF line endings. A line averages 44 characters. The longest line is 218.
  `mkfixture.py` writes it.
- `TI` is read inside the machine at real speed. `-warp` is never used.
- `SCROLLBEN` and `PAGEBEN` measure the empty repeat loop and subtract it. `EDITBEN`
  leaves it in.
- Each bench reads its result back and checks it.
- MSEDIT is timed on the same paths by a driver that calls its key dispatch, in a
  scratch copy. The MSEDIT repository is not changed.
- Both run on one emulator, one ROM and one fixture file.

### Measured

The figures are jiffies on the 2,000-line fixture. The first six paths are jiffies
for one key. Load, save and find are jiffies for the whole operation. The bar is 1.5
times MSEDIT with syntax colouring off.

| path | bench | GP.BASIC, colouring off | GP.BASIC, colouring on | MSEDIT, colouring off | MSEDIT, colouring on | bar |
|---|---|--:|--:|--:|--:|--:|
| move inside the pane | `SCROLLBEN` | 0.22 | 0.26 | 0.59 | 1.07 | 0.89 |
| scroll one line | `SCROLLBEN` | 0.60 | 0.66 | 2.42 | 3.03 | 3.63 |
| page | `PAGEBEN` | 0.80 | 1.83 | 6.2 | 21.6 | 9.3 |
| type one character | `EDITBEN` | 0.19 | 0.25 | 0.54 | 0.93 | 0.81 |
| RETURN | `EDITBEN` | 1.86 | 2.16 | 13.00 | 15.1 | 19.5 |
| delete line | `EDITBEN` | 1.76 | 2.00 | 13.04 | 14.2 | 19.6 |
| load | `EDITBEN` | 75 | 75 | 210 | 217 | 315 |
| save | `EDITBEN` | 42 | 42 | 156 | 155 | 234 |
| find | `EDITBEN` | 26 | 27 | 210 | 222 | 315 |

`SCROLLBEN` times 27 moves in 6 jiffies and 300 scrolls in 180 jiffies. `PAGEBEN`
times 60 pages in 48 jiffies each way. Both compare the pane with the store read in
BASIC. No cell differs. `SCROLLBEN` also compares the pane after the last scroll
with a full repaint. The two match.

`EDITBEN` times 200 typed characters in 38 jiffies, 50 RETURNs in 93 and 50 line
deletes in 88. Each edit writes its undo records inside its time. It runs MSEDIT's
sequence from the load on, without the moves, scrolls and pages. It compares the
pane with the store after the RETURNs, after the deletes and after the find. No
cell differs. Its load time includes the first paint. The load ends with 2,000
lines. The find stops on the last line, at its fifth character.

`spike.py` compares the file `EDITBEN` saves with the fixture. Lines 101 to 105
differ. Each is 40 typed characters and then the fixture's line.

With colouring on, `SCROLLBEN` times the 27 moves in 7 jiffies and the 300 scrolls
in 198. `PAGEBEN` times 60 pages in 110 jiffies each way. `EDITBEN` times the 200
typed characters in 49 jiffies, the 50 RETURNs in 108 and the 50 line deletes in
100. Colouring adds about 4,900 cycles to a painted row.

`CLASSBEN` paints every line of the fixture in colour and writes the class of every
column to `CLASSBEN.CLS`. `spike.py` compares the file with the same rules written
in Python, in `tgkeys.py`. 0 of 2,000 lines differ.

Each bench writes its last pane to `NAME.PANE`, a character byte and an attribute
byte for each cell. `spike.py` compares it with the pane the rules give. The panes
of `SCROLLBEN`, `PAGEBEN` and `EDITBEN` differ in 0 bytes with colouring on and with
colouring off. The pane of `CLASSBEN` is scrolled 17 columns sideways and differs in
0 bytes.

`msedit_bench.py` times MSEDIT. It copies MSEDIT's sources to
`source/scratch/msedit-bench`, pastes the driver `MSBENCH.P8` into the copy of
`edit.p8`, builds the copy with MSEDIT's `prog8c.jar` and runs it. The driver calls
`editor_key()`, so a key is MSEDIT's whole path. The line-number gutter is on. The
driver does not fit in MSEDIT's low RAM, so the copy's `act_replace` and
`comment_apply` are emptied. No timed path reaches them.

The MSEDIT sequence is: load, 27 moves, 300 scrolls, 60 pages down, 60 pages up, 40
characters typed at column 0 of each of lines 101 to 105, 50 RETURNs at the end of
line 105, 50 line deletes, save, find `ZZNEEDLE` from the first line. The term is on
the last line. Save and find are called below their keys, because those keys end in
a one second message. The saved file differs from the fixture in the five lines
typed into.

Both editors record every edit for undo. `UNDO.PUSH`, a `GP.ASM` kernel, writes a
record. A record costs about 0.08 to 0.10 jiffies, the call of `UNDO.GROUP.BEGIN`
included. With colouring off, RETURN writes two records and takes 1.86 jiffies
against 1.70 with no undo. Delete line writes one and takes 1.76 against 1.66. The
first character typed into a line writes one. The characters after it write none.

`UNDOBEN` makes six edits: 40 characters typed into a line, a RETURN inside them,
three line deletes, and 5 characters typed into another line. It undoes the six,
redoes them and undoes them again. Each of the three loops asks for a seventh edit
and gets none. It saves the document after the edits and after each loop.
`spike.py` compares each file with the same edits made in Python. No line differs
in any file. The pane after the last undo differs in 0 bytes.

`UNDOBEN` also sets the ring to 4 records and makes four edits that write seven
records: two RETURNs, a line delete and a RETURN. A full ring loses every record of
its oldest edit. Two edits are undone and two are not. No line of the saved document
differs.

The six undos and the empty seventh take 12 jiffies with colouring off and 16 with
colouring on. The six redos and their empty seventh take 11 and 16. Each one
repaints the pane. An undo or a redo is about 2 jiffies with colouring off and 2.7
with colouring on. MSEDIT's undo is not timed.

`KEYBEN` sends 657 keys through the key map: cursor keys, Ctrl+Left, Ctrl+Right,
Home, End, the page keys, typed characters, Tab, RETURN, Backspace, Delete and
delete line. Among them are joins of two lines, a join that is refused, a line
filled to 250 characters and a pane scrolled sideways. Moves with Shift select. A
typed character, RETURN, Backspace and Delete take a selection out. Ctrl+C, Ctrl+X,
Ctrl+V, Ctrl+Insert, Shift+Delete and Ctrl+A copy, cut, paste and select all. The
keys end with a selection over three lines. `keymodel.py` makes the same edits in
Python. No line of the saved document differs. The cursor and the selection's
anchor end on the same line and column. The pane differs in 0 bytes, with the
selection's highlight in it.

`KEYBEN` then undoes all 118 edits and saves the document. No line differs from the
fixture. It redoes the 118 and saves again. No line differs from the edited
document.

RETURN starts the new line with the cursor line's leading spaces, counted up to the
cursor. Counting them adds 0.04 jiffies to a RETURN. Two lines join only when they
hold 250 characters or fewer together. MSEDIT cuts the joined line at 250.

`KEYBEN` times these keys through the key map on line 100, in jiffies a key. The
document is saved after them. No line differs from the fixture. MSEDIT is not timed
on these keys.

| key | keys timed | colouring off | colouring on |
|---|--:|--:|--:|
| type one character | 40 | 0.25 | 0.30 |
| Backspace | 40 | 0.23 | 0.30 |
| Delete | 40 | 0.23 | 0.28 |
| cursor right | 40 | 0.20 | 0.25 |
| RETURN at column 0 | 20 | 1.95 | 2.40 |
| Backspace at column 0, which joins two lines | 20 | 1.65 | 2.00 |
| Ctrl+Right | 40 | 0.28 | 0.40 |
| Ctrl+Left | 40 | 0.28 | 0.43 |

A typed character takes 0.25 jiffies through the key map and 0.19 in `EDITBEN`,
which calls `VIEW.TYPE.CHAR`. With colouring on it takes 0.30 and 0.25. The key map
figures are 10 and 12 jiffies over 40 keys. A total over 40 keys carries 1 or 2
jiffies of noise. Backspace and Delete cost the same as a typed character within
that noise. Each of the three moves the line's bytes in a kernel.

The 40 Ctrl+Rights start at column 0 of line 100, where the joins end. The 40
Ctrl+Lefts start where the Ctrl+Rights stop. Some of the moves cross to another
line.

`TURBOTEST` types 74 keys in 20 groups into the program. It types on the empty
document, opens `W.DOC` over it and answers yes to the discard question. `W.DOC`
is a copy of the fixture. It edits, finds a term, finds it again and looks for a
term that is nowhere. It answers no to the quit question and saves. It starts a
new document and saves it under the name `N.DOC`, typed at the prompt. It opens
`W.DOC` again, moves and saves. The driver then dumps the pane and the two bars
and types Esc and Y.

`turbomodel.py` makes the same edits in Python. No line of `W.DOC` or of `N.DOC`
differs. The cursor ends on the same line and column, line 29 and column 91. The
pane differs in 0 bytes, with its top at line 2 and its left at column 18. The four
numbers count from 0. The two bars have 0 faults in the title, the labels, the line
and column numbers, the change mark, the file name and the `Saved` message. The
program leaves through its own exit. `TURBOTEST.PRG` is 11,722 bytes.

`TURBOTEST` does not cover Ctrl with PgUp, PgDn, Left and Right, the cursor keys
inside a prompt, or how the screen looks. Its driver puts keys in the KERNAL key
buffer. The program reads the modifier keys from the keyboard as they are held, so
the driver cannot give it one. `KEYBEN` covers the dispatch of Ctrl with PgUp, PgDn,
Left and Right, and of Shift and Ctrl with the selection and clipboard keys.

### Modules

The editor is in `GPC-BASIC-TOOLS-SRC/TURBO-GPC/`.

| file | holds |
|---|---|
| `TURBO.BASL` | the program: the key loop, the title bar, the status bar, the prompt, the yes or no question, and the commands find, find next, replace, save, open, new and quit |
| `TG-STORE.BASL` | the line table, the arena, the edit buffer, character insert and remove, the word scans, line split, the copies a join makes, line remove, new document, load, save, find |
| `TG-UNDO.BASL` | the undo ring, the redo ring, and the routines that note an edit, take it back and put it in again. `UNDO.PUSH`, which writes a record, is a `GP.ASM` kernel. The rest is BASIC. |
| `TG-VIEW.BASL` | row paint, the syntax classifier, pane slide, status numbers, and the keys: cursor, word left, word right, page, Home, End, first and last line, type, Tab, RETURN, Backspace, Delete, delete line, undo, redo, find next |
| `TG-KEYS.BASL` | the key map: a table that gives each key code its action, and the dispatch |
| `TGKEYS.BIN` | the keyword table. `tgkeys.py` writes it from the two keyword groups of `GPC.HELP.BASL`. |
| `tgkeys.py` | the writer of `TGKEYS.BIN`, and the colouring rules in Python |
| `build.py` | the build: it writes `TGKEYS.BIN`, tokenises `TURBO.BASL` and compiles it SHARED |
| `GPC-BASIC/` | the library copies: `GPB`, `APPSYS` and `LINEINPUT`, which the program includes, and `MEM`, which only the benches include |

The benches are in `bench/`.

| file | holds |
|---|---|
| `SCROLLBEN.BASL`, `PAGEBEN.BASL`, `EDITBEN.BASL`, `CLASSBEN.BASL`, `UNDOBEN.BASL`, `KEYBEN.BASL` | the six benches |
| `TG-BENCH-CHECK.BASL` | the pane checks, the pane dump and the colouring switch. Nothing in it is timed. |
| `TURBOTEST-DRIVER.BASL` | the driver that types the keys of `TURBOTEST.KEY` into the program |
| `spike.py` | the build and the run of one bench, and the checks of what it wrote |
| `keymodel.py`, `turbomodel.py` | the keys of `KEYBEN` and of `TURBOTEST`, and a model of what they do |
| `FIX2000.TXT`, `mkfixture.py` | the fixture and its writer |
| `MSBENCH.P8`, `msedit_bench.py` | the MSEDIT driver and its build and run |

The edit buffer, the block buffer and the screen code table are `%` arrays in low
RAM. Each is 256 bytes. `GP.ARRPTR` gives the address of each. A kernel reads them
with any bank selected.

`VIEW.PAINT` paints a run of rows in one call. It finds each line's record through
the line table, writes the gutter number, and turns each byte into a screen code
through the screen code table. The cursor line comes from the edit buffer.

With colouring on, `VIEW.PAINT` calls two more kernels for each row.
`VIEW.CLASS.SCAN` copies the line into a buffer and gives each column a class:
plain, directive, string, number, comment, or a word to look up. `VIEW.CLASS.WORDS`
looks up each word in the keyword table, which is indexed by first letter. The word
becomes a statement, a function or plain. A cell's attribute
is the ink of its class over the background of its row. The rules are those of
GPC.HELP's source viewer. The classifier keeps no state between lines, so a `REM`
line inside a `GP.ASM` block is a comment.

The keyword table, the inks, the text buffer and the class buffer are in one RAM
bank. `VIEW.SETUP` sets it to bank 15.

An undo record is 8 bytes: what the edit did, the line, the edit's number, and the
line table slot the line had before the edit. The arena never frees a record, so
the slot still points at the old text and the text is not copied. MSEDIT copies the
old line into its arena for each record. An undo swaps the slot back, or opens or
closes a slot in the line table. Its inverse goes on the redo ring.

The two rings of a document hold 32 records each, which keeps 16 edits or more. The undo
ring is at $B800 and the redo ring at $B900 of the document's first line table bank, past
its slots. MSEDIT keeps 12 records. Bit 7 of a record's first byte marks the first record
of an edit, so a full ring drops its oldest edit whole. A routine that moves the arena's
records must empty both rings.

`UNDO.PUSH` is the kernel that writes a record. It reads the line's slot from the
line table, places the record, drops the oldest edit of a full ring and writes the
8 bytes. Undo and redo apply through the same kernel. The first record and the
count of each ring are in two `%` arrays. BASIC copies them into two scalars before
the kernel and back after it, in four statements. The byte order of a `%` array's
elements is not established.

A `GP.ASM` block cannot name a label in another block. Each of the two kernels
stores its own entry address when `VIEW.SETUP` reaches it with a `GOSUB`.
`VIEW.PAINT` writes the two addresses into the operands of its two `JSR $FFFF`
instructions.

### Result

A path passes when its figure is at or under the bar. Every path passing selects
the GP.BASIC editor. A path that fails with its kernel in assembly selects the
fallback.

Every path passes, with colouring off and with colouring on, and with every edit
recorded for undo. The spike selects the GP.BASIC editor.

## The program

`TURBO.BASL` is the editor. It holds three documents, A, B and C, and shows one. Syntax
colouring is on.

### Build and run

- `python build.py` in `GPC-BASIC-TOOLS-SRC/TURBO-GPC/` writes `TGKEYS.BIN`,
  tokenises `TURBO.BASL` and compiles it SHARED. `TURBO.PRG` is 7,567 bytes. The
  SHARED p-code cap is 22,016.
- `USER-RUNS/turbo-gpc-demo.bat` runs it in a window. The emulator mounts
  `GPC-BASIC-TOOLS-SRC` and `turbo-gpc-demo.bas` changes into `TURBO-GPC`, so the
  runtime comes from `/GPC/`. The bat passes `-noemucmdkeys`. Ctrl+F and the
  emulator's other Ctrl keys reach the editor, and the emulator's own keys, Ctrl+V
  paste among them, are off.
- `python spike.py TURBOTEST` in `bench/` checks it. `TURBOTEST.PRG` is 8,624 bytes.
  The script opens `W.DOC` in the file picker with End and RETURN. `W.DOC` is the
  last file of the bench folder, which the drive lists in name order. It finds again
  with F3. It finds twice more with a term picked from the find history, with Up, and
  with Up and Down. It picks File, Exit and answers no. In document B it redoes and then undoes
  through the Edit menu, with Esc, Right and R, then Esc, Right and U. It selects all of
  B, one line, and finds the selected text. Then it selects
  all, copies, cuts and pastes in B through the Edit menu, because a key the driver
  types carries no modifier. It quits with Esc, X and Y. The run starts with a settings
  store that holds a key of another program and a find history of one term. At the end
  the store holds the other key and the four terms, newest first. Every check reads 0 and
  `QUIT` reads 1. Free memory at the end of the script was 8,210 bytes before the clipboard,
  and is not measured since.

### Screen

| row | holds |
|---|---|
| 0 | the menu bar: File, Edit, Search, Window and Help from column 0, the name `TURBO GPC` at column 66, and A, B and C at columns 76 to 78 |
| 1 to 28 | the pane |
| 29 | the status bar |

| status bar column | holds |
|---|---|
| 1 | `Line` and the cursor's line |
| 12 | `Col` and the cursor's column |
| 22 | `*` when an edit was made since the last load or save |
| 24 | the file name |
| 46 | a message. The next key clears it. |

The menu bar and the status bar take the X16 theme's bar colour, `THEME.BAR`, 193.
`APPSYS` remembers the screen mode, the charset and the text colour at the start and
puts them back at the exit.

`*` shows when `UNDO.GROUP%` differs from its value at the last load or save. An
undo back to the saved text still shows `*`.

Charset 5 is set at the start. The five ISO glyphs of Charset are not stamped.
`TURBO.ASCII.TO.PETSCII` turns an ASCII literal into PETSCII before it is drawn.

### Keys and commands

The key loop reads `GET`, and reads the modifiers from `$FEC0` for every key.

The editor follows Notepad++ where the X16 delivers the key, and keeps MSEDIT's
function keys.

| key | action |
|---|---|
| Ctrl+S or F2 | save |
| Ctrl+Z | undo |
| Ctrl+Y | redo |
| Ctrl+L | delete line |
| Ctrl+F or F6 | find |
| F3 | find next |
| Ctrl+H | replace |
| Ctrl+G | go to line |
| Ctrl+N | new |
| Ctrl+O | open |
| F7 | next document |
| F1, F5 | help, build |
| Ctrl+PgUp, Ctrl+PgDn | the first line, the last line |
| Shift with a cursor move | select |
| Ctrl+X or Shift+Delete | cut |
| Ctrl+C or Ctrl+Insert | copy |
| Ctrl+V | paste |
| Ctrl+A | select all |

MSEDIT's Ctrl+E for delete line and Ctrl+U for redo have no action here. Ctrl+G is go
to line, not find next.

The selection runs from the anchor to the cursor. A cursor move with Shift starts it or
moves its far end. A move without Shift ends it. A selected cell takes dark grey paper,
`VIEW.SELECT.PAPER%`, and keeps its ink. `VIEW.SELECT.PAINT`, a `GP.ASM` kernel, marks the
rows after `VIEW.PAINT`. A line inside the selection is marked to the pane's right edge.
Shift+Home and Shift+End arrive as 147 and 132, and Shift+Delete as 148 with Shift held.

A typed character and RETURN replace the selection. Backspace and Delete take it out. Tab
and every command but find and replace end it. Copy keeps it.

The clipboard is document 3 of the store, in bank 40. It holds 512 lines and 6,400 bytes.
A copy that does not fit goes to the file `TURBO.CLP` in the current directory instead, and
shows `Copied to TURBO.CLP`. A paste then reads that file in after the last line and
rotates the lines into place with `DOC.SLOT.ROTATE`. A paste that finds the file gone shows
`TURBO.CLP not found`. A failed write shows `TURBO.CLP not written`, leaves the clipboard
empty, and a cut then leaves the document as it was. Copy with no
selection takes the cursor line, and its paste goes in below the cursor line, as MSEDIT
does. Other text goes in at the cursor. A paste or a deletion that would make a line over
250 characters is refused. An edit with more undo records than the ring keeps, 32, empties
the rings.

Ctrl+C and Stop send code 3, and the KERNAL raises its stop flag for code 3. The runtime
polls that flag and ends the program with BREAK. `TURBO.STOP.OFF` points the KERNAL's stop
vector at a stub that answers no, as the GPC edit sample does. `TURBO.STOP.ON` puts it back
at the exit.

Ctrl+S and Ctrl+Y arrive as 19 and 25, the codes of Home and Delete. `TG-KEYS` keeps a
32-byte Ctrl table after the 256-byte key table. A code under 32 with Ctrl held takes
its action from the Ctrl table. Ctrl+Delete also arrives as 25 with Ctrl held, so it
redoes.

The Ctrl tables of the X16 keyboard layouts in RAM bank 0, layout IDs 4 and 132, give
Home, End, Backspace, Tab and Return no code. Ctrl+Home and Ctrl+End cannot give the
first and the last line, so Ctrl+PgUp and Ctrl+PgDn give them.

Esc and the Alt keys go to `MENU.KEY` in `MENUKEY` before the key map. Esc opens the
File dropdown. Alt with a bar letter opens that menu. Alt pressed and let go alone
lights the bar. Esc is not in the key map. The key map in `TG-KEYS.BASL` gives the
other keys their actions.

Ctrl+Right and Ctrl+Left move a word. A word is a run of characters that are not
spaces. Ctrl+Right goes past the rest of the word, then past the spaces after it.
At the end of a line it goes to column 0 of the line below. Ctrl+Left goes back
past the spaces, then to the start of the word in front of them. At column 0 it goes
past the last character of the line above. The rules are MSEDIT's `ed_word_right`
and `ed_word_left`.

| command | does |
|---|---|
| find | asks for a term in an input box and moves the cursor to the next place it starts. The box starts with the selected text when the selection is on one line, and with the last term when not. Up and Down in the box walk the last six terms. The selection ends when the find runs, and stays when the box is left with Esc. |
| find next | finds the last term again |
| replace | asks for a term in the find box, then for its replacement in a second box. The replace box starts with the last replacement, and Up and Down in it walk the last six. The run starts at the first line. Each place the term starts is selected, and the status bar asks `Replace?  Yes  No  All  Esc`. Y, RETURN and Space replace it, N passes it, A replaces it and every place after it, Esc and Stop end the run. An empty replacement takes the term out. A replacement that would make a line over 250 characters is passed over. The run is one edit for undo, and the cursor ends at the last place asked about. The status bar then shows `Replaced` and the count, or `Not found`. |
| save | writes the document. It prompts for a name when the document has none. |
| open | picks a file in the file picker and loads it. The pick can change the current directory. |
| new | starts an empty document with no name. `DOC.NEW` makes it one empty line. |
| go to line | an input box takes up to 4 digits. The cursor goes to column 0 of that line. A number past the last line goes to the last line. |
| save as | asks for a name in an input box and saves the document under it. The box starts with the document's name. It does not ask before it overwrites a file. |
| quit | the File menu's Exit row. It asks a yes or no question first. |
| next document | F7. A comes after C. |
| document A, B, C | shows that document. Picking the one on screen does nothing. |
| about | a message box: `TURBO GPC, the GP.BASIC editor` |
| build, help | F5 and F1. Both show `Not in this version`. |

Save as, quit, document A, B and C, and about, commands 6 and 10 to 14, have no key.
They run from menu rows. Go to line is command 15.

Open, new and quit ask before changes are lost. The quit question counts the edits of
all three documents.

### Menus

| menu | rows |
|---|---|
| File | New Ctrl+N, Open... Ctrl+O, Save Ctrl+S/F2, Save As..., a separator, Exit |
| Edit | Undo Ctrl+Z, Redo Ctrl+Y, a separator, Cut Ctrl+X, Copy Ctrl+C, Paste Ctrl+V, a separator, Select All Ctrl+A, Delete Line Ctrl+L |
| Search | Find... Ctrl+F/F6, Find Next F3, Replace... Ctrl+H, a separator, Go to Line... Ctrl+G |
| Window | Next Document F7, a separator, Document A, Document B, Document C |
| Help | Help... F1, About |

A menu row runs an action of the key map or a command of `TURBO.COMMAND`. Undo, redo
and delete line are actions of the key map, run through `KEYS.RUN` in `TG-KEYS.BASL`.
`TURBO.MENU.ACTIONS$(n)` holds one action byte for each row of dropdown n. The
`TURBO.ACT` defines in `TURBO.BASL` name the actions.

Dropdowns and dialogs have a drop shadow: `MENU.SHADOW%` is 1 and `DLGSHADOW` is 1.
Dropdowns are framed with the dialogs' six screen codes, listed in step 3 of The GUI
in the editor. The glyph table is the `%` array `TURBO.FRAME.GLYPHS%`, and
`MENU.DROPSTYLE` holds its address. An array does not move and a string can.

Hot letters are yellow, colour 7, `TURBO.HOT.COLOUR`. `TURBO.GUI.SETUP` runs
`MENU.THEME` after `THEME.SELECT`, then sets `MENU.BARHOT%` and `MENU.HOTATTR%`.
`GP.SUB DLGHOTKEY, colour` gives the dialogs' buttons and the picker's footer the same
colour. Colour 0, the default, keeps the theme's `BORDER` foreground.

### Three documents

The store holds three documents, A, B and C. F7 shows the next, and A comes after C.
Each document has its own line table, arena, undo rings, line limit, file name, cursor
and scroll.

A switch stores a dirty edit buffer, keeps the state of the document it leaves, and
paints the one it shows. A document shown for the first time is one empty line with no
name.

On the menu bar the letter of the document on screen takes the theme's text colour,
97. The letter of another document with an edit since its last load or save is yellow
on the bar colour, 199.

RETURN does nothing in a document at its line limit or over it. A load checks the limit
after each block of 255 bytes and stops at the first block that takes the document to
the limit or past it. A full arena stops it the same way. Either shows
`File too big, loaded in part`.

### Bank map

| bank | holds |
|---|---|
| 0 | the KERNAL's |
| 1 | the runtime's bank code |
| 2 to 5 | line table of A. Bank 2 also holds A's undo and redo rings. |
| 6, 7 | line table of B. Bank 6 also holds B's undo and redo rings. |
| 8, 9 | line table of C. Bank 8 also holds C's undo and redo rings. |
| 10 to 12 | the GUI's code and five routines of `TURBO.BASL`. The GUI's cost lists them. |
| 13 | the menu builder's text, `MENU.TEXTBANK`. The first `MENU.BEGIN` claims it. |
| 14 | pieces from `BANKMGR.SPACE`: the file picker's list, 6,144 bytes, and the TURBOTEST key script, 1,024 bytes, in TURBOTEST only. The clipboard is not placed. |
| 15 | keyword table, inks and the classify buffers |
| 16 to 37 | arena of A |
| 38 | the code of `TG-FIND` and `CHECK`: find, replace, the histories, the About box and the status bar's fields |
| 39 | the code of `TG-CLIP` and `KVBIN` |
| 40 | the clipboard, document 3 of the store: its line table to $A5FF, its arena from $A600 |
| 41 | the code of `LINEINPUT` and the TG modules other than `TG-CLIP` |
| 42 to 52 | arena of B |
| 53 to 63 | arena of C |

A has a line limit of 7,936 and B and C of 3,840. A load can end up to 254 lines over
the limit, and each line table has room for 256 lines over it. A bank above 63 is not
used. `DOC.PLACE` in `TG-STORE.BASL` and `UNDO.SELECT` in `TG-UNDO.BASL` set these
banks. `TURBO.GUI.SETUP` in `TURBO.BASL` claims 2 to 12 and 15 to 63 before the first
`BANKMGR.SPACE`.

A line table bank's slots end at $B7FF. In a document's first table bank the undo ring
takes $B800 to $B8FF and the redo ring $B900 to $B9FF. The rest of $B800 to $BFFF in each
table bank is free. A code bank past bank 12 comes from the top of A's arena. Bank 41 is
the first.

Dialogs keep the screen under them in VRAM through `STASHVRAM`, the library's default, and
take no bank. The clipboard takes bank 40, and its code bank 39. The editor's settings are keys in the shared
store `/SETTINGS.KVB`, read and written by `KVBIN.INC.BL`, and take no bank.

The find history is the keys `TG.FIND.1` to `TG.FIND.6`, newest first, and the replace
history `TG.REPLACE.1` to `TG.REPLACE.6`. The first find or replace of a run reads a history,
and stops at the first key the store does not hold. A find or a replace writes the keys
whose entry changed. An empty replacement is not kept. The first write of a run makes the store when it is not on the drive
or is an empty file. `KVBIN.PUT` cannot: its read and write open makes an empty file on
hostfs, and `KVBIN` then takes the file for one that is not a store. TURBOTEST's store is
`SETTINGS.KVB` in `bench/`.

### The GUI's cost

The editor holds the GUI in three regions. The sizes are the offset of the last line of
each region in `TURBO.MAP`. A region holds at most 8,188 bytes.

| bank | holds | bytes, about |
|---|---|---|
| 10 | `BANKMGR`, `STASHVRAM`, `THEME`, `MENU`, `MENUPULL`, `TURBO.PETSCII`, `TURBO.ADDROW`, `TURBO.MENU.SETUP` | 7,950 |
| 11 | `GUI`, `COMBO`, `CHECK` | 7,820 |
| 12 | `GUI-DIALOGS`, `FILEIO`, `FILEDIR`, `FILEPICK`, `TURBO.GUI.SETUP`, `TURBO.SETUP` | 7,480 |

`TURBO.MENU.SETUP`, `TURBO.GUI.SETUP` and `TURBO.SETUP` run once at the start.
`MENUKEY` executes `BANK`, and no region calls it. `MENU.KEYS.ON` runs from the main
code after `TURBO.GUI.SETUP`.

`TURBO.PRG` is 7,567 bytes. Low memory p-code is about 3,560 bytes: `TURBO.BASL`,
`MENUKEY` 906, `STASH` 443, `APPSYS` 114 and `TG-LOW` 40. The TG kernels that write `$00`
are `GP.ASM LOW` and stay in low memory too. Bank 41 holds about 6,830 bytes of p-code:
`LINEINPUT`, `TG-STORE`, `TG-UNDO`, `TG-VIEW` and `TG-KEYS`. The other TG kernels follow
it in the bank, and the bank is nearly full. Bank 39 holds `TG-CLIP`, `KVBIN` and the find
history, about 2,900 bytes.

With the setup in low memory, `TURBO.PRG` is 15,192 bytes and low memory p-code is
10,577. TURBOTEST's free memory is then 645 bytes after the first dialog and the picker,
and the next input box raises OUT OF MEMORY.

`KVBIN.INC.BL` runs from bank 39. Bank 12 has about 700 bytes free, too few for it.

`source/scratch/guimeasure/measure.py` builds the editor with the library modules that
the menu bar, the dialogs, the file picker and the settings need. The program it builds
is not run, and its figures are an estimate. `python measure.py packed` puts the modules
in three regions:

| bank | modules | bytes | spare |
|---|---|---|---|
| 10 | `BANKMGR`, `STASHVRAM`, `THEME`, `MENU`, `MENUPULL` | 6,761 | 1,427 |
| 11 | `GUI`, `COMBO`, `CHECK` | 7,499 | 689 |
| 12 | `GUI-DIALOGS`, `FILEIO`, `FILEDIR`, `FILEPICK`, `KVBIN` | 6,153 | 2,035 |

A region holds at most 8,188 bytes. `STASH` (480 bytes) and `MENUKEY` (906) stay in low
memory, because each holds a `BANK` statement. `LINEINPUT` also stays in low memory.

| | without the GUI | with the GUI |
|---|---|---|
| object | 11,357 | 13,515 |
| scalar bytes | 572 | 3,242 |
| workspace | 12,800 | 10,496 |

Scalar bytes have a ceiling of 4,096, which leaves 854 for the rest of the editor. About
400 of the library's scalars are floats. A float takes 6 bytes and an integer 2, so floats
are most of the scalar bytes the library adds.

The workspace holds the scalars, the arrays and the strings. With the GUI, 7,254 bytes
are left for arrays and strings. The library's arrays take about 1,300 of them once
they are made.

Each region costs workspace. Nine regions, one for each module group, leave 9,216 bytes
of workspace.

The menu store is 6,656 bytes. The editor puts it in bank 13 with `#DEFINE MENU.TEXTBANK`.

`DOS.INC.BL` and `FILEIO.INC.BL` both define `DOS.CMD`, so one program cannot include
both. `FILEDIR` needs `FILEIO`. The editor uses `FILEIO`.

### The GUI in the editor

Decided 2026-10-03. The work runs in this order.

1. The library change. No module names a bank. Done.
   - A module that stores data takes a bank and an address from its caller.
   - `BANKMGR.SPACE` takes a size and returns `BANKMGR.BANK` and `BANKMGR.ADDR`. It hands
     out consecutive pieces at startup. It never takes one back.
   - The editor claims its fixed banks first: 2 to 12, 15, and the arenas in 16 to 63.
     Then it asks for space. The menu store lands in bank 13.
   - The modules this change touches take `%` for their scalars, public names included.
     Every caller in the repository changes in the same pass. `int16scan.py --check`
     checks each program. GPBMODS, XBASE, GPB.HELP and GUIFRMT are rebuilt.
   - An address and a `FOR` index stay float. A `%` holds -32,768 to 32,767. A bank
     address is 40,960 or more.
2. The GUI in the editor. Done.
   - The `GP.BANKED` blocks sit at the top of `TURBO.BASL`. The region of `LINEINPUT` and
     the TG modules comes first, because `GUI.INC.BL` reads `LINEINPUT`'s `#DEFINE`s. A
     verb's callers sit below its `GP.DEFPROC`.
   - `TG-LOW.BASL` holds the TG modules' `BLOAD` and `BANK` statements, outside every
     region. A TG kernel that writes `$00` is `GP.ASM LOW` and puts the caller's bank
     back on every exit.
   - The status-bar prompts are removed: `TURBO.PROMPT`, `TURBO.CONFIRM`, and the
     `LINEINPUT` lines of `TURBO.SETUP`.
   - Find, Replace and Save as call `INPUTBOX`. Open calls `PICKFILE`, step 5.
   - Before a document's changes are lost, the editor asks with `ASK3`: Save, Discard
     and Cancel, as MSEDIT does. Quit asks with `ASKYNEX`, and the focus starts on No.
   - "Saved", "Loaded" and "Not found" stay on the status bar. "Save failed" and "File
     too big" open a `MSGBOX`.
3. Dialogs save the screen under them. Done.
   - `GP.SUB DLGSAVESCREEN, mode` sets `GUI.SAVEMODE%`. `GUI.SAVE.VRAM`, the default, keeps
     the cells in `STASHVRAM`, as the menu dropdowns do. `GUI.SAVE.BANK` keeps them in the
     `DLGRESET` space. A combo's dropdown saves where its dialog does.
   - The editor uses VRAM. It calls neither `DLGSAVESCREEN` nor `DLGRESET`.
   - `TURBO.GUI.SETUP` frames boxes with `DLGGLYPH 1` and six screen codes: `$70`, `$6E`,
     `$6D` and `$7D` for the corners, `$40` for the horizontal edge and `$5D` for the
     vertical. `GP.BOX` style 1 draws its vertical edge as the letter B under charset 5.
   - `GUI.TYPEAHEAD%` non-zero keeps the keys queued ahead of a dialog. The TURBOTEST
     driver sets it.
4. The menu bar. Done.
   - The library's menu matches a shifted PETSCII letter, 193 to 218, to the hot key
     of 65 to 90. A label made PETSCII keeps its hot key.
5. The file picker. Done.
   - `PICKFILE` in `FILEPICK.INC.BL` does what MSEDIT's picker does.
   - The box is 44 columns wide on an 80-column screen, at columns 18 to 61 and rows 3
     to 26. It has a title bar on its top edge, ` Open File ` in TURBO, 20 rows, and a
     footer bar on its bottom edge. The footer reads `Del  Folders:On   Esc`, or `Off`,
     with D and F in the hot letter colour. The box has the dialogs' frame, shadow and
     VRAM save.
   - The list is `..`, then the directories, each with `/` before its name, then the
     files, in the drive's order. A name that starts with a dot is left out. Blocks and
     type are shown.
   - Up, Down, PgUp and PgDn move and stop at the ends. Home and End go to the first and
     the last row.
   - RETURN on a file returns it. RETURN on a directory, `..` among them, changes into it.
     The picked file is in the current directory when the pick returns, so the editor's
     current directory can change.
   - D deletes the file after a Y on the footer. A directory is not deleted.
   - F shows or hides the directories. The setting lasts from one pick to the next.
   - Esc and Stop return "" and climb back to the directory the pick started in. From a
     directory above that one they do not go back down.
   - The listing is read once a directory. F walks it again without the drive, through
     `FILE.DIR.REWIND` in `FILEDIR`.
   - `PICKLABELS on$, off$, ask$` sets the two footer texts and the delete question. A
     `*` in the question stands for the file's name. TURBO passes the three through
     `TURBO.PETSCII`.
   - TURBO's list space is `TURBO.PICK.BYTES`, 6,144 bytes from `BANKMGR.SPACE`, in
     bank 14. It holds 95 entries. MSEDIT's picker holds 157.
   - Save As stays an input box. It does not ask before it overwrites a file. MSEDIT asks
     `Overwrite existing file? Y/N`.

WARNING: The editor runs charset 5, thin upper and lower case. An ASCII literal shows each
letter in the other case there. Every text the editor hands the library goes through
`TURBO.PETSCII` first: dialog text, menu rows, and the button labels `DLGLABELS` sets.

### Not built

- Five clipboard slots on disk.
- The settings, in `/SETTINGS.KVB`.
- The relay. See Data flow: the relay.

## Charset

The editor follows MSEDIT's scheme.

- The screen font is charset 5, thin PETSCII, in stock order. One font serves
  both document modes.
- `TURBO.GLYPHS.SETUP` gives the eight ASCII characters charset 5 lacks their
  ISO glyphs: `\`, `^`, `_`, the backtick, `{`, `|`, `}` and `~`. It writes them
  over the reverse glyphs at screen codes `$F8` to `$FF` and points the row
  kernel's table at them. A charset reload erases them. Call it after
  `VIEW.SETUP` and after every `APPSYS.SETCHR`.
- A file is ASCII on disk.
- A document is in PETSCII mode or in ISO mode. A PETSCII document is PETSCII in
  memory, and load and save convert. An ISO document is ASCII in memory.
- ISO mode also sets bit 6 of `$0372`, which makes the keyboard deliver ISO codes.
- The row kernel turns each byte into a screen code through a table, one table a
  mode. The lookup is 6 cycles on a 31-cycle cell.
- The stock order keeps `PRINT` and the PETSCII box glyphs usable.

WARNING: a BASL string literal is ASCII. The text of a PETSCII document is
PETSCII. A literal that is compared with that text, or drawn on the PETSCII
screen, is made PETSCII first.

## Data flow: the relay

    editor  --F5-->  BASLOAD-GPC  -->  GPC.BIN  -->  object  -->  editor
               \          |               |            |
                \         +---- fail -----+--- fail ---+-->  editor, cursor on the line

1. The editor saves every modified document.
2. It writes its state to `.ED.RUN` and sets cwd to the project folder.
3. It writes `GPC.INPUT` from the `.PDEF`.
4. It chains to the BASLOAD-GPC front end.
5. A clean tokenise chains to the compiler.
6. A clean compile runs the object.
7. The object returns to the editor on END, or the user presses F8.
8. A failure at any hop writes the error file and loads the editor.
9. The editor reads the error file, opens the named file and puts the cursor on
   the line. The message shows on the status bar.

### Hops that exist

- Editor to any program: a `LOAD`. MSEDIT's form is `ovl_chain_load`.
- BASLOAD-GPC to the next program: a clean tokenise loads and runs `.BASLOAD.NEXT`
  from the source's device. A failed tokenise never chains.
- BASLOAD-GPC failure: the engine leaves the message at `$BF00`, ending in the
  file and line. The source line is also in `R1H`..`R2H`, 24 bits, 0 when the
  fault has no line.
- Reload of the editor: the `/ED` launcher, and F8 through `pfkey`.

### Hops that do not exist

- BASLOAD-GPC.PRG takes its source name from a prompt only. It flushes the key
  buffer first, so the name cannot be typed in ahead.
- GPC.BIN has no exit to another program, on success or on failure.
- A compiled object has no exit to another program on END or on a runtime error.

## Files the relay writes

| file | where | writer | reader | state |
|---|---|---|---|---|
| `.ED.RUN` | root | editor | editor | MSEDIT's format |
| `.EDIT.SESSION` | project folder | editor | editor | MSEDIT's format |
| `GPC.INPUT` | project folder | editor | GPC.BIN | exists, five lines |
| `.BASLOAD.NEXT` | project folder | editor | BASLOAD-GPC.BIN | hook exists |
| tokenise job | project folder | editor | BASLOAD-GPC.PRG | proposed, name not chosen |
| error file | not chosen | each tool | editor | proposed, name not chosen |

`.BASLOAD.NEXT` is a program, not a name. The editor writes a short BASIC stub
that loads the compiler engine. It deletes the stub on return.

WARNING: a `.BASLOAD.NEXT` left behind makes every later tokenise in that folder
chain to the compiler.

### Error file, proposed

The error file is four lines of text.

| line | holds |
|---|---|
| 1 | the stage: `B` tokenise, `C` compile, `R` run |
| 2 | the file name, empty when the tool has none |
| 3 | the line number, or the runtime address for stage `R` |
| 4 | the message |

A tokenise error carries an exact source file and line. A compile error carries
a BASIC line of the tokenised program. GPC.ERR turns a BASIC line into a file and
the nearest label above it, with that label's source line. An exact source line
for a compile or runtime error is not established.

## Build menu

| row | does |
|---|---|
| Build and Run, F5 | the whole relay |
| Build | the relay, stopping after a clean compile |
| Tokenise | BASLOAD-GPC only |
| Run | the last object |
| Release | cruncher, then a SHARED compile with no debug exit |
| Next Error, Previous Error | walk the error file |
| Project... | chain to GPC.GUI |

A build result panel shows the object size, the free bytes and the overlay sizes.
Where the compiler leaves those numbers for the editor is not established.

## Editor features

| feature | source |
|---|---|
| F12 on a label or an `#INCLUDE` | the symbol file, or a scan of the open documents |
| label list popup | the same |
| F1 help on the word under the cursor | `HELP-TXT/`, shown by a viewer region |
| find in files | the project's includes |
| `GP.*` colouring, directives, labels, `$hex` | the classifier of the spike, in `TG-VIEW.BASL`. It does not colour a label. |
| `GP.*` insert popup | a list popup |
| primary file | F5 builds the `.PDEF` source, whatever document is on screen |

F12 on `#INCLUDE` is an entry in MSEDIT's `TODO.md`. The `charpick` popup filed
there, for BASLOAD `{}` tokens, is the widget the `GP.*` insert popup shares.

## Directories

    /ED                        root launcher
    /.ED.RUN                   editor state across a hop
    /GPC/                      the IDE and its overlays, BASLOAD-GPC, GPC, the runtimes
    /GPC/GPC-BASIC/            the library
    /GPC/HELP-TXT/             the help topics
    /BASIC-SRC/MYPROG/         MYPROG.BASL, its .PDEF, everything a build writes

- The project folder is pinned. The picker may browse anywhere. A build restores
  cwd to the project folder first.
- Every output lands in cwd.
- A tool opens from `/GPC/NAME` from any folder.
- An include is tried in cwd, then in `/GPC/`. The third try, `/GPC/GPC-BASIC/`,
  is gap 1 in `TOOL-HOME-LAYOUT.RESEARCH.md`.

WARNING: the host file system does not overwrite through an absolute path. Write
a bare name after a `chdir`.

WARNING: a command-channel call straight before an open corrupts the read.

Both warnings are MSEDIT's own findings, in its `TODO.md` and at `edit.p8:3233`.

## Assembly to agree first

The route for each row is `GP.ASM` or 64tass. It is agreed before work starts. The
spike kernels, the undo note, character delete, line join and the word moves are
`GP.ASM` and are written. No other row is written.

| change | where |
|---|---|
| spike kernels, written: line fetch, line store, character insert, line split, slot insert and delete, load by block, save, find scan, row paint with the screen code table, classify scan, keyword lookup, pane slide, status numbers | `TG-STORE.BASL`, `TG-VIEW.BASL` |
| the undo note, written: read a line's slot, place the record, drop the oldest edit of a full ring, write the record | `TG-UNDO.BASL` |
| character delete, written: take one character out of the edit buffer | `TG-STORE.BASL` |
| line join, written: copy the edit buffer into the block buffer, add the block buffer's characters to the end of the edit buffer | `TG-STORE.BASL` |
| word left and word right, written: a scan of the edit buffer | `TG-STORE.BASL` |
| `GPC.INPUT` line 6, the program to load after a clean compile | `source/application/source/file-io/control.asm`, `source/compiler/start.asm` |
| `GPC.INPUT` line 7, the program to load after a failed compile | the same |
| compile error written to the error file | `CompilerErrorHandler`, `source/compiler/_library.asm:4201` |
| debug exit: chain to the editor on END and on a runtime error | the runtime; the site is not located |
| third `#INCLUDE` try | `BASLOAD-GPC/src/option.inc` |

Line 6 is the design agreed for BUILD ALL.

## Work with no assembly

- BASLOAD-GPC.PRG reads a job file in place of its prompt, writes the error file
  on a failure and loads the editor. It is plain BASIC.
- GPC.GUI finds its engine in `/GPC/` and gains an exit back to the editor.
- The editor's logic is GP.BASIC.

## Order

1. The spike. It is done.
2. The editor core: three documents, edit, undo, find and replace, the menu bar,
   the file picker, the ISO glyphs, an About box and a scroll bar. It is built: the
   edit keys, the key map, the store, the menu bar, the file picker, find and replace
   in `TG-FIND.BASL`, and the program with open, save, go to line, new, quit and F7.
3. The relay with no assembly: job file, `.BASLOAD.NEXT` stub, `GPC.INPUT` from a
   fixed answer set, screen scrape for a compile error, F8 to return. Steps 2 and
   3 are version 1.
4. The assembly hooks: lines 6 and 7, the compile error file, the debug exit.
5. The crash line region.
6. `.PDEF` in the editor, the chain to GPC.GUI, the loose-file question.
7. The `/GPC/` layout: third include try, host scripts, USER-RUNS, release.
8. Editor features: colouring, wrap, session, F12, label list,
   F1 help, find in files.

If the spike selects the fallback, step 2 forks MSEDIT into this repository,
renames it, removes the 40-column layout and re-measures low RAM.

## Open

- Whether a `REM` line inside a `GP.ASM` block is coloured as assembly. The
  classifier would need the state of the lines above it.
- The names of the job file and the error file, and the error file's folder.
- An exact source line for a compile error and for a runtime error.
- Which banks the debug exit may assume survive the program under test.
- How the bank budget scales between 512 KB and 2 MB.
- The on-disk program name. The family form is `GPC.` plus a word. `TURBO.PRG` is
  the working name.
- The byte order of a `%` array's elements, which `UNDO.PUSH` would need to read
  the ring state without the two scalars.
- Whether the ROM BASLOAD path stays for the interpreter run of a loose file.
- What the Release row does when the cruncher refuses a source.
