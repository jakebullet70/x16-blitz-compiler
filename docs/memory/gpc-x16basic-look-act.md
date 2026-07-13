---
name: gpc-x16basic-look-act
description: How GPC-compiled programs are made to look + act like X16 BASIC (not Prog8) — stub rebrand + screen-preserving startup, with the no_sysinit/GC/float gotchas
metadata:
  node_type: memory
  type: project
  originSessionId: 481504f0-31d5-4658-a8c1-3b05e8802238
---

User requirement (2026-07-08): a GPC-compiled `.prg` must **look and act like X16 BASIC, not Prog8**.
Two independent fixes, both SHIPPED and corpus-green (262/262). See [[gpc-project]].

**LOOK — the BASIC stub.** A compiled program is `[runtime][pcode]`, so its first BASIC line was the
runtime's Prog8 launcher: `2026 SYS 2071 :REM PROG8` (line# = build year; REM PROG8 = Prog8's signature).
Fix: `debrand_stub()` in gpc.p8 `write_output` patches the runtime image (in scratch bank SRC_BANK0 at
BRAM+2) BEFORE writing out.prg: renumber the line to 10, and terminate the BASIC program right after the
SYS address (write `$00 $00 $00`, repoint the line link). Result LISTs as plain `10 SYS 2071`. The SYS
address + code are left byte-for-byte (nothing moves); the old ":REM PROG8" bytes fall after the end-of-
program marker so LIST never shows them and SYS jumps past them. Side effect: `scripts/entry-addr.sh` had
to be rewritten (od+awk: find the $9e SYS token, skip spaces, take digits until non-digit) because the new
`$00` terminator after the address made the old `od -c | tr -cd 0-9` grab a stray "0".

**ACT — don't reset the screen.** Prog8's `init_system` (run before `start()`) clears the screen and
recolors it **yellow-on-black + 80x60** (hardcoded CHROUT $90/$01/$9e/147 after `CINT`). Fix: `%option
no_sysinit` in BOTH gpc.p8 and vm_runtime.p8, then replay ONLY the KERNAL half in an `%asm` block at the
top of `start()`:
```
sei
jsr $ff84   ; IOINIT
jsr $ff8a   ; RESTOR
cli
```
Now the compiler + every compiled program leave the caller's screen mode/colors/content exactly as-is
(like a native X16 ML program). Verified in ref ROM that IOINIT does NOT touch the display (only
vera_wait_ready / clear_interrupt_sources / serial / entropy / VERA_IEN=1); `CINT` is what resets
mode+colors, and we skip it.

**TWO GOTCHAS that cost real debugging — DO NOT repeat:**
1. **Plain `no_sysinit` HANGS the ROM string GC.** Repeated concat (`A$=A$+"X"` in a loop) that triggers
   `garba2` hangs — this is the [[gpc-gating-requirement]] (ROM GC MUST work → no-go). `IOINIT`+`RESTOR`
   restore whatever KERNAL/I-O state the GC path needs; with them, GC + GC-stress pass.
2. **Do NOT add `stz $01` (ROM bank 0) to that block.** It breaks NUMBER/float printing: the VM's
   `print_float` calls ROM `FOUT` which lives in the **BASIC ROM (bank 4)**; leaving `$01` as BASIC left
   it (bank 4 on SYS entry) is required. Symptom of getting this wrong: strings print fine but `PRINT 42`
   produces nothing / mailbox 0, while GC works — a confusing split that points straight at the ROM bank.

**ACT (3) — no $9FBB debug-echo in shipped programs (2026-07-08).** The VM's `emit_char` mirrored every
printed byte to the x16emu debug register `$9FBB` (EMU_CHROUT) so the HEADLESS harness could capture
output — but it did so UNCONDITIONALLY, in every build, so shipped visual/standalone/interactive programs
poked `$9FBB` on every char (native BASIC never touches it; user noticed the compiled prg "printing to the
other window too"). Fix: `bool vm.host_echo = false` (default), guard the mirror `if host_echo`, and each
main sets `vm.host_echo = TESTBENCH` right before `vm.run` (vm_runtime/vm_selftest/gpc). Testbench builds
still echo (corpus intact); visual/standalone/interactive builds write ONLY to the screen (CHROUT).
Verified: a visual-runtime standalone run under `-testbench` produces NO host echo (it no longer writes
$9FBB at all), while the testbench build still does.

Net: compiled output LISTs as `10 SYS ..`, runs without disturbing the screen, doesn't poke emulator debug
registers, GC + float both intact. See also [[gpc-print-large-number-bug]] (same "run like BASIC" push).
