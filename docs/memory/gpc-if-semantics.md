---
name: gpc-if-semantics
description: GPC IF/THEN matches CBM V2 -- false IF skips the whole rest of the LINE; verified against the real X16 ROM source
metadata:
  node_type: memory
  type: project
  originSessionId: 481504f0-31d5-4658-a8c1-3b05e8802238
---

**GPC `IF` now matches CBM/X16 BASIC V2 line semantics (2026-07-09, branch `if-line-semantics`, commit 2c2ef1b).**
A FALSE `IF` skips the ENTIRE rest of the line (every colon-separated statement after THEN), not just the first.

**Verified against the real ROM, not memory:** the X16 ROM BASIC source is checked out at `ref/x16-rom/` (a local
clone, now gitignored -- do NOT `git add -A` it; it's an embedded repo). The IF handler is `ref/x16-rom/basic/code5.s`
label `if`: `jsr frmevl` (eval cond) -> require THEN/GOTO -> `lda facexp` (0 == false) -> `bne docond` (true: run rest
via `gone3`); on FALSE it falls to `rem: jsr remn` -- the SAME REM skip-to-end-of-line routine -- then `addon` (next
line). So false => skip to `$00` end of line. **Technique: read `ref/x16-rom/*` to settle "how does X16 BASIC really
behave" questions authoritatively instead of guessing.**

**GPC before:** each guard JZ was backpatched to end-of-BODY (one statement), so `IF 0 THEN A=1:A=2` still ran A=2
(empirically 2, should be 5). **Fix:** parse_if no longer backpatches locally; each guard's JZ/IJZ operand slot is
appended to a per-LINE module list `if_line_patch[MAXIFLINE=16]` (count `n_if_line`, reset per line), and the line loop
backpatches them ALL to end-of-line (`code_len` at line break = start of next line). This composes colon-separated IFs
correctly (`IF a THEN.. : IF b THEN..` -- each is a fresh parse_if that appends more guards to the same EOL target, so
NO recursion needed, Prog8 has none) and keeps nested `IF a THEN IF b` (the guard-chain `repeat` loop in parse_if)
working. GOTCHA: `for gi in 0 to n_if_line-1` underflows (ubyte 0-1=255) when n_if_line==0 -- guard with `n_if_line != 0`.

Supersedes the earlier "nested IF" note's local-backpatch description in [[gpc-project]]. Related: [[gpc-inc2-design]]
(IJZ/JZ opcodes), [[gpc-runtime-asm-conversion]].
