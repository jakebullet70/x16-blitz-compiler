# Shared key-value bank

Steps 1, 2 and 8 are done, and step 8 regenerated the help. Step 3's program, `KV.EXP.BL`, is written and has not run. The design decided so far is the TODO entry "A shared key-value
bank" (`TODO.md`, raised 2026-09-15). This plan settles its open items, fixes the interface, and
orders the work.

## 1. Decisions for review

### 1.1 Slot size: 64 slots of 128 bytes

- A value holds 119 characters. Slots 1-63 hold data.
- Slot n starts at `$A000 + n*128`.
- The alternative is 32 slots of 256 bytes: 247 characters, 31 data slots.

### 1.2 Bank number: 40

What each bank below 64 already belongs to:

| bank | owner | source |
|---|---|---|
| 0 | KERNAL; BASLOAD's message at `$BF00` | `BASLOAD-GPC/src/response.inc:106` |
| 1 | runtime, native test harness, BASLOAD (`BASLOAD_RAM1 = 1`) | `BASLOAD-GPC/upstream/common.inc:31` |
| 2-14 | the compiler, while it compiles | `source/compiler/source/system-specific/x16/x16_storage.inc:61-82` |
| 63 down | the compile-time `GP.BANKEDSTR` pool | same |
| 2 up | `BANKMGR.GET.FREE.BANK`, lowest free first | `BANKMGR.INC.BL` |
| 2-11 | bank `#DEFINE`s in the existing samples | `grep "#DEFINE .*BANK"` |

Bank 40 is clear of all of them unless the compile-time pool grows past 23 banks.

### 1.3 Module name: `KV.INC.BL`, prefix `KV.`

The older entry "`KV.INC.BL` — text out of low RAM, an index in it" (`TODO.md`) gives up the name.
It is rewritten as a text import into this store, done later with the `INI.INC.BL` work.

### 1.4 Disk format: a `BSAVE` image only

Text import is out of this plan (see 1.3).

### 1.5 Stub: none

Test T3 times a missing-key lookup, the worst case, in stock BASIC. A stub is raised again only if
that time is too slow.

### 1.6 Calls from a `GP.BANKED` region: `KV.HOMEBANK`

GPC's `BANK` writes the hardware register as well as `ramBank`
(`source/runtime/source/system-specific/x16/interface/x16_peekpoke.asm:63-67`). A region that calls
`KV.GET` with a plain `GOSUB` returns with bank 40 selected, and the next p-code fetch reads bank 40.
`BLOAD` moves the register too (`loadsave.asm:87-88`).

Every public routine therefore ends with `BANK KV.HOMEBANK`. The first `KV.INIT` sets `KV.HOMEBANK` to 1, the
bank the KERNAL selects for a program at startup (`docs/x16/X16 Reference - 08 - Memory Map.md:102`).
A caller in a region sets it to its own bank number after `KV.INIT`. A caller in low memory ignores
it.

`KV.INC.BL` itself cannot be placed inside a region, because the compiler refuses `BANK` there.

The alternative is to document "call from low memory only" and add nothing.

Superseded for regions: a call out of a region is now a banked call, and its `RETURN` selects the
region's bank again (`GP-BASIC.md` §3.12). A region caller needs no `KV.HOMEBANK`. It still serves a
low-memory caller that keeps another bank selected.

## 2. The bank layout

This layout is the contract between the three languages.

```
slot n = $A000 + n*128, n = 0-63
+0..+7    key, padded with spaces ($20); $00 at +0 marks the slot free
+8        value length, 0-119
+9..+127  value
```

Slot 0 is the header:

```
+0..+7    "*KVSTORE"
+8        2
+9        version, 1
+10       slot count, 64
```

- Key characters are `A`-`Z`, `0`-`9` and `.`: `$41`-`$5A`, `$30`-`$39`, `$2E`.
- A key longer than 8 characters is cut to 8.
- Scans cover slots 1-63 only, so no key matches the header.
- The include does not check key characters.

## 3. `KV.INC.BL` — stock BASIC and GPC

Plain BASL. No GP commands, so it tokenises for stock BASIC and compiles under GPC unchanged. No
`Requires GPB.INC.BL`. Guarded by `#IFNDEF KV.DEFS`.

```basic
#DEFINE KV.BANK 40
```

| Routine | in | out |
|---|---|---|
| `KV.INIT` | — | `KV.OK` |
| `KV.FIND` | `KV.KEY$` | `KV.SLOT`, 0 if missing |
| `KV.GET` | `KV.KEY$` | `KV.VALUE$` `KV.SLOT` `KV.OK` |
| `KV.AT` | `KV.SLOT` | `KV.KEY$` `KV.VALUE$` `KV.OK` |
| `KV.PUT` | `KV.KEY$` `KV.VALUE$` | `KV.SLOT` `KV.OK` |
| `KV.PUTNUM` | `KV.KEY$` `KV.NUM` | `KV.SLOT` `KV.OK` |
| `KV.GETNUM` | `KV.KEY$` | `KV.NUM` `KV.OK` |
| `KV.DEL` | `KV.KEY$` | `KV.OK` |
| `KV.WIPE` | — | — |
| `KV.SAVE` | `KV.FNAME$` | — |
| `KV.LOAD` | `KV.FNAME$` | `KV.OK` |

`KV.INIT` runs before any other routine. All routines read `KV.HOMEBANK` (1.6). `KV.OK` is -1 for
success and 0 for failure.

- **`KV.INIT`** writes the header and frees slots 1-63 when slot 0 holds no header. It returns
  `KV.OK = 0` and writes nothing when the header has another version or slot count. The first call
  `DIM`s `KV.CODE%(7)` and sets `KV.HOMEBANK = 1` behind `KV.READY`, the same guard as `BANKMGR.INIT`
  (`BANKMGR.INC.BL:69`), so a second call raises no `REDIM'D ARRAY`.
- **`KV.FIND`** pads `KV.KEY$` to 8 characters and puts its 8 byte codes in `KV.CODE%(7)`. It compares
  `+0` of each slot against `KV.CODE%(0)` and runs the other 7 compares only on a match.
- **`KV.GET`** is `KV.FIND` and then `KV.AT`. `KV.OK = 0` and `KV.VALUE$ = ""` when the key is missing.
- **`KV.AT`** reads slot `KV.SLOT` without a scan. `KV.OK = 0` when the slot is free or `KV.SLOT` is out of
  1-63. A length of 0 skips the read loop and returns `KV.VALUE$ = ""`: `FOR I = 1 TO 0` runs its body
  once in both BASICs.
- **`KV.PUT`** refuses an empty key. It writes over the key's slot when the key exists, and takes the
  first free slot when it does not. It clamps `KV.VALUE$` to 119 characters. An empty `KV.VALUE$` writes the
  length byte and skips the write loop. `KV.OK = 0` when no slot is free.
- **`KV.PUTNUM` and `KV.GETNUM`** are stubs. Each sets `KV.OK = 0` and returns without selecting a
  bank. Under GPC, `VAL` stops at an exponent sign written as text, so `VAL(STR$(1E10))` is 1
  (`TODO.md`, compiler work item 6). The bodies follow that item: `KV.PUTNUM` is `KV.PUT` of
  `STR$(KV.NUM)`, and `KV.GETNUM` is `KV.GET` then `VAL`. A value is always text. `VAL` skips the
  leading space `STR$` puts on a positive number, so `KV.PUTNUM` stores `STR$` unchanged.
- **`KV.DEL`** writes `$00` at `+0`. `KV.OK = 0` when the key is missing.
- **`KV.WIPE`** writes the header and frees slots 1-63.
- **`KV.SAVE`** runs `BSAVE "@:"+KV.FNAME$,8,KV.BANK,$A000,$C000`. A disk error stops the program, as
  every `BSAVE` does in both BASICs.
- **`KV.LOAD`** checks the file exists with `OPEN 15` and `INPUT#15`, the same shape as
  `FILE.EXISTS` (`FILEIO.INC.BL:142-148`), and returns `KV.OK = 0` when it does not. It then runs
  `BLOAD KV.FNAME$,8,KV.BANK,$A000`, selects `KV.BANK` again, and checks the header.

**Names.** BASLOAD reports `DUPLICATE SYMBOL` when a label and a variable share a name, and the `$`
does not separate them. The variables `KV.KEY$`, `KV.VALUE$`, `KV.SLOT`, `KV.OK`, `KV.FNAME$`, `KV.HOMEBANK`,
`KV.NUM`, `KV.READY`, `KV.CODE%()` share no name with a label.

**GPC programs that use `BANKMGR`** claim the bank after `BANKMGR.INIT`, before the first
`GET.FREE.BANK`:

```basic
BANKMGR.SET.BANK = KV.BANK : GOSUB BANKMGR.CLAIM
```

## 4. `KVGP.INC.BL` — a GPC read without heap churn

Built only if test T6 shows the `CHR$(PEEK())` loop in `KV.GET` spends heap blocks.

- Requires `GPB.INC.BL` and `KV.INC.BL`.
- `KV.GETGP` reads into `KV.VALUE$` in place. `KV.INIT` sizes `KV.VALUE$` to 119 characters once.
  `GP.STRPTR(KV.VALUE$)` gives the length byte, the text at +1 and the capacity at -2 (`GP-BASIC.md`
  §3.4.5). The fill clamps to the capacity.
- The fill is a `PEEK`/`POKE` loop. A `GP.ASM` copy blob is the faster choice and is agreed first,
  per the standing order on assembly.
- `KV.GET` stays in `KV.INC.BL`. BASLOAD does not nest `#IFNDEF`, so it cannot be left out.

## 5. `kvstore.p8` — Prog8

Last, and only when asked.

- Select the bank with `cx16.push_rambank(KV_BANK)` and put the caller's back with
  `cx16.pop_rambank()` (`docs/attic/prog8/cx16/syslib.p8:902-912`).
- Convert between a zero-terminated Prog8 string and the length byte.
- Toolchain: `C:\8bitProgramming\prog8\prog8c-12.0.1-all.jar`.

Probes, before the module:

- **P1.** The bytes a Prog8 `"ABC"` compiles to. Prog8's default encoding is PETSCII
  (`prog8-progB/docs/source/variables.rst:435`), and the byte for an upper-case letter is not stated.
  An `iso:` prefix gives `$41`-`$5A`.
- **P2.** `diskio.save_raw(name, $A000, $2000)` and `diskio.load_raw(name, $A000)` with the bank
  selected, read back by `KV.LOAD` in BASL.

## 6. Tests

T1 and T3 are `KV.EXP.BL`, beside `KV.INC.BL` in `GPC-BASIC-TOOLS-SRC/GPB-MODS-TESTING/GPC-BASIC/`. The other
programs live in `GPC-BASIC-TOOLS-SRC/KV-STORE/`. All build in place, and every program ends with `END`.

| test | build | checks |
|---|---|---|
| T1 `KV.EXP.BL` | GPC, SHARED | init, put, get, rewrite, 120 characters clamped to 119, delete then find = 0, 63 puts then a refused 64th, empty key refused, an empty value read back as `""`, save, wipe, load, get. Also: a second `KV.INIT` keeps the store, another version is refused, a key is cut to 8, `KV.AT` on a used, a free and an out-of-range slot, a freed slot is reused, the stubs return `KV.OK = 0`, a missing file is refused, and `PEEK(0) = KV.HOMEBANK` after every call |
| T2 `KVA.BASL` + `KVB.BASL` | GPC, SHARED | `KVA` puts 3 keys and `LOAD`s `KVB`, which gets them. Answers whether anything between one program's `END` and the next program writes to bank 40 |
| T3 `KV.EXP.BL` | tokenised, run in stock BASIC | same PASS as T1. `TI` around a missing-key `KV.FIND` with 63 full slots, in both BASICs |
| T4 `KVA.BASL` | stock BASIC, chaining to compiled `KVB` | the interpreted writer and compiled reader agree |
| T5 `KVT5.BASL` | GPC, SHARED, one `GP.BANKED` region | the region calls `KV.PUT`, `KV.GET`, `KV.SAVE` and `KV.LOAD` with `KV.HOMEBANK` set, and carries on after each. `BLOAD` leaves the bank where the load stopped selected |
| T6 `KVT6.BASL` | GPC, SHARED | `FRE(0)` before and after 200 `KV.PUT` and `KV.GET` calls |

## 7. Steps

1. Review section 1.
2. Write `KV.INC.BL` in `GPC-BASIC-TOOLS-SRC/GPB-MODS-TESTING/GPC-BASIC/`.
3. T1 and T3.
4. T2 and T4.
5. T5 and T6.
6. `KVGP.INC.BL`, if T6 calls for it.
7. When compiler work item 6 is done: the `KV.PUTNUM` and `KV.GETNUM` bodies, and a T1 and T3 round
   trip of 1E10, 0.005, 0.5 and -3.
8. Copy `KV.INC.BL` to `GPC-BASIC/`. Add a §4 entry to `GP-BASIC.md` and a line to
   `GPC-BASIC/README.md`. Update the TODO entry: decisions, answered unverified items, the renamed
   older `KV.INC.BL` entry. No help regeneration.
9. Prog8 probes P1 and P2, then `kvstore.p8`, when asked.

## 8. Corrections to the TODO entry

- Stock BASIC has `STRPTR`, which returns the address of the first character
  (`docs/x16/X16 Reference - 04 - BASIC.md`, under `STRPTR`). The entry names only `POINTER`. The
  length is still not beside the text, so the "no stub" decision stands.
- The unverified item on `GP.BANKED` regions is answered from source: a region call returns into the
  wrong bank unless the include restores it (1.6).
- Bank 1 has a third owner: BASLOAD.
