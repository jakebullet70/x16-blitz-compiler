---
name: release-readmes-fit-78-columns
description: "A readme that ships in the release is read on the X16, so no line, table row included, may pass 78 columns"
metadata:
  node_type: memory
  type: feedback
  originSessionId: d2b7b119-5992-421b-90e8-03d6d590b04d
  modified: 2026-10-01T11:11:43.812Z
---

A readme that ships in the release is read on the X16 itself, so every line stays at 78 columns or
less. Table rows count. A row that cannot fit gets shorter cells, a column moved into a sentence
after the table, or becomes a list.

The rule came from the MANDELBROT-SPEED readme on 2026-10-01, and the same day every shipped
readme was brought under it: the root `README.md` above its cut, and the GPC.ERR, GPC-HELP,
BASLOAD-GPC, GPC-BASIC and MANDELBROT-SPEED readmes. They are also ASCII only, because a UTF-8
em dash or section sign is three or two bytes of junk on the X16. Below the root README's cut is
not shipped and is still wider.

**Why:** the user said "readme file needs to be no bigger than 78 col so it can be read on the
X16". The screen is 80 columns.

**How to apply:** give the 78-column limit to any agent that writes or edits a shipped readme, and
check it with Python on the bytes, not characters. A long code-block command is broken with a
shell continuation, and a wide table becomes shorter cells plus a sentence or a list. Related:
[[release-samples-shape]], [[git-bash-sed-strips-crlf]].
