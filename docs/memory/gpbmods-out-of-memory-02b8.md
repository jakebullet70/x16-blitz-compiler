---
name: gpbmods-out-of-memory-02b8
description: GPBMODS "OUT OF MEMORY @ $02B8" is one corrupted zero-page byte, and the ruled-out list
metadata:
  type: project
---

GPBMODS built with the uncommitted compiler raises `OUT OF MEMORY @ $02B8` at startup, on
2026-09-17. The evidence points at the runtime, not at code generation.

**What fails.** The statement is `GOSUB APPSYS.STARTUP`, `GPC-BASIC-TOOLS-SRC/GPB-MODS-TESTING/GPBMODS.BASL`
line 204, BASIC line 2057, p-code `F5 B3 9A 07`. It is the program's first GOSUB, straight after
eight DIM statements. A ring recorder in `StackOpenFrame`/`StackCloseFrame` left its index at a
value the recorder cannot write, so no frame operation ran before this one: this is the first
frame push of the whole run.

**The damage is a single byte.** At the error, zero page reads `zsTemp $0000`,
`runtimeStackPtr $01FA`, `availableMemory $40E0`, `codePtr $0CB8`, `objPtr $0A00`,
`zTemp0 $92ED`. Only `$25` is wrong: `$01` where `$3E` belongs. `$24` holds `$FA`, which is the
correct `$FF - 5` for a `.bgosub` frame, so `StackOpenFrame` computed the low byte properly and
then compared a high byte that was already `$01` against `stackFloorHigh $37`. The duff marker at
`$3EFF` still read `$FF`, so `ResetRuntimeStack` ran correctly and the byte was destroyed after it.

**Zero page map, from `source/runtime/build/code.lbl`.** `$22 zsTemp`, `$24 runtimeStackPtr`,
`$26 availableMemory`, `$28 codePtr`, `$2A objPtr`, `$2C/$2E/$30 zTemp0-2`, then five twelve-byte
arrays: `NSStatus $32`, `NSMantissa0 $3E`, `NSMantissa1 $4A`, `NSMantissa2 $56`,
`NSMantissa3 $62`, `NSExponent $6E`. `NSSIInt16 = $20` and `NSSString`/`NSSTypeMask = $40` are
status bit constants, not addresses -- do not read them as a zero page map.

**Ruled out.** A wrong `storeStartHigh`; a runaway `StackFindFrame` walk (a `$00` marker adds zero
and hangs, so it cannot climb); any symbol-level write to `$24`/`$25` (eight exist in the whole
image, all legitimate); a low-RAM call into bank 1 address space; a zero page symbol aliasing
`$25`; an indexed store reaching `$25` (every NS base needs X between `$B7` and `$F3`, against a
legal range of 0 to 11); a store through `zsTemp` (none exists); ordering in `StartRuntime`;
`RestoreCode`; `XRuntimeSetup`; a mid-run CLR; a missing `.entercmd` on the `.fnpush` handler.
Recompiling GPBMODS gives a byte-identical PRG and OVL, so the object file under test is sound.

**Why the runtime and not the compiler.** The failure is layout sensitive. GPB.RT sizes 11951,
11971, 11980, 11994 and 12086 all reproduce it; 11981 and 12127 do not. Ten bytes inserted at
`NXDispatch` made it vanish, and in that build the program ran to its end with
`runtimeStackPtr` at `$0000`. Code generation cannot care where the runtime's own code sits; a
memory overwrite can. Only instrumentation confined to `errorhandler.asm`, late in the image,
preserves the repro.

The repro harness is `source/scratch/oomprobe/` -- the PRG, the OVL, the three `.RT.123.BIN`, driver text
files and `probeh.py`, which runs x16emu warped with 2048K and stops on `DONEB`.

**Second pass, 2026-09-17.** A clean build (GPB.RT 11909) reproduces. Earlier "no repro" readings
came from `tail` on the probe log: `DONEB` prints after an error too, so grep the log for
`ERROR|OUT OF MEMORY|@ \$` instead. The sensitive window is `[$7769, $7be6)`: bytes added at
`RuntimeErrorHandler` ($7be6) or later keep the repro, bytes added at `NXDispatch` ($7769) kill it.
`CommandXDIM`, `DIMCreateOneLevel`, `DIMWriteElement` and `DIMWriteByte` ($7ae4-$7bd5) sit inside it.

A watch that costs the window nothing: `lda #16` to `lda #1` at `NXBreakCheck` (same size),
`breakCount = 1` in `XRuntimeSetup`, and a range check on `runtimeStackPtr+1` against
`stackFloorHigh`/`storeStartHigh` at the top of `XCheckStop` ($8f8e) raising `.error_structure`
(prints MISMATCH). It runs before every p-code word. In that build the startup fault does not
happen, but the watch fires `MISMATCH @ $28FA`: `codePtr` after the `.goto` into the compiler's
DIM prologue (MAP lines 65024 and 65535), so the byte is hit inside the prologue's first 128 bytes,
which are `push 10, push 1, .byte 64, DIM, write-int`. The 11981 build's "end at $28FD" was the
same event. In the reproducing layout the two words before the faulting GOSUB are also DIMs
($02AA, $02B3). DIM is the prime suspect; every DIM seen is single-index (n=1), so the recursive
`(zTemp1)` writes in `DIMCreateOneLevel` never run and the exact store is still unidentified.
`$01` matches the high byte of the array block offset (`$40E0 - $3F00 = $01E0`) that DIM returns
in Y. Next: decode the prologue with `pcodesize.asm` operand widths, then trap inside DIM without
adding bytes to the window (repoint the shift-table `dim` vector, 2 bytes, at a late shim).

## Root cause, 2026-09-17

Found by snapshotting SP, Y, `runtimeStackPtr` and `codePtr` into golden RAM at every p-code word
(the no-shift watch above, with `breakCount = 1` so the check runs before every word) and printing
them from BASIC after the error. The last good check was at p-code `$28FA`, Y=4: the first word
of the prologue. The bad one was one word later, with `$25 = $0A`. The word between is `push 10`.

`StartRuntime` never initialises X, the numeric stack index. The last thing to set X before the
run loop is `ldx #RuntimeErrorHandler & $FF` for `SetErrorHandler`, and in the build under test
`RuntimeErrorHandler` sits at `$7BE6`, so the program starts with X = `$E6`. `PushByteA` does
`inx` then `sta NSMantissa0,x`; `NSMantissa0` is zero page `$3E`, zero-page indexing wraps, and
`$3E + $E7` lands on `$25`, the high byte of `runtimeStackPtr`. The next pushes hit `$26/$27`
(`availableMemory`), DIM then reads its arguments from the same wreckage, and the prologue's
`.goto` lands on a `new.line` (`$B8`), which does `ldx #$FF` and puts everything back except
the bytes already written. `runtimeStackPtr` stays wrong until the first GOSUB, whose floor
check raises OUT OF MEMORY at `$02B8`.

Every ordinary line starts with `new.line`, which is why a garbage X at start never mattered
before: the first line reset it. The implicit-DIM prologue is the first code the compiler has
ever emitted that pushes before any `new.line` runs. That is also the whole of the layout
sensitivity: bytes added before `RuntimeErrorHandler` change its low byte, X starts somewhere
else, and the wrapped stores land on bytes nobody reads.

Fixed 2026-09-17 in the runtime: `ldx #$FF` in `StartRuntime` before the run loop
(two bytes; the runtime should start with an empty numeric stack whatever the compiler emits),
now in `source/runtime/source/main/00runtime.asm`, after the `ldy #0`. GPB.RT went 11,909 to
11,911 bytes. GPBMODS then loads and runs with no error; before the fix the same PRG raised
OUT OF MEMORY within a second of RUN.
The compiler could also open the prologue with `new.line`, but the runtime invariant is the one
worth owning.

See [[banks-work-in-progress]], [[region-overlay-ovl-file]],
[[gp-bankedstr-literal-text-in-a-bank]].
