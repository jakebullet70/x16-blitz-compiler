---
name: gpc-for-step0-semantics
description: X16 FOR/NEXT ends iff sign(loopvar-limit)==sign(step); STEP 0 loops until EXACT equality. GPC op_fornext/op_ifornext fixed to match.
metadata: 
  node_type: memory
  type: reference
  originSessionId: 574aca0d-1e65-4eab-aab1-acf026f5db05
---

X16/CBM ROM `NEXT` (ref/x16-rom/basic/code8.s ~L88-131) terminates a loop **iff `FCOMP(loopvar_new, limit) == sign(step)`**, where `sign(step)` ∈ {+1($01), 0($00), -1($FF)} is stored by `FOR` via `jsr sign` (code3.s L177). Consequences:
- ascending (step>0): stop when loopvar > limit
- descending (step<0): stop when loopvar < limit
- **STEP 0: sign is 0, so stop ONLY when loopvar EXACTLY equals limit** — otherwise loops forever.

`FOR I=0 TO -1 STEP 0` is therefore a real idiom for "loop until you set I to the limit". e.g. `... : I=(GET$=CHR$(27)) : NEXT` loops forever until ESC makes the boolean -1 (== the limit), which is the exact-equality stop. It works uncompiled precisely because of this.

**Bug found & fixed (2026-07):** GPC's runtime folded STEP 0 into the ascending branch (stop when loopvar>limit), so `FOR I=0 TO -1 STEP 0` died after ONE iteration. This is why demo C256 (a color-cycling char animation) printed a single "A" compiled but animated uncompiled. Fixed in [src/runtime/vm.p8](../../src/runtime/vm.p8): `op_fornext` (float) got a `_fnzero` branch (stop iff FCOMP==0), `op_ifornext` (integer) got `_ifnzero` (stop iff nv==limit via 16-bit compare). Verified: C.C256.PRG now cycles A..Z..A; full suite still green. Related: [[gpc-inc2-design]] (2b int-FOR), [[gpc-x16-basic-coverage]].

**Gotcha after ANY runtime (vm.p8) change:** the on-device bins `demo/gpc.runtime.bin`, `demo/gpc.rt.nosarr.bin`, `demo/gpc.rt.noint.bin` are copies of the built VISUAL runtimes — they do NOT auto-update. If you only fix vm.p8 + recompile one standalone, an on-device recompile via `demo/gpc.prg` re-bundles the STALE runtime and the bug returns ("still fails"). Re-sync those 3 bins from `build/vm_runtime*.prg` (built `visual`), or run `scripts/stage-demo.sh` (note: stage-demo DELETES demo/C.*, incl. hand-placed C.C256.PRG). The compiler `gpc.prg` itself needs no rebuild for a runtime-only fix.

Side note: the fix added ~20 bytes to the runtime; PCODE_BASE margins are now tight (base 34, nosarr 36, noint 49 bytes) — see [[gpc-engine-shrink]] before adding more runtime code. And C256's `SLEEP 15` passes through fine on real HW but HANGS under headless `-testbench` (its `WAI` never wakes — no VERA VSYNC IRQ in that mode); use `-echo` + real video (non-testbench) to observe such programs.
