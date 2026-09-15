---
name: second-region-for-the-utilities
description: "BUILT: a program can carry many GP.BANKED regions -- GPBMODS has six code regions and two text banks -- and a module qualifies for one unless it holds a BANK statement. Regions call each other; a GOTO or ON GOSUB across a region boundary is refused"
metadata:
  node_type: memory
  type: project
---

**BUILT 2026-09-08.** `samples/GPB-MODS-TESTING` grew a **second** `GP.BANKED` region, bank 7, and
put `APPSYS`, `BANKMGR`, `STRCASE`, `STRINGS`, `STRUSING`, `SORT`, `STASHVRAM` and `FILEIO` in it.
Resident object **15,254 -> 14,001 while gaining two modules and three panels**; workspace
6,656 -> 7,680. A third region followed on 2026-09-09, and that build found the 37,632-byte `objPtr`
ceiling.

**The layout since 2026-09-14.** Each region in `GPBMODS.BASL` is a list of `#INCLUDE` lines
between `GP.BANKED` and `GP.ENDBANKED`, and the bank numbers are `#DEFINE`d at the top of the file:

    GM.UTILCODE    bank 7   APPSYS BANKMGR KB STRCASE STRINGS STRUSING SORT STASHVRAM STASHVRAMGC
    GM.THEMECODE   bank 9   THEME
    GM.GUICODE     bank 4   MENUVERT MENUBAR LINEINPUT GUI GUI2
    GM.COMBOCODE   bank 10  COMBO
    GM.FUTILCODE   bank 8   FILEIO FILEDIR
    GM.MODSCODE    bank 11  GMX.STRINGS, GMX.FILES and what they call
    GM.TEXTBANK    bank 5   GP.BANKEDSTR text, pool one
    GM.TEXTBANKB   bank 6   GP.BANKEDSTR text, pool two

`THEME` and `COMBO` have banks of their own because the GUI region reached its 8,192 bytes.
`FILEDIR` left bank 4 and `FILEIO` left bank 7 to share bank 8, which freed no low RAM, since both
were banked already, but made room in bank 4 for `GUI.FORM`. Bank 4 was at 7,424 of its 8,192 with
`FILEDIR` still in it.

## What actually disqualifies a module, and it is one thing

**A `BANK` statement, and nothing else.** `CommandBankGuard` (`compiler/commands/gpbank.asm`) is
called from exactly one place in `x16_command.def` -- `BANK` -- and answers `.error_unimplemented`
when a region is open. So the rule is not "anything that touches banks" and not "anything that
does I/O":

- **File statements are fine.** `OPEN`, `INPUT#`, `PRINT#` and `CLOSE` on device 8 leave `$00`
  alone -- measured for `FILEDIR` in [[filedir-bank-split]]. `FILEIO` banks whole.
- **A `GP.ASM` block is fine.** Since `c3320d1` a block inside a region is assembled into the
  region's bank and counts toward its 8,192. A block that stores to `$00` must be `GP.ASM LOW`,
  which stays in low memory; without `LOW` the compile stops with
  `BANKED GP.ASM WRITES $00, USE GP.ASM LOW`.
- **`DIM` and arrays are fine.** They are in the workspace like every other variable, so `BANKMGR`
  -- which *names* banks constantly but never selects one -- goes up with the rest.
- **`PEEK`/`POKE` are fine**, and this is the same fact from the other side: they save the selected
  bank, switch, access and restore, which is why `BANK` is the only statement that needs the guard.

What stays down: `STASH` and `STASHFILE`, which hold four `BANK`s and one. A region may still call
them. The call out of a region is a `.bgosub` with the region's own bank, so their `BANK` does not
strand the caller.

## Several regions, and the rules between them

`GPBANK_MAXREGIONS = 127`, code and text together, in banks 2 to 255.

**A region may call another region.** A `GOSUB`, `GP.SUB`, `GP.FN` or `FN` into a region from
outside it compiles to `.bgosub`, which selects the region's bank, and `RETURN` puts the caller's
bank back ([[compiler-emitted-bank-switch]]). GPBMODS depends on it: `GUI.FORM` in bank 4 GOSUBs
`COMBO.DRAW` and `COMBO.KEY` in bank 10. Before 2026-09-13 a region could not call another, because
both run at `$A000` and `GPBankMakeOffset` refused the branch. The library then needed a low-memory
shim for every entry point, and a split had to follow the cross-module call graph.

Still refused across a region boundary:

- **A `GOTO` into a region from outside it**, from low memory or from another region: `GOTO`,
  `IF .. GOTO`, `IF .. THEN <line>` and `ON .. GOTO`. `GPBankGotoGuard` stops the compile with
  `NOT IMPLEMENTED` in pass one. A `GOTO` inside one region, or out of a region to low memory, is
  allowed.
- **`ON .. GOSUB`** into a region, out of one or between two, with `ON GOSUB IN OR OUT OF GP.BANKED`.
  Its table steps 3 bytes an entry and a `.bgosub` is 4.

So a split is checked for `GOTO`s and `ON .. GOSUB`s across the new boundary, not for calls.

**Include order still binds across regions, and inside one.** `FILEDIR` reads `FILEIO`'s
`#DEFINE FILE.CHAN`, and BASLOAD substitutes a definition where it stands, so the file that
supplies one is written ABOVE the file that wants it. That was a cross-region rule while they sat
in bank 4 and bank 7, and is now the order of two `#INCLUDE` lines inside the `GM.FUTILCODE` region.
The same rule puts the `THEME` region above the GUI region, whose modules read its role numbers, and
the `COMBO` region below it. Getting it wrong gives
`SYMBOL NOT IN SCOPE IN FILEDIR.INC.BL:148` -- a line that has nothing to do with the definition.

## GP.DEFPROC verbs live in their modules

Until 2026-09-13 a verb could not be banked with its body. Its call site jumps to the body, and a
jump from low memory to `$A000` selected no bank, so the declaration sat in a shim file with a
`BANK` before the `GOSUB`. A call into a region now selects the bank, so `STR.UCASE` and
`STR.LCASE` are declared in `STRCASE.INC.BL` and `FILE.SIZE` in `FILEIO.INC.BL`, each on the line
above its body. None has a label: a verb is a name, and a label of the same name is
`DUPLICATE SYMBOL`.

## What the shims cost, and what replaced them

The 2026-09-08 build renamed the eight modules' entry points to `.BODY` and put 35 shims in
`SHIM.UTILBANK.INC.BL`, 359 bytes of low memory. The sample's copies forked from root
`GPC-BASIC/`, and one shim file for eight modules made all eight required in any program that
included it, for the [[basload-define-rejects-digits]] reason.

Step 3 of [[compiler-emitted-bank-switch]] deleted the shims and the `.BODY` names on 2026-09-13.
Each module is one `.INC.BL`, included inside a region or outside one, and root's seven are copies
of the working copy again ([[library-working-copy-then-root]]). The bank numbers moved from the
shims into the programs as `#DEFINE`s. `GPC-BASIC/BANKED-OR-NOT.md` holds the rules.

**A full text pool is answered by moving a group, not by trimming it.** Bank 5 hit its 8,192, and
`BS.G.SAY` moving to bank 6 (8,194 -> 7,426, and 1,794 -> 3,074) was the whole fix -- `GP.BSTR`
names the group, so the call site never learns which bank it is in.

Related: [[compiler-emitted-bank-switch]], [[gp-banked-region-relocation]],
[[gp-banked-call-out-loses-the-bank]], [[region-overlay-ovl-file]], [[pcode-runs-from-a-bank-proven]],
[[claim-every-compile-time-bank]], [[run-side-workspace-read-from-the-prg]],
[[gpbmods-resident-pcode-breakdown]].
