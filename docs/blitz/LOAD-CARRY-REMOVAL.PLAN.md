# Removing the LOAD chain's variable carry

Handoff document. The work described here has been agreed in principle and not started.
Runtime build **121** is the build that carries it, so the removal and the build-number
bump go together in one change.

`LOAD` stays exactly as it is as a chaining mechanism. Only the carry goes: after this
change a chained program cold-starts, the way an interpreted one already does on the X16.

## 1. What the carry is

Four pieces, eight lines of code, two files.

| piece | where |
|---|---|
| `LoadChainMagic`, the four bytes `"GPCL"` | `source/runtime/source/main/00runtime.asm:249-250` |
| `loadChainSig`, the four-byte slot in the storage section | `source/runtime/source/main/00runtime.asm:258-259` |
| the arm loop, run by every `LOAD` | `source/runtime/source/system-specific/x16/commands/load.asm:76-81` |
| the test, disarm and skip in `StartRuntime` | `source/runtime/source/main/00runtime.asm:74-90` |

`Command_LOAD` copies the magic into the signature before it hands off. The signature sits
in low RAM below `$0801`, so neither the load nor the ROM's `RUN`-time `CLR` disturbs it.
The loaded program's `StartRuntime` finds it, zeroes it, and branches past `ClearMemory` --
so the new program inherits the old one's variables and string heap.

`grep -rn "loadChainSig\|LoadChainMagic" --include=*.asm source/` finds every line of it.

## 2. Why it is going

Not for the bytes. The whole feature is about 44 bytes of a 10,956-byte runtime, and in
SHARED mode that is one resident copy, so the saving per compiled program is zero.

It goes because three defects go with it.

**The unbounded string-array leak.** `ClearMemory` is the only thing that lowers
`stringHighMemory`, so a chain never brings the string ceiling back down. A block is marked
dead only when its variable is reassigned to something longer, never when the pointer is
simply dropped -- and the loaded program's `DIM` zeroes every element of an array. Each
block the previous program's array held loses its only pointer while keeping a live control
byte: invisible to the scavenger and unreusable. Ten hops with a 50-element array strand
500 blocks. `docs/memory/load-chain-strands-array-strings.md` and the *LOAD chaining leaks
array strings* section of `GPC-BASIC/GP-BASIC.md` both describe it.

**Silent variable-base misalignment.** Variables are offsets from `variableStartPage`, which
`StartRuntime` takes from X on entry -- the same number as `storeStartHigh`, which the
bootstrap computes as `PCODE_PAGE + pages(p-code) + FrameStackPages`
(`source/application/source/compiler/object.asm:295-330`). The base therefore moves with the
program's own size. Two chained programs whose p-code rounds to different page counts carry
garbage across, with no error and nothing to detect it.

**The GP-OUT to GPB workspace overwrite.** `sharedCeilPage` is `RTBASE>>8` for a program
using no GPB keyword and `RTGPBASE>>8` for one that does, 2,560 bytes apart. A program of
the first kind chaining to one of the second pulls the full runtime down to `RTGPBASE`,
writing about 2 KB through the top of the workspace it just inherited.

It also simplifies the startup path. `StartRuntime` becomes straight-line, and
`ResetRuntimeStack` stops needing to be called from two places.

And both OASIS porting plans already refuse the carry on their own account and prescribe
`CLR` on entry instead -- `docs/oasis/FULL-SOURCE.PLAN.md` section 3 and
`docs/oasis/MSGPOST.PLAN.md` section 6. After this change that `CLR` is unnecessary: a
chained program clears on entry by itself.

## 3. What already does not use it

Both real chains in the tree pass their parameters through a disk file and would not notice:

- `source/gpc/GPC.BASL:85-105` (and its identical copy `testing/GPC.BASL`) writes
  `GPC.INPUT`, then `LOAD "GPC.BIN"`. This is the compiler's own front-end to engine handoff.
- `samples/cruncher/CRUNCH.BASL:100-115` writes `CRUNCH.INPUT`, then `LOAD "CRUNCH.BIN"`.
- `OASIS/tmp-test/` chains `T1`..`T9` and `C.T1`..`C.T9` through `CHAIN.DAT`, nine hops
  interpreted and nine compiled.

`samples/shared-vars/` is the only thing in the repository that depends on the carry, and it
exists to demonstrate it.

## 4. The assembly edits

**These are assembly changes and the standing order is to agree them with the user before
writing any.** Put the diff in front of him first.

Line numbers are from the tree as of this document and will move as the edits land.

### 4.1 `source/runtime/source/main/00runtime.asm`

Delete the chain test and its comment, lines 68 to 90, leaving the `ClearMemory` call
unconditional:

    jsr     ClearMemory                 ; clear memory.
    jsr     XRuntimeSetup               ; initialise the runtime stuff.

Delete `jsr ResetRuntimeStack` at line 59 and the comment above it at 53-58. `ClearMemory`
calls `ResetRuntimeStack` itself (`clr.asm:81`) and now always runs, so the second call is
redundant. **Keep the `stackFloorHigh` calculation at lines 49-52** -- `ClearMemory` does not
do that, and `CommandClr` must not disturb it. Reword the comment at 39-47 so it no longer
explains itself in terms of a chain.

Delete `LoadChainMagic` and its banner, lines 241-251 -- but keep the `.send code` at 252.

Delete `loadChainSig` and its comment, lines 258-259.

Add a line to the change log at the foot of the file.

### 4.2 `source/runtime/source/system-specific/x16/commands/load.asm`

Delete the arm loop and its comment, lines 71-81.

Rewrite the header paragraph at lines 40-46. It currently says variables carry across the
chain "like stock's LOAD-in-a-program", which is wrong twice over: it will not be true after
this change, and the comparison with stock is already wrong today. A program-mode `LOAD` on
the X16 (measured on R49) does not preserve variables. The replacement should say that the
loaded program starts clean, and that a chain passes state through a file or a bank.

Add a line to the change log at the foot of the file.

### 4.3 `source/runtime/source/commands/clr.asm`

Rewrite the banner at lines 85-106. Its whole argument is "ClearMemory is skipped on a LOAD
chain, and this went with it". Nothing is skipped now, and `ResetRuntimeStack` has one
caller again. Keep the routine where it is -- the history in the banner about the frame-stack
floor guard and build 114 is worth a sentence, but the chain rationale is not.

### 4.4 The storage layout moves

Removing `loadChainSig` takes four bytes out of the storage section, so every symbol after
it shifts down by four. `docs/oasis/MSGPOST.PLAN.md:70-76` quotes `source/runtime/build/code.lbl`:

    StorageEnd   = $5f7
    loadChainSig = $403
    ldNameLen    = $463

After the build, read `code.lbl` again and correct those numbers there. The OASIS collision
that section describes does not go away -- the storage section still covers `$0400` upward --
but the addresses it names change.

## 5. The build number

`source/application/rtbuild.txt` goes from `120` to `121`. Nothing else is edited by hand:
`scripts/bumpbuild.py` regenerates `source/application/source/generated/version.asm` from it,
and `source/runtime/scripts/rtname.py` formats the same number into the runtime file names.

Three file names change with it:

| 120 | 121 |
|---|---|
| `GPC.RT.120.BIN` | `GPC.RT.121.BIN` |
| `GPB.RT.120.BIN` | `GPB.RT.121.BIN` |
| `GPC.IMG.120.BIN` | `GPC.IMG.121.BIN` |

**Every shared-mode program must be recompiled.** The name is baked into each object by
`source/application/source/compiler/bootstrap.asm`, so a program compiled against 120 looks
for `GPC.RT.120.BIN` and will not find it. That is the whole point of moving the stamp:
nothing keeps running on the old runtime by accident.

The stale `.BIN` files already staged around the tree go with it. `samplesbuild.py:158`
clears older ones where it installs, but the copies under `work/*/`, `OASIS/tmp-test/` and
`samples/GPC-HELP/` want checking by hand.

Prose that names the old number reads stale afterwards. `help-demo.bat:42` and
`testing/readme.md:21-23` are the two that are operational rather than illustrative.

## 6. Prose that names the carry

Every one of these asserts something that stops being true. None of them is optional: a
document that describes a mechanism the runtime no longer has is worse than no document.

| file | what is there |
|---|---|
| `samples/shared-vars/readme.md` | the whole document is about the carry |
| `samples/shared-vars/PRG1.BASL:6-11`, `PRG2.BASL:6-10` | header REMs, and `PRG2` asserts the variables survived |
| `GPC-BASIC/GP-BASIC.md:2488` | the *LOAD chaining leaks array strings* section |
| `docs/memory/load-chain-strands-array-strings.md` | the defect note; becomes history, not a live hazard |
| `docs/blitz/GP-BASIC.ASM.RESEARCH.md:314, 345, 1625-1626` | cites the shared-vars readme for the offset rule |
| `docs/blitz/GP-BASIC.TIERS.md:508` | lists `loadChainSig` among the storage symbols |
| `docs/oasis/FULL-SOURCE.PLAN.md:71-76, 195-205` | the mixed-chain argument and the `CLR`-on-entry section |
| `docs/oasis/MSGPOST.PLAN.md:70-95, 175-200` | the golden RAM collision table and the handoff comparison |
| `source/gpc/GPC.BASL:100-102` and `testing/GPC.BASL:100-102` | a `REM` claiming the chain works exactly as stock BASIC does and that variables survive |
| `testing/GPCTEST.BASL:100-102` | the same `REM` |
| `samples/cruncher/CRUNCH.BASL:110-112` | "chain-loads exactly as stock BASIC does inside a running program" -- true enough about the mechanism, but check the wording still reads right |
| `OASIS/tmp-test/gen.py:7` | cites `samples/shared-vars` as the proven form for a compiled `LOAD` |
| `TODO.md:2968-2990` | the sample entry and the findings block |
| `TODO.md:3062-3066` | *Shared-runtime, THREE programs sharing variables -- TODO*; this item is cancelled by the change |

The two `GPC.BASL` copies are byte-identical. Edit both, or work out which direction they
are copied and fix the master.

The `REM` in `GPC.BASL` is worth keeping in some form: it explains why there is no `,8` on
the `LOAD`, which is a real trap. Only the "and variables survive" half is wrong.

`release/TMP/SRC/GPC.BASL` is a build artefact under a gitignored directory. Leave it.

## 7. The sample

`samples/shared-vars/` has no purpose after this. It is not in `samplesbuild.py`, so nothing
breaks by leaving it, but it demonstrates a mechanism that will not exist.

Two options, and this one is the user's call:

- **Rewrite it as a file handoff.** `PRG1` writes the five values to a sequential file and
  chains; `PRG2` reads them back and checks them. That keeps a chaining sample, and the
  point it makes -- SHARED mode means one 11 KB runtime for two ~0.5 KB programs -- survives
  the rewrite intact. `OASIS/tmp-test/SVARS.BASL` is a worked example of the shape.
- **Delete it**, and let `samples/cruncher/` stand as the chaining example it already is.

Either way `TODO.md:3062` (extend it to three programs) is dead.

## 8. Building and checking

Two halves, and both are needed -- `make libs` alone leaves the installed runtime stale:

    make libs
    make -C source/runtime gpc-rt

**Ask before running either.** Another agent is doing release builds, and the standing
instruction is one build at a time.

What to check afterwards:

- `source/runtime/build/code.lbl` -- `loadChainSig` is gone and `StorageEnd` has fallen by 4.
- The runtime is about 44 bytes smaller than the 10,956 of build 120.
- `samples/cruncher/` still chains: `CRUNCH.BASL` to `CRUNCH.BIN` through `CRUNCH.INPUT`.
  This is the one in-tree chain that a person can run end to end.
- The compiler still chains to its own engine -- `GPC.BASL` to `GPC.BIN` through `GPC.INPUT`.
  This exercises the same path on the tool you are building with, so a regression here shows
  up as the compiler failing to compile anything.
- A `GOSUB` in a chained program still works. The frame-stack reset moves, so this is the one
  behaviour the edit could plausibly break; `clr.asm:96-102` records that getting it wrong
  produced an immediate `OUT OF MEMORY` on the first `GOSUB` once the floor guard landed.

## 9. Things not to do

- Do not build `PICKDEMO`, or tokenise or stage it. Standing order.
- Do not regenerate the help. The `GP-BASIC.md` edit in section 6 changes
  `samples/GPC-HELP/HELP-TXT/H072.HLP`, which is committed and clean, and the user has a
  bulk `.HLP` edit in flight. Make the `GP-BASIC.md` change, say that `MKHELP.PY` is owed,
  and stop.
- Do not commit without asking.
- `GPC-BASIC/BMXVIEW.EXP.BL` and `samples/editor/EDITOR.BASL` each have a `#SAVEAS`/`#SYMFILE`
  pair that is tracked source with an outstanding question against it. Not part of this work;
  do not touch them in passing.
