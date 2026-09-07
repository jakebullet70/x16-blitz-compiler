---
name: gp-bankedstr-literal-text-in-a-bank
description: "BUILT: GP.BANKEDSTR puts a program's literal text in a RAM bank with named, compile-time-resolved groups; +3,840 bytes on GPBMODS and GPBFILES compiles at last, with 2,304 to spare"
metadata:
  type: project
---

**Shipped 2026-09-07.** `GP.BANKEDSTR <bank> <NAME>` / bare quoted body lines /
`GP.ENDBANKEDSTR`, read back with `GP.BSTR(NAME, n)` and `GP.BSTRCOUNT(NAME)`. Text stops
costing resident p-code: a literal is `2 + N` bytes of low RAM, a reference is **5**, measured
off per-line map deltas rather than guessed. So it pays from four characters up.

**The name is resolved at COMPILE time and never reaches the object.** `BankedStrGroupCompile`
reads the bare identifier the way `AnyArrayCompile` does for `GP.ARRPTR`, looks it up in a group
table, and pushes the group's base as a constant; a second `X:` helper emits `PCD_PLUS`, so the
runtime handler takes one flat index. A **runtime** name index was costed and refused — it would
put the name's letters back into resident p-code at every call site, ~2,750 bytes in GPBMODS,
which is over half of what the feature exists to win back.

**A name is two bytes** either way: `ExtractVariableName` compresses every name to two, and
BASLOAD has already crunched `MENU.FILE` to something like `A0`. The block header and the
reference site go through the same routine, so the two spellings cannot diverge.

## What it measured

GPBMODS, 258 strings in 37 groups, one group per routine:

| | CODE | FREE | object |
|---|---:|---:|---:|
| before | 19,778 | 5,888 | 20,291 |
| after | 22,016 | **9,728** | 22,529 |

**+3,840 bytes of workspace**, against ~4,230 predicted. The object grows because the text moved
into a bank region, which is outside the p-code fit check.

**The 256-byte GP block crossing was spent**: `UnaryGPBStr` is 81 bytes against the 27 free below
`ObjectBase`, so `ObjectBase` moved `$3C00` → `$3D00`. `GPBase` did not move, so a non-GP program
pays nothing. Every GP program pays 256 whether it uses `GP.BSTR` or not.

## GPBFILES, which is what it was for

**It compiles**, 341 strings in 51 groups: `CODE 27,392  FREE 6,400`, so 2,304 bytes above the
4,096 reserve. All 341 come back byte for byte.

It took two walls, not one. The p-code cap was the second; the first was
`ASM_MAX_FIXUPS = 128`, which stopped it on its ninth `GP.ASM` block long before the p-code was
measured — see [[gpasm-fixups-retired-by-two-passes]]. **Neither wall was visible behind the
other**: with the fixup table gone GPBFILES reached `PROGRAM TOO BIG`, which is the failure the
plan had assumed all along.

`BSTR_MAX_GROUPS` was 32 and is now **128**, the shape's own ceiling — the subscript is doubled
into X with one `ASL`, so 128 wraps to 0. 32 is plenty for a program written by hand and not
plenty for one converted from its own literals: GPBMODS wants 37 groups and GPBFILES 51.

## Traps it cost

- **The pool cannot live in bank 7.** `OBJ_BUF_BANK = 7` is the object output buffer and banks
  8-15 are the region banks, none of it listed with the compiler's own banks 2-6. Pass one writes
  no object so the pool survived; pass two filled the bank and every length byte read back as 0.
- **The bank number is handed over at a FIXED address** (`GPBSTRBANK` in `common.inc`), not a
  label: the runtime is linked twice with `gp.library` at opposite ends, so a label lands at
  `$05E5` in the application image and `$0400` in the standalone one. `RT_ABI` 22 → 23.
- **`make -C source/runtime gpc-rt` is a separate target** that neither `make libs` nor the
  application build runs. A two-day-stale `GPB.RT.120.BIN` with no `gp.bstr` vector cost a long
  detour; the ABI bump now catches it.
- **`bstrBank` is poked into EVERY object's bootstrap**, banked text or not, so leaving it
  uninitialised made two compiles of one source differ. Cleared for pass one now. The checksum
  cannot catch that class of bug — it compares pass two against pass one, and both passes read
  the same stale byte.
- The object-writer half of this is its own note: [[object-writer-regions-vs-low-code]].

Related: [[gp-banked-region-relocation]], [[banking-strings-scales-with-length]],
[[gpbmods-resident-pcode-breakdown]], [[gpc-core-page-cushion-below-gpbase]].
