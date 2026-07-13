---
name: memory-is-git-tracked
description: "This project's memory folder is a junction into the repo (docs/memory), so notes are git-tracked"
metadata: 
  node_type: memory
  type: reference
  originSessionId: 481504f0-31d5-4658-a8c1-3b05e8802238
---

The auto-memory folder for this project is a **directory junction**, not a plain folder:

- Link: `C:\Users\Admin\.claude\projects\c--dev-CmdrX16-dos-tools-X16-GPCompiler\memory`
- Target: `C:\dev\CmdrX16\dos_tools\X16-GPCompiler\docs\memory` (inside the git repo)

So every memory note written through the normal `~/.claude` path lands in `docs/memory/`
and is **version-controlled with the project** — no manual resync. Set up 2026-07-09
(verified read + write-through). Mirrors the XFMGR2 convention (that project pioneered it).

**How to apply:** memory changes here are also repo changes. When the user wants them on
GitHub, `git add docs/memory && git commit` (only when they ask). Keep notes
clean/committable. A one-time safety backup of the pre-junction folder sits at
`...\c--dev-CmdrX16-dos-tools-X16-GPCompiler\memory.prejunction.bak` and can be deleted
once the junction is trusted.
