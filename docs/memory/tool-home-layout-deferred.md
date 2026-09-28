---
name: tool-home-layout-deferred
description: The /GPC/ tool home plus /BASIC-SRC/<project> layout is next-version work; the rule now is copy the compiler and runtimes into the folder you work in
metadata:
  node_type: memory
  type: project
  originSessionId: a6c8e91e-e94a-4d89-bcb6-b55accf60704
  modified: 2026-09-28T10:37:37.853Z
---

Decided 2026-09-28. The one-root layout (tools in `/GPC/`, programs under `/BASIC-SRC/<project>/`, build from the project folder) is deferred to the next version. The research and the step order are in `docs/blitz/TOOL-HOME-LAYOUT.RESEARCH.md`.

Until then every working folder carries its own copy of the nine tool files: BASLOAD-GPC.PRG/.BIN, GPC.PRG/.BIN, GPB/GPC/GP1.RT.nnn.BIN, GPC/GP1.IMG.nnn.BIN. The sample folders under `GPC-BASIC-TOOLS-SRC/` got theirs from `GPC-BASIC-TOOLS-SRC/GPC/` (the `make install` output) on 2026-09-28.

**Why:** the Build 127 `/GPC/` fallbacks work, but the host scripts, the USER-RUNS bats and release.sh all still mount a single folder as the drive, and the bare `#INCLUDE` misses `/GPC/GPC-BASIC/`. The user chose local copies over finishing that now.
**How to apply:** after a `make install` or a runtime bump, re-copy the nine files into each sample folder, or the objects built there will look for a runtime that is not beside them. Do not start the layout steps without the user asking; step 1 is asm, see [[ask-before-writing-asm]]. Related: [[user-runs-demos-broken-by-build-127]], [[samples-build-in-place]].
