# Sample: GUI-LITE

A message box and a menu that fit in low memory. The program opens a menu on a themed page. ABOUT
opens a message box with one button. TWO BUTTONS opens one with SAVE and DISCARD, then a second box
shows the number `MSGBOX` returned. QUIT asks YES or NO.

THEME opens a second menu over the first, with the four themes, and repaints the page in the one
chosen. DISK opens a second menu of three file names. The one chosen goes to `DOSX.EXISTS`, and a
message box over the second menu says whether the file is on the drive and what the drive answered.
`NO-SUCH.FILE` shows the answer for a file that is not there. DISK STATUS reads the drive's status
and shows it in a message box.

Each message box opens over the menu, which stays on the screen until the program closes it. Each
box saves the screen it covers to VRAM and puts it back when it closes.

The top row names the theme. The bottom row shows `FRE(0)`, the string heap, read each time the
menu opens, and the number the menu returned.

Nothing in it is banked, so the compile writes one PRG and no `.OVL`.

Run it:

```
USER-RUNS\guilite-demo.bat
```

The screen is 80x30.

## Keys

| key | in the menu | in a message box |
|---|---|---|
| `UP`, `DOWN` | move the bar, wrapping at the ends | |
| `LEFT`, `RIGHT`, `TAB` | | move the focus between the buttons |
| `RETURN` | chooses the item | chooses the focused button |
| `ESC` | asks whether to quit | chooses the last button |

## The module

`GPC-BASIC/GUI-LITE.INC.BL` is three verbs. A program calls them and nothing else. The library at
the repository root holds the master copy.

```
B = GP.FN(MSGBOX, title$, line$, line$, line$, line$, button$, button$)
C = GP.FN(PICKMENU, x, y, title$, items$)
GP.SUB CLOSEBOX
```

`MSGBOX` centres up to four lines over one or two buttons and returns the button chosen, 1 or 2.
A `""` line is a blank row, and the box ends at the last line that is not `""`. A `""` second
button gives one button. `GP.SUB MSGBOX, ...` calls it without reading the result.

`PICKMENU` lists the comma-separated items in a box whose top-left corner is `x,y`. It returns the
item chosen, counting from 1, or 0 for `ESC`. An item cannot contain a comma. The menu stays open
when `PICKMENU` returns, so a message box can open over it.

`CLOSEBOX` takes down the box opened last, which is the menu. It puts back the screen as it was
when the menu opened, so a program that repaints the page closes the menu first.

Both boxes are as wide as their text and have a drop shadow. The caller keeps every box and its
shadow on the screen.

The screen under each box goes to VRAM, the first at `GL.SAVE.AT`, `$4000` by default, and each
later one just above the box before. Up to `GL.MOST.OPEN` boxes, 4 by default, are open at once.
The largest box on an 80x30 screen takes 5,084 bytes, so four of them end at `$8F70`, and the save
area must end below `$10000`. Define either name before the `#INCLUDE` to change it.
`STASHVRAM.INC.BL` starts its window at `$04000` too, so a program that includes both moves one of
them.

`GUI-DIALOGS.INC.BL` also declares `MSGBOX` and `PICKMENU`, so a program includes one or the other.

`DISK` uses `GPC-BASIC/DOS.INC.BL`, the small drive module. `GP.FN(DOSX.EXISTS, name$)` returns -1
when the file opens and 0 when not, and leaves the drive's answer in `DOS.ERR` and `DOS.MSG$`.
`DISK STATUS` calls `GP.SUB DOSX, ""`, which sends the drive no command and reads its status into
the same two names. A program includes it or `FILEIO.INC.BL`, not both.

The colours come from `THEME.INC.BL`. The frame is drawn in `THEME.BORDER`, the inside in
`THEME.TEXT` and the title in `THEME.TITLE`. The shadow is `THEME.SHADOW`. The focused button and
the menu bar are `THEME.HILITE`, and the other button is `THEME.BAR`.

## Build

From the repository root, with this folder as the drive. `python` is off PATH; see
`docs/BUILDING.md`.

```
python source/gpc/samplesbuild.py GUI-LITE
```

The build is EMBEDDED. It fails if the compile writes a `GUI-LITE.OVL`, because one PRG is the
point of the sample. A `GP.BANKED` or `GP.BANKEDSTR` block anywhere in the source writes one.

## Files

| | |
|---|---|
| `GUI-LITE.BASL` | the program |
| `GPC-BASIC/` | copies of `GPB`, `APPSYS`, `THEME`, `GUI-LITE` and `DOS` from the root library, the modules it includes |
| `GPC.BIN`, `GPC.PRG`, `BASLOAD-GPC.PRG`, `BASLOAD-GPC.BIN` | the compiler and tokeniser, for building on the machine |

Build outputs: `GUI-LITE.SRC.PRG`, `GUI-LITE.SRC.SYM`, `GUI-LITE.PRG` and `GUI-LITE.MAP`.
