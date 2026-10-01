---
name: gpc-joy-high-byte-diverges
description: "GPC's JOY(n) put the A, X, L and R buttons 4 bits higher than ROM BASIC; FIXED in runtime build 129 on 2026-10-01"
metadata:
  type: project
---

Found 2026-10-01 while porting LANDER64. FIXED the same day in runtime build 129.

ROM BASIC's `JOY(n)` is a 12-bit field: A $800, X $400, L $200, R $100, then B $80 down to
RIGHT $01 (docs/x16 BASIC reference). GPC's runtime
(`source/runtime/source/system-specific/x16/unary/joy.asm`) inverted the two `joystick_get` bytes
and returned them unshifted, so A came back as $8000, X $4000, L $2000, R $1000. Four `lsr a`
after the high byte's `eor #$FF` now move them to bits 3-0, matching ROM. Runtime +4 bytes.

**How to apply:** an object compiled at build 128 or earlier still has the old JOY. EMBEDDED
objects carry it until recompiled. Related: [[blitz-x16-basic-conformance]],
[[user-runs-demos-broken-by-build-127]].
