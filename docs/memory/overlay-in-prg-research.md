---
name: overlay-in-prg-research
description: "Putting GP.BANKED region data inside the PRG. A clean LOAD caps at 39,679 bytes; one file of any size works via self re-OPEN but LOAD prints ?OUT OF MEMORY, which the user REJECTED 2026-09-29. Option D chosen, not built. Write-up: docs/blitz/OVERLAY-IN-PRG.RESEARCH.md"
metadata:
  node_type: memory
  type: project
  originSessionId: 222be9a4-b83e-46a2-97e4-f9c3d57d0c2e
  modified: 2026-09-29T06:43:58.602Z
---

**Asked 2026-09-16. Option C built. Option D decided 2026-09-29, not built.**

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
caps a *clean* LOAD there, regions included.

**CORRECTED 2026-09-28: the wall is soft, so a single file of any size is possible.** The
X16 KERNAL LOAD does not overrun I/O. `x16-rom kernal/cbm/channel/load.s` drops from MACPTR
blocks to single bytes at `$9D00` (`cmp #$9d`), and the byte loop stops at `$9F00`
(`cmp #$9f` / `ld81`), closes the file and returns error 16. Everything to `$9EFF` is intact.
BASIC's `cload` (`basic/code26.s`) then prints `?OUT OF MEMORY` and skips the `vartab` /
`lnkprg` update, but the program text is in memory and `RUN` should reach the SYS line
(read, not yet run). So the bootstrap can re-OPEN its own PRG, skip the low part, and run
the existing `.OVL` reader over the tail. The cost is that error on LOAD for any file over
39,679, and `RUN"NAME"` aborts on it. x16emu `-prg -run` survives it: it pastes the LOAD and
the RUN as separate lines (`src/main.c`). The earlier "same wall" verdict assumed the overrun
corrupts memory, and it does not.

**Section 6 of the research doc has the full review: shape, seven costs, three probes owed.**
The costs most likely to bite: GPC's own LOAD chain (`load.asm` writes `10 LOAD"name"` and
RUNs it in the ROM) dies on error 16, so chaining into a big single file needs its own
KERNAL LOAD placed outside `$0801-$9EFF`; and the skip loop does not fit the page.

**DECIDED 2026-09-29: `?OUT OF MEMORY ERROR` on LOAD is not acceptable.** Do not propose the
self re-OPEN single file again. The plan is option D: append the regions when the total fits
in 39,679 bytes, write `NAME.OVL` beside the PRG when it does not. Every file loads clean.
**Why:** the user will not ship a program whose LOAD prints an error. **How to apply:** any
region-packaging work builds D; what D still needs is room on the extension page for a
second region path beside the `ACPTR` reader.

**The extension page had three free bytes**, `$09ED-$09EF` — the GP.BSTR table is pinned at
`GPBSTRBANKS $09F0`, and any loader bigger than the one it replaced would have needed a
second page and moved banked p-code from `$0A00` to `$0B00`. It did not come to that: the
`ACPTR` reader that replaced the bank bitmap and the name poker came out SMALLER. GP.BSTR's
table now copies to `$07F0`, and the listing of 2026-09-28 shows nine free bytes,
`$09F7-$09FF`.

**`MACPTR` is used nowhere in this codebase.** Only the address is defined. Any design that
reaches for it is writing first-use code with an `ACPTR` fallback, not reusing something.

**D keeps the fallback because** a plain append with no `.OVL` is a build-side size wall,
which [[compiler-must-not-cap-program-size]] forbids.

**`ACPTR` was measured on 2026-09-16 and it passes.** Under hostfs, at real speed, a byte loop
reads 8,192 bytes in **17 jiffies, 0.283 s**, against a 0.3 s threshold; `CHRIN` over the same
file takes 19 jiffies and would fail. So the reader fits the existing extension page and `MACPTR`
is not needed. The probe is `source/drive/ACPTRBEN.BASL` with `source/drive/PROBE.DAT` beside it.

**The regression was then measured against the real data, not extrapolated.**
`source/drive/LOADBEN.BASL` times both halves over GPBMODS' eight regions, which hold 32,000 bytes --
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
