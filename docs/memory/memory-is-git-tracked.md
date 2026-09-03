---
name: memory-is-git-tracked
description: "This project's memory folder is a junction into the repo (docs/memory), so notes are git-tracked -- and A PROJECT RENAME SILENTLY BREAKS IT"
metadata:
  node_type: memory
  type: reference
  originSessionId: 481504f0-31d5-4658-a8c1-3b05e8802238
---

The auto-memory folder for this project is a **directory junction**, not a plain folder:

- Link: `C:\Users\Admin\.claude\projects\c--dev-CmdrX16-dos-tools-x16-blitz-compiler\memory`
- Target: `C:\dev\CmdrX16\dos_tools\x16-blitz-compiler\docs\memory` (inside the git repo)

So every memory note written through the normal `~/.claude` path lands in `docs/memory/` and is
**version-controlled with the project** — no manual resync. Mirrors the XFMGR2 convention (that
project pioneered it).

## A RENAME BREAKS IT, SILENTLY, AND NOTHING WARNS YOU

**This has already happened once.** The junction was first made on 2026-07-09 for the old path
`X16-GPCompiler`. When the project was renamed to `x16-blitz-compiler`, Claude Code derived a NEW
slug from the new path, found no folder, and **created a plain one** — so memory kept working
perfectly while quietly writing outside the repo. `docs/memory` froze at 16 notes on 2026-08-30
and **44 more accumulated untracked** until 2026-09-04, when they were merged back and the
junction re-made.

Nothing about the failure is visible from inside a session: notes save, recall works, the index
looks right. The only tell is that `git status` never mentions memory changes.

**So: if the project directory is ever renamed or moved, re-make the junction FIRST.**

## How to check, and how to re-make it

Check (PowerShell) — `junction=False` means it is broken:

```powershell
$i = Get-Item 'C:\Users\Admin\.claude\projects\c--dev-CmdrX16-dos-tools-x16-blitz-compiler\memory' -Force
($i.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0
```

Or from bash, in that folder: `git rev-parse --show-toplevel` should name the repo, not fail.

Re-make it — **back up and merge first, or you throw away every note written while it was broken**:

```powershell
# 1. back up, 2. copy any notes not already in docs/memory, 3. reconcile the two MEMORY.md indexes,
# 4. only then:
Remove-Item -Recurse -Force $link -Confirm:$false
New-Item -ItemType Junction -Path $link -Target 'C:\dev\CmdrX16\dos_tools\x16-blitz-compiler\docs\memory'
```

Verify by writing a file through the `~/.claude` path and seeing it appear under `docs/memory`.

**How to apply:** memory changes here are also repo changes. When the user wants them on GitHub,
`git add docs/memory && git commit` — only when they ask ([[no-ship-language-this-is-dev]]). Keep
notes clean and committable. A safety copy of the pre-junction folder sits at
`...\c--dev-CmdrX16-dos-tools-x16-blitz-compiler\memory.prejunction.bak` and can be deleted once
the junction is trusted.
