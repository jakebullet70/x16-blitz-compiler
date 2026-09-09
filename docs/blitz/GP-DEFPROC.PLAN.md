# GP.DEFPROC / GP.SUB / GP.FN -- one-line calls to BASL routines

Three new GP keywords. A library routine declares its parameters once; callers pass them in one
statement instead of a run of assignments followed by a `GOSUB`.

Nothing here changes BASLOAD. Nothing here adds a byte to the runtime.

**GP.DEFPROC AND GP.SUB ARE BUILT AND MEASURED, 08/09/26. Cost: +672 bytes of GPC.BIN, 0 of
runtime, 0 of program size, 0 of the 1K storage hole.** `GP.FN` and `RETURNS` are not built; see
§7 and §8. The rest of this document is the design as it was written, with what the build
measured put in beside it.

**THE CALL SITE COSTS NOTHING, WHICH WAS THE CLAIM WORTH CHECKING.** `DEFP1B` and `DEFP1C` are the
same program with and without the keywords and both compile to **423 bytes**, differing in **ten
bytes: two at each of the five call sites** — the opcode `$E9` (`.fngosub`) where the long
spelling has `$E4` (`.gosub`), and an operand one higher because `.fngosub` enters just past the
line marker the label points at. Same length, same output, same everything else.

**A DECLARATION COSTS ONE BYTE, AND IT IS A LINE AND NOT A KEYWORD.** Every source line emits a
`new.line` byte (`compiler.asm`, `PCD_NEWCMD_LINE`), so a `GP.DEFPROC` on a line of its own is one
more line and one more byte: `DEFP1` is 427 against `DEFP1C`'s 423, four verbs, four bytes. Folding
it onto the shim's own line — `DP.SHOUT: GP.DEFPROC SHOUT, DP.S$ : PRINT ...` — adds no line and
so costs nothing at all, which is what `DEFP1B` is. **Folding it onto a BARE LABEL line does not
work**, and that is not a surprise: a bare label is not a BASIC line
([folding-onto-a-label-line-saves-nothing](docs/memory/folding-onto-a-label-line-saves-nothing.md)),
so the fold has to be onto the line carrying the shim's first real statement.

**THE VERB IS A NAME, NOT A NUMBER, AND THERE IS NO PROC TABLE.** See §7: the decision went the
other way from §3 and §4 below, and it made the change smaller rather than larger.

---

## 1. Syntax

```
GP.DEFPROC <verb> [, <formal> ...] [RETURNS <formal>]
```

Declaration. Emits no p-code. Binds to the code position that follows it, which is the next
statement in the source. `<verb>` is a compile-time integer constant. Each `<formal>` is an
ordinary variable, numeric or string.

```
GP.SUB <verb> [, <expression> ...]
```

Call, statement position. Assigns each expression to the matching formal, then calls the routine.
Any `RETURNS` value is discarded.

```
GP.FN(<verb> [, <expression> ...])
```

Call, expression position. The same, and the value of the term is the `RETURNS` formal after the
call. `GP.FN$(...)` for a string return.

### The two-line layout

The declaration sits on its own line, immediately above the shim it describes:

```
#DEFINE DBOPEN 1
#DEFINE DBFIND 2

GP.DEFPROC DBOPEN, DB.NAME$, DB.DEVICE
DB.OPEN:  BANK DB.CODEBANK : GOSUB DB.OPEN.BODY : RETURN

GP.DEFPROC DBFIND, DB.F, DB.KEY$, DB.EXACT RETURNS DB.FOUND
DB.FIND:  BANK DB.CODEBANK : GOSUB DB.FIND.BODY : RETURN
```

The shim line is unchanged from `LIB.GUIBANK.INC.BL`. Declarations may also be folded onto the shim
line; the binding rule is the same either way.

Call sites:

```
GP.SUB DBOPEN, "PARTS.DBF", 8
IF GP.FN(DBFIND, 2, "SMITH", 0) THEN GOSUB SHOW.RECORD
```

`GOSUB DB.OPEN` still works and still means the same thing. Adoption is per call site; no existing
code changes.

---

## 2. What it compiles to

| source | p-code emitted |
|---|---|
| `GP.DEFPROC DBOPEN, DB.NAME$, DB.DEVICE` | nothing |
| `GP.SUB DBOPEN, "PARTS.DBF", 8` | `DB.NAME$ = "PARTS.DBF" : DB.DEVICE = 8 : GOSUB DB.OPEN` |
| `GP.FN(DBFIND, 2, "SMITH", 0)` | the same, plus a read of `DB.FOUND` |

The `GP.SUB` row is byte-for-byte identical to the hand-written line, provided the formals are the
module's own globals (§5).

---

## 3. Cost

### Runtime: 0 bytes for `GP.SUB`, and 0 of PROGRAM SIZE for `GP.FN`

`GP.DEFPROC` and `GP.SUB` add no opcode: `.gosub`, `.fngosub`, the variable writes and the variable
read are all in the runtime already. **`GP.FN` did add two** -- `.fnsave` and `.fnrestore`, 213
bytes -- and they went into the padding that carries the GP block up to `RTBASE`, so they still
cost a program nothing. `RTGPBASE` and `RTBASE` did not move. See §9 for the measurement.

| feature | runtime bytes | program bytes |
|---|---:|---:|
| `GP.CALL` | 77 | 77 |
| `GP.SELECT` / `GP.CASE` | 127 | 127 |
| block `GP.IF` | 14 | 14 |
| **`GP.DEFPROC` / `GP.SUB`** | **0** | **0** |
| **`GP.FN`** | **213, into GP block padding** | **0** |

### Call site: 0 bytes over hand-written for `GP.SUB`, 2 for `GP.FN`

`GP.FN` is 5 bytes of bracket -- `.fnsave`, `.fngosub` and its operand, `.fnrestore` -- against
`GP.SUB`'s 3, plus the result read the long spelling pays anyway.

### Compiler: 672 bytes, MEASURED

`GPC.BIN` 23,627 — **24,299**, for GP.DEFPROC and GP.SUB. By label delta:

| | bytes |
|---|---:|
| the two handlers and `ProcReadVerb` | 396 |
| the six messages, in compiler space | 217 |
| the formal buffers, in the code section | 44 |
| two keyword table entries | 14 |
| **total** | **671** |

Over the bracket below, and the messages are why: six of them at an average of 36 bytes. They are
the price of saying which of six things went wrong instead of `SYNTAX ERROR`, they are in compiler
space so a compiled program pays none of it, and `GP.FN` will add no more of them.

**`StorageEnd` does not move.** It is `$066D` before and after: every byte of working storage went
to the code section by Wall 2's precedent, so the 1K hole below `$0801` still has its 404 free.

Original bracket below, and what it got wrong is the messages. Measured sizes of the routines the
three handlers are modelled on, by label delta in the current build:

| existing routine | bytes |
|---|---:|
| `CommandDEF` | ~106 |
| `CommandFOR` | ~90 |
| `CommandON` | ~44 |
| `CompileBranchCommand` | ~26 |
| keyword table entry, each | 7 |

Label deltas over-read where data follows a routine and under-read where local labels split one.
The bracket is not a measurement. §8 is.

### Compiler storage: NONE. There is no proc table

**Superseded by the decision in §7.** A verb lives in the variable list, so the storage this
section budgeted for does not exist: no compile-time bank, no table, and the only working storage is
44 bytes of code section holding one verb's formals while a call site is compiled. A verb does cost
one of the 1,365 variable records, and no variable memory at all — a proc record allocates none,
so `freeVariableMemory` is what it would have been and the two passes agree on it.

Original reasoning below.

Proc table: verbs x (2 B code position + 1 B arity + 1 B return type + ~3 B per formal). Twenty
verbs is about 300 bytes. Compile-time banks 0-4 are taken -- KERNAL, native harness p-code buffer,
line table, `GP.ASM` blob pool, variable list. Bank 5 is free. The table costs no low RAM and does
not touch the 2,048-line or 1,365-variable ceilings.

### Tokens: 4 taken

**Taken, in `c64tokens.py` and `GPB.INC.BL`:**

```
#TOKEN GP.DEFPROC 52817
#TOKEN GP.SUB     52816
#TOKEN GP.FN      52815
#TOKEN RETURNS    52814
```

`GP.FN` at 52815 is still free and still proposed. **`RETURNS` needs a token of its own, which this
section did not count**: it is not a ROM keyword, so BASLOAD crunches it as an ordinary identifier
and the compiler never sees the word.

**DECIDED 08/09/26: a token, 52814, not `TO`.** The alternative was the ROM's `TO` (token $A4), already
an equate and already reserved by `FOR..TO`, so it allocates nothing. The difference is **seven
bytes of GPC.BIN and one reserved word**, and neither is a reason:

- **A new token costs no keyword table row.** `RETURNS` only ever appears mid-statement, so it needs
  no `commands.def` entry — `GP.A`, `GP.X`, `GP.Y`, `GP.C`, `GP.HIBYTE` and `GP.CONTAINS` are the
  precedent, all `#TOKEN` declarations with no table line. A row is seven bytes
  (`length, $ce, id, $03, handler lo, handler hi, terminator`), and it is not spent.
- **It costs about 17 bytes of compiler code to test for**, against ~10 for `TO`: a GP keyword is
  two bytes, so `cmp #$CE` / `bne` / `jsr GetNext` / `cmp #GP_TOKEN_RETURNS` where `TO` is
  `lda #C64_TO` / `jsr CheckNextA`. `gpbstr.asm:94` is the written idiom for the first,
  `for.asm:79` for the second.
- **It costs one BASLOAD symbol**, permanently reserving the word `RETURNS` against every source
  that includes `GPB.INC.BL`, because tokens and variables share one namespace. `TO` was never
  available to a program anyway.
- **0 bytes of runtime and 0 of program size**, either way. The declaration emits no p-code.

What decides it is reading. `TO` already means *up to* in this BASIC, and
`GP.DEFPROC RND100 TO R` reads as a range on first sight:

```
GP.DEFPROC DBFIND, DB.F, DB.KEY$, DB.EXACT TO DB.FOUND
GP.DEFPROC DBFIND, DB.F, DB.KEY$, DB.EXACT RETURNS DB.FOUND
```

Seven bytes of compiler is not a reason to make a declaration harder to read, and
`docs/memory/compiler-must-not-cap-program-size.md` says the compiler's own size is the side that
gives.

The floor was 52818 (`GP.ENDBANKEDSTR`) and is 52816 now. Ten numbers inside the allocated range are unused
and 82 remain below it. The byte values are the ABI and mirror `getGP()` in
`source/common-scripts/c64tokens.py`.

---

## 4. How it works in the compiler

Every mechanism this needs already exists and ships. `DEF FN` is the working model: it declares a
routine, stores its code position, writes an argument into a variable, and calls it from inside an
expression.

### GP.DEFPROC -- model on `CommandDEF`

`source/compiler/source/commands/deffn.asm`. Same shape without the code generation.

1. Read the verb constant.
2. For each formal, `GetReferenceTerm` for the variable reference and type.
3. Optional `RETURNS` formal.
4. Record the CURRENT code position, the way `CommandDEF` calls
   `SetVariableRecordToCodePosition`. Because the declaration emits nothing, the current position
   is the first byte of the shim.
5. Store the record in the proc table, keyed by verb.

### GP.SUB and GP.FN -- model on `CompileFN`

`source/compiler/source/evaluate/term/functions.asm:25-70`. That routine already does the whole
call: it takes an absolute code position, compiles an argument expression, writes it into a
variable, and emits the call.

1. Read the verb constant, look it up in the proc table, take its code position.
2. For each formal, `CompileExpressionAt0` then `GetSetVariable` with carry SET, exactly as
   `deffn.asm` does through `CDReadWriteVariable`. Check arity and type against the declaration.
3. `WriteBranchToAddress` with `PCD_CMD_FNGOSUB`.
4. `GP.FN` only: emit a read of the `RETURNS` formal, `GetSetVariable` with carry CLEAR.

`GP.SUB` uses `.fngosub` rather than `.gosub`. The two are identical at runtime -- see the comment
on `CommandXFnGosub` in `source/runtime/source/commands/gosub.asm` -- and `.fngosub` takes an
absolute address, so the proc table never has to hold a source line number.

`WriteBranchToAddress` (`commands/goto.asm:502`) corrects the operand when one end of the branch is
inside a `GP.BANKED` region. Shims are the front door to banked code, so this is load-bearing.

### Why the math stack survives a call inside an expression

`X` is the math stack pointer. The dispatcher pushes and pulls it around each vector and never
resets it per statement (`source/runtime/source/main/00runtime.asm:126`), and `GOSUB` / `RETURN` do
not touch it. `DEF FN` already relies on this.

---

## 5. Constraints and traps

**The verb must be a compile-time constant.** `#DEFINE DBOPEN 1` substitutes an integer at
translation time. The compiler needs it to resolve the call target and, for `GP.FN`, the return
type. A variable verb cannot work.

**The declaration can never name its label.** A label name outside `GOTO` / `GOSUB` / `THEN` / `ON`
is crunched as a variable and collides with the label -- `DUPLICATE SYMBOL`. This is why the
binding is positional and why `GP.DEFPROC DBOPEN, DB.OPEN, ...` is impossible.

**GP.DEFPROC must be compiled before any call to it.** `.fngosub` carries an absolute address, and
`CompileFN` refuses a forward reference for that reason. The `LIB.GUIBANK` pattern already satisfies
this: shim files are `#INCLUDE`d at the top, above the code that calls them. An out-of-order call
must be an error naming the verb, not a wrong branch.

**Formals should be the module's existing globals.** Then the assignments a call site emits are the
ones a hand-written call would have emitted, and the cost is zero. A renamed formal costs an extra
assignment, about 6 bytes, per parameter per call site.

**Twelve math stack slots, total.** `MathStackSize = 12` in `source/ifloat32/source/data.inc:34`.
A `GP.FN` in flight costs one slot plus the callee's own peak. Deep nesting of `GP.FN` inside
expressions inside routines reached by `GP.FN` will exhaust it.

**Return strings, do not copy them.** Reading a string formal onto the stack is a pointer read.
Binding it into a caller variable is heap churn -- string blocks never shrink.

**`GP.CALL` is unrelated.** It calls machine code at an address with the registers set. It is not
being renamed: 99 uses across the BASL samples and 27 files in `docs` and `source`.

---

## 6. Why this is not a BASLOAD change

The obvious spelling is `DB.OPEN("PARTS.DBF", 8)`. It is not available. A label name in statement
position collides with the label, and BASLOAD resolves labels only after `GOTO` / `GOSUB` / `THEN`
/ `ON`. Getting that spelling means changing BASLOAD.

BASLOAD is not owned here and the local fork may be removed. So the verb is a `#DEFINE`d integer
and the keyword carries the call. `#TOKEN` is stock BASLOAD (`upstream/option.inc:465`), so the
three keywords survive the fork going away.

Do not reopen this by proposing a preprocessor or a BASLOAD patch.

---

## 7. Open questions

**Named verbs instead of `#DEFINE` -- DECIDED 08/09/26, NAMED VERBS, and it made the change
smaller.** A verb is a bare identifier and its record lives in the variable list. Three things this
section did not know, all checked before the decision:

- **There is a free bit.** `ExtractVariableName` packs a name into X = first character and 31 with
  the type bits, Y = second character and 63. `DEF FN` already claims **bit 7 of Y** to keep `FNA`
  apart from the variable `A`. **Bit 6 is free**, so a verb has a namespace of its own and cannot
  collide with a variable, with an `FN`, or with `TI`/`TI$`/`ST` — the three reserved names, whose
  second bytes are $09 and $14.
- **A variable record is already variable-length.** Byte 0 is its size and `FindVariable` walks by
  it, so a proc record simply runs on: byte 5 is the formal count and three bytes a formal follow,
  which is address low, address high and type — exactly what `GetSetVariable` takes. Nothing in
  the storage layer changed.
- **`FindVariable` already returns byte 5 in A**, having read it on the way past. The formal count
  comes back from the lookup for nothing.

So there is no proc table, no compile-time bank, and no `#DEFINE` line per verb. The record is
created AFTER the formals are read, because reading a formal may create a variable record of its
own and that would land on the space the proc record is about to grow into.

**Error text -- and named verbs do NOT fix it, which is the one thing that decision gave up.**
BASLOAD crunches every name to two characters, so the compiler could only ever print `AB`, not
`DBOPEN`. The messages therefore name the KEYWORD and the fault rather than the verb, and `@ line`
names the line, which is the identification a programmer can actually use:

    GP.DEFPROC VERB IS NOT A PLAIN NAME
    GP.DEFPROC VERB ALREADY DECLARED
    GP.DEFPROC FORMAL IS NOT A VARIABLE
    TOO MANY GP.DEFPROC FORMALS
    GP.SUB BEFORE ITS GP.DEFPROC
    GP.SUB DOES NOT MATCH ITS GP.DEFPROC

All six are in compiler space by the `gpasmcode.asm` pattern, so a program that never writes one of
these keywords pays nothing for them. A type mismatch is the shared `.error_type`, as an assignment
already is.

**`RETURNS` in phase 1 or phase 2 -- PHASE 2, and it needs a token.** Not built. See §3: `RETURNS`
is not a ROM keyword, so BASLOAD crunches it as an identifier and the compiler never sees the word.
**DECIDED 08/09/26: 52814, a token of its own, not `TO`** — the cost is seven bytes of GPC.BIN and
one reserved word, and §3 carries the breakdown.

**Whether `GP.SUB` should also accept a forward declaration**, given the `.fngosub` restriction.
Still open. It is refused by name today (`GP.SUB BEFORE ITS GP.DEFPROC`), which is what §5 asks
for.

**How many formals -- `PROC_MAXFORMALS` is 12.** Three bytes of the code section each and nothing
in the tree wants half of it, so the number is about what a shim plausibly takes rather than about
room. A thirteenth is `TOO MANY GP.DEFPROC FORMALS`.

**One set of formals is enough for `GP.SUB` and will not be for `GP.FN`. BUILT 08/09/26, and it
took two things and not one.** The compile-time buffers did become a stack, `ProcStatePush` /
`ProcStatePull` around each argument. That was not sufficient: the RUN-time formals are one set
too, and storing each argument as it compiled let a nested call write a formal the outer call had
already filled. The stores are deferred to the end of the list now. See §9.

---

## 8. First build -- DONE 08/09/26

Built against purpose-made tests in `testing/` rather than against XBASE: that sample is parked and
carries its own `GPC-BASIC`, so it is a slow cycle for a first build and it entangles the banked
case with its own state. **XBASE is the next step, not this one.**

All three questions are settled:

1. **The compiler size delta is +672 bytes** — see §3, which now carries the breakdown. 0 bytes
   of runtime, 0 of program size, 0 of the 1K storage hole.
2. **`WriteBranchToAddress` corrects a shim call, in both directions.** `DEFP2` is the
   `LIB.GUIBANK.INC.BL` shape: `DP.PUT` is a low memory shim that selects bank 5 and calls a body at
   `$A000`, and the declaration binds to the shim. The body then calls the OTHER way — a `GP.SUB`
   INSIDE the region reaching a low memory routine — so both ends of the correction are
   exercised. It compiles to a 609 byte object plus `DEFP2.B05` and prints `P1 START / P3 IN BANK
   A / P4 N= 1 / P3 IN BANK B / P4 N= 2 / P9 END`.
3. **The p-code matches the hand-written line.** `DEFP1B` (folded declarations) and `DEFP1C` (the
   long spelling) are both **423 bytes** and differ in **ten bytes, two at each of the five call
   sites**: `$E9` for `$E4`, and an operand one higher. `DEFP1`, with the declarations on lines of
   their own, is 427 — one `new.line` byte a declaration, which §3 explains.

### The tests

| | what it is |
|---|---|
| `DEFP1` | 0, 1 and 3 formals, numeric and string; a `GOSUB` to the same label still works |
| `DEFP1B` | the same, declarations folded onto the shim lines — the zero cost spelling |
| `DEFP1C` | the same, written the long way — the control |
| `DEFP2` | low memory shim, body in `GP.BANKED 5`, and a `GP.SUB` out of the region |
| `DEFPX` | a call above its declaration — `GP.SUB BEFORE ITS GP.DEFPROC @ 1` |
| `DEFPY` | three arguments to two formals — `GP.SUB DOES NOT MATCH ITS GP.DEFPROC @ 5` |
| `DEFPZ` | a string where the formal is a number — `TYPE MISMATCH @ 5` |
| `DEFPW` | the verb declared twice — `GP.DEFPROC VERB ALREADY DECLARED @ 5` |
| `DEFPV` | a `$` on the verb — `GP.DEFPROC VERB IS NOT A PLAIN NAME @ 2` |

`source/unit-tests/banktest3.py` passes unchanged beside them.

`GP.FN` follows only if 2 holds. It does.

Use `make libs` -- a change under `source/compiler/` silently misses `GPC.BIN` otherwise.

## 9. `GP.FN` -- BUILT AND MEASURED 08/09/26

`GP.FN(<verb>[, <expression> ...])` is a term in an expression. It fills the formals, calls the
routine, and gives back the variable `GP.DEFPROC` named after `RETURNS`. The body may be as long as
it likes -- print, read files, open blocks, call other verbs.

### What it cost

| | before | after | delta |
|---|---:|---:|---|
| `GPC.BIN` | 24,299 | 25,145 | **+846** |
| GP block code | ends `$6A5D` | ends `$6B32` | **+213, all of it into padding** |
| runtime image | ends `$9CEE` | ends `$9CFB` | **+13** |
| max program size | | | **0** |

Measured against a clean `HEAD` build in a detached worktree, not against the tree. **§10 adds two
more opcodes on top of these figures**; the running totals are there.

**The 213 bytes of handler cost a program nothing.** `source/main/05rtcore.divider` pads the GP
block out so the core lands exactly on `RTBASE`, and the two handlers went into that padding: the
slack was 927 bytes and is 714. The +13 in the image is the core side -- `clr.asm` initialising
`stringTempPages`, `stralloc.asm` reading it instead of a constant, and two vector table entries.

**`RTGPBASE $6600` and `RTBASE $6E00` did not move**, so the p-code ceiling is exactly what it was.
What the growth spends is runtime headroom: the image ends at `$9CFB` with **517 bytes** left below
`$9F00`.

### The two opcodes

`.fnsave` `$F1` and `.fnrestore` `$F2` bracket the `.fngosub`. They exist because
`MainCompileLoop` emits `PCD_NEWCMD_LINE` before every source line and `CommandNewLine` is
`.resetStringSystem` plus `ldx #$FF` -- so a call into a multi-line body from mid-expression would
wipe the caller's evaluation stack and its string temporaries. `.fnsave` pushes the live stack onto
the frame stack, one `FRAME_FNSLOT` a slot, and drops `stringTempPointer` below the caller's live
temporaries so the callee's per-line resets hand out memory underneath them. `.fnrestore` puts both
back. `stringTempPages` was a constant 2 inside `StringInitialise` and is now a variable, which is
the whole of the change on the string side.

The heap ceiling could not be moved instead: `StringConcrete`'s scavenger walks the blocks upward
from `stringHighMemory` and needs them to tile it exactly.

### The two defects, and what found them

**A nested call clobbered the outer call's formals.** `GP.FN(AREA, 2, GP.FN(AREA, 3, 4))` gave 36
where the longhand gives 24. Formals are plain variables, so storing each argument as it compiled
let the inner call write `A.W` while the outer call's 2 was already sitting in it -- silently, with
both passes agreeing. `ProcCompileArguments` now evaluates the whole list before storing any of it,
leaving the values on the evaluation stack and taking them off **last formal first**. What that
deferral cost was evaluation stack -- N formals in N of the twelve slots where one had done -- and
that is the hazard §10 closes.

**Every GP.FN program wedged with `OUT OF MEMORY` and a runaway PC, and no code was wrong.**
`testing/GPB.RT.120.BIN` was three and a half hours stale: `make libs` builds `gp.library` and
`GPC.BIN` but never installs the runtime, which is `make -C source/runtime gpc-rt`. The compiler
emitted `$F1`/`$F2` correctly and the loaded runtime's vector table had no entries for them.
Bisecting the handlers "changed nothing" because the gutted file was not the one being loaded. See
[make libs does not install the runtime](../memory/make-libs-does-not-install-the-runtime.md).

### The tests

`source/unit-tests/fntest.py`, six programs, `FAILURES: 0`.

| | what it is |
|---|---|
| `DEFFN1` | eight `GP.FN` call sites: bare, in a sum, nested in its own argument list, two in one expression, string concatenation, and inside a `FOR` |
| `DEFFN1C` | the same ten lines written the long way -- the control |
| `DEFP3` / `DEFP3C` | the twenty-one verb `GP.SUB` regression, in this harness because both keywords share `ProcCompileArguments` |
| `DEFFNX` | a verb with no `RETURNS` -- `GP.FN NEEDS A VERB DECLARED RETURNS @ 6` |
| `DEFFNY` | a call above its declaration -- `GP.FN BEFORE ITS GP.DEFPROC @ 1` |
| `DEFFNZ` | the wrong number of arguments -- `ARGUMENTS DO NOT MATCH THE GP.DEFPROC @ 6` |
| `DEFFNW` | `RETURNS A(1)` -- `GP.DEFPROC RETURNS IS NOT A VARIABLE @ 2` |
| `DEFFN2` | the minimal case: one formal, a one-line body, checked against the lines it prints |
| `DEFFN3` | a multi-line body that PRINTS from inside the call, reached by both `GP.SUB` and `GP.FN` |
| `DEFFN4` | the body folded onto the declaration -- the shortest thing `RETURNS` can name |

**`DEFFN2`, `DEFFN3` and `DEFFN4` have no longhand control**, because what they test is the shape
and not a byte count: the callee prints, so every line of it emits a `new.line` marker that would
have reset the string system and emptied the caller's evaluation stack. They are checked against
the lines they print instead, which is the harness's `EXPECT` table.

### What is not checked, and will not be

**A verb's body must not call its own verb.** There is one set of formals, so a routine that
recurses -- directly or round through another verb -- writes over the arguments it is still using.
It compiles, both passes agree, and the answer is wrong. Detecting it needs a call graph the
compiler does not build, and it is in `GP-BASIC.md` §3.11 as a rule instead.

A verb inside its **own argument list** is correct, and `DEFFN1`'s T3 is the test.

### The diagnostics in `.fnrestore`

Two conditions, one message. `_CXRBroken` raises `.error_structure` when the frame on top is
neither a slot nor the state frame -- which a callee returning with a block still open produces --
and the slot count reaching `MathStackSize` branches to the same place, because a store past
`NSExponent` runs off the end of the register file. Neither is in `errors.asm`, which links below
`GPBase` and is copied into every compiled program.


## 10. `.fnpush` / `.fnpop` -- BUILT AND MEASURED 08/09/26

§9 left a hazard behind it. `ProcCompileArguments` evaluates the whole argument list before storing
any of it, which is what makes `GP.FN(AREA, 2, GP.FN(AREA, 3, 4))` correct -- but it also means **N
formals hold N evaluation stack slots where one used to do**.

**And the evaluation stack is twelve slots with no overflow check anywhere in the runtime.**
`MathStackSize` is 12 (`ifloat32/source/data.inc:36`), six parallel zero page arrays of that length,
X the index. `NSStatus,x` at x=12 is `NSMantissa0[0]` -- the bottom slot of the same stack. So
overflowing it corrupts a live value rather than reporting anything, and `PROC_MAXFORMALS` is also
12, so a twelve-formal verb sat exactly on the edge of it with one deep argument to go.

That would have made the formal count a cap on what may be written, which
[compiler-must-not-cap-program-size](../memory/compiler-must-not-cap-program-size.md) forbids.

### Four options, and why this one

| | |
|---|---|
| cap the formals and check | a build-side wall, and the rule says no |
| grow `MathStackSize` | 6 bytes of zero page a slot, and it only moves the wall |
| spill to the string heap | the heap is what the callee is about to reset; wrong stack entirely |
| **spill to the frame stack** | **the machinery `.fnsave` already has, no cap, ~1 byte an argument** |

The frame stack is 4K and `StackOpenFrame` has checked it against `stackFloorHigh` since 02/08/26.
An argument waiting for a call **is** a saved evaluation stack slot, so it is the same frame.

### What it does

`.fnpush` `$F3` sends the argument just evaluated to the frame stack as a `FRAME_FNSLOT` and does
`dex`; `.fnpop` `$F4` does `inx` and brings one back, in front of the store that consumes it. The
evaluation stack then holds **one argument at a time however many there are**, so what a call needs
is the depth of its deepest single argument and nothing else.

**The last argument is never pushed.** It is evaluated last and stored first, so nothing runs
between the two. A one-formal verb emits neither opcode and costs exactly what the longhand did.

**Reusing `FRAME_FNSLOT` is safe, and it was checked rather than assumed.** `.fnsave` pushes its
`FRAME_FNSTATE` first and its slot frames above it, and `.fnrestore` stops counting at the state
frame, so it can never see an argument frame below. `.fnpop` pops **exactly one** frame rather than
counting, so a `GP.SUB` executed inside a `GP.FN` body -- whose own frames sit directly on top of
the enclosing call's argument frames -- is invisible to it. That is also why an auto-counting
`.fnargs` opcode was rejected: "pop until the frame is not a slot" would have over-popped in exactly
that case. An explicit count operand was dropped as dearer than `.fnpush`/`.fnpop` at 1-3 formals,
which is every real call site.

The slot copy was factored out of `.fnsave`/`.fnrestore` into `FnPushSlot`/`FnPullSlot`, which both
new handlers call. That is why two whole opcodes cost 39 bytes and not ninety. Neither
`StackOpenFrame` nor `StackCloseFrame` touches X, which is what lets both take X as the slot index
and leave it alone -- the pre-existing `.fnrestore` loop had already relied on half of that.

### What it cost

| | before | after | delta |
|---|---:|---:|---|
| `GPC.BIN` | 25,145 | 25,174 | **+29** |
| GP block code | ends `$6B32` | ends `$6B59` | **+39, all of it into padding** |
| runtime image | ends `$9CFB` | ends `$9D01` | **+6** |
| max program size | | | **0** |

The divider slack is **675** of the 927 that were there, and the image has **511 bytes** to `$9F00`.
`RTGPBASE $6600` and `RTBASE $6E00` did not move. The +6 is four bytes of vector table and two of
`pcodesize`. Running totals for the whole of `GP.FN`: +875 of `GPC.BIN`, +252 of GP block, +19 of
image, and still **0 of max program size**.

**At the call site: 2 bytes an argument after the first**, both opcodes being one byte with no
operand. Measured on `DEFP3`, which has twenty-one call sites, twenty of them 0 or 1 formal and one
`GP.SUB DBFIND, 3, "ACME", 0-1` at three: predicted +4, and the object went **528 to 532**.
`DEFFN2`/`DEFFN3`/`DEFFN4` are one-formal verbs and did not move -- 85, 131, 79 in both runs. The
longhand controls `DEFP3C` and `DEFFN1C` are byte identical, as a program not using the keywords
must be.

**At run time: ~360 cycles an argument after the first**, counted from the sources -- `.fnpush` is
188 (33 of dispatch, 155 of handler, of which `FnPushSlot` is 133 and `StackOpenFrame` 47) and
`.fnpop` is 163, plus about 11 amortised for the two extra p-code words against the one-in-sixteen
Ctrl+C poll. **The old code paid none of it**, so it is purely additive, with two qualifications:

- **a nested `GP.FN` gets most of it back.** The outer call's evaluated argument used to be on the
  evaluation stack when the inner `.fnsave` ran, so `.fnsave` pushed it to a `FRAME_FNSLOT` and
  `.fnrestore` pulled it back -- the identical work through the identical routines. `.fnpush` only
  does it earlier, and the real cost is the extra dispatch: **80 cycles, not 360**.
- **`GP.SUB` pays and gets nothing back**, having no `.fnsave` to offset against. Both keywords
  share `ProcCompileArguments`. A three-formal `GP.SUB` costs 720 cycles a call that it did not.
  That is the honest price: the hazard is a `GP.SUB` hazard as much as a `GP.FN` one.

### The test

**`testing/DEFFNS.BASL`.** A twelve-formal verb `WIDE` -- `W.A`..`W.L`, `RETURNS W.R`, body
`W.R = W.A + W.L` -- called by both `GP.SUB` and `GP.FN` with `1..11` and a last argument
`N + N * 2 + N * 3 + N * 4` at `N = 1`. Twelve formals is `PROC_MAXFORMALS` and the last argument is
four terms deep, so the arguments alone filled the stack and the depth ran off the end of it. Both
calls answer `1 + 10 = 11`. `fntest.py` is `FAILURES: 0` over all twelve programs.

**The harness needed one fix to get there, and it is not about this work.** `-echo` writes the
colour change following a printed number through as a literal `\X1D`, so `A2  6\X1D` never string
equals `A2  6` and `DEFFN2`/`DEFFN3`/`DEFFN4` reported `*** WRONG ***` while printing exactly the
right thing. The comparison truncates at the first backslash now; nothing here tests colour and no
line these programs print contains one of its own.
