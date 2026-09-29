---
name: x16-interpreter-load-chain-is-safe
description: "X16 R49 interpreter: a program-mode LOAD of a LONGER program runs it clean -- VARTAB moves to the new end, unlike the C64 chain bug. Measured 2026-09-29."
metadata:
  node_type: memory
  type: reference
  originSessionId: ea1eda60-28bc-453e-9476-7660f53eb8a0
  modified: 2026-09-29T08:50:01.925Z
---

**On R49, `LOAD name,8` inside a running interpreted program is safe for any size.** Measured
2026-09-29 by the BASLOAD-GPC front end's `.BASLOAD.NEXT` chain: a 1,147-byte program loaded a
4,807-byte one, which did `DIM A(800)`, filled it, jumped past 60 padding lines and summed it
correctly (320400). On a C64 the array would have landed on the new program's own text, because
program-mode LOAD there leaves VARTAB at the old program's end.

The harness is not in the repo. It typed the long program in and `SAVE`d it, tokenised a
fixed-answer front end with the engine, and ran it. Rebuild it from `BASLOAD-GPC/test/runfront.py`.

**The same handover from machine code inside a SYS** (R49 `cld70` in basic/code26.s): KERNAL LOAD
to `txttab`, store X/Y in `vartab`, then with ROM bank 4 `jsr stxtpt`, `jsr lnkprg`, `jsr cleart`
(its `stkini` empties the stack under the return), `jmp newstt`. `BASLOAD-GPC.BIN`'s `chain_next`
does this for `.BASLOAD.NEXT`, measured working 2026-09-29.

The compiled runtime's chain is a separate mechanism: [[load-chain-clears-memory]].
