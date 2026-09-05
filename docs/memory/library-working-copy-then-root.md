---
name: library-working-copy-then-root
description: Edit GPC-BASIC modules in samples/GPB-MODS-TESTING/GPC-BASIC/ and copy to root only when they pass — never edit the root copy directly
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 75714395-f705-4d27-8da6-af4a832a1e0b
  modified: 2026-09-05T17:29:43.127Z
---

**A `GPC-BASIC` module is edited in `samples/GPB-MODS-TESTING/GPC-BASIC/`, proved there, and copied
whole to root `GPC-BASIC/` only when it passes.** Never edit the root copy directly, and never merge
by hand — copy the whole file.

**Why:** root `GPC-BASIC/` is the release copy that `samples/GPC-HELP` and `samples/editor` build
against. Drift between copies is already real and unmarked (`samples/editor/GPC-BASIC/GUI.INC.BL` is
23,339 bytes against the root's 25,663), which is the reason the direction is written down at all —
`samples/GPB-MODS-TESTING/PLAN.md` §1.

**How to apply:** when a fix touches a shipped module, make it in the GPB-MODS-TESTING copy and test
it there. Do NOT ask whether to put it in the root instead, and do not take "recompiling is not an
issue" as permission to skip the working copy — that answers a different question, about whether
breaking dependent samples matters (it does not: sole user, see
[[no-backward-compatibility-needed]]), not about where the edit happens.

Related: [[compile-shared-not-embedded]], [[measure-pcode-per-module]].
