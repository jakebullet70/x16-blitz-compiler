---
name: xbase-engine-planned
description: The XBase/dBase record keeper -- skeleton on disk, DBU-shaped admin, and the 255-byte record ceiling that has to be broken before it is written
metadata:
  node_type: memory
  type: project
  originSessionId: c8f9c4f1-af72-41d6-9f53-96e77718aa50
  modified: 2026-09-08T00:00:00.000Z
---

A dBase II / XBase record keeper for the X16: data on disk, one record visible at a time, engine
p-code in a `GP.BANKED` region, two databases open at once, and a bar-menu admin that is also the
demo. Design in `samples/XBASE/PLAN.md`; the file skeleton, and where the code disagrees with the
plan, in `samples/XBASE/readme.md`.

**Skeleton written 2026-09-08, nothing compiled or run.** Eleven files. The only check made on any
of it is that every `GOSUB` and `GOTO` target resolves.

**The GUI is already banked; the engine is not.** `THEME`, `MENUVERT`, `MENUBAR`, `LINEINPUT`, `GUI`
and `GUI2` sit in a `GP.BANKED SHIM.GUIBANK` region — bank 4 — reached through the eighteen low
memory shims of `SHIM.GUIBANK.INC.BL`, exactly the arrangement `GPBMODS.BASL` already runs. `STASH` stays
low because a region may not hold the `STASH` statement, `STRINGS` stays because `DB.JOIN` calls it
per record and a region cannot call a region, and `DBFORM` stays because it calls `LINEINPUT`.
`GUI2` has to be included even though nothing calls it: `SHIM.GUIBANK` shims `GUI.LISTBOX`. Bank 4 and
bank 8 are both `BANKMGR.CLAIM`ed at startup, with an `XB.BANKSTOP` exit if either is taken.

**THE BUILD PULLS FROM TWO DIRECTORIES AND THAT IS NOT A MISTAKE.** The library modules come from
`samples/GPB-MODS-TESTING/GPC-BASIC/`, because that is where the `.BODY` renames, `SHIM.GUIBANK` and
`BANKMGR` live. `GPB.INC.BL` is the one exception and comes from root. See
[[library-working-copy-then-root]] for the skew.

## Decided

**The admin is Clipper's DBU, not dBASE III's ASSIST.** After reading
`github.com/ibarrar/clipper/tree/master/CLIPPER5/SOURCE/DBU` -- `DBU.PRG` lines 241-330 are the whole
menu. Eight bar titles that are also F1-F8, dropdowns of two to six items, and an enable rule per
item, which is the part worth copying: DBU keeps a parallel boolean array beside every menu array
(`open_b[2] = "... .AND. .NOT. EMPTY(cur_dbf)"`), and that is what two work areas need. ASSIST
assembles a command line at the bottom of the screen out of the dropdown choices; the verdict on it
was "ASSIST's as bad".

**255 bytes a record is not acceptable. 512 is the floor.** The user's words: "255 is garbage and
not usible". See [[binput-caps-at-255-bytes]] for why 255 is where it lands today and why no single
constant raises it.

**Assembly is authorised for this work** -- "ASM if needed", 2026-09-08. That is scoped to breaking
the record ceiling, and does not retire [[ask-before-writing-asm]] generally.

**The admin has no function keys and no keyboard shortcuts.** DBU names its eight bar titles F1-F8
and the skeleton followed it until 2026-09-08, when the user took them out. ESC opens the bar and
the arrows walk it, which is what `samples/editor/EDITOR.BASL` does. A CTRL-C quit shortcut was
added in the same breath and removed in the next: **leaving is File Exit and there is no second way
to it.**

**The bar is `File Create Save Browse Utility Move Set Help`.** DBU's Open is File here, Help moved
from first to last, and Quit came out of Utility so that File Exit is not the same command twice.

**A field is an array element, not a call.** `DB.GOTO` splits the record into `DB.FLD$(area, field)`
and `DB.PUT` joins it back. The set-a-global-then-GOSUB-then-read-a-global shape
(`DB.F = 3 : GOSUB DB.FIELD`) was proposed and rejected. Naming the area in the subscript is what
makes dBASE's `SUPP->NAME` alias free. **This is what rules out holding the record in a bank**: the
fields still have to arrive in heap strings, so a banked record costs 32 blob calls a record to split
-- about 82,000 cycles of call overhead alone at ~2,570 a call, see [[strcase-call-overhead-measured]].

## Proposed, not yet approved

- **Paged records.** `DIM DB.BUF$(DB.PAGES-1)`, each 255, laid out **dense** rather than
  page-aligned so a future bank reader inherits no padding. A field straddles at most one boundary.
  Cache chunk and offset-in-chunk at open time off the absolute offset in the descriptor, so access
  stays one `MID$` and the division is paid once per field per open, not per access.
- **A separate stride for the header and descriptors.** "Record 0 IS the header" was settled to keep
  a seek at `N * stride` with no addition; at a 1,020-byte stride it wastes 1,020 bytes per
  descriptor, 33 KB before the first data record on a 32-field table. One float add per seek buys
  that back and is nothing against a stride-length `CHRIN` loop.
- **`MACPTR` into the string heap, not into a bank.** The blob in
  `samples/GPB-MODS-TESTING/GPC-BASIC/FILEDIR.INC.BL` already takes an arbitrary destination pointer
  and restores the caller's window on every exit path. Pointed at `GP.STRPTR(DB.BUF$(n)) + 1` it
  block-reads into a BASIC string. See [[macptr-wraps-banks-itself]].

## Owed, and known wrong in the code on disk

- `DB.MINSTRIDE` is 32; the header needs 43 (title at offset 27, 16 wide). `DB.RDHDR` reads 32, so
  the title comes back as five characters at **every** stride.
- `DB.CREATE` accepts a stride it cannot read back. No ceiling check.

## Still unmeasured

1. **Does a write in `,M` overwrite in place, or truncate?** The pivot of the whole format.
   `MKFIX.BASL` is written to answer it.
2. Does `DBFILE.SEEK`'s `CHR$(0)` reach the command channel intact? Most offset bytes are zero.
3. Do consecutive `PRINT#` calls after one `P` seek append cleanly?
4. Whether a 16-bit signed path anywhere in the `P` argument caps the file at 32,767 bytes.

See [[gp-banked-region-relocation]] and [[gp-banked-call-out-loses-the-bank]] for the region rules
that place the modules, [[claim-every-compile-time-bank]] for banks 5 and 6, and
[[gpc-string-blocks-never-shrink]] for why fields stay padded to width in the array.
