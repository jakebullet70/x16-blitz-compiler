---
name: scalar-variable-space-caps-at-4096
description: "FOUND 2026-09-20: a p-code variable operand holds 11 bits of a halved offset, so scalars past 4,096 bytes alias the first ones and a read past the wall compiles as a WRITE; GPBMODS is at 4,400; the compiler never checks"
metadata:
  type: project
---

The GPBMODS FILES-menu failure (BLOCK MISMATCH on row 1, screen garbage on row 4, the
monitor on row 5; Dialogs rows fine) is a **compiler limit with no check on it**.

`GetSetVariable` (`source/compiler/source/variables/readwrite.asm`) emits a scalar access as
two bytes: the variable's offset from the workspace start, HALVED, low byte second, and the
high byte of the halved offset ORed WHOLE into the opcode byte, whose low 3 bits are the
address bits and whose bit 3 is the write flag. The runtime's `.vaddress`
(`source/runtime/source/memory/support.inc`) takes the 3 bits back. So:

| scalar offset | what the operand says |
|---|---|
| 0 .. 4,095 | correct |
| 4,096 .. 4,607 | bit 3 set: a READ compiles as a WRITE, to offset minus 4,096 |
| 4,608 .. | bit 4 on too: another opcode altogether |

Slots are 2 bytes for `$` and `%`, 6 for a float, handed out in first-appearance order
(`storage/create.asm`), and nothing in `create.asm` or `compiler.asm` compares
`freeVariableMemory` with 4,096. The figure is written into the object's `.varspace`
prologue (opcode `$E7`, offset 513 of a SHARED PRG); GPBMODS reads `$1130` = **4,400**.

**Why it looked like anything else:** the last ~300 bytes of variables are the ones first
seen late in the source, which is the FILES section; which early variable each one lands on
depends on the order, so one added reference (round 12's `[FT]` print in low code, which
moved `GM.FTITLE$` under the wall) made the fault vanish, and each FILES row hit a different
victim. Sixteen probe rounds went into string heap, frame stack, regions, banks and GP.ASM
before the operand encoding was read.

**How to apply:** a program that misbehaves only in its late-written code, with symptoms that
move when unrelated code is edited, is at this wall: read `$E7`'s operand from the PRG first.
The fix is the user's call between a compile-time check (asm, [[ask-before-writing-asm]]),
a wider operand, and trimming GPBMODS's scalars (its floats: [[int16-conversion-planned]]).
[[compiler-must-not-cap-program-size]] says the wall itself is the bug. Related:
[[program-too-big-fires-early]], [[file-io-error-in-gpdo-key-loop]] (same signature, unresolved).

**2026-09-20, the check is built.** `AllocateBytesForType` now tests the running total
against `MaxVariableSpace = 4096` at each allocation and raises TOO MANY VARIABLES, naming
the line where the variable that went over is first used. The message sits in compiler
space, not `errors.asm`, so it costs compiled programs nothing. Clean GPBMODS is refused at
BASIC 3888. Its measured varspace is **4,322**, and [[every-scalar-allocated-six-bytes]] is why.
