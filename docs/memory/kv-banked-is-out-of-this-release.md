---
name: kv-banked-is-out-of-this-release
description: "KV-BANKED is not in this release: do not report on it, and a failed KV-BANKED build is not a concern"
metadata:
  node_type: memory
  type: feedback
  originSessionId: 5991fdbe-eb9a-440f-bf52-e169789d2edb
  modified: 2026-10-02T09:09:09.209Z
---

Do not report on KV-BANKED. It is not in this release, so its build result, size and state stay
out of every summary. A KV-BANKED build that fails is not a problem to raise or to fix.

**Why:** the user said so on 2026-10-02, after two reports in a row carried KV-BANKED sizes and
"built clean" lines: "stopped talking about KV-BANKED, we are not using it for this release so if
it fails in the build we are not worried."

**How to apply:** leave KV-BANKED out of build reports, open-flag lists and release notes. Leave
its folder and its `samplesbuild.py` entry alone. Do not spend a build cycle or a repair on it
unless the user brings it back. The KV sample for the release is KV-BIN-STORE, see
[[demo-project-options]].
