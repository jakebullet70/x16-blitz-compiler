---
name: tool-home-goes-stale
description: "Sample builds run the compiler in GPC-BASIC-TOOLS-SRC/GPC/, which no commit refreshes; a new compiler must be copied there or the samples silently build with the old one"
metadata:
  node_type: memory
  type: project
  originSessionId: ada7aede-e994-49f6-9d7c-f0cc7eeb6cca
  modified: 2026-10-05T20:03:26.939Z
---

Every sample build (`compile_shared.py --drive <sample>`) runs `GPC-BASIC-TOOLS-SRC/GPC/GPC.BIN`, the tool home. The tool home is gitignored and only `make install` or a hand copy fills it. Refreshing `GPC.BIN` and `GPC.PRG` in source/drive and the sample folders does not touch it.

On 2026-10-05 the tool home still held V1.1.0 after V1.2.0 shipped. TURBO's `#GPC MAP` and `DEADLIST` lines were skipped, no map was written and no dead code was removed, and the build reported success. The first build only looked right because build.py still passed `--strip` and the map on the command line. The V1.2.0 `GPC.BIN` and `GPC.PRG` were copied in at 23:03 that day.

**Why:** a stale tool home fails silently. compile_shared checks for a map only when one is named on its command line.

**How to apply:** after any compiler change, copy `source/application/GPC.BIN` and `source/drive/GPC.PRG` into the tool home. To check which version is there, search the binary for its `V1.x.y` string. Related: [[baseline-compiler-is-the-application-copy]], [[tool-home-layout-deferred]].
