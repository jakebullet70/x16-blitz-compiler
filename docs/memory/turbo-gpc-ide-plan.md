---
name: turbo-gpc-ide-plan
description: "TURBO GPC is the on-machine IDE: a new GP.BASIC editor on MSEDIT's design; the speed spike passed on all nine paths on 2026-10-02, with syntax colouring on and off and an undo record on every edit; the source is in GPC-BASIC-TOOLS-SRC/TURBO-GPC and TURBO.PRG holds three documents, switched with F7, with open, save, find, new and quit; the undo note, character delete, line join and word left and right are GP.ASM kernels; the menu bar and the file picker are built, the keys follow Notepad++; the bank map is in the plan; layout, how to build and test, decisions, numbers and what is next"
metadata:
  node_type: memory
  type: project
  originSessionId: f2ef33fe-6565-4754-b1b1-05111d41cf23
  modified: 2026-10-03T14:34:00.080Z
---

**TURBO GPC is the name of the on-machine IDE, chosen by the user on 2026-10-02.** The plan is
`docs/blitz/TURBO-GPC.PLAN.md`.

**The editor is a fresh GP.BASIC program with MSEDIT (Prog8, `dos_tools/x16-MSEDIT`) as its
specification.** The user prefers GPC over Prog8 for it and chose this over forking MSEDIT. A
measurement spike gated the route and every path passed, so MSEDIT is not forked. The GP.BASIC
`edit` sample stays a sample.

## Layout, build and test

- The editor is in `GPC-BASIC-TOOLS-SRC/TURBO-GPC/`: `TURBO.BASL` (the program), `TG-STORE.BASL`,
  `TG-UNDO.BASL`, `TG-VIEW.BASL`, `TG-KEYS.BASL`, `tgkeys.py`, `TGKEYS.BIN`, `build.py`, and
  `GPC-BASIC/` (the library copies: GPB, APPSYS and LINEINPUT, which the program includes, and MEM,
  which only the benches include).
- `bench/` holds only the benches: the six `*BEN.BASL`, `TG-BENCH-CHECK.BASL`,
  `TURBOTEST-DRIVER.BASL`, `FIX2000.TXT`, `MSBENCH.P8`, `spike.py`, `keymodel.py`, `turbomodel.py`,
  `mkfixture.py`, `msedit_bench.py`.
- A BASLOAD `#INCLUDE` cannot name `../`. `spike.py` copies the editor's modules, `TGKEYS.BIN` and
  `GPC-BASIC/` into `bench/` for a build and removes them after the run, with everything the build
  and the run wrote. `--keep` leaves them. Edit a module in `TURBO-GPC/`, never the copy.
- The clean-up deletes every file in `bench/` whose name does not end in `.BASL`, `.py`, `.P8` or
  `.TXT`. A note or a data file of another kind put there is gone after the next run.
- Build the editor: `python build.py` in `TURBO-GPC/`. It writes `TGKEYS.BIN`, tokenises
  `TURBO.BASL` and compiles it SHARED. `TURBO.PRG` is 11,357 bytes. The SHARED p-code cap is 22,016.
- Run a bench: `python spike.py NAME` in `bench/` tokenises, compiles, runs at real speed with
  colouring off and prints `NAME.RES`. `NAME colour` runs with colouring on. `NAME both` builds
  once and runs with colouring off, then on.
- Test the program: `python spike.py TURBOTEST` in `bench/`.
- Run it in a window: `USER-RUNS/turbo-gpc-demo.bat`. It mounts `GPC-BASIC-TOOLS-SRC`, and
  `turbo-gpc-demo.bas` changes into `TURBO-GPC`, so the runtime comes from `/GPC/`. The bat has not
  been run. Its three driver lines ran headless and the program stayed in its key loop.

## The spike, started 2026-10-02 on the user's go

- `mkfixture.py` writes `FIX2000.TXT` (2,000 lines, 92,048 bytes).
- Kernels are `GP.ASM` blocks, the route the user agreed ("ASM blobs are on the table where speed is
  an issue").
- A path passes at 1.5 times MSEDIT's jiffies or less. A bench times the whole path, decide plus
  fetch plus render, never the kernel alone.
- Modules: `TG-STORE.BASL` (line table, arena, edit buffer, character insert and remove, the word
  scans, line split, the join copies, line remove, `DOC.NEW`, block loader, save, find),
  `TG-UNDO.BASL` (the undo and redo rings; `UNDO.PUSH` is a `GP.ASM` kernel, the rest is BASIC),
  `TG-VIEW.BASL` (row paint, the syntax classifier, pane slide, status numbers, and the keys: cursor,
  word left, word right, page, Home, End, first and last line, type, Tab, RETURN, Backspace, Delete,
  delete line, undo, redo, find next), `TG-KEYS.BASL` (the key map: a 256-byte
  table from key code to action, and `KEYS.DISPATCH`), `TG-BENCH-CHECK.BASL` (pane checks, the
  colouring switch, the pane dump).
- Benches: `SCROLLBEN`, `PAGEBEN`, `EDITBEN`. `EDITBEN` saves `EDITBEN.OUT`, and `spike.py` compares
  it with the fixture.
- `CLASSBEN` times nothing. It dumps the class of every column of all 2,000 lines, and `spike.py`
  compares the dump with the rules in `tgkeys.py`. Every bench also dumps its last pane, and
  `spike.py` compares it byte for byte. `tgkeys.py` writes `TGKEYS.BIN`, the keyword table, from
  the two keyword groups of `GPC.HELP.BASL`.
- `UNDOBEN` makes six edits, undoes them, redoes them and undoes them again, and tests a full ring
  of 4 records with four edits that write seven. It saves the document after each step and
  `spike.py` compares each file with the same edits made in Python.
- `KEYBEN` feeds 548 keys from `KEYBEN.KEY` to `KEYS.DISPATCH`, undoes every edit and redoes it.
  `keymodel.py` writes the keys and models them in Python. `spike.py` compares four saved
  documents, the cursor and the pane with the model.
- The store is MSEDIT's `edoc` and `xarena` layout. The sample's `ED-STORE.BASL` is already a port of
  that layout, so there was nothing to choose.

**The spike is measured and every path passes, 2026-10-02, with colouring off and with colouring
on, and with an undo record written on every edit.** Checks green. Jiffies a key for the first six,
jiffies for the whole operation for load, save and find. The bar is 1.5 times MSEDIT with colouring
off.

| path | GP.BASIC off | GP.BASIC on | MSEDIT colouring off | MSEDIT colouring on | bar |
|---|--:|--:|--:|--:|--:|
| move inside the pane | 0.22 | 0.26 | 0.59 | 1.07 | 0.89 |
| scroll one line | 0.60 | 0.66 | 2.42 | 3.03 | 3.63 |
| page (28 rows) | 0.80 | 1.83 | 6.2 | 21.6 | 9.3 |
| type one character | 0.19 | 0.25 | 0.54 | 0.93 | 0.81 |
| RETURN | 1.86 | 2.16 | 13.0 | 15.1 | 19.5 |
| delete line | 1.76 | 2.00 | 13.0 | 14.2 | 19.6 |
| load | 75 | 75 | 210 | 217 | 315 |
| save | 42 | 42 | 156 | 155 | 234 |
| find | 26 | 27 | 210 | 222 | 315 |

GP.BASIC is 2.7 to 8 times faster than MSEDIT on every path with colouring off. With colouring on
it is 2.9 to 12 times faster than MSEDIT with colouring on. Colouring costs about 4,900 cycles a
painted row. The plan's Result section says the spike selects the GP.BASIC editor.

The type, RETURN and delete line rows are the `EDITBEN` run with the undo kernel in. That run read,
in jiffies for the whole operation with colouring off / on: load 74 / 74, type 38 / 49 (200 keys),
RETURN 93 / 108 (50 keys), delete line 88 / 100 (50 keys), save 45 / 42, find 26 / 27. The load and
save rows of the table are the earlier run and were left as they are. `SCROLLBEN` after the kernel
read 5 / 7 for the 27 moves and 181 / 198 for the 300 scrolls, with 0 mismatches.

**The MSEDIT baseline is `python msedit_bench.py [plain|syntax]`** in the bench folder. It copies
MSEDIT's sources to `source/scratch/msedit-bench`, pastes `MSBENCH.P8` into `edit.p8` ahead of the
key loop, builds with MSEDIT's own `prog8c.jar` and reads back 18 words from `MSBENCH.RES`. MSEDIT's
low RAM is full, so the script empties `act_replace` and `comment_apply` in the copy to make room.
Save and find are called below their keys because `notify()` waits 60 jiffies.

No gap is left between the benches and MSEDIT. The colouring gap and the undo gap both closed on
2026-10-02.

## The program, built 2026-10-02

**The user gave the go for the editor core on 2026-10-02** (step 2 of the plan's Order). Two slices
are built and checked: the edit keys with the key map, and the program `TURBO.BASL`.

- Three documents, A, B and C, built 2026-10-03. F7 shows the next. Each has its own line table,
  arena, undo rings, line limit, name and cursor. The bank map is the plan's Bank map section.
- Row 0 is a title bar with the name, a key list and A, B and C at columns 76 to 78, until the menu
  bar exists. Rows
  1 to 28 are the pane. Row 29 is the status bar: `Line` and `Col` numbers, `*` when the document
  differs from its file, the file name, and a message that the next key clears.
- The key loop is on `GET`. The modifiers are read from `$FEC0` only for PgUp, PgDn, Left and Right.
  Ctrl with PgUp and PgDn gives the first and the last line. Ctrl with Left and Right moves a word.
- Commands from the key map: find (a prompt), find next, save (it asks for a name when there is
  none), open (a prompt; a name not on the disk gives an empty document of that name), new, and
  quit on Esc after a yes or no question. Build and help show `Not in this version`. Open, new and
  quit ask before changes are lost. Esc is command 6 of `TG-KEYS.BASL`, which that file calls menu.
- The prompt is the library's `LINEINPUT.ASK` on the status bar. `APPSYS` remembers the screen mode,
  the charset and the colour at the start and puts them back at the exit. Charset 5 is set at the
  start. The five ISO glyphs are not stamped yet.
- A change is `UNDO.GROUP%` differing from its value at the last load or save. An undo back to the
  saved text still shows `*`.
- `TURBO.ASCII.TO.PETSCII` turns an ASCII literal into PETSCII before it is drawn.
- `DOC.NEW` in `TG-STORE.BASL` makes the document one empty line.
- Syntax colouring is on.

**The program test is `python spike.py TURBOTEST`.**

- `spike.py` makes `TURBOTEST.BASL` from `TURBO.BASL` with five exact replacements, each asserted to
  occur once: two file names, the empty-key line of `TURBO.KEY.WAIT`, the exit, and one `#INCLUDE`.
  A change to any of those lines of `TURBO.BASL` needs `turbo_test_source()` changed with it.
- `TURBOTEST-DRIVER.BASL` feeds key groups from `TURBOTEST.KEY` into the KERNAL key buffer with
  `kbdbuf_put` (`$FEC3`), 10 keys a group at most, so the program's own `GET` loop and
  `LINEINPUT`'s read them. A key that opens a prompt and the prompt's keys go in one group, because
  `LINEINPUT` never returns to the driver for more. `turbomodel.py` writes the groups and holds the
  expectations.
- 103 keys in 26 groups: type on the empty document, open `W.DOC` (a copy of the fixture) over it and
  answer yes to the discard question, edit, find a term, find next, find a term that is nowhere,
  answer no to quit, F1, save, new document, save it under the prompted name `N.DOC`, open `W.DOC`
  again, move, save; then F7 to document B, two lines saved as `B.DOC`, F7 to document C, one line
  not saved, F7 through A to B, undo, undo, redo, undo, save `B.DOC` again as one line, F7 through
  C to A, save. The driver then dumps the pane and the two bars and types Esc and Y.
- Result on 2026-10-03: `W.DOC`, `N.DOC` and `B.DOC` 0 lines differ from the model, the cursor matches
  (line 29, column 91), the pane differs in 0 bytes (top 2, left 18), the bars have 0 faults (title,
  labels, line and column numbers, change mark, file name, the `Saved` message, the letters A, B and
  C and their three attributes), and the program left through its own exit (`QUIT 1`).
  `TURBOTEST.PRG` is 12,481 bytes.
- Not covered: Ctrl with PgUp, PgDn, Left and Right, the cursor keys inside a prompt, and how the
  screen looks. The driver puts keys in the KERNAL key buffer and the program reads the modifiers
  from the keyboard, so the test cannot hold Ctrl. `KEYBEN` covers the dispatch of all four.

**State, 2026-10-03.** Step 1, the library change, is done in the working copy
`GPB-MODS-TESTING/GPC-BASIC/`, and GPBMODS builds:
- The 14 modules take `%`, public names included, and `int16scan --check GPBMODS` finds no split
  name. Root's copies were renamed in place but do not have the bank-plus-address change yet:
  copying the 14 whole to root is owed.
- `BANKMGR.SPACE` hands out a bank and an address. `DLGRESET bank, addr, size`;
  `LIST.BANK` and `LIST.SORT bank, addr, first, last`; `FORM.ITEMS bank, addr`; `PICKSPACE` and
  `PICKDIRSPACE`; FILEDIR reads into `FILE.DIR.PTR` and `FILE.DIR.CAP%`; `MENU.TEXTBANK` has no
  default. GUI hot keys pair PETSCII shifted letters too.
- GPBMODS had hit BASLOAD's name limit; the compiler and BASLOAD were widened
  ([[basload-name-space-widened]]).

Step 2, the GUI in the editor, is written in `TURBO.BASL` and builds. The GUI block is at the
top; `TURBO.GUI.SETUP` claims 2 to 12 and 15 to 63 and runs `MENU.BEGIN` so bank 13 is claimed.
`INPUTBOX`, `ASK3`, `ASKYNEX` and `MSGBOX` replace the prompts; `GP.FN(TURBO.PETSCII, "...")`
makes text PETSCII. TURBOTEST's driver takes its 1,024 B key script from `BANKMGR.SPACE`, which lands in
bank 14, and the model answers the open key's question with D.

Step 3, the dialog save option, is done in the working copy:
- `GUI.SAVEMODE%`, set with `GP.SUB DLGSAVESCREEN, mode`. `GUI.SAVE.VRAM`, the default, keeps
  the covered cells in STASHVRAM; `GUI.SAVE.BANK` keeps them with STASH in the `DLGRESET` space.
  `DLGRESET` sets that space only. COMBO's dropdown saves where its dialog does.
- `SV.START` in STASHVRAM DIMs the handle table to `SV.MAX%` (0 gives 4) and runs `SV.INIT`, on
  the first call only. GUI, COMBO and MENUPULL call it. `MENUPULL.SVSTART` is gone.
- GPBMODS keeps bank mode: `DLGSAVESCREEN, GUI.SAVE.BANK` after `DLGRESET`, and `SV.MAX% = 8`.
- TURBO uses VRAM and has no `DLGRESET` and no 3,072 B piece. Boxes are framed with `DLGGLYPH 1`
  and six screen codes: `$70` `$6E` `$6D` `$7D` corners, `$40` horizontal, `$5D` vertical.
  `GP.BOX` style 1 draws its vertical edge as the letter B under charset 5.

**The TURBOTEST hang is fixed.** `GUI.FORM.DRAIN` dropped the dialog keys the driver had queued
with the key that opened the box. `GUI.TYPEAHEAD%` non-zero keeps them, and the driver sets it.
TURBOTEST passes in full again (every check 0). `TURBO.PRG` is 13,683 B, `TURBOTEST.PRG` 14,758 B;
GPBMODS embedded is 28,305 B with a 48,667 B overlay.

**Library button labels under charset 5** (2026-10-03, the user's pick of the recommendation):
`GP.SUB DLGLABELS, ok$, cancel$, yes$, no$` sets the labels the library names itself, kept in
`DLG.LABELS.*`; `GUI.DEFAULTS` fills a `""` one with `&OK`, `&CANCEL`, `&YES`, `&NO`. TURBO passes
them through `TURBO.PETSCII` in `TURBO.GUI.SETUP`. `source/scratch/int16/turbocap.py --hold=15,68`
captures the Open box; it shows "OK" and "Cancel". The user crunched `TG-UNDO` the same day and
TURBOTEST still passes in full; `TURBO.PRG` is 13,729 B. The user play-tested GPBMODS (about 15
menus) on the new library and it worked. GUI-FIELD-EDIT also worked, but on its own older copy.

**Copied to root 2026-10-03.** Every working-copy module is now in root `GPC-BASIC/`, with the
example programs brought up to the new library: each `#DEFINE`s `MENU.TEXTBANK 62`, a MENU user
includes THEME, and GUI.EXP.BL saves to VRAM. All nine examples compile, deferscan CLEAN; none was
run. The help is rebuilt with the plain three commands.

**Step 4, the menu bar, is built 2026-10-03.** Row 0 holds File, Edit, Search, Window and Help
through MENUKEY: Esc opens File, Alt with a bar letter opens that menu, Alt alone lights the bar,
and File, Exit quits (no key). A row's action is a byte in `TURBO.MENU.ACTIONS$`: a key-map action
run through `KEYS.RUN` in TG-KEYS, or 64 plus a command (`TURBO.ACT.*` defines). New commands:
Save As, Document A/B/C, About. The key wait reads the modifiers on every key and calls
`MENU.KEY` only for Esc or Alt; an empty GET polls `MENU.KEY(0)` for the Alt tap, so spike.py's
replaced line now ends `GOTO TURBO.KEY.IDLE`. The bars take the X16 theme (bar 193, changed letter
yellow 199). Dropdowns and dialogs have shadows; dropdowns are framed from a glyph table in a `%`
array, because a string can move. The menu library now pairs PETSCII shifted hot keys (193-218)
with 65-90, needed because TURBO makes its labels PETSCII. The bat passes `-noemucmdkeys` so Ctrl+F reaches
the editor. TURBO.PRG 14,822 B, TURBOTEST 15,906 B, every check 0.

**Step 5, the file picker, is built 2026-10-03.** `PICKFILE` in FILEPICK now walks directories
the way MSEDIT's picker does: `..`, `/`dirs, files; D deletes after Y, F hides folders, Esc climbs
back to the start directory. A title bar and a footer sit on the box's edges; `PICKLABELS` sets the
footer texts. TURBO's Open uses it, with 6,144 B of list space in bank 14 (95 entries).
The same day the keys moved to Notepad++ where the X16 allows it (Ctrl+S, Ctrl+Y, Ctrl+L, F3,
Ctrl+G go to line); TG-KEYS has a 32-byte Ctrl table, because Ctrl+S and Ctrl+Y arrive as Home's
and Delete's codes. Hot letters are yellow: `MENU.THEME` then two MENU attributes, and the new
`DLGHOTKEY` verb for buttons and the picker footer.
TURBOTEST then ran out of string space (FRE 645 after the first dialog and the picker). Fix: the
setup routines and `TURBO.PETSCII` moved into the regions (banks 10 and 12) and KVBIN was dropped
until the settings exist. FRE 2,324 at the script's end. LINEINPUT then moved to code bank 41 (786 B, taken from the top of A's arena, A now banks 16-40): TURBO.PRG 12,796 B, TURBOTEST passes. The TG modules then joined bank 41 (5,504 B of p-code in the region; kernels that write $00 are GP.ASM LOW and push/restore $00; BLOAD and BANK moved to TG-LOW.BASL): TURBO.PRG 7,511 B, FRE 8,210 at the script's end, TURBOTEST, KEYBEN and PAGEBEN pass. Bank
10's region is nearly full (about 7,950 of 8,188).
Selection, cut, copy and paste were built 2026-10-03: the clipboard is store document 3 in
bank 40 (table to $A5FF, arena from $A600, 512 lines), TG-CLIP.BASL runs from region bank 39,
A's arena is now 16-38. The one new asm is VIEW.SELECT.PAINT (GP.ASM, not LOW). Bank 41 holds
about 6,680 B of p-code and overflowed with TG-CLIP in it. TURBOTEST drives the clipboard
through the Edit menu, because injected keys carry no modifiers. The user wants the clipboard
to spill to disk in the editor's home folder, and later five clip slots there: not built.
The user also wants TURBO to show off GPC-BASIC (GP.DO, GP.SELECT) over plain GOTO style;
working code first, refactor later.
The library change (FILEPICK, FILEDIR's `FILE.DIR.REWIND`, `DLGHOTKEY` in GUI-DIALOGS and GUI) is
in the working copy and TURBO's copy, not root: root, GP-BASIC.md and the help wait for the user's
GPBMODS test of PICKFILE.
Find history built 2026-10-03 on the user's ask: the find box starts with a one-line selection
(Find keeps the selection in KEYS.SELECTION.FIRST), Up and Down walk the last 6 terms, kept as
TG.FIND.1-6 in /SETTINGS.KVB through KVBIN, which now runs from bank 39 with TG-CLIP. Library
side: `LINEINPUT.HISTORY$` and the one-shot verb `DLGHISTORY list$` (working copy plus TURBO's
copy; GPBMODS built with a history on its INPUTBOX demo, not hand-tested, root waits). The user
asked for FIND and REPLACE histories; Replace is not built, so only Find has one.

**Next:** step 6 of the plan's GUI order is not set; the plan's Order goes on to the relay. Also
owed: the sample folders' copies of the modules, which are unchanged and still build; XBASE, edit
and GPC-GUI-HELPER copies differ and need reconciling first. GUIFRMT uses retired modules and
cannot rebuild.

Decided 2026-10-03:

- The menu bar, the picker and the dialogs come from the GPC GUI library, run from `GP.BANKED`
  regions. The user wants the library in a bank or two.
- The library names no bank. Banks are shared ([[library-never-hard-codes-a-bank]]).
- The picker starts from `FILEPICK` and gains MSEDIT's features. TODO.md, Wanted, has the list.
- 16 undo steps a document are enough.
- Copy and paste are owed. A large clipboard can spill to disk.
- The editor's own persistence is a `KVBIN.INC.BL` store. The `KV-BIN-STORE` sample uses the same
  module. The store is a file and takes no bank. It opens logical files 12 and 15. The editor loads
  and saves on logical file 2.

**The GUI's cost is measured, 2026-10-03.** `source/scratch/guimeasure/measure.py packed` builds
the editor with three regions: BANKMGR, STASHVRAM, THEME, MENU and MENUPULL in bank 10 (6,761 B);
GUI, COMBO and CHECK in bank 11 (7,499 B); GUI-DIALOGS, FILEIO, FILEDIR, FILEPICK and KVBIN in
bank 12 (6,153 B). STASH and MENUKEY stay in low memory. The object grows from 11,357 to 13,515
bytes and the workspace shrinks from 12,800 to 10,496. Scalars grow from 572 to 3,242 bytes of the
4,096 ceiling, which leaves 854. The scalar ceiling is the limit to watch. About 400 of the
library's scalars are floats, and they are where bytes can be won back. Nine regions instead of
three cost 1,280 B more workspace. The menu store is 6,656 B in a text bank of its own. The plan's
"The GUI's cost" has the table.

What the key bench proved:

- Through the key map, in jiffies a key with colouring off / on: type 0.25 / 0.30, Backspace
  0.23 / 0.30, Delete 0.23 / 0.28, cursor right 0.20 / 0.25, RETURN at column 0 1.95 / 2.40,
  Backspace joining two lines 1.65 / 2.00, Ctrl+Right 0.28 / 0.40, Ctrl+Left 0.28 / 0.43. RETURN
  and the join are timed over 20 keys, the rest over 40. The type figure is 10 and 12 jiffies over
  40 keys, and 40 keys carry 1 or 2 jiffies of noise. Both colour modes: 548 keys, every check reads
  0 differences, 98 edits undone and redone.
- Character delete, line join and the word moves are `GP.ASM` kernels in `TG-STORE.BASL`, and
  `TURBO.BASL` does not include `MEM`. Backspace and Delete call `DOC.EDIT.REMOVE` and cost the same
  as a typed character within the noise. `MEM.COPY` without its two count guards is 60 bytes smaller
  and no slower.
- A join copies the lower line's record image into the block buffer with `DOC.EDIT.TO.BLOCK`,
  fetches the upper line, adds the block buffer's characters with `DOC.EDIT.APPEND` and stores the
  line. Two lines that hold over 250 characters together do not join. MSEDIT cuts the joined line at
  250, which loses text.
- `DOC.EDIT.WORD.RIGHT` and `DOC.EDIT.WORD.LEFT` follow MSEDIT's `ed_word_right` and `ed_word_left`
  in `edit.p8`. A word is a run of characters that are not spaces. At the end of a line Ctrl+Right
  goes to column 0 of the line below. At column 0 Ctrl+Left goes past the last character of the line
  above. `KEYBEN` times 40 of each from column 0 of line 100. Some of the moves cross to another
  line.
  `keymodel.py` models them and presses them in a fixed section and at random in the walk.
- RETURN copies the cursor line's leading spaces to the new line, as MSEDIT does. `DOC.LINE.SPLIT`
  takes the count in `DOC.SPLIT.INDENT%`. It costs 0.04 jiffies a RETURN.
- One `ON ... GOSUB` through a table of actions costs about 0.05 jiffies a key. The map follows
  MSEDIT's keys. Ctrl+Home arrives as the Home key's code, so the first and last line are Ctrl+PgUp
  and Ctrl+PgDn, read from the modifiers.
- Not tried: a label and a variable that differ only in a last letter. The names `VIEW.JOIN.PAIR`
  and `BEN.KEY.TOTAL` were chosen so the question does not arise.
- `MSEDIT` reads a key with `GETIN` and then the modifiers with `kbdbuf_get_modifiers`. Its Alt
  alone opens the menu. Its exit is a menu row with no key.

What the undo bench proved:

- An undo record is 8 bytes: op, line, group, and the 3-byte line table slot the line had before the
  edit. The arena never frees a record, so the slot still points at the old text and nothing is
  copied. MSEDIT copies the old line into its arena for every record and keeps 12 records. The
  rings keep 32 records each (16 edits or more, the user's call), undo at `$B800` and redo at
  `$B900` of the document's first line table bank, past its slots. `KEYBEN` moves its rings to
  bank 11 with 512 records, because its 98 edits need them.
- Ops are MSEDIT's: 1 changed, 2 added, 3 removed. The records of one edit share a group number.
  Typing notes one record when the edit buffer goes dirty. RETURN notes two. Delete line notes one.
- A record reads the slot, not the edit buffer, so RETURN, delete line, undo and redo store a dirty
  edit buffer first.
- A routine that moves the arena's records must empty both rings.
- A full ring drops every record of its oldest edit. Bit 7 of the op byte marks an edit's first
  record. MSEDIT's `u_drop_oldest` drops one record, so it can leave the second record of a RETURN
  as the oldest. That is read from `edit.p8`, not run.
- `UNDOBEN` with the kernel: six edits undone in 12 jiffies and redone in 11 with colouring off, 16
  and 16 with it on. An undo or a redo is about 2 jiffies with colouring off and 2.7 with it on,
  because each repaints the pane. All its documents and its pane match. `WRAP.UNDONE` is 2.

What the undo kernel proved:

- `UNDO.PUSH` in `TG-UNDO.BASL` is a `GP.ASM` kernel. The user agreed to it as `GP.ASM`; their go
  covered it. It reads the line's slot from the line table itself, places the record, drops the
  oldest edit of a full ring and writes the 8 bytes. Undo and redo apply through the same kernel.
  `UNDO.SLOT.READ` and `UNDO.DROP.OLDEST` are gone.
- A record was about 0.4 jiffies in BASIC. It is about 0.08 to 0.10 with the kernel, group begin
  included. With colouring off, RETURN (two records) is 1.86 with undo and 1.70 without, and delete
  line (one record) is 1.76 and 1.66. Without undo and with colouring on they are 2.00 and 1.90.
- In the nine-path table the kernel took RETURN from 2.54 / 2.84 jiffies to 1.86 / 2.16 and delete
  line from 2.14 / 2.38 to 1.76 / 2.00. In `KEYBEN`, RETURN at column 0 went from 2.60 / 3.10 to
  1.95 / 2.40 and the join from 3.45 / 3.80 to 2.65 / 3.00.
- `ADC`, `SBC` and `CMP` assemble with `{VAR},X`. `INC`, `DEC`, `ASL`, `ROL` and `STZ` assemble on a
  zero page address. A `JSR` to a label of the same block works. The kernel assembled and passed on
  its first build.
- The byte order of a `%` array's elements is not established. The kernel takes the ring's first
  record and count in two scalars. BASIC copies them from the two `%` arrays and back, four
  statements.

What the colouring kernels proved:

- The classifier is GPC.HELP's scan and word lookup ([[help-source-viewer-state]]), with a keyword
  table indexed by first letter in place of the linear walk. One key bank (15) holds the table at
  `$A000`, seven inks at `$BDF0`, the line's text at `$BE00` and its classes at `$BF00`.
- A `GP.ASM` block cannot name a label in another block. A block stores its own entry address with
  `JSR HERE` / `HERE: PLA` / `ADC #17`, when a `GOSUB` reaches it at setup. The caller writes that
  address into a `JSR $FFFF` operand with `STA LABEL,X` and `STA LABEL,Y`. `VIEW.PAINT` calls the
  scan and the lookup this way, once a row, with no p-code loop over rows.
- The store holds PETSCII, not ASCII: the loader turns `A`-`Z` into `$C1`-`$DA` and `a`-`z` into
  `$41`-`$5A`. A kernel that tests or folds a letter uses `AND #$7F`. `AND #$DF` is wrong here.
- The classifier keeps no state between lines, so a `REM` line inside `GP.ASM` is a comment.

What the load, save and find kernels proved:

- MACPTR and MCIOUT work from a `GP.ASM` block with the CHKIN or CHKOUT in the same block. The load
  kernel reads 255 bytes and splits the lines in the same block. Save is one kernel call for the
  whole document, one MCIOUT a line.
- A branch out of range is reported as `PASS 1 ...OUT OF RANGE @ <BASIC line>`, and the line is the
  block's `GP.ENDASM`, not the branch. Count the bytes by hand to find it.
- RETURN and delete line are a page-chunked memmove of the line table, three bytes a slot, with a
  p-code loop over table banks only.

What the first kernels proved:

- A `%` array is a 256-byte low-RAM buffer a kernel can read with any bank selected: `DIM X%(127)`,
  address from `GP.ARRPTR(X%())`. The edit buffer and the screen code table are held this way.
- `{VAR},Y` assembles for `LDA` and `STA`. `INC abs,Y` does not exist on the 65C02 and the compiler
  reports it as `PASS 1 SYNTAX ERROR @ <BASIC line>`.
- One kernel call paints a run of rows, with the table lookup, the gutter number and the cursor cell
  inside it. P-code sets three variables and calls.

## Other decisions the user took

- Charset is MSEDIT's scheme, not CP437: thin PETSCII font (charset 5), five ISO glyphs stamped in,
  ASCII on disk, a PETSCII or ISO mode a document. The ISO-8859-15 capitals round trip is not a
  concern of the user's. See [[gpc-editor-is-ascii-inside-petscii-outside]].
- Version 1 is three documents with F7 switching, plus the relay. Switching was built on
  2026-10-03 and cost 771 bytes, 10,654 to 11,425. The user kept it in version 1 the same day.
- F5 builds and runs, and a failure reloads the editor on the error line. Tokenise, compile and run
  are also separate Build menu rows. Keys are menu first: only F5 and F12 are function keys.
- Errors come back in an error file, with a screen scrape as the fallback.
- A debug object chains to the editor on END and on a runtime error. F8 stays armed.
- The runtime address to source lookup lives inside the IDE, on the GPC.ERR logic.
- F1 is an in-editor viewer on the word under the cursor.
- A project is `.MAKE` plus `.PDEF`. The IDE chains to GPC.GUI for the forms, it does not port them.
- A loose file with no `.PDEF` asks once: interpreter or compile.
- The IDE lives in `/GPC/`. 80x30 only. Runs on 512 KB and uses more banks when present.
- The on-disk program name is not chosen. `TURBO.PRG` is the working name.

**Why:** the X16 runs one program at a time, so the IDE is a chain of LOADs with state in files, and
that relay does not care what language the editor is. `.BASLOAD.NEXT` already chains BASLOAD-GPC to a
next program on a clean tokenise; GPC.BIN and a compiled object have no such exit. A p-code
statement is about 500 cycles and a module `GOSUB` about 2,570, so the rule is: p-code decides,
assembly moves bytes, and no loop over bytes or rows is p-code.

**How to apply:** the spike and the editor core have the user's go. The asm hooks of the relay
(GPC.INPUT lines 6 and 7, the compile error file, the runtime debug exit) still fall under
[[ask-before-writing-asm]]. Line 6 is
[[gpc-input-sixth-line-chain]]. The layout step is [[tool-home-layout-deferred]]. Related:
[[msedit-is-the-syntax-colouring-master]], [[gpcerr-builds-in-its-sample-folder]],
[[editor-return-is-the-line-table]], [[measure-before-changing-code]],
[[headless-basl-build-recipe]], [[gpc-shared-pcode-cap-is-rtbase]].
