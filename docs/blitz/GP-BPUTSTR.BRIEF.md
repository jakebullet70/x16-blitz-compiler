# GP.BSTRSET — a write into a GP.BANKEDSTR group

A brief for reviewing the design. Everything needed to start is in this file; the sources
it names are there to check against, not to learn from.

## What is wanted

`GP.BSTR(NAME, n)` reads string *n* of a `GP.BANKEDSTR` group out of a RAM bank. There is no
write. Wanted:

    GP.BSTRSET NAME, n, A$

- **A statement, not a function.** Nothing comes back, and a second unary operator is not
  free: `UnaryGPBStr` already spent the GP block's 256-byte crossing (`ObjectBase` moved
  `$3C00` → `$3D00` for it).
- **Argument order mirrors `GP.BSTR(NAME, n)`** — group, index, value.
- **`NAME` is resolved at compile time**, exactly as on the read side. It never reaches the
  object.
- The name is `GP.BSTRSET`, settled 2026-09-18. It was `GP.BPUTSTR` in an earlier draft of this
  brief. Every keyword of the group now starts `GP.BSTR`.

## Why

A group declared with space-filled literals becomes a set of fixed-capacity slots:

    GP.BANKEDSTR 3 FIELDS
    "                                        "
    "                                        "
    GP.ENDBANKEDSTR

**The length byte is content; the slot width is capacity.** Write 7 characters into a
40-byte slot and `GP.BSTR` allocates 7 and copies 7. Variable-length strings in a fixed slot,
no new metadata.

Two callers:

- **GUI form pages** — a dozen `LINEINPUT` fields, only one ever being edited. Their text
  need not sit in the low-RAM string heap.
- **The menu refactor** (`docs/blitz/GUI-MENUS.PLAN.md` §8) — it would retire the private
  `MENU.TEXT$()` / `MENU.HINT$()` arrays. The engine reads a row, draws it, drops it.

Both rest on one property: **never more than one string live at once.** If a path wants every
slot in variables at the same time, the idea gains nothing.

## Why it must be a compiler command, not BASIC

The read can't be hand-rolled cheaply — `A$ = A$ + CHR$(PEEK(...))` makes a new heap block per
character. Writing by hand *is* possible (`GP.STRPTR` + a `BANK`/`PEEK`/`POKE` loop, if the
group owns its whole bank so the flat index equals the group index). It fails two ways:

1. **A `BANK` statement disqualifies code from a `GP.BANKED` region.** The loop cannot live in
   banked code, and banking the GUI library is the point. `GP.BSTR` is safe in a region because
   its handler saves and restores the bank itself.
2. **The own-bank trick breaks once the group shares a bank** — the group base is then a
   compile-time fact the program cannot see.

## How the read side works (what the write must mirror)

**Compile side** — `source/compiler/source/commands/gpbstr.asm`:

- `GP.BANKEDSTR <bank> <NAME>` … `GP.ENDBANKEDSTR` collects bare quoted lines into a pool.
  The bank number is a compile-time decimal constant.
- `BankedStrGroupCompile` (`:225`) reads the bare group name, looks it up in the group table,
  and **pushes the group's base as a constant**. A second helper, `BankedStrAddCompile`, emits
  `PCD_PLUS`. So `GP.BSTR(NAME, n)` compiles to *push base, push n, add, call handler* — the
  handler sees one flat index.
- The dispatch line in the generated table (for spelling a new entry) is
  `source/compiler/_library.asm:5422`:

      ;	GP.BSTR   (X:BankedStrGroupCompile,# X:BankedStrAddCompile) T S

**Pool** — `source/compiler/source/commands/gpbstrpool.asm`:

- `BStrAppendString` (`:186`) appends every literal unconditionally: placeholder length byte,
  characters to the closing quote, patch the length, bump the count. **No deduplication**, so
  identical space-filled literals are distinct records.
- **A literal caps at 255 characters** (`inc bstrLength` / `beq _BASTooLong`).
- `BSTR_MAX_GROUPS` = 128.

**Flush** — `source/compiler/source/commands/gpbstrflush.asm` writes each bank image into the
object as a region.

**Runtime** — `source/gp-runtime/source/commands/gpbstr.asm`, `UnaryGPBStr` (`:67`), 185 lines.
The bank layout, offsets from `$A000`:

    +0    string count, 16 bit
    +2    count x 16-bit offsets, each from $A000
    ...   records, [length][characters] back to back

The handler:

1. `GetInteger16Bit` → flat index in `zTemp0` (not raw from `NSMantissa` — a `FOR` variable
   arrives as a float).
2. Top 4 bits are a **slot**; `GPBSTRBANKS,x` maps slot → RAM bank. `X` is the evaluation
   stack slot, so it is `phx`/`plx`'d around that lookup. Low 12 bits are the index.
3. Directory entry = `$A002 + index*2`; save `SelectRAMBank`, select the text bank.
4. Record address = stored offset + `$A0` on the high byte.
5. Read the length, `StringAllocTemp`, copy backwards, **restore the caller's bank**.

**No bounds check**, deliberately: "the compiler knows every index it emits." That reasoning
**does not carry** to a write, whose string arrives at run time.

`GPBSTRBANKS` is a **fixed address** (`source/common-source/source/common.inc:147-148`:
`BSTR_MAX_BANKS = 16`, `GPBSTRBANKS = $0A00 - BSTR_MAX_BANKS`), not a label — the runtime is
linked twice with `gp.library` at opposite ends.

## What a write handler looks like

The read handler run backwards, without `StringAllocTemp`, so smaller:

1. Pop `A$` → its address (`GP.STRPTR` semantics: points at the length byte, text at +1).
2. Flat index → slot → bank, directory entry → record address, exactly as the read.
3. **Clamp** the length to the slot's capacity.
4. Select bank, write length byte, copy characters, restore the caller's bank.

## The failure it must guard

Overflowing slot *n* overwrites slot *n+1*'s length byte, and the directory still points there.
The next `GP.BSTR` on *n+1* allocates a garbage-sized temp and copies garbage into it. The write
**must clamp**.

## The open questions — the review should answer these

1. **How does the handler know a slot's capacity?** Today a record carries only its current
   length; once written shorter, the original width is gone. Options to weigh:
   - capacity = distance to the next directory entry (free, but the last record in a bank
     needs another bound, and it assumes records are contiguous and in order);
   - a capacity byte per record (costs the bank one byte a string, changes the layout the read
     side walks);
   - a per-group capacity emitted by the compiler as a constant beside the group base, as the
     TODO suggests (costs call-site bytes; requires every slot in a group to be one width).
2. **How does the declaration say a group is writable and how wide?** Nothing today makes
   `GP.BANKEDSTR` say "these are 40-byte slots". Typing out 40 spaces per line is error-prone.
   Is a declaration form like `GP.BANKEDSTR 3 FIELDS, 40` with a count wanted?
3. **Compile side:** does `GP.BSTRSET` reuse `BankedStrGroupCompile` + `BankedStrAddCompile`
   as-is for `NAME, n`, then compile `A$` as a third operand?
4. **Where the handler lives and what it costs** — the GP block's free bytes below
   `ObjectBase`, and whether it forces another page crossing.

## Rules for this work

- **Ask before writing asm** — agree GP.ASM or 64tass first. This review produces a design, not
  code.
- `TODO.md` is 3,377 lines — read only the entry, lines 1365-1458. The `_library.asm` files
  under `source/` are generated concatenations of the sources above; `sed` a line range when
  needed.
- After any runtime change: `make -C source/runtime gpc-rt` is a separate target that
  `make libs` does not run. A stale `GPB.RT.nnn.BIN` cost a long detour last time.
- The pool cannot live in bank 7 (`OBJ_BUF_BANK`); banks 8-15 are region banks.
- No build unless asked.

## Background, if wanted

- `TODO.md` lines 1365-1458 — the full original argument.
- `docs/memory/gp-bankedstr-literal-text-in-a-bank.md` — the read side's economics and traps.

## Decisions, 2026-09-18

The review questions are settled. Implementation is under way in 64tass.

- **Blank slots are declared with `SPC(n)`.** It is a body line inside the block, and n is a
  decimal constant from 0 to 255. `SPC(` is a one-byte X16 token (`$A6`) with the opening
  paren built in, so BASLOAD tokenises the line without complaint. The compiler reads it at
  compile time and nothing reaches the runtime. The slot has capacity n and length 0, so
  `GP.BSTR` returns `""` until it is written. `RPT$(n)` was considered and dropped: the real
  `RPT$` takes two arguments, so a one-argument form clashes with it.
- **Every slot is writable**, whether it comes from a quoted literal or from `SPC(n)`.
- **Capacity is a byte before each record.** The layout is `[cap][len][cap bytes]`. The
  directory still points at the length byte, so the read handler finds its length as before.
  A quoted literal gets a capacity equal to its length. The cost is one bank byte per string
  and no low RAM.
- **A too-long string is cut to the capacity without an error.**
- **An index past the bank's count writes nothing.** Without this guard, a runtime n out of
  range could aim the write at `$9Fxx` I/O.
- **The handler lives in the GP block.** Bank 1 is not possible, because the handler has to
  swap the `$A000` window to reach the text bank. The core is not wanted, because every
  program would pay for it. If the handler forces a page crossing, that is accepted.
- **The statement compiles as `GP.BSTRSET NAME, n, A$`.** It reuses `BankedStrGroupCompile`
  and `BankedStrAddCompile` for `NAME, n`, and then compiles `A$`.
- **The token is 52813.**
