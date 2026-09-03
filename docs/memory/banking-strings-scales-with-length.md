---
name: banking-strings-scales-with-length
description: "Moving held strings to a RAM bank wins with string LENGTH, not count -- the editor's menus broke even at 249 bytes saved against 245 spent; plus the ED-MENUS.BASL layout and the ED.ALTKEYS bank trap"
metadata:
  node_type: memory
  type: project
---

**Before banking any set of strings, ask how LONG they are, not how many.** A concrete block is
`max(10, len * 1.5) + 3`, so a 4-character string costs 13 bytes and nets about **6** when moved to
a bank, while a 30-character one costs 48 and nets about **41**. Count barely matters; length is
the whole term.

**Measured 2026-09-03, `samples/editor` menus -> bank 5 (`ED-MENUS.BASL`), and it BROKE EVEN.**
`FRE(0)` either side of `ED.MENU.SETUP`, release build:

| | before | after | |
| --- | --- | --- | --- |
| low RAM taken by menu setup | 473 | 224 | saved 249 |
| p-code | 12,910 | 13,155 | cost 245 |
| p-code, as shipped | 12,882 | 13,118 | cost 236 |
| free at that point | 5,449 | 5,420 | **net -29** |

The strings really were 249 bytes and really are gone; `EDMNU.PUT` + `EDMNU.GET` + the setup lines cost
the same again. **A TODO estimate of "order 1 KB" was wrong by 4x** -- only 14 of 42 DIMmed slots
were ever populated. `FRE(0)` deltas WITHIN one build are the right instrument here: the absolute
number moves with code size, the delta does not. See [[measure-before-changing-code]].

**Banking helps strings you HOLD, never strings you USE.** A string value is a bare 16-bit pointer
with no bank byte (`read_string.asm`), ~111 sites dereference it, and `GP.STRPTR` hands the raw
address to BASL as well -- so `MENUVERT.ITEM$` had to stay in low RAM as the staging array. The heap
itself cannot move: one 8K window cannot hold the three blocks `A$ = B$ + C$` needs live at once.

**Two traps this cost time on:**

- **`ED.ALTKEYS` selects bank 0 for the KERNAL keymap**, so a banked fetch inside its scan loop
  clobbers it. Fixed by scanning `MENU.HOT$` (a low-RAM scalar) instead of the titles -- which also
  fixed a latent bug, since an accelerator need not be a title's initial. See
  [[gpc-editor-alt-keys-need-the-keymap]], [[gpc-bank-statement-not-poke-zero]].
- **Every accessor must set its own BANK.** House rule already, in `ED-STORE.BASL` and
  `STASH.INC.BL`; a routine relying on someone else's selection breaks on the next reorder.

**`ED-MENUS.BASL`'s layout is the fixed-stride variant** -- `[len][chars]`, slot N at
`$A000 + N * 32`, no allocator and no pointer table -- deliberately unlike `ED-STORE.BASL`'s bump
allocator, because a small fixed set does not need one. Editor bank map is now 1-3 line table,
4 GUI stash, 5 menus, 6+ document arena.

**BASLOAD resolves a hyphenated `#INCLUDE`** (`ED-STORE.BASL`, `ED-MENUS.BASL`). Nothing in the
tree had a hyphen in a source filename before this, so it was untested.

Related: [[gpc-string-blocks-never-shrink]], [[string-heap-scavenger]], [[headless-basl-build-recipe]].
