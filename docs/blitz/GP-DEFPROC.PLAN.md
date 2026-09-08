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

The shim line is unchanged from `LIBBANK.INC.BL`. Declarations may also be folded onto the shim
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

### Runtime: 0 bytes

No new opcode. `.gosub`, `.fngosub`, the variable writes and the variable read are all in the
10,956-byte runtime copied into every program. Max program size stays 17,408 bytes of p-code.

| feature | runtime bytes |
|---|---:|
| `GP.CALL` | 77 |
| `GP.SELECT` / `GP.CASE` | 127 |
| block `GP.IF` | 14 |
| **`GP.DEFPROC` / `GP.SUB` / `GP.FN`** | **0** |

### Call site: 0 bytes over hand-written

`GP.FN` is about 3 bytes more than `GP.SUB`, for the result read.

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

### Tokens: 2 taken, and GP.FN still wants two not one

**Taken, in `c64tokens.py` and `GPB.INC.BL`:**

```
#TOKEN GP.DEFPROC 52817
#TOKEN GP.SUB     52816
```

`GP.FN` at 52815 is still free and still proposed. **`RETURNS` needs a token of its own, which this
section did not count**: it is not a ROM keyword, so BASLOAD crunches it as an ordinary identifier
and the compiler never sees the word. Either allocate 52814 for it, or spell the declaration with
`TO`, which is already token $A4 and reads no worse:

```
GP.DEFPROC DBFIND, DB.F, DB.KEY$, DB.EXACT TO DB.FOUND
```

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
`CompileFN` refuses a forward reference for that reason. The `LIBBANK` pattern already satisfies
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
Allocate 52814 for it, or spell it `TO`.

**Whether `GP.SUB` should also accept a forward declaration**, given the `.fngosub` restriction.
Still open. It is refused by name today (`GP.SUB BEFORE ITS GP.DEFPROC`), which is what §5 asks
for.

**How many formals -- `PROC_MAXFORMALS` is 12.** Three bytes of the code section each and nothing
in the tree wants half of it, so the number is about what a shim plausibly takes rather than about
room. A thirteenth is `TOO MANY GP.DEFPROC FORMALS`.

**One set of formals is enough for `GP.SUB` and will not be for `GP.FN`.** `GP.SUB` is a statement
and nothing an argument expression can contain re-enters it, so the buffers are flat. `GP.FN` is an
expression term and can appear inside an argument to another `GP.FN`: the buffers have to become a
stack before it is built. This is written at the top of `gpdefproc.asm` as well.

---

## 8. First build -- DONE 08/09/26

Built against purpose-made tests in `testing/` rather than against XBASE: that sample is parked and
carries its own `GPC-BASIC`, so it is a slow cycle for a first build and it entangles the banked
case with its own state. **XBASE is the next step, not this one.**

All three questions are settled:

1. **The compiler size delta is +672 bytes** — see §3, which now carries the breakdown. 0 bytes
   of runtime, 0 of program size, 0 of the 1K storage hole.
2. **`WriteBranchToAddress` corrects a shim call, in both directions.** `DEFP2` is the
   `LIBBANK.INC.BL` shape: `DP.PUT` is a low memory shim that selects bank 5 and calls a body at
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
