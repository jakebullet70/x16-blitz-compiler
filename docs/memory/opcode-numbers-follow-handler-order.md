---
name: opcode-numbers-follow-handler-order
description: Command p-code opcodes are numbered in the order of the ;; markers across the runtime sources, so moving a handler renumbers opcodes
metadata:
  type: project
---

`pcode.py` gives each command its opcode in the order `getRuntimeASMFiles()` meets its `;; [name]`
marker: runtime/ and gp-runtime/ in one sorted file order, then line order. Moving a handler above
another renumbers every opcode between them. `pcodeconst.py` (compiler) and `vectors.py` (runtime)
read the same order, so a full `make` stays consistent; a runtime or compiler built alone does not,
and old objects break. Seen 2026-09-15: HANDLER-BANK step 12's reorder renumbered 10 opcodes (CHAR,
PSET to RING, MOVSPR, SPRITE, SPRMEM), visible only in the regenerated `vectors.asm`.

**Why:** the renumbering does not show in the diff of the handler file.
**How to apply:** to split a file's code across sections, open a section per handler rather than
reorder. If handlers must move, change `RT_ABI` and rebuild the compiler and runtime together. See
[[banks-work-in-progress]].
