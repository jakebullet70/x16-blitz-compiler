---
name: gp-strptr-points-at-the-length-byte
description: "GP.STRPTR returns the address of a string's LENGTH byte; the characters start at +1"
metadata:
  type: reference
---

**`GP.STRPTR(A$)` points at the LENGTH BYTE, not at the first character.** The text runs from
**+1**. `STRCASE.INC.BL` says so where it sets its pointer up -- "zTemp0 -> the length byte, text
from +1" -- and its own trim walks DOWN to offset 0 to reach the length.

**A blob that forgets the +1 fails in a way that hides itself.** It stores each string one byte
early: the length as the first character, and the last character lost. Checking the first byte of
every stored line flagged only **14%** of them, because a length of 32 to 126 IS a printable
character and reads as ordinary text -- so the short lines look corrupt and everything else looks
fine. Cost a debugging cycle on 04/09/26 in `HELP.STORE.ASM`.

**The tell, if it happens again:** the first byte of the stored data equals its length. `W 19, B 19`
/ `W 30, B 30` in a dump is this bug and nothing else.

See [[gpasm-blob-may-use-ztemp]] for the zero page a blob may use, and
[[gpasm-implementation-status]] for `{VAR}` syntax -- note `LDA {V%},X` with `X=1` is how the high
byte of a 16-bit variable is read, not `{V%}+1`.
