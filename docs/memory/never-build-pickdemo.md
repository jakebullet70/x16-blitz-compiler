---
name: never-build-pickdemo
description: "PICKDEMO is never to be built, tokenised or staged unless the user names it. Standing order, no exceptions for verification."
metadata: 
  node_type: memory
  type: feedback
  originSessionId: f87e5476-6891-4ee2-8570-b0660121dae8
  modified: 2026-09-12T08:11:02.598Z
---

`samples/GPB-MODS-TESTING/PICKDEMO.BASL` is off limits as a build target. Do not build it,
do not tokenise it, do not stage it into `testing/` — not as a verification step, not to prove
a banked library compiles, not as part of a sweep over the samples.

**Why:** a standing order given on 12th September 2026, after I proposed tokenising PICKDEMO
against the root `GPC-BASIC` to prove the promoted banked set resolved. The user gave no reason
and none is needed; the rule holds regardless of how convenient the program looks as a test.

**How to apply:** when you need to prove a banked or multi-region arrangement compiles, ask
which program to use instead of reaching for PICKDEMO. Reading it and citing it in
documentation as a worked example is still fine — GP-BASIC.md §4 points at it for exactly that.
This is the hard case of [[no-ship-language-this-is-dev]]; see also
[[user-runs-concurrent-agents-here]], since builds share `testing/` with other agents.
