---
name: prog8-petscii-charlits
description: "Prog8 cx16 char literals are PETSCII, so 'a'..'z' = $C1..$DA and is_alpha() misfires on token bytes"
metadata: 
  node_type: memory
  type: reference
  originSessionId: 481504f0-31d5-4658-a8c1-3b05e8802238
---

**Prog8 (`-target cx16`) char literals are PETSCII, not ASCII.** `'A'..'Z'` = `$41..$5A` (as ASCII), but **`'a'..'z'` = `$C1..$DA`** (PETSCII shifted letters), NOT `$61..$7A`.

Consequence for GPC's byte-classification helpers (see [[gpc-project]]): a naive `is_alpha(c) = (c>='A' and c<='Z') or (c>='a' and c<='z')` returns **true for high token bytes** in `$C1..$DA` — e.g. `$CE` (the X16 `$CE`-escape prefix used by VPOKE/VPEEK/etc.). This bit `parse_passthru` on 2026-07-08: scanning a tokenized statement for variable names, `is_alpha($CE)` was true, so the VPOKE opcode byte itself got interned as a bogus variable and the VM crashed.

**Rule:** when scanning tokenized BASIC (bytes are either `>= $80` tokens or ASCII text), guard `c >= $80 -> treat as a token, never a variable/letter` BEFORE any `is_alpha`/letter-range test. The normal lexer avoids this because it dispatches `>= $80` bytes via `map_token`/`func_id` before reaching `is_alpha`; only ad-hoc scanners (like the pass-through variable substitutor) are exposed. **How to apply:** any new byte-classification over tokenized input in `gpc.p8` must exclude `>= $80` first.
