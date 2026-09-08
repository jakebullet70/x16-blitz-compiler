---
name: compile-shared-timeout-fakes-success
description: "compile_shared.py reported a 180s timeout as a successful compile, because the success test was only that the object file exists -- and pass two writes the object as it goes, so a killed run leaves a short one. Fixed: 420s, and the banner and the map are the test"
metadata:
  node_type: memory
  type: project
---

**Cost three build cycles on 2026-09-08 before it was spotted.** `source/gpc/compile_shared.py`
printed

    compiled GPBMODS.SRC.PRG -> GPBMODS.PRG (513 bytes, SHARED)

and exited 0. 513 bytes is the bootstrap and nothing else; there was no `.MAP` at all. **The
compile had simply run out of TIMEOUT and been killed**, and the success test was
`os.path.exists(objpath)` -- which a half-written object passes.

**Two-pass is what made "the object exists" meaningless.** Pass two writes the object AS it
compiles, so the file appears early and grows in bursts. The file's own header already warned
about this for the *stop condition* (a lull in warp mode used to kill the emulator mid-compile,
"leaving a 513 byte object, NO MAP, and a cheerful compiled line") -- the stop condition was fixed
to wait for `OK CODE` and **the success check was left behind**.

**Fixed 2026-09-08:**

- `TIMEOUT` 180 -> **420**. GPBMODS at ~2,200 lines and two `GP.BANKED` regions takes about 200
  seconds, so 180 was under the biggest thing in the tree and had been for a while.
- The loop sets `finished = True` only on `OK CODE`, and a run that ends any other way now
  `die()`s instead of reporting a size.
- A build that asked for a map and did not get one `die()`s too.

**The tell, when it happens again anywhere:** an object that is 513 bytes, or any size with no
map beside it. Do not read the size as progress -- the banner is the finish line. And note the
log is DELETED on success, so a false success destroys its own evidence; check for the map first.

Related: [[headless-basl-build-recipe]], [[two-pass-compiler]], [[tests-share-the-products-memory]].
