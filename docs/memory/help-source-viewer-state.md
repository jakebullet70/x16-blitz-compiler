---
name: help-source-viewer-state
description: "GPC.HELP shows example programs as coloured source; written and compiled clean 2026-10-02, never run on the X16; what is owed and how to re-check the blobs"
metadata:
  node_type: memory
  type: project
  originSessionId: d3ac16d2-cd1b-4147-b724-55dc40a31b99
  modified: 2026-10-02T14:12:41.821Z
---

GPC.HELP opens a `.EXP.BL` example as source, in syntax colour, with LEFT and RIGHT for wide lines.
Written 2026-10-02 in `GPC-BASIC-TOOLS-SRC/GPC-HELP/GPC.HELP.BASL` (the "An example program, read as
source" section), `MKHELP.PY` and `readme.md`. Uncommitted as of that date.

**State: built, not run.** On 2026-10-02 BASLOAD tokenised it and GPC compiled it SHARED with no
error, so GPC accepts both `GP.ASM` blobs. Tokenised 52,341 bytes (was 41,597), `GPC.HELP.PRG`
10,136 (was 8,286), `GPC.HELP.OVL` 24,333 (was 22,795). The viewer has not run on the X16. Each
further step is the user's to call. See [[no-ship-language-this-is-dev]].

**Content is in place, 2026-10-02.** `python MKHELP.PY`, run from `GPC-BASIC-TOOLS-SRC/GPC-HELP`,
rewrote `HELP-TXT`: 76 topics, 29 examples, 196 of 210 index rows, 6,046 of 6,302 index characters,
so 256 are left. `GPC.HELP.IDX` and 22 `.HLP` files changed, and every change is an example pointer
turned into a cross reference, or the `E` rows. Topic 8 fell from 121 lines to 93. `GPC-HELP.md` did
not change. `GPC-HELP-TESTING.md` and `GPC-HELP.WIN.md` were not regenerated.

The 29 `.EXP.BL` files were copied from `GPC-BASIC/` into `GPC-HELP/GPC-BASIC/`, 138,667 bytes,
untracked. The viewer opens `//GPC-BASIC/:NAME`, then `//GPC/GPC-BASIC/:NAME`. The copies are not
kept in step with the masters by anything.

**Owed before it can be called working:**

- Run it on the X16. No line of the change has executed.
- The four ink rows in `HELP.SYN.INK` are MSEDIT's, with GRAY and CUSTOM given the dark row. Nobody
  has looked at them on the X16.

**The check that stands in for a build:** `python source/scratch/helpblobs.py`. It pulls the two
blobs and the keyword table out of the `.BASL`, assembles them with 64tass, and runs them in a small
65C02 emulator over every line of all 29 examples at three scroll offsets, against a classifier
written in Python. It passed 11,901 runs with 0 wrong. It also counts labels and label references
against GPC's limits of 32 and 64 a block: 21 and 46 for the scan, 17 and 29 for the paint.

**Why two blobs and not one:** the 64 label references a block. One lexer with the table lookup
inside it came to 63. The scan marks a word as class 6 and the paint blob resolves it.

**Why one keyword a record:** more than 127 records rules out an X-indexed directory, and several
words a record needs an end-of-record test inside the compare loop. One word a record keeps the
compare to a length byte and a straight match.

Left out on purpose: colouring label definitions, `DATA` items, and `:` code lines in ordinary
topics.

Related: [[msedit-is-the-syntax-colouring-master]], [[gpasm-implementation-status]],
[[gp-bankedstr-literal-text-in-a-bank]], [[gpc-help-scroll-cost-is-the-file-read]].
