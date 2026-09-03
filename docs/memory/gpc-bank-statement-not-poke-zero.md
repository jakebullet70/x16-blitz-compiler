---
name: gpc-bank-statement-not-poke-zero
description: "GPC's PEEK/POKE save and restore the RAM bank around every access, so POKE 0 can never select a bank - the BANK statement is the only way"
metadata: 
  node_type: memory
  type: project
  originSessionId: 5591d6bc-636d-4001-b0b0-d858156d6ec0
  modified: 2026-08-31T13:49:13.201Z
---

**`POKE 0, n` cannot switch the RAM bank in a GPC program. Use `BANK n`.**

`source/runtime/source/system-specific/x16/interface/x16_peekpoke.asm` — every `PEEK`
and `POKE` does the same three steps:

```asm
ldy  SelectRAMBank      ; remember the current bank
ldx  ramBank            ; switch to the one BANK named, unless it is $FF
sta  (zTemp0)           ; the access
sty  SelectRAMBank      ; and put the old bank BACK
```

So a `POKE 0, 0` writes the bank register and then the *same instruction sequence* undoes
it one cycle later. `CommandBank` (`;; [!bank]`, spelled `BANK n` in BASIC) is what sets
`ramBank`; `$FF` means "don't switch at all", which is the default.

**The failure looks like reading the wrong memory, not like a banking error.** Hunting the
keyboard layout tables at `$A000` bank 0, every bank read *identically* and `$A670` came
back as `" the fiel"` — the editor's own document text, because the doc arena lives in
that same banked window and the bank never actually changed.

**It is documented in this tree already**, at the top of `samples/editor/STORE.BASL`:
"the runtime's PEEK/POKE honour the last BANK statement, so a banked access is
`BANK <bank> : PEEK/POKE $A000+<offset>`". Read that before inventing a mechanism.

`samples/editor` reserves bank 1..3 for its line table and 4+ for content, and it sets
`BANK` before *every* banked access — so **bank 0 is free to borrow** and nothing needs
restoring afterwards.

Related: [[gpc-editor-alt-keys-need-the-keymap]], [[gpc-blitz-runtime-slack-and-limits]].
