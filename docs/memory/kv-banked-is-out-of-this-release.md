---
name: kv-banked-is-out-of-this-release
description: "The KV-BANKED sample was deleted on 2026-10-02: never mention it, report on it or bring it back unasked"
metadata:
  node_type: memory
  type: feedback
  originSessionId: 5991fdbe-eb9a-440f-bf52-e169789d2edb
  modified: 2026-10-02T18:00:00.000Z
---

The KV-BANKED sample is deleted. Do not mention it in a report, a summary, an open-flag list or a
release note, and do not bring it back unasked.

**Why:** the user asked twice on 2026-10-02. First: "stopped talking about KV-BANKED, we are not
using it for this release so if it fails in the build we are not worried." Later the same day, after
a commit report listed its files again: "del KV-BANKED stuff. i do not want to here about it anymore."

**How to apply:** what went is the folder `GPC-BASIC-TOOLS-SRC/KV-BANKED/`,
`USER-RUNS/kvbanked-demo.bat` and the `KV-BANKED` entry in `source/gpc/samplesbuild.py`. The last
commit that holds them is `9e98e96`, if the user ever asks for the sample back.

The `KV` library module is a different thing and stays: `GPC-BASIC/KV.INC.BL`, its `KV.EXP.BL`
example and its help topic. The KV sample for the release is KV-BIN-STORE, see
[[demo-project-options]].
