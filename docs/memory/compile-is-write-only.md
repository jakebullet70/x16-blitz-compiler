---
name: compile-is-write-only
description: "The compiler never reads back the p-code it is emitting -- exactly one instruction touches the object during a compile, and it is a store. This is the fact the two-pass architecture rests on."
metadata: 
  node_type: memory
  type: project
  originSessionId: 75714395-f705-4d27-8da6-af4a832a1e0b
  modified: 2026-09-06T03:08:29.571Z
---

**Established by complete static enumeration on 2026-09-06**, not by sampling. Between
`StartCompiler` and the end of the main loop, the object buffer is touched by **one instruction**:

    api.asm:108        sta (objPtr)          <- the only write path, via WriteCodeByte

`objPtr` is the sole handle on the buffer and it lives in zero page, so enumerating every
`(objPtr)` dereference in the tree is exhaustive. Every other one is in `FixBranches`,
`GPBankRelocate`, `ScanGPUsage` or the object writer -- all of which run inside
`SaveCodeAndExit`, **after** the compile proper. `AsmPoolPoke` looks like a counter-example and
is not: it writes `AsmPool` in bank 3 through `.asm_access`, never the object.

`fixbranches.asm` states the same thing from the other direction, in its own words: *"this
compiler has no back-patching machinery at all (IF sidesteps the problem entirely by branching
to 'current line + 1' and letting STRFindLine resolve it)."*

**Why it matters.** A write-only forward stream can be sent straight to a file, which is what
removes the compile-side program-size wall for good -- see [[two-pass-compiler]]. Anything that
adds a read-back of emitted p-code during a compile breaks that premise, so it is worth
re-checking this enumeration before accepting one.

Related: [[compiler-must-not-cap-program-size]], [[program-too-big-fires-early]],
[[gp-banked-region-relocation]].
