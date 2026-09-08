---
name: region-overlay-ovl-file
description: "DESIGN, not built: ship GP.BANKED and GP.BANKEDSTR regions in a separate .OVL file the bootstrap LOADs into banks, so region bytes stop counting against the 24,065-byte file ceiling"
metadata:
  type: project
---

**Proposed 2026-09-08. Not built.** The user does exactly this in Prog8, so the shape is proven
elsewhere.

## The problem it solves

Every region ships inside the object, and a GP program's whole file is capped at **24,065 bytes**
([[object-file-must-fit-under-the-runtime]]). GPBMODS spends ~13K on low p-code, so **all** its
regions together get ~10K — barely more than one full bank. Eight regions of 8K would be 64K,
three times the entire file budget. **The 8-region cap is not what binds; the file is.**

Pull the regions into `NAME.OVL`, loaded separately, and the file ceiling stops applying to them
entirely.

## Most of it is already written

- **The bootstrap already LOADs a file by name** — `BBTryLoad` (`bootstrap.asm:229-240`) is nine
  instructions of SETNAM/SETLFS/LOAD, with a local-then-root fallback, carry-based retry, and a
  `?RT` error path to copy.
- **`BXTable` is already the OVL's directory** — `(pages, bank)` per region, in object order.
- **The once-per-load latch already exists** — `stz BXTable` (`bootstrap2.asm:96`).
- **`GPBankRelocate` already emits the regions as one contiguous page-aligned blob** at the end of
  the object. It lands in the same file only because nothing tells it not to.
- **130 spare bytes** on the extension page.

## What is new — four things

1. `ObjectWriteShared` opens a second stream and diverts the region run to it.
2. The compiler bakes the OVL name into the extension page — the patched-operand trick already
   used for `BBBasePage` and `BXBStrBank`, plus ~16 bytes of string.
3. The load itself (below).
4. **The fit check drops its region term**: `fileEndPage = PCODE_PAGE + gpBankActive +
   pages(low code)`. That is the whole prize.

## The one real decision: LOAD cannot seek

| | banks | padding | bootstrap |
|---|---|---|---|
| **(a) one LOAD, consecutive banks** | must be consecutive | 8K a region on disk | one LOAD, no loop |
| (b) one file a region | arbitrary | none | a loop, N files to keep together |
| (c) OPEN + MACPTR | arbitrary | none | most code, none of it written yet |

**Take (a).** The X16 KERNAL auto-increments the RAM bank crossing `$BFFF`, so select the first
bank, `LOAD` at `$A000`, and one call fills consecutive banks — the bootstrap does not even keep
its copy loop. The compiler pads each region to 8K in the OVL and refuses non-consecutive banks
with a message. Padding costs disk and nothing else. (c) is the upgrade if arbitrary banks ever
matter.

**The auto-increment is CONFIRMED** — no test needed, it is already documented and already relied
on here:

- `source/runtime/_library.asm:4403` — *"LOAD into banked RAM starts at whatever bank `$00` selects
  and advances it by itself when a file runs past `$BFFF`, so setting the bank IS the whole of the
  bank handling."*
- `docs/x16/X16 Reference - 04 - BASIC.md:417` says the same for the KERNAL.
- `samples/prg2basload/prg2basload.basl:76` BLOADs a source file through as many banks as it needs,
  and works.

The load also reports back: `$030D/$030E` hold the end address and `$00` the ending bank, so the
bootstrap can check the OVL arrived whole for free.

**The OVL never touches low RAM.** That is the whole point and it is worth stating plainly, because
today's path does: a region is compiled into the object, LOADed at `$0801` with everything else, and
only then copied up to `$A000` — so it pays full file price to arrive. Select the bank, LOAD
straight to `$A000`, and the bytes never enter the low 40K at all. `bootstrap2.asm`'s copy loop
disappears with them.

Secondary address 1 (what `BBTryLoad` already passes) loads at the file's own header address, so the
compiler writes an `$A000` header and the bank select is the only new instruction pair.

See [[macptr-wraps-banks-itself]] for the neighbouring fact that MACPTR does it too.

## Costs, stated

- **Two files that must travel together, versioned as a pair.** A stale `.OVL` beside a fresh
  `.PRG` is silently wrong text -- the same class of bug that cost a day in
  [[object-file-must-fit-under-the-runtime]]. It needs a stamp the bootstrap checks; the runtime
  already solves this with a build number in the filename, so there is a pattern to copy.
- A LOAD-chained set needs an OVL each ([[load-chain-strands-array-strings]]).
- One more file open per run.

## What it unlocks, and in what order

Region bytes stop counting against the file. **Resident p-code stays capped at 15,360** — that is
the workspace test and this does not touch it. Only after this is banked content bounded by banks
rather than by the file, which is the point at which raising `GPBANK_MAXREGIONS` (8, and cheap to
raise — 130 spare bootstrap bytes, 13 bytes of compiler storage a region) and the one-text-bank
rule become worth doing. **In that order.** Do them first and you only move where
`PROGRAM TOO BIG` fires.

**Measure GPBFILES against BOTH ceilings before building this.** If it is over on the workspace
test too, the OVL does not help it and it still needs splitting.

Related: [[gp-banked-region-relocation]], [[gp-bankedstr-literal-text-in-a-bank]],
[[compiler-must-not-cap-program-size]], [[object-writer-regions-vs-low-code]].
