---
name: demo-project-options
description: "The six showcase demo projects proposed on 2026-10-01 after GUI-LITE, which one was picked, and the library gaps each fills"
metadata:
  node_type: memory
  type: project
  originSessionId: d2b7b119-5992-421b-90e8-03d6d590b04d
  modified: 2026-10-01T14:42:26.287Z
---

On 2026-10-01, after the GUI-LITE sample, the user asked for demo projects that show off
GPC-BASIC. Six were proposed. The user picked number 1 and asked for it in
`GPC-BASIC-TOOLS-SRC/MANDELBROT-SPEED/`, to move to `release/` when done.

No sample includes `KV`, `SORT`, `STRUSING`, `MATH` or `MEM` yet. That gap drove the list.

1. **Speed Duel (PICKED).** The same Mandelbrot run three ways: ROM BASIC, GPC compiled, and GPC
   with the inner loop in `GP.ASM`. Times shown side by side. The duel core must be plain X16
   BASIC, because a GP.BASIC program is compile-only.
2. **Control Panel.** A settings editor, the full-GUI counterpart of GUI-LITE. One form with
   `LINEINPUT`, `CHECK`, `COMBO`, `MENUPULL`, saved through `KV.SAVE`. Fills `KV`. Small.
3. **Ledger / checkbook.** `STRUSING` money columns, `SORT` by date, `FILEIO SAVEARRAY/LOADARRAY`,
   a menu bar, `GUI.YN` to confirm a delete. Fills `STRUSING`, `SORT`, `SAVEARRAY`, `MATH`. Medium.
   The recommended second pick.
4. **Text-mode game** (Minesweeper or Snake). `GP.PRINTAT`, `GP.CHAR`, `GP.BOX`, `GP.SELECT` keys in
   a `GP.DO` loop, `THEME`, a high score through `DOS.INC`, a `MSGBOX` at game over. Tests need the
   `POKE 780` key queue. Medium.
5. **File Commander.** Two-pane disk manager: `FILEDIR` into a bank, `FILEIO` copy, rename, delete,
   mkdir and chdir, `STASHVRAM` to swap panes. Wait for the LISTS/DIR work, because the DIR read
   loop is slow. Medium to large.
6. **Text adventure bigger than BASIC RAM.** `GP.BANKEDSTR` room text, `GP.BANKED` code, `KV` game
   state, a `SPLIT`/`STRCASE` parser, one PRG plus `.OVL`. Needs story content. Large.

A picture slideshow was dropped, because BMXVIEWER covers it.

**Number 1 was built 2026-10-01** and added to `release.sh` the same day as
`SAMPLES/MANDELBROT-SPEED/`. The user chose a
per-cell `GP.ASM` blob, a 40x28 picture, a key to start, and APPSYS save and restore. Times:
ROM 6,048 jiffies, GPC 3,075 (1.97x), GP.ASM 284 (21.3x). Fixed-point maths in BASIC was slower
both ways, so it was dropped. The folder `readme.md` holds the rest.

**Number 2 was picked next, on 2026-10-01**, in `GPC-BASIC-TOOLS-SRC/KV-BANKED/` (the user's
folder name). The library code runs from `GP.BANKED` regions, the text sits in `GP.BANKEDSTR`, and
the settings are a KV bank saved as `SETTINGS.KV`. It is EMBEDDED and ships a `.OVL`. It has
`samplesbuild.py` entry `KV-BANKED` and `USER-RUNS/kvbanked-demo.bat`. It is not in `release.sh` yet.
It is parked: it still calls the old `FORM.COMBOSEL`, `COMBO.ITEM$` and `FORM.COMBO` signature.

**KV-BIN-STORE was written 2026-10-02**, outside the six, in `GPC-BASIC-TOOLS-SRC/KV-BIN-STORE/`
(the user's folder name). It is a registry editor on `KVBIN.INC.BL`, a new plain-BASL module that
keeps keys and values in one file of 128-byte records: a 12-byte key, a value of up to 115, both
padded with `$00`. The user's idea is a small registry in the X16 root that many programs share,
with the file name and path passed in. The module and `KVBIN.EXP.BL` are in the
`GPB-MODS-TESTING/GPC-BASIC/` working copy, not in root. `KVBIN.EXP.BL` passes 13 of 13 in ROM
BASIC, and 13 of 13 under GPC once the runtime was fixed, see [[file-io-error-in-gpdo-key-loop]].
The editor has a `samplesbuild.py` entry and `USER-RUNS/kv-bin-store-demo.bat`. It was built
EMBEDDED on 2026-10-02: PRG 22,417 bytes, OVL 26,893. A headless first run made `SETTINGS.KVB`
with its six sample keys. The user ran it on 2026-10-02 and said it looks good, then asked for a
shadow on every popup: `DLGSHADOW 1` follows `DLGRESET`, and the dropdowns had `MENU.SHADOW`
already. It builds against runtime build 131.

Later on 2026-10-02 the user asked for a ROM BASIC version and a Prog8 version in the same folder,
all three in the release. Both are text programs with one menu line, `L LIST  G GET  P PUT
D DELETE  Q QUIT`, on the same `SETTINGS.KVB`:
- `KVBIN-BASIC.BASL` tokenises to `KVBIN-BASIC.PRG`, 3,444 bytes. It includes `KVBIN.INC.BL`,
  which uses no GP keyword.
- `KVBIN-PROG8.P8` compiles to `KVBIN-PROG8.PRG`, 3,855 bytes, with Prog8 12.0.1. Its `kvbin`
  block is the module's Prog8 counterpart, on `diskio` (`f_open_w_seek`, `f_seek_w`).

Each reads what the others wrote, and each makes a missing store. Tested headless with
`runkeys.py`, see [[paste-cannot-drive-a-running-program]]. `samplesbuild.py` has entries
`KVBIN-BASIC` (`kind="basic"`, tokenise only) and `KVBIN-PROG8` (`kind="prog8"`). `release.sh`
ships the folder as `SAMPLES/KV-BIN-STORE/`, without `SETTINGS.KVB`. `USER-RUNS` has
`kvbin-basic-demo.bat` and `kvbin-prog8-demo.bat`. `KVBIN.INC.BL` and `KVBIN.EXP.BL` are in root
`GPC-BASIC/` and listed in `GP-BASIC.FILES.md`. The module is §4.26 of `GP-BASIC.md`, and the
GPBMODS harness moved to §4.27. The help was rendered with it: 76 topics, 166 index rows, the
topic is `H063.HLP`. `KVBIN.EXP.BL` calls every routine but `KVBIN.STOP`.
The folder has a `readme.md` with a release cut. `release.sh stage` put all of it in
`release/TMP` on 2026-10-02, at build 131, 345 files. No zip was made. The user has not run the
two text programs by hand. `SETTINGS.KVB` and `SETTINGS.TXT` in the folder are run data and are
not committed.
See [[cmdr-dos-modify-mode-measured]].

**GUI-FIELD-EDIT was built 2026-10-01**, outside the six. It is a fake video rental store form in
`GPC-BASIC-TOOLS-SRC/GUI-FIELD-EDIT/`: 80x30, two columns, 26 controls plus the RENT and CANCEL
buttons, and a summary `MSGBOX` after RENT. It drove the FORM library extension: per-control list state, `FORM.LIST`, `FORM.SEL n`,
radio and read-only value controls, `FORMTO.EVENT`, and SHIFT+TAB out of a text field. Its text is in
`GFE.TEXT.INC.BL`. The user hand-tested it and it works. It has a folder `readme.md` with a release cut, and
`release.sh` ships it as `SAMPLES/GUI-FIELD-EDIT/`.

**LANDER64 was built 2026-10-01**, outside the six. The user asked for a graphics C64 BASIC
game with an open licence. It is a port of rosdec/lander64 (GPL-3.0, `contest/lander64.bas`) in
`GPC-BASIC-TOOLS-SRC/LANDER64/`, with `LICENSE` beside it. The user wants it in GP.BASIC, not
plain X16 BASIC: GP.DO, GP.IF, GP.SELECT, GP.CHAR, GP.PRINTAT and APPSYS, so
`LANDER64.SRC.PRG` does not run in ROM BASIC and is not shipped. It uses `SPRITE`/`SPRMEM`/`MOVSPR`,
`JOY(0)` and `JOY(1)`, PSG noise, and `VPEEK` of the layer 1 map for the landing test. Its exit
left the noise on until [[gpc-psgvol-fmvol-inverted]] was fixed. Game over is a GUI-LITE
`MSGBOX` with PLAY AGAIN and QUIT, which the user asked for. The user had every GP.DEFPROC
removed: its routines are plain `GOSUB` targets that take and return values in variables. The title page asks E for EASY (6 jiffies a tick) or H for
HARD (4, the first speed, which the user found a little fast). It has a `samplesbuild.py`
entry, a `release.sh` entry and `USER-RUNS/lander64-demo.bat`. Other open-licence candidates
found: Kidelyneen (EgonOlsen71, Unlicense), Ball and Paddle (alejsanc, Apache-2.0), Skyscrape64
(croys, MIT). Magazine type-ins are publisher copyright, so they cannot ship.

**How to apply:** when the user asks for the next demo, start from this list. Related:
[[release-samples-shape]], [[samples-build-in-place]], [[ask-before-writing-asm]].
