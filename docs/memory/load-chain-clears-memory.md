---
name: load-chain-clears-memory
description: "The LOAD-chain variable carry was ripped out on 2026-09-12 -- a chained program now clears memory on entry like a fresh RUN, which closes the unbounded string-array leak and means CLR on entry is never needed. The shared runtime is still not reloaded."
metadata:
  type: project
---

**What a LOAD chain re-uses now.** The carry was removed on 2026-09-12 in **runtime build 121**,
with the leak below as the reason. Replaces the earlier `load-chain-strands-array-strings` note.
The build number moved with it, so every SHARED object built against 120 is stranded and must be
recompiled -- see [[make-libs-does-not-install-the-runtime]]. Verified by the nine-hop compiled
chain in `OASIS/tmp-test` (`python build.py compiled`): RESULT PASS, 45 GOSUB calls across the
hops, zero failures. The runtime came out 43 bytes smaller and `StorageEnd` fell $5f7 -> $5f3.

- **The shared runtime is not reloaded, and that has not changed.** `BootEntry`
  (`source/application/source/compiler/bootstrap.asm:57-80`) compares a 4-byte magic at `RTBASE`
  and jumps straight to `RT_ENTRY` when it matches. Prg2 runs prg1's copy. This is what makes a
  chain fast.
- **Nothing else carries.** `ClearMemory` runs on every entry, so variables, the string heap and
  `stringHighMemory` all start fresh -- the same as a fresh `RUN` and the same as the interpreter.
  The `"GPCL"` signature `Command_LOAD` armed at `loadChainSig`, and the `StartRuntime` branch that
  skipped the clear, are gone. `samples/shared-vars` demonstrated the old behaviour.
- **Pass state through a disk file.** That is also the only mechanism a mixed interpreted/compiled
  chain can use; see `docs/oasis/FULL-SOURCE.PLAN.md`.

**Why it went.** A block is marked dead only when its variable is reassigned to something
**longer** (`write_string.asm:47-51`), never when its pointer is dropped, and a `DIM` zeroes every
element (`dim.asm:97-100`, `_DCOLFillArray`). With the clear skipped, every block the previous
program's string array held lost its only pointer while keeping a live control byte -- invisible to
the scavenger, unreusable, and `stringHighMemory` never came down. Scalars were bounded (in-place
reuse, `write_string.asm:46-48`); string arrays leaked without bound. Ten hops with a 50-element
array stranded 500 blocks.

Both halves of that mechanic still hold **inside** one program -- a `DIM` frees nothing and a
re-assignment to a shorter string keeps the block -- so a program that builds many big temporaries
still has to watch its own heap. See [[gpc-string-blocks-never-shrink]] and
[[string-heap-scavenger]].

**`FRE(0)` is the instrument** -- literally `stringHighMemory - availableMemory`
(`fre.asm:49-53`).

**One hazard closed with it.** A GP-OUT program chaining to a GPB one makes the loaded program
pull the full runtime up to `RTGPBASE $6600`, writing 2 KB through the top of the inherited
workspace. Nothing checked it, and it does not matter now that the workspace is cleared on entry
anyway.
