---
name: basload-basic-ram-is-the-tokenise-ceiling
description: "The 38,655-byte tokenise ceiling is REMOVED for anything build_basl.py drives, but still binds the ROM BASLOAD -- the BASIC prompt and every other emulator harness in the tree."
metadata:
  node_type: memory
  type: project
  originSessionId: bd07b4f1-99e6-4093-b015-3bc230589125
  modified: 2026-09-06T15:37:57.588Z
---

**Fixed 2026-09-06, commits `c0b978f` and `08443c1`.** The ROM BASLOAD builds the tokenised program
in BASIC RAM, so 38,655 bytes was the ceiling on `.BASL` + every `#INCLUDE` combined, and it
truncated **silently-ish**: it printed `SAVING` and wrote a short PRG *before* reporting
`ERROR: BASIC RAM FULL`, so the file existed, was non-empty and loaded at $0801. GPC then died a
stage later on a label whose line was never written -- `UNKNOWN LINE NUMBER @ nnnn` -- naming
neither the file nor the cause.

**`build_basl.py` no longer uses the ROM BASLOAD.** It drives the streaming fork, so the ceiling is
the disk. See [[basload-streams-to-a-file]].

## Where the old ceiling still binds

Anything that types `BASLOAD "X"` at the BASIC prompt, which is **the interactive path and every
other emulator harness in this tree**: `work/help/build.py`, `work/lineinput/build.py`,
`work/rename/build.py`, `source/unit-tests/devprobe.py`. They are dev scratch and were left alone.
If one of them ever hits the wall, point it at `testing/BASLOAD.PRG` and copy the driver out of
`source/gpc/build_basl.py`.

## Sizes worth keeping

`GPBMODS.BASL` tokenised to **37,872 bytes -- 783 bytes under the old ceiling** with twelve modules
in, which is why `FILEIO` + `FILEDIR` (~7,200) and a FILES panel (~8,000) could not go in.

**GPBMODS CROSSED IT on 2026-09-07** and came back under, which is the useful part. Moving the
three trims into `STRINGS.INC.BL` **with an assembly `STR.SPLICE` beside them** took it to 39,794
and `work/rename/build.py` died on `ERROR: BASIC RAM FULL`; rewriting `STR.SPLICE` in BASIC brought
it to 38,226, and trimming the prose of `STRINGS` and `STRCASE` to **37,197 -- 1,458 bytes under,
and 675 below where GPBMODS started**. Comment lines are worth as much here as code: `##` prose
does not survive tokenising, but the `REM`-carried assembly and the sheer line count do. The mechanism to remember: **`GP.ASM` rides in `REM` statements,
so a blob costs tokenised bytes even though `##` prose costs none** -- trimming comments to make
room does nothing, and adding a blob to a widely-included module is what moves this number.

`work/rename/build2.py` is `build.py` with the streaming driver lifted out of
`source/gpc/build_basl.py`. **Copy `build2.py`, not `build.py`, into any new work dir that compiles
GPBMODS or anything its size** -- the margin is 1,458 bytes. Rule of
thumb from two real builds: **~17.5 tokenised bytes per non-comment source line** (GPBMODS 16.9,
FILEDIRT 18.2).

**The next wall is not BASLOAD's.** For a SHARED program it is the p-code cap -- see
[[gpc-shared-pcode-cap-is-rtbase]], ~17,920 bytes, which at ~1.7:1 tops out near 30,500 tokenised
bytes. That is *below* the old BASLOAD ceiling, so removing this one does not by itself make an
oversize SHARED program compilable. `GP.BANKED` is what clears it.

See [[basload-runs-from-ram-unmodified]] -- that finding is what made this cheap.
