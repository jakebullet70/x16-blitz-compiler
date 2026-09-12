---
name: gui-cua-phase5-state
description: Where GUI-CUA-PLAN phase 5 stands as of 2026-09-10 — what is written, what is left, and the three traps found doing it
metadata:
  type: project
---

Phase 5 of `samples/GPB-MODS-TESTING/GUI-CUA-PLAN.md` (demo panels, `GP-BASIC.GLOBALS.md`,
help text — no new bank code) is **written but not verified or committed** as of 2026-09-10.

Committed already: `2d18df6`, the six CUA modules into root `GPC-BASIC/` (THEME, MENUVERT,
MENUBAR, LINEINPUT, GUI, GUI2). **The `*.PLAIN.INC.BL` front doors that commit added are gone.**
Every bankable module is now two files instead: `X.INC.BL` with plain labels for low memory, and
`X.BANK.INC.BL` with `.BODY` labels for a `GP.BANKED` region. See `GPC-BASIC/BANKED-OR-NOT.md`.

Uncommitted in the working tree: `GPC-BASIC/GP-BASIC.md`, `GPC-BASIC/GP-BASIC.GLOBALS.md`
(new §3/§4 sections for MENUBAR, GUI, GUI2, STASH, STASHFILE, SORT, STRCASE; the
public-name-vs-`.BODY` rule), and `samples/GPB-MODS-TESTING/GPBMODS.BASL` (the new
`GMX.D.FOCUS` demo panel, dropdown entry 11, `BS.CHROME` TAB line).

**Still owed:** rebuild GPBMODS + GUIFRMT headlessly (last good: GUIFRMT 3,690 B /
ALL TWENTY-FOUR PASS; GPBMODS 14,652 B, `.B04` 8,194 `.B05` 7,938 `.B06` 3,330
`.B07` 4,098 `.B08` 1,538) — delete the stale `.SRC.PRG` first, see
[[headless-basl-build-recipe]]; regenerate help with `samples/GPC-HELP/MKHELP.PY`;
mark phase 5 done in the plan (em dashes and §, the file is UTF-8); commit and push.

**Deliberately outside phase 5** and still drifting: KB.INC.BL (root header is newer — a
merge, not a copy), STRCASE.INC.BL (work copy wants a `SHIM.UTILBANK.INC.BL` root lacks),
APPSYS/SORT/STASH/STASHFILE/STRINGS/STRUSING, and `STASH.SLOT`/`STASH.NEXT` which
`GP-BASIC.md` §3.6 documents but the root copy does not have.

**Why:** three phases of context were spent proving the root folder self-consistent; the
verification and the sync scope are the expensive parts to re-derive.

**How to apply:** resume at the rebuild. `#SYMFILE` is named after the SOURCE PRG —
`X.SRC.PRG` needs `X.SRC.SYM`, or the compile dies with `NO SYMBOL FILE FOR {}` only
after the 420 s timeout. A `\` inside a `<<'PY'` heredoc reaches Python as one
backslash — use `chr(92)`. And the user has twice rejected heredoc scripts that patch
another script; prefer plain `sed -i` or Edit. See [[library-working-copy-then-root]].
