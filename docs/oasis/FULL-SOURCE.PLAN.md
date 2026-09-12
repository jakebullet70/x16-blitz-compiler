# OASIS_FULL_SOURCE -- staged conversion to GPC

**The complete BBS is ten programs, eighteen shared includes and 10,216 lines, split across
compilation units because BASLOAD inlines every `#INCLUDE` into every unit that names it and
performs no dead-code elimination. GPC performs none either, so the split survives the port
unchanged. The staging is two steps: replace the golden-RAM handoff with SVARS while everything
stays interpreted, then compile one module at a time. The first step is a precondition for the
second, not preparation for it -- a mixed chain needs a handoff both an interpreted and a compiled
program can speak, and a disk file is the only one.**

Companion document: `MSGPOST.PLAN.md`, which covers one unit in full detail. `OASIS/OASIS_MSGPOST`
is a byte-identical flattened copy of the MSGPOST unit from this tree, so everything in that
document applies here without adjustment.

## 1. The application as it stands

Seven programs are in the chain and three are standalone.

```
BBSINIT ──> LOGIN ──> BBSMSG <──> MSGPOST
   ^  ^       │  │
   │  │       │  └──> SYSOP ──> PWMAINT
   │  └───────┘         │
   └── COMPACT <────────┘   (SYSOP also returns to BBSINIT)

never LOADed and never LOAD: BBSSETUP, MKFILL, MKMAIL
```

Nineteen `LOAD` sites carry the chain.

Sizes, with comments stripped. The tokenised column is anchored on MSGPOST's measured
37,353 -> 19,723 and the p-code column on the measured 1.7:1 compression.

| unit | lines | code bytes | tokenised | p-code |
|---|---|---|---|---|
| LOGIN | 1,276 | 57,789 | ~30,500 | ~18,000 |
| BBSMSG | 218 | 42,929 | ~22,700 | ~13,400 |
| MKFILL | 196 | 38,814 | ~20,500 | ~12,100 |
| MSGPOST | 123 | 37,353 | **19,723** | ~11,600 |
| PWMAINT | 656 | 33,788 | ~17,800 | ~10,500 |
| BBSINIT | 840 | 28,001 | ~14,800 | ~8,700 |
| MKMAIL | 229 | 26,376 | ~13,900 | ~8,200 |
| SYSOP | 304 | 24,009 | ~12,700 | ~7,500 |
| BBSSETUP | 502 | 8,286 | ~4,400 | ~2,600 |
| COMPACT | 302 | 7,172 | ~3,800 | ~2,200 |

The program line count is not the unit size. MSGPOST is 123 lines and 37,353 code bytes because
nine includes are inlined into it.

Include graph, which fixes what each unit carries:

| unit | includes |
|---|---|
| BBSINIT | STANDARD.DEF OASIS.DEF OASIS.BI STANDARD.BI |
| BBSMSG | STANDARD.DEF OASIS.DEF MSG.DEF OASIS.BI MSG.BI MSGREAD.BI STANDARD.BI |
| BBSSETUP | *none* |
| COMPACT | COMPACT.DEF ENCODE.BI COMPACT.BI |
| LOGIN | STANDARD.DEF OASIS.DEF OASIS.BI LOGIN.BI EDITINFO.BI STANDARD.BI |
| MKFILL | STANDARD.DEF OASIS.DEF MSG.DEF OASIS.BI INPUT.BI MSG.BI ENCODE.BI MSGWRITE.BI STANDARD.BI |
| MKMAIL | STANDARD.DEF OASIS.DEF MSG.DEF POSTOFFICE.DEF OASIS.BI ENCODE.BI POSTOFFICE.BI STANDARD.BI |
| MSGPOST | STANDARD.DEF OASIS.DEF MSG.DEF OASIS.BI INPUT.BI MSG.BI ENCODE.BI MSGWRITE.BI STANDARD.BI |
| PWMAINT | STANDARD.DEF OASIS.DEF OASIS.BI STANDARD.BI |
| SYSOP | STANDARD.DEF OASIS.DEF OASIS.BI STANDARD.BI |

`INCLUDES/LOGIN.BI:8-40` records the reachability analysis that produced this layout: OASIS.BI was
828 code lines, LOGIN reached 686 of them and no other unit reached more than 157, and BBSMSG was
measured at 897 bytes free while carrying ~13,600 bytes of code it never called.

## 2. Stage one: golden RAM to SVARS, still interpreted

### 2.1 Why this comes first

A staged port means a mixed chain. Nothing survives a `LOAD` in either mode -- GPC clears memory
on entry now, the same as the interpreter. A compiled program cannot use `$0400` either; that
address is inside the runtime's `$0400`-`$05F2` storage section. A disk file is the only mechanism
both speak.

Without this step the choice is to convert all seven chained programs at once.

`OASIS/tmp-test` already proves the mechanism: `T1`..`T9` and `C.T1`..`C.T9`, nine hops interpreted
and compiled, with `CHAIN.DAT` arriving intact.

### 2.2 The slot map

`SVARS.BASL` covers the handoff one slot for one address, with two numeric spares left over.

| golden RAM | carries | SVARS slot |
|---|---|---|
| `$0400` | module command byte | `SV.MODE` |
| `$0401` | calls today | `SV.CALLS` |
| `$0402` | user count | `SV.USERCOUNT` |
| `$0403` | access level | `SV.LEVEL` |
| `$0404` | terminal type | `SV.TERM` |
| `$0405` | sysop flag | `SV.SYSOP` |
| `$0406` | user record number | `SV.RECNO` |
| `$0407` | screen width | `SV.WIDTH` |
| `$0408`-`$0409` | post base number, lo/hi | `SV.MBASE` |
| `$040A`-`$040B` | reply target, lo/hi | `SV.REPLYTO` |
| `$040C` | reply outcome | `SV.REPLYOK` |
| `$0410`-`$041E` | `WS.LAST.CALLER$` | `SV$(SV.LASTCALLER)` |
| `$0421`-`$042F` | `FOUND.USERNAME$` | `SV$(SV.USERNAME)` |
| `$0431`-`$043F` | caller IP | `SV$(SV.CALLERIP)` |

Channel 5, which `SVARS.SAVE` and `SVARS.LOAD` use, is free. The application opens 1, 2, 3 and 15
only.

### 2.3 A POKE writes one byte, a save writes all sixteen

`POKE $0402, n` leaves every other slot alone. `SVARS.SAVE` writes the whole array. So a program
that saves without having loaded first zeroes the slots it does not own.

The discipline is the same in all seven programs:

1. `SVARS.LOAD` on entry, before reading any slot.
2. `SVARS.SAVE` immediately before each of the nineteen `LOAD` statements.

### 2.4 Read-then-clear stops being crash-safe

`X = PEEK($0400) : POKE $0400, 0` clears the mode the instant it is read. A file's clear lands only
when something saves. A program that stops between the two leaves the stale mode on disk, and the
next boot re-enters the mode it just left.

The entry sequence is therefore load, clear the mode, save -- two file writes a hop, not one.

### 2.5 The warm-boot witness byte

`BBSINIT.BAS:426` sets `$0400` to 1 and reloads itself when `FRE(0) < 9000`. `BBSINIT.BAS:198`
reads it on entry and jumps to `BBS.RESTART`, skipping UART and ZiModem init, because the modem is
already up and re-initialising it drops the caller.

The flag works because golden RAM is zero after a power-on and holds its value across a software
reset. A file does not have that property.

> **WARNING.** Moving this flag into SVARS.DAT breaks cold boot. The file still reads 1 after a
> power cycle, so BBSINIT skips UART init and the modem never comes up.

One byte of memory stays behind. `$0700` is the place:

- The runtime's storage section ends at `StorageEnd = $05F3` (`source/runtime/build/code.lbl`)
  and code starts at `$0801`, so `$05F7`-`$0800` is untouched by a running shared-mode program.
- The compiler's own build puts `StorageEnd` at `$0678` (`source/compiler/build/code.lst:7724`), so
  anything above that is clear in both builds.
- No banking, and the code is the same `PEEK` and `POKE` it is today.

Confirm on hardware that interpreted BASIC leaves `$0700` alone across a `DOS` call and a `LOAD`:
`POKE $0700, 42`, do file work, `PRINT PEEK($0700)`.

Everything except this one flag goes into SVARS.

### 2.6 Two 16-bit values the swap frees

SVARS stores numbers as text, so the lo/hi splitting goes away at eight sites: `MSGREAD.BI:365-366`
and `:379-382` on the write side, `BBSMSG.BAS:176`, `:195`, `:201` and `MSGPOST.BAS:61`, `:88` on
the read side.

It also removes a live defect. `BBSINIT.BAS:294` reads the user count as a genuine 16-bit value out
of the file header:

    WS.USER.COUNT = (ASC(MID$(WS.HDR$, UHDR.USERCOUNT.HI, 1))-32)*256
                  + (ASC(MID$(WS.HDR$, UHDR.USERCOUNT.LO, 1))-32)

`BBSINIT.BAS:445` then writes it through `POKE $0402`, one byte.

> **WARNING.** At 256 registered users the BBS raises `?ILLEGAL QUANTITY ERROR` at boot.
> `FOUND.RECORD.NUM` at `$0406` caps user records the same way -- PWMAINT multiplies it by
> `USER.REC.SIZE = 256` to seek, at `PWMAINT.BAS:321`, `:356`, `:381`, `:404`, `:461`. The file
> format handles more than 255 users; the handoff does not.

Both caps disappear as a side effect of the swap.

## 3. Nothing carries across a hop, and no CLR is needed

GPC's `LOAD` clears memory on entry, the same as a fresh `RUN` and the same as the interpreter.
The `"GPCL"` signature at `loadChainSig` and the skipped `ClearMemory` are gone from the runtime.

Two consequences, both of them in this port's favour.

**Every value a program needs has to be in the handoff.** There is no variable carry to fall back
on and no first-appearance-order trap to respect. Section 2 is not an improvement on an
alternative; it is the whole mechanism.

**Nothing strands in the string heap.** `stringHighMemory` comes back down in `ClearMemory`, and
`ClearMemory` runs on every entry, so each program starts on a clean heap. A block is still marked
dead only when its variable is reassigned to something longer, and a `DIM` still zeroes every
element without freeing anything -- but both are now bounded by one program's run, which is
exactly the interpreted behaviour the BBS runs on today. `CLR` on entry is not needed and should
not be written. There is none anywhere in the tree, in any of the twenty-eight files.

What each unit holds in the heap still matters, because it is live for as long as that program
runs and it comes out of a workspace that section 4.1 shrinks:

| unit | string arrays | elements |
|---|---|---|
| MSGPOST | `MSG.LINE$(MSG.LINE.MAX)`, `MSG.LINE.MAX = 200` | **201** |
| MKFILL | same | 201 |
| BBSMSG | `BASE.STATUS$(26)`, `BASE.NAME$(26)` | 54 |
| COMPACT | same two | 54 |
| BBSSETUP | `MC.BNAME$(26)` | 27 |
| BBSINIT | `WS.LOG$(9)` | 10 |
| LOGIN | `WS.LOG$(9)` | 10 |
| SYSOP, PWMAINT, MKMAIL | none | 0 |

A block is `length × 1.5 + 3`, so a full 201-line message at 80 columns is about **24 KB** -- the
whole compiled workspace. Nothing frees an element inside the program either, so a re-edited line
costs a second block. That is section 4.1's problem for MSGPOST and MKFILL, and it is the one
place the compile stage can fail on memory alone.

SVARS adds `DIM SV$(2)` to every program, three blocks.

`FRE(0)`, literally `stringHighMemory − availableMemory`, is the instrument. Print it on entry to
each program and on the way out. `BBSINIT.BAS:415-426` already keeps measured WFC readings in a
comment.

## 4. Stage two: one module at a time

### 4.1 Shared mode does not return memory at these sizes

Interpreted, a program has `$0801`-`$9F00` = **38,655 bytes** for tokenised code, variables and
heap together. Compiled shared it has `$0801`-`$6E00` less the 2,048-byte frame stack = **24,063**
for p-code, variables and heap, with the runtime resident above `$6E00`.

At 0.59 compression, room for variables is `24,063 − 0.59T` compiled against `38,655 − T`
interpreted. Shared wins above

    0.41T > 14,592   ->   T > ~35,600 tokenised

No unit reaches that. LOGIN, the largest, is ~30,500.

| unit | vars+heap interpreted | vars+heap shared |
|---|---|---|
| LOGIN | ~8,200 | ~6,100 |
| BBSMSG | ~15,900 | ~10,700 |
| MSGPOST | ~18,900 | ~12,500 |
| SYSOP | ~26,000 | ~16,600 |
| COMPACT | ~34,900 | ~21,900 |

So the compile stage costs workspace in every unit. It is affordable except where an array already
dominates, which is MSGPOST and MKFILL.

> **WARNING.** LOGIN at ~18,000 p-code is at or over the ~17,920 shared cap
> (`PCODE_PAGE($09) + pages(p-code) + FrameStackPages < sharedCeilPage − MIN_WS_PAGES + 1`). LOGIN
> may not build shared at all.

### 4.2 Where the memory is

Two payoffs, neither of them shared-mode compression.

**Speed.** `msglib.p8` exists because BASIC could not wrap and send fast enough. Compiling brings
those paths back inside BASIC.

**`GP.BANKED`.** P-code in a bank leaves the full ~24,063 of low RAM for variables and heap alone,
against `38,655 − T` interpreted: ~24,000 against ~8,200 for LOGIN, ~24,000 against ~15,900 for
BBSMSG. This is the answer to the memory ceiling that forced the split, and it is what would let
part of the reachability split be undone.

Three constraints land on this application specifically:

- A `BANK` statement disqualifies a routine from a region. There are twelve: `LOGIN.BI:124`,
  `MSG.BI:385`, `MSGREAD.BI:468`, `:707`, `:810`, `OASIS.BI:363`, `:365`, `STANDARD.BI:185`,
  `:194`, `:201`, `:212`, `:214`.
- Banked code loses the bank on a call out and may not `BANK` itself back.
- `SYS MSGLIB.*` into bank 254 works in shared mode -- `CommandBank` writes `SelectRAMBank`, and
  `SYS` is `jsr FloatIntegerPart / jsr _CSZTemp0 / jmp (zTemp0)` with no bank handling -- but from
  inside a region the p-code fetch owns the bank register.

BBSMSG and LOGIN are therefore the hard ones and the msglib-free units are the easy ones.

### 4.3 DOS is the only unsupported keyword

A full keyword sweep of all 10,216 lines, with comments and string literals stripped and only
statement position matched, finds `DOS` and nothing else. `LOCATE` (56 sites) is supported --
`x16_command.def:17` is `LOCATE # X:OptionalParameterCompile T N`.

**112 distinct source sites in 18 files.** Per unit the count is higher because a shared include is
inlined into every unit that names it.

| unit | DOS sites in the unit | dead `.DEF` constants |
|---|---|---|
| PWMAINT | 24 | 133 of 202 |
| BBSSETUP | 22 | -- no includes |
| LOGIN | 22 | 126 of 202 |
| BBSMSG | 20 | 134 of 239 |
| MSGPOST | 19 | 145 of 239 |
| MKFILL | 19 | 152 of 239 |
| MKMAIL | 17 | **177 of 254** |
| SYSOP | 16 | 139 of 202 |
| BBSINIT | 14 | 143 of 202 |
| COMPACT | 9 | 7 of 28 |

The replacement already exists once in the tree, at `STANDARD.BI:146-152`:

    DOS.CMD:
     OPEN 15, DEVICE, 15, COMMAND$
     GOTO GETFCODE
    GETFILECODE:
     OPEN 15,8,15
    GETFCODE:
     INPUT#15, FCode, FC$, A, B : CLOSE 15 : RETURN

Two units cannot reach it. **BBSSETUP has no `#INCLUDE` at all** and **COMPACT does not include
STANDARD.BI**. Both need STANDARD.BI added or a local copy.

The dead-constant column is `.DEF` names defined but never referenced in that unit's
comment-stripped bodies. Twenty names across the `.DEF` files carry a digit, so they cannot become
`#DEFINE`s without renaming -- BASLOAD rejects a digit in a `#DEFINE` name. There are also 172
`MID$` calls application-wide for `GP.INSTR` to replace.

`STANDARD.DEF` is Tony 3068's, MIT-0, and marked not to be modified. It packs many constants per
line with `:`, so a per-line count undercounts it.

### 4.4 #AUTONUM, and an error that names a line that cannot exist

Nine of the ten programs carry `#AUTONUM 10`. COMPACT does not.

`SVARS.BASL` has `GOTO SVARS.MODULE.END` at line 92 jumping over its own body to the label at line
149, inside `#IFNDEF SVARS.DEFS` at 46 and `#ENDIF` at 150. That is the shape `#AUTONUM` with a
step other than 1 mis-resolves.

> **WARNING.** The tokenise succeeds silently. The failure is GPC's: the compile stops with
> `UNKNOWN LINE NUMBER @ nnn` naming a line that does not exist, and it appears in CMP.LOG, not
> TOK.LOG.

Stage one is unaffected, because interpreted tokenisation is clean. Remove `#AUTONUM` from a module
when that module is compiled, not before.

## 5. Order

1. **Stage one across all seven chained programs**, with the witness byte settled first. Verify by
   walking a full session: BBSINIT, LOGIN, BBSMSG, MSGPOST, BBSMSG, LOGIN, SYSOP, PWMAINT and back.
2. **COMPACT** as the toolchain proof. ~3,800 tokenised, 7 dead constants, 9 DOS sites, one `LOAD`
   in and one out, no banked RAM, no msglib, no `#AUTONUM`. It proves a compiled program chains to
   and from interpreted ones and that SVARS crosses the boundary, and it is small enough that
   nothing else can be blamed.
3. **SYSOP** as the first real module. No banked RAM, no arrays, ~12,700 tokenised.
4. **PWMAINT**, then **BBSINIT** -- BBSINIT carries the witness byte and the `FRE(0)` self-reload.
5. **MSGPOST**, where `MSG.LINE$(200)` meets the smaller compiled workspace. See `MSGPOST.PLAN.md`.
6. **BBSMSG**, then **LOGIN**. LOGIN needs `GP.BANKED`.

The three standalone tools can go at any point. They are not in the chain and cannot break it.

## 6. Open items

- Whether interpreted BASIC leaves `$0700` alone across a `DOS` call and a `LOAD`.
- Whether the interpreted chain clears the string heap on a hop. Stage one is all interpreted, so
  this is stage one's question, and `FRE(0)` on entry to each program answers it.
- Whether LOGIN builds shared at all, or goes straight to `GP.BANKED`.
- Whether `MSG.LINE$(200)` fits the compiled workspace, and what replaces it if not.
- Whether the twelve `BANK` statements can be lifted out of the routines that would go into a
  region.
- `BBSINIT.BAS:415-426` asks for the `FRE(0) < 9000` threshold to be made relative to a snapshot
  taken at the first WFC. The compile stage changes every number it rests on.
