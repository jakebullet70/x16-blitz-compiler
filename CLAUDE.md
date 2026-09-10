# Working in this repo

## Never read these whole

| file | lines | cost of a full read |
|---|---|---|
| `TODO.md` | 3,377 | ~55k tokens |
| `samples/GPB-MODS-TESTING/GPBMODS.BASL` | 3,453 | ~30k |
| `GPC-BASIC/GP-BASIC.md` | 1,813 | ~21k |
| `GPC-BASIC/GP-BASIC.GLOBALS.md` | 524 | ~9k |

Once read, a file is re-sent on every turn until the next compact, so one careless
read costs its size many times over.

Find the place first, then read only around it:

    grep -n "GMX.D.FOCUS" samples/GPB-MODS-TESTING/GPBMODS.BASL
    sed -n '1140,1200p' samples/GPB-MODS-TESTING/GPBMODS.BASL

GPBMODS has 99 top-level labels and both markdown files have numbered sections, so
the thing you want always has a name to grep for. The same applies to the
`_library.asm` files under `source/`, which are larger still.

## Build output

The headless emulator runs print long transcripts. Keep the last ~20 lines and the
numbers that matter (object size, the overlay `.Bnn` sizes, the PASS count); do not
echo the whole log.

## Compact

Compact after every step, not at the end of a phase. Cost is context size times
turns, so a compact deferred through three steps is paid for on every turn of all
three.
