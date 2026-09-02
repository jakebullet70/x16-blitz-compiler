# The GP block: what is in it, what it costs, and what a cut line could save

**Re-measured 1st September 2026, AFTER the stash and the sort left the block.** The survey below
was written when the block was 2,048 bytes; §0 records what actually happened next, and the rest of
the document is the original finding with its numbers marked. Everything is read from
`source/runtime/build/code.lst`, the linked runtime image this tree last produced.

---

## 0. What changed, and what is left

| | then | now |
|---|---:|---:|
| `ObjectBase` | `$3f00` | **`$3c00`** |
| block size | 2,048 | **1,280** |
| code ends at | `$3EE1` | **`$3B54`** |
| free | 29 | **172** |
| runtime image (`RT`) | 14,079 | **13,311** |

Three of the groups §3 called out as least used have gone, and none of them by finding a cheaper way
to write the code — **by finding it did not belong in the block at all**:

- **`GP.STASH` / `GP.RESTR`, 329 bytes** -> `GPC-BASIC/STASH.INC.BL`, `GP.ASM`. `$3f00` -> `$3e00`.
- **`GP.SORT`, 408 bytes** -> `GPC-BASIC/SORT.INC.BL`, `GP.ASM`. `$3e00` -> `$3d00`. `GP.ARRPTR`
  stayed (49 bytes), because the module is built on it: a BASL subroutine cannot be handed an array.
  The file it was in is `gparrptr.asm` now.
- **`GP.UPPER` / `GP.LOWER` / `GP.TRIM` / `GP.LTRIM` / `GP.RTRIM`, 188 bytes** including their
  shared `GPStringAddress` -> `GPC-BASIC/STRCASE.INC.BL`, `GP.ASM`, one blob with the mode tested
  once at entry. `$3d00` -> `$3c00`. `GP.STRPTR` stayed and is what the module is built on, for the
  same reason `GP.ARRPTR` did.

Each page is charged twice — object *and* workspace floor — so that is **1,536 bytes back for every
GP program in the tree**, whether or not it sorts, stashes or touches a string, and no keyword was
lost: all three are still available as an `#INCLUDE`, in the programs that actually want them.

**The pattern is now explicit enough to state as a rule.** A group can leave the block when its
argument can be reduced to an ADDRESS a BASL routine can be handed — `GP.ARRPTR` for the sort,
`GP.STRPTR` for the strings — and when what it does is a STATEMENT rather than a function. Those two
keywords are therefore load-bearing and should be the last things anyone tries to remove, not the
first: each is small, and each is the hinge that let a much larger group out.

Conversely: **`GP.INSTR`, `GP.COMP` and `GP.STRPTR` stay because they are functions.** A module
cannot be one, so `IF GP.COMP(A$,B$) = 0` would become three lines and an out-variable. That is the
boundary of this technique, not a gap in it.

### The next 84 bytes are worth 512

Code ends at **`$3B54`**, which is **84 bytes** past `$3B00`, and `ObjectBase` rounds up to a page —
so 84 bytes saved anywhere in the block hands back another 512. The 172 bytes of slack above the cut
are doing nothing; the 84 below it are worth more than all of them. Check which side of a page a
change lands on before costing it: the answer flips. Candidates, none costed:

- **`GP.SELECT`'s general path, 98 bytes**, which `TODO.md` has costed in full — and rejected,
  *because* it freed no program bytes at the boundary of the day. It clears this one on its own.
- **`GP.A` / `GP.X` / `GP.Y` / `GP.C`, 31 bytes**, which are `PEEK($030C..$030F)` and could be
  composites for zero runtime bytes. `gpcall.asm` left them unshifted deliberately — 41 cycles
  against `PEEK`'s 58, in loops — so this is a speed decision to re-open, not free.
- **`GP.ARRPTR` (49) and `GP.STRPTR` (24)** — see the rule above. Removing either means finding
  another way to hand a module an address first; `{A$()}` in the `GP.ASM` brace parser is the
  proposal on file, and would be compiler-side and free at runtime.

---

## 1. The block as it was (2,048 bytes) — the original survey

`GPBase = $3700`, `ObjectBase = $3f00` (`source/application/rtimage.gen.asm`). **2,048 bytes**,
and it is charged **twice**: `WriteObjectCode` writes `$0801..ObjectBase` instead of
`$0801..GPBase` into the object, and the workspace floor moves up by the same amount. So one GP
keyword costs a program **4,096 bytes** of the machine.

It is **all-or-nothing**. `gpscan.asm` walks the finished p-code and asks, per opcode, "does this
instruction's handler live at or above `GPBase`?" — by address, not by name or token number,
which is the right invariant and is why it cannot drift. But the answer is one bit for the whole
program: `gpUsed`, set or clear.

Code ends at **`$3EE1`**. `ObjectCodePreHeader` sits at `$3EFE`. **29 bytes free.**

---

## 2. Where the 2,048 bytes go

| group | files | bytes | what pulls it in |
|---|---|---:|---|
| control flow | `do.asm` `select.asm` `unwind.asm` | **252** | `GP.DO` `GP.LOOP` `GP.EXITDO` `GP.SELECT` `GP.CASE` `GP.OTHER` `GP.ENDSEL`, and a `GOTO` out of a block |
| machine-code call | `gpcall.asm` | **108** | `GP.CALL` `GP.A` `GP.X` `GP.Y` `GP.C` |
| drawing | `gpdraw.asm` | **445** | `GP.BOX` `GP.FILL` `GP.PRINTAT` (+ the shared `GPDraw*` helpers and the 48-byte border table) |
| screen stash | `gpstash.asm` | **329** | `GP.STASH` `GP.RESTR` — **GONE, now `STASH.INC.BL`** |
| strings | `gpstring.asm` | **426** | `GP.INSTR` `GP.COMP` `GP.STRPTR`, and the five in-place statements — **GONE, now `STRCASE.INC.BL`** |
| sort | `gpsort.asm` | **457** | `GP.SORT` — **GONE, now `SORT.INC.BL`** — and `GP.ARRPTR`, which stayed |
| | free | 29 | |

`GP.IF` / `GP.ELSEIF` / `GP.ELSE` / `GP.ENDIF` have **no handler in the block** — they compile to
`.ifnext` / `.ifelse`, which run the core `.goto.z` / `.goto` handlers below `GPBase`. A program
whose only block construct is `GP.IF` is GP OUT and pays nothing.

---

## 3. The finding

**Sort and stash are 786 bytes — 38% of the block — and are the two least-used keywords in the
set.** *(Both have since left it entirely; see §0. That turned out to be a better answer than any
cut line, because it needed no change to `gpscan.asm` at all.)* Strings add another 426. Meanwhile **control flow, the group nearly every GP program pulls
the block in for, is the smallest at 252 bytes — and it is split across both ends**:

```
$3700  do.asm       (98)   <-- control flow
$3762  gpcall.asm  (108)
$37CE  gpdraw.asm  (445)
$398B  gpsort.asm  (457)   <-- least used, in the middle
$3B54  gpstash.asm (329)
$3C9D  gpstring.asm(426)
$3E47  select.asm  (112)   <-- control flow again, at the far end
$3EB7  unwind.asm   (42)   <-- and again
$3EE1  (29 free)
```

For any scheme that cuts at a high-water mark, that order is exactly backwards: a program using
only `GP.SELECT` reaches `$3E47` and therefore keeps everything.

**Link order is alphabetical by leaf filename** (`build.py`, `sortKey = (parts[-1], parts)`), so
reordering the block is *renaming files*. That is not a new trick in this tree — `00gpbase.asm`
already carries a comment saying "THE LEADING ZEROS IN THE NAME ARE LOAD BEARING".

**And the groups are already separable.** A scan of all nine files for any reference — `jsr`,
`jmp`, or a bare symbol in an operand — to a symbol defined in another file inside the block
returns **nothing**. Every GP file calls only downward into the core runtime. There is no
dependency graph to untangle; the layout is free to be reordered by frequency alone.

---

## 4. What a cut line would save

Proposed order, cheapest and most-common first, with the cut rounded up to a page:

| tier | cumulative | cut at | a program that stops here keeps | saves (object + workspace) |
|---|---:|---:|---:|---:|
| control flow | 252 | 256 | 256 | **3,584** |
| + `GP.CALL` | 360 | 512 | 512 | **3,072** |
| + drawing | 805 | 1,024 | 1,024 | **2,048** |
| + stash | 1,134 | 1,280 | 1,280 | **1,536** |
| + strings | 1,560 | 1,792 | 1,792 | **512** |
| + sort | 2,017 | 2,048 | 2,048 | 0 |

Against real programs in this tree:

- **`samples/editor`** uses `GP.CALL`, `GP.BOX`, `GP.FILL`, `GP.PRINTAT`, `GP.STASH`, `GP.RESTR`,
  `GP.DO`, `GP.SELECT`, `GP.IF` — stops at the stash tier. **1,536 bytes back**, against a build
  currently reporting `FREE 6400`.
- **A `MENUVERT` / `GUI.INC.BL` program with `GUI.BANK = 0`** — drawing and control flow only.
  **2,048 bytes back.**
- **A program whose only GP keyword is `GP.SELECT` or `GP.DO`** — **3,584 bytes back**, which is
  most of what a small program has.

---

## 5. What it would take

1. **Rename the nine files** so link order is the tier order. No code moves.
2. **`genrtimage.py`** — `GPUsageBits` is one bit per opcode today (32 bytes). It becomes one
   *tier index* per opcode. Three bits is enough for six tiers; a byte per opcode is 386 bytes of
   compiler space and simpler. The comparison is still done at build time against the image's own
   linked table, so the invariant in §1 is preserved: it is still an address question.
3. **`gpscan.asm`** — `stz gpUsed` / set-if-any becomes max-so-far. Same walk, same
   `MoveObjectForward` stepping, one `cmp`/`bcc` instead of a bit test.
4. **`WriteObjectCode`** — cut at the computed page rather than at `GPBase` or `ObjectBase`.
5. **The workspace floor** — derived from the image length, and has to follow the same variable
   cut, or the saving is halved.
6. **`memreport.asm`** — `GP-BASIC IN/OUT` becomes a tier, e.g. `GP-BASIC DRAW`.

## 6. What has NOT been checked

- **SHARED mode.** A shared program loads `GPB.RT.<n>.BIN` from disk and gets the whole runtime.
  A variable cut can only apply to self-contained objects; whether that is already true of
  `WriteObjectCode`'s two paths has not been read.
- **`RT_ABI`.** Whether a variable-length image needs an ABI bump, and what that costs in forced
  recompiles of shared-mode programs.
- **Absolute references from the core *into* the block.** §3 proves the block does not reference
  itself across files. It does not prove nothing below `GPBase` reaches up — it should not, since
  the block is discardable today, but the vector table is the obvious place to look.
- **The 29 free bytes.** Any tier that lands a few bytes over a page boundary wastes most of a
  page. Worth measuring the padding after a reorder before believing the table in §4.

---

## 7. The cheap version, if the full scheme is not wanted

One extra tier instead of six: move `gpsort.asm` and `gpstash.asm` (786 bytes) above a second cut
point, and give `gpscan` a second bit rather than a max. Programs that neither sort nor stash —
most of them — get **1,536 bytes** back, for one bit and two file renames.
