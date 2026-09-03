---
name: retired-keyword-defers-to-runtime
description: "Retiring a GP keyword leaves every stale caller compiling clean and throwing SYNTAX ERROR at run time — grep the whole tree, testing/ included"
metadata: 
  node_type: memory
  type: project
  originSessionId: 5591d6bc-636d-4001-b0b0-d858156d6ec0
  modified: 2026-09-01T16:20:40.265Z
---

**Confirmed twice on 2026-09-01, both times after a keyword left the GP block for a `GP.ASM` module.**

A call to a keyword that no longer exists **compiles without complaint** and throws `SYNTAX ERROR @
$xxxx` at run time, the first moment it is reached. `errorhandler.asm` arms `deferErrors` while a
statement compiles and a SYNTAX error does not abort — the statement is rolled back and replaced with
a runtime throw-stub. Right for a typo you are about to fix; wrong for stale source, where the whole
file is affected and the compile says `OK CODE` instead of naming the line.

**The symptom is maximally misleading**: an address, no line, no keyword name, fired in whatever
section happens to reach the call first — for the editor, a hundred lines from anything to do with
the stash.

**What actually diagnosed it**: building the PREVIOUS compiler in a `git worktree` and running the
SAME source through it. Clean there, broken here ⇒ the compiler moved under the source, not the
source under the compiler. `git ls-tree <old> testing/` first — `GPC.BIN` is tracked but
`GPC.IMG.120.BIN` is not, so the old compiler needs a real `make` in the worktree.

**So: after retiring ANY keyword, grep the whole tree for it — `GPC-BASIC`, `samples`, AND
`testing`.** Casualties found this way: `GUI.INC.BL` (editor branch only, so the shrink branch never
saw it — a textually clean merge that was semantically broken) and `SCREEN.EXP.BL` (broken since
`15d90eb`, unnoticed for days), and `testing/GPC.ERR.BASL` — all three fixed 2026-09-01.

`testing/*.INC.BL` is **gitignored**, so those are local working copies: refresh them from
`GPC-BASIC/` rather than editing them, and remember a stale one silently changes what BASLOAD
tokenises. `testing/GPC.ERR.PRG` and `testing/C.GPC.ERR.PRG` ARE tracked, are SHARED-runtime builds
(~1.6 KB, no embedded runtime — `edbuild.py` only makes standalone ones), and are still stale.

**THE TOOL NOW EXISTS: `source/common-scripts/deferscan.py`.**

    python source/common-scripts/deferscan.py C.NAME.PRG <the OK CODE number> M.NAME

Walks the object's p-code by real instruction size and names every `.deferror` (token 234) with its
source line, from the `M.<name>` map. Exit 1 = found something. A byte search for `$EA` cannot do
this — it occurs inside `.word` operands and strings — so the walk steps properly and fails loudly
if it desynchronises. **`OK CODE` is not a passing test; this is.** Run it on anything after
retiring a keyword, and on the examples generally.

It immediately found one more, older than the shrink work: `INPHELP.ASK` did
`INPHELP.HOME = INPHELP.X` where `INPHELP.HOME` is `#DEFINE`d as 19 (the HOME key), so it compiled
as `19 = ...`. Fixed to `INPHELP.SAVEX`. **A `#DEFINE`d name used as a variable is the same trap
from the other end** — sweep `#DEFINE` names against assignment targets when touching a module.

To read a deferred statement back: the map gives a TOKENISED line number, and
`scratchpad/getline.py` prints that line out of the `.PRG`. Crunched names, but the shape is enough.

**Nothing builds the examples.** Twelve `.EXP.BL` files and eight `.INC.BL` modules are the
documentation and `make` compiles none of them, which is why a broken example survives a release.
Both fixes are written up in `TODO.md`'s Bugs section, which now leads with this.

Same root as [[gpb-block-openers-must-not-defer]]: deferral is only safe when the failure is
contained to one retypeable statement. Related: [[no-backward-compatibility-needed]] — retiring
keywords is cheap, but only if the stale callers are actually found.
