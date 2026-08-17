# GP.BASIC — the build plan

Companion to [GP-BASIC.PLAN.md](GP-BASIC.PLAN.md), which holds the dotBASIC background, the token-space
decisions and the BASLOAD spike results. **This document is the build plan**: what we are adding, in
what order, at what cost, and why.

Every number here traces to a measurement or a source file. Where something is an estimate it says so.

---

## 1. Context

GPC compiles X16 BASIC to p-code. GP.BASIC extends it with `GP.*` keywords modelled on **C64 dotBASIC
Plus** — not a port of its command list, but an adoption of its *idea*: a reserved namespace, commands
implemented in machine language behind it, and **include-what-you-use** so a program pays only for
what it calls.

The design was worked out in a session that was lost before anything was written down. This is the
rebuild, recorded so it cannot evaporate again.

### The governing principle

> **ASM owns what a human cannot wait for. BASL owns what a human is already waiting on.
> Anything only BASIC reads does not belong in the runtime at all.**

That one rule produced most of the decisions below. It is why sorting and string search are assembly,
why a menu costs one token instead of dotBASIC's six, and why the colour theme has no runtime
presence whatsoever.

### Why it is worth the bytes

Compiled GPC already runs **3.3× stock BASIC** (geomean, `bench/RESULTS.md`). That is the bar a new
command has to clear. A command that merely saves typing is not worth a token. What is worth it is
work where compiled BASIC is still hopeless and assembly is not — sorting a string array, searching a
string, moving 2 KB of screen. That is the whole list.

---

## 2. Budget

| | |
|---|---|
| Target | ~1.5 KB (1,536 B) for the whole set |
| Planned, still to build | **nothing** — the ASM side is complete |
| Shipped, measured | **2,362 B** across tiers 1-10 |
| **All-in** | **2,362 B — about 830 B over the original target** |
| Why that is accepted | RTBASE moved to `$6400` on 17th August; the runtime ends `$9BDD` with **803 B** still free |
| Fixed cost per keyword | **6 B** (2 vector slot + 4 glue) before any code |
| Free `GP.*` BASIC tokens | 115 of 127 (`$CE01`–`$CE7F`) |
| Free p-code opcodes | **20 unshifted** (41 cycles), 60 shifted (58 cycles, +1 byte per call) |

**The unshifted count is now the tightest of the three.** A shifted opcode is fine for an ordinary
command, but a **system token** (one carrying an inline operand) and anything `FixBranches` scans for
**must** be sub-256 — `MOFSizeTable` covers only `PCD_STARTSYSTEM`..`PCD_ENDSYSTEM`, and the scan is an
8-bit compare. `GP.SELECT` spent six of them. Every future block construct with a forward branch
spends from the same 20.

**Compiler-side code is free against this budget.** The 1.5 KB is the *runtime*, which is copied
verbatim into every object. Anything in the compiler half of `GPC.BLITZ.BIN` — `GP.EXITDO`'s whole
resolver, for instance — never reaches an object at all. When a feature can be moved from runtime to
compile time, it costs nothing here.

**Two token spaces, one of each spent per command.** The **BASIC keyword token** is what BASLOAD
writes into the `.PRG`; the **p-code opcode** is what the VM dispatches on. Traced through `GP.DO 5`:

```
source        GP.DO 5
  ↓ BASLOAD
tokenised     CE 7F 35        CE7F = GP.DO keyword token, 35 = "5" as text
  ↓ GPC compiles
p-code        05 96           05 = push constant 5, 96 = GP.DO opcode
```

The keyword space is roomy. **The unshifted opcode space is the scarce one** — 27 left, and unshifted
is 40% cheaper per call and one byte smaller at every call site, so spend them on the most-called
commands.

**But an opcode carrying an inline operand has no choice at all**: it must be a *system* token, in the
`PCD_STARTSYSTEM`–`PCD_ENDSYSTEM` range, because that is the only range `MoveObjectForward` has an
operand-size entry for. `GP.EXITDO` needs two bytes of branch offset, so the "spend a shifted opcode on
rare commands" rule simply did not apply to it. Expect the same for anything else with an operand.

**BASL is a different currency.** Library code becomes tokenised BASIC in the user's program and
compiles at roughly **14 bytes of p-code per line**. BASL menus (~60–100 lines) cost ~850–1,400 bytes
— but *only* in programs that `#INCLUDE` them, where ASM costs every object until tier 7.

### Size estimates by section

| § | Feature | ASM |
|---|---|---:|
| 1 | Loops — **all shipped**; `GP.UNTIL` **CUT**, measured at only 4-6% | 0 |
| 2 | `GP.CALL` + 4 value words — **SHIPPED** | 108 |
| 3 | Strings — all 8 **SHIPPED**: `GP.INSTR` 115 + `GP.STRPTR` 12 + in-place x5 220 + `GP.COMP` 90; `GP.PAD` moved to BASL | 437 |
| 4 | `GP.SORT` + `GP.ARRPTR` — **SHIPPED** | 447 |
| 5 | Stash / restore — **SHIPPED** (368, then 329 after the `TileSetAddress` re-base) | 329 |
| 6 | Drawing ×3 (`GP.LOCATE` **CUT**) — **SHIPPED** | 440 |
| 7 | Input — **BASL** | 0 |
| 8 | Colour / theme — **BASL** | 0 |
| 9 | `GP.MENU` + `GP.SEL` — **SHIPPED** | 377 |
| 10 | `GP.SELECT` / `GP.CASE` / `GP.ELSE` / `GP.ENDSEL` — **SHIPPED** | 127 |
| | **Built** | **2,362** |

#### Measured overrun, 17th August 2026 — read this before trusting an estimate below

The estimates in this table have run **1.62x over** on average. Actuals:

| item | estimated | actual | |
|---|---:|---:|---:|
| `GP.CALL` + 4 value words | 76 | 108 | x1.42 |
| `GP.INSTR` + `GP.STRPTR` | 127 | 127 | x1.00 |
| in-place strings x5 | 200 | 220 | x1.10 |
| `GP.COMP` | 40 | 90 | x2.25 |
| `GP.SORT` | 156 | 398 | x2.55 |
| `GP.ARRPTR` | 15 | 49 | x3.27 |
| stash / restore | 290 | 368 | x1.27 |
| drawing x3 | 250 | 440 | x1.76 |
| `GP.MENU` + `GP.SEL` | 266 | 377 | x1.42 |
| `GP.SELECT` x4 | 85 | 127 | x1.49 |
| **total** | **1,505** | **2,304** | **x1.53** |

`GP.SELECT` is the first estimate made *with* this table in hand — 56 B raw, scaled by the 1.53
overrun to ~85 — and it came in at 127, x1.49 on the raw figure. The multiplier predicts better than
the raw estimate does; keep using it.

The pattern is not random: the two worst overruns are the two commands that had to VALIDATE
something (array header, element type, null pointers) and RETYPE a result. The estimates costed the
algorithm and forgot the guards. **Cost the guards.**

Applying 1.62x, tiers 5, 6 and 9 come to **~1,400 bytes, not 865**. That is why RTBASE moved to
`$6400` on the same day, before starting tier 5 rather than after hitting the ceiling in tier 6:
headroom went 1,061 -> **2,085**, leaving ~690 bytes of margin once everything planned is built.

**That projection has now been checked against two more tiers and it held.** Tiers 5 and 6 came in at
1.27x and 1.76x, and the multiplier over everything built is **1.56x** — close enough that the same
arithmetic can be trusted for tier 9. After tier 6 the runtime ends **`$99E5`** with **1,306 bytes**
of headroom; `GP.MENU` at 266 x 1.56 is ~415, which leaves ~890 spare. **No further RTBASE move is
needed.** (Tier 6 also gave 39 bytes back by re-basing `gpstash.asm` on `TileSetAddress`, so the net
cost of the tier was ~400, not 440.)

Anchors for the estimates: `GP.DO` 29 B, `GP.LOOP` 57 B, `CommandSYS` 54 B, `CommandPOKE` 24 B,
`CommandXFor` 107 B, GPC's 7 graphics primitives 280 B total (all from `source/application/build/code.lbl`);
VTUI `save_rect`/`rest_rect` ~60–70 B each, `fill_box` ~25 B, `border` ~50 B.

---

## 3. The tiers

| Tier | Content | Where |
|---|---|---|
| 1 | **Foundations** — `#TOKEN`/`#DEFINE` plumbing and naming **done**; handler placement **deferred, see below** | ASM + BASL |
| 2 | `GP.CALL` and the register value words — **DONE** | ASM |
| 3 | **Strings** — find, trim/pad, case, compare, `GP.STRPTR` | ASM |
| 4 | **Sort** for string arrays | ASM |
| 5 | **Screen stash / restore** — **DONE** | ASM |
| 6 | **Boxes, fills, positioned text** — **DONE**; menus, dialogs and the colour theme build on them | ASM, then BASL |
| 7 | **Drop what the program does not use** | compiler |
| 10 | **`GP.SELECT`** — multi-way branch, prog8 `when` style — **DONE** | ASM + compiler |

### Tier 1's deadline was wrong — corrected 16th August 2026

The claim was that handler placement had to be settled **before the third GP command**, because each
one added in the middle of the image makes tier 7's truncation harder. Checked against the makefiles,
and it does not hold. The runtime image is **four libraries concatenated**:

```
00main.header  runtime.library  common.library  ifloat32.library  polynomials.library  10object.divider
```

Sorting a handler to the tail of `runtime.library` still leaves three whole libraries after it, so
**this is a link-order problem, not a filename problem.** Tier 7 needs GP code as its own
`gp.library` placed immediately before `10object.divider` — a new source tree, a new Makefile, four
link lines, and teaching `pcode.py` and `vectors.py` to scan it.

That cost is **fixed build plumbing, not per-handler**: moving three handlers costs what moving eight
costs. So it does not compound, there is no deadline, and it is deferred until tier 7 actually needs
it. The original reasoning is kept below because the *facts* in it are still true.

**The original argument:**

Two facts from the code: the runtime is copied **verbatim** into every object (12,031 bytes today),
and every handler is reachable *only* through its `VectorTable` slot — the emitted p-code addresses
commands **by token, never by handler address**. So the compiler already has the information needed to
ship only referenced handlers. The obstacle is layout, not information.

If GP handlers land in `source/runtime/source/commands/` alphabetically they sit in the **middle** of
the image and become permanently unreclaimable — and each one renumbers every opcode after it and
forces an `RT_ABI` bump (`do.asm` sorting ahead of `for.asm` is exactly what drove `RT_ABI` 3 → 4).

**Put every GP handler in its own group at the image tail**, in dependency order. Then tier 7 can
truncate with `ObjectBase` lowered — no relocator — and a program using no GP commands pays zero.

---

## 4. Prior art we are building on

### VTUIlib — public domain, adopt the inner loops

<https://github.com/JimmyDansbo/VTUIlib> (Jimmy Dansbo), **Unlicense**, 828 lines for ~20 functions.

It settles two things about VERA:

1. **Per-row stepping is nearly free.** VERA maps `ADDR_L` to the byte within a row and `ADDR_M` to
   the row, so the next row is `sty VERA_ADDR_L : inc VERA_ADDR_M` — 10 cycles, not a re-address.
2. **VERA has two independent data ports.** `save_rect` takes a destination flag (`0` = system RAM via
   `(ptr)`+INC16, `$80` = VRAM via `DATA1`), and a VRAM copy is `DATA0`→`DATA1` with **no CPU buffer
   and no banking at all**.

**Take the inner loops, not the library.** VTUI is an ASM helper with an API surface for ASM callers;
we are building BASIC commands.

| Drop | Why |
|---|---|
| `initialize` + jump table | GPC dispatches via its own `VectorTable` |
| `set_bank`/`get_bank`, `set_stride`/`get_stride`, `set_decr`/`get_decr` | Accessors for external ASM; we write `VERA_ADDR_H` directly |
| `screen_set`, `clr_scr` | X16 `SCREEN` and `CLS` already exist |
| `input_str` | Moved to BASL |
| `scr2pet` | Only needed to read text back off screen |

**Keep:** `save_rect`, `rest_rect`, `fill_box`, `border`, `hline`, `vline`, `plot_char`, `gotoxy`,
`pet2scr`.

**VTUI has no menu function** — it supplies the ingredients, not the menu.

### Zero page — no conflict

Measured from `code.lbl`. **GPC occupies `$22–$7B`** (90 bytes):

```
$22 zsTemp   $24 runtimeStackPtr   $26 availableMemory   $28 codePtr   $2A objPtr
$2C zTemp0   $2E zTemp1   $30 zTemp2
$32 NSStatus + $3E/$4A/$56/$62 NSMantissa0-3 + $6E NSExponent   (6 x 12)
$7A srcPtr
```

`ZeroPageMandatory = $22` (`source/common-source/source/common.inc:32`) starts deliberately **above**
the X16 KERNAL's `r0`–`r15` API block at `$02–$21` — which is exactly where VTUI lives (`$02–$1B`).
**No overlap.**

**Decision: use GPC's own scratch anyway — the compiler owns zero page.** VTUI's rectangle routines
need 5 bytes (dest pointer, width, dest flag, height); `zTemp0`/`zTemp1`/`zTemp2` at `$2C–$31` give 6.
A symbol remap, not a rewrite, and it removes the hazard of a KERNAL call clobbering `r0`–`r15`
mid-routine.

### GPC's string representation — why sort and STRPTR are cheap

From `strings/concrete.asm`, `memory/read_string.asm`, `commands/dim.asm:191`:

- A string variable **or array element holds a 2-byte pointer** (`dim.asm`: *"work out size is 2 or 6"*).
- It points to a heap block `[MaxLen][Control][ActLen][Data]`, total `MaxLen+3`.
- `ReadStringCommand` pushes **pointer + 2** — a string on the number stack is already the address of
  `[ActLen][Data]`.

So **`GP.SORT` sorts in place by swapping 2-byte pointers**: no temp string, no data movement, O(1)
per swap whatever the string length — a 200-character string swaps as fast as an empty one. And
**`GP.STRPTR` is nearly free**, because the address is already what the stack carries.

---

## 5. The command list

**20 keywords, 7 reserved variables.** Reserved variables cost no token and no vector slot.

### §1 Loops — 4 tokens

| Command | Form | Notes |
|---|---|---|
| `GP.DO` | `GP.DO [count]` | Counted loop, omitted/0 = forever. **Shipped, 6/6 tests pass** |
| `GP.LOOP` | `GP.LOOP` | End of counted loop. **Shipped** |
| `GP.EXITDO` | `GP.EXITDO` | Leave the innermost `GP.DO` early. **Shipped, 11 bytes** |
| `GP.UNTIL` | `GP.UNTIL <cond>` | Post-tested exit, reuses `GP.DO`'s frame |

`GP.WHILE` deliberately **not** included.

**`GP.EXITDO` — the structured exit, and why it is 11 bytes.** Leaving a loop with `GOTO` hardcodes a
line number that goes stale when the loop is edited, and abandons the frame. `GP.EXITDO` targets *the
end of the loop it is in*, whatever that becomes, and closes the frame on the way out. The handler is
three instructions because both halves already existed:

```asm
CommandXExitDo: ;; [.exitdo]
        .entercmd
        lda     #FRAME_LOOP
        jsr     StackFindFrame      ; innermost loop frame, discarding anything above it
        jsr     StackCloseFrame     ; drop it -- we are leaving for good
        jmp     PerformGOTO         ; and branch past the matching GP.LOOP
```

`StackFindFrame` discarding frames above its target means a `FOR` abandoned inside the loop is cleaned
up for free, and its structure error is the runtime backstop if there is no loop at all. Neither stack
routine touches Y (both use 65C02 zp *indirect*, not indirect-indexed), so the error address stays
meaningful and `PerformGOTO` finds its operand where it expects it.

**It is a SYSTEM token (`.exitdo`, `$DF`), not a `GP.*` command token.** Only system tokens carry an
inline operand — the size entry is what tells `MoveObjectForward` to step over the branch offset. That
overrides the earlier plan to spend a *shifted* opcode: a shifted token cannot carry an operand, so
there was no choice to make. Appended after `.deferror` so no existing opcode renumbers.

**Resolution needs no compile-time state at all.** This compiler has *no back-patching machinery* —
`IF` sidesteps forward branches entirely by targeting "current line + 1" and letting `STRFindLine`
resolve it. So instead of a structure stack, `FixBranches` scans **forward** from each `.exitdo`,
raising a depth on every `GP.DO` and lowering it on every `GP.LOOP`; the `GP.LOOP` found at depth zero
is the matching one, and the target is the instruction after it. `MoveObjectForward` steps by real
instruction size, so an operand byte that happens to equal a loop token is never misread. A structural
match on emitted code cannot be fooled by line numbering or by an inner loop.

A `GP.EXITDO` with no matching `GP.LOOP` is a **compile-time** `STRUCTURE IMBALANCE`. Caveat: because
this runs in a post-pass, the reported line is the last line compiled, not the offending one.

Verified: exit at a condition (`R1= 5`); nested, inner-only exit (`R1= 6`); 2,000 loop entries each
exited via `GP.EXITDO`, bounded, proving the frame really is closed; plain `GP.DO`/`GP.LOOP`
unaffected; and the no-loop case rejected at compile time. Also end-to-end from BASLOAD source through
`GP.INC.BL` → `GPC` → running object.

### §2 Machine code interface — 5 tokens. **SHIPPED, 108 B**

| Command | Form | |
|---|---|---|
| `GP.CALL` | `GP.CALL addr [,a] [,x] [,y] [,c]` | shifted, like `SYS` — 77 B |
| `GP.A` `GP.X` `GP.Y` `GP.C` | value words, no arguments | **unshifted** — 31 B for all four |

```basic
POKE $30C,65 : POKE $30D,0 : SYS ADDR : A=PEEK($30C)      becomes
GP.CALL ADDR,65,0 : A=GP.A
```

It shares `SYS`'s `$030C`–`$030F`, so the two interoperate and `PEEK` still reads what either left.

**The plan said "reserved variables, 0 tokens". That was wrong and cost 4 tokens.** Nothing lets
assembly write a *named BASIC variable* — variable addresses are resolved at compile time and the
runtime has no name lookup. X16's own `ST`, `TI`, `MX`, `MY` are **tokens** in GPC for exactly this
reason, and `GP.A` had to follow. Assume the same for `GP.END`, `GP.SEL`, `GP.N` in later sections:
**there is no such thing as a free reserved variable here.**

Left **unshifted** deliberately: the readers are pulled inside loops, where 41 cycles against 58 and
one byte against two is the entire reason to have them instead of `PEEK`. `GP.CALL` itself is shifted
because a machine-code call dwarfs its own dispatch.

**Every argument is optional and defaults to ZERO**, which needs no sentinel at all — an unspecified
register genuinely *is* 0, so the runtime carries no "omitted" test. And 0 fits the one-byte short
constant, so here **omitting costs less than supplying** — the opposite of `OptionalParameterCompile`,
whose 255 default cannot fit and emits a two-byte `.byte` every time.

**Carry in is set with `LSR`, not `PLP`.** `SYS` pushes a whole status byte and `PLP`s it, which also
writes I and D — clearing the interrupt disable inside a routine that had set it. `LSR` moves bit 0 of
the argument into carry and touches nothing else, and `LDA`/`LDX`/`LDY` do not affect carry, so the
registers load afterwards without disturbing it.

> **Put the machine code in banked RAM (`$A000`–`$BFFF`). NOT `$0400`–`$07FF`.**
> Stock X16 BASIC leaves that page free for the user. A **compiled GPC program does not**:
> `MemoryStorage = $400` (`common.inc`), and `$0400` onwards holds `stringHighMemory`,
> `runtimeHigh`, `loadChainSig`, `storeStartHigh`, `stackFloorHigh`, `variableStartPage`…
> The first version of the `GP.CALL` test POKEd its routine there, **passed all four assertions**,
> and was silently corrupting three runtime variables — it only survived because nothing used them
> afterwards. Adding one string to the program was enough to expose it.

### §3 Strings — 7 tokens

**Constraint that shapes this section:** BASLOAD's `#TOKEN` **rejects `$`-suffixed names**
(`GP.TRIM$` produced an empty 6-byte PRG). So anything *returning* a string must be a **statement that
modifies its variable in place**; numeric returns can be functions.

| Command | Form | Kind | |
|---|---|---|---|
| `GP.INSTR` | `GP.INSTR(hay$, needle$ [,start])` | function → position, 0 if absent | **shipped** |
| `GP.STRPTR` | `GP.STRPTR(a$)` | function → address | **shipped** |
| `GP.COMP` | `GP.COMP(a$, b$)` | function → case-insensitive compare | to do |
| `GP.TRIM` | `GP.TRIM a$` | statement, in place, both ends | **shipped** |
| `GP.LTRIM` | `GP.LTRIM a$` | statement, in place, leading spaces | **shipped** |
| `GP.RTRIM` | `GP.RTRIM a$` | statement, in place, trailing spaces | **shipped** |
| `GP.UPPER` | `GP.UPPER a$` | statement, in place | **shipped** |
| `GP.LOWER` | `GP.LOWER a$` | statement, in place | **shipped** |

**Named `GP.INSTR`, not `GP.FIND`** (17/08/26). Same function, but every BASIC programmer already
knows what INSTR does, and X16 BASIC has no `INSTR` of its own to collide with. The optional third
argument is what turns it from "find the first" into "walk every occurrence".

**`GP.PAD` was built, shipped for a few hours, and REMOVED (17/08/26).** It is the one command in
this section that cannot work in ASM, and the reason generalises: an in-place handler receives the
string's **block address**, never the **variable slot**, so it can shrink or rewrite a string but can
never *grow* one past the capacity it was born with (`StringConcrete`: length+50%, minimum 10). That
capped it at ~10 characters for a short string, so `GP.PAD NAME$,20` — a plain column heading, the
entire point of the command — raised `OUT OF RANGE`. Padding is now **`STRHELP.PADR` / `PADL` / `PADC`
in BASL** (`GPC-BASIC/STRHELP.INC.BL`), where ordinary assignment reallocates and the problem does
not exist. Its token (52852/`$CE74`) went to `GP.LTRIM`.

**The rule that falls out of it, for every future in-place string command: shrink and rewrite are
free, grow is impossible.** `GP.TRIM`/`GP.LTRIM`/`GP.RTRIM`/`GP.UPPER`/`GP.LOWER` are all on the
right side of that line, which is why all five are ~40 bytes each and none of them checks anything.

**Ideas worth taking from prog8's `strings.p8`** (surveyed 17/08/26, 33 `asmsub`s), which is also
where this library's module shape comes from — namespace, parameters declared in the header,
preconditions documented rather than checked, include-what-you-use:

| prog8 | worth it? |
|---|---|
| `rfind` — search from the RIGHT | **yes** — GPC cannot do this at all; ~20 B as a `GP.INSTR` variant. Last `.` in a filename, last space for word-wrap |
| `pattern_match` — glob `*` and `?` | **yes, the standout** — hard in BASIC, ~77 lines of asm there; file filters, search boxes |
| `compare_nocase` | already `GP.COMP` above — prog8 confirms it earns a slot |
| `length`/`left`/`right`/`slice`/`copy`/`append` | no — GPC has `LEN`/`LEFT$`/`MID$`/`+` already |
| `isdigit`/`isletter`/`isspace`… | no — one-line `ASC()` comparisons in BASIC, no bulk data, no inner loop |

Note prog8 has **no pad/ljust/rjust at all** — nothing to copy for padding, which is its own argument
that padding does not belong in ASM.

**`GP.STRPTR` returns pointer+2** — the address of `[ActLen][Data]`. Deliberately **not** X16's shape
(X16's `STRPTR` returns the first character, and GPC rejects it outright because the CBM
`[len,lo,hi]` descriptor does not match). The rule a BASIC programmer learns is one line — *length at
`A`, characters at `A+1`* — and because the block is contiguous nothing is lost:

```
PEEK(A-2) = MaxLen (capacity)      PEEK(A) = current length
PEEK(A-1) = control byte           A+1     = first character
```

Capacity at `A-2` is what lets an ML routine reached by `GP.CALL` fill a BASIC string in place and set
its length — something X16 BASIC has no answer for.

**Caveat:** a string literal is pushed by `CommandPushS` pointing **into the p-code itself**, so an
address from `GP.STRPTR` on a literal is read-only.

**Split stays in BASL** — it composes from `GP.INSTR` + `MID$` and does not earn ASM bytes.

### §4 Sorting — 1 token

| Command | Form |
|---|---|
| `GP.SORT` | `GP.SORT a$() [,dir] [,case]` |

**Shell sort**, in place, 2-byte pointer swaps. No recursion, no stack use, no worst-case blowup;
~n^1.3 on real data.

#### Design settled 17th August 2026 — read this before writing the code

Everything below was verified against the source, not assumed.

**Syntax is `GP.SORT A$()`, with the empty parentheses REQUIRED.** They are not decoration: in
BASIC `A$` and `A$()` are different variables, so without the parens the compiler would find the
scalar and silently sort nothing. `ExtractVariableName` (`variables/getname.asm:66`) already sets
`NSSArray` in the returned type and **consumes the `(`**, so the helper only has to check that bit
and then require the `)`. VB spells it the same way.

**The compile helper pushes the array's BASE address and stops there** — it must NOT emit
`PCD_ARRAY1`, which is what turns a base plus subscripts into an element address. The idiom is
already in `variables/refterm.asm:70`:

```asm
lda     #NSSIFloat+NSSIInt16        ; pretend it is an int16 reference
clc
jsr     GetSetVariable              ; pushes the array's base address
```

**Array block layout** (`commands/dim.asm`, confirmed against `memory/array.asm`):

| offset | |
|---|---|
| +0,+1 | element count — this is `DIM n` **plus one** |
| +2 | type byte; **bit 7 set = this level has sub-arrays** |
| +3.. | the elements, **2 bytes** each for a string (6 for a float) |

The base address arrives as an **offset**, so the handler must add `variableStartPage` to the high
byte exactly as `ArrayConvert1` does.

**Three things the handler must reject or handle, all real:**

1. **Multi-dimensional arrays** — bit 7 of the type byte. Sorting one is meaningless; raise
   `.error_index` rather than scrambling it.
2. **Non-string arrays** — the element size is 6, not 2, so the pointer arithmetic would be wrong
   in a way that corrupts memory silently. The compile helper catches this, but check anyway.
3. **Null elements.** A never-assigned string element is `$0000`, and `ReadStringZTemp0Sub`
   substitutes a static empty string for it (`memory/read_string.asm:47`). The comparator MUST do
   the same — treat a zero pointer as length 0 — or a `DIM A$(20)` with five entries used walks
   off into low memory. **This is the trap in this command.**

**Element count is capped at 255** and anything larger raises `.error_range`. A 16-bit index would
grow every address calculation in the inner loop for a case no BASIC program on this machine has;
the cap is documented, not silent.

**The comparator is NOT `strings/compare.asm` as this document previously said** — that one is a
p-code handler reading its operands off the number stack, and the sort needs a plain subroutine
taking two block pointers. It shares the *shape* of `CompareStrings` and the case-folding of
`GP.COMP`, so `,case` selects between folding and not by pointing at one of two comparators.

### §5 Screen stash / restore — 2 tokens

| Command | Form | Notes |
|---|---|---|
| `GP.STASH` | `GP.STASH <bank\|file$> [,x,y,w,h] [,target]` | `target`: 0 = RAM, `$80` = VRAM |
| `GP.RESTR` | `GP.RESTR <bank\|file$> [,x,y]` | Geometry from the header |

The X16 text screen is in **VRAM**, 2 bytes per cell, default 80x60:

| mode | cells | stash size |
|---|---:|---:|
| 80x60 (default) | 4,800 | **9,600 bytes** |
| 80x25 | 2,000 | 4,000 |
| 40x30 | 1,200 | 2,400 |

**A full 80x60 screen does not fit an 8 KB bank.** Hence the destination flag: **VRAM** has no bank
limit and needs no banking at all (`DATA0`→`DATA1`), while **banked RAM** is the choice when the stash
is going on to a file.

**Geometry is optional parameters, not settings** — measured, `GP.STASH 1,5,5,20,10` is 1 line and
6 bytes; the settings equivalent is 4 `GP.SET` calls, 5 lines and 14 bytes, re-issued whenever the
rectangle changes. The rectangle varies per call, so it is a parameter.

Note the counter-intuitive part: **omitting the optional arguments costs more than supplying them**
(`GP.STASH 1` = 10 bytes vs `GP.STASH 1,5,5,20,10` = 6), because `OptionalParameterCompile` defaults
to 255, which will not fit a short constant.

#### Screen addressing — MEASURED on R49, 17th August 2026

Probed from a running program rather than assumed, because two things here are easy to get wrong.

| | |
|---|---|
| `VERAL1MapBase` (`$9F35`) | 216, and the register holds bits **16:9** — so the map is at `216*512` = **`$1B000`** |
| `VERAL1Config` (`$9F34`) | `$60`. Bits **5:4** = map width = `10` = **128 tiles**; bits 7:6 = height = 64 |
| Row stride | 128 tiles x 2 bytes = **256 bytes**, confirmed: "ABC" on row 0 read back as screen codes 1,2,3 and "DEF" at **+256** read back as 4,5 |
| +160 (80 cols x 2) | garbage — the stride is **not** the visible width |

So **cell (x,y) is at `mapbase + y*256 + x*2`**, and because the stride is exactly 256 the row step is
`inc VRAMMed0` — 6 cycles, no re-address. That is the property the whole tier leans on.

**Two traps, both hit while probing:**

1. **`$1B000` does not fit 16 bits.** `VPEEK`/`VPOKE` take a **bank** and a 16-bit offset, so the map
   is bank **1**, offset `$B000`. Reading `VPEEK(0,110592)` silently returns the wrong memory — it
   gave 186/80/129 for "ABC" instead of 1/2/3, and looked like a stride problem rather than a bank one.
2. **`MB` is an X16 keyword** (mouse button, `x16_unary.def`). `MB=PEEK(...)` is a SYNTAX ERROR, not an
   assignment. The same collision trap the BASL naming rules exist to dodge.

**The 256 stride is conditional on map width 128.** It is the default, but a program that changes
`VERAL1Config` changes the stride (64/128/256/512 tiles = 128/256/512/1024 bytes). The handler must
either read those two bits and shift accordingly, or reject a non-default width -- **not assume it**.

> **Resolved 17th August 2026: neither. Use `TileSetAddress`.**
> `source/runtime/source/system-specific/x16/commands/tiles.asm:73` has done the general thing since
> `TILE` shipped: it derives the shift (6..9) from `VERAL1Config` bits 5:4, accumulates in **24 bits**
> because a 256x256 map of two-byte entries is the whole 128 KB of VRAM, adds the map base from
> `VERAL1MapBase`, and leaves X alone. Both `gpstash.asm` and `gpdraw.asm` call it.
>
> `GP.STASH` shipped first with the hand-rolled version and the map-width **check** — a restriction
> dressed up as a guard. Re-basing it on `TileSetAddress` **removed 39 bytes of code and 2 of storage**
> *and* removed the restriction. Look for the existing primitive before writing the special case.

**Files.** The stash is **byte-identical to the file**, as dotBASIC's `.TBS` screens are:

- `GP.STASH` publishes the end address in **`GP.END`**, so `BSAVE "F",8,bank,$A000,GP.END` works with
  the existing keyword — dotBASIC's proven `.CUTSOB`→`FP` pattern.
- **Direct file forms**: `GP.STASH "PANEL.SCR"` / `GP.RESTR "PANEL.SCR"` accept a string where the
  bank goes. **Implemented in BASL**, not ASM (−120 B).
- **A 4-byte header (w, h)** makes the stash self-describing, so `GP.RESTR` needs only the bank or
  filename — fixing the flaw dotBASIC admits to, that `.CUT`/`.PASTE` *"requires correctly
  re-describing the width and height of each cut"*.

### §6 Screen drawing — 3 tokens *(adapted from VTUIlib)*

#### `GP.LOCATE` is CUT — 17th August 2026

It was in the plan as VTUI's `gotoxy`. It should not have been, for two independent reasons:

1. **Nothing would consume it.** VTUI's `gotoxy` sets an internal cursor that later VTUI calls read.
   Our `GP.PRINTAT` takes its own `x,y`, and there is no `GP.PRINT` — so the cursor `GP.LOCATE` set
   would be written and never read.
2. **Stock `LOCATE` already exists and is implemented** — `CommandLocate`, vector `$d7cc`,
   `x16_command.def:17`. It moves the KERNAL cursor, which is the one `PRINT` uses. Shipping
   `GP.LOCATE` alongside it means two commands with the same name-shape and *different,
   non-interacting cursors*.

**And `GP.PRINT` is not the fix.** A `GP.PRINT` continuing from a GP cursor needs line wrap,
scrolling and persistent cursor state — that is re-implementing `PRINT`, and the scroll alone is
substantial. For what this tier is for (menus, boxes, status lines) the position is always known,
so `GP.PRINTAT` covers it.

#### SHIPPED 17th August 2026 — 440 B, RT_ABI 16

| Command | Form | Notes |
|---|---|---|
| `GP.BOX` | `GP.BOX x,y,w,h [,style] [,col]` | frame only; 6 styles, glyph table in ASM. 144 B |
| `GP.FILL` | `GP.FILL x,y,w,h,char [,col]` | 57 B |
| `GP.PRINTAT` | `GP.PRINTAT x,y,text$ [,col]` | 73 B |

Plus **166 B of shared helpers** the three split: geometry 26, colour 17, addressing 21, put-cell 12,
edge run 14, `pet2scr` 20 + its 8-byte table, and the 48-byte border table. Storage 7 B, vectors 6 B.

**The optional colour defaults to what `COLOR` last set, and that costs one instruction.** The KERNAL
keeps the current text colour at **`$0376`** (`kernal.sym`: `.color`) packed as
`(background << 4) | foreground` — **byte for byte the VERA attribute format**, so an omitted colour is
`LDA $0376` with no repacking. Measured, not assumed: `COLOR 5,2` leaves `$25` there, and it survives
the compiled path (GPC's `CommandColor` emits PETSCII control codes and lets the KERNAL keep the
books, so GPC has **no colour state of its own** — this really is "the colour `PRINT` would use").

The sentinel is **256**, so `OptionalColourCompile`, not `OptionalParameterCompile`: `$FF` is a legal
attribute (light grey on light grey). `TILE` gets this wrong and cannot write attribute `$FF` at all.

**Characters are PETSCII and are converted here.** No PETSCII→screen-code conversion existed anywhere
in GPC before this (repo-wide grep; `CHAR` hands bytes to `GRAPH_put_char`, `PRINT` to `BSOUT` —
neither has a screen-code notion). `GPDrawPet2Scr` is prog8's shape: one add from an 8-entry table
indexed by the top three bits, `$80,$00,$C0,$E0,$40,$C0,$80,$80`, plus a test for `$FF` (π is screen
code `$5E`; the arithmetic gives `$7F`. `CHR$(222)` is the same character and needs no special case).

*Known limit, and it is not a loss:* `pet2scr` cannot reach screen codes **`$A0-$BF`**, the reverse-video
glyphs, because PETSCII expresses reverse with a control code rather than a character. Highlighting a
menu row is a matter of swapping the **attribute**, which the colour argument does directly.

**The border glyphs are VTUI's bytes, verified against the ROM charset rather than taken on trust.**
No VTUI ASM source exists on this box (all copies of `VTUI1.2.BIN` are md5 `81fdd876…`), so the table
was disassembled and then each glyph's 8x8 bitmap rendered out of `rom.bin` to settle the slot order:
**b0=TR, b1=TL, b2=BR, b3=BL, b4=top, b5=bottom, b6=left, b7=right**. Style 4's `$77` is two filled
rows at the *top* of the cell and its `$74` two filled columns at the *left* — no other reading fits.
**How to render a glyph, when you next need to** — the PETSCII set is in `bin/x16emu/rom.bin` at
**offset `$18000`** (bank 6, load address `$C000`), 8 bytes per glyph, glyph `n` at `$18000 + n*8`,
MSB leftmost. It holds only **128 glyphs**: screen codes `$80`–`$FF` are generated at charset-upload
time by **inverting** `$00`–`$7F`, so a naive dump shows `$A0` as blank rather than as a solid block.
Sanity-check any offset by rendering `$00` (`@`) and `$01` (`A`) first.

| style | look | TL | TR | BL | BR |
|---|---|---|---|---|---|
| 0 | solid block | `$A0` | `$A0` | `$A0` | `$A0` |
| 1 | chequered dither | `$66` | `$66` | `$66` | `$66` |
| 2 | single line | `$70` | `$6E` | `$6D` | `$7D` |
| 3 | single line, rounded | `$55` | `$49` | `$4A` | `$4B` |
| 4 | thick line | `$4F` | `$50` | `$4C` | `$7A` |
| 5 | thick, shaded corners | `$69` | `$5F` | `$DF` | `$E9` |

**Nothing clips.** `x`, `y`, `w`, `h` are bytes used as given: off the right edge wraps into the next
row, off the bottom writes past the end of the map. **Zero width or height is caught** — that is the
one a program reaches by accident, from a computed size, and it would otherwise count down through
256 cells. `GP.BOX` also needs `w >= 2` and `h >= 2` to have two corners, and no-ops below that.
Style `>= 6` is `OUT OF RANGE`.

*Verified on R49:* fill glyph/colour/bounds, omitted colour resolving to `$25` after `COLOR 5,2`,
`'A'`→1 / `'B'`→2, `176`→`$70` / `192`→`$40` / `255`→`$5E` / `160`→`$60`, all four sides and all six
styles of a box, and every zero/degenerate case a no-op.

**These are not restating `LOCATE`/`PRINT` — they are the fast path, and the margin is large.**
`source/runtime/source/system-specific/x16/interface/x16_printchar.asm:23` shows GPC's per-character
output path makes **two KERNAL calls for every single character** — `CLRCHN` to select the channel,
then `BSOUT` — on top of three register pushes:

```asm
XPrintCharacterToChannel:
        pha / phx / phy
        cpx  #0
        bne  _XPCNotDefault
        jsr  X16_CLRCHN        ; KERNAL call, every character
_XPCSend:
        jsr  X16_BSOUT         ; KERNAL call, every character
```

`BSOUT` alone carries scroll checks, quote mode and cursor handling. VTUI's `plot_char` is a pair of
stores to `VERA_DATA0`. This is the single biggest speed win in the drawing section.

> **The two worlds stay separate.** Direct VERA writes do not update the KERNAL cursor, and GP drawing
> never calls the KERNAL — so `PRINT` and `GP.PRINTAT` are independent, and a plain `PRINT` after a
> `GP.PRINTAT` resumes where the KERNAL still thinks the cursor is. **This must be documented
> prominently**, because a program mixing the two will surprise someone at least once.

*Moved to BASL:* `GP.CENTER` — arithmetic plus `GP.PRINTAT`, one line.
*Not doing:* `GP.STRING` — X16's `RPT$` covers it.

### §7 Input — BASL, 0 tokens

Positioned, length-limited entry built in BASL from `GET` + `GP.BOX` + `GP.FILL` (−166 B).
`INPUT`/`LINPUT` already exist, and only programs that want a form pay for it.

### §8 Colour / theme — BASL data, 0 tokens, 0 ASM

**No `GP.THEME`, no `GP.SET`, no settings block.** The theme is a BASIC array with named slots:

```
#DEFINE CLR_TXT_BRIGHT 3
COLOR CLRS(CLR_TXT_BRIGHT), CLRS(CLR_BG)
```

Theme colours are read by *BASIC*, for `COLOR` — ASM never touches them — so putting them in the
runtime bought nothing and cost two tokens. As data they are **savable and loadable from disk** like
any other array, and switching light for dark is reloading the array rather than invoking a keyword.

**`#DEFINE` value substitution is confirmed** (`testing/MSEDIT/BASLOAD.MD:313-331`): *"defines a 16 bit
integer constant… replaced by its integer value in the resulting generated code"*, with the worked
example `#DEFINE MYPARAM 1` / `PRINT MYPARAM` → `PRINT 1`. So named slots cost **nothing** — no
variable, no 6-byte scalar, no runtime lookup. This applies to every named constant in the library,
not just colours: menu flags become `GP.MENU x,y,w,n,hk$, MENU_MUSTSELECT+MENU_HOTKEYS`.

**Constraint:** a `#DEFINE` name may not collide with a BASIC reserved word, variable or label — so
constants need a prefix distinct from variables in the library's naming discipline.

### §9 Menus — SHIPPED 17th August 2026, 377 B, RT_ABI 17

`GP.MENU x,y,w,n,hotkeys$ [,flags]` drives a menu BASL has already drawn, and the row chosen comes
back in **`GP.SEL`** (1..n, or 0 for cancelled) — a value word, because nothing in the runtime can
write a BASIC variable by name.

**IT TAKES NO COLOURS, and that is the design.** The highlight is a **swap of the cell's own attribute
nibbles**: an attribute is `(bg << 4) | fg`, so exchanging the halves is inverse video. Whatever the
caller drew, in whatever colours, highlights correctly and un-highlights back to exactly what was
there — and because a nibble swap **is its own inverse**, one routine does both and there is no
"normal colour" to pass, store or get wrong. Only attribute bytes are touched, never the text, so
moving the highlight cannot disturb the drawing.

**Read-modify-write of a cell needs increment ZERO.** VERA steps the address on reads as well as
writes, so with the usual increment of 1 the write-back lands on the next byte. `TileSetAddress`
leaves increment 1, so the field is cleared and the address stepped by hand, two bytes a cell.

Keys: cursor up/down move, RETURN chooses, ESC and STOP cancel, anything else is tried as a hotkey —
matched **without case** through the same `GPFoldUpper` that `GP.COMP` and `GP.SORT` use. A hotkey
**chooses** its row rather than merely moving to it, which is what makes hotkeys worth having.

Flags (added together): `1` MUST SELECT (ESC does not cancel), `2` KEEP MARK (leave the chosen row
highlighted), `4` NO WRAP (stop at the ends).

*Verified on R49*, all eleven cases: two-downs-and-RETURN with the highlight correctly removed
afterwards, hotkey by upper and lower case, ESC, wrap at both ends, no-wrap at both ends, all three
flags, an empty hotkey string, and zero rows returning 0 without waiting for a key.

### §10 `GP.SELECT` — SHIPPED 17th August 2026, 127 B, RT_ABI 18

A multi-way branch on one value, modelled on prog8's `when`. Four keywords:

```basic
GP.SELECT K
GP.CASE 13
    ...
GP.CASE 17, 145
    ...
GP.ELSE
    ...
GP.ENDSEL
```

**It does not replace `ON x GOTO/GOSUB`,** which is a real skip table and stays the right answer for
a dense `1..n` index — prog8's own documentation says the same about its `when`. This is for the
**sparse** selector: key codes out of `GET`, state machines, anything `ON` cannot index.

**Case values are ordinary expressions, not the compile-time constants prog8 restricts itself to.**
That is not generosity, it falls out of the design: the selector is re-fetched for every alternative,
so each test is just an expression compiled the ordinary way. Numeric only — a string selector would
need `s.cmp` instead of `f.cmp`, and the type is not known when each `GP.CASE` is compiled.

**The selector lives in a stack frame (`FRAME_SELECT`, id 4, 7 bytes), not on the number stack, and
that was forced rather than chosen.** `new.line` resets the number stack pointer to `$FF` at every
source line, so a value left there by `GP.SELECT` would be gone by the time the first `GP.CASE` on
the next line looked for it. The frame pays for itself twice over: nesting works with no extra
machinery, `GP.ENDSEL`'s `StackFindFrame` discards anything a case body left open, and `GP.EXITDO`
out of an enclosing `GP.DO` discards the select the same way.

**`GP.CASE` *is* the value fetch, emitted once per alternative** — which is why there is no separate
marker keyword and no stack-duplicate opcode. `GP.CASE 13,17` compiles to

```
gp.case 13 f.cmp =   gp.case 17 f.cmp =   or   .casenext
```

A comma list is an `or` of tests: one byte per extra alternative, against three for a branch each.
`FixBranches` lands a `.casenext` on the **first** `gp.case` of the next alternative, and the extra
ones inside an alternative all sit behind its `.casenext`, so the scan never sees them.

**The two branches reuse the `.goto` handlers outright.** `.casenext` is `.goto.z` and `.caseend` is
`.goto`; only how `FixBranches` resolves them differs, exactly as `.fngosub` differs from `.gosub`.
Two extra `;; [...]` markers on the existing labels, so they cost two vector slots and not one byte
of code. Resolution is `_FBFixExitDo`'s forward scan with the nesting counted on
`gp.select`/`gp.endsel` instead of `GP.DO`/`GP.LOOP`, and **both land ON the target token** — a
`.caseend` must *execute* the `GP.ENDSEL` or the frame is never closed.

**The `.caseend` closing a case body is written at the start of the alternative that FOLLOWS it**,
because that is the first moment the compiler knows the body has ended; there is no back-patching
here. One byte of compiler state (`SelectFirstCase`) suppresses it in front of the first
alternative, and that one byte is enough for any depth of nesting — an inner `GP.SELECT` sets it,
the inner first alternative clears it, and the outer select's next alternative sees it clear again.
`GP.ENDSEL` deliberately writes no `.caseend` of its own: the last body falls straight into it.

| | |
|---|---|
| Runtime | **127 B** measured — 112 B of code (`gp.select` 44, `gp.case` 42, `gp.else` 4, `gp.endsel` 10, frame finder 12; the two branches 0) plus 12 B of vector slots |
| Compiler | ~200 B and free against the budget — none of it is copied into an object |
| Tokens spent | 4 BASIC keywords (`$CE63`–`$CE66`), **6 sub-256 opcodes** — 4 unshifted commands + 2 system |
| Sub-256 opcodes left | **20** (`$EC`–`$FF`) |
| Runtime after | ends `$9BDD`, **803 B** free below `$9F00` |

**20 sub-256 slots is the number to watch.** System tokens *must* live there — `MOFSizeTable` covers
only `PCD_STARTSYSTEM`..`PCD_ENDSYSTEM` — and so must any token `FixBranches` scans for, because that
scan is an 8-bit compare. Every future operand-carrying construct spends from the same 20.

**Not built, deliberately:** prog8's `50 to 60 step 2` ranges (they multiply the compare chain, and
prog8's own docs warn that long lists perform poorly), and a string selector.

*Verified on R49*: first / middle / last alternative, a comma list, `GP.ELSE` taken, **nothing
matching with no `GP.ELSE`** falling clean through, a select nested inside a case body of another,
expression case values, `GP.EXITDO` out of a `GP.DO` with a live select frame inside it, and a
1,000-pass balance run with the **whole loop on one source line** so `new.line` never resets the
number stack — a leak of one slot per pass would have corrupted within about thirty. Both error
paths too: no `GP.ENDSEL` gives `STRUCTURE IMBALANCE`, a string selector gives `TYPE MISMATCH`.

### §9 Menus — the original plan

**Split as dotBASIC effectively did: BASL draws, ASM interacts.**

| Command | Form |
|---|---|
| `GP.MENU` | `GP.MENU x,y,w,n,hk$ [,flags]` |

ASM runs the interaction loop over `n` rows BASL has drawn — key read, hotkey match against `hk$`,
highlight repaint — and returns the choice in **`GP.SEL`**. BASL owns layout and the variants
(`GP.MENU.SHOW`, `GP.MENU.SCROLL`, `GP.MENU.MULTI`) built on `GP.BOX`, `GP.FILL`, `GP.PRINTAT`,
`GP.STASH`.

**Why ASM owns only the loop:** a menu waits on a *human*, so the speed argument that justifies ASM
everywhere else does not apply to layout. dotBASIC needed six ASM menu commands plus five support
commands; we get the common case with one.

**Behaviour is an optional `flags` parameter** carrying dotBASIC's `MV+10` bits: point-to-first-item,
must-select, escape-equals-last, honour hotkey colours, un-highlight after select, stray-to-exit.
Eight behaviours in one argument, and **no global runtime state**.

### Reserved variables — 0 tokens

`GP.A` `GP.X` `GP.Y` `GP.C` (from `GP.CALL`) · `GP.END` (from `GP.STASH`) · `GP.SEL` `GP.N` (menus)

### `GPC-BASIC/GP.INC.BL` — the BASLOAD side, and why it is mandatory

The library lives in **`GPC-BASIC/`** at the repo root — flat, names UPPERCASE, role carried in the
extension: **`XXX.INC.BL`** for a BASL include, **`XXX.EXP.BL`** for an example program. Today that is
`GP.INC.BL` and `LOOPS.EXP.BL`.

**Two tokenisers have to learn every GP keyword, not one.** The host-side `bin/tokenise.zip` learns
them from `c64tokens.py` at build time, so `.bas` files work the moment a keyword is added. **BASLOAD
does not** — it runs on the X16 and knows only the ROM's keywords, so a BASL source using `GP.DO`
is a syntax error until the tokens are declared to it.

`GPC-BASIC/GP.INC.BL` is that declaration, `#INCLUDE`d at the top of any BASL source using GP
keywords. It is **staged flat into `testing/`** to be built, because BASLOAD resolves `#INCLUDE` by
bare filename off the emulator's drive:

```
#IFNDEF GP.DEFS
#DEFINE GP.DEFS 1
#TOKEN GP.DO 52863
#TOKEN GP.LOOP 52862
#TOKEN GP.EXITDO 52861
#ENDIF
```

Values are decimal because `#TOKEN <name> <int16>` takes an int16 (`BASLOAD.MD:359`), and they mirror
`getGP()` in `c64tokens.py` — `$CE7F` downward. **The include guard matters**: the spike confirmed
`#IFNDEF`/`#DEFINE` work across `#INCLUDE` boundaries, so a library that includes it and a program that
also includes it do not collide.

**This file is a second source of truth and it will drift.** Adding a keyword to `c64tokens.py` without
adding it here produces a BASLOAD syntax error, not a missing token — annoying but loud. Generating it
from `c64tokens.py` at build time would remove the hazard entirely, and is worth doing before the list
grows past a handful.

Verified end to end: `LOOPS.EXP.BL` using all three keywords tokenises through BASLOAD to a PRG
carrying `CE 7F` / `CE 7E` / `CE 7D`, which GPC then compiles and runs.

---

## 6. Configuration policy

There is **no settings block and no global runtime state**. Configuration is either a **parameter**
(the compiler can see it) or **BASIC data** (the program owns it).

The rule that decided this, counted from `00runtime.asm:126-193`, `gensupport.asm:22` and
`constant.asm:33`:

| | p-code | cycles |
|---|---:|---:|
| Optional param, omitted or ≥64 | 2 bytes | ~80 |
| Optional param, value 0–63 | 1 byte | ~57 |
| Settings byte (`lda abs`) | 0 bytes | 4 |

**Stable across many calls → settings block; varies per call → parameter.** Nothing in the final
design met the left-hand side: theme colours are read by BASIC not ASM, border glyphs became a style
number, and menu flags became a parameter on a command that runs once. The analysis is kept for future
commands, not as a live decision.

---

## 7. Verification

### Driving a compiled program's keyboard — `-bas` paste is NOT enough

Measured 17th August 2026 while testing `GP.MENU`, after three runs hung and looked like a bug in the
cursor-up path.

**x16emu's `-bas` paste STOPS DEAD at `$91`** (cursor up). Not "drops the key" — *stops*: nothing
after it is ever delivered, so the program waits forever. `$11` (cursor down), `$0D`, `$1B`, `$43` and
`$64` all paste fine, so the tell is the high bit. A test whose keys are all under `$80` will pass and
tell you nothing about the rest.

**The fix is to inject keys through the KERNAL instead**, which is exact, ordered and needs no paste:

```basic
POKE 1,0 : GP.CALL $F09F,145 : POKE 1,4     : REM kbdbuf_put, cursor up
```

`kbdbuf_put` is at `$F09F` inside the **banked** ROM window, and compiled GPC code runs with ROM bank
4 (BASIC) selected — hence the `POKE 1,0` around it. Verified: injecting `65` then `GET` returns "A".
The queue at `$A800`/`$A80A` that `kernal.sym` calls `keyd`/`ndx` is **not** what `GETIN` reads —
poking it directly reads back fine and changes nothing.

- **Compile-and-run each new keyword headlessly. Omit `-echo` on the compile step** — it deadlocks the
  emulator on a full stdout pipe and silently truncates the object to a byte-exact prefix that BRKs
  into the monitor with no error message. Floor-check the object: a real one is ~12 KB, so anything
  near 4 KB is truncation. Working harness: `scratchpad/gpdo/run2.py`.
- Size-check every tier by differencing `code.lbl` label deltas against the estimates in §2.
- **Re-run `source/unit-tests/compiler-runtime` after any `RT_ABI` bump** — adding a runtime command
  file renumbers opcodes.
- Differential-test against stock where a GP command has a stock equivalent (see
  `docs/memory/blitz-x16-differential-testing.md`).

---

## 8. Open

### Abandoned-loop frame leak — `FOR` FIXED, `GP.DO` still open

Escaping a loop with `GOTO`/`IF…THEN` leaves its frame open. **Stock BASIC 2.0 self-heals and GPC did
not** — a pre-existing compatibility divergence, found while sizing `GP.DO` and not a `GP.BASIC`
problem at all.

Stock's `FOR` searches the stack for an existing frame with the **same index variable** and reuses it.
`CommandXFor` opened a frame unconditionally, so a program that runs forever interpreted died
compiled after ~215 passes.

Differential test, `10 C=0 / 20 FOR I=1 TO 5 / 30 C=C+1 / 40 IF C<n THEN 20 / 50 PRINT`:

| | frame | n=500 | n=1,500 | n=20,000 |
|---|---:|---|---|---|
| **Stock** (interpreted) | reused | `R1= 500` ✓ | — | `R1= 20000` ✓ |
| **GPC `FOR`** *before* | 19 B | **`OUT OF MEMORY @ $0011`** | — | — |
| **GPC `FOR`** *after* | reused | `R1= 500` ✓ | — | **`R1= 20000`** ✓ |
| **`GP.DO`** | 6 B | `R1= 500` ✓ | **`OUT OF MEMORY @ $000C`** | — |

The pre-fix crossovers match the arithmetic: a 4 KB frame stack (`FrameStackPages = 16`) holds ~215
19-byte `FOR` frames and ~682 6-byte `LOOP` frames. **`GP.DO` was never immune — it leaked ~3× slower**,
so do not read its n=500 pass as a clean bill.

**The fix** (`ReuseForFrame`, `commands/for.asm`) walks a *copy* of the stack pointer and only commits
on a match, so a search that finds nothing leaves the stack untouched. It **stops at the first frame
that is not a `FOR`**, exactly as the 6502 ROM's `FNDFOR` does — which is what makes an intervening
`GOSUB` shield a subroutine's `FOR I` from its caller's. The `$FF` stack-empty marker is not
`FRAME_FOR`, so it terminates the walk too and needs no test of its own. Y is saved and restored
because `StackOpenFrame`'s `OUT OF MEMORY` reports `codePtr+Y`.

Cost: **72 bytes** for the routine, ~81 with the guard, on every object (the runtime is copied
verbatim). Runtime cost falls on loop *entry*, not iteration, and the guard skips the search entirely
unless a `FOR` frame is already on top.

Verified: five differential programs (the leak at n=500 and n=20,000; `GOSUB` shielding; nesting with
`STEP 2` and `STEP -1`; abandoned inner loop) all match stock exactly, plus all six randomised
`compiler-runtime` suites and the `ifloat32` / `polynomials` / `runtime` suites.

**Still open — `GP.DO`.** It has no index variable, but it has something better: `StackSaveCurrentPosition`
(`stack/location.asm:21`) stores its own 2-byte `codePtr` at frame offset 2/3, and **two `GP.DO`
statements can never share a code address, where two `FOR`s can share an index variable**. So the same
walk applies, keyed on position instead of variable — call `FixUpY` first to normalise `codePtr`, and
the nested case works too (a `GOTO` from an inner loop back to the outer `GP.DO` walks past the inner
frame and discards both). No new token, no reliance on programmer discipline.

**`GP.EXITDO` is shipped, but it is NOT this fix — keep the two apart.** It gives code that *wants* a
clean exit a leak-free way to take one; it cannot help code that does not use it, and the leaking
pattern is precisely the programmer reaching for `GOTO` instead. So the position-match above is still
required. What `GP.EXITDO` did rule out is the tempting cheap version: a command that merely unwinds
the frame would be a footgun, because execution then continues at the next statement — still inside the
body — reaches `GP.LOOP`, and `StackFindFrame` finds the *enclosing* loop's frame and jumps back into
the wrong loop, silently and with no error. It has to branch past the matching `GP.LOOP`, which is why
it resolves in `FixBranches` (see §5 §1).

Mitigating factors for what remains, both real:

- **`StackFindFrame` discards everything above its target** (`stack/frames.asm:78-89`), so `NEXT`,
  `RETURN` and `GP.LOOP` all unwind whatever was abandoned inside them. The leak only accumulates
  when loops are abandoned at the outermost level and nothing ever unwinds.
- **The failure is a clean `OUT OF MEMORY`**, not a BRK into the monitor. The guard works.

### Closed during design

| Question | Resolution |
|---|---|
| Zero-page overlap with VTUI | No conflict — GPC owns `$22–$7B`, VTUI sits below in the KERNAL block. Porting onto `zTemp0/1/2` regardless |
| Optional-argument sentinel | Keep 255. The constraint is *illegality* for that parameter, not size — `OptionalColourCompile` already had to pay 3 bytes to escape a collision |
| `#DEFINE` value substitution | Confirmed working. Named constants are free everywhere in the BASL library |
