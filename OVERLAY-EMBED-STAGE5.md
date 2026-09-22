# Stage 5 — lifting the refusal

Status: **done.** `GP.BANKED` compiles EMBEDDED, and a banked embedded program runs and prints
exactly what a shared build of the same source prints. `GP.BANKEDSTR` is still refused, on
purpose, and the reason is now a different one.

The plan called this stage "delete three instructions twice". It was not. Stage 4 had already
found four compiler sites that assume a shared layout; a fifth turned up here, in the object
writer, and it was the one that mattered most.

## What was refused, and what still is

`source/compiler/source/commands/gpbank.asm` — the three instructions at the head of
`CommandGPBankedCompile` are gone, and so is `GPBankNeedsShared` and its message.

`source/compiler/source/commands/gpbstr.asm` — **unchanged in behaviour.** Text in a bank still
stops an embedded compile, because `gp-runtime/source/commands/gpbstr.asm` turns a text slot into
a RAM bank by reading `GPBSTRBANKS` **at its address** — `$09F0`, the top of the shared bootstrap
extension page. An embedded program has no such page: `$09F0` is its own code. Lifting that means
finding the table a home both readers can reach, which is a change to the runtime rather than to
the overlay, and it is not this work. The comment there now says so instead of repeating
`GP.BANKED`'s old reason.

## The run page

`gpBankRunPage` was "buffer page → the shared p-code page", and `GPBankRelocate` added one to it
at each use, for the bootstrap extension page a banked shared program carries. Three sites did
that — `gpbank.asm` twice and `gpbstrflush.asm` once — each with a comment saying the `+1` was
unconditional because only a shared program could bank.

It is now the **whole** buffer-to-run delta, and `CompileCode` sets it:

| build | `gpBankRunPage` | why |
|---|---|---|
| SHARED | `PCODE_PAGE + 1` = `$0A` | the p-code loads at `$0900`, above the extension page |
| EMBEDDED | `ObjectBase >> 8` = `$36` | the p-code runs where the runtime image stops |

The three `inc a` are gone. The layout fact now lives in the one place that knows the layout, and
the region code cannot get it wrong for a mode it cannot see.

### Why the embedded value has to be a constant

`GPBankRelocate` works out every cross-boundary correction at the **end of pass one**, before the
application is asked anything at all — `BLC_ENDPASS1` fires after it. So the answer has to be
settled before the compile starts.

The embedded p-code runs at `runtimeEndPage`, which `PrepareObjectCode` cuts at `GPBase` or at
`ObjectBase` depending on `gpUsed` — and `gpUsed` is not final until pass one ends. That is later
than the question.

So `PrepareObjectCode` now takes the **whole** runtime for any program with a region, `gpUsed` or
not. It costs a program that banks and calls no GP.BASIC keyword `ObjectBase - GPBase` = 1,536
bytes of handlers it will never reach. A program with 8K regions in it is not the program that
grudges them, and the alternative is asking a question that cannot be answered yet. The memory
banner was taught the same rule, so a banked embedded program reports `GP BASIC` rather than
`CORE` — it is carrying the handlers and the RUNTIME line was already saying their size.

## The pad — the bug the plan did not know about

With all of the above in, BANKY, BANKZ and BANKN ran embedded first time. **BNK64 printed
nothing.**

Its five patched bytes were right: p-code `$36`, workspace `$46`, bank code `$3E`, overlay `$48`,
start bank `$40`. The file disagreed with them. The overlay was really at `$4400` and the bank
code at `$3A00` — four pages low, both of them.

`ObjEmitBankCode` padded the low code up to the **next page**, and its comment said that was
enough: "the lowest region is page aligned onto the end of the low code, so this pad is zero
whenever a program has any". That is true of where pass ONE put the lowest region. It is not true
of where pass TWO's low code stops.

- `RTIMG_BANKPOFS` is `newWorkspacePage - FrameStackPages`, and `newWorkspacePage` comes from
  `gpBankStart` — pass one's lowest region, and what the banner prints as `LOW CODE`.
- BNK64's banner says `LOW CODE 2048`. Pass two writes **926** bytes of low code.
- So the file was 1,122 bytes shorter than the layout the runtime had been handed. The program
  loaded, copied p-code into bank 1 believing it was the bank code, and hung.

A shared build survives the same gap: its workspace starts above `gpBankStart` too, so the bytes
were never free in either mode — the shared object simply never has to contain them. `LOW CODE
2048` for 926 bytes of code has presumably always been the shared banner's answer.

The fix is in `ObjEmitBankCode`: pad up to the page the runtime was **told**, computed from the
same two bytes the image was patched with —

    (newWorkspacePage - FrameStackPages - runtimeEndPage) << 8  -  objBufBase

A program with no region pads exactly as it did before: its `newWorkspacePage` was measured from
`objPtr`, so that target *is* the next page. A borrow out of the subtraction means the low code
ran above its own layout, which cannot happen, and stops the compile rather than writing 64K of
filler.

BNK64's object grew 31,616 → 32,640 bytes, which is the hole, and it runs.

## The overlays are no longer byte-identical, and should not be

Stage 3's acceptance was "the last `len(.OVL)` bytes of an embedded object equal the shared
build's `.OVL`". That assertion is now **wrong**, and it was only ever true because the embedded
build was using the shared build's run page.

A branch that crosses into a region is corrected by where the p-code runs: `$0A00` shared, `$3600`
embedded. Every region that is ever entered contains at least one such branch — its exit bridge
back to the low code — so the two overlays differ in every region that does anything. They are not
meant to be the same bytes. They are meant to do the same thing.

## What the suite checks now

`source/unit-tests/banktest3.py` keeps every test it had, all SHARED, which is what says the
shared path did not move. Added at the foot of it:

- **`EMBEDDED`** — BANKY, BANKZ, BANKN at 512K and BNK64 at 2048K, each compiled SHARED and run,
  then compiled EMBEDDED and run again. The embedded build must print the same lines, must leave
  no `.OVL` behind, and its appended overlay — walked from the page `RTIMG_OVLPOFS` names, which
  is the only thing the program itself is told — must hold the same regions and end with the
  terminator on the last byte of the file. `appended()` reads the offsets out of
  `rtimage.gen.asm`, so it cannot drift from the build.
- **`BADEMB`** — two refusals that only exist embedded:
  - `BNKBIG`, generated like BNKOVL: a hundred one-page regions, none of them ever called.
    `EMBEDDED REGIONS LEAVE NO ROOM TO LOAD`.
  - `BNK255`, which has text: `GP.BANKEDSTR NEEDS SHARED`.

The embedded block is last because it recompiles names the tests above it have already used.

    BANKY  embedded  512K YES   (Q1 / Q2 / Q3)
    BANKZ  embedded  512K YES   (Z1 START / Z2 LOW 2 / Z3 IN / Z4 CASE2 / Z5 OUT 5)
    BANKN  embedded  512K YES   (N1 BEFORE / N2 ONE / ... / N7 AFTER)
    BNK64  embedded 2048K YES   (R0 BEFORE / R2 IN 2 / ... / R64 IN 64)
    BNKBIG embedded rejected YES   (EMBEDDED REGIONS LEAVE NO ROOM TO LOAD @ 402)
    BNK255 embedded rejected YES   (GP.BANKEDSTR NEEDS SHARED @ 1)

    ALL PASS

`BANKP`, the suite's own "does the region really execute from the bank" probe and the program
Stage 4 recorded as the blocker, now prints all three lines embedded: `P1 LOW CODEPTR 54` (`$36`),
`P2 BANKED CODEPTR 160` (`$A0`), `P3 BANK 5`.

## Two transients, recorded rather than explained

One run of the suite reported `BNKBIG embedded rejected *** NO *** ()`. The empty message is a
tokenise failure, not a compile: BASLOAD did not produce a `.SRC.PRG`. Three tokenises of the same
file straight afterwards all succeeded, and the runs either side of it were clean. Stage 4 saw one
unexplained transient too. Neither reproduced.

## Files

| file | what changed |
|---|---|
| `source/application/source/compiler/start.asm` | `gpBankRunPage` is mode-aware and set after the mode is read |
| `source/application/source/compiler/object.asm` | the runtime cut for a banked program; the low-code pad; `objPadLen`; `INTERNAL: LOW CODE ABOVE ITS OWN LAYOUT` |
| `source/application/source/compiler/memreport.asm` | `GP BASIC` rather than `CORE` for a banked embedded program |
| `source/compiler/source/commands/gpbank.asm` | refusal and message removed; both `inc a` removed |
| `source/compiler/source/commands/gpbstrflush.asm` | the text bank's `inc a` removed |
| `source/compiler/source/commands/gpbstr.asm` | the refusal stays; its reason is rewritten |
| `source/unit-tests/banktest3.py` | the embedded half |
| `GPC-BASIC/GP-BASIC.md`, `GPC-BASIC/BANKED-OR-NOT.md` | they said `GP.BANKED` needs a shared build |

## Still outstanding

- **`GP.BANKEDSTR` embedded**, which needs `GPBSTRBANKS` somewhere both readers can find it.
- **`GP.ASM` inside a region** resolves its addresses against `AsmPageDelta`, which is the p-code
  base and not `$A000`. That is wrong in *both* modes and predates this work; `BANKP`'s region
  contains one, which is why its overlay is the one that differed from the shared `.OVL` before
  anything else did.
- The samples are all shared. Nothing has been rebuilt embedded to see what it buys.
