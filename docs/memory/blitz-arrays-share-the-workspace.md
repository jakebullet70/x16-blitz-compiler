---
name: blitz-arrays-share-the-workspace
description: Blitz has no array heap - DIM bump-allocates from the same workspace as everything else and raises OUT OF MEMORY on collision; the old 409-float/512-int figures were the deleted Prog8 GPC, not this compiler
metadata:
  type: project
---

**Verified 2026-09-04**, reading `source/runtime/source/commands/dim.asm` and
`source/runtime/source/memory/array.asm`.

**There is no separate array heap in Blitz.** `DIM` bump-allocates upward from `availableMemory`,
in the same pot as p-code, variables and the string heap, and `DIMWriteByte` compares against
`stringHighMemory` on every page boundary:

```asm
lda     availableMemory+1           ; check out of memory
cmp     stringHighMemory+1
bcs     _DIMWBMemory                ; -> .error_memory
```

So a too-big `DIM` **raises `OUT OF MEMORY`**. It is loud, and it is charged directly against the
room the program has left to run in. A float element is **6** bytes, an int (`%`) 2, plus a 3-byte
header per level. Re-checked 2026-09-06 against `array.asm`, which multiplies the index by 3 and then
by 2 -- its own comment says "x2 or x6 depending on type". An earlier revision of this note said 5.

**THIS REPLACES A NOTE THAT WAS ABOUT A DIFFERENT COMPILER.** `gpc-array-heap-capacity` recorded
fixed bump heaps -- `ARRHEAP_SIZE = 2048` float / `IARRHEAP_SIZE = 1024` int, so ~409 and 512
elements -- with a too-big `DIM` silently marking the array unusable and every access reading 0.
That was the abandoned Prog8 self-hosted GPC, whose `src/runtime/vm.p8` is not in this tree and
whose source is off disk ([[blitz-x16-prior-attempt]]). Nothing of it applies here: grep finds no
`ARRHEAP` anywhere in `source/`. The note survived the GPC prune because its name did not say GPC's
*internals* were the subject, and it was still indexed under Performance as if it constrained Blitz.
It was caught when it got copied into a subagent file and the claim was checked against the runtime.

**The lesson worth keeping is the filing one**: a `gpc-*` note is about the dead project unless it
is demonstrably about X16 BASIC or the X16. Check the path it cites -- if the file is not in this
tree, neither is the fact.

Related: [[gpc-blitz-runtime-slack-and-limits]], [[measure-before-changing-code]],
[[gpc-string-blocks-never-shrink]].
