---
name: gpc-gating-requirement
description: The GPC go/no-go gate (ROM GARBAG + command pass-through) and its proven result on R49
metadata: 
  node_type: memory
  type: project
  originSessionId: 481504f0-31d5-4658-a8c1-3b05e8802238
---

The user set a hard STOP gate for GPC (see [[gpc-project]]): **without both (a) calling the X16 ROM string garbage collector and (b) mid-program command pass-through to ROM BASIC working, the project is a no-go.** Home-grown GC / per-statement keyword reimplementation are NOT acceptable substitutes. The prior attempt `../BLITZ-COMPILER` had given up on both as "infeasible/undocumented."

**Verified 2026-07-07 on R49: BOTH GATES PASS** (proofs in `X16-GPCompiler/spikes/`, run headless via x16emu -testbench):
- Pass-through: a compiled program sets TXTPTR at an embedded tokenized statement, `jsr chrget` then `jsr gone3`, the ROM handler executes and RTSes back. Proven for a core token (POKE) and an X16-only escape token (VPOKE = `$CE $84`). See [[x16-rom-internal-calls]].
- GARBAG: `garba2` compacts a BASIC-format string heap, reclaims orphaned space (reclaimed exactly 45 bytes of garbage), preserves live strings, returns cleanly.

The prior "infeasible" verdict was wrong for R49 — X16 BASIC keeps the classic-CBM zero-page + a vectored dispatcher, so both work. **Why:** clears the gate → GPC is a GO. **How to apply:** proceed to the port/build; GPC strings must use BASIC's string-storage format to reuse the ROM GC.

**Update — GARBAG gate now satisfied in the REAL VM (Phase 2 DONE, 2026-07-07).** Not just a spike: the VM's private heap + custom mark-compact collector were deleted and replaced with BASIC-format string storage collected solely by ROM `garba2`. New engine `src/runtime/bstr.p8` (var table + 3-slot temp stack + real BASIC string arrays + banked getspa wrapper); `vm.sstack` holds descriptor addresses; memory map placed at `image_top = max(sys.progend(), datatop)`. Full corpus **196/196 PASS**, including standalone GC-stress (200-char accumulation + byte-exact MID$ after 150 collections, no compiler present). See [[gpc-project]].

**Update — command pass-through gate (b) now REAL too (Phase 3 DONE, 2026-07-07).** Not a spike: `OP_PASSTHRU`=64 carries a tokenized statement; the runtime copies it to low-RAM `passbuf` `[':'][tokens][$00]`, sets TXTPTR/curlin, pages in BASIC ROM (`$01=4`), `jsr $00E7`+`jsr $CC63` (gone3), restores banks. The compiler routes any statement whose first byte is a keyword GPC doesn't compile (`>= $80`, the `$CE` X16 escapes) to it; `tokenize.py` carries the full R49 escape-statement table. Verified `VPOKE 0,4660,66` → VRAM (read back = 66) in-process, standalone, and mid-line. **Both gate capabilities are now real in the actual GPC compiler.** Corpus **199/199**.
