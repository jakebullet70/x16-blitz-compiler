---
name: gp-banked-region-relocation
description: GP.BANKED moves its region to the end of the object with a rotation and two GOTOs to line numbers; the three things that hold a buffer address and had to be fixed by hand
metadata: 
  node_type: memory
  type: project
  originSessionId: 75714395-f705-4d27-8da6-af4a832a1e0b
  modified: 2026-09-05T15:37:35.863Z
---

**BUILT 2026-09-05, increment 2 of the banked GUI.** `GPBankRelocate` (`gpbank.asm`) lifts a
`GP.BANKED` region out of the middle of the object and puts it at the end. Called from
`SaveCodeAndExit` **after the `$FF` end marker and BEFORE `FixBranches`**, which is the whole reason
it is cheap: every branch is still an unresolved LINE NUMBER at that point, so no branch needs
touching.

**The trick is that both bridges are ordinary `GOTO`s to ordinary line numbers.** The region starts
on the `GP.BANKED` line's `PCD_NEWCMD_LINE` byte and ends on the `GP.ENDBANKED` line's, so both
lines have a line-table entry pointing exactly at a boundary. Fix the table, write a `GOTO
<GP.BANKED's line>` where the region was and a `GOTO <GP.ENDBANKED's line>` after it, and
`FixBranches` resolves them by the path it resolves every other `GOTO`. **No new opcode, no
absolute operand, no back-patching.** Six bytes.

**The move is a rotation, in place** -- shift region+tail up by three, reverse the region, reverse
the tail, reverse the pair. There is no room in low RAM for a second buffer; the object buffer is
the biggest thing there precisely because there isn't.

**THREE THINGS HOLD A BUFFER ADDRESS and had to be corrected by hand.** Miss any one and the
program compiles clean and misbehaves:

1. the line-number table (bank 2, 4-byte entries, `addr` at +2);
2. **`.fngosub`** -- a `DEF FN` body's position. It is ABSOLUTE in the buffer until `FixBranches`
   turns it into an offset a moment later, so at relocation time it is live;
3. **`GP.ASM` blob-call fixups** (`AFIX_CALL`), whose `AsmFixTarget` is *where in the buffer the
   `.word` operand sits*. The other two fixup kinds are pool/workspace offsets and must NOT move.

**Both markers must be FIRST on their line, and outside every `GP.DO` / `GP.SELECT`.** First on the
line because `objPtr-1` is then the line marker, which is the boundary; written after another
statement the boundary lands mid-instruction. Outside every block because a `GOTO` written after
compilation has no `.unwind` in front of it to release the frames it leaves. All three ways to get
it wrong are `BLOCK MISMATCH`.

**The map file is no longer sorted by offset** once a region has moved -- every entry is right, but
the region's lines carry the highest offsets while sitting in source position. "Largest offset <=
the reported one" now means reading the whole file, not reading down it.

**`FixBranches` DESTROYS `objPtr`.** It rewinds to the start of the object and walks, so it returns
pointing at the `$FF` end marker -- not at the end of the buffer. That was invisible while the
GP.ASM pool was appended AFTERWARDS, because then the end marker really was the end. Move
`AsmFlushPool` ahead of it and `objPtr` -- which is the length `WriteObjectCode` streams -- cuts
every pool off the object file: a program with an inline blob compiles OK and jumps into nothing at
its first blob call, with no error anywhere. `SaveCodeAndExit` holds the real end in `objectEnd`
across the call.

**The layout the region ends up in, and the one rule behind it:** `[A][GOTO in][C][$FF][pool][pad]
[B][GOTO out][$FF]`, low RAM up to the pool and the bank from the pad on. **The pool stays in low
memory** because a blob is 65C02 code and a blob that changes the RAM bank -- `STASH` does -- must
not itself be executing out of one. The region is page aligned so the bootstrap's copy is a page
loop; there are only 33 spare bytes in the bootstrap page and a byte loop does not fit. Two walkers
(`FixBranches`' main loop and its unwind walk, and `ScanGPUsage`) HOP over the pool via `GPBankHop`,
because the `$FF` they all stop at is now in the middle of the object.

**IT RUNS FROM THE BANK, and that had to be READ OUT rather than inferred.** The region is still
present at its old low-memory address in the loaded image -- the bootstrap copies it up, it does not
remove it -- so a branch that wrongly pointed back at the low copy passes every behavioural test
until the workspace grows over it. `testing/BANKP.BASL` reports codePtr and the bank register from a
blob inside the region: **160 (`$A0xx`) and bank 5**, against `$09xx` from low memory.

**The cross-boundary correction is ONE BYTE**, because both bases are page aligned so the difference
is a whole number of pages: `$A0` minus the page the region would have run at, added to the offset's
high half. `GPBankMakeOffset` replaces `STRMakeOffset` in FixBranches' two patch tails.

**No sidecar file.** The bootstrap copies the region in -- 33 bytes that fitted in the padding at
`$08DF..$08FF` after reclaiming 4 (`stz abs,x` for the magic wipe, and letting `BBLoadX` fall through
into `BBTryLoad`). ONCE PER LOAD: it zeroes its own page count, because the workspace starts where
the region was and a second RUN would otherwise copy variables into the bank.

**SHARED mode only** -- embedded has no bootstrap, and `NOT IMPLEMENTED` says so against the line.

**The bank must stay selected at every fetch inside the region.** `PEEK`/`POKE` are safe (they save
and restore); `BANK` inside a region is refused at compile time; `BANK`/`BLOAD`/`BSAVE` in LOW memory
before a call into the region are equally fatal and are closed by a low-memory ENTRY SHIM per public
library entry point (`BANK n : GOSUB body : RETURN`, ~12 bytes each). `testing/BANKR.BASL` hangs and
`BANKS.BASL` -- the same program with the bank put back -- does not.

Tests: `testing/BANK*.BASL`, thirteen of them, each marked program run against an otherwise
identical unmarked control and compared on OUTPUT (the objects differ now, so a byte
compare is no longer the test -- it was, for increment 1). `GPC.BIN` 16,409 -> 17,694, which costs
nothing: see [[compiler-must-not-cap-program-size]], the buffer has thousands of bytes of slack over
the run-side ceiling.

Related: [[pcode-runs-from-a-bank-proven]], [[gpasm-implementation-status]],
[[program-too-big-fires-early]].
