---
name: change-a-called-vector-with-one-poke
description: "The GPC runtime calls the KERNAL STOP vector ($0328) every 16 p-code words, so a vector changed by two POKEs crashes between them"
metadata:
  node_type: memory
  type: project
  originSessionId: f2ef33fe-6565-4754-b1b1-05111d41cf23
  modified: 2026-10-03T13:02:14.425Z
---

The GPC runtime polls STOP ($FFE1, through the ISTOP vector at $0328) once every 16 p-code
words. A program that repoints the vector with two POKEs leaves it half written between them,
and a poll there jumps into the ROM. TURBOTEST crashed into the monitor at startup this way
(PC $4949, SP $00) on 2026-10-03.

The fix in TURBO.BASL (TURBO.STOP.OFF): put the `LDA #$FF : RTS` stub at page 7 plus the
vector's current low byte, and POKE only the high byte. R49's ISTOP is $E170, so the stub is at
$0770. The page $05F0 to $07EF is free in both runtime links; GPBSTRBANKS sits at $07F0.

**Why:** Ctrl+C sends code 3, and the KERNAL raises its stop flag for code 3, so a program that
uses Ctrl+C as Copy must answer "no" to STOP or the runtime ends it with BREAK.

**How to apply:** any vector the runtime or an IRQ calls changes in one POKE, or in one
GP.ASM block. GPC-BASIC-TOOLS-SRC/edit/ED-MISC.BASL ED.APPSYS.STOPOFF still uses two POKEs
and has the same race. See [[turbo-gpc-ide-plan]].
