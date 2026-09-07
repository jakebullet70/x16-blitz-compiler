---
name: object-writer-regions-vs-low-code
description: "Pass two streams low code through a buffer and each region into its own bank; anything written above the buffer's reach makes the streamer pad forward, and both passes agree so no check fires"
metadata:
  type: project
---

**Pass two has two ways to write a byte and they are not interchangeable.** `ObjStreamWork`
(`source/application/source/compiler/object.asm`) branches on `regionOpen`:

- **low code** goes into a sliding buffer in `OBJ_BUF_BANK`, indexed `objPtr - objBufBase`, and is
  flushed to the file as it fills. It is **sequential**: the buffer only ever moves forward.
- **a region** goes into `OBJ_RGN_BANK + nextRegion`, indexed `objPtr - layoutStart[nextRegion]`,
  which is **random access** inside that bank.

`ObjStreamClose` then writes, in order: whatever the buffer still holds, **one** gap of `$FF`
filler from `objBufTop` up to `layoutStart[0]`, then each region out of its bank. Region *n*'s
span is `layoutStart[n+1] - layoutStart[n]`, and the topmost region's is `pass1Len` minus its
start. That is the whole contract, and it has three requirements:

1. anything living **above** the low code must be a region with a layout slot;
2. regions are contiguous — each starts exactly where the one below it ends, which is why only
   one gap is filled;
3. the topmost region must end at `pass1Len`.

**BREAKING (1) COSTS 65,535 BYTES AND NOTHING REPORTS IT.** GP.BANKEDSTR's text region was first
written as low code at an `objPtr` above everything the buffer had reached. The streamer answered
by padding forward across the entire span the GP.BANKED regions occupy — and then wrote those
regions *again* out of their own banks. A 22K program came out as an 88K file whose tail was a
chunk of BASIC ROM, read past `$BFFF` off the end of a bank window.

**Neither the length check nor the Fletcher checksum saw anything wrong**, and that is the part
worth remembering: `_SCECompare` compares pass two against pass one, the padding is the
*streamer's* and not the compiler's, and both passes did the identical thing. The compiler's own
`objPtr` said 22,528 throughout. **The file size is the only witness** — check it against `CODE`
whenever object layout changes.

The fix was to give the text a real layout slot, with `gpBankLinesIn`/`gpBankLinesOut` of `$FFFE`
so `RegionSwitch` — which walks the layout looking for the line that opens each region — never
matches it. Then `ObjStreamClose` needed no change at all.

**Two traps that follow from (2).** Page-align a region by *advancing* `objPtr`, never by writing
filler: `ObjStreamClose` fills the gap below the first region itself, so written filler is
counted twice. And `ClaimRegionTop` hands pass two `pass1Len` as "the top of the regions" — true
only while the topmost region is the last thing pass one wrote. Add a region above it and pass
two starts one region too high; winding back is what triggers the pad above.

**And a region needs more than a bank number.** `BStrRegister` first raised `gpBankCount` without
filling `gpBankStarts`/`gpBankEnds`, and `_GBMOSide` — which decides which region each end of a
branch is in — read the stale entry, found ordinary addresses inside it, and stopped the compile
with `NOT IMPLEMENTED` on a branch that crossed nothing.

Related: [[gp-banked-region-relocation]], [[two-pass-compiler]], [[compile-is-write-only]],
[[gp-bankedstr-literal-text-in-a-bank]].
