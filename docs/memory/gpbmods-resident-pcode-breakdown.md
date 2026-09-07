---
name: gpbmods-resident-pcode-breakdown
description: "MEASURED: 79% of GPBMODS resident p-code is the shell itself (10,737 B). All eight library modules together are 2,825 B -- so banking libraries cannot buy headroom."
metadata:
  type: project
---

**Measured 2026-09-06** from `testing/GPBMODS.MAP` + `GPBMODS.SRC.SYM`, charging each label the
distance to the next label in OBJECT order. Totals 13,563 against the 13,568 `gpBankStart` read off
the map's own discontinuity, so the method is sound to five bytes.

| file | resident p-code | `BANK`/`BLOAD`/`BSAVE` in code |
|---|---:|---|
| **(main program) -- the GPBMODS shell** | **10,737** | none, but it calls the GUI |
| `STASH.INC.BL` | 650 | **4** |
| `BANKMGR.INC.BL` | 574 | none |
| `SORT.INC.BL` | 499 | none |
| `STRINGS.INC.BL` | 430 | none |
| `STRCASE.INC.BL` | 200 | none |
| `LIBBANK.INC.BL` | 187 | **18** -- it IS the shims |
| `STASHFILE.INC.BL` | 171 | **4** |
| `APPSYS.INC.BL` | 114 | none |

**THE MAP CANNOT SEE GP.ASM CODE, so the label-gap method charges every blob to the shell.**
`gpasm.asm` deliberately writes no `STRMarkLine` for a swallowed body, so assembled machine code
appears as one unmarked 716-byte span between the last main-program line and `gpBankStart`, and
whichever label precedes it is charged the lot. It splits 243 `STASH` / 174 `STRCASE` /
299 `SORT`, summing to the observed span exactly and matching the sizes those two modules record
in their own headers. **The table above has that correction applied**; a fresh run of
`source/unit-tests/deadcode.py --price` reports the pool separately rather than folding it in.

**Grep for these with `##` comment lines stripped first.** Counting raw matched the word `BSAVE`
inside an APPSYS comment explaining why there is no BSAVE, and wrongly excluded both APPSYS and
BANKMGR -- which halved the apparent total.

**The shell is 79% of it.** Every library module put together is 2,825 bytes, 21%. The five with no
bank statement come to **1,817 bytes** -- seven pages, against a gap of several thousand.

**Passing that grep is necessary, not sufficient.** The second test is whether the module is ever
called WITH A DATA BANK SELECTED, which is what disqualifies `FILE.DIR.FILL` and `FILE.DIR.STEP`
even though the `BANK` statements are in their callers -- see [[filedir-bank-split]]. Check both
before counting a module as movable.

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

A different lever on the same total: 1,212 of these bytes are routines the program includes and
never calls -- see [[basl-dead-code-elimination-measured]].
