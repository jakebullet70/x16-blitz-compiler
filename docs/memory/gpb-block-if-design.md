---
name: gpb-block-if-design
description: GP.IF/GP.ELSEIF/GP.ELSE/GP.ENDIF shipped 2026-08-30 on branch gp-if at 14 runtime bytes; incl. the GP.ELSE -> GP.OTHER rename
metadata:
  node_type: memory
  type: project
  originSessionId: d7531322-9a88-4f9a-8bdd-54f6afe99cb4
---

**SHIPPED 2026-08-30, branch `gp-if`, commit `8e9c1af`.** Documented as §11 of
`docs/blitz/GP-BASIC.TIERS.md`, which has the full account — this note keeps only what a future
session needs that the tree does not already say.

**The cost is 14 runtime bytes, not 12, and the 2 that surprised me are `MOFSizeTable`.** I had
checked `source/runtime/_library.asm`, found no `MOFSizeTable`, and concluded the size table was
compiler-only and free. It is in `common.library`, which the application links **before**
`10object.divider` — so everything in it sits below `GPBase` and IS copied into every object. **Rule:
"is it in the copied runtime?" is answered by the ADDRESS in `code.lbl` against `GPBase`, never by
which `_library.asm` a symbol appears in.** `MOFSizeTable` measured `$285a`.

Decisions (the user's, not derivable from code): `THEN` mandatory, single-line illegal, `GP.SELECT`
kept, and `GP.SELECT`'s `GP.ELSE` renamed `GP.OTHER` with **id 52836 staying on `GP.OTHER`** so old
tokenised PRGs keep their meaning; the new `GP.ELSE` took 52828.

**What the build actually cost:** `GPC.BLITZ.BIN` 22,498 -> 22,731, which crossed a page, so
`FreeMemory` moved `$6000` -> `$6100` and the object buffer lost 256 B (16,128 -> 15,872 — and the
README was already stale claiming that buffer does not bind, see
[[gpc-blitz-runtime-slack-and-limits]]). Core cushion 40 B -> **26 B**
([[gpc-core-page-cushion-below-gpbase]]). No compiled program grew.

**Headless test recipe, which is what took the longest to work out:** `python bin/tokenise.zip src.bas
SOURCE.PRG` (the host tokeniser DOES know the `GP.*` keywords), a `GPC.INPUT` of
`SOURCE.PRG\nOBJECT.PRG\n\n`, then **`cd` into the work dir first** — `-prg` resolves against cwd, not
`-fsroot`, and gets "Cannot open" otherwise. `x16emu -sound none -zeroram -fsroot "$W" -prg
GPC.BLITZ.BIN -run -warp -echo raw`. Filter with `tr -d '\000\r' | tr -cd '\40-\176\n'`; the compiler
ends with `OK CODE n FREE n RT n GP IN|OUT`, and **`GP OUT` is the proof the 2K GP block was cut**.
Each emulator round trip is ~90 s, so batch the cases.

Related: [[gpb-block-openers-must-not-defer]] (why all four helpers `stz deferErrors`).
