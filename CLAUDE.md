# Working in this repo

## Never read these whole

| file | lines | cost of a full read |
|---|---|---|
| `TODO.md` | 3,377 | ~55k tokens |
| `GPC-BASIC-TOOLS-SRC/GPB-MODS-TESTING/GPBMODS.BASL` | 3,453 | ~30k |
| `GPC-BASIC/GP-BASIC.md` | 1,813 | ~21k |
| `GPC-BASIC/GP-BASIC.GLOBALS.md` | 524 | ~9k |

Once read, a file is re-sent on every turn until the next compact, so one careless
read costs its size many times over.

Find the place first, then read only around it:

    grep -n "GMX.D.FOCUS" GPC-BASIC-TOOLS-SRC/GPB-MODS-TESTING/GPBMODS.BASL
    sed -n '1140,1200p' GPC-BASIC-TOOLS-SRC/GPB-MODS-TESTING/GPBMODS.BASL

GPBMODS has 99 top-level labels and both markdown files have numbered sections, so
the thing you want always has a name to grep for. The same applies to the
`_library.asm` files under `source/`, which are larger still.

## Build output

The headless emulator runs print long transcripts. Keep the last ~20 lines and the
numbers that matter (object size, the overlay `.nnn` sizes, the PASS count); do not
echo the whole log.

## Compact

Compact after every step, not at the end of a phase. Cost is context size times
turns, so a compact deferred through three steps is paid for on every turn of all
three.

## Comments

Four kinds earn a place: the **contract** on a callable routine, a **trap** that will cost an hour,
a **checklist** of what else to change, and a `## ---- signpost ----` in a long routine. Nothing
else.

Never write history, and never justify. "It was X until Y", what was tried, why an alternative was
rejected, what a number measured: all of it goes. State what is true now. One person reads this code
and it is the person who wrote it.

No ALL CAPS except in a labelled `WARNING`, a handful a file. No em-dash asides. One fact a
sentence.

A note or two, not an essay. A comment that restates the code is a naming bug; fix the name.

`.claude/agents/doc-style.md` has the full rules. Invoke `doc-style` for any prose work.

## Code

**Long, descriptive variable names.** BASLOAD crunches every identifier, so a short name saves
nothing in the PRG. `BITS.BYTEADDR` and `BITS.MASK`, not `BITS.W` and `BITS.M`. Internals and loop
counters too, not only the public in/out names. A name that needs a comment to say what it holds is
the bug.

**Write it expanded. Crunching is the user's pass, not mine.** One statement a line. A
single-statement conditional is a plain `IF ... THEN <statement>`, not a `GP.IF` / `GP.ENDIF` block.
Never put a statement on a label's line.

`.claude/agents/basl-author.md` has the rest of the house style.
