---
name: program-too-big-fires-early
description: "PROGRAM TOO BIG was the compiler's shared 8K workspace, not the object buffer — fixed by a RAM bank each; and the real max program size is 17,408 bytes, not 22,272"
metadata:
  node_type: memory
  type: project
  originSessionId: 5591d6bc-636d-4001-b0b0-d858156d6ec0
  modified: 2026-09-01T20:03:48.859Z
---

**FIXED 2026-09-01.** It was never the object buffer.

**`PROGRAM TOO BIG` HAS THREE RAISE SITES, not one**, and only the last is about the object:
`STRMarkLine` (line-number table), `CreateVariableRecord` (variable name list) and `_CAWriteByte`
(`objPtr` vs `ObjectCeiling`). One message for two unrelated exhaustions is exactly why it read as
an object-size problem. The two with a source line print `@ nnnn`; a fourth, write-time check in
`WriteObjectCode` prints **`PROGRAM TOO BIG` with no `@`** — that spelling tells you which fired.

**The cause: the two tables shared ONE 8K bank** at `$A000-$BFFF`, growing towards each other, so
the real limit was their SUM. `samples/editor` had reached **7,981 of 8,192** — 1,461 line entries
x 4 plus 356 variable records x 6 — leaving **211 bytes, about fifty-two more lines of source.**

**The fix: a bank each** (`source/compiler/source/system-specific/x16/x16_storage.inc`). Line table
keeps bank 2, variable list moves to bank 4, and each bounds itself against its own window rather
than against the other table. `varstore_access`/`varstore_release` is the second window pair. The
split is clean because no routine touches both tables: `mark_line.asm` + `WriteMapFile` are the
line table; `create.asm`, `findvar.asm`, `reset.asm` are the variable list. **2,048 lines and 1,365
variables now.** `GPC.BIN` came out 13 bytes smaller — both bounds tests got simpler.

**Bank allocation at compile time, and it matters**: 0 KERNAL, 1 the native test harness's p-code
buffer, 2 line table, 3 GP.ASM's blob pool, 4 variable list. A table in bank 1 once broke the
`variables` and `arrays` suites silently, so run those six after touching any of this.

## THE REAL MAX PROGRAM SIZE IS 17,408 BYTES OF P-CODE

`ObjectCeiling - FreeMemory` = 22,272 is where the compiler BUILDS the object; **it is not what a
program may be.** `WriteObjectCode` computes `newWorkspacePage = ObjectBase + pages(object) +
FrameStackPages` and rejects anything leaving under `MIN_WS_PAGES`. With `ObjectBase $3b00` and
both page counts 16 (4K each), `$3b00`..`$9F00` is 25,600 bytes of object + frame stack +
workspace, so the object may be at most **68 pages = 17,408**.

Measured on `samples/editor` with filler lines worth 10 bytes of p-code each:

| filler | object | `FREE` | result |
|---:|---:|---:|---|
| 0 | 15,166 | 6,144 | OK |
| 120 | 16,366 | 5,120 | OK (this one used to fail) |
| **224** | **17,406** | **4,096** | **OK — the last one that fits** |
| 232 | — | — | `PROGRAM TOO BIG`, no line |
| 600 | — | — | `PROGRAM TOO BIG @ 2186` — entry 2,048, the line table |

**So `FREE nnnn` IS the headroom, once you know what it is headroom for.** It is the runtime
workspace, and a program is refused below 4,096 — so `FREE - 4096` is how much more p-code will
fit. I previously told the user `FREE` was not headroom at all; that was half right and the useful
half was the part I dropped. See [[answer-the-question-asked]].

**Which limit binds now:** at editor density (10.4 bytes/line) the object wall arrives at ~1,675
lines and the line table not until 2,048, so the object budget binds first — which is correct, the
wall is now about the program's own size. Sparse code meets the line table first.

To raise it further, in order of work: relax `MIN_WS_PAGES` for a program that needs little
workspace (policy, not hardware); shrink the 4K frame stack (~250 frames); or shrink the runtime,
since every byte off it moves `ObjectBase` down.

Related: [[compiler-must-not-cap-program-size]], [[gpc-blitz-runtime-slack-and-limits]],
[[headless-basl-build-recipe]].
