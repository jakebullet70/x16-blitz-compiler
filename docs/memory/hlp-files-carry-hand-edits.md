---
name: hlp-files-carry-hand-edits
description: The HELP-TXT .HLP files carry no hand edits; a plain MKHELP.PY run is the rebuild, three commands
metadata: 
  node_type: memory
  type: project
  originSessionId: 422a7b37-5897-4def-9e69-98fb13f87ae9
  modified: 2026-10-03T00:00:00.000Z
---

The committed `GPC-BASIC-TOOLS-SRC/GPC-HELP/HELP-TXT/*.HLP` files hold no hand edits. A plain
`MKHELP.PY` run loses nothing, so a help rebuild is a render in place. The user confirmed it on
2026-10-03 ("there are no hand edits anymore in help"), after a render-and-diff check on 2026-09-24
matched the committed files.

**How to apply:** three commands rebuild the content, after the module change is copied to root
`GPC-BASIC/`:

- `MKHELP.PY` from `GPC-BASIC-TOOLS-SRC/GPC-HELP`, which writes `HELP-TXT`, the index and
  `GPC-HELP.md`;
- `MKHELP.PY --mods GPC-BASIC-TOOLS-SRC/GPB-MODS-TESTING/GPC-BASIC --md-only --md-name GPC-HELP-TESTING.md`;
- `MKHELPWIN.PY` from the repository root, which writes `GPC-HELP.WIN.md`.

`GPC-HELP-TESTING.md` is CRLF. A new topic renumbers every later `.HLP` file. See
[[help-topic-writing-rules]].
