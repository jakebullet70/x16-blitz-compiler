---
name: gpc-core-page-cushion-below-gpbase
description: Only ~40 bytes of page padding sit between the runtime core's last byte and GPBase; crossing it costs every compiled program 256 bytes
metadata:
  node_type: memory
  type: project
  originSessionId: d7531322-9a88-4f9a-8bdd-54f6afe99cb4
---

**Measured 2026-08-30 from `source/application/build/code.lst`.** The runtime core ends at `$36d7`
(an `rts`), and `GPBase` is `$3700` — so there are **40 bytes** of `.align 256` padding between them,
and that is the real budget for anything added to the **core** (`VectorTable`, `$20d7`, is core; so is
any shared handler).

**Why it matters more than the 590 B "headroom" figure.** Small additions to the core are absorbed by
this padding and cost a compiled program *literally nothing* — `GPBase`/`ObjectBase` don't move, so a
non-GP program stays 12,031 B and a GP program stays 14,079 B. But the moment the core crosses `$3700`
the align pushes `GPBase` a whole page, and **every compiled program grows 256 bytes**. A 12-byte
feature and a 41-byte feature differ by 21x in delivered cost, with no warning and no error.

**So: re-measure `$36d7` against `$3700` before costing anything that touches the core**, and land
core-touching features before, not after, unrelated core growth.

The mirror-image fact for the GP block: it ends at `$3eb1`, giving **78 bytes** free below
`ObjectBase $3f00` (the sibling note says 80; 78 is what `code.lst` shows). Inside the GP block bytes
are *headroom only* until they cross a page — GPB is 1,970 used of 2,048, so ~178 B would have to come
out before a page is actually returned.

Related: [[gpc-blitz-runtime-slack-and-limits]] (the layout numbers above `GPBase`),
[[gpb-block-if-design]].
