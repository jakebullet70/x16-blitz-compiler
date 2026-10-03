---
name: guard-sweep-owed
description: "Owed task: sweep the GPC-BASIC library and the samples for input guards and range checks and take them out; MEM.INC.BL was the first, done 2026-10-02"
metadata:
  node_type: memory
  type: project
  originSessionId: f2ef33fe-6565-4754-b1b1-05111d41cf23
  modified: 2026-10-02T19:04:06.414Z
---

**A sweep for guards is owed.** The user asked on 2026-10-02 to go back and check the other code
for guards, after having the two `MEM.COUNT` checks taken out of each of `MEM.COPY` and
`MEM.FILL`: "waste of bytes", "its an 8bit compiler". The sweep is not started.

**Why:** a guard is p-code bytes and cycles on every call, and the caller already keeps its inputs
in range. The rule is [[bounds-checks-are-a-luxury]]. The sweep applies it to code written before
the rule.

**How to apply:**

- Scope is the `GPC-BASIC` modules first, then the samples under `GPC-BASIC-TOOLS-SRC`. Look for an
  `IF <input> < low THEN RETURN` or `> high` at the top of a routine, and for a status variable
  that only reports such a refusal.
- A guard goes together with its status variable, the manual's sentence about the refusal, and the
  caller's test of it. `MEM.OK` went with the `MEM` guards. `GPC-BASIC/GP-BASIC.md` section 4.23
  and `GP-BASIC.GLOBALS.md` are corrected. The `GPC-HELP` help files still say `MEM.OK`. The
  installed copies under `GPC-BASIC-TOOLS-SRC/GPC/` and `release/TMP/` still hold the old
  `MEM.INC.BL`, the old manual and the old help files.
- A check stays when the failure is silent and costs real time to find. Report those and let the
  user decide.
- List the guards found and their byte cost before taking any out. Edit in the working copy, then
  the root: [[library-working-copy-then-root]].
