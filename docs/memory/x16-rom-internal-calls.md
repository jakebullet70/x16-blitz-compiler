---
name: x16-rom-internal-calls
description: "Verified R49 BASIC-ROM internal addresses/mechanisms for GPC (dispatcher, GC, ZP pointers)"
metadata: 
  node_type: memory
  type: reference
  originSessionId: 481504f0-31d5-4658-a8c1-3b05e8802238
---

Verified against R49 (source cloned to `X16-GPCompiler/ref/x16-rom`; addresses from the emulator's `C:\8bitProgramming\x16emu\basic.sym`, matching its `rom.bin`, MEMTOP=`$9F00`). BASIC lives in ROM **bank 4** (`$01=4` to page in). Confirmed working in spikes.

Statement dispatcher / pass-through: `newstt=$CC21`, `gone=$CC57`, `gone3=$CC63`, `gone2=$CC65`, `stmdsp=$C00E`, `igone` RAM vector `$0308`, `frmevl=$D350`. To run one tokenized statement: set TXTPTR, `jsr $00E7` (chrget), `jsr $CC63` (gone3); leaf/extension handlers RTS back (control-flow ones don't — GPC compiles those itself). X16 escape statements tokenize as `$CE $8x` (index into `stmdsp2`; e.g. VPOKE = `$CE $84`).

String GC: `getspa=$DC35` (ROM string allocator, auto-GCs on collision), `garbag=$DC5E`, `garba2=$DC70` (the collector; re-reads KERNAL MEMTOP `$FF99` and sets memsiz itself).

Zero-page / data pointers (note: X16 MOVED these out of ZP vs C64; the `;$xx` comments in `basic/declare.s` are stale C64 values): `chrget=$00E7`, `chrgot=$00ED`, `txtptr=$00EE`, `tempst=$00D6`, `frespc=$00E1`, `txttab=$00DF`; `temppt=$03DE`, `vartab=$03E1`, `arytab=$03E3`, `strend=$03E5`, `fretop=$03E7`, `memsiz=$03E9`, `curlin=$03EB`, `buf=$0200`. Set `curlin` to a real line (not `$FFxx`) to avoid direct-mode behavior. See [[gpc-gating-requirement]].
