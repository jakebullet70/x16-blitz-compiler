---
name: gpc-psgvol-fmvol-inverted
description: "GPC's PSGVOL and FMVOL passed the volume straight to the audio ROM's attenuation call, so 0 was full volume; FIXED in runtime build 130 on 2026-10-01"
metadata:
  type: project
---

Found 2026-10-01 when LANDER64's exit left its noise on. FIXED the same day in runtime build 130.

ROM BASIC's `PSGVOL` and `FMVOL` take a volume, 0 silent and 63 full. R49's BASIC bank turns it
into an attenuation before the audio call (disassembled from `bin/x16emu/rom.bin`, bank 4):
- `psgvol` ($ED5F): `eor #$3F`, then `psg_setatten`.
- `fmvol` ($ECB6): 0 becomes $40 first, then `eor #$3F`, so 0 is $7F (muted, the YM range is
  0-127) and any other volume is 63 - volume. Then `ym_setatten`.

GPC's generator (`source/compiler/scripts/genx16.py`) passed the value through unchanged, so
`PSGVOL 0,0` meant full volume. The setup codes `AXV` and `AXF` now emit the two conversions.

**Trap:** `psg_init` silences the voices, but `PSGFREQ` and `PSGNOTE` turn a voice on at full
volume less its attenuation. Under the old runtime, `PSGVOL v,0` after either one played at full
volume.

**Trap:** a genx16.py edit needs `make libs` twice. `source/Makefile` builds `runtime` before
`compiler`, and genx16.py runs in the compiler's prelim, writing the runtime's
`generated/x16_sound.asm`. After one pass, `GP1.RT` had the fix through `gpc-rt`, but
`GP1.IMG.130.BIN` was byte-identical to 129, so EMBEDDED objects would have kept the old handler.

**How to apply:** an object compiled at build 129 or earlier keeps the inverted volume until it
is recompiled. Related: [[gpc-joy-high-byte-diverges]], [[blitz-x16-basic-conformance]].
