---
name: hostfs-is-not-the-dir-slowness
description: "XFMGR reads files MUCH faster on the same HOSTFS, so the ~2 s FILEDIR pause is our read loop, not the host filesystem. Queued for investigation after the LISTS/DIR work"
metadata: 
  node_type: memory
  type: project
  originSessionId: b52e8c4f-ffdf-4b2a-89c7-8a57e0a20a41
  modified: 2026-09-20T15:45:40.807Z
---

The ~2 s pause before a FILEPICK box appears was put down to HOSTFS being slow.
**That is wrong.** The user checked XFMGR on the same machine and the same HOSTFS:
it reads files MUCH faster. The host filesystem is not the bottleneck, so the cost
is in how FILEDIR pulls the listing in.

**Queued, not started.** The user asked to dig into speeding it up *after* the
LISTS and DIR work is finished. Do not start it mid-task.

Where to start when it is time:
- `GPC-BASIC-TOOLS-SRC/GPB-MODS-TESTING/GPC-BASIC/FILEDIR.INC.BL` -- the read loop behind
  `FILE.DIR.OPEN` / `FILE.DIR.NEXT`, which `FILEPICK.SCAN` drives once a file.
- The precedent is already measured: [[gpc-editor-loader-linput-and-blob]] found
  LINPUT# **10.5x** over a GET# byte loop, and [[binput-caps-at-255-bytes]] notes
  BINPUT# is itself a CHRIN loop. A per-byte read is the first suspect.
- [[macptr-wraps-banks-itself]] says MACPTR's caller is STASH, not FILEDIR -- worth
  re-testing that conclusion against a measured number rather than assuming it.
- [[measure-before-changing-code]]: time it before touching it.

Supersedes the "about 2 s of that is FILEDIR pulling the listing in" line in
[[lists-and-dir-plan]], which said where the time went but wrongly blamed the host.
