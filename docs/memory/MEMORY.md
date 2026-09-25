# Memory Index

Knowledge base for the Blitz-X16 compiler. `gpc-*` notes are facts about **X16 BASIC or the X16
itself**, not GPC internals. **This folder is the live auto-memory**, reached by a directory
junction that broke once when the project was renamed — **re-make it first** if a rename moves it
again. See [memory-is-git-tracked](memory-is-git-tracked.md).

## How to work in this repo
- [Answer the question asked](answer-the-question-asked.md) — lead with the number asked for; and [measure before changing code](measure-before-changing-code.md), probes beat edit-and-see
- [Review findings must be reachable](review-findings-must-be-reachable.md) — drop anything only invalid source or a typo triggers
- [Prose style is flat reference](prose-style-is-flat-reference.md) — five settled rules, `doc-style` owns them; [help topics are current behaviour only](help-topic-writing-rules.md); [HLP files carry hand edits](hlp-files-carry-hand-edits.md), so patch the render delta
- [Write readable code, user crunches](write-readable-code-user-crunches.md) — one statement a line, an unexplained SRC edit is his crunch pass; [comments light](comments-light-code-should-flow.md), heavy REMs mean bad naming
- [Ask before writing asm](ask-before-writing-asm.md) — standing order: agree GP.ASM or 64tass first
- [Keep Claude's files off the root](keep-claude-files-off-the-root.md) — source/drive and source/scratch are Claude's; the root is the user's
- [Commit to main directly](commit-to-main-directly.md) — solo repo, no branch; [never commit OASIS](never-commit-oasis.md), stage by name
- [Compiler must not cap program size](compiler-must-not-cap-program-size.md) — a build-side wall is a bug; and [no backward compatibility](no-backward-compatibility-needed.md), replaced layers get ripped out
- [Library working copy, then root](library-working-copy-then-root.md) — edit in GPC-BASIC-TOOLS-SRC/GPB-MODS-TESTING/GPC-BASIC/, drift runs BOTH ways; [test in GPBMODS first](test-in-gpbmods-before-spreading.md); [samples build in place](samples-build-in-place.md), never staged into source/drive/
- [GUI only through verbs](gui-only-through-verbs.md) — no GOSUB GUI.* in a program; forms and pickers become verbs like MENU
- [No ship language, no unasked builds](no-ship-language-this-is-dev.md) — [run builds in the background](run-builds-in-background.md), a typed message cancels an in-flight tool; [build, report, hand it back](build-report-dont-investigate.md)
- [Compile shared, not embedded](compile-shared-not-embedded.md) — SHARED is the p-code number
- [The compiler is GPC](name-the-compiler-gpc.md) — "Blitz" is a heritage nod; and [concurrent agents run here](user-runs-concurrent-agents-here.md), so re-read before any write
- [Compact early, not at the end](compact-early-not-at-the-end.md) — remind the user to /compact at the end of EVERY turn that lands a step; cost is context size x turns

## Build and toolchain
- [Build toolchain location](build-toolchain-location.md) — make, 64tass, python are off-PATH in C:\8bitProgramming; build setup is in docs/BUILDING.md
- [Git Bash sed strips CRLF](git-bash-sed-strips-crlf.md) — `sed -i` writes LF and `grep -c $'\r$'` lies; count with Python bytes
- [App make skips compiler.library](app-make-does-not-rebuild-compiler-library.md) — use `make libs`; [it does not install the runtime](make-libs-does-not-install-the-runtime.md) either; [the baseline is the application copy](baseline-compiler-is-the-application-copy.md), source/drive/GPC.BIN can be stale
- [Measure p-code per module](measure-pcode-per-module.md) — map plus SYM gives bytes per include and routine
- [Headless BASL build recipe](headless-basl-build-recipe.md) — the three emulator runs and their stop conditions; [a timeout once faked success](compile-shared-timeout-fakes-success.md), the banner is the finish line
- [GPC.ERR builds in its sample folder](gpcerr-builds-in-its-sample-folder.md) — never standalone
- [Runtime storage is the golden RAM](runtime-storage-is-golden-ram.md) — $0400 to StorageEnd, which MOVES; a test routine goes at $0780; [tests share the product's memory](tests-share-the-products-memory.md)
- [/GPC/NAME opens from any folder](gpc-home-path-form.md) — measured on R49 hostfs; the plain form works, no CMD syntax needed
- [Paste can't drive a running program](paste-cannot-drive-a-running-program.md) — use a fixed-answer variant. x16emu r49 runs tests, Box16 debugs
- [File I/O dies in a GP.DO key loop](file-io-error-in-gpdo-key-loop.md) — the seven shapes already ruled out
- [Retired keyword defers to runtime](retired-keyword-defers-to-runtime.md) — stale callers compile clean and explode

## GP.BASIC — the GP block and inline assembly
- [GP.DEFPROC one-line calls](gp-defproc-one-line-calls.md) — BUILT; formals are shared, so a body must not call its own verb
- [GP.FN string RETURNS aliased, FIXED](gp-fn-string-returns-aliases.md) — FIXED 2026-09-13: a string GP.FN concats "" into a temporary, 3 B a call site
- [Block GP.IF design](gpb-block-if-design.md) — SHIPPED at 14 runtime bytes; [block openers must not defer](gpb-block-openers-must-not-defer.md), .error_syntax corrupts enclosing nesting
- [GOTO out of a GP block](gpb-goto-out-of-block-design.md) — BUILT: .unwind opcode, zero runtime bytes; [RETURN unwinds frames](gpc-return-unwinds-frames.md) out of FOR/GP.DO/GP.SELECT
- [GP.ASM implementation status](gpasm-implementation-status.md) — shipped; dotted {VAR} names, self-patching operands; [fixups retired by two passes](gpasm-fixups-retired-by-two-passes.md), the 128-reference cap is gone; [where the research doc is](gpasm-inline-assembly-research.md)
- [GP.ASM label cannot start with A](gpasm-label-cannot-start-with-a.md) — the operand parser tests accumulator mode first, a real defect; [blobs may use zTemp0/1/2](gpasm-blob-may-use-ztemp.md)
- [GP.STRPTR points at the length byte](gp-strptr-points-at-the-length-byte.md) — text starts at +1
- [GP draw under a re-ordered font](gp-draw-under-a-reordered-font.md) — only GP.BOX style 0 survives

## Compiler limits, memory and banking
- [Scalar variable space caps at 4,096 bytes](scalar-variable-space-caps-at-4096.md) — 11-bit halved operand, now checked; [every scalar was allocated 6 bytes](every-scalar-allocated-six-bytes.md), FIXED 2026-09-20, GPBMODS 4,322 -> 3,482
- [PROGRAM TOO BIG was the workspace](program-too-big-fires-early.md) — FIXED; a bank per table, 4,096 lines; [OUT OF MEMORY $02B8](gpbmods-out-of-memory-02b8.md) was StartRuntime never setting X
- [SHARED p-code cap is RTBASE](gpc-shared-pcode-cap-is-rtbase.md) — 22,016 bytes, not $9F00; [the full slack table](gpc-blitz-runtime-slack-and-limits.md) — LOW FREE minus 4096 is the headroom
- [Run-side workspace, read from the PRG](run-side-workspace-read-from-the-prg.md) — two bootstrap page numbers give the budget; [52 B cushion below GPBase](gpc-core-page-cushion-below-gpbase.md)
- [Compiler-emitted bank switch](compiler-emitted-bank-switch.md) — .bgosub emitted, twins merged, shims deleted 2026-09-14; [banks work in progress](banks-work-in-progress.md) — ALL-BANKS done, HANDLER-BANK at step 28, both uncommitted
- [Opcode numbers follow handler order](opcode-numbers-follow-handler-order.md) — moving a `;;` handler renumbers p-code; open a section per handler instead
- [Library sizes owed to help](library-sizes-belong-in-help.md) — runtime 10,956 B always; GPC-BASIC costs only what you #INCLUDE
- [Runtime footprint](blitz-x16-runtime-footprint.md) — 10,956 B in every program, and how to shrink it
- [String heap scavenger](string-heap-scavenger.md) — SHIPPED: dead blocks reused, +1 page RT; [string blocks never shrink](gpc-string-blocks-never-shrink.md), never build a big temporary
- [BINPUT# caps at 255 bytes](binput-caps-at-255-bytes.md) — three caps land on one number; it is a CHRIN loop
- [LOAD chain clears memory](load-chain-clears-memory.md) — the variable carry is GONE; no leak, no CLR needed
- [Two-pass compiler](two-pass-compiler.md) — DONE; the compiler's own size bounds nothing, and [compile is write-only](compile-is-write-only.md) is the premise it rests on
- [Compiler overlay into a bank](compiler-overlay-into-a-bank.md) — REVERTED, but the mechanism works; [banking strings scales with length](banking-strings-scales-with-length.md), the menus barely broke even
- [BANK, not POKE 0](gpc-bank-statement-not-poke-zero.md) — PEEK/POKE restore the bank around every access; [STASH now restores the caller's bank](stash-leaves-its-bank-selected.md)
- [Claim every compile-time bank](claim-every-compile-time-bank.md) — BANKMGR.CLAIM before the first ALLOC
- [color-test sample state](color-test-sample-state.md) — parked 2026-09-06; four loose ends
- [XBase engine planned](xbase-engine-planned.md) — skeleton on disk, GUI in bank 4, 255 bytes a record to find
- [GPC.GUI: defs into a folder next](gpc-gui-next-defs-in-a-folder.md) — GPC-GUI-DATA, asked 2026-09-16, not started; [size is not a constraint](gpc-gui-size-not-a-constraint.md), do not price features in bytes
- [BUILD ALL: a sixth GPC.INPUT line](gpc-input-sixth-line-chain.md) — agreed route, asm not written

## The editor sample
- [Editor branch state, GUI next](gpc-editor-branch-and-gui-next.md) — the self-check lines to keep green
- [ED-STORE 255.BASL is test data](editor-test-fixture-files.md) — the editor opens it; not dead source, do not flag it
- [The editor's slow RETURN](editor-return-is-the-line-table.md) — FIXED at 87x, the 2048-entry boundary is the trap; [the LINPUT# loader](gpc-editor-loader-linput-and-blob.md) — 10.5x over GET#, ST=66 on a missing file
- [Editor: ASCII inside, PETSCII outside](gpc-editor-is-ascii-inside-petscii-outside.md) — why the font is re-ordered in VRAM; [ALT keys need the keymap](gpc-editor-alt-keys-need-the-keymap.md), in ISO mode ALT+F sends nothing
- [VERA FX cache writes are aligned](vera-fx-cache-write-is-aligned.md) — the row renderer needs an EVEN column
- [GPC-HELP scroll cost is the file read](gpc-help-scroll-cost-is-the-file-read.md) — the .HLP is re-read every keypress
- [HOSTFS is not the DIR slowness](hostfs-is-not-the-dir-slowness.md) — XFMGR is much faster on the same host; the 2 s is our read loop. QUEUED after LISTS/DIR
- [Bar and dropdown drive each other](menubar-menuhelp-cross-axis-exits.md) — DOWNEXIT and KEYEXIT are the two halves; [use the whole interface](menuhelp-use-the-whole-interface.md), build the library's own example first

## The CUA GUI library
- [LISTS and DIR plan](lists-and-dir-plan.md) — lists read GP.BSTR-layout banks at run time; LIST.BANK and FILEPICK tested, LIST.SORT written and awaiting its run
- [GUI-CUA phase 5 state](gui-cua-phase5-state.md) — written not verified; what is owed and what still drifts

## The BASL cruncher
- [Folding onto a label line saves nothing](folding-onto-a-label-line-saves-nothing.md) — a bare label is not a BASIC line
- [BASL cruncher built](basl-cruncher-built.md) — GPC-BASIC-TOOLS-SRC/cruncher; 255 bytes on the editor
- [BASL cruncher internals](basl-cruncher-internals.md) — routine map and build cycle; the harness is NOT in the repo
- [All three line endings](basl-sources-use-all-three-line-endings.md) — how to sniff; a short CR file reads as CRLF

## BASLOAD
- [BASIC RAM was the tokenise ceiling](basload-basic-ram-is-the-tokenise-ceiling.md) — REMOVED for build_basl.py only
- [BASLOAD streams to a file](basload-streams-to-a-file.md) — SHIPPED; a failed run now deletes its own output
- [BASLOAD runs from RAM unmodified](basload-runs-from-ram-unmodified.md) — the ROM source builds as a plain PRG
- [BASLOAD #DEFINE rejects digits and negatives](basload-define-rejects-digits.md) — INVALID PARAMETER, silent 6-byte PRG; unsigned only; no #INCLUDE is optional
- [Labels and variables collide](basload-label-and-variable-collide.md) — DUPLICATE SYMBOL; the $ does not separate them
- [#AUTONUM breaks STRCASE](basload-autonum-breaks-strcase.md) — do not write it
- [TRUE is -1](gpc-basl-true-is-minus-one.md) — why NOT needs -1, and the two spellings that break

## X16 BASIC semantics (ROM-verified — apply to any compiler)
- [IF semantics](gpc-if-semantics.md) — a false IF skips the WHOLE line. Blitz gets this right.
- [FOR STEP 0 semantics](gpc-for-step0-semantics.md) — STEP 0 needs EXACT equality. **Blitz gets this wrong.**
- [FOR 1 TO 0 runs once](gpc-basic-for-loop-runs-once.md) — guard every FOR 1 TO LEN()
- [X16 BASIC conformance](blitz-x16-basic-conformance.md) — 4 real defects fixed; `SLEEP 0` returns at once and still diverges
- [No END crashes at exit](program-without-end-crashes.md) — runs off the last line into $ffff; end every test program with END
- [X16 BASIC coverage](gpc-x16-basic-coverage.md) — the 7 lexer blockers on valid X16 BASIC
- [R44+ keywords](blitz-x16-r44-plus-keywords.md) — CLOSED: all 10 are in; do not re-fix

## Performance
- [C64 Blitz benchmark yardstick](blitz-c64-benchmark-yardstick.md) — real C64 Blitz is ~2.6x stock
- [Arrays share the workspace](blitz-arrays-share-the-workspace.md) — no array heap; DIM raises OUT OF MEMORY
- [Array index fast path](gpc-array-index-fastpath.md) — worth ~31%; watch the OOB short-circuit
- [STRCASE call overhead, measured](strcase-call-overhead-measured.md) — ~2,570 cycles a call
- [GP.ASM {VAR} symbol lookup, FIXED](gpasm-var-lookup-rescans-symfile.md) — was 95% of GPBMODS compile; now read once into banks 13-14, 317 s to 20 s

## X16 platform / toolchain
- [MACPTR wraps banks itself](macptr-wraps-banks-itself.md) — the caller that wants it is STASH, not FILEDIR
- [Scrolling a screen region](scrolling-a-screen-region.md) — no GP command; three ways to do it by hand
- [GP drawing targets layer 1](gp-drawing-targets-layer-1.md) — no row clamp, and L1_MAPBASE is POKEable
- [P-code runs from a bank, PROVEN](pcode-runs-from-a-bank-proven.md) — no ABI change; RETURN out needs no bank restore
- [GP.BANKED region relocation](gp-banked-region-relocation.md) — the rotation and two GOTOs that move it
- [GP.BANKEDSTR: literal text in a bank](gp-bankedstr-literal-text-in-a-bank.md) — BUILT; +3,840 B on GPBMODS
- [Object file must fit under the runtime](object-file-must-fit-under-the-runtime.md) — regions were invisible to the fit check
- [Wildcard scratch eats the source](wildcard-scratch-eats-the-source.md) — S0:NAME.B* matches NAME.BASL
- [One NAME.OVL holds every region](region-overlay-ovl-file.md) — BUILT; banks 2-255, 127 regions; bank and page count ahead of each region, $01 end marker, read through ACPTR
- [Object writer: regions vs low code](object-writer-regions-vs-low-code.md) — the streamer pads forward 65,535 bytes with no check firing
- [Overlay inside the PRG: research](overlay-in-prg-research.md) — the option C plan came out of it; a LOADed file caps at 39,679 bytes total
- [A second region for the utilities](second-region-for-the-utilities.md) — BUILT; a BANK statement is the ONLY disqualifier; regions call each other, a GOTO across is refused
- [Banked code loses the bank on a call out](gp-banked-call-out-loses-the-bank.md) — a region may not BANK itself back; every call into a region is now .bgosub, library shims gone
- [FILEDIR banks whole](filedir-bank-split.md) — BUILT; the switch moved into its two blobs
- [GPBMODS resident p-code breakdown](gpbmods-resident-pcode-breakdown.md) — the shell is 79%, all eight modules 21%
- [Dead-code elimination, measured](basl-dead-code-elimination-measured.md) — 691 B free by deleting two #INCLUDEs; compiler-option plan in docs/blitz/DEAD-CODE-ELIMINATION.PLAN.md
- [VRAM-to-VRAM memory_copy limits](vram-to-vram-memory-copy-limits.md) — 15,360 in one call; descending overlap is safe
- [Array element sizes, measured](array-element-sizes-measured.md) — a `%` array is TWO bytes an element, untyped SIX
- [INT16 conversion planned](int16-conversion-planned.md) — not started; handoff in GPB-MODS-TESTING, int16scan.py is the check
- [Byte data type feasibility](byte-data-type-feasibility.md) — STUDY ONLY; the opcode space refuses byte SCALARS
- [KERNAL preserves the RAM bank](kernal-preserves-ram-bank.md) — measure it in asm, PEEK(0) cannot see it
- [X16 ROM internal calls](x16-rom-internal-calls.md) — verified R49 dispatcher/GC addresses and ZP pointers
- [X16 toolchain](x16-toolchain.md) — 64tass and emulator paths on this machine
- [x16emu -echo doubling](x16emu-echo-doubling.md) — non-warp `-echo raw` prints every char TWICE
- [Memory is git-tracked](memory-is-git-tracked.md) — versions with the project, via a junction that must survive renames
- [Blitz-X16 prior attempt](blitz-x16-prior-attempt.md) — the earlier Prog8 self-hosted compiler, now deleted
- [Prog8 PETSCII char literals](prog8-petscii-charlits.md) — legacy; only if Prog8 comes back
