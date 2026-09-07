---
name: gp-bankedstr-literal-text-in-a-bank
description: "BUILT: GP.BANKEDSTR puts a program's literal text in a RAM bank with named, compile-time-resolved groups; measured +3,840 bytes on GPBMODS, and GPBFILES is blocked by ASM_MAX_FIXUPS instead"
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

## The two caps

`BSTR_MAX_GROUPS` was 32 and is now **128**, which is the shape's own ceiling — the subscript is
doubled into X with one `ASL`, so 128 wraps to 0. 32 is plenty for a program written by hand and
not plenty for one converted from literals.

**GPBFILES is still blocked, but NOT by p-code** — by `ASM_MAX_FIXUPS = 128` in
`commands/gpasmcode.asm`, which has the identical `asl a / tax` ceiling. It needs ~194 fixups
across nine `GP.ASM` blocks (SORT alone is 67, the two FILEDIR blocks 71); **GPBMODS is at ~114
and about to hit it too**. Lifting it needs 16-bit indexing in `AsmAddFixup` and `AsmPatchAll`,
or — cheaper and probably right — noticing that pass two knows `AsmPoolBase` and
`AsmWorkspacePage` while it assembles and could resolve on the spot instead of recording anything.

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
- The object-writer half of this is its own note: [[object-writer-regions-vs-low-code]].

Related: [[gp-banked-region-relocation]], [[banking-strings-scales-with-length]],
[[gpbmods-resident-pcode-breakdown]], [[gpc-core-page-cushion-below-gpbase]].
