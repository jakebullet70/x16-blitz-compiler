---
name: binput-caps-at-255-bytes
description: A BINPUT# read can never exceed 255 bytes, for three separate reasons, and it is a CHRIN loop rather than a block read
metadata:
  node_type: memory
  type: reference
---

**`BINPUT# <n>,<var$>,<len>` cannot read more than 255 bytes.** Read out of the runtime on
2026-09-08, not inferred. Three independent caps land on the same number, so there is no single
constant to raise:

1. **The buffer is 255 bytes.** `source/runtime/source/commands/read.asm` -- `ReadBuffer: .fill 255`,
   with `ReadBufferSize` one byte in front of it.
2. **The count argument is 8 bit and unchecked.** `CommandXBinput` in
   `source/runtime/source/system-specific/x16/commands/linput.asm` does
   `jsr GetInteger8Bit : sta liCount`, and `GetInteger8Bit`
   (`source/runtime/source/support/integers.asm`) is three instructions -- it takes mantissa byte 0
   and returns. **`BINPUT# 12, A$, 256` sets the count to 0 and hands back an empty string,
   silently.** 300 gives 44 bytes.
3. **A BASIC string is 255 characters**, so there is nowhere to put a longer record even if the read
   cooperated. This is the one that cannot be raised without touching every string operation in the
   compiler and runtime.

**IT IS NOT A BLOCK READ.** `CommandXBinput` is an `X16_CHRIN` loop, one KERNAL call per byte, with
an EOF check per byte on top. `BINPUT#` is one *statement*, not one transfer. Anything costing a
`BINPUT#` per record is paying stride KERNAL calls per record, which is the thing `MACPTR` exists to
avoid -- see [[macptr-wraps-banks-itself]].

`LINPUT#` shares the same buffer and stops at 255 too, but runs on to the delimiter afterwards so
the next read starts at a line boundary.

**The consequence for anything record shaped:** a record cannot be one string. It is N strings of
255, or it lives in a bank and something copies it out. See [[xbase-engine-planned]], where this
forced the design.

Related: [[gpc-string-blocks-never-shrink]], [[gp-strptr-points-at-the-length-byte]].
