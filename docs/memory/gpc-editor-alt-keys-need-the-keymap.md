---
name: gpc-editor-alt-keys-need-the-keymap
description: "In ISO mode ALT+letter gives an accented char or nothing at all, so menu accelerators must be made by rewriting the keyboard layout table, not by decoding a key code"
metadata: 
  node_type: memory
  type: project
  originSessionId: 5591d6bc-636d-4001-b0b0-d858156d6ec0
  modified: 2026-08-31T13:49:34.085Z
---

**Built 2026-08-31.** In ISO mode the X16 keyboard driver returns ISO-8859-15, and
**ALT+letter cannot be decoded from the character**:

- **ALT+S arrives as 223** (`ß` — the ISO ALT table remaps it)
- **ALT+F arrives as nothing at all** — its slot in that table is empty, so no keystroke
  is generated and there is nothing to inspect

`kbdbuf_get_modifiers` (**`$FEC0`**, bit 1 = Alt, bit 0 Shift, bit 2 Ctrl) reliably says
ALT was held, but it cannot say *which key* — and for an unmapped letter there is no key
event to attach it to. Reading modifiers alone is **not** enough.

**The fix is to rewrite the layout.** Tables live in banked RAM at `$A000`, **bank 0** —
eleven of 128 bytes, byte 0 an ID, bytes 1..127 the code each *keynum* produces.
ID `$80` = ISO unmodified, `$C6` = ISO+Alt (`$FF` = empty). Measured IDs on ROM R49:
`0 1 4 6 2 128 129 132 198 199 255`, so plain sits at `41600` and ALT at `41984`.

Find the menu's initial in the **plain** table — the index it sits at *is* that key's
keynum — then write the upper-case letter into the same index of the ALT table. Doing it
by **search rather than a hardcoded keynum** means it works for any loaded layout and
follows the menu names: rename a menu and its accelerator moves with it. Save every
overwritten byte and restore on exit; the layout outlives the program.

**Reach it with `BANK 0`, never `POKE 0`** — see [[gpc-bank-statement-not-poke-zero]],
which is what made this look impossible for several builds.

**The old PETSCII path is dead and worth deleting where it survives.** Commodore+letter
used to arrive as `161..191`; the driver stops sending those the moment the ISO flag goes
in, and a leftover `IF KEY >= 161 AND KEY <= 191` *swallows* every ISO character in that
range instead of typing it.

**No headless test can press ALT** — `kbdbuf_put` fills the buffer but sets no modifiers —
so assert on what is readable instead: which tables were found and how many keys were
rewritten (`ALTKEYS N= 3 PLAIN= 41600 ALT= 41984`), and have the program print the raw
key and modifier bytes when ALT matches nothing.

Related: [[gpc-editor-is-ascii-inside-petscii-outside]], [[menuhelp-use-the-whole-interface]].
