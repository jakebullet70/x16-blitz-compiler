---
name: turbo-gpc-ide-plan
description: "TURBO GPC is the on-machine IDE: a new GP.BASIC editor on MSEDIT's design, source in GPC-BASIC-TOOLS-SRC/TURBO-GPC; the speed spike passed on all nine paths; the editor core (plan Order step 2) is built: three documents on F7, menu bar, file picker, Notepad++ keys, clipboard, find and replace in TG-FIND.BASL with options and combo-box histories, the ISO glyphs, an About box and a scroll bar; TURBO.BASL names its outputs with #GPC lines, TURBO.PRG is 7,658 B SHARED; the relay is next and waits on the user's naming decisions; layout, build, test, decisions and numbers"
metadata:
  node_type: memory
  type: project
  originSessionId: f2ef33fe-6565-4754-b1b1-05111d41cf23
  modified: 2026-10-05T22:30:00.000Z
---

**TURBO GPC is the name of the on-machine IDE, chosen by the user on 2026-10-02.** The plan is
`docs/blitz/TURBO-GPC.PLAN.md`.

**The editor is a fresh GP.BASIC program with MSEDIT (Prog8, `dos_tools/x16-MSEDIT`) as its
specification.** The user prefers GPC over Prog8 for it and chose this over forking MSEDIT. A
measurement spike gated the route and every path passed, so MSEDIT is not forked. The GP.BASIC
`edit` sample stays a sample.

## Layout, build and test

- The editor is in `GPC-BASIC-TOOLS-SRC/TURBO-GPC/`: `TURBO.BASL` (the program), `TG-STORE.BASL`,
  `TG-UNDO.BASL`, `TG-VIEW.BASL`, `TG-KEYS.BASL`, `TG-CLIP.BASL`, `TG-FIND.BASL`, `TG-LOW.BASL`,
  `tgkeys.py`, `TGKEYS.BIN`, `build.py`, and `GPC-BASIC/` (the library copies the program includes,
  and MEM, which only the benches include).
- `bench/` holds the benches: the six `*BEN.BASL`, `TG-BENCH-CHECK.BASL`, `TURBOTEST-DRIVER.BASL`,
  `FIX2000.TXT`, `MSBENCH.P8`, `spike.py`, `keymodel.py`, `turbomodel.py`, `mkfixture.py`,
  `msedit_bench.py`.
- A BASLOAD `#INCLUDE` cannot name `../`. `spike.py` copies the editor's modules, `TGKEYS.BIN` and
  `GPC-BASIC/` into `bench/` for a build and removes them after the run, with everything the build
  and the run wrote. `--keep` leaves them. Edit a module in `TURBO-GPC/`, never the copy.
- The clean-up deletes every file in `bench/` whose name does not end in `.BASL`, `.py`, `.P8` or
  `.TXT`. A note or a data file of another kind put there is gone after the next run.
- `TURBO.BASL` begins with `#GPC SHARED`, `#GPC OBJECT "TURBO.PRG"`, `#GPC MAP "TURBO.MAP"` and
  `#GPC DEADLIST "TURBO.DEAD"`. GPC 1.2.0 reads them (commit 0757c08).
- Build the editor: `python build.py` in `TURBO-GPC/`. It writes `TGKEYS.BIN`, tokenises
  `TURBO.BASL` and calls `compile_shared.py` with only the source and the object. It prints each
  step's time and the `{VAR}` cache need.
- The object name `build.py` passes must match `#GPC OBJECT`. `compile_shared.py` checks the file
  it was given and reports a false failure when they differ.
- Sizes on 2026-10-05: `TURBO.PRG` 7,658 B SHARED, `TURBO.OVL` 40,975 B. Dead-code removal drops
  499 lines, 4,190 B. Tokenise about 54 s, compile about 42 s. The `{VAR}` cache needs 16,423 of
  32,768 B. The SHARED p-code cap is 22,016.
- Run a bench: `python spike.py NAME` in `bench/` tokenises, compiles, runs at real speed with
  colouring off and prints `NAME.RES`. `NAME colour` runs with colouring on. `NAME both` builds
  once and runs with colouring off, then on.
- Test the program: `python spike.py TURBOTEST` in `bench/`.
- Run it in a window: `USER-RUNS/turbo-gpc-demo.bat`. It mounts `GPC-BASIC-TOOLS-SRC`, and
  `turbo-gpc-demo.bas` changes into `TURBO-GPC`, so the runtime comes from `/GPC/`. The bat passes
  `-noemucmdkeys` so Ctrl+F reaches the editor.

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
save rows of the table are the earlier run. `SCROLLBEN` after the kernel read 5 / 7 for the 27
moves and 181 / 198 for the 300 scrolls, with 0 mismatches.

**The MSEDIT baseline is `python msedit_bench.py [plain|syntax]`** in the bench folder. It copies
MSEDIT's sources to `source/scratch/msedit-bench`, pastes `MSBENCH.P8` into `edit.p8` ahead of the
key loop, builds with MSEDIT's own `prog8c.jar` and reads back 18 words from `MSBENCH.RES`. MSEDIT's
low RAM is full, so the script empties `act_replace` and `comment_apply` in the copy to make room.
Save and find are called below their keys because `notify()` waits 60 jiffies.

## The program, state 2026-10-05

**The editor core, step 2 of the plan's Order, is built.** Commits 4818871, 047bb50, 781f699,
70b12cd and 973db63.

- Three documents, A, B and C. F7 shows the next. Each has its own line table, arena, undo rings,
  line limit, name and cursor. The plan's Bank map section has the banks.
- Row 0 is the menu bar: File, Edit, Search, Window and Help through MENUKEY, the name, and A, B and
  C at columns 76 to 78. Esc opens File, Alt with a bar letter opens that menu, Alt alone lights
  the bar, and File, Exit quits (no key). Rows 1 to 28 are the pane, and column 79 of them is the
  scroll bar. Row 29 is the status bar: `Line`, `Col`, `*` for a change, the file name, `Lines`
  with the count, the file form and the tab width, and a message that the next key clears.
- A row's action is a byte in `TURBO.MENU.ACTIONS$`: a key-map action run through `KEYS.RUN` in
  TG-KEYS, or 64 plus a command (`TURBO.ACT.*` defines). The menu library pairs PETSCII shifted hot
  keys (193-218) with 65-90, because TURBO makes its labels PETSCII.
- The keys follow Notepad++ where the X16 allows it: Ctrl+S, Ctrl+Y, Ctrl+L, F3, Ctrl+G go to line,
  Ctrl+H replace. TG-KEYS has a 32-byte Ctrl table, because Ctrl+S and Ctrl+Y arrive as Home's and
  Delete's codes. Ctrl with PgUp and PgDn gives the first and the last line. The key wait reads the
  modifiers on every key and calls `MENU.KEY` only for Esc or Alt. An empty `GET` polls
  `MENU.KEY(0)` for the Alt tap and goes to `TURBO.KEY.IDLE`.
- Commands: open, save, save as, find, find next, replace, go to line, new, document A, B and C,
  About, and exit. Help shows `Not in this version`. Open, new and quit ask before changes are lost.
- Open uses `PICKFILE` from FILEPICK, which walks directories as MSEDIT's picker does: `..`, `/`
  dirs, files; D deletes after Y, F hides folders, Esc climbs back to the start directory. Its list
  space is 6,144 B in bank 14 (95 entries).
- Dialogs come from the GUI library (`INPUTBOX`, `ASK3`, `ASKYNEX`, `MSGBOX`, forms) and keep the
  screen under them in VRAM. Dialogs and dropdowns have shadows and are framed with `DLGGLYPH 1`
  and six screen codes held in a `%` array: `$70` `$6E` `$6D` `$7D` corners, `$40` horizontal,
  `$5D` vertical. `GP.BOX` style 1 draws its vertical edge as the letter B under charset 5.
  `DLGLABELS` gives the library's buttons TURBO's case. Hot letters are yellow.
- Selection, cut, copy and paste: the clipboard is store document 3 in bank 40 (table to $A5FF,
  arena from $A600, 512 lines). TG-CLIP runs from bank 39 with KVBIN. TURBOTEST drives the
  clipboard through the Edit menu, because injected keys carry no modifiers.
- Find and replace are in `TG-FIND.BASL`, which runs from bank 38 with CHECK, the About box and the
  status bar's fields. The boxes are forms with four check boxes: Match case, Whole word, Wrap
  around, In selection. A found term is selected whole. The find box starts with a one-line
  selection. Each term field is an editable combo box with its history in a list under it, and
  Down opens the list. The find and the replace boxes each keep their own history of 6 terms in
  `/SETTINGS.KVB` through KVBIN: `TG.FIND.1` to `TG.FIND.6` and `TG.REPLACE.1` to `TG.REPLACE.6`.
  Replace asks Y, N, A or Esc at each place, defaults to Cancel, and the run is one undo edit.
- `TURBO.GLYPHS.SETUP` copies the ISO glyphs of `\ ^ _ ` { | } ~` over the reverse glyphs at
  screen codes `$F8` to `$FF`. Call it after `VIEW.SETUP` and after every `APPSYS.SETCHR`.
- The About box shows the name, then what the banked RAM, the workspace and each document hold.
- `APPSYS` remembers the screen mode, the charset and the colour at the start and puts them back at
  the exit. Charset 5 is set at the start.
- A change is `UNDO.GROUP%` differing from its value at the last load or save. An undo back to the
  saved text still shows `*`.
- `TURBO.ASCII.TO.PETSCII` and `GP.FN(TURBO.PETSCII, "...")` turn an ASCII literal into PETSCII
  before it is drawn.
- The GUI library and the setup routines run from banks 10 to 12. LINEINPUT and the TG modules
  other than TG-CLIP and TG-FIND run from bank 41. Kernels that write `$00` are `GP.ASM LOW` and
  push and restore `$00`. BLOAD and BANK are in `TG-LOW.BASL`.
- `TURBO.GUI.SETUP` claims banks 2 to 12 and 15 to 63 and runs `MENU.BEGIN`, which claims bank 13.
- Syntax colouring is on.

**The program test is `python spike.py TURBOTEST`.**

- `spike.py` makes `TURBOTEST.BASL` from `TURBO.BASL` with nine exact replacements, each asserted
  to occur once: the `#SAVEAS` and `#SYMFILE` names, the three `#GPC` output names (renamed to
  `TURBOTEST.*`), the empty-key line of `TURBO.KEY.WAIT`, the exit, the settings store's name, and
  one `#INCLUDE`. It reads `TURBO.BASL` with LF line endings, so its newline-ending strings match a
  CRLF copy. A change to any of those lines of `TURBO.BASL` needs `turbo_test_source()` changed
  with it.
- `TURBOTEST-DRIVER.BASL` feeds key groups from `TURBOTEST.KEY` into the KERNAL key buffer with
  `kbdbuf_put` (`$FEC3`), 10 keys a group at most, so the program's own `GET` loop and the dialogs
  read them. A key that opens a box and the box's keys go in one group. `GUI.TYPEAHEAD%` non-zero
  keeps queued keys from being drained when a form opens, and the driver sets it. The driver takes
  its 1,024 B key script from `BANKMGR.SPACE`, in bank 14. `turbomodel.py` writes the groups and
  holds the expectations.
- The script types, opens, edits, finds, picks terms from the find history, replaces with Y, N, Y
  and Esc, then A with an empty replacement that it undoes, then A with a term from the replace
  history, switches documents with F7, undoes and redoes, and saves `W.DOC`, `N.DOC` and `B.DOC`.
  `spike.py` compares the saved documents, the cursor, the pane, the two bars and the settings
  store with the model. TURBOTEST's store is `SETTINGS.KVB` in `bench/`.
- Not covered: Ctrl with PgUp, PgDn, Left and Right, and how the screen looks. The driver puts keys
  in the KERNAL key buffer and the program reads the modifiers from the keyboard, so the test
  cannot hold Ctrl. `KEYBEN` covers the dispatch of all four.

**The library change for TURBO, first part,** is in the working copy `GPB-MODS-TESTING/GPC-BASIC/`
and in root `GPC-BASIC/`, and the help is rebuilt: the 14 modules take `%`; `BANKMGR.SPACE` hands out a bank
and an address (`DLGRESET bank, addr, size`, `LIST.BANK`, `LIST.SORT`, `FORM.ITEMS`, `PICKSPACE`,
`PICKDIRSPACE`, `FILE.DIR.PTR` and `FILE.DIR.CAP%`; `MENU.TEXTBANK` has no default);
`GUI.SAVEMODE%` set with `GP.SUB DLGSAVESCREEN, mode` (`GUI.SAVE.VRAM` the default, `GUI.SAVE.BANK`
keeps the cells with STASH in the `DLGRESET` space); `SV.START` in STASHVRAM DIMs the handle table
to `SV.MAX%` (0 gives 4) on the first call; `DLGLABELS`. GPBMODS keeps bank mode with
`SV.MAX% = 8`.

**The second part is not in root.** CHECK, COMBO, FILEDIR, FILEPICK, GUI-DIALOGS and GUI in
TURBO's `GPC-BASIC/` differ from root on 2026-10-05: the picker walk, `FILE.DIR.REWIND`,
`DLGHOTKEY`, `DLGHISTORY`, check box hot keys and the `FORM.EDITCOMBO` field. The working copy matches
TURBO's except FILEPICK, which has uncommitted edits. Root, GP-BASIC.md and the help wait for the
user's GPBMODS test of PICKFILE.

**Next.** The relay, step 3 of the plan's Order, needs the user's decisions first: the job file's
name, the error file's name and folder, and the program's on-disk name (`TURBO.PRG` is the working
name). Owed before it:

- Reconcile the sample folders' copies of the modules. XBASE, edit and GPC-GUI-HELPER have copies
  that differ. GUIFRMT uses retired modules and cannot rebuild.
- The clipboard's spill to disk in the editor's home folder, and later five clip slots there.
- Settings in `/SETTINGS.KVB` beyond the find and replace histories.

The user wants TURBO to show off GPC-BASIC (GP.DO, GP.SELECT) over plain GOTO style; working code
first, refactor later.

Decided 2026-10-03:

- The menu bar, the picker and the dialogs come from the GPC GUI library, run from `GP.BANKED`
  regions. The user wants the library in a bank or two.
- The library names no bank. Banks are shared ([[library-never-hard-codes-a-bank]]).
- The picker starts from `FILEPICK` and gains MSEDIT's features. TODO.md, Wanted, has the list.
- 16 undo steps a document are enough.
- A large clipboard can spill to disk.
- The editor's own persistence is a `KVBIN.INC.BL` store. The `KV-BIN-STORE` sample uses the same
  module. The store is a file and takes no bank. It opens logical files 12 and 15. The editor loads
  and saves on logical file 2.

**The GUI's cost was measured on 2026-10-03.** `source/scratch/guimeasure/measure.py packed` builds
the editor with three regions: BANKMGR, STASHVRAM, THEME, MENU and MENUPULL in bank 10 (6,761 B);
GUI, COMBO and CHECK in bank 11 (7,499 B); GUI-DIALOGS, FILEIO, FILEDIR, FILEPICK and KVBIN in
bank 12 (6,153 B). The workspace shrank from 12,800 to 10,496. Scalars grew from 572 to 3,242 bytes
of the 4,096 ceiling. The scalar ceiling is the limit to watch. About 400 of the library's scalars
are floats, and they are where bytes can be won back. Nine regions instead of three cost 1,280 B
more workspace. The menu store is 6,656 B in a text bank of its own. The plan's "The GUI's cost"
has the table. The program's banks have moved since; the plan's Bank map is current.

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
- A record is about 0.08 to 0.10 jiffies with the kernel, group begin included, against about 0.4
  in BASIC. With colouring off, RETURN (two records) is 1.86 with undo and 1.70 without, and delete
  line (one record) is 1.76 and 1.66. Without undo and with colouring on they are 2.00 and 1.90.
- `ADC`, `SBC` and `CMP` assemble with `{VAR},X`. `INC`, `DEC`, `ASL`, `ROL` and `STZ` assemble on a
  zero page address. A `JSR` to a label of the same block works.
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

- Charset is MSEDIT's scheme, not CP437: thin PETSCII font (charset 5), the eight ASCII-only
  glyphs copied in from the ISO font at `$F8` to `$FF`, ASCII on disk, a PETSCII or ISO mode a
  document. The ISO-8859-15 capitals round trip is not a concern of the user's. See
  [[gpc-editor-is-ascii-inside-petscii-outside]].
- Version 1 is three documents with F7 switching, plus the relay. Switching cost 771 bytes. The
  user kept it in version 1 on 2026-10-03.
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
[[headless-basl-build-recipe]], [[gpc-shared-pcode-cap-is-rtbase]], [[build-times-baseline]].
