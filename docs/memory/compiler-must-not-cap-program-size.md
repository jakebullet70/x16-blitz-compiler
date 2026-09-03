---
name: compiler-must-not-cap-program-size
description: "Standing instruction - if the compiler's own footprint is what limits how big a program can be built, that is a bug to fix, not a constraint to work around."
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 4b8bda58-db0d-4799-90e8-505eac54670b
  modified: 2026-08-30T13:33:00.988Z
---

If the compiler is limiting the build output, fix the compiler. Stated 2026-08-30, as a
standing rule for future work, not just for the case that prompted it.

**Why:** the object buffer is `FreeMemory..ObjectCeiling` and `FreeMemory` is `.align 256`
after the compiler's last byte, so compiler growth eats max program size one page at a time.
It had drifted to the point where the compiler refused programs the runtime would happily
run (12,800 buildable vs 18,432 runnable). The user's position: *"if I cannot build it then
really, it is dead now"* — a program you cannot compile is worth nothing, so a run-side
headroom figure is not an answer to a build-side wall.

**How to apply:** when weighing a compiler change, report its cost in *max program size*, not
in "compile-time memory" — the project rule "we only care about runtime memory" means bytes
in the compiled program, and does NOT make compiler bytes free. If a feature would push
`FreeMemory` up a page, say so up front and pair it with where the page comes back from.
See [[gpc-blitz-runtime-slack-and-limits]] and [[gpasm-implementation-status]].

**Sharpened 2026-08-30: "compile cost is not an issue. Only runtime cost."** Max program size
is the ONLY channel through which compiler size matters. Compile time, compile-time memory,
how much work the generator or `FixBranches` has to do — none of it belongs in a costing
answer, and quoting it reads as dodging the question. See [[answer-the-question-asked]].
