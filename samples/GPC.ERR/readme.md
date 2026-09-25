# Sample — GPC.ERR

A runtime error address, turned into a place in the source. Give it the `M.<source>` debug map GPC
wrote beside the object and an address out of an error line, and it answers with the BASIC line, the
file that line came from, and the nearest label above it.

Run it:

```
gpcerr-demo.bat
```

The batch file runs the object out of `samples/GPC-HELP`, which is where the `GPB.HELP` map, symbol
file and tokenised source already are. The screen is 80x30.

## Using it

Three bar items. ESC opens the bar and ALT with an item's marked letter opens that item's dropdown.
LEFT and RIGHT walk from one dropdown to the next. ESC closes an open one.

| item | rows |
|---|---|
| FILE | LOAD MAP, BROWSE MAP, QUIT |
| SEARCH | BY ADDRESS, BY LINE |
| HELP | HOW TO, ABOUT |

`LOAD MAP` asks for the name and fills the box in when the drive holds exactly one `.MAP`.
`BROWSE MAP` opens the file picker on the same list. `QUIT` under FILE is the way out.

`BY ADDRESS` takes the hex address a runtime error prints, `$34A7` or the whole error line; any hex
number in the text is found. `BY LINE` takes a BASIC line number, which is what the compiler's
`N STATEMENTS NOT COMPILED` line gives. `BY LINE` reads no map, because the number is already the
merged line a map lookup would answer with. Both need a map loaded first: the map's name is what
finds the symbol file.

## What it reads

Three files, all found from the map's name.

| | |
|---|---|
| the map | `NAME.MAP` or `M.NAME`, addresses to merged BASIC lines |
| the symbol file | `NAME.SRC.SYM`, or `NAME.SYM` when that is not there |
| the tokenised source | `NAME.SRC.PRG`, or `NAME.PRG` when that is not there |

BASLOAD names the symbol file and the tokenised source after the PRG it wrote, so a program built
through `NAME.SRC.PRG` has `NAME.SRC.SYM`. A missing symbol file costs the file name, the label and
the names block; a missing tokenised source costs the source window.

## What it shows

The address line says where the address landed: on a line's first opcode, so many bytes into it,
before the first mapped line, or past the last record in the map. A line number at or above 65,024
is the compiler's own setup code and is reported as that.

Under it, `BASIC LINE`, `FILE` and `NEAR` — the label at or above the line, with the source line
it sits on.

`SOURCE` is up to seven lines of the tokenised source, the looked-up line marked with `>` and the
three either side of it dimmed. The names in it are the crunched ones BASLOAD wrote.

`NAMES` turns up to six of those crunched names back into the real ones, two to a row, with the
source line each was first seen on. A name the symbol file does not carry gets its row and reads
`NOT A SYMBOL`.

The footer carries the loaded project: source files, source lines, compiled lines. Counting them
reads the symbol file and the map end to end, 9.4 seconds on the `GPB.HELP` fixture. The file count
caps at 40 and shows a `+` past that.

On that fixture, `$34A7` answers `GPB.HELP.BASL`, BASIC line 1669, near `HELP.BOOT` at source line
147, and the names block shows `N6$ = HELP.ROW$, LINE 186`.

## Build

Both steps run from the repository root, with this folder as the drive. `python` is off PATH; see
`docs/BUILDING.md`.

```
python source/gpc/build_basl.py     --drive samples/GPC.ERR GPC.ERR.BASL GPC.ERR.SRC.PRG
python source/gpc/compile_shared.py --drive samples/GPC.ERR GPC.ERR.SRC.PRG GPC.ERR.PRG GPC.ERR.MAP
```

```
python source/gpc/samplesbuild.py GPC.ERR
```

`samplesbuild.py` runs the same two steps and installs `GPC.ERR.PRG` and `GPC.ERR.OVL` into
`samples/GPC-HELP/`. It copies no runtime, in either direction: `GPB.HELP` owns the `.RT.` files in
that folder. This folder carries build 125 of the three, `GPC.RT.125.BIN`, `GPB.RT.125.BIN` and
`GP1.RT.125.BIN`.

The object is SHARED. It loads `GPB.RT.nnn.BIN` off the drive when it runs, the runtime with the GP
handlers rather than the core-only `GPC.RT.nnn.BIN`. 10,197 bytes of object against a 22,016 byte
ceiling.

**`GPC.ERR.OVL` travels with `GPC.ERR.PRG`.** It is 28,433 bytes and holds the six code regions and
the banked text. Without it the program prints `?OVL` and stops. The two names have to agree: the
object carries its own name and the bootstrap reads `<name>.OVL` from it.

**WARNING: shared, never standalone.** Shared leaves the runtime out of the object, which is the
point of a helper you run beside the program you are debugging. A standalone build is the wrong
artifact. `scratchpad/edbuild.py` builds standalone, so what it produces must not be copied over
these files.

## Where the code lives

Seventeen of the 22 modules run from RAM banks as `GP.BANKED` regions: bank 7 the utilities, 12 the
menus, 5 the pull-downs, 4 the GUI, 10 the dialogs, 8 the file handling. Two more banks hold
`GP.BANKEDSTR` text: 61 the keyword table and the HOW TO lines, 62 the menu texts and hints. The dialog, list and directory banks are claimed at boot through `BANKMGR`.

Five modules stay in low RAM. `GPB.INC.BL` is definitions and no code. `STASH.INC.BL` holds a `BANK`
statement, which the compiler refuses inside a region. `ERRSRC.INC.BL` writes `$00` to hold a bank
across a read, and `MENUKEY.INC.BL` reads the keyboard layout under `BANK 0` and leaves that bank
selected.

## `GPC-BASIC/` here

The 22 modules `GPC.ERR.BASL` includes. The `#INCLUDE` lines name `GPC-BASIC/`, so these copies are
the ones the build reads and nothing comes from the master library.

`ERRSRC.INC.BL` is 18,132 bytes here against 18,151 in the root `GPC-BASIC/`. It is the only module
that differs.

## Files

| | |
|---|---|
| `GPC.ERR.BASL` | the source |
| `GPC.ERR.PRG` | compiled SHARED, 10,197 bytes |
| `GPC.ERR.OVL` | the region overlay, 28,433 bytes |
| `GPC-BASIC/` | the 22 modules the source includes |
| `M.GPC.ERR` | a debug map, to try the lookup on |
| `GPC.BIN` | the compiler's engine, for compiling in this folder on the machine |
| `GPC.INPUT` | the engine's four lines for this program: source, object, map, `SHARED` |
| `BASLOAD-GPC.PRG`, `BASLOAD-GPC.BIN` | the tokeniser's front end and engine |
| `GPB.RT.125.BIN`, `GPC.RT.125.BIN`, `GP1.RT.125.BIN` | the runtimes a shared object loads |

Build outputs: `GPC.ERR.SRC.PRG`, `GPC.ERR.SRC.SYM` and `GPC.ERR.MAP`. Nothing under `samples/` is
git-ignored, so the object and the overlay are ordinary tracked files.
