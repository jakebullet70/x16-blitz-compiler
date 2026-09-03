---
name: commit-to-main-directly
description: Commit finished work straight to main here - do not branch first just because main is the default branch
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 0ab8399a-fad5-4910-bb84-5b25da13690f
  modified: 2026-09-03T16:46:02.104Z
---

**Commit to `main` directly.** On 2026-09-03 I put the cruncher on a `feature/basl-cruncher`
branch — following the general "if on the default branch, branch first" rule — and the user's reply
was **"put it on main"**.

**Why:** this is a one-user repo with no review step, so a branch per change is ceremony that buys
nothing and leaves stale branches behind. Feature branches here are for work the user *chooses* to
isolate (`feature/editor-petscii`, `feature/shrink-gp-block`), not a default.

**How to apply:** when asked to commit, commit on whatever branch is checked out. Do not create a
branch unasked, and do not explain why you would have. Still commit only when asked — and
"commit" does not include a push or a build ([[no-ship-language-this-is-dev]]).
