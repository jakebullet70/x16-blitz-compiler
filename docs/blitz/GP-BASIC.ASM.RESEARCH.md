# GP.ASM — inline 65C02 assembly in GP-BASIC (research)

> **Status: IMPLEMENTED, on branch `feature/gp-asm`.** This document was written
> as research, before any code existed, and it is kept as the reasoning behind
> what was built — not as a description of it. Where the two differ, the tree is
> right. What shipped: §18's option A (the `SYS` composite with blobs pooled past
> the `$FF` end marker), §17's REM-bodied block, §19.1's `#INCLUDE`. Verified on
> R49 at **RT 12031 / GP-BASIC OUT** — zero runtime bytes. Labels, branches and `{VAR}`
> are not built yet. See `TODO.md` and the commit messages for the build itself.

> **Originally written as research only.** Started and written 2026-08-30, incrementally, because the previous
> GP-BASIC design session was lost before it was written down (see the banner on
> `GP-BASIC.PLAN.md`). Every claim says where it came from, and measurements are
> labelled as measurements.

## Read this first — the document grew in layers

It was written as the research happened, so **later sections correct earlier
ones**. Read in this order, not top to bottom:

| if you want | read | note |
| --- | --- | --- |
| what was decided | **§D** and **§D2** | the answers given on 2026-08-30 |
| **what it costs** | **§14**, then **§15.9** | §14 supersedes §13; §15.9 revises §14.9 |
| **what changed under it** | **§15** | GP.IF landed 2026-08-30 and moved things |
| **how to avoid the 2 KB** | **§18**, then §16-§17 | adversarially reviewed; **§18.1/§18.2 correct earlier numbers** |
| **loading `.asm` files** | **§19** | `#INCLUDE` adopted; `GP.ASMFILE` dropped |
| what is still open | **§Q2**, plus **§15.2** and **§15.7** | §Q2 supersedes §Q |
| the background | §1-§12 | ground truth, measured |

**Two sections are stale and kept only for the record:**

- **§13 (cost) is superseded by §14.** §13 counted compile-time memory and led
  with a 12.7% cut in maximum program size. Compile-time memory was later ruled
  out of scope, which changes the design and the answer. §14 is the live one.
- **§Q (open questions) is superseded by §Q2.** Q1/Q2/Q4/Q8 are decided (§D),
  Q9 is answered by §10.

**§10 is corrected by §15.3** — it argued the object base is *forced* to
`ObjectBase`; that holds only if the handler is linked into `gp-runtime/`.

**Also note §3 is incomplete on its own.** It concludes a variable's address is
not known until run time. That is true from the *runtime's* side; **§14.1 shows
the compiler computes it** (`newWorkspacePage`), which is what makes `{VAR}`
free. Do not read §3 without §14.1.

### The short version

- The compiler emits **p-code**, not native code (§1.1). Inline ASM is an
  embedded blob plus an opcode that enters it.
- **`GP.CALL` + `GP.A/X/Y/C` already exist** and already do registers in/out
  (§1.3). The missing piece is only the assembler; today the bytes are
  hand-POKEd (`GPC-BASIC/MLCALL.EXP.BL`).
- **Bare assembly text does not survive tokenisation** — measured (§2.3).
  Quoting does (§2.4). Hence `GP.ASM "LDA {A}"`.
- **No relocation is needed** (§10) — the blob's run address is computable at
  compile time.
- **`{VAR}` costs nothing at run time** (§14.2) — the compiler knows
  `variableStartPage` and already patches operands on the way out.
- **Net runtime cost: ~0 bytes** (§14.9). A ~40-byte handler fits in the
  **78 bytes of slack measured in the GP block** (§14.4, corrected in §18.1). All the cost is
  compiler-side, which is out of scope.
- **Cap: 127 bytes of machine code per block** (§11, corrected in §18.2 — it is
  not 255), and `GP.ASM` **cannot be a
  shifted opcode** (§14.5).
- **Since GP.IF (§15): where the handler is linked is worth 2,048 bytes** to a
  program using assembly and no other GP keyword (§15.2), and a per-line
  `GP.ASM "..."` form is close to unusable — each statement becomes its own blob,
  so branches between instructions are impossible (§15.7).


## 0. The feature as asked for

```basic
  ASM
     lda {A}
     ldx #$23
     ldy #$9F
     sec
     jsr {MACPTR}
     stx {XR}
     sty {YR}
  END ASM
```

Two distinct things are being asked for:

1. **A block of 65C02 assembly** embedded in a BASIC program and assembled
   into the object at compile time.
2. **`{NAME}` — a substitution syntax that reaches out of the assembly and
   names something the BASIC side knows about**: a BASIC variable (`{A}`),
   a KERNAL entry point (`{MACPTR}`), and apparently a pseudo-register
   (`{XR}`, `{YR}`) for handing results back.

(2) is the hard half and the interesting half. (1) is mostly bookkeeping.

## 1. Ground truth established so far

### 1.1 The compiler emits p-code, not native code

This is the single most important constraint and it is easy to get wrong,
because the README's headline says the opposite at a glance:

> "turns tokenised Commander X16 BASIC into a **standalone 65C02 machine-code
> program**. There is no runtime interpreter in the output"

That means **no BASIC interpreter** in the output. There *is* a P-code VM.
The README says so plainly further down (`README.md:88`, `:144`, `:233`):

- the debug map's columns are "a 4-digit hex **p-code offset**" and a line number;
- runtime errors report a p-code offset — `DIVIDE BY ZERO @ $0030`;
- "every compiled program carries the same support runtime — **the P-code VM**,
  all command handlers, ...";
- the object file is "bootstrap plus p-code" (`README.md:164`).

The compiler's whole output path is `WriteCodeByte` emitting `PCD_*` opcodes
(`source/compiler/source/main/compiler.asm` — `PCD_CMD_GOTO`, `PCD_EXIT`,
`PCD_CMD_VARSPACE`, `PCD_CMD_DEFERROR`).

**Consequence for this feature:** inline assembly cannot simply be "emitted
inline with the surrounding code", because the surrounding code is not
machine code. It has to become *a native blob embedded in the p-code stream*
plus *a p-code opcode that jumps into it*. That shapes everything downstream:
where the blob lives, how the VM gets into and out of it, and what state the
blob is allowed to touch.

### 1.2 Code generation is table-driven

`source/compiler/source/generation/commands.def` is the command table; each
line is a keyword and a little string of generator directives, executed a
nibble at a time by `GeneratorExecute` in
`source/compiler/source/generation/genexec.asm`. The directive nibbles are:

| nibble | meaning |
| --- | --- |
| 1 / 2 | compile a 1- or 2-byte token |
| 3 | `X:` run arbitrary compiler code |
| 4 | `C:` run arbitrary code, channel redirection possible |
| 6 / 7 | exit returning number / string type |
| 8 / 9 / A | require `(` / `)` / `,` |
| E / F | compile any number / any string |

So a new statement is normally "a line in `commands.def`" + "a compiler
routine named by `X:`" + "a runtime handler". A block construct that swallows
raw text is not a normal statement, so how much of this machinery applies is
an open question (§Q).

### 1.3 The precursor already in the tree: `GP.CALL` + `GP.A/X/Y/C`

**This feature is not starting from zero.** GP.BASIC already has a way to run
machine code and exchange register values with it, shipped and documented:

```basic
GP.CALL ADDR, 65, 0, 0, 1      : REM  A=65, X=0, Y=0, carry=1  (all optional, default 0)
A = GP.A : X = GP.X : Y = GP.Y : C = GP.C
```

Tokens `52860..52856` (`$CE7C..$CE78`), declared in
`source/common-scripts/c64tokens.py` `getGP()` and mirrored in
`GPC-BASIC/GPB.INC.BL`. The worked example is `GPC-BASIC/MLCALL.EXP.BL`.

Two facts recorded there that this feature inherits:

- the four values **share `SYS`'s `$030C-$030F`**, so they also read back what a
  plain `SYS` left behind;
- carry is set with `LSR`, **not `PLP`**, so the caller's interrupt-disable and
  decimal flags survive.

And the warning that matters most, from both `GPB.INC.BL` and `MLCALL.EXP.BL`:

> **Put machine code in BANKED RAM (`$A000-$BFFF`), NOT `$0400-$07FF`.** Stock
> X16 BASIC leaves `$0400` free for the user; a **compiled GPC program does
> not** — that page holds runtime state (`stringHighMemory`, `storeStartHigh`,
> `variableStartPage`), and POKEing code over it corrupts the program silently.

**What is missing is exactly the requested feature.** Today the *bytes* must be
hand-assembled and POKEd one decimal literal at a time:

```basic
POKE ML.INCS+0, 26        ## INC A
POKE ML.INCS+1, 232       ## INX
...
```

So `ASM ... END ASM` is best understood not as a new subsystem but as **a
compile-time assembler that removes the hand-POKE step** from a mechanism that
already exists. That framing matters for scoping: the runtime side (call it,
pass registers, read them back) is already built and tested.

The user's `{XR}` / `{YR}` map onto the existing `GP.X` / `GP.Y`.

## 2. The source pipeline — where tokenisation happens

This is the constraint that decides the *syntax*, so it is worth being exact.
GP.BASIC sources are `.BL` files (BASLOAD source, plain text) that become
tokenised `.PRG`. **Two different tokenisers exist**, and a design has to work
under whichever ones it must support:

| tokeniser | where it runs | how it learns `GP.*` |
| --- | --- | --- |
| **BASLOAD** | inside the X16 ROM — the build boots the bundled emulator headless and "types" `BASLOAD "X.BASL"` (`source/gpc/build_basl.py`) | `#TOKEN GP.DO 52863` lines in `GPC-BASIC/GPB.INC.BL` |
| **host-side** `bin/tokenise.zip` | on the PC | reads `c64tokens.py` at build time (per `GPB.INC.BL`'s header) |

Note `build_basl.py`'s header states plainly: *"BASLOAD is an X16 ROM utility,
so there is no host-side tokeniser for it"* — the host-side tokeniser is a
separate path, not a BASLOAD reimplementation. **Which of the two an ASM block
has to survive is an open question (§Q).**

`GP.*` tokens are `$CE7x` shifted tokens allocated **downward** from `$CE7F`,
deliberately into the 127 slots (`$CE01-$CE7F`) that the ROM's own upward
numbering structurally cannot reach. Consequence already accepted in this
project: **a PRG containing a GP token is compile-only — the ROM can neither
`LIST` nor `RUN` it.**

### 2.1 The compiler reads RAW TOKENISED BYTES

`ProcessNewLine` (`source/compiler/source/helpers/api.asm:68`) sets `srcPtr` to
the line body — start of line **+4** (link word + line-number word) — and the
compiler walks the tokenised bytes from there. There is no detokenise-to-text
step. So whatever the tokeniser did to the assembly text is what the compiler
sees.

**This is the crux of the whole design.** Free-form text like `lda {A}` does not
survive a BASIC tokeniser unexamined: a tokeniser matches keywords greedily at
every character position, so mnemonics and operands containing keyword spellings
get rewritten to token bytes. Candidates to check by measurement, not by
reasoning (§Q): `ROR` (contains `OR`), `AND`, `ORA` (contains `OR`), `NOT`,
`DEC`, `TO` inside a label. This must be *tested*, not assumed — the whole
question is what a given tokeniser does, and the two tokenisers may differ.

### 2.2 `DATA` is the existing precedent for slurping raw text

`source/compiler/source/commands/data.asm` is the pattern an ASM line would
follow: after the opening token, copy every remaining byte of the line verbatim
into a buffer (`BufferWrite`/`GetNext` to end of line), then emit an opcode
(`PCD_CMD_DATA`) followed by the buffered bytes (`BufferOutput`). It shows the
machinery for "this statement owns the rest of the line" already exists.

### 2.3 MEASURED: what the host tokeniser does to assembly text

Not reasoned about — run. `bin/tokenise.zip` was unpacked and its `Tokeniser`
class driven directly over candidate lines (2026-08-30). Bare, unquoted text:

```
LDA {A}        -> LDA {A}
LDX #$23       -> LDX #$23
LDY #$9F       -> LDY #$9F
SEC            -> SEC
JSR {MACPTR}   -> JSR {MACPTR}
STX {XR}       -> STX {XR}
STY {YR}       -> STY {YR}
ORA #$01       -> <B0>A #$01        <-- MANGLED  (OR token $B0)
EOR #$FF       -> E<B0> #$FF        <-- MANGLED
AND #$0F       -> <AF> #$0F         <-- MANGLED  (AND token $AF)
ROR A          -> R<B0> A           <-- MANGLED
JMP DONE       -> JMP D<91>E        <-- MANGLED  (ON token $91)
LDA STORE      -> LDA S<A4>RE       <-- MANGLED  (TO token $A4)
LDA NOTYET     -> LDA <A8>YET       <-- MANGLED  (NOT token $A8)
LDA ONTOP      -> LDA <91><A4>P     <-- MANGLED
ROL A / INC A / DEC A / NOP / STZ / TAX / PHX / LSR / BNE LOOP / JMP  -- all clean
```

**The user's example happens to survive intact — but that is luck, not safety.**
Four common mnemonics (`ORA`, `EOR`, `AND`, `ROR`) are destroyed, and so is any
*label or symbol* containing `ON`, `TO`, `NOT`, `OR`, `AND`, `IF`, `FN`, ... —
`STORE`, `DONE`, `NOTYET`, `COUNTER`, `TOTAL` are all ordinary label names.

Why: the tokeniser retries a longest-match keyword lookup **at every character
position**, not just at token starts. Its own source comments this, from the
`PSGCHORD` bug — *"matched the OR in psgchORd"*.

So **bare unquoted assembly text is not viable.** This is the finding that
drives the syntax question.

### 2.4 MEASURED: quoting IS a complete escape hatch (host tokeniser)

```
GP.ASM "ORA #$01"   -> <CE>{SM "ORA #$01"
GP.ASM "AND #$0F"   -> <CE>{SM "AND #$0F"
GP.ASM "JMP ONTOP"  -> <CE>{SM "JMP ONTOP"
```

Everything inside the quotes is preserved byte for byte (uppercased — the
tokeniser does `body.upper()` before anything else, which is harmless for
assembly). Quoted text is copied verbatim by `tokeniseOne`'s first branch.

Two incidental findings from the same run, both worth keeping:

- **`REM` does *not* protect text in this tokeniser**: `REM ORA #$01` came out
  `<8F> <B0>A #$01` — it keeps tokenising past the `REM`. (The *ROM* tokeniser
  stores REM text verbatim; this host tool does not. Do not assume they agree.)
- **`GP.ASM` tokenised as `<CE>{SM`** — i.e. the existing **`GP.A` token
  ($CE7B) swallowed the prefix** and left `SM` as bare characters. Longest-match
  would fix it once `GP.ASM` is a real table entry (6 chars beats 4), but it is
  a live reminder that any new `GP.A*` keyword collides with `GP.A` until it is
  registered in **both** `c64tokens.py` and `GPB.INC.BL`.

## 3. Sharing variables — how a BASIC variable is actually addressed

This is the half the request calls out specifically ("feature to share vars"),
and it is where the p-code architecture bites hardest. Traced end to end:

### 3.1 Compile time: variables are OFFSETS, not addresses

- `CreateVariableRecord` (`source/compiler/source/storage/create.asm`) allocates
  each new variable from `freeVariableMemory` and stores that value in a 6-byte
  record (2-byte name, 2-byte address, link).
- `STRReset` (`storage/reset.asm:49`) initialises `freeVariableMemory` to **0**.
  So the stored "address" is an **offset from the start of the variable block**,
  counting up from zero in order of first appearance.
- `GetReferenceTerm` (`variables/refterm.asm`) documents it in as many words:
  *"returning **offset** in YX"*.

This is what `samples/shared-vars/readme.md` means by *"The compiler assigns each
variable a fixed address by order of first appearance"* — and why its rule 1 is
that both programs in a chain must **first touch the shared variables in the same
order**, or the offsets do not line up.

### 3.2 The reference is folded into the opcode

`GetSetVariable` (`variables/readwrite.asm`) emits a **2-byte** p-code reference:

- the offset is **halved** (variables are even-aligned), leaving 11 significant bits;
- the top 3 bits are OR'd **into the opcode byte**, along with the type (float /
  int16 / string, bits derived from `NSSTypeMask`) and **bit 3 = write**;
- the low 8 bits are the second byte.

So there is no absolute address anywhere in the object.

### 3.3 Run time: base is `variableStartPage`, decided when the program starts

- `CommandVarSpace` (`runtime/source/support/allocate.asm`) reads the patched
  `.varspace` operand and does `adc variableStartPage` to get a real address.
  (The operand itself is back-patched by `_FBFixVarSpace` in
  `fix-branches/fixbranches.asm:130` with the final `freeVariableMemory`.)
- The `vaddress` macro (`runtime/source/memory/support.inc`) is what every
  variable read/write goes through: unpack the 11-bit halved offset, `asl`/`rol`
  to undo the halving, then **`adc variableStartPage`**.
- `variableStartPage` is set in `StartRuntime`
  (`runtime/source/main/00runtime.asm:37`) from **X on entry** — the same value as
  `storeStartHigh`, handed in by the bootstrap.

**Therefore: a variable's absolute address is not known until the program runs,
and it differs between embedded and shared-runtime builds and with the program's
own size.** The `~$8100` in the shared-vars readme is an observation about one
build, not a constant to assemble against.

### 3.4 What that means for `{A}`

`{A}` cannot become a literal absolute address at assembly time. The realistic
options — none chosen, this is the central design decision (§Q):

1. **Runtime relocation.** Assemble `LDA $00nn` with `nn` = the variable offset,
   and emit a **fixup list** alongside the blob naming every byte that holds a
   variable-address high byte. Something adds `variableStartPage` to each, once,
   before the blob first runs. Costs a fixup table and a patch pass; gives the
   blob direct absolute addressing, which is the fastest and most natural to
   write assembly against.
2. **Zero-page window.** The VM points a zero-page pointer at the variable block
   before entering the blob; `{A}` assembles to `($nn),y`-style access with a
   compile-time-known `y`. No patching, but it changes the addressing mode the
   programmer writes, and burns a zp pair.
3. **Copy in / copy out.** Named variables are copied to a fixed scratch area
   before the call and back after. Simplest and safest; the `{XR}`/`{YR}` in the
   request already have exactly this shape (they are the existing `GP.X`/`GP.Y`
   `$030C-$030F` slots). Costs cycles per call and does not scale to arrays or
   strings.

**Types matter and are easy to overlook.** A GPC scalar is not one byte. The
type bits distinguish **float / int16 / string** (`NSSTypeMask`, `NSSIInt16`;
floats are the `ifloat32` format — see `source/ifloat32/`). `LDA {A}` is only
meaningful once it is decided what `{A}` denotes for each type: the first byte,
the whole value, or its address. Strings are worse — a string variable holds a
pointer to a `[ActLen][Data]` block (that is exactly what the existing
`GP.STRPTR` returns), so `{A$}` would have to mean the pointer, not the text.

### 3.5 The existing register hand-back is already built

`{XR}` / `{YR}` need no new mechanism: `GP.A` / `GP.X` / `GP.Y` / `GP.C` already
read back `$030C-$030F` after a `GP.CALL`, sharing `SYS`'s slots. Whether inline
ASM should reuse those or define its own convention is an open question, but the
runtime plumbing exists and is tested.

## 4. Where the assembled bytes go, and the relocation problem

### 4.1 The object moves after compilation

The object's base is **not fixed**. `docs/blitz/GP-BASIC.TIERS.md` (Tier 7)
records that a program using no GP keyword has the whole GP block cut out of its
object, and `compiler/gpscan.asm` then walks the finished p-code with
**`MoveObjectForward`** so the code lands at `GPBase` instead of `ObjectBase` —
measured as a drop from 14,591 to 12,031 bytes, moving the workspace 2,560 bytes
with it. Shared mode changes the layout again (bootstrap at `$0801`, runtime at
`RTBASE`).

So the address a given p-code byte will occupy is decided **after** the statement
is compiled, and differs by build mode.

**Consequence:** a native blob embedded in the p-code stream is *relocatable
data*, not fixed-address code.

- **PC-relative** control flow inside the blob (`BNE`, `BEQ`, `BRA`, ...) is
  position independent and safe.
- **`JMP` / `JSR` to a label inside the blob** is absolute on 65C02 and would
  break, unless the blob is relocated or those are restricted or rewritten.
- Absolute references *out* of the blob (KERNAL, VERA, the runtime's own
  routines) are fine — those addresses are genuinely fixed.

Note the Tier 7 audit already had to prove "every instruction below `GPBase` was
scanned for an operand landing inside the block: zero hits". Inline ASM
introduces exactly the class of reference that audit was checking for, so it
interacts with that guarantee and with `gpscan.asm`'s decision rule, which
classifies an opcode as GP or not **by comparing its handler address against
`GPBase`**.

### 4.2 How control would enter the blob

`GP.CALL`'s handler (`source/gp-runtime/source/commands/gpcall.asm`) shows the
whole entry/exit shape already exists and is small: save Y (the p-code offset),
pop carry/Y/X/A off the float stack into `SYS_Reg_*`, pop the target address into
`zTemp0`, save X, set carry with `LSR`, load the registers, `jsr` to a
`jmp (zTemp0)`, then `PHP` and store A/X/Y/status back into `SYS_Reg_*`, restore
X and Y, `.exitcmd`.

The two invariants any inline-ASM entry must also honour, both visible there:

- **X is the float/expression stack pointer** and Y is the p-code offset — both
  must be saved across the call and restored. A blob that clobbers X without
  saving it corrupts the expression stack.
- **`.entercmd` / `.exitcmd`** are the VM's dispatch wrapper; the blob has to
  return into it.

An inline block therefore looks a lot like `GP.CALL` with the target being "the
bytes immediately following this opcode" instead of a value popped off the stack,
plus a length so the VM can skip past them. That is a genuinely small runtime
addition — the expensive part is elsewhere (§5).

### 4.3 Candidate homes for the bytes

1. **Inline in the p-code stream**, skipped over by the opcode. Simplest to
   reason about, no allocation, blob always present and matched to the code.
   Pays the relocation problem of §4.1 and spends p-code budget (18,432 bytes).
2. **Banked RAM `$A000-$BFFF`**, which is what `MLCALL.EXP.BL` already tells
   people to do by hand. Fixed, known addresses — **no relocation problem at
   all** — and does not consume the p-code budget. Costs a bank-management story
   (who owns which bank, what happens with two blocks) and a copy-in step.
3. **A dedicated region reserved at the top of the object**, relocated once by
   the existing `MoveObjectForward` pass.

**`$0400-$07FF` is excluded**, loudly and already documented: a compiled GPC
program keeps runtime state there (`stringHighMemory`, `storeStartHigh`,
`variableStartPage`) and code written over it corrupts the program **silently**.

## 5. Where the assembler itself runs — the biggest cost question

**The compiler is a 65C02 program that runs on the X16.** `GPC.BIN` is
**22,498 bytes** today. A 65C02 assembler is not a small thing to add to it:
mnemonic table, addressing-mode resolution, a symbol table for labels, forward
references, and a second pass — all on a machine where the compiler already has
to police its own table growth (`CreateVariableRecord` raises `PROGRAM TOO BIG`
when the variable list runs into the line-number table coming the other way).

There are two very different places it could live, and the choice changes the
size of this project by an order of magnitude:

**(a) In the compiler, on the X16.** Inline ASM works for anyone compiling on
real hardware or in the emulator, with no host toolchain. This is consistent with
the project's stated shape — "The compiler itself is a 6502 program — it runs on
the X16". It is also by far the most code, in the place with the least room.

**(b) On the host, before tokenisation.** A preprocessor expands the ASM block
into something the existing compiler already understands — plausibly a `GP.CALL`
plus the byte-poking that `MLCALL.EXP.BL` does by hand, or a `DATA` block.
**Zero compiler change, zero runtime change**, and the assembler can be Python
next to the other tools in `source/common-scripts/`. But it only works for
host-driven builds, and the current `.BL` path deliberately runs BASLOAD
**inside the emulator** (`source/gpc/build_basl.py`) precisely because there is
no host-side BASLOAD — so where such a preprocessor would sit in that pipeline
needs thought.

A middle option **(c)**: the assembler is a separate X16-side tool, or a
`GP.*`-aware pass, rather than being welded into `GPC.BIN`.

## 6. Syntax, given the tokeniser measurements

Because bare text is mangled, the realistic spellings quote the assembly:

```basic
GP.ASM "LDA {A}"
GP.ASM "LDX #$23"
```

or a block whose lines are individually quoted:

```basic
GP.ASM
  "LDA {A}"
  "JSR {MACPTR}"
GP.ENDASM
```

The requested spelling —

```basic
ASM
   lda {A}
END ASM
```

— has three problems, all with answers, none free:

1. **Unquoted text is mangled** — `ORA`, `EOR`, `AND`, `ROR`, and any label
   containing `OR` / `TO` / `ON` / `NOT`. Measured, §2.3.
2. **`ASM` and `END ASM` are not tokens.** `END` already is a keyword, so
   `END ASM` parses as `END` followed by a variable named `ASM`. GP.BASIC's whole
   convention is the `GP.` prefix precisely so extensions can never collide with
   the ROM (`GP-BASIC.PLAN.md` §2), which argues for `GP.ASM` / `GP.ENDASM`.
3. **`GP.ASM` collides with the existing `GP.A` token** until registered —
   measured in §2.4, where `GP.ASM` tokenised as `<CE>{SM`. Registering it in
   `c64tokens.py` **and** `GPB.INC.BL` fixes it by longest match.

A block form also has to survive the compiler's statement loop, which is
line-at-a-time (`MainCompileLoop` reads one line, then splits on `:`), so
"swallow lines until `GP.ENDASM`" is a mode the main loop does not currently
have. `GP.SELECT` / `GP.CASE` / `GP.ENDSEL` are the precedent for a multi-line GP
construct — but they resolve across lines via `fixbranches`, not by swallowing.

## 7. Rough shape of the work, if it were built compiler-side

Not a plan — a scale estimate, so the questions below can be answered knowingly.

| piece | where |
| --- | --- |
| `GP.ASM` / `GP.ENDASM` tokens | `source/common-scripts/c64tokens.py` `getGP()` **and** `GPC-BASIC/GPB.INC.BL` — same change, the token values are the ABI |
| table entry | `source/compiler/source/generation/commands.def`, an `X:` routine |
| text capture | new compiler routine, modelled on `commands/data.asm` |
| the assembler | new, and the largest piece — mnemonics, addressing modes, labels, two passes |
| `{...}` resolution | hooks `FindVariable` / `CreateVariableRecord`; needs a symbol source for KERNAL names |
| new p-code opcode | `pcodetokens.inc` (generated), `pcodesize.asm`, runtime `vectors.asm` |
| runtime handler | `source/gp-runtime/source/commands/`, modelled on `gpcall.asm` |
| relocation | interacts with `compiler/gpscan.asm` and `MoveObjectForward` |
| docs and example | `GPC-BASIC/GP-BASIC.md`, a new `ASM.EXP.BL` |

Note the ABI ratchet: adding a runtime opcode is not free. `GP-BASIC.PLAN.md`
records that opcodes are "gathered in directory order, so a new file renumbers
every opcode after it — `RT_ABI` went 3 to 4 for exactly this", and a bumped
`RT_ABI` forces every shared-mode program to be recompiled.

## Q. Open questions — nothing below is decided

> **SUPERSEDED by §Q2.** Q1/Q2/Q4/Q8 were answered on 2026-08-30 (§D), and Q9
> is answered by §10. Kept so the superseded numbering still resolves.

1. **Where does the assembler run?** §5 (a) in `GPC.BIN` on the X16,
   (b) a host preprocessor, or (c) a separate tool. This is the single biggest
   fork; everything else is downstream of it.
2. **Is quoted assembly acceptable?** Bare `lda {A}` is not safe (§2.3). Is
   `GP.ASM "LDA {A}"` an acceptable spelling, or is unquoted text a hard
   requirement — which would mean owning the tokenisation path?
3. **One statement per instruction, or a real block?** A block needs a
   swallow-until-terminator mode the compiler's line-at-a-time loop lacks (§6).
4. **What must `{VAR}` support?** Numeric scalars only, or also strings and
   arrays? Strings are pointers to `[ActLen][Data]`, floats are `ifloat32` — so
   "the address of" is the only uniform meaning (§3.4).
5. **Read-write or read-only?** May the blob *write* a BASIC variable, or only
   read it? Writing means the assembler must respect the type's layout.
6. **How is `{MACPTR}` resolved?** KERNAL names need a symbol table from
   somewhere. Fixed built-in list, a user-supplied `#DEFINE`, or just "any
   `{NAME}` not a BASIC variable is looked up in a KERNAL table"?
7. **`{XR}` / `{YR}` — new convention or the existing `GP.A/X/Y/C`?** The
   `$030C-$030F` slots already do this and are shared with `SYS` (§3.5).
8. **Where do the bytes live?** §4.3 — inline p-code (relocation needed) or
   banked RAM (fixed addresses, bank management needed).
9. **Are intra-blob `JMP` / `JSR` and labels in scope?** If yes, relocation is
   required (§4.1). If branches-only, the problem largely disappears.
10. **Is an `RT_ABI` bump and forced recompile of shared-mode programs
    acceptable** for this feature (§7)?
11. **Which tokeniser must this work under** — BASLOAD (the `.BL` authoring path),
    the host `bin/tokenise.zip`, or both? They demonstrably differ (`REM` is
    verbatim in the ROM, not in the host tool — §2.4).

## D. Decisions taken 2026-08-30

These answer the corresponding questions in §Q. Everything else in §Q is still open.

| # | Decision | Consequence |
| --- | --- | --- |
| Q1 | **The assembler runs at compile time, on the X16** — inside `GPC.BIN`. Not a host preprocessor. | The largest piece of work, in the tightest space. §5(a). Budget analysis in §8. |
| Q2 | **Quoted, one instruction per line** — `"LDA {A}"`. | Safe under both tokenisers with no tokeniser work. §2.4. |
| Q4 | **`{VAR}` must reach strings and arrays**, not just numeric scalars. | The hardest variable case. Layouts in §9. |
| Q8 | **Assembled bytes go in the p-code**, unless relocation into banked RAM proves better. | Relocation must be answered, not assumed. §10. |

Two things the answers did not settle and that are assumed below, flagged so they
are not mistaken for decided:

- **Numeric scalars are in scope too.** Only strings and arrays were named, but
  they are the harder superset and `{A}` in the original request is a scalar.
- **Read *and* write.** "Fill a BASIC string in place" only means anything if the
  blob may write. Assumed read-write throughout; see §9 for what that costs.

## 8. The budget for an on-X16 assembler — measured

Decision Q1 puts the assembler inside `GPC.BIN`, so the question "how much
room is there?" stops being rhetorical. Measured from
`source/application/build/code.lbl` and `source/application/source/compiler/start.asm`:

```
$0801  [ runtime, minus the GP block ]
$3700  GPBase      [ GP.BASIC handlers ]
$3F00  ObjectBase  [ the compiler itself -- 8,448 bytes ]
$6000  FreeMemory  [ object code is built upward from here ]
$9F00  ObjectCeiling (I/O page; usable low RAM stops here)

banked RAM $A000-$C000 : the compiler's TABLES
                         variable-name list grows UP from $A000
                         line-number table grows DOWN from $C000
```

- **The compiler's own code is 8,448 bytes** (`ObjectBase $3F00` to
  `FreeMemory $6000`).
- **The object buffer is 16,128 bytes** (`$9F00 - $6000`).
- `GPC.BIN` is 22,498 bytes on disk, which is `$0801 + 22,496 = $5FE1` —
  consistent with `FreeMemory = $6000`, so these labels are current, not stale.

### 8.1 Every byte added to the compiler comes straight off the program ceiling

`FreeMemory` is `.align 256` immediately after the compiler's last byte
(`source/application/source/main/zzfree.footer`). So growing the compiler by N
bytes raises `FreeMemory` by N (rounded up to a page) and **shrinks the object
buffer by exactly the same amount**. There is no slack in between.

An assembler with a mnemonic table, addressing-mode resolution, a symbol table
and two passes is plausibly 2-4 KB. That is 2-4 KB off the maximum compilable
program, for every program, whether or not it contains a single line of assembly.

### 8.2 A stale README claim, worth correcting

`README.md` ("How big a program can it compile?") says the binding limit is the
**run** side — 18,432 bytes — and that *"what binds is not the compiler's buffer
(19,456 bytes)"*. That is no longer true: the buffer is **16,128** bytes today,
which is *below* the 18,432 run-side ceiling. **The compiler's buffer is now the
binding constraint**, and it has been shrinking as the compiler grew. Worth
checking and correcting independently of this feature.

### 8.3 Mitigations worth considering, none chosen

- **Put the assembler in banked RAM.** The compiler already reaches banked RAM
  through the `storage_access` / `storage_release` macros for its two tables, so
  the mechanism exists. The assembler's own symbol table almost certainly belongs
  there regardless. Running *code* from a bank is a bigger step than reading
  tables from one.
- **Make it optional.** The GP block is already cut out of an object that uses no
  GP keyword (`gpscan.asm`, Tier 7). The analogous trick — an assembler that is
  not resident unless needed — is harder for the *compiler*, since it must be
  present to know whether the program needs it. Loading it as an overlay on first
  `GP.ASM` is conceivable.
- **Restrict the assembler.** A subset — no expressions, no forward references,
  numeric literals only, one addressing mode per mnemonic decided by syntax — is
  dramatically smaller than a general assembler, and may be all inline assembly
  needs.

## 9. `{VAR}` for strings and arrays — the layouts

Decision Q4 puts strings and arrays in scope. Both already have a runtime
precedent that resolves exactly the address inline assembly would want, so the
semantics do not have to be invented — only reused.

### 9.1 Strings

From `source/gp-runtime/source/commands/gpstring.asm` (verified there against
`memory/read_string.asm`): `ReadStringZTemp0Sub` reads a string variable's block
address and **adds 2** before pushing it. So what `GP.STRPTR(a$)` hands back is
the address of `[ActLen][Data]`:

```
   A-2   MaxLen      (capacity the string was born with)
   A-1   control byte
   A     ActLen      (current length)
   A+1   first character
```

So `{A$}` has an obvious and already-established meaning: **the `GP.STRPTR`
address**. Assembly can read the length at `+0`, walk the text from `+1`, and
rewrite both — which is precisely the "fill a BASIC string in place" case, and
the reason `GP.STRPTR` exists.

**The hard limit to carry over:** a handler receives *the block*, never the
variable slot, so it **cannot repoint the variable at a larger block**. This is
recorded as the reason `GP.PAD` was written, worked, and then removed on
16/08/2026 — padding grows a string, and the capacity is fixed at birth
(`StringConcrete`: length + 50%, minimum 10). Inline assembly inherits the same
ceiling: **it may rewrite a string up to `MaxLen`, never beyond.** That needs
saying in the docs, because it is the first thing someone will try.

### 9.2 Arrays

`GP.ARRPTR` (`source/gp-runtime/source/commands/gpsort.asm`) shows the layout:
the base arrives as an **offset**, `variableStartPage` is added to reach the real
address, there is a **3-byte header**, and **element zero is at +3**. Byte 2 of
the header is a type byte whose **bit 7 means "sub-arrays below this level"** —
`GP.ARRPTR` raises an index error rather than hand back a pointer into a
multi-dimensional array.

So `{A()}` would sensibly mean the `GP.ARRPTR` address (element zero), with the
same one-dimensional-only restriction.

### 9.3 What this implies for the compiler side

The three `{...}` forms resolve to three different things, and the assembler has
to know which at compile time:

| form | compile-time value | run-time fixup |
| --- | --- | --- |
| `{A}` scalar | variable offset | `+ variableStartPage` |
| `{A$}` string | variable offset of the *slot* | `+ variableStartPage`, then **indirect** — the slot holds a pointer, so one more dereference (+2) to reach `[ActLen][Data]` |
| `{A()}` array | variable offset of the array structure | `+ variableStartPage`, then `+3` past the header |

**Only the scalar case is a single add.** Strings and arrays need a dereference
that assembly cannot do in one addressing mode, so `{A$}` cannot simply become an
absolute operand. The realistic options are that the VM resolves these *before*
entering the blob (into zero page or a fixed slot), or that `{A$}` is defined to
mean the *slot* address and the programmer does the indirection. That is an open
question (§Q, new item 12).

Also unresolved by "strings and arrays": a GPC numeric scalar is **`ifloat32`**,
not a byte or a word (`source/ifloat32/`). `LDA {A}` on a float loads its first
byte, which is almost certainly not what anyone means. Whether `{A}` on a numeric
should be legal at all, or only `{A}` on an int16, needs deciding.

## 10. Relocation — the open question from Q8, ANSWERED

> **Corrected by §15.3.** The conclusion (no relocation needed) stands, but the
> claim that a `GP.ASM` program is *forced* to base `ObjectBase` holds only if the
> handler lives in `gp-runtime/`. `gpUsed` is also not known while the statement
> compiles, so the patch-before-streaming approach of §14.2 is required, not
> merely convenient.

The concern in §4.1 was that the object moves after compilation, so an embedded
blob's internal `JMP`/`JSR` would need fixing up. **Traced, and the concern turns
out not to apply.** Three findings, all measured:

### 10.1 The object never moves within the buffer

`MoveObjectForward` (`source/common-source/source/forward.asm`) — the routine
`gpscan.asm` and `FixBranches` both walk with — is a **cursor advance by
instruction size**. It reads an opcode, looks up its length, and adds it to
`objPtr`. It does not relocate anything. The name is about moving a *pointer*
forward, not moving the object.

### 10.2 The run address is one of exactly two page values, both known at compile time

From `source/application/source/compiler/object.asm`:

- **Shared mode:** the file is a bootstrap at `$0801` followed by the p-code,
  and the code says plainly *"the p-code from FreeMemory..objPtr, which lands at
  **`$0900`** on reload"*.
- **Embedded mode:** the object code lands at `runtimeEndPage`, which is
  `GPBase` (**`$3700`**) if the program uses no GP keyword, or `ObjectBase`
  (**`$3F00`**) if it uses any. Both are page aligned.

And **a program containing `GP.ASM` uses a GP keyword by definition** — provided
its runtime handler lives in `gp-runtime/` (above `GPBase`), which is where it
belongs. `ScanGPUsage` sets `gpUsed` by comparing each opcode's handler address
against `GPBase`, so the answer is forced: **embedded + inline ASM always lands
at `ObjectBase = $3F00`.**

### 10.3 The mode is known before compilation starts

`CompileCode` (`source/application/source/compiler/start.asm`) calls
`ReadControlFile` **before** `StartCompiler`. `ModeText` — GPC.INPUT line 4,
`'S'` for shared — is therefore already set while statements are being compiled.

### 10.4 Conclusion: no relocation, no fixup table, no banked-RAM detour

Putting 10.1-10.3 together: while compiling a `GP.ASM` statement the compiler
knows both the base (`$0900` shared / `$3F00` embedded) **and** the blob's offset
(`objPtr - FreeMemory`). So **the absolute run address of every byte in the blob
is computable at compile time.** Labels, `JMP`, `JSR` and self-reference all just
work, assembled to real absolute addresses. Nothing needs patching at run time.

**This answers Q8 as asked: bytes in the p-code, and there is no better way.**
Relocating into banked RAM would *cost* rather than save — it adds bank
ownership, a copy-in step, and a second address space, to solve a problem that
does not exist. Two caveats keep it honest:

- **Variables still need the runtime add.** §3 is unchanged: `variableStartPage`
  is genuinely a run-time value, so `{A}` cannot be an absolute operand however
  well the blob's own address is known. The blob-internal addressing being solved
  does not solve variable addressing.
- **It is a compile-time coupling to the object layout.** If `GPBase` /
  `ObjectBase` / the shared `$0900` ever move, previously compiled objects
  containing assembly become wrong — silently, since the bytes still look valid.
  That argues for tying it to `RT_ABI` and for the compiler asserting the base it
  used. The Tier 7 audit in `GP-BASIC.TIERS.md` — *"every instruction below
  `GPBase` was scanned for an operand landing inside the block: zero hits"* — is
  exactly the kind of check that would need re-running.

## 11. A hard 255-byte limit per block, unless designed around

> **CORRECTED by §18.2: the real cap is 127, not 255.** The skip is an 8-bit
> add and Y is already 0..127 at handler entry, so Y+len+1 wraps above 127.
> This is also a latent hazard in existing DATA/string literals.

`MoveObjectForward` already supports variable-length opcodes, and `GP.ASM` must
use that form or both `ScanGPUsage` and `FixBranches` would try to decode native
bytes as p-code and derail. The mechanism: a size-table entry of **255** means
"string/data skip" — the walker reads a **single length byte** after the opcode
and skips that many bytes.

`source/common-source/source/generated/pcodesize.asm` shows two opcodes already
using it:

```
.byte 255  ; $df .string
.byte 255  ; $e0 .data
```

**So a blob carries an 8-bit length: 255 bytes maximum.** For inline assembly
that is a real ceiling — reachable, though probably not on a first cut. Options:
accept it and error clearly past 255; allow consecutive blocks to be chained; or
add a new two-byte-length skip form to the walker (a change to shared code that
`FixBranches`, `ScanGPUsage` and the runtime's `read.asm` all depend on).

## 12. Where the research leaves it

With Q1/Q2/Q4/Q8 decided, the feature has a coherent shape. Stated as findings,
not as a plan — no implementation order is proposed here.

**Settled by measurement, not opinion:**

- Bytes go **inline in the p-code**, and **no relocation is needed** (§10). The
  blob's absolute run address is computable at compile time.
- The blob must use the **variable-length opcode form** the walker already
  supports, which caps it at **127 bytes** (§11 as corrected by §18.2).
- Entry/exit is a near-copy of `CommandGPCall` (§4.2) — save Y and X, `jsr` into
  the blob, restore, `.exitcmd`. Small.
- `{A$}` and `{A()}` have established meanings already implemented by
  `GP.STRPTR` and `GP.ARRPTR` (§9).
- Syntax is `GP.ASM "..."` with quoted lines; `GP.ASM` / `GP.ENDASM` must be
  registered in **both** `c64tokens.py` and `GPB.INC.BL`, or `GP.A` swallows the
  prefix (§2.4).

**The two real costs:**

1. **The assembler itself**, which is the bulk of the work and comes straight
   off the maximum compilable program size, byte for byte (§8). This is the
   thing to size before committing.
2. **A new runtime opcode implies an `RT_ABI` bump**, which forces every
   shared-mode program to be recompiled (§7).

**The one genuinely unsolved piece** is `{VAR}` addressing (§3.4, §9.3):
`variableStartPage` is a run-time value, so a variable reference cannot be an
absolute operand no matter how well the blob's own address is known. Strings and
arrays need a dereference on top. This is where the next round of design work
belongs.

## Q2. Open questions after the 2026-08-30 answers

Superseded: Q1, Q2, Q4, Q8 (see §D). Q9 is answered by §10 — labels and
`JMP`/`JSR` inside a blob are fine. Still open:

3. **One statement per instruction, or a real block?** `GP.ASM "LDA {A}"` per
   line needs no new compiler mode. A `GP.ASM ... GP.ENDASM` block needs a
   swallow-until-terminator mode `MainCompileLoop` does not have (§6). With
   quoting decided, the block form buys less than it did.
5. **Read-write or read-only?** Assumed read-write (§D). If assembly may write a
   variable, the assembler and the docs must carry the type layouts — and for
   strings, the "never beyond `MaxLen`" rule that killed `GP.PAD` (§9.1).
6. **How is `{MACPTR}` resolved?** KERNAL names need a symbol source. Built-in
   table (costs compiler bytes, §8), a `#DEFINE` the programmer supplies, or
   "any `{NAME}` that is not a BASIC variable is looked up in a KERNAL table".
7. **`{XR}` / `{YR}` — reuse `GP.A/X/Y/C` or a new convention?** The
   `$030C-$030F` slots already do exactly this and are shared with `SYS` (§3.5).
10. **Is an `RT_ABI` bump acceptable**, forcing recompiles of shared-mode
    programs (§7)?
11. **Which tokeniser must this work under** — BASLOAD, host `tokenise.zip`, or
    both? Quoting makes both safe, so this may now be moot.
12. **NEW — how does `{A$}` / `{A()}` reach through the dereference?** (§9.3.)
    Does the VM resolve them into zero page before entering the blob, or does
    `{A$}` mean the slot address and the programmer does the indirection?
13. **NEW — what does `{A}` mean on an `ifloat32` scalar?** `LDA {A}` on a float
    loads one byte of a four-byte format. Legal, or restricted to int16?
14. **NEW — how big is the assembler allowed to be?** Every byte comes off the
    program ceiling, and the object buffer is already the binding constraint at
    16,128 bytes (§8.1, §8.2). A restricted assembler — no expressions, no
    forward references, literals only — is dramatically smaller.

## Side finding, unrelated to this feature

`README.md` is stale about compile limits: it says the compiler's buffer is
19,456 bytes and does not bind, but the buffer is **16,128** bytes today
(`$9F00 - FreeMemory $6000`) and is now *below* the 18,432-byte run-side ceiling.
**The buffer binds.** Worth fixing on its own account — see §8.2.

## D2. Further decisions, 2026-08-30

- **Numeric scalars are in scope** (confirmed, not assumed — supersedes the flag in §D).
- **Read *and* write**, for scalars, strings and arrays.
- **Multi-file assembly is `#INCLUDE` of a REM-bodied `.asm` file** (§19.1),
  which works today with no compiler change. **`GP.ASMFILE` is dropped**
  (§19.2) — removed from the plan, not carried to `TODO.md`.

Write access sharpens two things already recorded: the string capacity ceiling
that killed `GP.PAD` (§9.1) becomes a rule the assembler must enforce or document,
and `{A}` on an `ifloat32` scalar (§Q2.13) becomes more pressing — writing one
byte of a four-byte float leaves a malformed number, not an approximate one.

## 13. What this costs in bytes

> **SUPERSEDED by §14.** This section counts compile-time memory, which was
> later ruled out of scope. Its headline (a 12.7% cut in maximum program size)
> is a compile-time cost and no longer applies. Kept for the measured
> comparables in §13.1, which §14 reuses. **For the cost, read §14.**

Two separate budgets, and conflating them would mislead. Compiler bytes come off
the **maximum program size**; runtime bytes go into **every GP program's object**.
Measured comparables first, then the estimate built on them.

### 13.1 Measured comparables from this tree

From `source/application/build/code.lbl` (current build, `code.prg` = 22,498 bytes):

| thing | bytes | what it does |
| --- | --- | --- |
| `CommandGPCall` | **77** | the whole registers-in / call / registers-out handler |
| `UnaryGPArrPtr` | **49** | offset -> address, header check, +3, retype |
| `UnaryGPStrPtr` | **12** | retype an address already on the stack |
| `CommandDATA` (compiler) | **28** | slurp rest of line to buffer, emit opcode + buffer |
| `CommandPRINT` (compiler) | **126** | |
| `CreateVariableRecord` | **123** | allocate + link a variable record |
| `GeneratorExecute` | **181** | the whole nibble-driven generator |
| `ScanGPUsage` | **93** | walk all p-code, look up handler, compare |
| **whole GP runtime block** | **2,048** | `GPBase $3700` -> `ObjectBase $3F00`, ~31 keywords, **avg 66 each** |
| **whole compiler** | **8,448** | `ObjectBase $3F00` -> `FreeMemory $6000` |
| object buffer | 16,128 | `FreeMemory $6000` -> `ObjectCeiling $9F00` |

This codebase is *tight*. Routines are tens of bytes, and a whole keyword
averages 66. Any estimate that ignores that will be wrong high.

### 13.2 Compiler side — the assembler

Estimate, decomposed. These are engineering estimates, not measurements, and are
flagged as such:

| piece | est. bytes | note |
| --- | --- | --- |
| mnemonic table | 128 | ~64 65C02 mnemonics, 3 letters packed 5-bit into 2 bytes (the classic Supermon trick). 192 if stored plainly |
| opcode / addressing-mode table | 256 | one byte per opcode giving mnemonic index + mode; searched to assemble |
| operand parser | 300-400 | `#`, `$hex`, decimal, `(`, `)`, `,X`, `,Y`, `A`, labels, `{NAME}`. Lower end if it reuses the compiler's existing `helpers/constant.asm` and `helpers/get.asm` |
| addressing-mode determination | 120 | parsed shape -> mode code |
| emitter | 150 | opcode lookup, 1-3 byte emit, branch offset + range check |
| label table, two passes | 200-300 | can lean on the existing banked-RAM storage macros and `FindVariable` pattern |
| `{VAR}` resolution | 250 | name -> `FindVariable` -> offset + type; emit operand and a fixup entry; three type cases |
| statement plumbing | 200 | capture quoted text (`CommandDATA` is 28), block state, emit opcode + length + fixup table, errors |
| **total** | **~1,600-2,100** | call it **2 KB**, and round to **2,048 (8 pages)** for planning |

### 13.3 Runtime side — the handler

| piece | est. bytes | note |
| --- | --- | --- |
| enter / exit the blob | 80 | near-copy of `CommandGPCall` (**measured 77**) |
| fixup resolver | 200 | walk the table; three kinds — scalar `+variableStartPage`, string deref, array deref +3. `UnaryGPArrPtr` does the array half in **49 measured** bytes |
| **total** | **~280** | call it **250-400** |

That lands close to the measured 66-byte average per GP keyword times a handful,
which is the sanity check it should pass.

### 13.4 What each budget actually costs you

**Compiler (~2 KB): comes straight off every program's ceiling.**
`FreeMemory` is `.align 256` immediately after the compiler's last byte, so
+2,048 bytes of compiler moves `FreeMemory` `$6000 -> $6800` and the object
buffer goes **16,128 -> 14,080 bytes, a 12.7% cut in maximum program size** —
paid by every program, including ones with no assembly in them. Given §8.2 (the
buffer is already the binding limit, below the 18,432 run-side ceiling), this is
the real price of the feature.

**Runtime (~300 bytes): paid by GP programs only.**
It joins the GP block, which the Tier 7 cut already omits from any object using
no GP keyword. `2,048 -> ~2,350`, and since `GPBase`/`ObjectBase` are page
aligned it will round to a whole page — so realistically **+512 bytes** to a GP
program's object, and **0** to a non-GP one.

**Per use, in p-code:** `1 (opcode) + 1 (length) + blob + fixup table`, with
fixups at 1-2 bytes each. So roughly **the size of the machine code itself**.

### 13.5 The offsetting saving, which is large

Against that, inline assembly is *dramatically* cheaper per byte of machine code
than what the tree does today. `MLCALL.EXP.BL` pokes each byte with its own
statement:

```basic
POKE ML.INCS+0, 26        ## INC A
POKE ML.INCS+1, 232       ## INX
```

Each such line is a whole BASIC statement — push an address expression, push a
value, `POKE` — and `README.md` puts the average at **~14 bytes of p-code per
BASIC line**. So the current idiom costs on the order of **14 bytes of p-code per
byte of machine code**; inline assembly costs about **1**.

A 100-byte machine-code routine is therefore roughly **1,400 bytes of p-code
today** against **~120 with this feature**. Anyone actually using `GP.CALL` today
gets that back immediately — it takes only a few hundred bytes of hand-poked
machine code across a program to repay the 2 KB ceiling cut.

### 13.6 The mitigation that removes the compiler cost entirely

The ~2 KB ceiling cut is avoidable, and this is worth weighing before accepting it.

Banking on this machine is cheap — `storage_access`
(`source/compiler/source/system-specific/x16/x16_storage.inc`) is just "save the
bank register, write `CompilerStorageBank`, restore" — and switching the
`$A000-$BFFF` window leaves **low RAM mapped throughout**, so code running from a
bank can still call the compiler's low-RAM helpers. It only must not switch banks
while executing from one.

The compiler already owns one whole bank for its tables (`CompilerWorkspaceStart
$A000` to `CompilerWorkspaceEnd $C000` = exactly 8 KB = one bank), and the X16 has
many more.

So: **load the assembler as an overlay from disk into a second bank, on first
`GP.ASM`.** It never occupies low RAM, `FreeMemory` never moves, and the object
buffer stays at 16,128 bytes. The costs are a second shipped file, its load time,
and bank discipline. Whether that trade is worth it is a decision, not a finding —
but it means **the 12.7% ceiling cut is a choice, not a requirement.**

### 13.7 Summary

| | bytes | who pays |
| --- | --- | --- |
| assembler, in the compiler | **~2,048** (est.) | **every program** — max size 16,128 -> 14,080 (-12.7%) |
| assembler, as a banked overlay | **0** low RAM | nobody; costs a file + load time + bank discipline |
| runtime handler | **~300**, rounding to a page | GP programs only; 0 for non-GP programs (Tier 7 cut) |
| per `GP.ASM` block | ~ size of the machine code + 2 | the program using it |
| *saving* vs today's `POKE` idiom | **~13 bytes of p-code per byte of ML** | anyone already writing machine code |

Plus one non-byte cost already noted (§7): a new runtime opcode means an
**`RT_ABI` bump**, forcing every shared-mode program to be recompiled.

### 13.8 Why the resolver runs on every entry, not once

Relevant to the runtime cost above, and a correctness trap worth stating plainly.

**There is no garbage collector.** Strings are allocated *downward* from
`stringHighMemory` and arrays *upward* from `availableMemory`, and the two ends
simply may not cross — `DIMWriteByte` refuses to let the arrays reach the string
ceiling's page and `StringConcrete` refuses to bring the ceiling below
`availableMemory` (`runtime/functions/number/fre.asm`). Nothing is ever compacted,
so **no live block is ever relocated behind your back.**

That is not the same as "a variable's block address is stable". Assigning a new
value to a string allocates a **fresh block** and repoints the slot. So:

- **`{A$}` must be resolved on each entry to the blob.** Patching it once and
  reusing it means that the moment BASIC does `A$ = A$ + "X"` between two `GP.ASM`
  blocks, the second one writes into the *previous* block — which is still live
  memory, so there is no error, just corruption.
- **`{A()}` likewise**: an array's structure is allocated at `DIM`, and a `CLR`
  followed by a re-`DIM` can place it elsewhere.
- **`{A}` scalars are the exception.** `variableStartPage` is fixed for the whole
  run (set once in `StartRuntime`), so a scalar's absolute address genuinely is
  constant, and patch-once would be safe. Whether that special case is worth the
  extra state is a decision, not a finding.

The cost estimate in §13.3 assumes resolve-on-entry for all three, which is the
safe choice.

## 14. Cost, redone: RUNTIME ONLY

> **Supersedes §13.** Compile-time memory is explicitly not a concern
> (2026-08-30). §13's headline — a 12.7% cut in maximum program size — was
> entirely a *compile-time* cost and is struck. What follows counts only bytes
> that end up in the compiled program or in the runtime it carries.

Removing the compile-time budget does not just delete a row from the table. It
**changes the right design**, because work moved into the compiler is now free.
That turns out to eliminate almost the entire runtime cost.

### 14.1 The finding that does it: the compiler already knows `variableStartPage`

§3 established that a variable's address is `offset + variableStartPage`, and
that `variableStartPage` is a run-time value — which is why §3.4 listed three
awkward options (runtime relocation, a zero-page window, copy in/out).

**That was researched from the runtime's side only, and it is incomplete.** From
the *compiler's* side (`source/application/source/compiler/object.asm`):

- `WriteObjectCode` computes **`newWorkspacePage`** = `runtimeEndPage` +
  pages(object) + `FrameStackPages`, and rejects the program if it does not fit.
- It then **patches that value into the streamed file** — the `RunWorkspacePage+1`
  immediate in the embedded path, and `BootWSPatchOffset` in the shared path.
- `StartRuntime` (`runtime/source/main/00runtime.asm:37`) takes exactly that page
  in X and does `stx variableStartPage`.

So **`variableStartPage` *is* `newWorkspacePage`, and the compiler computes it.**
It is a run-time value only in the sense that the runtime reads it; the compiler
decided it.

The compiler also already runs a **patch-bytes-on-the-way-out pass** — two
operand bytes in embedded mode, three via `BootPatchTable` in shared mode. The
machinery for "fix up known byte positions before writing" exists and is used.

### 14.2 Consequence: `{VAR}` costs nothing at run time

Combine 14.1 with §10 (the blob's own absolute address is compile-time known):

| form | resolved | run-time cost |
| --- | --- | --- |
| `{A}` scalar | compile time — absolute address = `varOffset + (newWorkspacePage << 8)` | **0 bytes, 0 cycles** |
| `{A$}` string | compile time, as the **slot** address; the blob dereferences it itself | **0 bytes**; the deref is the programmer's instructions, which they were writing anyway |
| `{A()}` array | compile time, as the **slot** address; same | **0 bytes** |

The mechanism costs only compiler-side work, which is now free: keep a list of
"object-buffer positions holding a variable operand" in the compiler's banked
workspace, and walk it once before streaming, adding `newWorkspacePage` to each
high byte. **No fixup table ships in the object. No resolver ships in the
runtime.** §13.3's 200-byte resolver and §13.8's resolve-on-every-entry
requirement both disappear.

§13.8's correctness trap is also dissolved rather than solved: because `{A$}`
resolves to the **slot**, not the block, a reassignment between two blocks is
picked up automatically — the blob rereads the slot every time it runs. The
stale-pointer hazard only existed for a design that cached the block address.

The `ifloat32` question (§Q2.13) is unaffected and still open — it is about
*meaning*, not addressing.

### 14.3 The runtime handler, sized against a measured twin

The handler no longer resolves anything. It computes the blob's address, calls
it, and advances past it. `CommandPushS` (`runtime/source/support/pushstring.asm`)
does the same two jobs for inline string data and is the model:

```asm
        clc                         ; blob address = codePtr + Y
        tya
        adc     codePtr
        ...
        tya                         ; advance Y past length + payload
        sec
        adc     (codePtr),y
        tay
```

The VM wrapper is trivial — `.entercmd` is **`plx`** (1 byte), `.exitcmd` is
**`jmp NextCommand`** (3 bytes) (`runtime/source/main/runtime.inc`).

Instruction-counted for a handler that computes the address, saves Y and X,
`jsr`s through `jmp (zTemp0)`, restores, and advances Y:

| part | bytes |
| --- | --- |
| address computation (`codePtr + Y`, +1 past the length byte) | ~18 |
| advance Y past the payload | 5 |
| save/restore Y and X around the call | 4 |
| `jsr` + `jmp (zTemp0)` | 6 |
| `.entercmd` + `.exitcmd` | 4 |
| **total** | **~37** |

Sanity check against measured neighbours: `CommandGPCall` is **77 bytes** and does
strictly more (marshals four values off the float stack, sets carry with `LSR`,
stores four results back). `CommandPushS` does roughly half of this in ~30. So
**~40 bytes, and certainly under 80**, is the right order.

Register in/out is *not needed*: the blob reads and writes variables directly, so
the `SYS_Reg_*` marshalling that dominates `CommandGPCall` has no purpose here.
If it were wanted anyway, add ~40 bytes and reuse `GP.A`/`GP.X`/`GP.Y`/`GP.C`,
which already exist and cost nothing further.

### 14.4 MEASURED: there are 80 free bytes in the GP block right now

Parsed out of `source/application/build/code.lst` (2026-08-30):

```
GP block reserved : $3700 (GPBase) .. $3F00 (ObjectBase) = 2,048 bytes
last GP byte emitted ends at      : $3EB0
SLACK before ObjectBase           : 80 bytes
```

Both labels are `.align 256`, so the block is padded to a page boundary and **80
bytes of that padding are unused today**.

A ~40-byte handler **fits inside the existing padding**. `GPBase` does not move,
`ObjectBase` does not move, the runtime image does not grow, and the object code
still lands at `$3F00` — which also keeps §10's compile-time address computation
valid, since the handler living in the GP block is what makes `ScanGPUsage` set
`gpUsed` for any program containing assembly.

**So the runtime cost is plausibly zero bytes.** That is a real measurement of
real slack, but it is slack, and honesty requires the caveats in §14.6.

### 14.5 Table growth

A new opcode also touches three generated tables. **`GP.ASM` cannot be a shifted
opcode**: `MOFSizeTable` gives `$db .shift` a size of **1**, so the walker treats a
shifted token as two bytes with no operands — a shifted opcode cannot carry a
payload at all. It must be an **unshifted system token** with the variable-length
marker, like `.string` and `.data`.

| table | growth | where |
| --- | --- | --- |
| `MOFSizeTable` | **+1** byte (value 255 = variable length) | below `GPBase` |
| `VectorTable` | **+2** bytes (it is sized to the highest used token, currently `$dbd0`) | below `GPBase` |
| free slots | `$ec`..`$fe` unused (`$ff` is the end marker) — ~19 available | no pressure |

Those 3 bytes sit below `GPBase`, which is `.align 256`, so they are absorbed by
alignment padding unless they happen to cross a page boundary. **Expected cost: 0.**

### 14.6 What could still make it cost something

Stated plainly, because "zero" needs its conditions attached:

- **The 78 bytes of slack (§18.1) are a measurement of today, not a reservation.** Any
  other GP work that lands first consumes them. If the handler ends up over 80
  bytes — because register marshalling is added, or the address computation is
  less tidy than estimated — `GPBase`/`ObjectBase` move a page and the cost
  becomes **+256 bytes** to every GP program, and **0** to non-GP programs (the
  Tier 7 cut).
- **Link order is not guaranteed.** The slack exists at the top of the block; a
  new file in `gp-runtime/` is placed by directory order (`GP-BASIC.PLAN.md`),
  so it lands wherever its name sorts. It still fits, but the arithmetic is
  "does the block total stay under 2,048", not "is there room at the end".
- **`RT_ABI` bump.** Adding a file to `gp-runtime/` renumbers every opcode after
  it — the PLAN records `RT_ABI` going 3 to 4 for exactly this. That costs no
  bytes, but forces **every shared-mode program to be recompiled**.

### 14.7 Per-use cost, in the object

Each `GP.ASM` block costs, in p-code:

```
1 byte  opcode
1 byte  length
N bytes the assembled machine code
```

**N + 2, and nothing else** — no fixup table, since §14.2 resolves everything at
compile time. Capped at **127 bytes of machine code per block** (§18.2) by the
single-length-byte form (§11).

### 14.8 Against what it replaces, it is a large net saving

Today machine code is poked in a byte at a time
(`GPC-BASIC/MLCALL.EXP.BL`):

```basic
POKE ML.INCS+0, 26        ## INC A
POKE ML.INCS+1, 232       ## INX
```

Each line compiles to: push the address (a 16-bit constant — `.word`, 3 bytes),
push the value (short constant, 1-2 bytes), the `POKE` token (1 byte), plus the
`PCD_NEWCMD_LINE` each source line carries. That is roughly **6-8 bytes of
p-code per byte of machine code**, and more where the address is written as an
expression like `ML.INCS+0`. (`README.md`'s ~14 bytes per BASIC line average is
the upper anchor.)

| | p-code for 100 bytes of machine code |
| --- | --- |
| today, `POKE` per byte | **~600-1,400 bytes** |
| `GP.ASM` | **102 bytes** |

So a single 100-byte routine saves roughly **500-1,300 bytes of object**, against
a runtime cost of ~40 bytes that currently fits in existing padding.

### 14.9 Answer

| | bytes at run time |
| --- | --- |
| runtime handler | **~40** — fits in the **78 bytes of slack in the GP block** (§18.1), so **0 net** |
| generated tables | **+3**, absorbed by `.align 256` — **0** |
| `{VAR}` support, all three types, read and write | **0** — resolved at compile time (§14.2) |
| per `GP.ASM` block | **N + 2**, N = the machine code itself |
| *saving* vs the current `POKE` idiom | **~5-13 bytes of object per byte of machine code** |
| **net runtime cost of the feature** | **~0 bytes**, with the caveats in §14.6 |

The entire cost of this feature is compiler-side — the assembler, ~2 KB (§13.2) —
and that is now explicitly not a concern. **On a runtime-bytes basis the feature
is free, and pays for itself many times over the first time anyone uses it
instead of `POKE`.**

## 15. Impact review — GP.IF landed 2026-08-30 (commit `8e9c1af`)

> Reviewed against the ASM research the same day. **§14's headline survives but
> its reasoning needs one correction and gains one decision worth 2,048 bytes.**
> Everything below was re-measured after the commit, not carried over.

`GP.IF <expr> THEN` / `GP.ELSEIF` / `GP.ELSE` / `GP.ENDIF`, each alone on its
line. Also landed since: `GPC.ERR` rewritten in GP.BASIC, and object/map
scratching fixes.

### 15.1 Re-measured layout

| | before | now | matters? |
| --- | --- | --- | --- |
| `GPBase` | `$3700` | **`$3700`** | **held** |
| `ObjectBase` | `$3F00` | **`$3F00`** | **held** — §10 outcome intact |
| `FreeMemory` | `$6000` | `$6200` | compile-time only, out of scope |
| object buffer | 16,128 | 15,616 | compile-time only, out of scope |
| GP block | 2,048 | **2,048** | |
| **GP block slack** | 78 B | **78 B — unchanged** | §14.4 still stands (figure corrected in §18.1) |
| **core cushion** (`$0801..$3700`) | ~40 B | **26 B** (last core byte ends `$36E6`) | **new, and it binds** — see §18.1 |
| `RT_ABI` | 18 | **21** | |
| `GPC.BIN` | 22,498 | 22,832 | compile-time only |

The GP block slack is **untouched** because GP.IF deliberately kept its handler
out of the GP block — which is the finding below.

### 15.2 THE IMPACT THAT MATTERS: handler placement is worth 2,048 bytes

The commit message states it directly:

> *"That NOP is in the CORE, not gp-runtime, and it has to be: ScanGPUsage
> decides whether an object carries the ~2K GP block by comparing each opcode's
> handler address against GPBase. Measured — a GP.IF program compiles RT 12031 /
> GP-BASIC OUT, against RT 14079 / GP-BASIC IN for a GP.SELECT one."*

`14,079 - 12,031 = 2,048`. So **where a handler is linked decides whether the
program drags in the whole GP block.**

§14 assumed the `GP.ASM` handler would live in `gp-runtime/` (it is a `GP.`
keyword, so that was the natural reading, and §10 leaned on it for base
determinism). **That assumption is now expensive.** The two placements:

| placement | handler budget | cost to a program using ASM **and other GP keywords** | cost to a program using **ASM only** |
| --- | --- | --- | --- |
| **`gp-runtime/`** (GP block) | **78 B slack** — comfortable | **0** | **+2,048** (it becomes GP-BASIC IN) |
| **core** (below `GPBase`) | **26 B cushion** — very tight | 0 | **0** |

A core handler that overruns the 26-byte cushion pushes `GPBase` to `$3800` and
costs **+256 bytes to every compiled program**, GP or not.

§14.3 estimated the handler at **~37-40 bytes**. That **fits the GP block's 80
and does not fit the core's 30.** So the honest position is:

- **Core placement is the right target** — it is what keeps an ASM-only program
  from paying 2 KB — but it needs the handler at **≤26 bytes**, or ≤23 once the
  tables below are counted. That is roughly 25% smaller than estimated, and it is
  not obviously achievable.
- **GP block placement is safe and easy** and costs nothing to any program that
  already uses a GP keyword — which, realistically, a program doing inline
  assembly probably does.

**This is a new open question and the most consequential one left.** GP.IF
achieved *zero* handler bytes by reusing existing handlers; `GP.ASM` cannot —
nothing existing performs an indirect jump into the p-code stream.

### 15.3 Correction to §10

§10.2 argued the object's base is forced to `ObjectBase $3F00` because *"a program
containing `GP.ASM` uses a GP keyword by definition"*. **That is only true if the
handler is linked into `gp-runtime/`.** With a core handler (15.2), an ASM-only
program is GP-BASIC OUT and the base is `GPBase $3700`.

Either way the base is one of two known page values, and — critically — **`gpUsed`
is not known while the statement is being compiled**; `ScanGPUsage` runs inside
`WriteObjectCode`, after the whole program is compiled.

**§14.2's design already handles this and is unaffected**: it resolves operands by
patching the object buffer *before streaming*, at `WriteObjectCode` time, where
`gpUsed`, `runtimeEndPage` and `newWorkspacePage` are all known. What the GP.IF
commit does is turn that from a convenience into a **requirement** — the
"compute it while compiling the statement" shortcut §10 implied is not available.

### 15.4 Opcode budget is tighter than §14.5 said

`MOFSizeTable` now runs `$dd .shift` .. `$ef .ifelse` (`PCD_STARTSYSTEM` moved
`$db -> $dd`). Free unshifted system slots are `$f0..$fe` — **15**, not the ~19
in §14.5. GP.IF spent 4. One is still plenty for `GP.ASM`, but the trend is worth
noting.

**Unchanged and still decisive:** `.shift` has size **1**, so a shifted opcode
carries no payload and `GP.ASM` must be an unshifted system token (§14.5).

Also confirmed from the commit: **`MOFSizeTable` is copied into every object**
(*"common.library links before 10object.divider"*), so its +1 byte is a real core
cost, not free. With vector slots that is **+3 bytes off the 26-byte cushion**
before a single byte of handler.

### 15.5 `RT_ABI` is much cheaper than §7/§14.6 implied

`RT_ABI` is **21**, having gone 18 -> 21 in a day. §7 and §14.6 treated an ABI
bump as a notable cost ("forces every shared-mode program to be recompiled").
It is clearly **routine in this project** and should be weighed as a minor,
expected consequence rather than an obstacle.

### 15.6 Tokeniser findings re-verified against the new `tokenise.zip`

`bin/tokenise.zip` changed (5,570 -> 5,576 bytes). Re-ran the §2.3/§2.4 probes:

```
ORA #$01          -> <B0>A #$01        still mangled
AND #$0F          -> <AF> #$0F         still mangled
EOR {A}           -> E<B0> {A}         still mangled
ROR A             -> R<B0> A           still mangled
LDA {A}           -> LDA {A}           clean
GP.ASM "LDA {A}"  -> <CE>{SM "LDA {A}"   quoted text still verbatim
```

**All of §2 holds.** Two notes:

- `GP.ASM` **still collides with `GP.A`** (`<CE>{SM`) until registered.
- **New:** `GP.ENDASM` tokenises as `GP.<80>ASM` — `END` is matched as a keyword.
  So *both* names must be registered in `c64tokens.py` and `GPB.INC.BL`, not just
  the opener.

GP token space: `GP.IF/ELSEIF/ELSE/ENDIF` took 52830-52827, so **the next free id
is 52826**. (`GP.SELECT`'s else was renamed `GP.OTHER`, keeping id 52836, to free
the `GP.ELSE` spelling — ids are the ABI, names are not.)

### 15.7 A block form now has a proven pattern — but it does not fit ASM directly

GP.IF is the first multi-line GP construct with **no runtime frame**: markers in
the p-code, nesting counted by **`FixBranches`**, and `.ifnext`/`.ifelse` reusing
the existing `.goto.z`/`.goto` handlers via extra `;; [...]` markers. §6 and
§Q2.3 were written before this existed and said the compiler had no multi-line
mode; **it now has a proven one.**

**But it does not transfer as-is.** GP.IF's body lines are *ordinary statements*.
An ASM block's body lines are *quoted text*, and a bare `"LDA {A}"` is not a
statement, so the main loop cannot simply compile them.

That leaves two shapes, and the choice matters more than it did:

1. **`GP.ASM "..."` per line.** Needs no new compiler mode. **But each statement
   becomes its own blob with its own VM dispatch** — so a ten-instruction routine
   pays ten dispatches, and **branches between instructions are impossible**
   because each blob is entered and left separately. This is close to unusable
   for anything but a one-liner.
2. **A real block that coalesces into ONE blob.** Either a swallow-until-
   `GP.ENDASM` mode in `MainCompileLoop`, or — more in keeping with how this
   project works — emit one `.asm` opcode per line and **merge adjacent blobs in
   a `FixBranches`-style pass**, which is compile-time-only and therefore free
   under §14's constraint. GP.IF proves such a pass is workable.

**§Q2.3 was "worth deciding"; it is now the difference between a usable feature
and a toy.**

### 15.8 Two traps to inherit from GP.IF

Both are stated in the commit and apply directly to any `GP.ASM` block:

- **A block opener must `stz deferErrors` first.** Otherwise an opener that fails
  with a deferrable SYNTAX error is rolled back into a throw-stub while its
  closer on a later line still compiles — leaving a closer with no opener, and an
  *enclosing* block's nesting scan then resolves to the wrong place, **silently**.
- **Every `.def` helper must return carry CLEAR.** A helper returning carry set
  makes the generator silently drop every table element after it, with no error.

And one **known gap, pre-existing and shared**: a block opener with no closer is
detected, but the compiler still writes the truncated object and reports `OK`
(true of `GP.SELECT`/`GP.ENDSEL` on this build, and now `GP.IF`/`GP.ENDIF`). An
ASM block would land in the same place unless fixed.

### 15.9 Revised answer to "what does it cost at run time"

Replaces §14.9's single figure with the placement fork it now depends on:

| | ASM + other GP keywords | ASM only |
| --- | --- | --- |
| handler in **GP block** (~40 B, fits 78 B slack) | **0** | **+2,048** |
| handler in **core** (needs ≤27 B, est. ~37) | **0** | **0** — *if it fits*; **+256 to every program** if not |
| tables (`+2` vector, `+1` size) | +3 B off the 26 B core cushion | same |
| `{VAR}`, all types, read+write | **0** (§14.2, unaffected) | **0** |
| per block | **N + 2** | **N + 2** |

**§14's conclusion still holds for the likely case** — a program using inline
assembly alongside other GP keywords pays **~0 runtime bytes**. What GP.IF adds
is that the ASM-only case is now a real 2 KB decision, and that squeezing the
handler under 26 bytes is what buys it back. **§18 shows it can be done in 17.**

## 16. Avoiding the 2,048-byte GP block — the composite route

> Investigated 2026-08-30 after §15 established that handler placement is worth
> 2,048 bytes. **Independently verified by reading the source; addresses taken
> from `source/application/build/code.lbl`.**

### 16.1 The insight: SYS already IS the primitive, and it is in the core

`GP.ASM` needs one runtime capability — *call machine code at an address, with
the registers set, and come back safely*. **That already exists and is already
in the core.** `CommandSYS` (`source/runtime/source/commands/sys.asm`):

```asm
CommandSYS: ;; [!sys]
        .entercmd
        phx                         ; save X (float stack ptr) and Y (code offset)
        phy
        jsr     FloatIntegerPart
        lda     NSMantissa1,x       ; call address -> zTemp0
        ...
        ldx     SYS_Reg_X           ; registers in from $030C-$030F
        ldy     SYS_Reg_Y
        lda     SYS_Reg_S : pha : lda SYS_Reg_A : plp
        jsr     _CSZTemp0           ;  -> jmp (zTemp0)
        php
        stx     SYS_Reg_X           ; registers out
        ...
        ply : plx : dex             ; restore, drop the argument
        .exitcmd
```

It saves and restores **both** X and Y, marshals registers in and out, and calls
through an indirect. That is the entire runtime side of the feature.

**Handler addresses, measured against `GPBase = $3700`:**

| handler | address | in core? |
| --- | --- | --- |
| `PushWordCommand` (`.word`, `$df`) | **`$08DF`** | yes |
| `CommandXData` (`.data`, `$e2`) | **`$0BBD`** | yes |
| `CommandShift` (`.shift`, `$dd`) | **`$1AA3`** | yes |
| `CommandSYS` (`$ddb0`) | **`$1E1A`** | yes |
| — | `GPBase` **`$3700`** | — |

Every one is far below `GPBase`. **A lowering built only from these opcodes
leaves the program GP-BASIC OUT**, so `ScanGPUsage` cuts the 2,048-byte block.

### 16.2 The lowering

```
.word  <blob's absolute address>     $df lo hi          3 bytes
.shift sys                           $dd $b0            2 bytes
<container> <len> <blob>             opcode + len + N   2 + N bytes
```

Execution: push the address, `SYS` calls the blob, control returns, and the
container opcode skips its own payload so the VM resumes at the next real
instruction. `CommandXData`'s runtime handler is exactly that skip, and nothing
else:

```asm
CommandXData: ;; [.data]
        .entercmd
        tya : sec : adc (codePtr),y : tay      ; Y += length + 1
        .exitcmd
```

The blob's absolute address is a compile-time constant (§10, §14.1), patched by
the compiler before the object is streamed out — which the object writer already
does for other operands.

**Cost: `N + 7` bytes of p-code per block, and nothing else.** No new handler
code, no GP block, and — for the pure composite form — no new opcode and
**no `RT_ABI` bump**.

### 16.3 The trap: `.data` cannot be the container

`READ` scans the object for data blocks by comparing against the opcode number
(`source/runtime/source/commands/read.asm:130`):

```asm
_RLNFindData:
        lda     (objPtr)
        cmp     #$FF                 ; end of program
        beq     _RLNNoData
        cmp     #PCD_CMD_DATA        ; <-- found a DATA block
        beq     _RLNHaveData
        jsr     MoveObjectForward
        bra     _RLNFindData
```

So a blob parked in a `.data` opcode **would be found by `READ` and handed back
as DATA items** — machine code read as program data, silently. Any program using
both `READ` and `GP.ASM` would be wrong.

### 16.4 The fix, and it costs 3 bytes

Give the container its **own opcode number**, and point its `VectorTable` entry
at the **existing** `CommandXData` handler — precisely the aliasing trick GP.IF
used for `.ifnext`/`.ifelse` (`source/runtime/source/commands/goto.asm`).

- `READ` compares against `PCD_CMD_DATA` specifically, so a different number is
  invisible to it.
- The walker behaviour is identical: a `255` entry in `MOFSizeTable`.
- The runtime behaviour is identical: skip the payload.
- **Zero new handler code** — the vector points at `$0BBD`, which is in the core.

Cost: **+2 bytes** `VectorTable`, **+1 byte** `MOFSizeTable` = **3 bytes**,
against the 30-byte core cushion (§15.1). It does mean a new opcode, hence an
`RT_ABI` bump — cheap, and routine in this project (§15.5).

### 16.5 Where this leaves the cost

| | ASM-only program | program already using other GP keywords |
| --- | --- | --- |
| §15's GP-block handler | +2,048 | 0 |
| §15's core handler (~40 B vs 26 B cushion) | 0 **or** +256 to every program | same |
| **this route** | **3 bytes of core, once** | **3 bytes of core, once** |

Plus `N + 7` per block instead of `N + 2` — five bytes more per use, which is
noise against the 2,048 it avoids, and still an order of magnitude better than
the `POKE`-per-byte idiom it replaces (§14.8).

**Open points, not yet settled:**

- **Registers.** The blob inherits SYS's `$030C-$030F` convention, so reading
  results back with `GP.A`/`GP.X`/`GP.Y`/`GP.C` would drag the block in after all
  — those handlers are in `gp-runtime/`. `PEEK($030C)` is core and works. In
  practice the blob should write results straight into BASIC variables via
  `{A}`, which is the point of the feature.
- Capped at **127 bytes per block**, not 255 — see §18.2.
- The per-line vs block question (§15.7) is unchanged and still the thing that
  decides whether the feature is usable.

## 17. REM as the container — MEASURED, and it beats quoting

> Proposed 2026-08-30. **Tested by running BASLOAD headless via
> `source/gpc/build_basl.py` on purpose-written probes**, not reasoned about.
> This supersedes §6 and §15.7's assumption that quoting is the only safe form.

### 17.1 BASLOAD has an explicit switch for this

`testing/MSEDIT/BASLOAD.MD` documents **`#REM 0` / `#REM 1`**:

> *"This option lets you select whether REM statements are included in the
> resulting code or not. `#REM 0` turns off the output and `#REM 1` turns it on
> again. It is possible to change the option value multiple times in the source
> code. The option takes effect from the line where it is encountered and remains
> in force until changed. **The default value is 0 (off).**"*

Confirmed in the tree: every `.BASL` here sets `#REM 0` explicitly
(`samples/shared-vars/PRG1.BASL:3`, `testing/GPC.BASL:4`,
`testing/GPC.ERR.BASL:5`), and `samples/shared-vars/PRG1.PRG` contains **no `$8F`
byte at all** — the REMs really are stripped.

**Crucially, the option can be toggled per region**, so only an ASM block's REMs
need be emitted.

### 17.2 MEASURED: BASLOAD stores REM text completely verbatim

Probe: a `.BASL` with `#REM 1` and REM lines holding the exact mnemonics that the
host tokeniser destroys (§2.3). Tokenised through real BASLOAD in the emulator,
then the `.PRG` decoded:

```
    1  <REM> ASM
    2  <REM> LDA {A}
    3  <REM> LDX #$23
    4  <REM> ORA #$01          <- intact  (host tokeniser: <B0>A)
    5  <REM> EOR #$FF          <- intact  (host tokeniser: E<B0>)
    6  <REM> AND #$0F          <- intact  (host tokeniser: <AF>)   AND IS A KEYWORD
    7  <REM> ROR A             <- intact  (host tokeniser: R<B0>)
    8  <REM> JMP ONTOP         <- intact  (host tokeniser: <91><A4>P)
    9  <REM> ASM-END
   10  <PRINT>"Q1{A}Q2"
```

**Everything survives**: no keyword tokenising (even `AND`), no identifier
crunching (contrast `PRG1.PRG`, where BASLOAD crunched `NM$`/`GN$`/`CT` down to
`A$`/`A0$`/`A1`), and **braces are preserved**.

So the user's original spelling works, unquoted:

```basic
GP.ASM
REM lda {A}
REM ldx #$23
REM ldy #$9F
REM sec
REM jsr {MACPTR}
REM stx {XR}
GP.ENDASM
```

### 17.3 MEASURED: REM is immune to `#CONTROLCODES` — quoted strings are NOT

`#CONTROLCODES 1` makes BASLOAD interpret `{NAME}` inside strings as PETSCII
control codes (`BASLOAD.MD`: *"The named control codes are only available within
a string"*). That collides head-on with `{VAR}`.

Second probe, with `#CONTROLCODES 1`:

```
    1  <REM> LDA {A}        <- intact
    2  <REM> STA {B}        <- intact
                            <- PRINT "S{A}S" and END are ABSENT
```

BASLOAD **aborted at the string**, and everything from that line on is missing
from the output.

- **REM text is immune** — control codes are string-only. Confirmed.
- **The quoted form `GP.ASM "LDA {A}"` breaks outright** in any program that
  turns control codes on — which is entirely plausible for a program doing screen
  work, exactly the sort of program that wants inline assembly.

This is a strong, measured argument for REM over quoting, independent of taste.

### 17.4 REM costs nothing in the object today

`CommandREM` (`source/compiler/source/commands/rem.asm`) consumes to end of line
and **emits no p-code at all**. So REMs are free in the compiled program; turning
`#REM 1` on inflates only the intermediate tokenised `.PRG`, which is
compile-time and out of scope.

### 17.5 The one serious hazard: silent disappearance

**`#REM 0` is the default.** If a user writes an ASM block and REM output is off,
the assembly is stripped before GPC ever sees it — and there is *nothing left in
the object to detect*. The program would compile clean and simply not contain the
code. That is the worst class of failure this project has.

**The fix is cheap: make the delimiters real tokens, not REMs.**

```basic
GP.ASM            <- a real $CE7x token; BASLOAD always emits it
REM lda {A}       <- the body, stripped if #REM 0
GP.ENDASM         <- a real token
```

With REM output off, GPC sees `GP.ASM` immediately followed by `GP.ENDASM` — an
empty block — and can raise a named error ("ASM BLOCK EMPTY — is `#REM 1` set?").
The failure becomes loud and self-explaining instead of silent.

It also removes the `GP.ENDASM` tokenisation wart from §15.6 in the nicest way:
the body needs no `GP.` prefix at all.

### 17.6 The catch: this is BASLOAD-only

The **host** tokeniser (`bin/tokenise.zip`) does *not* protect REM text —
measured in §2.4: `REM ORA #$01` came out `<8F> <B0>A #$01`. It keeps tokenising
past the `REM`.

So a REM-bodied ASM block works under BASLOAD and breaks under the host path.
Two ways out, and the second looks right:

1. Declare the feature BASLOAD-only (all of `GPC-BASIC/` already is).
2. **Fix the host tokeniser.** It is ours, it is Python
   (`source/tools/tokenise/`), and copying REM text verbatim is what the ROM
   does anyway — so this is arguably fixing a latent bug rather than adding a
   feature. Compile-time work, therefore free.

### 17.7 Revised recommendation

| form | survives BASLOAD | survives `#CONTROLCODES 1` | quoting | one blob |
| --- | --- | --- | --- | --- |
| `GP.ASM "LDA {A}"` per line | yes | **no — aborts** | yes | no, one blob each |
| `GP.ASM "..","..",".."` | yes | **no — aborts** | yes | yes, but line-length capped |
| **`GP.ASM` / `REM ...` / `GP.ENDASM`** | **yes** | **yes** | **none** | **yes, naturally** |
| separate `.ASM` file (§ earlier) | n/a — never tokenised | n/a | none | yes |

**The REM form wins on every axis that was in tension**, and it is the closest to
the syntax originally asked for. The block is naturally delimited, so the body
coalesces into a single blob without the merge pass §15.7 wanted — labels and
branches inside a block just work.

Remaining open: whether to also support the separate-`.ASM`-file form for larger
routines (they are complementary), and the 255-byte-per-block cap (§11) is
unchanged.

## 18. Adversarial review of the escape routes — results

> Six candidate ways to add `GP.ASM` without dragging in the 2,048-byte GP block,
> each investigated against the source and then attacked by two independent
> verifiers (one on the walkers and the block test, one on runtime correctness
> and shared/embedded modes). 16 agents, 0 errors, 2026-08-30.
> **Two options survived both attacks. Three of this document's own numbers were
> wrong and are corrected below.**

### 18.1 CORRECTION: the cushion is 26 bytes and the slack is 78

Found independently by two agents, and confirmed by re-reading `code.lst`:

```
CORE : last byte is the rts at $36E5, ending $36E6; .align 256 pad starts there
       $3700 - $36E6 = 26 bytes   (this document said 30)
GP   : last byte is the rts at $3EB1, ending $3EB2
       $3F00 - $3EB2 = 78 bytes   (this document said 80)
```

**Cause of the error:** the measuring script required each listed hex byte to be
followed by a space, but 64tass separates a *single*-byte instruction's opcode
from its mnemonic with a **tab**. So every one-byte instruction — including the
two closing `rts` — was invisible to it.

Note the GP.IF commit message already said **"26 B of core cushion where there
were 40"**. The correct figure was on record and this document contradicted it
without noticing. All affected figures in §14-§16 have been corrected in place.

### 18.2 CORRECTION: the per-block cap is 127 bytes, not 255 — and it is a live bug

The variable-length skip is an **8-bit** add. Both `.data` and `.string` do:

```asm
        tya : sec : adc (codePtr),y : tay        ; Y = Y + len + 1
```

(`runtime/source/commands/data.asm:23-26`, `support/pushstring.asm:38-41`.)

And Y is **already 0..127** at handler entry: `NXCommand` does `iny / bpl /
jsr FixUpY`, and `FixUpY` folds Y into `codePtr` and resets it to 0 whenever it
goes negative (`runtime/source/main/00runtime.asm:210-239`).

So `Y + len + 1 <= 255` requires **len <= 127**. At `len = 128` with `Y = 127`
the add wraps to `$00` and the interpreter resumes at `codePtr + 0` — **backwards
into already-executed p-code**, with no diagnostic.

**This is a pre-existing latent hazard, not something `GP.ASM` introduces**: any
existing `DATA` payload or string literal of 128+ bytes can trip it, but only
when it happens to land at a high enough `Y`, which makes it position-dependent
and rare. Derived from the code; **not empirically confirmed on hardware**, and
worth confirming before acting on it. It is independent of this feature and
should be raised on its own.

### 18.3 Results

| option | survived | ABI bump | runtime cost | verdict |
| --- | --- | --- | --- | --- |
| **composite via `SYS` + post-`$FF` pool** | **2/2** | **no** | **0** | works, reshaped |
| **new `.asm` opcode, handler in core** | **2/2** | yes | **0** | works, *built and run* |
| alias to existing core handler | 0/2 | yes | +3 | no indirect-call primitive exists |
| reclaim core space | 1/2 | yes | 0 | works, but shared-mode defect found |
| second cut point | 0/2 | yes | +256 ×2 | fails the brief; not worth it for one keyword |
| no new opcode at all | not viable | — | — | `READ` collision, no `DROP` opcode |

### 18.4 Winner A — composite via `SYS`, with the blob in a pool past `$FF`

This is §16 corrected. My `.data` carrier was right to be rejected (the `READ`
collision I found), **and `.string` fails too, for a reason I had not seen**:
`CommandPushS` never writes `NSExponent` (`pushstring.asm:22-40`), so the slot
carries a stale exponent that `SYS`'s `FloatIntegerPart` branches on
(`ifloat32/.../integer.asm:22-24`). It also pushes the address of the *length
byte*, one short of the blob, and leaks a number-stack slot because **the core
has no `DROP` opcode**.

**The fix is better than either carrier: put the blobs in a pool appended after
the `$FF` end marker.** Nothing walks there — `MoveObjectForward` returns CS on
`$FF`, and `FixBranches`, `ScanGPUsage` and `ReadLookNext` all stop at it. So the
pool needs no length byte, no framing, and no carrier opcode — **and therefore no
127-byte cap.**

Emitted per statement, 5 bytes:

```
$DF lo hi        .word  <- absolute run address of the blob      3 bytes
$DD $B0          .shift + sys                                    2 bytes
```

Every handler is below `GPBase`: `PushWordCommand $08DF`, `CommandShift $1AA3`,
`CommandSYS $1E1A`. `PushWordCommand` falls through to `ClearRestWord`, which
zeroes `NSExponent` — so unlike `.string`, the address arrives clean.

**Cost: 0 runtime bytes, no `RT_ABI` bump**, 5 + N per block.

The real price is not bytes: `.word <absolute>` would be the **first
position-dependent operand ever put in this p-code** (branches are offsets,
`.string` is `codePtr`-relative, `.varspace` is workspace-relative), and the same
image runs at three bases — `$6200` in memory, `$3700`/`$3F00` embedded, `$0900`
shared. `WriteObjectCode` would need a write-time high-byte patch in both
`_WOCCode` and `_WOCSCode`. All compiler-side, so free under §D's constraint.

### 18.5 Winner B — a new `.asm` opcode with its handler in the core

**Both verifiers applied the patch to a clean tree and built it; one ran the
result in `x16emu` with hand-built p-code.** That makes this the best-evidenced
option in the document.

The handler is **17 bytes**, not the ~40 estimated in §14.3, because it does not
write `.entercmd` and instead **falls through into `CommandXData`**:

```asm
CommandXAsm: ;; [.asm]
        sec : tya : adc codePtr : sta zTemp0      ; zTemp0 = codePtr + Y + 1
        lda codePtr+1 : adc #0 : sta zTemp0+1     ;   = first blob byte
        phy                                       ; the blob owns Y
        jsr CallZTemp0                            ; sys.asm's existing jmp (zTemp0)
        ply
        ;                                    17 bytes -- falls through, deliberately
CommandXData: ...                                 ; its plx restores X; its tail advances Y
```

- `NXCommand` has already pushed the number-stack X before dispatching, so
  letting `CommandXData`'s existing `plx` serve both entries makes **X protection
  structurally free** — no "user must preserve X" contract.
- `jmp (zTemp0)` already exists at `$1E4D` in `sys.asm`; it only needs promoting
  from a `_`-local label to a global. **Zero bytes.**
- 17 handler + 2 `VectorTable` + 1 `MOFSizeTable` = **20 core bytes**, inside the
  26-byte pad. `GPBase` and `ObjectBase` do not move, the runtime slice stays
  exactly `$0801..$3700` (12,031) or `$0801..$3F00` (14,079), and an ASM-only
  program stays **GP-BASIC OUT**.

**Cost: 0 runtime bytes. Per block: N + 2** — cheaper than A's N + 5.

Its honest costs, all flagged by the agents:

- **It spends nearly the whole remaining core budget**: 6 bytes left (2 if you
  take the 21-byte variant that lifts the cap from 127 to 254). The next core
  addition of any size pushes `GPBase` to `$3800`: **+256 to every program, twice
  over.**
- **`RT_ABI` 21 → 22**, forcing shared-mode recompiles.
- **The fall-through is load-bearing and silent** — inserting a line between
  `CommandXAsm` and `CommandXData` breaks X restoration with no build error.
- The compiler's `dataBuffer` has **no overflow check** (`buffer.asm:33-35`): a
  256-byte blob wraps `bufferSize` to 0 and emits an empty payload, so
  `CommandAsmCompile` must enforce its own cap.
- **Zero-page contract**: the blob runs with the interpreter live — `codePtr $28`,
  `zTemp0 $2C`, `NSStatus $32`, `NSMantissa0..3 $3E/$4A/$56/$62` must not be
  touched.

### 18.6 Why the other four fell

- **Alias to an existing core handler (0/2).** A full search of the core found
  **no indirect-call primitive to alias to** — `GP.CALL` is at `$3762`, *above*
  `GPBase`, so it is disqualified by address. The alias half is sound; the
  `.word` half is what fails.
- **Reclaim core space (1/2).** The mechanism survives — a verifier built it and
  the core ended at `$36B4` — but the second verifier found a **silent
  shared-mode failure** in the specific claims. Viable as a *supplement* to B if
  more core margin is wanted, not as a route on its own.
- **Second cut point (0/2).** Both verifiers refuted it on the same ground: it
  **does not meet the brief.** It moves `runtimeEndPage` `$3700 -> $3800`, giving
  an ASM-only program a third "GP LOW" state at 12,287 bytes — **+256 twice
  over**, not GP-BASIC OUT. Mechanically cheap, but disproportionate for one keyword.
- **No new opcode at all (not viable).** Clears the 2,048-byte question easily,
  then dies on the `READ`/`.data` collision with no way to carry the blob.

### 18.7 Where this leaves it

**Both winners cost zero runtime bytes.** The choice is a trade, not a ranking:

| | A: `SYS` composite | B: `.asm` core opcode |
| --- | --- | --- |
| runtime bytes | 0 | 0 |
| per block | N + 5 | **N + 2** |
| `RT_ABI` bump | **no** | yes (21 → 22) |
| per-block cap | **none** (pool needs no length byte) | 127 (254 at +4 bytes) |
| core budget spent | **none** | 20 of 26 bytes |
| new machinery | first position-dependent p-code operand | a load-bearing silent fall-through |
| evidence | source-verified, 2/2 | **built and run**, 2/2 |

**A leaves the core untouched and needs no ABI bump; B is cheaper per block and
is the one that has actually been built.** A's pool also removes the payload cap
entirely, which matters more now that the cap is known to be 127 rather than 255.

Neither solves absolute addresses *inside* the blob, or `{VAR}` — both still need
the compile-time patch pass of §14.2 / §15.3, which remains free.

## 19. Loading `.asm` text files — one form adopted, one dropped

> Asked 2026-08-30, after §17 settled REM as the container.
>
> **Naming warning:** §18 already uses "A" and "B" for the two *lowerings*
> (SYS composite / `.asm` core opcode). The two forms below are **file** forms
> and are unrelated to those. Either file form works with either lowering.

### 19.1 ADOPTED — `#INCLUDE` a REM-bodied `.asm` file. Works today, no compiler change.

**Measured.** A `.BASL` with `#REM 1` and `#INCLUDE "MACPTR.ASM"`, run through
real BASLOAD headless (`source/gpc/build_basl.py`), then the `.PRG` decoded:

```
    1  <PRINT>"BEFORE"
    2  <REM> GP.ASM-OPEN
    3  <REM> LDA {A}
    4  <REM> LDX #$23
    5  <REM> ORA #$01          <- intact
    6  <REM> AND #$0F          <- intact  (AND is a keyword)
    7  <REM> JSR {MACPTR}
    8  <REM> GP.ASM-CLOSE
    9  <PRINT>"AFTER"
   10  <END>
```

`#INCLUDE` splices the file **verbatim, in place**, so everything §17.2 measured
about REM text holds inside an included file too: mnemonics that collide with
keywords survive, braces survive, nothing is crunched. The probe files were
deleted afterwards.

**Cost: nothing.** No compiler change, no opcode, no `RT_ABI` bump, and — because
`CommandREM` emits no p-code at all (§17.4) — **0 runtime bytes** beyond the
block itself.

**What you give up:** each line still needs a `REM ` prefix, so the file is not
*pure* assembly. It is a BASLOAD fragment that happens to contain assembly.

Two things it inherits from BASLOAD for free, both of which §19.2 would have had
to rebuild:

- **Line attribution** — BASLOAD tracks included files and emits `REM #nn-mm`, so
  an error inside the include names the include, not the `#INCLUDE` line.
- **Nesting**, to the X16's ten-open-files limit (`testing/MSEDIT/BASLOAD.MD`).

### 19.2 DROPPED — `GP.ASMFILE "MYCODE.ASM"`

A compiler-side directive that would read a plain, un-prefixed `.asm` file at
compile time. **Dropped by decision, 2026-08-30 — not on cost.** Nothing was
ever implemented; there is no `ASMFILE` anywhere in the tree (the
`getRuntimeASMFiles()` hits in `source/common-scripts/build.py` are the build
system and unrelated).

Recorded so it is not researched a second time. It was feasible, and cheaper
than first assumed:

- **There is no channel conflict.** The compiler hardcodes logical file 3 for
  both directions (`file-io/read.asm:25`, `:58`, and `SETLFS 3,8,3` at `:111`),
  but the two never overlap: `_CAResetOut` (`compiler/api.asm:66`) only points
  `objPtr` at `FreeMemory`, so the object is **buffered in memory** during the
  compile, and `IOOpenWrite` is called solely from `object.asm` (`:115`, `:254`,
  `:375`) — inside `WriteObjectCode`, after the source is closed. A second
  concurrent input on LFN 4 was therefore free.
- **0 runtime bytes**, like every other compile-time part of this feature.
- The real price was **line attribution**: an error inside the `.asm` would have
  named the `GP.ASMFILE` line unless the compiler grew its own within-file
  numbering — exactly what §19.1 gets from BASLOAD for nothing.

**§19.1 is the supported multi-file form.**
