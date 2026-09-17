---
name: gpc-gui-size-not-a-constraint
description: "Do not justify design in the GPC.GUI sample by byte cost; the program is small and has room"
metadata:
  type: feedback
---

**In the GPC.GUI helper sample, stop pricing features in bytes.** Told twice on
2026-09-16: *"do not worry about file cost, this project is pretty small"*, and
again the same turn.

**Why:** the sample is a few kilobytes of p-code with three code banks that are
nowhere near their 8K caps. A size estimate attached to every proposal reads as a
reason not to do the thing, and the reason does not apply here. It is the compiler
and the runtime that live under a real ceiling, not this program.

**How to apply:** propose the feature on its merits and say what it does. Report
sizes after a build, because that is a measurement, not an argument. Keep the byte
budgeting for the runtime, the resident p-code and anything shared by every
program — see [[gpc-blitz-runtime-slack-and-limits]] and
[[blitz-x16-runtime-footprint]].
