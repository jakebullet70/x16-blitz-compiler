---
name: gpasm-fixups-retired-by-two-passes
description: "GP.ASM's deferred fixup list was a single-pass habit: pass two knows every base while it assembles, and pass one's pool is skipped from the checksum, so references resolve where they are made and the 128 cap is gone"
metadata:
  type: project
---

**Removed 2026-09-07, and it unblocked GPBFILES.** `GP.ASM` used to record every label reference
and `{VAR}` reference in a table of up to `ASM_MAX_FIXUPS = 128`, walked by `AsmPatchAll` at the
end of pass two. **128 was a hard ceiling, not a tunable** — `AsmAddFixup` did `asl a / tax`, so
entry 128 wrapped to entry 0, the same shape `BSTR_MAX_GROUPS` has.

GPBFILES needs about **194** across nine `GP.ASM` blocks (SORT alone 67, the two FILEDIR blocks
71) and stopped with `OUT OF MEMORY` on its ninth. **GPBMODS was sitting at 114 of 128.** The
error names the `GP.ENDASM` line, because `AsmResolveLocals` adds a block's whole crop of label
references at once when the block closes.

**Two facts retire the table, and both were already true:**

- `AsmSetBases` / `AsmSetBasesShared` run at `BLC_ENDPASS1`, before `ObjStreamOpen` and therefore
  before pass two compiles a line (`application/compiler/object.asm`). So `AsmPoolBase`,
  `AsmPageDelta` and `AsmWorkspacePage` are all in hand **while** a blob is being assembled, not
  merely afterwards. `AsmCloseBlock` already relied on this for the blob-call address.
- **Pass one never needed a fixup at all.** `AsmFlushPool` calls `SumSkipYA` over the entire pool
  — *"the pool is resolved in the bank by pass two and not at all by pass one, so it is not summed
  either"* — so an operand pass one leaves unresolved is an operand nobody reads.

So `AsmAddFixup` became `AsmResolveRef`: pass one returns immediately, pass two does the same
arithmetic `AsmPatchAll` did and stores it into the pool where it stands. The table, its count,
its index and `AsmPatchAll` are gone; **there is no cap on references any more**, the window gives
640 bytes back to the blob pool, and the compiler is 116 bytes smaller.

**Proved by byte-comparing the object.** GPBMODS compiles to a file identical to the pre-change
one apart from a single bootstrap byte that was itself a bug (see below), so every blob address
and label target resolves exactly as it did.

**The bug that comparison found.** `bstrBank` was cleared nowhere — `ResetPassState` deliberately
leaves it alone so pass two inherits pass one's answer — and `object.asm` pokes it into **every**
object's bootstrap extension page, GP.BANKEDSTR or not. So a program with no banked text got a
different stale byte in each build and **two compiles of one source did not match**. Cleared for
pass one now, beside `bstrPages`. Whenever object layout changes, compile twice and `cmp` the two
files: the checksum compares pass two against pass one, and cannot see a value both passes take
from the same uninitialised byte.

Related: [[two-pass-compiler]], [[gpasm-implementation-status]],
[[gp-bankedstr-literal-text-in-a-bank]], [[compiler-must-not-cap-program-size]].
