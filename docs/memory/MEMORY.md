# Memory Index

Knowledge base for the Blitz-X16 compiler. The `gpc-*` notes are what survived the prune of the
abandoned sibling project (GPC): everything kept here is a fact about **X16 BASIC or the X16 itself**,
not about GPC's internals. The rest are recoverable from git history (commit `0f3f82b`).

> **This folder is the live auto-memory**, reached through a directory junction from
> `~/.claude/projects/c--dev-CmdrX16-dos-tools-x16-blitz-compiler/memory`. The junction broke when
> the project was renamed from `X16-GPCompiler`, so 44 notes accumulated untracked between
> 2026-08-30 and 2026-09-04 before being merged back in here. See
> [Memory is git-tracked](memory-is-git-tracked.md) — **if a rename ever moves the project again,
> re-make the junction first.**

## How to work in this repo
- [Answer the question asked](answer-the-question-asked.md) — lead with the number asked for; no adjacent easier problem, no edge cases nobody writes
- [Measure before changing code](measure-before-changing-code.md) — FRE probes found in 2 minutes what 2 rounds of edits missed
- [Prose style is flat reference](prose-style-is-flat-reference.md) — the five settled rules for comments and help text; the `doc-style` agent owns them
- [Write readable code, user crunches](write-readable-code-user-crunches.md) — one statement a line, plain IF for one statement, never a statement on a label line
- [Comments light, code should flow](comments-light-code-should-flow.md) — a note or two, not essays; heavy REMs mean bad naming
- [No ship language, no unasked builds](no-ship-language-this-is-dev.md) — dev and test work only; "commit and push" does not include a build
- [Commit to main directly](commit-to-main-directly.md) — do not branch first; solo repo, no review step
- [Compiler must not cap program size](compiler-must-not-cap-program-size.md) — standing rule: a build-side wall is a bug, report costs in max program size
- [No backward compatibility needed](no-backward-compatibility-needed.md) — sole user; token renumbering and forced recompiles cost nothing
- [Ask before writing asm](ask-before-writing-asm.md) — standing order: no GP.ASM or 64tass without agreeing it first
- [The compiler is GPC](name-the-compiler-gpc.md) — "Blitz" is a heritage nod to the C64 compiler; all the code here is the user's own
- [User runs concurrent agents here](user-runs-concurrent-agents-here.md) — default to read-only research; re-read before any write
- [Compile shared, not embedded](compile-shared-not-embedded.md) — standing: SHARED is the p-code number; GPC-HELP stays uncrunched
- [Library working copy, then root](library-working-copy-then-root.md) — edit modules in samples/GPB-MODS-TESTING/GPC-BASIC/, copy to root only when they pass

## Build and toolchain
- **Build setup** — *(note missing: linked by the index but never committed)* how to build it, and the 5 blockers that made a fresh clone unbuildable on any OS. See docs/BUILDING.md.
- [Build toolchain location](build-toolchain-location.md) — make, 64tass and python are off-PATH in C:\8bitProgramming
- [Measure p-code per module](measure-pcode-per-module.md) — the map file plus the SYM give exact bytes per include and per routine
- [Headless BASL build recipe](headless-basl-build-recipe.md) — the three emulator runs and the stop conditions that keep a cycle to ~70s
- [GPC.ERR builds shared, in the main dir](gpcerr-build-shared-in-main-dir.md) — never standalone; the headless harness builds the wrong kind
- [Tests share the product's memory](tests-share-the-products-memory.md) — the harness was 3,615 B of workspace; and BASLOAD does not nest #IFNDEF
- [Paste can't drive a running program](paste-cannot-drive-a-running-program.md) — test an interactive front end with a generated fixed-answer variant
- [File I/O dies in a GP.DO key loop](file-io-error-in-gpdo-key-loop.md) — writes the file, then INPUT/OUTPUT ERROR; the seven shapes already ruled out
- [Retired keyword defers to runtime](retired-keyword-defers-to-runtime.md) — stale callers compile clean and explode; grep testing/ too
- **Emulator split** — *(note missing: linked by the index but never committed)* x16emu r49 runs the tests, Box16 is for debugging.

## GP.BASIC — the GP block and inline assembly
- [Block GP.IF design](gpb-block-if-design.md) — SHIPPED at 14 runtime bytes; why it was 14 not 12, and the headless emulator test recipe
- [Block openers must not defer](gpb-block-openers-must-not-defer.md) — .error_syntax rolls a statement back and silently corrupts enclosing block nesting
- [GOTO out of a GP block](gpb-goto-out-of-block-design.md) — BUILT: .unwind opcode, zero runtime bytes, and the four traps each build cost
- [RETURN unwinds frames](gpc-return-unwinds-frames.md) — StackFindFrame closes what it passes, so RETURN out of a FOR/GP.DO/GP.SELECT is safe
- [GP.ASM implementation status](gpasm-implementation-status.md) — shipped; dotted {VAR} names, the self-patching-operand idiom, and the 123x editor render numbers
- [GP.ASM inline assembly research](gpasm-inline-assembly-research.md) — where the research doc lives, what was decided, what is still open
- [GP.ASM blobs may use zTemp0/1/2](gpasm-blob-may-use-ztemp.md) — SYS already clobbers zTemp0 to get there, so `(ptr),y` is available
- [GP.STRPTR points at the length byte](gp-strptr-points-at-the-length-byte.md) — text starts at +1; forgetting it corrupts only the short lines
- [GP draw under a re-ordered font](gp-draw-under-a-reordered-font.md) — only GP.BOX style 0 survives, and GP.FILL converts its glyph argument (+$40)

## Compiler limits, memory and banking
- [PROGRAM TOO BIG was the workspace](program-too-big-fires-early.md) — FIXED with a RAM bank per table; three raise sites, and the real max program size
- [GPC Blitz runtime slack and limits](gpc-blitz-runtime-slack-and-limits.md) — measured memory layout; the run-side ceiling, quotable as FREE minus 4096
- [Core page cushion below GPBase](gpc-core-page-cushion-below-gpbase.md) — only ~40 B of padding; cross it and every program grows 256 B
- [Runtime footprint](blitz-x16-runtime-footprint.md) — the 10,956 B runtime copied into every program, and how to shrink it
- [String heap scavenger](string-heap-scavenger.md) — SHIPPED: dead blocks reused, +1 page RT; the intermittent OOM was no-reclaim plus a garbage line-0 read
- [String blocks never shrink](gpc-string-blocks-never-shrink.md) — a big temporary must not be built; freeing it is not a thing
- [Banking strings: length, not count](banking-strings-scales-with-length.md) — the menus broke even at 249 saved vs 245 spent
- [BANK, not POKE 0](gpc-bank-statement-not-poke-zero.md) — PEEK/POKE restore the bank around every access, so POKE 0 can never select one
- [STASH leaves its bank selected — FIXED](stash-leaves-its-bank-selected.md) — it now restores the caller's bank; what the symptom looked like, and why it named the wrong routine

## The editor sample
- [Editor branch state, GUI next](gpc-editor-branch-and-gui-next.md) — the self-check lines to keep green
- [The editor's slow RETURN](editor-return-is-the-line-table.md) — FIXED at 87x with a GP.ASM memmove; the 2048-entry segment boundary is the trap
- [LINPUT# loader, and its NUL trap](gpc-editor-loader-linput-and-blob.md) — 10.5x over GET#; ST=66 on a missing file, for ever
- [Editor: ASCII inside, PETSCII outside](gpc-editor-is-ascii-inside-petscii-outside.md) — why the font is re-ordered in VRAM
- [ALT keys need the keymap](gpc-editor-alt-keys-need-the-keymap.md) — in ISO mode ALT+F sends nothing; rewrite the layout table at $A000 bank 0
- [VERA FX cache writes are aligned](vera-fx-cache-write-is-aligned.md) — the row renderer needs an EVEN text column
- [GPC-HELP scroll cost is the file read](gpc-help-scroll-cost-is-the-file-read.md) — the cell move was 4%; the .HLP is re-read every keypress
- [Bar and dropdown drive each other](menubar-menuhelp-cross-axis-exits.md) — MENUBAR.DOWNEXIT and MENUHELP.KEYEXIT are the two halves
- [MENUHELP: use the whole interface](menuhelp-use-the-whole-interface.md) — build the library's own example headlessly before blaming it

## The BASL cruncher
- [BASL cruncher built](basl-cruncher-built.md) — samples/cruncher: 255 lines, 255 bytes on the editor; and the three guesses it disproved
- [BASL cruncher internals](basl-cruncher-internals.md) — routine map, the two join properties, the build cycle; the harness is NOT in the repo
- [All three line endings](basl-sources-use-all-three-line-endings.md) — how to sniff, and why a short CR file reads as CRLF

## BASLOAD
- [BASLOAD #DEFINE rejects digits](basload-define-rejects-digits.md) — GUI2.DEFS is INVALID PARAMETER but GUI2.SEL is fine; and no #INCLUDE is ever optional
- [Labels and variables collide](basload-label-and-variable-collide.md) — DUPLICATE SYMBOL, and the $ does not separate FOO from FOO$
- [#AUTONUM breaks STRCASE](basload-autonum-breaks-strcase.md) — do not write it; it sets the STEP, and only the default 1 survives STRCASE

## X16 BASIC semantics (ROM-verified — apply to any compiler)
- [IF semantics](gpc-if-semantics.md) — a false IF skips the WHOLE line, not just the first statement. Blitz gets this right.
- [FOR STEP 0 semantics](gpc-for-step0-semantics.md) — NEXT exits iff sign(loopvar−limit)==sign(step); STEP 0 needs EXACT equality. **Blitz gets this wrong.**
- [FOR 1 TO 0 runs once](gpc-basic-for-loop-runs-once.md) — the string-walk idiom turns an empty string into CHR$(0); guard every FOR 1 TO LEN()
- [X16 BASIC conformance](blitz-x16-basic-conformance.md) — Blitz vs stock BASIC: 4 real defects (float literals, STEP 0, sci notation, reversed relops)
- [X16 BASIC coverage](gpc-x16-basic-coverage.md) — the 7 lexer blockers on valid X16 BASIC (hex, binary, .5, >=65536, 9.2E5, long names, `=<` `=>` `><`)
- [R44+ keywords](blitz-x16-r44-plus-keywords.md) — 10 keywords added after R43 that Blitz doesn't know + a LINPUT/LINPUT# token swap

## Performance
- [C64 Blitz benchmark yardstick](blitz-c64-benchmark-yardstick.md) — real C64 Blitz ≈2.6× vs stock BASIC; the bar to beat
- [Arrays share the workspace](blitz-arrays-share-the-workspace.md) — no array heap; DIM raises OUT OF MEMORY, and the old 409/512 figures were the dead Prog8 GPC
- [Array index fast path](gpc-array-index-fastpath.md) — 1-D indexing fast path was worth ~31%; incl. the OOB short-circuit gotcha

## X16 platform / toolchain
- [Scrolling a screen region](scrolling-a-screen-region.md) — no GP command for it; STASH moved, VERA-to-VERA memcopy, or a masked layer
- [GP drawing targets layer 1](gp-drawing-targets-layer-1.md) — only layer 1, but no row clamp and L1_MAPBASE is POKEable
- [P-code runs from a bank, PROVEN](pcode-runs-from-a-bank-proven.md) — executed at $A000 with two GP.ASM blobs and no ABI change; RETURN out needs no bank restore
- [GP.BANKED region relocation](gp-banked-region-relocation.md) — the region moves to the end of the object with a rotation and two GOTOs to line numbers; the three things holding a buffer address
- [KERNAL preserves the RAM bank](kernal-preserves-ram-bank.md) — CHROUT, GETIN, scroll, CLS and screen_mode all leave $00 alone; measure it in asm, PEEK(0) cannot see it
- [X16 ROM internal calls](x16-rom-internal-calls.md) — verified R49 dispatcher/GC addresses + ZP pointers
- [X16 toolchain](x16-toolchain.md) — 64tass / emulator paths on this machine
- [x16emu -echo doubling](x16emu-echo-doubling.md) — non-warp `-echo raw` prints every char TWICE
- [Memory is git-tracked](memory-is-git-tracked.md) — this folder versions with the project, via a junction that must survive renames
- [Blitz-X16 prior attempt](blitz-x16-prior-attempt.md) — the earlier Prog8 self-hosted compiler (now deleted from disk)
- [Prog8 PETSCII char literals](prog8-petscii-charlits.md) — legacy; only relevant if Prog8 comes back
- [STRCASE call overhead, measured](strcase-call-overhead-measured.md) — ~2,570 cycles a call, and 1.3% of the editor line it rides on.
