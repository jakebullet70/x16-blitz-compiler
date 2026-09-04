---
name: stash-leaves-its-bank-selected
description: "STASH.SAVE and STASH.RESTORE each do BANK STASH.BANK, so anything reading banked data after one must re-select its own bank"
metadata:
  type: reference
---

**`STASH.SAVE` and `STASH.RESTORE` both do `BANK STASH.BANK` internally**, and neither puts back
what was selected. Any `PEEK` after a STASH call reads the STASH BUFFER unless the caller selects
its own bank again.

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
