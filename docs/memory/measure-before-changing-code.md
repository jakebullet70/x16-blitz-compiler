---
name: measure-before-changing-code
description: "User feedback 2026-09-02: probe first, change second -- speculative fixes to a memory problem cost most of a day"
metadata:
  type: feedback
---

**Guidance, after an OUT OF MEMORY chase ran 08:21 to 12:47 and then resurfaced the same
afternoon:** when the symptom is a resource running out, measure where it goes BEFORE editing code.

**Why:** two rounds of entirely reasonable changes -- a faster loader, then a `GP.ASM` pass over the
store -- moved the ceiling by 18 bytes and one of them made the failure fire *earlier*. A single run
with `FRE(0)` printed at eight points found the real 579-byte consumer in about two minutes. The
user asked, fairly, how many hours had gone to it.

**How to apply:** for memory, `PRINT FRE(0)` at bisecting points and read the descent (it is a
high-water ceiling, so it only falls). For speed, put the old and new code in ONE program on ONE
fixture and time both -- `samples/editor/LOADBEN.BASL` and `SLOTBEN.BASL` are the pattern. Then
bisect a behaviour change by BUILDING the halves (old file + new file, and the reverse), rather than
reasoning about which half did it.

Two related habits the same day: do not assert an attribution before the run that proves it has
finished, and when a build artifact differs from a stale log, reproduce the baseline rather than
treating the old log as ground truth. See [[answer-the-question-asked]].
