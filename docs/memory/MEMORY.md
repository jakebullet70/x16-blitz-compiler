# Memory Index

Knowledge base for the Blitz-X16 compiler. `gpc-*` notes survived the prune of the abandoned
sibling project: what is kept is a fact about **X16 BASIC or the X16 itself**, not GPC internals.

> **This folder is the live auto-memory**, reached by a directory junction from
> `~/.claude/projects/c--dev-CmdrX16-dos-tools-x16-blitz-compiler/memory`. The junction broke
> when the project was renamed once already — **if a rename moves it again, re-make the junction
> first.** See [memory-is-git-tracked](memory-is-git-tracked.md).

## How to work in this repo
- [Answer the question asked](answer-the-question-asked.md) — lead with the number asked for
- [Measure before changing code](measure-before-changing-code.md) — probes beat edit-and-see
- [Prose style is flat reference](prose-style-is-flat-reference.md) — the five settled rules; `doc-style` owns them
- [Write readable code, user crunches](write-readable-code-user-crunches.md) — one statement a line; an unexplained SRC edit is his crunch pass
- [Comments light, code should flow](comments-light-code-should-flow.md) — heavy REMs mean bad naming
- [No ship language, no unasked builds](no-ship-language-this-is-dev.md) — "commit and push" does not include a build
- [Commit to main directly](commit-to-main-directly.md) — solo repo, no branch, no review
- [Compiler must not cap program size](compiler-must-not-cap-program-size.md) — a build-side wall is a bug; compiler growth now costs a program zero
- [No backward compatibility needed](no-backward-compatibility-needed.md) — forced recompiles cost nothing
- [Ask before writing asm](ask-before-writing-asm.md) — standing order: agree GP.ASM or 64tass first
- [The compiler is GPC](name-the-compiler-gpc.md) — "Blitz" is a heritage nod; the code is the user's own
- [User runs concurrent agents here](user-runs-concurrent-agents-here.md) — re-read before any write
- [Compile shared, not embedded](compile-shared-not-embedded.md) — SHARED is the p-code number
- [Library working copy, then root](library-working-copy-then-root.md) — edit in samples/GPB-MODS-TESTING/GPC-BASIC/; drift runs BOTH ways
- [Compact early, not at the end](compact-early-not-at-the-end.md) — after every step; cost is context size x turns

## Build and toolchain
- **Build setup** — *(note missing)* see docs/BUILDING.md
- [Build toolchain location](build-toolchain-location.md) — make, 64tass, python are off-PATH in C:\8bitProgramming
- [App make skips compiler.library](app-make-does-not-rebuild-compiler-library.md) — use `make libs`
- [make libs does not install the runtime](make-libs-does-not-install-the-runtime.md) — `make -C source/runtime gpc-rt` is the other half
- [Baseline compiler is the application copy](baseline-compiler-is-the-application-copy.md) — testing/GPC.BIN can be stale
- [Measure p-code per module](measure-pcode-per-module.md) — map plus SYM gives bytes per include and routine
- [A compile timeout faked success](compile-shared-timeout-fakes-success.md) — the banner is the finish line, not the file size
- [Headless BASL build recipe](headless-basl-build-recipe.md) — the three emulator runs and their stop conditions
- [GPC.ERR builds shared, in the main dir](gpcerr-build-shared-in-main-dir.md) — never standalone
- [Tests share the product's memory](tests-share-the-products-memory.md) — the harness costs workspace; BASLOAD does not nest #IFNDEF
- [Paste can't drive a running program](paste-cannot-drive-a-running-program.md) — use a fixed-answer variant
- [File I/O dies in a GP.DO key loop](file-io-error-in-gpdo-key-loop.md) — the seven shapes already ruled out
- [Retired keyword defers to runtime](retired-keyword-defers-to-runtime.md) — stale callers compile clean and explode
- **Emulator split** — *(note missing)* x16emu r49 runs tests, Box16 debugs

## GP.BASIC — the GP block and inline assembly
- [GP.DEFPROC one-line calls](gp-defproc-one-line-calls.md) — BUILT; formals are shared, so a body must not call its own verb
- [GP.FN string RETURNS aliases](gp-fn-string-returns-aliases.md) — OPEN BUG: two calls on one verb in an expression both give the second answer
- [Block GP.IF design](gpb-block-if-design.md) — SHIPPED at 14 runtime bytes
- [Block openers must not defer](gpb-block-openers-must-not-defer.md) — .error_syntax silently corrupts enclosing nesting
- [GOTO out of a GP block](gpb-goto-out-of-block-design.md) — BUILT: .unwind opcode, zero runtime bytes
- [RETURN unwinds frames](gpc-return-unwinds-frames.md) — RETURN out of FOR/GP.DO/GP.SELECT is safe
- [GP.ASM fixups retired by two passes](gpasm-fixups-retired-by-two-passes.md) — the 128-reference cap is gone
- [GP.ASM implementation status](gpasm-implementation-status.md) — shipped; dotted {VAR} names, self-patching operands
- [GP.ASM inline assembly research](gpasm-inline-assembly-research.md) — where the doc is, what is still open
- [GP.ASM blobs may use zTemp0/1/2](gpasm-blob-may-use-ztemp.md) — SYS already clobbers zTemp0
- [GP.STRPTR points at the length byte](gp-strptr-points-at-the-length-byte.md) — text starts at +1
- [GP draw under a re-ordered font](gp-draw-under-a-reordered-font.md) — only GP.BOX style 0 survives

## Compiler limits, memory and banking
- [PROGRAM TOO BIG was the workspace](program-too-big-fires-early.md) — FIXED; a bank per table, 4,096 lines
- [SHARED p-code cap is RTBASE](gpc-shared-pcode-cap-is-rtbase.md) — ~17,920 bytes, not $9F00
- [GPC Blitz runtime slack and limits](gpc-blitz-runtime-slack-and-limits.md) — the run-side ceiling is FREE minus 4096
- [Run-side workspace, read from the PRG](run-side-workspace-read-from-the-prg.md) — two bootstrap page numbers give the budget
- [Core page cushion below GPBase](gpc-core-page-cushion-below-gpbase.md) — ~40 B; cross it and every program grows 256 B
- [Runtime footprint](blitz-x16-runtime-footprint.md) — 10,956 B in every program, and how to shrink it
- [String heap scavenger](string-heap-scavenger.md) — SHIPPED: dead blocks reused, +1 page RT
- [BINPUT# caps at 255 bytes](binput-caps-at-255-bytes.md) — three caps land on one number; it is a CHRIN loop
- [String blocks never shrink](gpc-string-blocks-never-shrink.md) — never build a big temporary
- [LOAD chain strands array strings](load-chain-strands-array-strings.md) — UNBOUNDED leak for string arrays
- [Compile is write-only](compile-is-write-only.md) — the premise two-pass rests on
- [Two-pass compiler](two-pass-compiler.md) — DONE; the compiler's own size bounds nothing
- [Compiler overlay into a bank](compiler-overlay-into-a-bank.md) — REVERTED, but the mechanism works
- [Banking strings: length, not count](banking-strings-scales-with-length.md) — the menus barely broke even
- [BANK, not POKE 0](gpc-bank-statement-not-poke-zero.md) — PEEK/POKE restore the bank around every access
- [Claim every compile-time bank](claim-every-compile-time-bank.md) — BANKMGR.CLAIM before the first ALLOC
- [STASH leaves its bank selected — FIXED](stash-leaves-its-bank-selected.md) — it now restores the caller's bank
- [color-test sample state](color-test-sample-state.md) — parked 2026-09-06; four loose ends
- [XBase engine planned](xbase-engine-planned.md) — skeleton on disk, GUI in bank 4, 255 bytes a record to find

## The editor sample
- [Editor branch state, GUI next](gpc-editor-branch-and-gui-next.md) — the self-check lines to keep green
- [The editor's slow RETURN](editor-return-is-the-line-table.md) — FIXED at 87x; the 2048-entry boundary is the trap
- [LINPUT# loader, and its NUL trap](gpc-editor-loader-linput-and-blob.md) — 10.5x over GET#; ST=66 on a missing file
- [Editor: ASCII inside, PETSCII outside](gpc-editor-is-ascii-inside-petscii-outside.md) — why the font is re-ordered in VRAM
- [ALT keys need the keymap](gpc-editor-alt-keys-need-the-keymap.md) — in ISO mode ALT+F sends nothing
- [VERA FX cache writes are aligned](vera-fx-cache-write-is-aligned.md) — the row renderer needs an EVEN column
- [GPC-HELP scroll cost is the file read](gpc-help-scroll-cost-is-the-file-read.md) — the .HLP is re-read every keypress
- [Bar and dropdown drive each other](menubar-menuhelp-cross-axis-exits.md) — DOWNEXIT and KEYEXIT are the two halves
- [MENUHELP: use the whole interface](menuhelp-use-the-whole-interface.md) — build the library's own example first

## The CUA GUI library
- [GUI-CUA phase 5 state](gui-cua-phase5-state.md) — written not verified; what is owed and what still drifts

## The BASL cruncher
- [Folding onto a label line saves nothing](folding-onto-a-label-line-saves-nothing.md) — a bare label is not a BASIC line
- [BASL cruncher built](basl-cruncher-built.md) — samples/cruncher; 255 bytes on the editor
- [BASL cruncher internals](basl-cruncher-internals.md) — routine map and build cycle; the harness is NOT in the repo
- [All three line endings](basl-sources-use-all-three-line-endings.md) — how to sniff; a short CR file reads as CRLF

## BASLOAD
- [BASIC RAM was the tokenise ceiling](basload-basic-ram-is-the-tokenise-ceiling.md) — REMOVED for build_basl.py only
- [BASLOAD streams to a file](basload-streams-to-a-file.md) — SHIPPED; the fork and its partial-output defect
- [BASLOAD runs from RAM unmodified](basload-runs-from-ram-unmodified.md) — the ROM source builds as a plain PRG
- [BASLOAD #DEFINE rejects digits](basload-define-rejects-digits.md) — GUI2.DEFS is INVALID PARAMETER; no #INCLUDE is optional
- [Labels and variables collide](basload-label-and-variable-collide.md) — DUPLICATE SYMBOL; the $ does not separate them
- [#AUTONUM breaks STRCASE](basload-autonum-breaks-strcase.md) — do not write it
- [TRUE is -1](gpc-basl-true-is-minus-one.md) — why NOT needs -1, and the two spellings that break

## X16 BASIC semantics (ROM-verified — apply to any compiler)
- [IF semantics](gpc-if-semantics.md) — a false IF skips the WHOLE line. Blitz gets this right.
- [FOR STEP 0 semantics](gpc-for-step0-semantics.md) — STEP 0 needs EXACT equality. **Blitz gets this wrong.**
- [FOR 1 TO 0 runs once](gpc-basic-for-loop-runs-once.md) — guard every FOR 1 TO LEN()
- [X16 BASIC conformance](blitz-x16-basic-conformance.md) — 4 real defects vs stock BASIC
- [X16 BASIC coverage](gpc-x16-basic-coverage.md) — the 7 lexer blockers on valid X16 BASIC
- [R44+ keywords](blitz-x16-r44-plus-keywords.md) — CLOSED: all 10 are in; do not re-fix

## Performance
- [C64 Blitz benchmark yardstick](blitz-c64-benchmark-yardstick.md) — real C64 Blitz is ~2.6x stock
- [Arrays share the workspace](blitz-arrays-share-the-workspace.md) — no array heap; DIM raises OUT OF MEMORY
- [Array index fast path](gpc-array-index-fastpath.md) — worth ~31%; watch the OOB short-circuit
- [STRCASE call overhead, measured](strcase-call-overhead-measured.md) — ~2,570 cycles a call

## X16 platform / toolchain
- [MACPTR wraps banks itself](macptr-wraps-banks-itself.md) — the caller that wants it is STASH, not FILEDIR
- [Scrolling a screen region](scrolling-a-screen-region.md) — no GP command; three ways to do it by hand
- [GP drawing targets layer 1](gp-drawing-targets-layer-1.md) — no row clamp, and L1_MAPBASE is POKEable
- [P-code runs from a bank, PROVEN](pcode-runs-from-a-bank-proven.md) — no ABI change; RETURN out needs no bank restore
- [GP.BANKED region relocation](gp-banked-region-relocation.md) — the rotation and two GOTOs that move it
- [GP.BANKEDSTR: literal text in a bank](gp-bankedstr-literal-text-in-a-bank.md) — BUILT; +3,840 B on GPBMODS
- [Object file must fit under the runtime](object-file-must-fit-under-the-runtime.md) — regions were invisible to the fit check
- [Wildcard scratch eats the source](wildcard-scratch-eats-the-source.md) — S0:NAME.B* matches NAME.BASL
- [Every region gets its own .Bnn file](region-overlay-ovl-file.md) — BUILT; a .Bnn size is a PAGE COUNT unless topmost
- [Object writer: regions vs low code](object-writer-regions-vs-low-code.md) — the streamer pads forward 65,535 bytes with no check firing
- [A second region for the utilities](second-region-for-the-utilities.md) — BUILT; a BANK statement is the ONLY disqualifier
- [Banked code loses the bank on a call out](gp-banked-call-out-loses-the-bank.md) — and may not BANK itself back
- [FILEDIR banks whole](filedir-bank-split.md) — BUILT; the switch moved into its two blobs
- [GPBMODS resident p-code breakdown](gpbmods-resident-pcode-breakdown.md) — the shell is 79%, all eight modules 21%
- [Dead-code elimination, measured](basl-dead-code-elimination-measured.md) — PARKED; 691 B free by deleting two #INCLUDEs
- [VRAM-to-VRAM memory_copy limits](vram-to-vram-memory-copy-limits.md) — 15,360 in one call; descending overlap is safe
- [Array element sizes, measured](array-element-sizes-measured.md) — a `%` array is TWO bytes an element, untyped SIX
- [Byte data type feasibility](byte-data-type-feasibility.md) — STUDY ONLY; the opcode space refuses byte SCALARS
- [KERNAL preserves the RAM bank](kernal-preserves-ram-bank.md) — measure it in asm, PEEK(0) cannot see it
- [X16 ROM internal calls](x16-rom-internal-calls.md) — verified R49 dispatcher/GC addresses and ZP pointers
- [X16 toolchain](x16-toolchain.md) — 64tass and emulator paths on this machine
- [x16emu -echo doubling](x16emu-echo-doubling.md) — non-warp `-echo raw` prints every char TWICE
- [Memory is git-tracked](memory-is-git-tracked.md) — versions with the project, via a junction that must survive renames
- [Blitz-X16 prior attempt](blitz-x16-prior-attempt.md) — the earlier Prog8 self-hosted compiler, now deleted
- [Prog8 PETSCII char literals](prog8-petscii-charlits.md) — legacy; only if Prog8 comes back
