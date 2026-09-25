---
name: keep-claude-files-off-the-root
description: "Claude's working folders (drive, scratch test drives) live under source/, never at the repo root or inside the user's folders"
metadata:
  node_type: memory
  type: feedback
  originSessionId: a0618060-52ae-4ba6-9834-adc5515db93b
  modified: 2026-09-25T13:45:13.156Z
---

Claude's working files go under `source/drive/` and `source/scratch/`. The repo root is kept for the
user's own folders: `GPC-BASIC-TOOLS-SRC/` (the programs), `GPC-BASIC/`, `release/` (with
`release/TMP/`), `USER-RUNS/`.

**Why:** the user stopped using a shared working folder once Claude filled it with hundreds of
probe files. Mixing Claude's files into a folder the user browses means the user cannot find their
own. Asked 2026-09-25.

**How to apply:** a new test drive, probe or harness goes in `source/scratch/<name>/`. Never create a
new top-level folder, and never drop probe files into `GPC-BASIC-TOOLS-SRC/` or `release/`. See
[[commit-to-main-directly]].
