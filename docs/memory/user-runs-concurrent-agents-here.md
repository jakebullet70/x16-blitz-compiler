---
name: user-runs-concurrent-agents-here
description: The user runs several Claude sessions on this repo at once; default to read-only for research and say so up front
metadata:
  node_type: memory
  type: feedback
  originSessionId: d7531322-9a88-4f9a-8bdd-54f6afe99cb4
---

The user regularly has **more than one agent working this repo simultaneously** and will ask
mid-task whether work can proceed in parallel (asked 2026-08-30, while another session was
researching GP.ASM and writing to this same memory directory).

**Why:** builds write into shared `testing/` and `release/` trees and renumber generated tables, and
two agents editing `GPC-BASIC/*.INC.BL` or `TODO.md` collide. Research questions do not need any of
that.

**How to apply:** for a research-only request, state up front that you will stay read-only — no edits,
no `git` writes, **no builds** — and derive sizes from `code.lbl` / `code.lst` / generated tables
instead of compiling probe programs. Say plainly which measurements that leaves unverified. Before any
write, re-read the target (memory files and `MEMORY.md` included) so a concurrent append is not
clobbered, and tell the user which files you dirtied so they can warn the other agent.
