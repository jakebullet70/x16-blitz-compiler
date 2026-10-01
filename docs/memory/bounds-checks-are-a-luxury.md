---
name: bounds-checks-are-a-luxury
description: "Library routines do not range-check their inputs; the caller keeps them in bounds, and the header says so"
metadata:
  node_type: memory
  type: feedback
  originSessionId: 4a512896-8fa6-4490-ab9d-593731b95903
  modified: 2026-10-01T06:25:32.265Z
---

Do not write bounds or range checks into GPC-BASIC routines: off-screen boxes, sizes below a
minimum, counts past an array's DIM. State the limit in the routine's contract and let the caller
keep to it.

**Why:** 2026-10-01, the user: "In 8bit programming, bounds checks are a luxury, not the norm." They
stripped GUI-LITE's 3x3 and off-screen refusals from GL.OPEN by hand.

**How to apply:** a check earns its place only when the failure is silent and costs real time to
find, such as a VRAM allocation that can run out. Everything else is one line in the header's
contract. Fits [[write-readable-code-user-crunches]] and [[comments-light-code-should-flow]].
