---
name: second-region-for-the-utilities
description: "BUILT: a program can carry several GP.BANKED regions -- THREE of them now -- and a module qualifies for one unless it holds a BANK statement. File I/O, GP.ASM blobs and DIM are all fine"
metadata:
  node_type: memory
  type: project
---

**BUILT 2026-09-08.** `samples/GPB-MODS-TESTING` grew a **second** `GP.BANKED` region, bank 7, and
put `APPSYS`, `BANKMGR`, `STRCASE`, `STRINGS`, `STRUSING`, `SORT`, `STASHVRAM` and `FILEIO` in it.
Resident object **15,254 -> 14,001 while gaining two modules and three panels**; workspace
6,656 -> 7,680. `LIB.UTILBANK.INC.BL` is the low-memory front door, 359 bytes for 35 shims.

**A THIRD REGION 2026-09-09, and the layout below is the current one:**

    LIB.GUIBANK    bank 4   THEME MENUVERT MENUBAR LINEINPUT GUI GUI2
    LIB.UTILBANK   bank 7   APPSYS BANKMGR STRCASE STRINGS STRUSING SORT STASHVRAM
    LIB.FUTILBANK  bank 8   FILEIO FILEDIR

`FILEDIR` left bank 4 and `FILEIO` left bank 7 to share one of their own, which frees no low RAM
-- both were banked already -- but empties bank 4 for the `GUI.FORM` of the CUA refactor. Bank 4
was at 7,424 of its 8,192 with `FILEDIR` still in it. Three regions had never been built before
this; they build, five overlays and all. The build is also what found the 37,632-byte `objPtr`
ceiling.

## What actually disqualifies a module, and it is one thing

**A `BANK` statement, and nothing else.** `CommandBankGuard` (`compiler/commands/gpbank.asm`) is
called from exactly one place in `commands.def` -- `BANK` -- and answers `.error_unimplemented`.
So the rule is not "anything that touches banks" and not "anything that does I/O":

- **File statements are fine.** `OPEN`, `INPUT#`, `PRINT#` and `CLOSE` on device 8 leave `$00`
  alone -- measured for `FILEDIR` in [[filedir-bank-split]]. `FILEIO` banks whole.
- **A `GP.ASM` blob is fine.** Its body never occupies a region either way: the pool is appended
  at the object tail in low RAM and the call is an absolute `.word`. Four of the eight hold one.
- **`DIM` and arrays are fine.** They are in the workspace like every other variable, so `BANKMGR`
  -- which *names* banks constantly but never selects one -- goes up with the rest.
- **`PEEK`/`POKE` are fine**, and this is the same fact from the other side: they save the selected
  bank, switch, access and restore, which is why `BANK` is the only statement that needs the guard.

What stayed down: `STASH` and `STASHFILE` (four `BANK`s and one), and `LIB.GUIBANK`, `LIB.FUTILBANK` and
`LIB.UTILBANK`, which are the shim layer itself.

## Several regions, and the two rules that shape them

`GPBANK_MAXREGIONS = 63` -- every bank a 512K machine has. **A region may not call another
region**: both live at `$A000`, so `GPBankMakeOffset` refuses the branch. Check the cross-module
call graph before splitting, and note it is cheap to check -- here the only call the GUI bank made
downwards was to `STASH`, which is in low memory and stayed there.

**Include order still binds across regions, and inside one.** `FILEDIR` reads `FILEIO`'s
`#DEFINE FILE.CHAN`, and BASLOAD substitutes a definition where it stands, so the file that
supplies one is written ABOVE the file that wants it -- which was a cross-region rule while they
sat in bank 4 and bank 7, and is now the order of two `#INCLUDE` lines inside `LIB.FUTILBANK`.
Getting it wrong gives
`SYMBOL NOT IN SCOPE IN FILEDIR.INC.BL:148` -- a line that has nothing to do with the definition.

## GP.DEFPROC cannot be banked with its body

A verb's call site is compiled into a jump to the body, and a call site in low memory jumping to
`$A000` selects no bank. **The declaration is the shim** -- it is the one place a `BANK` can go:

    GP.DEFPROC STR.UCASE, STRCASE.S$ RETURNS STRCASE.S$ : BANK LIB.UTILBANK : GOSUB STR.UCASE.BODY
    RETURN

so `STRCASE.INC.BL` keeps only `STR.UCASE.BODY` and `LIB.UTILBANK.INC.BL` carries both declarations.

## The cost, and who pays it

The eight modules' public entry points are renamed to `.BODY` permanently, so **the sample's
copies have forked from root `GPC-BASIC/`** -- see [[library-working-copy-then-root]], which now
runs in only one direction for these. And one shim file for eight modules means all eight are
required in any program that includes it, for the [[basload-define-rejects-digits]] reason: BASLOAD
resolves every label in every file, so a shim for an absent module is `LABEL NOT FOUND`.

**A full text pool is answered by moving a group, not by trimming it.** Bank 5 hit its 8,192, and
`BS.G.SAY` moving to bank 6 (8,194 -> 7,426, and 1,794 -> 3,074) was the whole fix -- `GP.BSTR`
names the group, so the call site never learns which bank it is in.

Related: [[gp-banked-region-relocation]], [[gp-banked-call-out-loses-the-bank]],
[[region-overlay-ovl-file]], [[pcode-runs-from-a-bank-proven]], [[claim-every-compile-time-bank]],
[[run-side-workspace-read-from-the-prg]], [[gpbmods-resident-pcode-breakdown]].
