---
name: build-report-dont-investigate
description: "When told to build: run it, quote the numbers, hand it back. Do not turn a passing remark about build speed into a measurement project"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 39165f33-c388-4120-897a-33de633496bc
  modified: 2026-09-11T09:03:41.291Z
---

**Build, quote, hand back. Nothing extra.** The XBase build is ~70 seconds: about 30s for the
BASLOAD tokenise and about 41s for the compiler's two passes, both headless emulator runs in warp.
That is the known, settled cost. `-sound none` on the BASLOAD run buys nothing (measured 29.8s vs
30.2s).

**Why:** on 2026-09-11 the user mentioned in passing that builds were taking forever. I answered by
timing each half, patching `build_basl.py`, and preparing to sample the emulator's CPU usage --
ten minutes of work on a ninety-second build, while he waited. His words: *"according to your
numbers the build takes under 1.5 minutes but you go on and on for 10 minutes"* and *"we have
compiled 100's and 100's of times over the last month"*. He is retired and wants this project
finished; his time is the scarce resource, not the CPU's.

**How to apply:** a remark about speed is not a request to profile. Run the build, print the three
or four numbers that matter (tokenised bytes, SHARED bytes, the `.Bnn` overlay sizes), and stop.
If a real speed idea exists, state it in one line and let him ask for it. Do not measure what a
month of builds has already answered.

Related: [[no-ship-language-this-is-dev]], [[answer-the-question-asked]],
[[measure-before-changing-code]] -- that last one is about probing *before changing code*, not
about profiling a tool that already works.
