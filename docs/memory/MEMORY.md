# Memory Index

`gpc-*` notes are facts about X16 BASIC or the X16, not GPC internals. This folder is reached by a
junction; re-make it first if a rename breaks it. See [memory-is-git-tracked](memory-is-git-tracked.md).

## How to work in this repo
- [Answer the question asked](answer-the-question-asked.md) — lead with the number asked for; [measure before changing code](measure-before-changing-code.md)
- [Review findings must be reachable](review-findings-must-be-reachable.md) — drop anything only invalid source or a typo triggers
- [Tech doc structure spec](tech-doc-structure-spec.md) — named sections, inputs/outputs/errors, never invent a detail
- [Prose style is flat reference](prose-style-is-flat-reference.md) — `doc-style` owns the rules; [help topics are current behaviour only](help-topic-writing-rules.md); [HLP files carry no hand edits](hlp-files-carry-hand-edits.md), a plain MKHELP.PY run rebuilds
- [Write readable code, user crunches](write-readable-code-user-crunches.md) — one statement a line, an unexplained SRC edit is the user's crunch pass; [comments light](comments-light-code-should-flow.md)
- [Bounds checks are a luxury](bounds-checks-are-a-luxury.md) — no range checks in library routines; the contract states the limit; [a sweep of the older code is owed](guard-sweep-owed.md)
- [Ask before writing asm](ask-before-writing-asm.md) — standing order: agree GP.ASM or 64tass first
- [Keep Claude's files off the root](keep-claude-files-off-the-root.md) — source/drive and source/scratch are Claude's
- [Commit to main directly](commit-to-main-directly.md) — solo repo, no branch; [never commit OASIS](never-commit-oasis.md), stage by name
- [Compiler must not cap program size](compiler-must-not-cap-program-size.md) — a build-side wall is a bug; [no backward compatibility](no-backward-compatibility-needed.md)
- [BMXVIEW: two copies, one master](bmxview-two-copies-one-master.md) — BMXVIEWER/BMXVIEW.BASL is the master; sync back, adjusting the #INCLUDE prefix
- [Library working copy, then root](library-working-copy-then-root.md) — edit in GPB-MODS-TESTING/GPC-BASIC/, drift runs both ways; [test in GPBMODS first](test-in-gpbmods-before-spreading.md); [samples build in place](samples-build-in-place.md)
- [Ask before adding library code](ask-before-adding-library-code.md) — unused routines ship unless --strip; one program's feature goes in that program
- [GUI only through verbs](gui-only-through-verbs.md) — no GOSUB GUI.* in a program
- [Library never hard-codes a bank](library-never-hard-codes-a-bank.md) — the program hands each module its place; banks are shared, no waste
- [No ship language, no unasked builds](no-ship-language-this-is-dev.md) — a change sent back during a play-test gets built at once; [run builds in the background](run-builds-in-background.md); [build, report, hand it back](build-report-dont-investigate.md)
- [Compile shared, not embedded](compile-shared-not-embedded.md) — SHARED is the p-code number; [release samples are the exception](release-samples-shape.md); [shipped readmes fit 78 columns](release-readmes-fit-78-columns.md)
- [The compiler is GPC](name-the-compiler-gpc.md) — "Blitz" is a heritage nod; [concurrent agents run here](user-runs-concurrent-agents-here.md), re-read before any write
- [Build times baseline](build-times-baseline.md) — time every build, flag 2x over; build.py prints step times
- [Compact early, not at the end](compact-early-not-at-the-end.md) — remind the user to /compact at the end of every turn that lands a step

## Build and toolchain
- [Release 1.1.0 state](release-1-1-0-state.md) — zip rebuilt 2026-10-02 on build 131, not sent yet; the smoke test of release/TMP is owed
- [USER-RUNS demos broken by Build 127](user-runs-demos-broken-by-build-127.md) — runtimes sit beside each sample; the tree is on build 131
- [Tool home layout deferred](tool-home-layout-deferred.md) — /GPC/ + /BASIC-SRC/ is next-version; research in docs/blitz/TOOL-HOME-LAYOUT.RESEARCH.md
- [Build toolchain location](build-toolchain-location.md) — make, 64tass, python are off-PATH in C:\8bitProgramming; see docs/BUILDING.md
- [Git Bash sed strips CRLF](git-bash-sed-strips-crlf.md) — `sed -i` writes LF; count CRLF with Python bytes
- [App make skips compiler.library](app-make-does-not-rebuild-compiler-library.md) — use `make libs`; [it does not install the runtime](make-libs-does-not-install-the-runtime.md); [the baseline is the application copy](baseline-compiler-is-the-application-copy.md)
- [Measure p-code per module](measure-pcode-per-module.md) — map plus SYM gives bytes per include and routine
- [Headless BASL build recipe](headless-basl-build-recipe.md) — three emulator runs; [a timeout once faked success](compile-shared-timeout-fakes-success.md), the banner is the finish line
- [GPC.ERR builds in its sample folder](gpcerr-builds-in-its-sample-folder.md) — never standalone
- [Runtime storage is the golden RAM](runtime-storage-is-golden-ram.md) — $0400 to StorageEnd, which moves; [tests share the product's memory](tests-share-the-products-memory.md)
- [/GPC/NAME opens from any folder](gpc-home-path-form.md) — measured on R49 hostfs; the plain form works
- [Paste can't drive a running program](paste-cannot-drive-a-running-program.md) — queue keys with `POKE 780,K:SYS 65219` or `source/scratch/runkeys.py`; x16emu r49 runs tests, Box16 debugs
- [File I/O dies in a GP.DO key loop](file-io-error-in-gpdo-key-loop.md) — FIXED in runtime build 131: CLS, COLOR and PRINT# mishandled the channel
- [shared_test.py WARM step is stale](shared-test-warm-step-is-stale.md) — fails with `?RTC<nnn>`; the driver never loads bank 1, not a runtime fault
- [Retired keyword defers to runtime](retired-keyword-defers-to-runtime.md) — stale callers compile clean and explode

## GP.BASIC — the GP block and inline assembly
- [GP.DEFPROC one-line calls](gp-defproc-one-line-calls.md) — BUILT; a body must not call its own verb
- [GP.FN string RETURNS aliased, FIXED](gp-fn-string-returns-aliases.md) — FIXED: a string GP.FN concats "" into a temporary
- [Block GP.IF design](gpb-block-if-design.md) — SHIPPED; [block openers must not defer](gpb-block-openers-must-not-defer.md)
- [GOTO out of a GP block](gpb-goto-out-of-block-design.md) — BUILT: .unwind opcode; [RETURN unwinds frames](gpc-return-unwinds-frames.md)
- [GP.ASM implementation status](gpasm-implementation-status.md) — shipped; [fixups retired by two passes](gpasm-fixups-retired-by-two-passes.md); [where the research doc is](gpasm-inline-assembly-research.md)
- [GP.ASM label cannot start with A](gpasm-label-cannot-start-with-a.md) — a real defect in the operand parser; [blobs may use zTemp0/1/2](gpasm-blob-may-use-ztemp.md)
- [GP.STRPTR points at the length byte](gp-strptr-points-at-the-length-byte.md) — text starts at +1
- [GP draw under a re-ordered font](gp-draw-under-a-reordered-font.md) — only GP.BOX style 0 survives

## Compiler limits, memory and banking
- [Scalar variable space caps at 4,096 bytes](scalar-variable-space-caps-at-4096.md) — 11-bit halved operand, now checked; [every scalar was allocated 6 bytes](every-scalar-allocated-six-bytes.md), FIXED
- [PROGRAM TOO BIG was the workspace](program-too-big-fires-early.md) — FIXED; the line table holds 12,286 code lines in six bank pairs, STRPageLine alone pages it; [OUT OF MEMORY $02B8](gpbmods-out-of-memory-02b8.md) was StartRuntime never setting X
- [SHARED p-code cap is RTBASE](gpc-shared-pcode-cap-is-rtbase.md) — 22,016 bytes, not $9F00; [the full slack table](gpc-blitz-runtime-slack-and-limits.md)
- [Run-side workspace, read from the PRG](run-side-workspace-read-from-the-prg.md) — two bootstrap page numbers give the budget; [2 B cushion below GPBase](gpc-core-page-cushion-below-gpbase.md)
- [Compiler-emitted bank switch](compiler-emitted-bank-switch.md) — .bgosub emitted, shims deleted; [banks work in progress](banks-work-in-progress.md), HANDLER-BANK at step 28, uncommitted
- [Opcode numbers follow handler order](opcode-numbers-follow-handler-order.md) — moving a `;;` handler renumbers p-code
- [Library sizes owed to help](library-sizes-belong-in-help.md) — runtime 10,239 B CORE / 11,775 GP.BASIC embedded; GPC-BASIC costs only what you #INCLUDE
- [Runtime footprint](blitz-x16-runtime-footprint.md) — build 128 sizes and how to shrink it
- [String heap scavenger](string-heap-scavenger.md) — SHIPPED; [string blocks never shrink](gpc-string-blocks-never-shrink.md), never build a big temporary
- [BINPUT# caps at 255 bytes](binput-caps-at-255-bytes.md) — it is a CHRIN loop
- [LOAD chain clears memory](load-chain-clears-memory.md) — the variable carry is gone; no CLR needed
- [Two-pass compiler](two-pass-compiler.md) — DONE; [compile is write-only](compile-is-write-only.md) is the premise
- [Compiler overlay into a bank](compiler-overlay-into-a-bank.md) — REVERTED, the mechanism works; [banking strings scales with length](banking-strings-scales-with-length.md)
- [BANK, not POKE 0](gpc-bank-statement-not-poke-zero.md) — PEEK/POKE restore the bank around every access; [STASH now restores the caller's bank](stash-leaves-its-bank-selected.md)
- [Claim every compile-time bank](claim-every-compile-time-bank.md) — BANKMGR.CLAIM before the first ALLOC
- [color-test sample state](color-test-sample-state.md) — parked; four loose ends
- [XBase engine planned](xbase-engine-planned.md) — skeleton on disk, GUI in bank 4
- [GPC.GUI: defs into a folder next](gpc-gui-next-defs-in-a-folder.md) — GPC-GUI-DATA, not started; [size is not a constraint](gpc-gui-size-not-a-constraint.md)
- [BUILD ALL: a sixth GPC.INPUT line](gpc-input-sixth-line-chain.md) — agreed route, asm not written

## The editor sample
- [TURBO compile slow, FIXED](turbo-compile-slow-open.md) — the {VAR} cache overflowed; now banks 24-27, 32K; TURBO compiles in 45 s
- [TURBO GPC IDE plan](turbo-gpc-ide-plan.md) — a fresh GP.BASIC editor on MSEDIT's design, source in GPC-BASIC-TOOLS-SRC/TURBO-GPC; the library change is done (bank plus address, `%` in 14 modules); the GUI dialogs are in TURBO.BASL, save to VRAM, and TURBOTEST passes; the menu bar is built (Esc opens File, Exit is a row); the file picker is built and the keys follow Notepad++; setup code lives in the regions to keep workspace; DLGLABELS gives the library's buttons TURBO's case; the library is copied to root and help rebuilt; plan in docs/blitz/TURBO-GPC.PLAN.md
- [Editor branch state, GUI next](gpc-editor-branch-and-gui-next.md) — the self-check lines to keep green
- [ED-STORE 255.BASL is test data](editor-test-fixture-files.md) — the editor opens it; do not flag it
- [The editor's slow RETURN](editor-return-is-the-line-table.md) — FIXED, the 2048-entry boundary is the trap; [the LINPUT# loader](gpc-editor-loader-linput-and-blob.md), ST=66 on a missing file
- [Editor: ASCII inside, PETSCII outside](gpc-editor-is-ascii-inside-petscii-outside.md) — why the font is re-ordered in VRAM; [ALT keys need the keymap](gpc-editor-alt-keys-need-the-keymap.md)
- [VERA FX cache writes are aligned](vera-fx-cache-write-is-aligned.md) — the row renderer needs an EVEN column
- [GPC-HELP scroll cost is the file read](gpc-help-scroll-cost-is-the-file-read.md) — FIXED: loaded once, table in bank 9, text in 15-22
- [HELP source viewer state](help-source-viewer-state.md) — committed in 9e98e96, the user tested it in the emulator; [MSEDIT is the colouring master](msedit-is-the-syntax-colouring-master.md)
- [HOSTFS is not the DIR slowness](hostfs-is-not-the-dir-slowness.md) — XFMGR is much faster on the same host; the 2 s is our read loop
- [Bar and dropdown drive each other](menubar-menuhelp-cross-axis-exits.md) — DOWNEXIT and KEYEXIT; [use the whole interface](menuhelp-use-the-whole-interface.md)

## The CUA GUI library
- [LISTS and DIR plan](lists-and-dir-plan.md) — lists read GP.BSTR-layout banks; LIST.SORT written and awaiting its run
- [GUI-CUA phase 5 state](gui-cua-phase5-state.md) — written not verified; what is owed
- [Demo project options](demo-project-options.md) — the six showcase ideas and their state; [KV-BANKED is deleted, never mention it](kv-banked-is-out-of-this-release.md)
- [CMDR-DOS modify mode, measured](cmdr-dos-modify-mode-measured.md) — `,M` overwrites in place, `,A` appends, paths work; KVBIN timings

## The BASL cruncher
- [Folding onto a label line saves nothing](folding-onto-a-label-line-saves-nothing.md) — a bare label is not a BASIC line
- [BASL cruncher built](basl-cruncher-built.md) — GPC-BASIC-TOOLS-SRC/cruncher; 255 bytes on the editor
- [BASL cruncher internals](basl-cruncher-internals.md) — routine map and build cycle; the harness is NOT in the repo
- [All three line endings](basl-sources-use-all-three-line-endings.md) — how to sniff; a short CR file reads as CRLF

## BASLOAD
- [BASIC RAM was the tokenise ceiling](basload-basic-ram-is-the-tokenise-ceiling.md) — REMOVED for build_basl.py only
- [BASLOAD streams to a file](basload-streams-to-a-file.md) — SHIPPED; a failed run now deletes its own output
- [BASLOAD runs from RAM unmodified](basload-runs-from-ram-unmodified.md) — the ROM source builds as a plain PRG
- [BASLOAD name space, widened](basload-name-space-widened.md) — about 950 two-character names until 2026-10-03, now about 1,135; BASLOAD errors cleanly past `_Z`
- [BASLOAD #DEFINE rejects digits and negatives](basload-define-rejects-digits.md) — INVALID PARAMETER, silent 6-byte PRG; unsigned only
- [Labels and variables collide](basload-label-and-variable-collide.md) — DUPLICATE SYMBOL; the $ does not separate them
- [A define eats a longer name](basload-define-eats-a-longer-name.md) — `#DEFINE X.W` turns `X.W%` into `44%`; SYNTAX ERROR at run time
- [#AUTONUM breaks STRCASE](basload-autonum-breaks-strcase.md) — do not write it
- [TRUE is -1](gpc-basl-true-is-minus-one.md) — why NOT needs -1, and the two spellings that break

## X16 BASIC semantics (ROM-verified — apply to any compiler)
- [IF semantics](gpc-if-semantics.md) — a false IF skips the WHOLE line. Blitz gets this right.
- [FOR STEP 0 semantics](gpc-for-step0-semantics.md) — STEP 0 needs EXACT equality. FIXED 2026-07-13 in `next.asm` and `for.asm`
- [FOR 1 TO 0 runs once](gpc-basic-for-loop-runs-once.md) — guard every FOR 1 TO LEN()
- [Empty INPUT gives ""](gpc-input-empty-line.md) — FIXED; ROM keeps the old value, a chosen divergence
- [GPC JOY high byte diverges](gpc-joy-high-byte-diverges.md) — FIXED in runtime build 129
- [GPC PSGVOL and FMVOL were inverted](gpc-psgvol-fmvol-inverted.md) — FIXED in runtime build 130
- [X16 BASIC conformance](blitz-x16-basic-conformance.md) — 4 defects fixed, PEEK/SYS ROM bank fixed in build 133; `SLEEP 0` still diverges
- [Interpreter LOAD chain is safe](x16-interpreter-load-chain-is-safe.md) — R49 moves VARTAB
- [No END crashes at exit](program-without-end-crashes.md) — end every test program with END
- [X16 BASIC coverage](gpc-x16-basic-coverage.md) — the 7 lexer blockers on valid X16 BASIC
- [R44+ keywords](blitz-x16-r44-plus-keywords.md) — CLOSED: all 10 are in; do not re-fix

## Performance
- [C64 Blitz benchmark yardstick](blitz-c64-benchmark-yardstick.md) — real C64 Blitz is ~2.6x stock
- [Arrays share the workspace](blitz-arrays-share-the-workspace.md) — no array heap; DIM raises OUT OF MEMORY
- [Array index fast path](gpc-array-index-fastpath.md) — worth ~31%; watch the OOB short-circuit
- [STRCASE call overhead, measured](strcase-call-overhead-measured.md) — ~2,570 cycles a call
- [GP.ASM {VAR} symbol lookup, FIXED](gpasm-var-lookup-rescans-symfile.md) — FIXED: read once into a bank cache, now 24-27

## X16 platform / toolchain
- [PRINT and SCREEN drop the input channel](print-and-screen-drop-the-input-channel.md) — re-CHKIN before every MACPTR
- [MACPTR wraps banks itself](macptr-wraps-banks-itself.md) — the caller that wants it is STASH, not FILEDIR
- [Scrolling a screen region](scrolling-a-screen-region.md) — no GP command; three ways to do it by hand
- [GP drawing targets layer 1](gp-drawing-targets-layer-1.md) — no row clamp, and L1_MAPBASE is POKEable
- [P-code runs from a bank, PROVEN](pcode-runs-from-a-bank-proven.md) — no ABI change; RETURN out needs no bank restore
- [GP.BANKED region relocation](gp-banked-region-relocation.md) — the rotation and two GOTOs that move it
- [GP.BANKEDSTR: literal text in a bank](gp-bankedstr-literal-text-in-a-bank.md) — BUILT; +3,840 B on GPBMODS
- [Object file must fit under the runtime](object-file-must-fit-under-the-runtime.md) — regions were invisible to the fit check
- [Wildcard scratch eats the source](wildcard-scratch-eats-the-source.md) — S0:NAME.B* matches NAME.BASL
- [One NAME.OVL holds every region](region-overlay-ovl-file.md) — BUILT; banks 2-255, 127 regions, read through ACPTR
- [Banked error address can't be placed](banked-error-address-unplaceable.md) — FIXED in runtime build 128: a region error prints `$bb:AAAA`
- [Object writer: regions vs low code](object-writer-regions-vs-low-code.md) — the streamer pads forward 65,535 bytes unchecked
- [Overlay inside the PRG: research](overlay-in-prg-research.md) — option D decided: one PRG up to 39,679, PRG + .OVL above; LOAD must never print ?OUT OF MEMORY
- [A second region for the utilities](second-region-for-the-utilities.md) — BUILT; a BANK statement is the only disqualifier; a GOTO across is refused
- [Banked code loses the bank on a call out](gp-banked-call-out-loses-the-bank.md) — a region may not BANK itself back; every call into a region is .bgosub
- [FILEDIR banks whole](filedir-bank-split.md) — BUILT; the switch moved into its two blobs
- [GPBMODS resident p-code breakdown](gpbmods-resident-pcode-breakdown.md) — the shell is 79%, all eight modules 21%
- [Dead-code elimination, measured](basl-dead-code-elimination-measured.md) — 691 B free by deleting two #INCLUDEs; plan in docs/blitz/DEAD-CODE-ELIMINATION.PLAN.md
- [VRAM-to-VRAM memory_copy limits](vram-to-vram-memory-copy-limits.md) — 15,360 in one call; descending overlap is safe
- [Array element sizes, measured](array-element-sizes-measured.md) — a `%` array is TWO bytes an element, untyped SIX
- [INT16 conversion planned](int16-conversion-planned.md) — the TURBO GUI change converts its 14 modules; the rest before release; int16scan.py is the check, but not for an address a caller hands in
- [Byte data type feasibility](byte-data-type-feasibility.md) — STUDY ONLY; the opcode space refuses byte SCALARS
- [KERNAL preserves the RAM bank](kernal-preserves-ram-bank.md) — measure it in asm, PEEK(0) cannot see it
- [Change a called vector with one POKE](change-a-called-vector-with-one-poke.md) — the runtime polls STOP via $0328 every 16 words; two POKEs crash between them
- [X16 ROM internal calls](x16-rom-internal-calls.md) — verified R49 dispatcher/GC addresses and ZP pointers
- [X16 toolchain](x16-toolchain.md) — 64tass, emulator and Prog8 12.0.1 paths on this machine
- [x16emu -echo doubling](x16emu-echo-doubling.md) — non-warp `-echo raw` prints every char TWICE
- [Memory is git-tracked](memory-is-git-tracked.md) — via a junction that must survive renames
- [Blitz-X16 prior attempt](blitz-x16-prior-attempt.md) — the earlier Prog8 self-hosted compiler, now deleted
- [Prog8 PETSCII char literals](prog8-petscii-charlits.md) — legacy; only if Prog8 comes back
