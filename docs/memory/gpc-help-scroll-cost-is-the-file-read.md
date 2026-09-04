---
name: gpc-help-scroll-cost-is-the-file-read
description: "GPC-HELP's scroll is dominated by re-reading the .HLP on every keypress, not by moving cells -- measured 04/09/26"
metadata:
  type: project
---

**Making the cell move faster bought 4%.** Measured on the X16, 50 iterations, jiffies:

| | STASH slide | VRAM memory_copy |
|---|---:|---:|
| shift only, down | 499 | **81** |
| whole scroll step | 2245 | **1838** |
| full repaint (control) | 1867 | 1870 |

The slide itself went 10.0 -> 1.6 jiffies a step, a real 6.2x. But a whole scroll step is 36.8
jiffies against a full repaint's 37.4 -- **1.6% -- because only 1.6 of those 36.8 are the slide.**
The other 35 are `HELP.PAGE.DRAW` re-`OPEN`ing the `.HLP` and `LINPUT#`-ing the WHOLE topic on every
keypress. It cannot stop at the bottom of the visible window because the same pass collects the
cross-references; the code says so ("they have to be collected on this pass because there is no
other one"). Scrolling one line re-reads up to 120 lines to find the one line that is new.

**Before the change the STASH slide was SLOWER than just repainting the page** (44.9 vs 37.4 jiffies)
-- it was buying the flicker fix with time.

**The footer flickers for the reason the text region used to:** `HELP.STATUSBAR` does a full-width
`GP.FILL` and then `GP.PRINTAT`s over it -- blank-then-repaint -- and `HELP.PAGE.LOOP` calls it every
pass, not only when the text changed.

**Sizes.** Worst topic 120 lines / 5,278 bytes; `HELP.VIEW` is 27 of 30 rows. The attribute is
per-ROW, not per-cell (`HELP.PAGE.ROW` picks one for the line), so a cached row is 80 chars + 1
attribute byte. The VRAM shift cost +218 bytes of p-code and a page of workspace.

See [[scrolling-a-screen-region]] -- whose own "pick" line says option 3 for one pane that scrolls
constantly, which is this -- and [[gp-drawing-targets-layer-1]].

## FIXED, 04/09/26 -- and what the fix ran into

The topic now loads ONCE into bank 9 (`HELP.TBANK`) on entry and a scroll paints a row out of RAM.
The VERA `memory_copy` slide stayed. Measured in `testing/SCRLTST.BASL`, jiffies a scroll step:
shipped 36.8, bank + STASH 12.6, bank + VERA slide ~2.6.

**THE WORKSPACE HAS ABOUT A KILOBYTE IN IT, and that is the binding constraint on this program.**
The self-check prints `FRE AT THE END`: **1,046 bytes** before the change, 969 after. Three `DIM`s of
`HELP.MAXLINES` for the line table were 840 bytes and the answer was `OUT OF MEMORY` before the index
finished loading -- so **the line table went into the bank too**, four bytes a line at the front,
offset/length/kind, text above it. It costs nothing that is scarce.

**`HELP.MAXIX` was 160 and is now 120.** An index row costs TEN bytes of workspace whether it is used
or not -- four integer arrays and a string pointer -- so forty unused rows was four hundred bytes in
a program that had one thousand. The library has 91 rows.

**The load is a POKE a character: 158 jiffies, 2.6 seconds, on the largest topic**, against 37 to
open one before. `HELP.PAGE.LOADING` paints the title bar and "Reading ..." so it reads as work.
The one-call version does NOT work and was measured, not assumed -- see
[[stash-leaves-its-bank-selected]] for the sibling trap and the note in `HELP.PAGE.LOAD`:
`memory_copy` takes no bank argument, the bank must be live in `$00` when it runs, and `BANK` only
applies around a `PEEK` or a `POKE`. 91 jiffies and 214 of 218 bytes wrong. Holding a bank across a
KERNAL call needs `GP.ASM`.

**Run the self-check before believing any of this again:** comment out `#DEFINE HELP.RELEASE 1`,
build as `HELPCK`, run headless. It prints rows opened, lines read, cross references resolved and
`FRE`. The rewrite matches the baseline on every number.
