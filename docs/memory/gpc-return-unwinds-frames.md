---
name: gpc-return-unwinds-frames
description: "GPC's RETURN closes every frame it passes on the way to the GOSUB frame, so RETURN out of a FOR, GP.DO or GP.SELECT is safe - GOTO is the one that needed .unwind"
metadata: 
  node_type: memory
  type: project
  originSessionId: 5591d6bc-636d-4001-b0b0-d858156d6ec0
  modified: 2026-08-31T13:50:34.861Z
---

**`RETURN` from inside a `FOR`, a `GP.DO` or a `GP.SELECT` does NOT leak the frame.**
`source/runtime/source/stack/frames.asm`:

```asm
StackFindFrame:
        sta  requiredFrame
_SFFLoop:
        lda  (runtimeStackPtr)      ; TOS
        cmp  #$FF                   ; empty stack = fail
        beq  SCFFail
        cmp  requiredFrame          ; found this type?
        beq  _SFFFound
        jsr  StackCloseFrame        ; close the top frame
        bra  _SFFLoop               ; and try the next
```

and `commands/gosub.asm` calls it with `#FRAME_GOSUB`, so `RETURN` **closes every frame
it walks past**. That file's own changelog says it outright: *"22/06/23 Uses FindFrame on
Return, so will throw any incomplete NEXTs."* Classic CBM BASIC 2.0 behaves the same way,
which is where the intuition comes from — and here it is genuinely implemented.

**This is exactly why `GOTO` needed separate work and `RETURN` did not.** `GOTO` does not
go through `StackFindFrame`, which is what `.unwind` was added for — see
[[gpb-goto-out-of-block-design]]. The rule that still holds is the narrow one in
`SELECT.EXP.BL`: *"Do NOT jump out of a select with GOTO ... GP.EXITDO out of a loop
containing one is fine, it cleans up on the way."*

**Measured, not just read**: `GP.EXITDO` from inside a `GP.CASE` was driven 600 times
through `kbdbuf_put` in `samples/editor`'s self-check, sized against the 4 KB frame stack
so that even a 7-byte selector leak would overflow before finishing. It does not leak.

Do not "fix" a `RETURN` inside a `FOR` in this tree — it is correct, and I asserted
otherwise and was corrected.

Related: [[gpb-goto-out-of-block-design]], [[gpc-blitz-runtime-slack-and-limits]].
