---
name: bmxview-two-copies-one-master
description: BMXVIEW has two sources on purpose; the BMXVIEWER folder is the master and changes flow back to the library sample
metadata:
  type: project
---

BMXVIEW exists as two files, and both stay.

`GPC-BASIC-TOOLS-SRC/BMXVIEWER/BMXVIEW.BASL` is the master. It is the full
featured example program, and every change starts here.

`GPC-BASIC/BMXVIEW.EXP.BL` is the downstream copy. It is the short sample a
user reads in the library, one of 28 `.EXP.BL` files, and it is named in
`GP-BASIC.md`, `GPC-BASIC/README.md`, `GP-BASIC.FILES.md` and the generated
help. Fixes made in the master get reflected back into it.

The two files differ only in the `## ** Build:` header comment and in the four
`#INCLUDE` paths. BASLOAD resolves an `#INCLUDE` against the folder the program
runs in, so the library copy uses bare names such as `"GPB.INC.BL"` and the
master carries a `GPC-BASIC/` prefix. Apply that prefix change when syncing and
nothing else needs touching. Both were verified identical line for line on
2026-09-29.

The master folder builds SHARED in place, which is why it picks up a rebuilt
runtime without recompiling.

**Why:** the library sample is documentation and the master is the program.
Editing the library copy first loses the work when the master is next built.

**How to apply:** edit `BMXVIEWER/BMXVIEW.BASL`, then port the same change into
`GPC-BASIC/BMXVIEW.EXP.BL` with the include prefixes adjusted.

Same shape as [[library-working-copy-then-root]] and
[[samples-build-in-place]]. The empty-line bug that sent us here is
[[gpc-input-empty-line]].
