---
name: overlay-in-prg-research
description: "Research only, 2026-09-16: putting GP.BANKED region data inside the PRG instead of N .nnn files. A LOADed file is capped at 39,679 bytes total, so a single file only works for small programs; the write-up is docs/blitz/OVERLAY-IN-PRG.RESEARCH.md"
metadata:
  type: project
---

**Asked 2026-09-16. Researched, nothing decided, nothing built.**

The full write-up with all the arithmetic is
[docs/blitz/OVERLAY-IN-PRG.RESEARCH.md](../blitz/OVERLAY-IN-PRG.RESEARCH.md). Read that
before reopening the question. What is worth carrying without it:

**Option C was chosen and is BUILT**, to
[docs/blitz/OVERLAY-SINGLE-FILE.PLAN.md](../blitz/OVERLAY-SINGLE-FILE.PLAN.md) --
one `NAME.OVL`, self-describing, no `.nnn` left anywhere. What it became is
[[region-overlay-ovl-file]]; what remains owed is the plan's own test matrix, section 10,
which needs a build.

**The binding number is `$9F00 - $0801 = 39,679`.** BASIC's `LOAD` puts the whole file in
low RAM from `$0801` and low RAM ends at `ObjectCeiling`. So appending regions to the PRG
caps a program's total payload there, regions included. No trick lifts it: a self re-LOAD,
a `P` seek plus MACPTR, and padding up to `$A000` were all checked and all fail, because
the tail is inside the stream the first LOAD already delivered.

**The extension page had three free bytes**, `$09ED-$09EF` — the GP.BSTR table is pinned at
`GPBSTRBANKS $09F0`, and any loader bigger than the one it replaced would have needed a
second page and moved banked p-code from `$0A00` to `$0B00`. It did not come to that: the
`ACPTR` reader that replaced the bank bitmap and the name poker came out SMALLER, and the
page now has seven free bytes.

**`MACPTR` is used nowhere in this codebase.** Only the address is defined. Any design that
reaches for it is writing first-use code with an `ACPTR` fallback, not reusing something.

**The preferred shape is D**: append the regions into the PRG when the total fits under
`$9F00`, and fall back to a single self-describing `.OVL` when it does not. A plain append
with no fallback is a build-side size wall, which [[compiler-must-not-cap-program-size]]
forbids.

**`ACPTR` was measured on 2026-09-16 and it passes.** Under hostfs, at real speed, a byte loop
reads 8,192 bytes in **17 jiffies, 0.283 s**, against a 0.3 s threshold; `CHRIN` over the same
file takes 19 jiffies and would fail. So the reader fits the existing extension page and `MACPTR`
is not needed. The probe is `drive/ACPTRBEN.BASL` with `drive/PROBE.DAT` beside it.

**The regression was then measured against the real data, not extrapolated.**
`drive/LOADBEN.BASL` times both halves over GPBMODS' eight regions, which hold 32,000 bytes --
125 pages, every one already an exact page multiple, so the `.OVL` padding costs GPBMODS nothing
and the file is 32,016 bytes. Eight `BLOAD`s of the `.nnn` files take **1 jiffy**; one `OPEN` and
an `ACPTR` walk of the `.OVL` take **75 jiffies, 1.25 s**. Both phases checksum the eight banks
and both were right.

So under hostfs the cost is **1.23 s, a factor of 75**. But hostfs flatters the baseline and not
the reader: a hostfs `LOAD` is a host-side block copy, while the `ACPTR` walk is CPU-bound and
will cost about the same on any device. 1.23 s is therefore the worst case for the regression,
not the expected one. The GUI helper's 12,296 padded bytes come to 0.42 s by the same rate. It
is a startup regression, not a size cap.

**Still owed: the same number from a mounted SD card image.** Nothing in this tree mounts one and
there is no image builder in `bin/x16emu/`, so it needs an image made first.

Related: [[region-overlay-ovl-file]], [[object-writer-regions-vs-low-code]],
[[object-file-must-fit-under-the-runtime]], [[macptr-wraps-banks-itself]].
