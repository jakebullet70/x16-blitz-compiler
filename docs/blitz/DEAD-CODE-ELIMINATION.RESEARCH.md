# Dead-code elimination (research)

Status: research only, 2026-09-13. No code. Measurements come from
`docs/memory/basl-dead-code-elimination-measured.md` and `source/unit-tests/deadcode.py`.
Prog8 facts come from its source at commit `ca729d27` (2026-09-12).

The build plan is `DEAD-CODE-ELIMINATION.PLAN.md`. It puts the pass inside GPC as an option, for
any program, and uses an analysis pass in place of the token scan in 6.3.

## 1. What is at stake

`GPBMODS.BASL` carries 1,212 resident bytes of p-code that nothing calls, 8.9% of 13,563.

| where the dead code sits | bytes |
|---|---:|
| whole modules never called (`SORT`, `STRCASE`) | 691 |
| routines never called inside modules that are used | 521 |

Deleting two `#INCLUDE` lines removes the 691 today. The 521 needs a tool. 426 of it is `STRINGS`.

`CRUNCHER.BASL` is the sharper case: it calls two trims and pays 493 bytes for the rest of `STRINGS`,
a tenth of the program.

## 2. How Prog8 does it

Abbreviations for the three source files:

- UCR is `codeOptimizers/src/prog8/optimizer/UnusedCodeRemover.kt`.
- CG is `compilerAst/src/prog8/compiler/CallGraph.kt`.
- IRUCR is `codeGenIntermediate/src/prog8/codegen/intermediate/IRUnusedCodeRemover.kt`.

### 2.1 Three tiers

1. **AST pass, UCR.** It runs on every backend. It works on the syntax tree, before code generation.
2. **Assembler.** The default 6502 backend emits each subroutine as a 64tass `.proc`. 64tass does not
   assemble a `.proc` that nothing references.
3. **IR pass, IRUCR.** It runs only on the VM, M68k and `newCodegen` backends, and only with the
   optimizer on. It does not run on the default 6502 backend.

### 2.2 What the AST pass removes

- non-library modules (UCR:51)
- blocks (UCR:89-107)
- subroutines (UCR:113-134)
- variables (UCR:140-202), plus dead first assignments, self-assignments and duplicate assignments

It never removes the entry point or any `asmsub` (UCR:115). A short list of library routines is
hard-coded as kept (UCR:25-43).

Code after `return`, `jump`, `break` or `exit` gets a warning, "unreachable code" (UCR:78-82). The
AST pass does not remove it.

### 2.3 How "used" is decided

A subroutine is used if any identifier anywhere names it (CG:28-30, CG:117-124). The pass does not
check whether the caller is itself used. It is a reference test, not reachability from `main.start`.

Transitivity comes from repetition, not from the graph:

- UCR builds a new call graph on every cycle (UCR:45-47).
- The compiler reruns the pass until it changes nothing, capped at 2,000 cycles
  (`compiler/src/prog8/compiler/Compiler.kt:656-665`).
- A subroutine called only from a removed subroutine goes on the next cycle.
- Two unused subroutines that call each other both survive. This is inferred from the code, not
  tested.

Library blocks and `main` always count as used blocks (CG:32-48).

### 2.4 Inline assembly

The call graph scans the text of every `%asm {{ }}` block for names.

- The scan is a regex, `\b([_a-zA-Z]\w+?)\b`, over each line cut at `;`
  (`compilerAst/src/prog8/ast/statements/AstStatements.kt`, near line 1202).
- It counts every word as a reference, not only `jsr` and `jmp` operands.
- A subroutine matches as `name` or `p8s_name`, a block as `p8b_name`, a variable as `name` or
  `p8v_name` (CG:242, 257, 274).
- A mention does not count if it sits inside a subroutine that is itself unused (CG:245-252).
- A one-letter name never matches, because the pattern needs two characters. Inferred.
- `%asminclude` files are not scanned (CG:201-203). A subroutine named only inside an included
  file is not seen. Inferred, not tested.

A false match keeps code. It never removes code.

### 2.5 References that are not calls

- `&sub` keeps the subroutine (CG:101-104).
- A bare subroutine name keeps it, for example `call(sub)` or a name in an array (CG:117).
- `%jmptable` entries and pointer dereference chains count (CG:63-73, CG:167-199).
- A `call` to a numeric address keeps nothing. Unverified.

### 2.6 Keeping code on purpose

| control | effect |
|---|---|
| `%option force_output` on a block | nothing in the block is removed; it is emitted as `.block`, so 64tass keeps it too |
| `%option ignore_unused` | silences the messages only; removal still happens |
| `@shared` on a variable | keeps the variable |
| `-noopt` | skips the AST pass and the IR pass; 64tass still drops unreferenced `.proc` |

### 2.7 Library code

Library modules are Prog8 source and compile with every program. The module and its blocks are never
removed. Unused non-asm subroutines and variables inside the module are removed one at a time.

Library `asmsub` routines are exempt from the AST pass. The assembler tier removes them.
`docs/source/todo.rst:77-83` records a 64tass bug: a nested subroutine stops the outer one from
being removed.

`%asminclude` text and `%asmbinary` data are never cut internally. They leave only with the block or
`.proc` around them.

### 2.8 What the IR pass adds

- Reachability from `main.start` at the chunk level, so code after `return` is removed
  (IRUCR:205-262).
- Subroutines whose chunks all became empty are removed (IRUCR:109-123).
- An `asmsub` is removed when its label is not a substring of any assembly text (IRUCR:150-185).
- Empty blocks are removed (IRUCR:17-25). Library and `force_output` blocks are exempt.

### 2.9 Reporting

Prog8 prints one line per removal: "removing unused block", "removing empty subroutine",
"unused subroutine", "removing unused variable". "unreachable code" is the only warning.
`ignore_unused` silences all of them except "unreachable code".

## 3. What transfers to GPC

| Prog8 | GPC |
|---|---|
| `sub { }` gives a subroutine its extent | a routine has no extent; control falls from one line into the next |
| any reference keeps a subroutine, rerun to a fixpoint | reachability from the entry, as `deadcode.py` does; this also removes dead mutual recursion |
| inline asm is scanned for names | a `GP.ASM` blob names variables through `{VAR}`; whether a blob can reach a BASIC label is unchecked |
| `%asminclude` is never cut | a `GP.ASM` blob with modes is one routine; it is never cut below its label |
| `force_output` | wanted: a directive that keeps a block, through the `#GPC` channel |
| 64tass drops unreferenced `.proc` | no assembler runs after GPC; the runtime analogue is selective handler inclusion, ranked item 2 |
| one message per removal | wanted: the removed labels, in the end-of-compile report or the map |

## 4. Edges in BASIC

Every branch target GPC compiles is a constant. X16 BASIC has no computed `GOTO`.

| statement | where GPC reads the target |
|---|---|
| `GOTO n` | `ParseConstant` in `commands/goto.asm` |
| `GOSUB n` | `CompileBranchCommand` from `commands/gosub.asm` |
| `IF … THEN n` | `CompileBranchCommand` from `commands/if.asm` |
| `ON x GOTO/GOSUB n,n,…` | `CompileBranchCommand` per target, `commands/on.asm` |
| `RESTORE n` | `CompileBranchCommand` from `commands/restore.asm` |
| `FN name(…)` | `branchTarget` in `evaluate/term/functions.asm` |
| a `GP.DEFPROC` verb | `branchTarget` in `commands/gpdefproc.asm` |

A `RESTORE n` target is an edge. It keeps the `DATA` at `n` live.

A block ends at an unconditional `RETURN`, `END`, `STOP` or `GOTO`. Any other last statement falls
through and keeps the next block live. `IF … THEN RETURN` falls through.

The module guard `GOTO x.MODULE.END` is an edge from the module's first line to its end. It keeps
`MODULE.END` live and nothing between.

## 5. Traps

- **`DATA`.** `READ` walks every `DATA` in program order. Removing a dead block that holds `DATA`
  changes what every later `READ` returns, with no error. A block that holds `DATA` stays.
- **`DIM`.** The measurement note lists `DIM` beside `DATA`. The failure case is not written down.
  Settle it before building.
- **`{VAR}` in a blob.** A variable assigned only in dead code still has a `#SYMFILE` entry. A blob
  that reads it through `{VAR}` may find the symbol and no runtime variable. Unchecked.
- **Fall-through.** When the scanner cannot tell how a block ends, it keeps the next block.
- **`GP.BANKED` regions.** Removing lines shrinks a region. The two splice `GOTO`s stay. A region
  that becomes empty needs a rule.
- **Menu text.** A string literal that spells a label is not an edge. A source-level scanner blanks
  string literals first. GPC sees only compiled targets, so it cannot make this mistake.

## 6. Where the pass can live

### 6.1 Host side, before BASLOAD

`deadcode.py` already computes reachability. A build step writes a stripped `.BASL` beside the
source and tokenises that.

- It sees labels, module prefixes and the `#INCLUDE` structure.
- It reports removals by label name.
- It costs no compiler bytes and no emulator time.
- It does not exist on the X16. A build on the machine gets nothing.
- Its edges are name matches, not compiled targets.

### 6.2 On the machine, before BASLOAD

The same analysis in the BASLOAD fork, which is assembly. Everything in 6.1 holds, and it runs on
the X16. See `docs/memory/ask-before-writing-asm.md`.

### 6.3 Inside GPC

GPC sees line numbers, not labels. Its edges are exact: the table in section 4 is every target it
compiles.

- **Unit.** A block runs from a target line to the next target line. This is finer than a label
  block, and it covers hand-written `.PRG` input.
- **Layout.** Pass one fixes every line address. Removing a line after pass one moves every address
  behind it. The graph has to exist before the pass that lays out the object.
- **Pass structure.** Two ways to get the graph first:
  - a token scan ahead of pass one, reading targets out of the tokenised source without compiling;
  - a third pass: pass one builds the graph, a layout pass repeats pass one without the dead lines,
    and pass two writes.

  The token scan is cheaper at run time. The third pass reuses the target code in section 4 as it
  stands.
- **Storage.** One bit per line marks it dead. At 4,096 lines that is 512 bytes, which fits in a
  bank.
- **Checks.** `STRMarkLine` compares each line's address across passes. A skipped line has to skip in
  every pass that lays out code, or that check fires.
- **Reporting.** Removals are line numbers. The map file converts them to labels.
- **Compile time.** A third pass costs about one more pass one: about 4.5 minutes on GPBMODS under
  emulation.

## 7. Recommendation

1. Delete the `SORT` and `STRCASE` `#INCLUDE` lines from `GPBMODS.BASL`. This gets 691 bytes with no
   tool.
2. Make `deadcode.py` write a stripped `.BASL` and call it from `build_basl.py`. It uses true
   reachability, not Prog8's reference rule. It keeps any block that holds `DATA`, and it prints the
   labels it removed. This gets the 521.
3. Build the GPC pass only if programs must build on the X16 itself. Use the token scan ahead of pass
   one, and the one-bit-per-line table.

A keep directive through `#GPC`, the analogue of `force_output`, comes with step 2 or step 3,
whichever is built first.
