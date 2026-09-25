---
name: editor-test-fixture-files
description: GPC-BASIC-TOOLS-SRC/edit/ED-STORE 255.BASL is editor test data, not source - never flag it as dead code
metadata:
  type: project
---

`GPC-BASIC-TOOLS-SRC/edit/ED-STORE 255.BASL` is a **test document loaded in the editor**, not a
source file. No `#INCLUDE` references it and it diffs behind `ED-STORE.BASL` by design
-- it is a stale snapshot kept as sample text. The filename and contents are both the
test: the space exercises loading a name with a space, and the 255 is a line at the
length cap (`DOC.MAX.LINE.LEN 250` in ED-DOC-CONST.BASL).

**Why:** it looks exactly like an unreferenced file swept up by `git add`, and was
flagged as dead weight in a review on 2026-09-24. It is not.

**How to apply:** leave it tracked and unignored. Before calling any file under
`GPC-BASIC-TOOLS-SRC/edit/` dead, ask whether it is something the editor *opens* rather than
something the compiler builds. See [[review-findings-must-be-reachable]] and
[[gpc-editor-branch-and-gui-next]].
