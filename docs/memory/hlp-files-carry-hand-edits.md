---
name: hlp-files-carry-hand-edits
description: The committed HELP-TXT .HLP files hold hand edits the GPC-BASIC masters lack; a plain MKHELP.PY run reverts them
metadata: 
  node_type: memory
  type: project
  originSessionId: 422a7b37-5897-4def-9e69-98fb13f87ae9
  modified: 2026-09-13T16:29:35.235Z
---

The committed `samples/GPC-HELP/HELP-TXT/*.HLP` files were trimmed by hand after they were last
generated: H001, H002, H003, H011, H013, H015, H022 and others, as of 2026-09-13. The masters under
`GPC-BASIC/` still hold the longer text, so `MKHELP.PY` over the tree puts it back. The index line
counts were not updated for those edits; an untouched topic's file is one line longer than its
`GPB.HELP.IDX` count.

**Why:** found 2026-09-13, when a full regeneration for the dead-code and GP.FN help changes rewrote
28 files and undid the trims.

**How to apply:** to carry a master change into the help, render twice into scratch with `--src`
and `--out`: old masters from `git archive`, new masters copied from the tree. `diff -u` the two
outputs and `patch` the committed files. Take a whole file only where the committed copy equals a
render of the old masters; the three `.md` files, the §7 and §8 topics and the index did. A `>n|`
cross reference counts index rows from line 3 of the file. The generated header's command line
always differs, so its hunk always fails; `-N -r -` skips it. `GPC-HELP-TESTING.md` is CRLF: strip
the CRs from a copy, patch it, and put them back, or every hunk fails. H007 is hand-edited too. See [[no-ship-language-this-is-dev]].
