# KV-BIN-STORE

This sample is a small registry. One file of fixed 128-byte records holds
keys and values that every program on the drive can share. Three programs
work on the same file, `SETTINGS.KVB`, in the folder they run from.

## Files

| File | What |
|---|---|
| `KV-BIN-STORE.PRG` | The registry editor, compiled. 22,417 bytes. |
| `KV-BIN-STORE.OVL` | The editor's banked code and text. 26,893 bytes. |
| `KV-BIN-STORE.BASL` | The editor's source, in GPC-BASIC. |
| `KBS.TEXT.INC.BL` | Source. Every string the editor shows. |
| `KVBIN-BASIC.PRG` | Plain X16 BASIC. Runs in ROM BASIC. 3,444 bytes. |
| `KVBIN-BASIC.BASL` | Its source, for BASLOAD. |
| `KVBIN-PROG8.PRG` | The Prog8 program. 3,855 bytes. |
| `KVBIN-PROG8.P8` | Its source, one file. |
| `README.md` | This file. |

`SETTINGS.KVB` is not in the folder. The first run makes it. `KVBIN.INC.BL`,
which both `.BASL` files include, is in the release's `GPC-BASIC/` folder.

`KV-BIN-STORE.PRG` is compiled EMBEDDED. It carries its own runtime, so no
runtime file is needed beside it. It reads `KV-BIN-STORE.OVL` when it starts.
The name is fixed when the program is compiled, and the file is opened from
the current folder of drive 8. Keep both files in one folder under these
names. A missing or short `.OVL` stops the program with `?OVL`.

## Run it

Start in the release root.

| Step | Type | Result |
|---|---|---|
| 1 | `DOS"CD:SAMPLES"` | Changes to `SAMPLES`. |
| 2 | `DOS"CD:KV-BIN-STORE"` | Changes to `SAMPLES/KV-BIN-STORE`. |
| 3 | `LOAD "KV-BIN-STORE.PRG",8` | Loads the editor. |
| 4 | `RUN` | Reads the `.OVL` and opens the editor. |

With no `SETTINGS.KVB`, the editor asks
`SETTINGS.KVB IS NOT HERE. CREATE IT WITH 40 FREE SLOTS?` YES makes it and
writes the six sample keys in `KBS.TEXT.INC.BL`. NO leaves no store open.

In the same folder, `LOAD "KVBIN-BASIC.PRG",8` and `RUN` start the ROM BASIC
program. `LOAD "KVBIN-PROG8.PRG",8` and `RUN` start the Prog8 program.

## The editor

The editor runs in `SCREEN 1`, 80x30, with the menu bar on the top line. The
list on the left shows 20 slots at a time, each with its number and key. The
panel on the right shows the slot under the bar, read from the file: `KEY`,
`SLOT`, `AT BYTE`, `LENGTH` and `VALUE`. A line under the list reads
`n OF m SLOTS USED` and names the view. The bottom line names the last store
call and the jiffies it took. A failed call adds the reason.

UP and DOWN move the bar one row. PGUP and PGDN move it 20 rows. HOME and END
move it to the first or the last row. ESC opens `FILE`. ALT with F, K, V or H
opens that menu. A key at the start of a table row does what the row does.

| Menu | Row | Does |
|---|---|---|
| `FILE` | `NEW STORE` | Asks a name. Makes a store of 40 free slots. |
| | `OPEN STORE` | Asks a name and reads that store. |
| | `EXPAND STORE` | Adds 20 free slots, after a YES. |
| | `EXPORT TEXT` | Writes each used key as a line, `KEY)!(VALUE`. |
| | `IMPORT TEXT` | Writes each `KEY)!(VALUE` line into the store. |
| | `EXIT` | Asks `LEAVE THE EDITOR?` YES ends the program. |
| `KEY` | `NEW KEY` | INS. Asks a key of up to 12 characters, then a value. |
| | `EDIT VALUE` | RETURN. Edits the value. On a free slot, adds a key. |
| | `DELETE KEY` | DEL, BACKSPACE. Asks `DELETE <key>?` YES frees the slot. |
| | `GET BY NAME` | Asks a key and moves the bar to it. |
| `VIEW` | `USED KEYS` | Lists the slots that hold a key. |
| | `ALL SLOTS` | Lists every slot. A free one shows `(FREE)`. |
| | `READ AGAIN` | Reads the file again. |
| `HELP` | `KEYS`, `FILE LAYOUT` | Each shows a box of help. |

The editor starts on `USED KEYS`. `NEW STORE` asks before it replaces a file.
The list holds 100 slots, and `EXPAND STORE` refuses a store that would pass
100. A new key in a full store asks `THE STORE IS FULL. ADD 20 FREE SLOTS?`
YES expands the store and writes the key. The edit field holds 70 characters.
The panel shows a longer value whole, and `EDIT VALUE` refuses it.

An exported line ends CR LF. The default name is `SETTINGS.TXT`, and a file
of that name is replaced. `IMPORT TEXT` also takes lines ended CR alone. A
key in the file replaces the store's value for it, and the other keys stay. A
line with no `)!(` after a key is skipped and counted. The first write that
fails ends the import.

## The two text programs

`KVBIN-BASIC.PRG` and `KVBIN-PROG8.PRG` behave the same. With no
`SETTINGS.KVB`, each makes an empty store of 40 slots without asking and
prints `NEW STORE`. For a file that is not a store, each prints
`SETTINGS.KVB IS NOT A KVBIN STORE` and ends. The menu line is
`L LIST   G GET   P PUT   D DELETE   Q QUIT`, and it takes one key.

| Key | Asks | Prints |
|---|---|---|
| L | | Every used key as `KEY = VALUE`, then `n OF m SLOTS USED`. |
| G | `KEY:` | The value, or `NO SUCH KEY`. |
| P | `KEY:`, `VALUE:` | `SAVED IN SLOT n`, or `THE STORE IS FULL`. |
| D | `KEY:` | `DELETED FROM SLOT n`, or `NO SUCH KEY`. |

Q returns to BASIC. An empty key line goes back to the menu. A typed line is
one screen line. Neither program expands a store. `FILE`, `EXPAND STORE` in
the editor does. Each of the three programs reads what the other two wrote.

## The file

The file is records of 128 bytes. Record 0 is the header. Record n is slot n,
at byte n times 128.

| Record | Bytes | Holds |
|---|---|---|
| Header | +0 to +5 | `*KVBIN` |
| | +6, +7, +8 | The version 1, key length 12 and record length 128. |
| | +9, +10 | The slot count, low byte first. |
| Slot | +0 to +11 | The key, padded with $00. |
| | +12 to +126 | The value, padded with $00. |
| | +127 | $00 |

$00 at +0 of a slot marks it free. A key is cut to 12 characters and a value
to 115, and neither holds $00. The three programs write both in upper-case
PETSCII, the letters ROM BASIC shows as capitals. A write keeps a key's slot,
and a new key takes the first free slot.

## Using the store in your own program

In BASIC, include `KVBIN.INC.BL`, set the in variables and `GOSUB` the
routine. The module tokenises for ROM BASIC and compiles under GPC unchanged.

```
#INCLUDE "GPC-BASIC/KVBIN.INC.BL"
KVBIN.FNAME$ = "SETTINGS.KVB"
KVBIN.KEY$ = "USER.NAME"
KVBIN.VALUE$ = "STEVE"
GOSUB KVBIN.PUT
KVBIN.KEY$ = "USER.NAME"
GOSUB KVBIN.GET
IF KVBIN.OK THEN PRINT KVBIN.VALUE$
```

`KVBIN.OK` is -1 when the call is done and 0 when it is not. `KVBIN.WHY` then
says why, as a `KVBIN.WHY.*` number. Section 4.26 of `GP-BASIC.md`, and the
same topic in `GPC.HELP`, list every routine and variable. Every routine
opens logical files 12 and 15, and closes them.

In Prog8, copy the `kvbin` block from `KVBIN-PROG8.P8`, the counterpart of
`KVBIN.INC.BL`. The block needs `%import diskio` and `%import strings`.

```
str storename = "settings.kvb"
kvbin.filename = &storename
void kvbin.put("user.name", "steve")
if kvbin.get("user.name")
    txt.print(kvbin.value)
```

A routine returns true when it is done, and `kvbin.why` says why not. The
block's header lists every routine. The block has no `AT` and no `EXPAND`.
Every routine uses the two `diskio` file channels.

WARNING: Type Prog8 text in lower case. The compiler turns it into the
PETSCII letters that ROM BASIC shows as capitals.

## Rebuilding

The two `.BASL` files cannot be rebuilt in `SAMPLES/KV-BIN-STORE/`. Their
`#INCLUDE` lines need a `GPC-BASIC/` folder beside the source, and that
folder has none. The compiler is not there either. See the release root's
`README.md`, section "Compiling a program".

`KVBIN-PROG8.P8` builds in any folder with Prog8 12.0.1. The command is
`prog8c -target cx16 KVBIN-PROG8.P8`.

<!-- release: the rest is for the source tree -->

## In the repository

`USER-RUNS\kv-bin-store-demo.bat`, `USER-RUNS\kvbin-basic-demo.bat` and
`USER-RUNS\kvbin-prog8-demo.bat` each run one of the three programs in the
emulator, with the sample folder as the drive.

The builds, from the repository root:

```
python source\gpc\samplesbuild.py KV-BIN-STORE
python source\gpc\samplesbuild.py KVBIN-BASIC
python source\gpc\samplesbuild.py KVBIN-PROG8
```

The last needs Java and the Prog8 jar that `PROG8C` names in
`samplesbuild.py`. The runtime is build 131.

`GPC-BASIC/` holds the 17 modules `KV-BIN-STORE.BASL` includes: `GPB.INC.BL`,
`STASH.INC.BL`, `DOS.INC.BL`, `KVBIN.INC.BL`, `APPSYS.INC.BL`,
`BANKMGR.INC.BL`, `STASHVRAM.INC.BL`, `THEME.INC.BL`, `MENU.INC.BANKED.BL`,
`MENU.INC.BL`, `MENUPULL.INC.BL`, `LINEINPUT.INC.BL`, `GUI.INC.BL`,
`COMBO.INC.BL`, `CHECK.INC.BL`, `GUI-DIALOGS.INC.BL` and `MENUKEY.INC.BL`.
