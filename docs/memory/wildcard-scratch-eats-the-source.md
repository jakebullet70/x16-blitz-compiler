---
name: wildcard-scratch-eats-the-source
description: "A DOS scratch of <name>.B* matches <name>.BASL as squarely as <name>.B05 -- it deleted 17 test sources. Never send a wildcard through IOScratchFile."
metadata:
  type: project
---

**`S0:<name>.B*` deletes `<name>.BASL`.** CBM pattern matching is a literal prefix followed by
`*` matching anything, so `BANKA.B*` matches `BANKA.BASL` exactly as well as it matches the
`BANKA.B05` it was aimed at. Seventeen tracked test sources went on 2026-09-08, in the compile that
was supposed to be tidying up after itself.

They came back with `git restore testing/` — but only because they were tracked. An untracked
`.BASL` would simply have been gone.

**There is no safer spelling here.** Every extension this project uses starts with B: `.BASL`,
`.BAS`, `.BIN`, and the `.Bnn` overlays themselves. A wildcard cannot separate them.

**So the compiler sends no wildcard through `IOScratchFile`, ever.** What the sweep was for is done
by exact names instead: `ObjEmitOverlay` scratches each overlay by its full name immediately before
writing it (which `"name,S,W"` needs anyway — it refuses to open over a file that exists), and
`ObjStreamAbort` removes the one that was in flight if the compile stopped. What is left unswept is
an orphan `.Bnn` from an earlier run whose `GP.BANKED` has since changed bank or gone; nothing loads
it, and [[region-overlay-ovl-file]] records that the programmer owns stale overlays by decision.

**The general rule: `IOScratchFile` has no undo and reads no status.** It refuses only one name —
`SourceFile` — and that guard exists because someone already aimed it at the source once. Anything
that is not a name the compiler is about to write itself does not belong in it.

Related: [[region-overlay-ovl-file]], [[object-file-must-fit-under-the-runtime]].
