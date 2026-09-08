---
name: make-libs-does-not-install-the-runtime
description: "make libs rebuilds gp.library and GPC.BIN but never writes testing/GPB.RT.nnn.BIN. A new runtime opcode then compiles fine and dispatches into garbage at run time. Run make -C source/runtime gpc-rt as well."
metadata:
  type: project
---

**`make libs` does not install the runtime binaries.** `source/runtime`'s default target is
`build`, which assembles the test harness image into `source/runtime/build/`. The two files a
compiled program actually loads — `testing/GPB.RT.nnn.BIN` and `testing/GPC.RT.nnn.BIN` — are
written only by the **`gpc-rt`** target, through `scripts/rtname.py`.

So after a change under `source/gp-runtime/` or `source/runtime/`:

    make libs                          # gp.library, runtime.library, GPC.BIN -- all fresh
    make -C source/runtime gpc-rt      # ...and THIS is what testing/ runs against

## What it looks like when it bites

Found 2026-09-08 building `GP.FN`. The compiler emitted the two new opcodes `$F1`/`$F2` correctly —
p-code, branch offsets and variable addresses all decoded right out of the object — and every
program using them wedged with `OUT OF MEMORY` and a runaway PC. The runtime in `testing/` was
three and a half hours old and its vector table had no entries for them, so the dispatcher jumped
through whatever followed the table.

**The tell is one `ls`:** `testing/GPC.BIN` freshly dated, `testing/GPB.RT.120.BIN` hours behind it.
The name never changes (`rtbuild.txt` is pinned), so nothing notices.

Bisecting the handlers cannot find this — gutting them to no-ops changes a file that is not being
loaded. **Check the runtime's date before bisecting runtime code.**

Related: [[app-make-does-not-rebuild-compiler-library]] (the same trap one library up),
[[baseline-compiler-is-the-application-copy]], [[headless-basl-build-recipe]],
[[measure-before-changing-code]].
