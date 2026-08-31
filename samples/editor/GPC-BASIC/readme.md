# This is a COPY. The master is `/GPC-BASIC/`.

Every `.INC.BL` here is a byte-for-byte copy of the file of the same name in the repository
root's [`GPC-BASIC/`](../../../GPC-BASIC/). Nothing in this folder is edited.

## The rule

**Fix the master first, then re-copy.** If the editor needs a change to `THEME.INC.BL`,
`MENUHELP.INC.BL`, `INPHELP.INC.BL` or any other module, the change goes into
`/GPC-BASIC/<file>` and comes back here with a copy. A change made here and not there is
lost the next time anyone re-copies, and — worse — the two versions look interchangeable
while behaving differently.

Re-copy and check, from the repository root:

```sh
cp -p GPC-BASIC/*.INC.BL samples/editor/GPC-BASIC/
diff -r GPC-BASIC samples/editor/GPC-BASIC --exclude='*.EXP.BL' --exclude='*.md'
```

The `diff` must print nothing. It is the only test that matters here, and it is worth
running before any commit that touches either location.

## Why a copy exists at all

BASLOAD resolves `#INCLUDE` **by bare filename off the emulator's drive** — there is no
search path and no notion of a parent directory. So a module has to sit beside the source
that includes it. `make samples` is `cp -r samples`, which mirrors this whole tree into
`testing/samples/` (the emulator drive, and the root of the release zip), so the copy
travels with the sample and the sample builds anywhere it is unpacked.

The root `GPC-BASIC/` is the single master for the same reason the build refuses to track
`testing/*.INC.BL`: two tracked copies of a library are two copies free to drift apart.
This one is tracked because a sample that cannot build without files it does not ship is
not a sample. The rule above is what keeps that from costing anything.

## What is here, and what the editor actually uses

| file | used by the editor |
| --- | --- |
| `GPB.INC.BL` | yes — the `#TOKEN` definitions every GP.BASIC keyword needs |
| `THEME.INC.BL` | yes — named colour roles, light and dark |
| `MENUHELP.INC.BL` | yes — the menu bar and dropdowns |
| `INPHELP.INC.BL` | yes — positioned, length-limited entry fields |
| `APPHELP.INC.BL` | yes — start up politely, restore the screen on the way out |
| `STRHELP.INC.BL` | yes — string helpers the modules above lean on |
| `BMX.INC.BL` | **no** — image loading, copied only to keep this a whole-library mirror |

`BMX.INC.BL` is 20 KB the editor never touches. It is here so the folder is a complete,
one-`diff` mirror of the library rather than a hand-picked subset somebody has to remember
the shape of. `#IFNDEF` guards mean an unused module that is never `#INCLUDE`d costs the
compiled program nothing at all — not a byte of p-code, not a variable.
