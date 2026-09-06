---
name: filedir-bank-split
description: "TODO: split FILEDIR into a bankable half and a low-memory half. The naive split only moves 22% of it -- FILL and STEP run WITH THE DATA BANK SELECTED, so they cannot live in a code bank either."
metadata:
  type: project
---

**Noted 2026-09-06, not built.** `FILEDIR.INC.BL` cannot go in a `GP.BANKED` region, which is what
stopped `GPBFILES.BASL` (GPBMODS + FILEIO + FILEDIR + a FILES panel) from compiling after the
tokenise ceiling was removed -- see [[basload-streams-to-a-file]].

**The obvious reason is `BANK`.** The compiler refuses a `BANK` statement inside a region, because
code fetched from the window cannot be running when the window changes. FILEDIR has four, in three
routines:

    FILE.DIR.OPEN   restore the caller's bank after the read
    FILE.DIR.SUCK   select the data bank, then GOSUB FILE.DIR.FILL
    FILE.DIR.NEXT   select the data bank, GOSUB FILE.DIR.STEP, restore

**The real reason is worse, and it is why a naive split is not worth doing.** `FILE.DIR.FILL` and
`FILE.DIR.STEP` are *called with the data bank already selected*. Put either in a CODE bank and its
own p-code is fetched from the DATA bank. They are also the two big ones:

| routine | code lines | bankable |
|---|---:|---|
| `FILE.DIR.FILL` (MACPTR reader) | 93 | **no** -- runs under the data bank |
| `FILE.DIR.STEP` (entry parser) | 112 | **no** -- runs under the data bank |
| everything else, 9 routines | 59 | yes, once the `BANK`s move out |

205 of 264 code lines, **78%**, are in the two that cannot move. A split that banks only the small
routines pays a shim per entry point to move a fifth of the module.

## What would actually work

**Push the window switch below BASIC**, so no `BANK` statement exists and no p-code ever runs under
a foreign bank: a low-memory `GP.ASM` trampoline that selects the data bank, does the access, and
restores -- *and is itself in low memory*, because a blob inside the region would stop fetching the
moment it changed the window. Then all of FILEDIR banks.

That is the same shape as the existing `FILE.DIR.FILL` MACPTR blob, moved down and given the bank
select. [[macptr-wraps-banks-itself]] means a block read crossing $BFFF needs no banking code of its
own, so the trampoline is smaller than it sounds.

Until then FILEDIR stays in low memory. FILEIO is clean -- no `BANK`, `BLOAD` or `BSAVE` -- and can
be banked today behind the [[gpc-shared-pcode-cap-is-rtbase]] budget.

See [[gp-banked-call-out-loses-the-bank]] for the constraint that decides where a *caller* can live.
