---
name: gpc-shared-pcode-cap-is-rtbase
description: "A SHARED non-GPB program is capped at ~17,920 bytes of p-code by RTBASE, not by $9F00 -- and PROGRAM TOO BIG is raised at END OF PASS 1, which is why it proves the whole source was read."
metadata:
  type: project
---

**The SHARED ceiling is the resident runtime, not the I/O page.** `ObjectPrepareShared`
(`source/application/source/compiler/object.asm:286`) requires

    PCODE_PAGE + pages(p-code) + FrameStackPages  <  sharedCeilPage - MIN_WS_PAGES + 1

with `PCODE_PAGE = $09`, `FrameStackPages = 16`, `MIN_WS_PAGES = 16` and `sharedCeilPage` =
**`RTBASE` $6E00** for a program using no GPB keyword, **`RTGPBASE` $6600** for one that does
(`source/common-source/source/common.inc:113`). That works out at **70 pages, ~17,920 bytes of
p-code** — nothing like the $9F00 `ObjectCeiling`, which bounds the object *buffer*, not the fit.

This is why GPBMODS needs `GP.BANKED`: at ~30 KB of p-code it clears the cap only by moving the
region into a bank. See [[gp-banked-region-relocation]] and [[pcode-runs-from-a-bank-proven]].

## Measured, 2026-09-06

- **~10 bytes of p-code per simple assignment line.** 804 lines of `A=1234567890` tokenise to
  13,625 bytes and compile to an 8,281-byte object; the MAP's line-to-address deltas are all `0A`.
- **Tokenised-to-p-code is about 1.7:1** for dense code. So a SHARED non-GPB program tops out
  around 30,500 tokenised bytes — *below* BASLOAD's 38,655 — and no such program can be both
  oversize and compilable. Empty statements are the exception: 200 colons on a line cost 200
  tokenised bytes and **nothing** in p-code.

## PROGRAM TOO BIG says the source was read in full

`_CAEndPass1` (`compiler/api.asm:51`) jumps to `PrepareObjectCode`, so the message is raised
**after pass 1 has read every line**. A compile that reaches it has parsed the whole source
successfully — useful when the question is whether the reader coped, not whether the object fits.

See [[gpc-blitz-runtime-slack-and-limits]] and [[program-too-big-fires-early]].
