---
name: gpc-core-page-cushion-below-gpbase
description: In the EMBEDDED image only 4 bytes now sit between the core's last byte and GPBase $3700 (was 16 before .bgosub); crossing costs every embedded program 256 B. SHARED has 542 B core and 633 B GP block free. Measure from rtimage.lbl, not a listing.
metadata:
  node_type: memory
  type: project
  originSessionId: d7531322-9a88-4f9a-8bdd-54f6afe99cb4
---

**Re-measured 2026-09-13: 4 bytes left in the embedded image.** The last core routine is
`FloatTangent`, 38 B, and it now starts at `$36d6`, so the core ends at `$36fc` and `GPBase` is
`$3700`. It was 16 B before `.bgosub` added 12 to the core. See [[compiler-emitted-bank-switch]].

**Measure it from `source/application/build/rtimage.lbl`**, the labels of link one, which is the
embedded image. Take the start of `FloatTangent` and add 38. The genrtimage line in the build log
(`GPBase $3700, ObjectBase $3d00`) says at once whether the page moved. Two sources gave wrong
answers:

- `source/application/build/code.lst` is link two, the compiler, and no longer holds the runtime.
- `source/runtime/build/code.lst` is whichever runtime link ran last, the test build or `gpc-rt`.
  On 2026-09-13 it showed 34 B, and a 17 B change crossed the page.

**Why it matters.** Core bytes inside the padding cost a compiled program nothing, because
`GPBase` and `ObjectBase` do not move. Once the core crosses `$3700` the align pushes `GPBase` a
whole page, and **every embedded program grows 256 bytes**, with no warning and no error. The
`VectorTable` is core, so every new opcode costs 2 B here even when its handler is in the GP block.

**SHARED is a different layout** (`make -C source/runtime gpc-rt`). The GP block runs from
`$6600` to `$6E00`, and the core from `$6E00` up to the `$9F00` guard. On 2026-09-13 the core had
**542 B** free and the GP block **633 B** (the zero run before the `GB` magic in
`testing/GPB.RT.122.BIN`). The tests compile SHARED only, so no test notices an embedded page move.

**Embedded GP block:** `ObjectBase` is `$3d00`. The old figure of 78 B below `$3f00` is stale.

Related: [[gpc-blitz-runtime-slack-and-limits]] (the layout numbers above `GPBase`),
[[gpb-block-if-design]].
