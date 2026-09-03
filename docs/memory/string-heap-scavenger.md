---
name: string-heap-scavenger
description: "SHIPPED 2026-09-02: StringConcrete reuses dead blocks; the editor's intermittent OOM was two bugs (no reclaim + a garbage line-0 read); doc-present self-check still ~600B over budget"
metadata: 
  node_type: memory
  type: project
  originSessionId: 0e51b2f1-b7dd-4e99-9afa-7d0af2c10e19
  modified: 2026-09-02T09:40:46.167Z
---

**The runtime string heap never reclaimed anything until 2026-09-02.** `write_string.asm` set an
"available for reclaim" flag (control byte bit 7) on every block a string outgrew, and nothing read
it. `StringConcrete` (source/runtime/source/strings/concrete.asm) now walks the heap first — blocks
tile it exactly from `stringHighMemory` up to `storeEndHigh:00` — and resurrects the first dead
block whose max length fits, ceiling untouched, max length KEPT. First fit, ~62 bytes.
**Cost: crossed the page cushion ([[gpc-core-page-cushion-below-gpbase]]), RT 13,055 → 13,311 —
one page off every program's max size.** FRE probes showed the editor's render path plateau at a
fixed value instead of descending forever: that plateau is the proof it works.

**The "intermittent OOM I could not explain" (commit be65870) was two bugs, neither timing in the
program logic:**

1. The leak above — total burn tracked FREE within a page of the cliff, so 5888=0/24 fail,
   5632=1-in-6, 5120=8/8.
2. The randomness: document-less boot has `LINE.COUNT=0`, and `ED.LOAD.LIVE` asked `DOC.LOAD` for
   line 0 anyway — an unwritten table slot, and PEEK of wherever it pointed became a LENGTH over
   the emulator's randomised RAM: a 0..255-char garbage string, different every boot. `DOC.LOAD`
   now guards `LINE.INDEX >= LINE.COUNT` → "". Result: self-check 12/12 clean at FREE 5,120.

**FIXED 2026-09-02 (later the same day):** the doc-present case ran to `M4 OK` once the FIND
path stopped allocating -- it was spending 579 bytes on folded copies of every line it
scanned. See [[gpc-string-blocks-never-shrink]]. The historical note below stands as the
record of what was true before that.

**Known limit, deterministic (WAS):** stage a real TEST.MD and the self-check dies 8/8 in
`LINEINPUT.WAIT`, ~600 bytes short — every historical "green" run was document-less without
anyone noticing (`FIND1 ... Not found: bullet` in the log was the tell). Next levers: the 1.5×
expansion factor in StringConcrete; the FIND residue (`ED.HAY$`, `ED.FOLD.OUT$`) held live
through the GUI block.

**Method that cracked it:** FRE() at bisecting probes, per-run, via flake.py — but remember FRE
reads the CEILING, a high-water ratchet: two runs with equal FRE can hold different corpse
patterns, so equal probes upstream do NOT clear upstream code. The map file (`M.EDITOR` p-code
offset → line) plus EDITOR.SYM (label → line, and BASLOAD strips blank/label/REM-only lines —
model that when counting) turns `OUT OF MEMORY @ $xxxx` into a source line.

Pre-sizing strings (assign long once, then reuse-in-place forever) is real but costs its blocks
up front — 5×258 did not fit alongside the editor's arrays and killed boot deterministically.
Measure before band-aiding. See [[headless-basl-build-recipe]], [[program-too-big-fires-early]].
