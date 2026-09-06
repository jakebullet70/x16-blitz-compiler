---
name: gpbmods-resident-pcode-breakdown
description: "MEASURED: 84% of GPBMODS resident p-code is the shell itself (11,453 B). All eight library modules together are 2,109 B, and only 656 B of that is bankable -- so banking libraries cannot buy headroom."
metadata:
  type: project
---

**Measured 2026-09-06** from `testing/GPBMODS.MAP` + `GPBMODS.SRC.SYM`, charging each label the
distance to the next label in OBJECT order. Totals 13,563 against the 13,568 `gpBankStart` read off
the map's own discontinuity, so the method is sound to five bytes.

| file | resident p-code | bankable |
|---|---:|---|
| **(main program) -- the GPBMODS shell** | **11,453** | **no** -- calls the GUI |
| `BANKMGR.INC.BL` | 574 | no -- a `BANK` |
| `STRINGS.INC.BL` | 430 | yes |
| `STASH.INC.BL` | 407 | no -- six |
| `SORT.INC.BL` | 200 | yes |
| `LIBBANK.INC.BL` | 187 | no -- it IS the shims |
| `STASHFILE.INC.BL` | 171 | no -- twelve |
| `APPSYS.INC.BL` | 114 | no -- a `BSAVE` |
| `STRCASE.INC.BL` | 26 | yes |

**The shell is 84% of it.** Every library module put together is 2,109 bytes, 16%, and only
`STRINGS` + `SORT` + `STRCASE` = **656 bytes** can go in a region at all. Banking the whole library
would buy less than a page.

**So "bank another module" is not a lever on this program.** The lever is the shell, and the shell
cannot be banked because it calls `GUI.SAY` and friends -- see [[gp-banked-call-out-loses-the-bank]].

## What would actually open it up

**Give the GOSUB frame a code-bank field and have RETURN restore it.** Then a shim needs no holding
variable, nesting works, region-to-region calls through low memory work, and the shell banks. Every
constraint in [[gp-banked-call-out-loses-the-bank]] and most of [[filedir-bank-split]] dissolves at
once. The frame machinery already exists -- see [[gpc-return-unwinds-frames]] and
[[pcode-runs-from-a-bank-proven]].

Until then the answer for an oversize GUI program is the two-demo split, not more regions.

Per-module cost is worth re-measuring whenever the map is rebuilt: the script idea is in
[[measure-pcode-per-module]], and the label-gap method above is what survives GP.BANKED relocation.
