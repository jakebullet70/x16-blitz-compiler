---
name: program-too-big-fires-early
description: "PROGRAM TOO BIG was the compiler's shared 8K workspace, not the object buffer — a RAM bank each, then a second bank under the line table for 4,096 lines; and the real max program size is 17,408 bytes, not 22,272"
metadata:
  node_type: memory
  type: project
  originSessionId: 5591d6bc-636d-4001-b0b0-d858156d6ec0
  modified: 2026-09-08T22:30:00.000Z
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

**AND 2,048 LINES WAS THE WALL AGAIN, 2026-09-08.** `samples/GPB-MODS-TESTING/GPBMODS.BASL` marks
**2,156** lines and stopped with `PROGRAM TOO BIG @ 3055` — same message, same wrong limit, one
table further along. **The line table has a SECOND bank under it now (9, and 10 for the block
depths that shadow it), and holds 4,096.**

The mechanism is worth knowing before touching any of it: every pointer into the table — in
`mark_line.asm`, in `GPBankRelocate` and in `WriteMapFile` — is now a **virtual** address running
`$C000` down to `$8000`, and `STRPageLine` (`storage/mark_line.asm`) is the only thing that turns
one into a real `$A000-$BFFF` address plus a bank. **Bit 13 is the whole of the segment**, so the
translation is an `ORA #$20`. `storage_access` and `depth_access` therefore select from a
*variable* rather than a constant, which `STRPageLine` writes — so **page the record first, with
nothing between that and the window**, or you get whichever segment the last call left selected.
`STRFindLine` no longer holds one window across its whole search: it copies the four-byte record
out and closes, because the bank has to be re-chosen per entry.

Fixed in passing, since it was in the rewritten lines: `STRFindLine`'s exact-match test compared
the line number's **low byte twice** (`lda (zTemp1)` where it meant `(zTemp1),y`), so `GOTO 300`
could report an exact match on line 556 and hand back its address.

Evidence it is transparent: `samples/editor` (1,461 lines) compiles **byte-for-byte identically**
under the old compiler and the new one, and GPBMODS's 2,156 lines all pass the two-pass agreement
check in `STRMarkLine`, which is an exhaustive round trip of the table across the bank boundary.

**Bank allocation at compile time, and it matters**: 0 KERNAL, 1 the native test harness's p-code
buffer, 2 line table, 3 GP.ASM's blob pool, 4 variable list, 5 block depth, 6 block ends, 7 the
object buffer, 8 the shared region scratch, 9 the line table's second half, 10 the block depth's
second half, 63 down the GP.BANKEDSTR pools. A table in bank 1 once broke the `variables` and
`arrays` suites silently, so run those six after touching any of this.

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
lines and the line table not until 4,096, so the object budget binds first — which is correct, the
wall is about the program's own size. Only very sparse code, or a program that puts most of its
p-code in `GP.BANKED` regions the fit check does not see, reaches the line table at all: GPBMODS is
15,209 bytes resident with 2,156 lines, and that is what got there.

To raise it further, in order of work: relax `MIN_WS_PAGES` for a program that needs little
workspace (policy, not hardware); shrink the 4K frame stack (~250 frames); or shrink the runtime,
since every byte off it moves `ObjectBase` down.

Related: [[compiler-must-not-cap-program-size]], [[gpc-blitz-runtime-slack-and-limits]],
[[headless-basl-build-recipe]].
