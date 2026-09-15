---
name: runtime-storage-is-golden-ram
description: "The runtime's storage section is $0400-$05F4, the X16's golden RAM -- a test routine POKEd at $0400 corrupts a compiled program; use $0780"
metadata:
  type: reference
---

The runtime links its `storage` section at `MemoryStorage`, `$0400`, and it ends at `StorageEnd`
(`$05F4` at runtime 123, in both `source/application/build/rtimage.lbl` and
`source/runtime/build/code.lbl`). The compiler's own ends at `$0678`. `storeStartHigh`,
`stackFloorHigh`, `Runtime6502SP` and `handlerBank` live there, so the X16's usual free "golden RAM"
is not free under a compiled program.

A 6-byte bank probe POKEd at `$0400` on 2026-09-15 overwrote `stackFloorHigh`: the next `FOR` stopped
with `OUT OF MEMORY` at a nonsense address, in build 122 as well, and a probe called by `SYS` from direct
mode was overwritten while it ran and dropped into the monitor (`B*`). `$0780`-`$07FF` is free in every
link.

A direct-mode line pasted with `-bas` holds 80 characters: four `POKE nnnn,nnn` statements, not six.
A longer line is `?SYNTAX ERROR` and writes nothing.

**How to apply:** check `StorageEnd` in the label file before putting test code or data below `$0801`.
See [[tests-share-the-products-memory]] and [[kernal-preserves-ram-bank]].
