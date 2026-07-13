---
name: gpc-x16-basic-coverage
description: what GPC can/can't compile vs real X16 BASIC — lexer gaps (fixed) + remaining function gaps
metadata:
  type: project
---

A docs-driven audit (docs/x16/X16 Reference - 04 - BASIC.md vs gpc.p8, workflow x16-basic-gap-audit)
mapped where GPC fails on VALID ordinary X16 BASIC. Key framing: GPC's statement coverage is broad
because any unrecognized keyword-first statement becomes OP_PASSTHRU and is run by ROM BASIC at
runtime (parse_statement else-arm) — so CLS/COLOR/sound/sprites/VERA-graphics all effectively work.
The real gaps are only (a) the LEXER and (b) expression-position FUNCTIONS (which can't pass through,
being inside compiled expressions).

**7 lexer blockers — ALL FIXED (commit 36fb6e3), all in next_token():**
1. hex literals `$FF`/`$A000` — were ?SYNTAX ERROR. (single highest-impact: POKE/SYS/VPOKE addrs)
2. binary literals `%1010` — a leading `%` is a literal; the `A%` int-var SUFFIX is separate/unaffected.
3. leading-dot floats `.5`/`.01`.
4. decimal >= 65536 — SILENTLY WRAPPED mod 65536 (1000000 -> 16960); now routes to the float path.
5. scientific notation `9.2E5`.
6. identifiers > 7 chars — split into two tokens; now the over-long tail is drained (NAMELEN-1=7 significant).
7. reversed relationals `=< => ><` — CBM/X16 folds `< = >` in ANY order; all six orderings now recombine.
Hex/binary emit an ordinary T_NUM (reuse the existing literal path; works in full AND noint builds).
Added is_hexdigit/hexval. Tests: test.sh "M2b" block. NOTE: PRINT of a value >32767 leaves the
mailbox 0 by design (op_printi), so assert those via printed output, not the mailbox.

**4 common function/statement gaps — ALL FIXED (commit 8277fca):**
- `MOD(a,b)` — an X16 two-arg numeric function ($CE $DE). Just added $DE to is_xfunc: it rides the
  existing OP_CALLX/frmevl path (ROM evaluates it). This also FIXED a latent OP_CALLX bug for EVERY
  xfunc: a negative arg's sign was formatted as raw ASCII '-', which frmevl (reads TOKENS) can't parse
  as unary minus → it wedged. xbuild now emits the tokenized MINUS ($AB); the doc example MOD(-17,5) works.
- `TAB(` / `SPC(` — PRINT-context cursor control. New UNIVERSAL opcodes OP_TAB (93) / OP_SPC (94);
  handled in print_items via parse_index (the '(' is baked into the $A3/$A6 token). TAB reads the live
  cursor column via KERNAL PLOT ($FFF0); both take a 0..255 byte arg (clamp_byte).
- plain `GET var[,var...]` — new UNIVERSAL opcode OP_GETKEY (92): GETIN (non-blocking → ""/0 idle).
  String target → OP_STORS; numeric/int target → OP_STRNUM(VAL) [→ OP_FTOI/ISTORV]. GET# unchanged.
New opcodes sit AFTER op_iastore in _optab so the nosarr/noint strip ranges miss them (all tiers keep
them); dispatch gate raised to <95. tokenize.py learns TAB(/SPC(. Tests: test.sh MOD/TAB-SPC/GET blocks.

**Still missing — niche expression-position functions:** `FRE` `POS` `USR` `POINTER` `STRPTR`, and the
pi glyph constant. These need per-function parser/codegen work (POINTER/STRPTR need a var ADDRESS, not
its value, so OP_CALLX can't carry them). Low priority — rarely hit ordinary programs.

**Correctly omitted (these WORK via OP_PASSTHRU to ROM):** all FM/PSG sound, sprites, VERA bitmap
graphics (SCREEN/LINE/RECT/...), VPOKE/TILE/VLOAD, BLOAD/BSAVE, tooling (LIST/MON/EXEC/BASLOAD/DOS).

**X16FONTS.PRG campaign** (492-line BASLOAD font editor, renumbered 1..492, full of $hex + TAB(/SPC(/GET).
Progress via the $0403 err-cat / $0404-5 err-line mailbox, one capacity/gap ceiling at a time (commit 05eeb1b):
- line 129: **MAXLINES=128** line-number map (NOT CODE_CAP — I mis-diagnosed that first; growing CODE_CAP
  16->32 KB did NOT move line 129). Fixed: MAXLINES 128->512 (nlines/find_line_addr index -> uword, banked
  line-map pointers grow to 1 KB each). Also grew CODE_CAP 16->32 KB anyway (banks 7..10, NAMES_BANK 9->11).
- line 149: **IF..THEN + an X16 keyword** was ?SYNTAX (parse_then_body had no OP_PASSTHRU else-arm like
  parse_statement). Fixed: THEN routes unknown keyword-first stmts to pass-through; false guard still skips.
- line ~363: **LIT_SIZE=768** string-literal pool (X16FONTS totals 828 literal bytes; cumulative crosses
  768 at line 362). **FIXED by the banked-pool relocation (below).** Ruled out on the way: ~25 vars (<127),
  70 fwd-refs (<128 MAXFIX), 0 DATA.

**X16FONTS NOW COMPILES END-TO-END** (all 492 lines): $0403 err-cat = 0, $0404/5 err-line = 0, $0406 = 1
(out.prg written, ~17.7 KB). Verified headless: stage demo/X16FONTS.PRG as source.prg + gpc.runtime.bin
(+ gpc.rt.nosarr.bin) in an fsroot, run gpc.prg, read the mailbox. This is GPC's proof case: a real native
X16 BASIC program ($hex + TAB(/SPC(/GET throughout) compiles to a standalone .prg. (Interactive RUN of the
editor is a manual/visual check — not headless-scriptable.)

**The wall — BROKEN by the banked-pool relocation** (gpc.p8 only; vm.p8 UNCHANGED, protecting its ~58 B
runtime margin): litpool + datapool moved OUT of exhausted low RAM into **POOLS_BANK (= NAMES_BANK+1 = 12)**,
litpool at BRAM+0, datapool at BRAM+LIT_SIZE, both grown to 2048 B (4 KB of the 8 KB window; room to double).
Pools are WRITE-ONLY during compile, so store_literal/store_data just `cx16.rambank(POOLS_BANK)` before the
`strings.copy` (self-correcting: the next pc_poke/next_src_line/intern_* re-pages its own bank — same
invariant NAMES_BANK already relies on; safe because `sptr` lexes the low-RAM `linebuf` copy, not the bank).
write_output pages POOLS_BANK before streaming the pools to out.prg. **vm.p8 stays bank-UNAWARE:** the
IN-PROCESS run (headless testbench ONLY — a real INTERACTIVE build writes out.prg and the user RUNs it
separately) copies the used pool bytes down to small low-RAM scratch (litscratch 256 / datascratch 128) and
points vm.litbase/database there ($A000 window holds P-code during the run, so pools can't live there). The
guard `lit_len<=256 and data_len<=128` (+ RUN_CAP) gates in-process self-run; over that → "too big to run"
(out.prg still complete). Shrinking scratch from the old 768+768 pools FREED ~1.1 KB of low RAM → the
in-process string heap (progend $978c..MEMTOP $9F00) GREW to ~1.9 KB (was ~0.8 KB), so the reverse of the
old spiral — GC stress tests got MORE headroom. Full suite: 337 PASS / 0 FAIL. See [[gpc-project]]
[[gpc-engine-shrink]] [[x16-rom-internal-calls]].
