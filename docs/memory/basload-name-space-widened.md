---
name: basload-name-space-widened
description: "BASLOAD crunches every identifier to 2 chars; the space was ~950 names and GPBMODS hit it 2026-10-03; widened to first chars A-Z plus [ \\ ] ^ _"
metadata:
  node_type: memory
  type: project
  originSessionId: f2ef33fe-6565-4754-b1b1-05111d41cf23
  modified: 2026-10-06T08:53:48.845Z
---

BASLOAD crunches every variable, GP.DEFPROC verb and GP.BANKEDSTR group name to one or two
characters. Labels do not count. The space was 26 first characters times 37 seconds, minus
the reserved pairs: about 950 names. On 2026-10-03 GPBMODS reached 968 and stopped with
SYNTAX ERROR @ 4899.

Two faults were behind it. BASLOAD's out-of-names check ran only when a label was added, so
variables ran on past Z into `[` with no error. The compiler took A to Z only as a name's
first character.

Fixed the same day, with the user's go-ahead for the asm:
- The compiler accepts `[ \ ] ^ _` as a first character too, through `CharIsNameStart` in
  `helpers/get.asm`. That gives about 1,135 names.
- BASLOAD stops with OUT OF VARIABLE NAMES after `_Z`. The fix is in
  `BASLOAD-GPC/src/symbol.inc`. `build/stock` stays pristine upstream.

A program using these names does not run in ROM BASIC.

**Why:** GPBMODS sat at the limit, and TURBO's measuring build had 885 names before its menu
and picker landed.

**TURBO hit the new cap on 2026-10-06.** The Custom theme work stopped BASLOAD with OUT OF
VARIABLE NAMES; trimmed, TURBO uses 1,132 of 1,135. Every new TURBO variable now needs one
freed. `#DEFINE` constants and labels cost no name.

**One pool per kind, 2026-10-06 (option A, user's go-ahead).** BASLOAD-GPC keys a variable by its
name plus the sigil and `(` it was written with, and each of the six kinds (N, N%, N$, N(, N%(, N$()
takes names from its own pool of about 1,135. GPC already keeps the six apart by type bits. The SYM
file now records `PR$(` not `PR`, and GP.ASM `{VAR}` appends the sigil before its lookup
(gpasmcode.asm). TI$ and DA$ are reserved keys. Trap: `N% (1)` with a space is a scalar's key.

**How to apply:** when a GPC build fails with a SYNTAX ERROR on an innocent line, count the
distinct crunched names in the SYM before blaming the source. A refused expression is
deferred to a runtime stub. A block opener is not deferred, so the compile stops there. See
[[retired-keyword-defers-to-runtime]] and [[compiler-must-not-cap-program-size]].
