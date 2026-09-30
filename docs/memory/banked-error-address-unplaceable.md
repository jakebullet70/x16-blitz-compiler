---
name: banked-error-address-unplaceable
description: "Runtime build 128 prints a GP.BANKED region error as $bb:AAAA and the map writes region lines the same way; before 128 such an error printed $96xx and GPC.ERR named the wrong line"
metadata:
  node_type: memory
  type: project
  originSessionId: 6cb2a824-c1cb-47e0-8336-85f9918b1083
  modified: 2026-09-30T08:59:46.320Z
---

Fixed 2026-09-30 as runtime build 128, on the user's go-ahead ("lets do a 128, fix it right").

- **Runtime** (`source/runtime/source/errors/errorhandler.asm`): p-code at `$A000` up prints as
  the selected bank, a colon and the run address, `DIVIDE BY ZERO @ $14:A048`. Low code still prints
  the offset from the p-code base. `SelectRAMBank` is trusted as the region's bank; the bank-1
  handler case is put back first.
- **Core cushion**: the change cost 9 bytes net (the `" @ $"` print became a 4-byte table loop and
  `EHDisplayCodePtr` was inlined). `FloatIsZero` now ends at `$2FF6`, 10 bytes below `GPBase $3000`.
- **Map** (`WriteMapFile`, `object.asm`): region lines are written `14:A043 10`, found by searching
  `layoutStart` from the top, with the bank from `gpBankBanks`. Low lines stay `0143 10`.
- **Probe** `BNKERR` (scratch, bank 20 region, divide by zero on line 10): shared and embedded both
  printed `$14:A048`, the map has `14:A043 10`. A low-code error printed `$003B`, line 18, correct.
- **GPC.ERR** parses `bb:` in the address and matches records by bank. Verified with a fixed-answer
  variant on the GPC.HELP map: `$0C:AAF4` gives line 1000, `$027E` line 1669, `$05:A000` reports no
  region in that bank. An address past a region's last record is counted into that line.

A failed `BLOAD` with a bank argument inside a region leaves the load bank selected, so the printed
bank would be wrong there; a region is not refused `BLOAD`. Related: [[region-overlay-ovl-file]],
[[gpc-core-page-cushion-below-gpbase]].
