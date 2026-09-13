---
name: never-commit-oasis
description: "Nothing under OASIS/ goes into git -- never stage or commit it, not even in a broad add"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 422a7b37-5897-4def-9e69-98fb13f87ae9
  modified: 2026-09-12T21:53:25.906Z
---

Nothing under `OASIS/` is to be put in git. Stage files by name. Do not run `git add -A`,
`git add .` or `git commit -a` in this repo while OASIS has changes.

**Why:** the user said so on 2026-09-13. The LOAD-chain commit of 2026-09-12 had swept in 42 OASIS
files. They were untracked, `OASIS/` was ignored, and local history was rewritten without them.

**How to apply:** before any commit, run `git diff --cached --name-only` and unstage anything under
`OASIS/`. See [[commit-to-main-directly]], [[user-runs-concurrent-agents-here]].
