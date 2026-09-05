---
name: stash-leaves-its-bank-selected
description: "FIXED 2026-09-05 -- STASH now restores the caller's bank. What it looked like before, and why the symptom named the wrong routine"
metadata:
  type: reference
---

**FIXED 05/09/26. `STASH.SAVE` and `STASH.RESTORE` now leave by one exit, `STASH.DONE`, which puts
the caller's bank back.** `STASH.BANK.HOLD` captures it first, and it has to be a GP.ASM blob
because BASIC cannot see the register -- `PEEK` selects and restores around every access, so
`PEEK(0)` reads back whatever `BANK` last set rather than what the hardware holds.

The second reason it had to be fixed, and the one that forced it: banked p-code is FETCHED from
`$A000`, so a `STASH` followed by a call into a `GP.BANKED` region fetched the next instruction out
of the stash bank. A silent hang, nowhere near the STASH. `testing/BANKV.BASL` is that program --
against the old module it prints `V2 BANK AFTER STASH 8` and stops. See
[[gp-banked-region-relocation]].

**What it did before**, and worth keeping because the symptom named the wrong routine: any `PEEK`
after a STASH call read the STASH BUFFER unless the caller selected its own bank again.

**What it looks like:** text read from a bank after a STASH slide comes out with a junk glyph
between every character -- `#G#U#I#.#Y#N#` for `GUI.YN`. Those are the cell ATTRIBUTE bytes: the
buffer holds char, attr, char, attr, and reading it as text alternates the two. It reads as a
corrupt scroll, so the slide gets the blame; the slide is fine.

**Found 04/09/26** in `testing/SCRLTST.BASL`, holding a help topic in bank 9 and sliding with a
STASH in bank 10. The fix is one line -- `BANK` your own bank at the top of the read routine, not
once at startup.

**It is invisible without a cell-by-cell check.** `STASH DOWN 27 ROWS DIFFER / VERA DOWN OK` is what
named it: reach the same position by sliding and by repainting, checksum each row, compare. One
checksum a ROW, because 29 numbers name the row that is wrong where one number only says something
is. See [[scrolling-a-screen-region]], whose closing rule is exactly this, and
[[gpc-bank-statement-not-poke-zero]].
