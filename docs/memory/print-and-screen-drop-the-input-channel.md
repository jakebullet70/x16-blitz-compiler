---
name: print-and-screen-drop-the-input-channel
description: "PRINT and SCREEN return the KERNAL input channel to the keyboard, so MACPTR after either one moves nothing and still reports a non-zero count"
metadata:
  node_type: memory
  type: project
  originSessionId: e179b21e-600e-494f-acf6-72782518954d
  modified: 2026-09-29T15:40:57.212Z
---

**Re-assert CHKIN immediately before every MACPTR.** A CHKIN done at open time does not
survive `PRINT` or `SCREEN`. Both put the input channel back on the keyboard, so a later
MACPTR reads from nothing.

**The failure is silent and looks like success.** MACPTR on the wrong channel moves no
bytes and still returns a count in .X/.Y that is not zero. A measured call asking for 16
bytes returned 28,095 and wrote nothing. Any loop whose only guard is "a zero-length
transfer means the file ran out" counts that as progress, reaches its byte total in two or
three passes and returns with no error set.

**The fix that holds is structural: put CHKIN and MACPTR in ONE GP.ASM blob.** A BASIC-level
CHKIN is a rule somebody has to remember; a blob makes the gap impossible. `FILEDIR.INC.BL`
had it right from the start and never hit this.

FIXED 2026-09-29 in `GPC-BASIC/BMX.INC.BL`. The symptom was a white screen from `BMXVIEW`
with `BMX.ERROR$` empty at every stage, and it came from making the module a library: the
CHKIN was in `BMX.OPEN` and the MACPTR in `BMX.PAINT`, so the caller's `PRINT` and `SCREEN`
sat in the gap. The module's own documented two-step form is the failing case. Cost an
afternoon chasing the build wiring, the runtime version and SHARED-vs-EMBEDDED, all of which
were byte-identical to a build that had worked.

`BMX.MOVE` is now the only channel reader in the file: CHKIN, the 255-byte chunk loop,
READST and the count tests all inside one blob. It carries a guard worth copying -- MACPTR is
asked for at most 255 bytes, so a returned count above the ask is impossible, and testing for
it turns a junk 28,095 into a named error instead of a blank screen. BMXVIEW went 2,269 to
2,561 bytes for it.

**Consequence for callers: `{VAR}` needs a `#SYMFILE`**, above the `#INCLUDE`s, named to match
the PRG. Any program including `BMX.INC.BL` must now have one or the compile stops with a
`?STRING TOO LONG ERROR` naming neither the file nor the cause.

**`FILEDIR.INC.BL` is safe, checked 2026-09-29**: its CHKIN, MACPTR loop and CLRCHN are all
inside one blob. So are BASIC's own file statements -- `x16_getchar.asm` calls CHKIN before
every CHRIN and `x16_printchar.asm` calls CHKOUT before every write, so `GET#`, `INPUT#`,
`LINPUT#` and `PRINT#` cannot hit this. The exposure is only hand-rolled KERNAL channel calls
issued from BASIC. `MCIOUT` has the identical trap on the write side and is used nowhere yet.

How it was measured, and the shape any repeat should take: run the same MACPTR twice in
one program, differing only in the carry flag, with CHKIN re-asserted before each, and
count how many target bytes changed. Carry clear steps the target and changes all of them.
Carry set holds the target and changes one. Print nothing between the calls, and read
results into variables before printing: `PRINT` moves VERA's ADDR0, so a readback loop
with a `PRINT` inside it returns screen memory rather than what was asked for.

Related: [[bmxview-two-copies-one-master]], [[headless-basl-build-recipe]],
[[macptr-wraps-banks-itself]].
