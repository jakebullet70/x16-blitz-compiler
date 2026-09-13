---
name: gpasm-var-lookup-rescans-symfile
description: "FIXED 13 Sep 2026: GP.ASM {VAR} re-read the #SYMFILE per lookup (95% of GPBMODS compile); now read once into banks 13-14, GPBMODS 317 s -> 20 s"
metadata: 
  node_type: memory
  type: project
  originSessionId: 148b528a-0772-4f0b-9030-22a687f7a603
  modified: 2026-09-13T15:08:08.722Z
---

Measured 13 September 2026, GPBMODS option off, one emulator alone: 317 s, of which 301 s was the
111 `{VAR}` references in its 13 GP.ASM blocks. Each one opened the symbol file and read it line by
line to the name, in every pass, at about 0.28 s wall per 10 KB of file ahead of the name.
Statements, labels, GP.BANKEDSTR groups and $CE tokens cost nothing measurable.

**Fixed the same day** in `source/application/source/compiler/symfile.asm`: the first `{VAR}` of a
compile copies every VARIABLES entry into RAM banks 13 and 14 (name, zero, two crunched bytes; a
zero ends a bank) and later lookups search the banks. `CompileCode` resets `symCacheState`. Names
that outgrow both banks (about 1,300 at GPBMODS's lengths; GPBMODS uses 8,656 bytes) fall back to
the old per-lookup file read, so there is no new limit. GPC.BIN grew 348 bytes, to 28,911.

After: GPBMODS alone 19.8 s (pass 1 5.0 s, pass 2 14.0 s), object identical. Quick tier 562 s ->
115 s, full tier 1,040 s -> 170 s, every check passes. The fallback, forced with a symbol file padded
to 87 KB, takes 336 s and its output is identical.

Full table and method: `docs/blitz/COMPILER-TESTS.PLAN.md` section 5.

**Why:** the lookup was the whole of the slow compile that set every test tier's wall time.

**How to apply:** a GPBMODS or RGM compile that is slow again is a new cause; do not re-profile the
symbol lookup first. Banks 13 and 14 are taken at compile time (listed in x16_storage.inc). A
progress dot counts main-loop lines only; GP.ASM and GP.BANKEDSTR bodies print none
([[gpasm-implementation-status]]). The fix was asm, agreed first ([[ask-before-writing-asm]]).
