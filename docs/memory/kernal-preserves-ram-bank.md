---
name: kernal-preserves-ram-bank
description: "Measured R49: CHROUT, GETIN, a screen scroll, CLS and screen_mode all leave $00 as they found it -- the gate banked p-code had to pass"
metadata: 
  node_type: memory
  type: project
  originSessionId: 75714395-f705-4d27-8da6-af4a832a1e0b
  modified: 2026-09-05T14:27:25.560Z
---

**Measured on x16emu R49, 2026-09-05.** `BANK 5`, then a `GP.ASM` blob reading the live `$00` after
each call. Every one came back **5**:

| after | `$00` |
|---|---|
| nothing (baseline) | 5 |
| `PRINT` — `CHROUT` | 5 |
| `GET` — `GETIN` | 5 |
| 40 `PRINT`s, so the screen editor scrolls | 5 |
| `GP.FILL` + `GP.PRINTAT` — VERA direct, no KERNAL | 5 |
| `CLS` | 5 |
| `GP.CALL $FF5F` — `screen_mode`, carry set | 5 |

**Why it mattered:** code fetched from `$A000-$BFFF` cannot be running when `$00` changes, and
`PRINT` and `GET` are on every path of every GUI module. A KERNAL call that moved the bank and did
not restore it would have killed banked p-code outright, or forced a wrapper round every call.
It does not. See [[gpc-bank-statement-not-poke-zero]].

**IT HAS TO BE MEASURED IN ASSEMBLY.** GPC's `PEEK`/`POKE` save `$00`, select `ramBank`, access,
and restore (`x16_peekpoke.asm`), so they always report the bank they were told to use and can
never see the hardware one. `PEEK(0)` returns `ramBank`, not the register. Only a `GP.ASM` blob,
which runs with the live register, can answer this — the first probe that tries it with `PEEK` will
pass regardless and prove nothing.

The X16 reference's remark that `$01` always reads back `4` and that a program should track its own
bank in variables is about the ROM bank and about not relying on read-back; it is not a statement
that the KERNAL clobbers `$00`.

Related: [[x16-rom-internal-calls]], [[stash-leaves-its-bank-selected]] (a case that does NOT
restore, and is ours, not the KERNAL's).
