---
name: git-bash-sed-strips-crlf
description: In this repo's Git Bash, sed -i writes a CRLF file back as LF, and grep -c $'\r$' counts every line as CRLF; check line endings with Python bytes
metadata:
  type: feedback
---

`sed -i` on a CRLF source rewrites it with LF line endings. `grep -c $'\r$'` reports every line as
CRLF whatever the file holds, so it does not catch the change, and `core.autocrlf` is true, so
`git diff` does not show it either. Seen 2026-09-15 on 22 files in HANDLER-BANK step 12, and put back.

**Why:** the sources are CRLF, and the broken check reported the converted files as CRLF.
**How to apply:** change CRLF files with the Edit tool or with Python in binary mode, not `sed -i`.
Count line endings with Python (`data.count(b"\r\n")` against `data.count(b"\n")`), never with grep.
See [[basl-sources-use-all-three-line-endings]].
