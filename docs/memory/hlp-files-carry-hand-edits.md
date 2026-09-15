---
name: hlp-files-carry-hand-edits
description: The committed HELP-TXT .HLP files hold hand edits the GPC-BASIC masters lack; a plain MKHELP.PY run reverts them
metadata: 
  node_type: memory
  type: project
  originSessionId: 422a7b37-5897-4def-9e69-98fb13f87ae9
  modified: 2026-09-15T09:30:43.142Z
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

**A new topic renumbers every later file** (2026-09-15, the `KV.INC.BL` entry added two topics at
H056, and every topic after it moved up two). A per-file-name diff then pairs the wrong topics.
Instead, map old topic to new by the index `T` rows' titles, with the section number stripped, so a
renumbered heading still matches. Then diff old render n against new render m and patch committed n
into m. Snapshot `HELP-TXT` first, because the renames overwrite each other. Also on 2026-09-15,
`GPC-HELP-TESTING.md` was stale rather than hand-edited: it had not been regenerated after commit
867976c. Take it whole from a render with `--mods samples/GPB-MODS-TESTING/GPC-BASIC`, then put back
the header's command line and the CRs.
