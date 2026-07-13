---
name: gpc-runtime-asm-conversion
description: "Ongoing runtime-VM Prog8->hand-asm conversion (branch runtime-asm) — phases, methodology, size trajectory, recalibrated floor"
metadata: 
  node_type: memory
  type: project
  originSessionId: 481504f0-31d5-4658-a8c1-3b05e8802238
---

Converting the GPC runtime VM (`src/runtime/vm.p8`) from Prog8-generated code to hand-written 65C02
asm **in place**, one opcode group per phase, to shrink + speed up the bytes shipped inside every
compiled program. **Compiler (`gpc.p8`) STAYS Prog8; only the runtime converts.** Branch `runtime-asm`;
commit after each phase, full corpus (`scripts/test.sh`, now 275 tests) must stay green. See [[gpc-project]].

**Methodology (validated):** replace `sub op_X()` with `asmsub op_X() { %asm {{ ... rts }} }`; the 89-entry
dispatch jump table `_optab` + `jsr p8b_vm.p8s_op_X` are untouched, so a regression is isolated to the one
handler. Symbols: module vars `p8b_vm.p8v_<name>`, subs `p8b_vm.p8s_<name>`, ZP scratch
`P8ZP_SCRATCH_W1/W2/B1/REG`. **@shared** any module var referenced ONLY from asm (prog8 dead-strips vars it
can't see referenced — bit us repeatedly: for_ilimit/for_top/callstack). Split arrays are
`p8v_<n>_lsb`/`_msb` indexed per-element; `float[N]` are CONTIGUOUS 5-byte (`i*5`) via the `faddr` helper.
Ending an asmsub with `.byte`/`.word` data tables trips prog8's return check → add `; !notreached!`.

**Progress (size = build/vm_runtime.prg):** baseline 13,547 → cumulative: P1 int-core -530, P2 float
arith/cmp/pow -615, P3 float loads/consts -53, P4a float FOR -156 (=12,193), P4b gosub/ret+callfn -247
(=11,946), P5 numeric-array op_aload/op_astore -113 (=11,833, d58763e), P6 machine/channel
POKE/PEEK/SYS/CLOSE/CHKIN/CHKOUT -153 (=11,680, c9c427e), P7 bstr core (13 string-storage subs
dlen/dptr/bcompare/chr/mem_to_temp/to_cbuf/sarr_desc/store_desc/store_var/var_from_mem/concat/substr/
push_body_temp) -323 (=11,357, f338440), **P7b 19 string HANDLERS in vm.p8 -935 = 10,422 (f43d450)**.
**Conversion effectively COMPLETE: 10,422 B = -23% from 13,547 baseline** (lands in the recalibrated
8-9 KB realistic floor, not the 5 KB Blitz aspiration). All hot paths + string core are hand-asm.
**P5 note:** converted only the HOT element-access ops (op_aload/op_astore) — the win is a direct 5-byte
MFLPT memcpy between arrheap cell and stack cell, replacing peekf/pokef's FAC round-trip. Kept `op_dim`
prog8 (cold, once-per-array; its heap-overflow guard is safety logic not worth hand-transcribing for ~100B).
Kept `index_of`/`dim_setup` prog8, called from asm via their `p8s_<sub>.p8v_<param>` slots (they only READ
params so the slots double as slot/nd storage after the call). **mul_word_5 clobbers BOTH W1 and W2** — never
hold a live pointer across it. `faddr` uses only REG (safe across it). Ran a 4-lens adversarial asm review
(Workflow) before committing P5 — clean.
**Recalibrated floor: realistic ~8-9 KB, NOT the 5 KB Blitz target** — fat is spread across handlers, not
concentrated; the label-delta size method over-attributes (counts shared temps). Communicate this at a checkpoint.

**MEASURED 2026-07-10 — THE "2x" IS REAL; there are TWO different "Blitz"es, don't conflate them (I did, and
was briefly wrong).** (a) **Prog8 `BLITZ-COMPILER` reimplementation** (the sibling GPC ported from): VM runtime
= **8,841 B** (all inline in one 7,021-B `p8s_run` when()-cascade; string/GC = `gc_collect`/`gc_rewrite`/`gc_ensure`/
`substr` inside vm), 64 opcodes. GPC VM = **9,644 B** (vm 7,748 + bstr 1,896), 92 opcodes, 104.8 vs 138.1 B/op —
so vs THIS Blitz we're +9% for 28 more opcodes (int subsystem 1,662 B + passthru bridge 771 B) and denser per op.
That comparison is real but IRRELEVANT to the user's size goal. (b) **The genuine 1986 SuperSoft Blitz!** (C64,
`demo-c64/blitz_compiler.d64`, run via `run64.bat` in VICE) — THIS is the "~5 KB" aspiration and it is NOT a
phantom: its whole standalone compiled `c/dir` = **6,244 B / 25 blocks, contiguous, no padding** (SYS $081c);
the DIR logic itself is ~0.4 KB (`z/dir`=444 B), so the **real Blitz runtime ≈ 5.5-6 KB**. GPC's runtime is
**10.6 KB = ~1.85x** that. The 2x the user keeps citing is against the 1986 product, and it's genuine. My prior
"phantom" note compared (a) not (b) — deleted. Method: `awk` label-delta by `p8b_<mod>` (`:` sep); real-Blitz via
VICE `c1541 -read`.

**COMPILED-PROGRAM SIZE is gated by PCODE_BASE, NOT runtime code size — this is why runtime shrink stopped moving
blocks (2026-07-10).** A compiled `.prg` = `[code $0801..$318B][low BSS $318B..$3939][margin..$3C80][pcode@$3C80]`;
the compiler PADS the file to fixed `PCODE_BASE=$3C80`, so DIR's 281-B pcode rides on ~13.4 KB fixed overhead =
~55 blocks (measured `C.DIR.PRG` 13,722 B — but it's STALE, embeds the old ~13.5 KB pre-shrink runtime; a fresh
compile is the same block count, just filler instead of old code). The asm-shrink already cashed its size win ONCE
(let PCODE_BASE fall $5600→$3C80 = 80→52 blocks). Now PCODE_BASE is gated by the **BSS footprint top $3939**, not
the code top $318B (code has ~2.8 KB headroom below PCODE_BASE), so **further code-only shrink can't lower blocks.**
Levers to beat 52: (1) reclaim margin PCODE_BASE $3C80→~$3A40 = ~2 blocks free; (2) relocate low BSS above pcode
→ ~43 blocks (investigated + REJECTED, see below); (3) shrink runtime code 10.6→~6 KB = the real parity lever, hard.
TODO: re-stage `demo/C.DIR.PRG` (stale). Interactive runtime rebuild: `bash scripts/build.sh runtime interactive`.

**Hard constraints (unchanged):** ROM string GC (garba2) + command pass-through MANDATORY (gating,
[[gpc-gating-requirement]]); acts-like-BASIC startup preserved ([[gpc-x16basic-look-act]]); standalone must work.

**P7b string-handler methodology:** the handlers are thin SHELLS over the P7 bstr asm core, so lower-risk.
Helpers added: `opw` (P8ZP_SCRATCH_W1 = pcbase+pc; read operand via `lda (W1)`/`ldy #n:lda (W1),y`) and
`pcadd(A)` (pc+=A). Two `@shared` BSS scratch words `shtmp`/`shtmp2` park descriptors across bstr calls
(BSS = FREE for .prg size). Tricks reused: **re-read a descriptor from sstack[ssp] instead of parking it**
when ssp is fixed after its dec (op_strnum/scmp/sastore/prints free the temp by re-reading). **Write result
then tail-`jmp str_error`** = faithful to `if str_error() return` (on error str_error sets halt→run() stops,
so the just-pushed cell is inert; on success returns false). `bcompare` OVERWRITES its own ad/bd params →
re-read operands, don't reuse. $ffff out-of-range test = `lda lo; and hi; cmp #$ff` (AND==$ff iff both $ff).
MID$ signed-word start: <=0→0, 1..256→start-1, >256→255. Float I/O: FREADUY (byte→FAC), copy_float
(src=W1→dst A/Y, for the clamp_count float param), cast_FAC1_as_w_into_ay (signed), tostr/parse.

**@shared bug (found staging the demo, PRE-EXISTING from P7 core):** `sarr_hdr` (bstr) is read only from
asm (`sarr_desc`); its lone prog8 reader `sarr_dimmed` dead-strips in **TESTBENCH=false** builds → prog8
strips the write-only array → asm ref dangles (`undefined p8v_sarr_hdr_lsb/msb`, "Error in codegeneration").
`scripts/test.sh` ONLY builds the TESTBENCH=true `gpc`/`gpc prompt` variants, so it never caught it — only
`stage-demo.sh`'s `build.sh gpc interactive` (TESTBENCH=false) and `runtime visual` do. Fix: `@shared` on
`sarr_hdr` (245c464). **LESSON: after converting a var's last prog8 reader to asm, @shared it AND build the
`interactive`+`visual` variants, not just the corpus.** Demo staging = `bash scripts/stage-demo.sh` →
`demo/gpc.prg` (interactive), run via `run.bat`.

**ADDING A NEW VM OPCODE — checklist (learned the hard way landing int arrays 2c, e5a8f5a).** Three
places, miss any and it fails SILENTLY: (1) **`run()`'s asm dispatch has a hard opcode-count bound**
`cmp #N ; bcs _next` — opcodes >= N are treated as "unknown -> ignore", so a new handler runs as a NO-OP
and its operand bytes get mis-decoded as the next opcodes (symptom: program runs but the op does nothing +
downstream corruption; a `00` operand reads as OP_END). Bump N to new_opcode_count. (2) add `.word _tN` to
`_optab` AND a `_tN: jsr p8s_op_x / jmp _after` trampoline. (3) **re-check `PCODE_BASE` still clears the
runtime's BSS top** — new handler code + new BSS grows the low footprint; if BSS crosses PCODE_BASE the
STANDALONE loaded P-code is silently corrupted (in-process is immune — it runs P-code from banked RAM, so
the corpus's check-basic passes while check-standalone fails). The `build.sh runtime` map's last BSS gap end
is the top; raise PCODE_BASE above it. [[gpc-inc2-design]] (2c: opcodes 89-91 IDIM/IALOAD/IASTORE; both bugs
bit at once — cmp #89 ignored them, then BSS $3b5a > old PCODE_BASE $3A00; fixed to cmp #92 / $3E00.)

**Tier 1 — compiled-program size (1ff971d, the Blitz layout fix; separate axis from runtime CODE size).**
A compiled `.PRG` = `[$0801 runtime code][filler up to PCODE_BASE][pcode+pools @ PCODE_BASE]` — the compiler
(`gpc.p8` write_output) pads the FILE contiguously to the FIXED `PCODE_BASE`, so the file spans the runtime's
whole low-RAM footprint regardless of program size. The runtime asm-shrink did NOT shrink compiled programs
(PCODE_BASE was still `$5600`). Fix: the 5 VM slabs (varsf/ivarsf/arrheap/arr_dims/sarr_dims, `SLAB_BYTES`=3456)
are no longer prog8 `memory()` in low BSS — they're **host-assigned pointers**. Standalone (`heapfloor==0`):
`vm.run` parks them at `datatop` (just ABOVE the loaded pcode), string var table/heap stack above them → nothing
between code and pcode. Resident compiler (`heapfloor=progend`): keeps them in its own low buffer `gpc_vmslabs`
(little RAM above its 25KB image; must NOT starve the in-process heap). `PCODE_BASE $5600→$3A00` (clears the
remaining low footprint = code + hot BSS top ~$3808, +0.5KB margin). **c.HELLO 79→51, C.DIR 80→52 blocks (~-35%,
-7KB each).** Corpus 275 green. **INVARIANT: PCODE_BASE MUST stay above the runtime's low-RAM BSS top** (passbuf/
xbuf pass-through buffers MUST stay low for ROM CHRGET/TXTPTR reach) — if BSS grows past it, loaded pcode is
silently corrupted at runtime. Full Blitz parity (pcode right after code, ~43 blocks) needs the hot BSS moved
out of low RAM too — deferred. Residual: runtime CODE ~10.6KB vs the genuine 1986 SuperSoft Blitz! runtime ~5.7KB = the real ~1.85x (this "~5KB Blitz / long-tail 2x" is CORRECT — it's the C64 product, not the Prog8 reimpl; see the MEASURED 2026-07-10 note above).

**PCODE_BASE invariant now BUILD-ENFORCED + tightened (2026-07-09, branch `harden-and-tier2`).** Both int-array
bugs were silent; one was the BSS-crosses-PCODE_BASE trap (in-process immune, so corpus passes while standalone
silently corrupts). `scripts/assert-pcode-base.sh` reads the authoritative footprint top (`prog8_program_end` from
the `.vice-mon-list`) + PCODE_BASE (from `pcode_format.p8`) and FAILS the build if the footprint reaches PCODE_BASE
(warns if margin <256 B). Wired into `build.sh`'s `runtime` target (the single chokepoint producing the shipped VM
image). Verified: exit 1 when violated, 0 when valid. With the guard in place, PCODE_BASE tightened **$3e00 -> $3c80**
(footprint top $3b5b + 293 B margin), reclaiming 384 dead filler bytes from every compiled program = ~1 block (54 vs
55 on a sample loop). **Tier-2 "BSS above P-code" (~43 blocks) INVESTIGATED + REJECTED as a bad trade:** unlike Tier-1's
slabs (already-indirect `memory()` handles, 4736 B -> pure win), the remaining low BSS is ABSOLUTE-addressed (`istack`
98 asm sites, `sstack` 48, ...); relocating it above the P-code means converting each site to indirect access, which
trades BSS bytes for ~equal CODE bytes (re-raising the footprint) AND slows the hot paths -- ~2-3 blocks for real risk +
a slower VM. The real remaining size lever is runtime CODE shrink (the deferred long-tail ~2x vs Blitz), not BSS moves.

**Runtime CODE shrink -- RTS-dispatch (2026-07-09, branch `if-line-semantics`, commit 0c7736b).** run()'s jump
table pointed at ~89 per-opcode trampolines, each a 6-byte `jsr p8s_op_X / jmp _after` (~534 B, the single most
CONCENTRATED fat -- everything else is spread 80-400 B across cold handlers). Replaced with the classic RTS-dispatch
trick: the loop pushes `_after-1` ONCE (lda #>/pha, lda #</pha after `tax`), then `jmp (_optab,x)` straight into the
handler; the handler's own final `rts` returns to `_after`. `_optab` now lists the handler subs directly
(`p8b_vm.p8s_op_*`). The 3 inline ops (`_t0/_t1/_t2` = END/JMP/JZ) `jmp` not `rts`, so each pulls the pushed addr off
first (`pla/pla`). Transparent to handlers that tail-`jmp str_error` (the final rts in the chain still lands on `_after`).
**vm_runtime.prg 11182 -> 10660 B (-522), footprint top $3b5b -> $3951 (PCODE_BASE margin now 815 B); also -1 jsr+jmp per
opcode (faster dispatch).** **HONEST CEILING (confirmed by module measurement): p8b_vm handlers = 8270 B / 74%, p8b_bstr
= 1896 / 17%, all else ~1000 B combined. No more concentrated wins exist -- the handlers ARE the size and are already
dense hand-asm. Further shrink toward the ~5 KB Blitz aspiration = shaving many handlers by small amounts (high effort,
real regression risk, diminishing returns); realistic floor stays ~8-9 KB.** Method to find fat: sort code-region labels
from `.vice-mon-list`, diff consecutive addrs, group by module prefix.

**op_callfn (P4b):** dispatches fnid→ROM float fn via a split lo/hi vector table indexed by fnid, called
through a `jsr _cfvec / _cfvec: jmp (W2)` trampoline (ROM fn's rts returns past the jsr). RND special-cased:
load FAC=`c_one`(1.0, positive) before `$fe57` for a fresh 0..1. Table order = FN_* ids 0..10:
SGN$fe84 INT$fe2d ABS$fe4e SQR$fe30 RND$fe57 SIN$fe42 COS$fe3f TAN$fe45 ATN$fe48 LOG$fe2a EXP$fe3c.

**EXP bug — root cause was the COMPILER, not the runtime (corrects the prior "apply_fn no FN_EXP" belief).**
`EXP(x)` returned 0 because `gpc.p8 func_id()` mapped `$bc`(LOG)→`$be`(COS) and **skipped `$bd` (EXP)**, so
EXP was never emitted as OP_CALLFN. Fixed by adding `$bd -> return pcode.FN_EXP`. The ROM `$fe3c` EXP itself
works fine in the runtime's no_sysinit/bank-4 context — PROVEN by `spikes/exp_spike.p8` (MOVFM/`$fe3c`/MOVMF
gives EXP 0/1/2 = 1/2/7). Lesson: when one function of a family misbehaves, check the compiler's token→id
map before suspecting the ROM call.
