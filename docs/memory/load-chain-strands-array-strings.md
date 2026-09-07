---
name: load-chain-strands-array-strings
description: "LOAD chaining keeps variables by skipping ClearMemory, which also never lowers the string ceiling -- bounded for scalars, an UNBOUNDED leak for string arrays, because the chained program's DIM drops every block pointer without marking a single block dead."
metadata:
  type: project
---

**What a LOAD chain actually re-uses.** Found while costing alternatives to
[[gp-bankedstr-design]]; it is about `LOAD`, not about banking.

- **The shared runtime is not reloaded.** `BootEntry`
  (`source/application/source/compiler/bootstrap.asm:57-80`) compares a 4-byte magic at `RTBASE`
  and jumps straight to `RT_ENTRY` when it matches. Prg2 runs prg1's copy.
- **Variables carry because `ClearMemory` is skipped.** `Command_LOAD` arms `"GPCL"` at
  `loadChainSig` (`load.asm:76-81`); `StartRuntime` disarms it and skips the clear
  (`00runtime.asm:70-88`). This is what `samples/shared-vars` demonstrates.
- **Reset regardless of the chain**, so do not rely on them carrying: the frame stack
  (`ResetRuntimeStack` is unconditional), `stackFloorHigh`, the error handler, `ramBank` / `romBank`,
  and `availableMemory` -- which comes from the loaded program's own `.varspace` prologue, not from
  `ClearMemory`.

**The string ceiling never comes back down.** `stringHighMemory` is reset only by `ClearMemory`.

For **scalars** that is bounded. Slots are shared across the chain by first-appearance order, and
`WriteStringZTemp0Sub` reuses a block in place whenever the new string fits (`write_string.asm:46-48`),
so ten hops assigning the same five variables settle at five blocks.

**For string ARRAYS it is an unbounded leak, and this is the finding.** A block is marked dead only
when its variable is reassigned to something **longer** (`write_string.asm:47-51`) -- never when its
pointer is simply dropped. The chained program's `DIM` zeroes every element (`dim.asm:97-100`,
`_DCOLFillArray`), so every block the previous program's array held loses its only pointer while
keeping a live control byte. It is invisible to the scavenger and cannot be reused. Ten hops with a
50-element array strands 500 blocks.

`samples/shared-vars` carries five scalars and so never shows it.

**`FRE(0)` is the instrument** -- literally `stringHighMemory - availableMemory` (`fre.asm:49-53`).
Print it on entry to each program in the chain and watch it fall monotonically.

**`CLR` on entry is the fix**, at the price of the carry -- which is the whole reason for chaining
rather than `RUN`. A program that bounces between many others and does not need the carry should
just do it.

**One more, unguarded.** A GP-OUT program chaining to a GPB one makes the loaded program pull the
full runtime up to `RTGPBASE $6600`, writing 2 KB through the top of the inherited workspace -- where
the string heap lives. Nothing checks this.
