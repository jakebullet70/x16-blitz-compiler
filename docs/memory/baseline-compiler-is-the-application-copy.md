---
name: baseline-compiler-is-the-application-copy
description: "For an A/B comparison against an old commit, take source/application/GPC.BIN, never testing/GPC.BIN -- the testing copy can be committed stale and will invent regressions that are not there."
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 75714395-f705-4d27-8da6-af4a832a1e0b
  modified: 2026-09-06T03:49:48.447Z
---

`make libs` writes `source/application/GPC.BIN` and copies it to `testing/GPC.BIN`, but the two
are committed independently, so **the testing copy can lag by a build**. At `3335ab5` it did:

    3335ab5:source/application/GPC.BIN   18,889 bytes   the real compiler
    3335ab5:testing/GPC.BIN              17,949 bytes   940 bytes stale

**Why:** on 2026-09-06 a two-pass change was A/B'd against `git show 3335ab5:testing/GPC.BIN`
and three programs came out with different objects. The diff said the differences were all in
the bootstrap and all a constant -33 displacement, which is a *layout* shift, not a behaviour
change -- the tell that the baseline binary, not the change, was wrong. Against
`source/application/GPC.BIN` the same three programs were byte-identical, 0 differing bytes.

**How to apply:** when diffing a compiler change against an older commit, pull the baseline from
`source/application/GPC.BIN`. And when a diff looks like a regression, look at *where* the bytes
differ before believing it -- a constant displacement in one region means something moved, and
things move when the binary is not the one you meant. See [[measure-before-changing-code]].

Worth committing `testing/GPC.BIN` alongside `source/application/GPC.BIN` so a fresh clone tests
with the compiler its own sources describe.

Related: [[headless-basl-build-recipe]], [[two-pass-compiler]].
