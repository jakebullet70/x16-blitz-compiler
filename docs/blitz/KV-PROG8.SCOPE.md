# A Prog8 KV store — scope

Written for the agent that will build `kvstore.p8`. It assumes you know Prog8 and the Commander
X16 but nothing about this repository.

## 0. What you are building, and why

`KV` is a key/value store that lives in one 8 KB RAM bank. A BASL implementation already exists and
is in use. The job is a Prog8 implementation that reads and writes **the same bytes in the same
bank**, so that a Blitz-compiled program and a Prog8 program can hand state to each other.

The motivating case: `GPC.GUI` (Blitz, `samples/GPC-GUI-HELPER/`) wants to launch an external
program and get information back. Nothing returns on the X16 — a `LOAD` from a running program
replaces low RAM and hands the machine to the ROM — but **banked RAM survives that transition**, so
a shared bank is the mailbox. See `docs/memory/load-chain-clears-memory.md`: a chained program
clears its variables and string heap on entry, and nothing clears banks.

## 1. What already exists

| file | what it is |
|---|---|
| `GPC-BASIC/KV.INC.BL` | the reference implementation, 247 lines of BASL. **This is the specification.** |
| `samples/GPB-MODS-TESTING/GPC-BASIC/KV.INC.BL` | the working copy that gets edited first |
| `samples/GPB-MODS-TESTING/GPC-BASIC/KV.EXP.BL` | the exercise/test program, 350 lines |
| `docs/blitz/KV-STORE.PLAN.md` | the design record. Section 5 is an earlier, shorter sketch of this job; section 1.2 explains the bank choice |

Read `GPC-BASIC/KV.INC.BL` in full before writing anything. It is short, and its header comment is
the interface contract.

## 2. The contract — the bank layout, byte for byte

One bank, `$A000`–`$BFFF`, 8,192 bytes, divided into 64 slots of 128 bytes.

**Slot 0 is the header:**

| offset | bytes | content |
|---|---|---|
| +0 | 8 | the magic `*KVSTORE` |
| +8 | 1 | `2` |
| +9 | 1 | the format version, currently `1` |
| +10 | 1 | the slot count, currently `64` |
| +11.. | | unused, not zeroed by the formatter |

**Slots 1 to 63 each hold one entry:**

| offset | bytes | content |
|---|---|---|
| +0 | 8 | the key, padded on the right with spaces (`$20`). **A `$00` at +0 means the slot is free.** |
| +8 | 1 | the value length, 0 to 119 |
| +9 | up to 119 | the value |

Slot *n* starts at `$A000 + n * 128`.

Rules the BASL side enforces, which yours must match:

- A key is truncated to 8 characters and padded to 8 with spaces. The documented character set is
  `A-Z`, `0-9` and `.`, but nothing validates it.
- Reading a key back stops at the first space, so a key may not contain one.
- An empty key is refused by `KV.PUT`.
- A value is truncated to 119 characters. An empty value is legal and reads back as an empty string.
- `KV.PUT` rewrites in place when the key is found, otherwise it takes the **first free slot**
  scanning upward from 1. With no free slot it fails.
- `KV.DEL` writes `$00` at +0 and nothing else, so a deleted slot keeps its old bytes. Anything that
  reads a slot must test +0 first.
- The scan is linear from slot 1 to 63, comparing byte +0 first and the other seven only on a match.
  There is no hashing and no ordering. Order of insertion is the order of the slots.

## 3. The API to implement

Match these, name for name where Prog8 allows it. The BASL originals communicate through globals;
the Prog8 versions should take parameters and return values, but the **semantics** must not drift.

| BASL | what it does |
|---|---|
| `KV.INIT` | formats the bank when it holds no valid header; leaves a foreign header alone and reports failure |
| `KV.FIND` | the slot a key is in, 0 for missing |
| `KV.GET` | a value by key |
| `KV.AT` | the key and value in a given slot, for enumeration |
| `KV.PUT` | write a value by key |
| `KV.DEL` | free the slot a key is in |
| `KV.WIPE` | re-format: header, and every slot marked free |
| `KV.SAVE` | the whole 8 KB bank to a file |
| `KV.LOAD` | a file into the bank, then a header check |
| `KV.PUTNUM` / `KV.GETNUM` | **stubs on the BASL side**, they report failure and do nothing. Do not implement them in Prog8 either; a number format that both sides agree on has not been designed |

`KV.INIT` is the one with the subtle behaviour. It checks the header and formats **only** when the
magic is absent. A bank holding `*KVSTORE` with a different version or slot count is left untouched
and the call reports failure, so that a newer writer cannot be silently overwritten by an older
reader.

## 4. The bank number — the open question, and a collision

**The BASL side currently uses `#DEFINE KV.BANK 40`, a compile-time constant.** Section 1.2 of the
plan records why 40: it is clear of the KERNAL (bank 0), the runtime and BASLOAD (bank 1), the
compiler working banks (2–15), the sample `#DEFINE`s (2–11), and `BANKMGR`, which hands out the
lowest free bank from 2 upward.

**The new requirement is that both sides rendezvous on the top bank instead**, discovered at run
time, so neither side carries a magic number.

### Finding the top bank

The KERNAL call is `MEMTOP` at `$FF99` with the carry flag set. It returns the **number** of banks
in `.A`: `$40` for a 512 KB machine, `$80` for 1024 KB, `$C0` for 1536 KB, and `$00` for 2048 KB,
where `$00` means 256. The top bank number is the count minus one — 63 on a 512 KB machine, 255 on
a 2 MB one.

Prog8 has this wrapped already:

- `cx16.numbanks()` — `docs/attic/prog8/cx16/syslib.p8:920`. It returns a `uword` and already
  converts the 2 MB `0` into 256, so `cx16.numbanks() - 1` is the top bank.
- `cx16.push_rambank(bank)` / `cx16.pop_rambank()` — `syslib.p8:902` and `:912`. Use these rather
  than writing `$00` directly, so the caller keeps its bank.

### The collision you must raise before writing code

**On a 512 KB machine the top bank is 63, and bank 63 is already spoken for.**
`source/compiler/source/system-specific/x16/x16_storage.inc:82` reads:

```
;			63	the GP.BANKEDSTR pool, growing DOWN from the top bank a 512K machine has.
```

That pool is claimed by `GPC.BIN` **while it compiles**. The whole point of the shared bank is to
carry state across a chain that includes a compile, so this is not a theoretical clash: a program
that puts its state in bank 63 and then chains to the compiler can have it overwritten by any source
that uses `GP.BANKEDSTR`.

A 2 MB machine has no such problem — the top bank is 255, and the pool still starts at 63.

Four ways out, none chosen. **Put these to the user before you write the bank-selection code:**

1. **Top bank minus a fixed margin**, for example `numbanks() - 4`. Cheap, and it still needs a
   number nobody else uses.
2. **Keep bank 40.** It is already clear of everything documented, and it costs one constant on each
   side. It gives up the run-time discovery the user asked for.
3. **Move the `GP.BANKEDSTR` pool** so it grows down from a number below the rendezvous bank. This
   is a compiler change, in assembly, and the standing order in
   `docs/memory/ask-before-writing-asm.md` says assembly is agreed first.
4. **Top bank, and accept that a compile clears the store.** Workable if the state is written after
   the compile rather than across it, but it makes the mailbox useless for the case that motivated
   it.

There is a second unknown in the same area. The external program in the motivating case is `XFMGR`,
a Prog8 application (`samples/GPC-GUI-HELPER/XFMGR/`) that ships `ZSMKIT.BIN` and five `.OVL`
overlays. Which banks it claims is not known here and its source is not in this repository. Whatever
bank is chosen has to be checked against it.

### What changes on the BASL side

A run-time bank number is not a `#DEFINE`. Note these for whoever updates `KV.INC.BL`; they are not
your job, but the two implementations have to move together.

- `#DEFINE KV.BANK 40` becomes a variable. In BASL a label and a variable of the same name collide
  (`docs/memory/basload-label-and-variable-collide.md`), and a `#DEFINE` name may not contain
  digits, so the new name needs care.
- The BASIC route to `MEMTOP` is through the `SYS` register block: `$030C` is `.A`, `$030D` is `.X`,
  `$030E` is `.Y`, `$030F` is the flags, and bit 0 of the flags is the carry. So
  `POKE $30F,1 : SYS $FF99 : N = PEEK($30C)`, with `N = 0` meaning 256.
- `BANK`, `BSAVE` and `BLOAD` each take the bank number. Whether the Blitz compiler accepts a
  variable where the constant is today needs checking.

## 5. Text encoding — settle this with a probe

The BASL side stores `ASC()` of each character, and a compiled Blitz program works in PETSCII.
Prog8 strings default to PETSCII as well, and an `iso:` prefix gives ASCII.

For the documented key character set this does not matter: `A`–`Z` is `$41`–`$5A` and `0`–`9` is
`$30`–`$39` in both. **Values are free text and it does matter** — the two encodings disagree on
case, on punctuation above `$5B`, and on everything graphical.

Probe **P1**: compile a Prog8 `"ABC"` and a `iso:"abc"`, dump the bytes, and compare against what
BASL writes for the same text. Record the answer in this file. Then state the chosen encoding in the
module header on both sides, because nothing in the format itself declares it.

## 6. The disk image

`KV.SAVE` is `BSAVE "@:"+name, 8, bank, $A000, $C000` and `KV.LOAD` is
`BLOAD name, 8, bank, $A000`.

**`BSAVE` and `BLOAD` are headerless** (`docs/x16/X16 Reference - 04 - BASIC.md`, lines 410–448), so
the file is exactly 8,192 raw bytes with no load address in front. The end address is exclusive,
which is why `$C000` writes the whole bank. The `@:` prefix is what allows an overwrite.

The Prog8 equivalents are `diskio.save_raw(name, $A000, $2000)` and `diskio.load_raw(name, $A000)`
(`docs/attic/prog8/cx16/diskio.p8:747` and `:805`), with the bank selected first.

Probe **P2**: write an image from Prog8, read it back with `KV.LOAD` in BASL, and the other way
round. This is what proves the two file paths agree.

Two behaviours of the BASL side to copy: `KV.LOAD` opens the file first and reads channel 15 so that
a missing file is a clean failure rather than a crash, and `BLOAD` leaves the bank register where the
load stopped, so the bank is selected again before the header is checked.

## 7. Toolchain and placement

- Compiler: `C:\8bitProgramming\prog8\prog8c-12.0.1-all.jar`. Newer jars sit beside it; 12.0.1 is
  the one this project has been using.
- A local copy of the Prog8 library sources is at `docs/attic/prog8/cx16/` for reading. It is a
  reference copy, not the build path.
- Place the module at `samples/KV-STORE/kvstore.p8` with a test program beside it. Samples in this
  repository build in place — see `docs/memory/samples-build-in-place.md` — and are never staged
  into `drive/`.

## 8. Tests

Mirror the BASL exercise program, `samples/GPB-MODS-TESTING/GPC-BASIC/KV.EXP.BL`, which already
covers: init, put, get, rewrite, a 120-character value clamped to 119, delete then find, 63 puts and
a refused 64th, an empty key refused, an empty value read back, save, wipe, load, get, a second
`KV.INIT` keeping the store, a foreign version refused, a key cut to 8, `KV.AT` on a used slot, a
free slot and an out-of-range slot, and a freed slot being reused.

The tests that matter most for this job are the ones the BASL side cannot run alone:

- **Prog8 writes, BASL reads.** Put several keys from Prog8, then chain to a compiled Blitz program
  that gets them.
- **BASL writes, Prog8 reads.** The reverse.
- **The disk image both ways**, probe P2 above.
- **Survival across a chain.** Write from one program, `LOAD` another, read. This is the behaviour
  the whole feature rests on and it should be proved rather than assumed.

## 9. Ground rules in this repository

- Do not write or modify assembly without agreeing it first
  (`docs/memory/ask-before-writing-asm.md`).
- Do not run builds that were not asked for, and never build `PICKDEMO`.
- One statement to a line, light comments, readable code over crunched code.
- Builds run in the background, with absolute paths.

## 10. Decisions owed before coding starts

1. Which bank — section 4, the four options.
2. Which text encoding — section 5, after probe P1.
3. Whether the Prog8 module keeps the BASL global-variable interface or takes parameters. The
   recommendation is parameters, with the byte format unchanged.
