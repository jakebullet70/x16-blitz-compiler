---
name: turbo-compile-slow-open
description: "FIXED 2026-10-05 -- TURBO's 10-15 min compile was the {VAR} cache overflowing; the cache moved to banks 24-27 (32K), compile now 45 s"
metadata:
  node_type: memory
  type: project
  originSessionId: d662cdc7-bff8-47b0-95f7-b4086f5383d3
  modified: 2026-10-05T04:05:26.218Z
---

On 2026-10-04 a TURBO compile (`TURBO-GPC/build.py`) took 10 to 15 minutes, against about 20 s for GPBMODS. The user calls it unusable for release.

**Cause, found 2026-10-05: the {VAR} symbol cache overflows.** The cache is banks 13-14, 16,384 bytes, and each VARIABLES name costs its length plus 3. TURBO needs 16,423 bytes for 1,076 names, 39 over. The six TURBO.GLYPH.* names tipped it. GPBMODS needs about 13.7 KB. On overflow `symfile.asm` sets SYM_TOO_BIG and `SymFileLookup` reads the 114 KB TURBO.SRC.SYM from disk for each of TURBO's 363 {VAR} references, on both passes. An earlier estimate of 9.9 KB was wrong.

**FIXED 2026-10-05:** SymCacheBank is 24 and SYM_CACHE_BANKS is 4 (32K), listed in x16_storage.inc; banks 13-14 are free. TURBO compiles in 45 s and the PASS 1 BAD VALUE did not recur. build.py warns before compiling if the names outgrow the cache.

A hand compile in the turbo-gpc-demo.bat window runs at normal speed, since that .bat has no `-warp`. build.py's headless run uses `-warp`, so a hand compile is slower whatever the cause.

**State left at the stop:**
- TURBO.BASL has a new routine, TURBO.GLYPHS.SETUP, that copies the ISO glyphs for `\ ^ _ \` { | } ~` into screen codes $F8-$FF and points the XLAT table at them. It has never been built.
- The user was compiling by hand in the emulator.
- `GPC.INPUT` was written by hand into TURBO-GPC.
- TURBO.PRG and TURBO.OVL may be missing. If so, `git checkout` gives back the committed build.
- Nothing from 2026-10-04 is committed: About box, footer, scroll bar, glyphs.

**How to apply:** measure the GP.ASM cost before changing anything ([[measure-before-changing-code]]). A compiler fix is asm, so ask first ([[ask-before-writing-asm]]).

**`PASS 1 .BAD VALUE`, seen 2026-10-04 on the first compile with TURBO.GLYPHS.SETUP.** The six new TURBO.GLYPH.* variables got the crunched names `^0` to `^5`. TURBO is almost out of BASLOAD short names: they run through `[`, `\`, `]` and `^` now, and `_Z` is the end. `^` with a digit had never been used before. The lead is untested. To check it, take the routine out or reuse existing names, then compile again. The compiler raises BAD VALUE in three places: a GP.BANKED bank of 0, a GP.BANKED bank already taken (both in gpbank.asm), and an undefined or forward FN (evaluate/term/functions.asm). TURBO's banks (10, 11, 12, 38, 39, 41) pass both bank checks.
