---
name: program-without-end-crashes
description: A GPC program whose last statement is not END prints its output and then crashes with "CPU program counter reached $ffff"; found 2026-09-14, not fixed
metadata:
  type: project
---

**A compiled program that runs off its last line without `END` crashes on exit.** The output is
all there, then x16emu dumps with `CPU program counter reached $ffff` instead of `READY.`.
Measured 2026-09-14 on a one-line `PRINT "A OK"`: embedded and shared, with the current compiler
and an older one, every time. The same program with `END` added exits clean. Stock X16 BASIC
ends such a program normally, so this is a GPC defect. The path at fault is the one that reaches the
`$FF` end marker; the `END` path is fine. Not investigated; a fix is asm, so ask first.

It is the tail of the "empty PRG" signature in [[basload-label-and-variable-collide]]: a 6-byte PRG
is a program with no `END`, and the `$ffff` there comes from this, not from BASLOAD.

**Why:** a throwaway test program without `END` looked like a `BANK` bug for a cycle, because the
crash landed right after the statement under test.

**How to apply:** end every test program with `END`. A `$ffff` dump after correct output is this
defect, not the feature being tested — rerun with `END` before reading any compiler code.

Related: [[headless-basl-build-recipe]], [[blitz-x16-basic-conformance]].
