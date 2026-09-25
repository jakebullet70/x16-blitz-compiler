---
name: gpc-core-page-cushion-below-gpbase
description: In the EMBEDDED image 52 bytes sit between the core's last byte and GPBase $2F00 since build 123 moved handlers to bank 1; crossing costs every embedded program 256 B. SHARED has 379 B core and 633 B GP block free. Measure from rtimage.lbl, not a listing.
metadata:
  node_type: memory
  type: project
  originSessionId: d7531322-9a88-4f9a-8bdd-54f6afe99cb4
---

**Re-measured 2026-09-15, build 123: 52 bytes left in the embedded image.** Build 123 moved the
rarely used handlers, `FloatTangent` among them, to bank 1. The last core routine is now
`FloatIsZero`, 9 B at `$2ec3`, so the core ends at `$2ecc` and `GPBase` is `$2f00`. The 45 B that
copy the bank code to bank 1 at start are inside that figure. Before build 123 the cushion was 4 B
below `$3700`. See `docs/blitz/HANDLER-BANK.PLAN.md` and [[compiler-emitted-bank-switch]].

**Measure it from `source/application/build/rtimage.lbl`**, the labels of link one, which is the
embedded image. Take the highest label below `GPBase` and add its length; a label at `$A000` or
above is bank 1 code, not core. The genrtimage line in the build log (`GPBase $2f00, ObjectBase
$3500` for build 123) says at once whether the page moved. Two sources gave wrong answers:

- `source/application/build/code.lst` is link two, the compiler, and no longer holds the runtime.
- `source/runtime/build/code.lst` is whichever runtime link ran last, the test build or `gpc-rt`.
  On 2026-09-13 it showed 34 B, and a 17 B change crossed the page.

**Why it matters.** Core bytes inside the padding cost a compiled program nothing, because
`GPBase` and `ObjectBase` do not move. Once the core crosses `$2F00` the align pushes `GPBase` a
whole page, and **every embedded program grows 256 bytes**, with no warning and no error. The
`VectorTable` is core, so every new opcode costs 2 B here even when its handler is in the GP block.

**SHARED is a different layout** (`make -C source/runtime gpc-rt`). The GP block runs from
`$6F00` to `$7700`, and the core from `$7700` up to the `$9F00` guard. On 2026-09-15 the core had
**379 B** free (`source/drive/GPB.RT.123.BIN` ends at `$9D85`) and the GP block **633 B** (the zero run
before the `GB24` magic at `$76FC`). Build 122 had 542 B and 633 B. The tests compile SHARED only,
so no test notices an embedded page move.

**Embedded GP block:** `ObjectBase` is `$3500`, and its last handler, `CommandXUnwind`, starts at
`$345D`.

Related: [[gpc-blitz-runtime-slack-and-limits]] (the layout numbers above `GPBase`),
[[gpb-block-if-design]].
