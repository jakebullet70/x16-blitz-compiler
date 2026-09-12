# The attic — kept, but dead

Nothing in this directory describes the tree as it is now. It is here because deleting it would
lose the only copy, not because it is worth reading. **Nothing in the live tree links into it, and
nothing should.** If you are grepping the documentation, exclude this directory.

Swept in on 12th September 2026.

| what | where it came from | why it is here |
| --- | --- | --- |
| `prog8-manual/` | was `docs/source/` | The **Prog8 compiler's own** Sphinx manual — `.rst` sources, `conf.py`, the call graph and memory-map diagrams. Upstream's documentation, not ours; nothing in this repo is Sphinx-built. Renamed on the way in, because `source/` at the top of this repo means the 64tass sources the compiler is built from, and two `source/` directories meaning opposite things is a trap. |
| `prog8/` | was `docs/prog8/` | The Prog8 standard library — 129 `.p8` and `.asm` files — plus `PROGB.PLAN.MD` and `PROG8_TO_PROGB_CONVERSION.md`, the plan and conversion guide for a BASIC-flavoured front end to a compiler this project no longer has. The library sources are the part that could still earn its keep: `math.asm`, `sorting.p8` and `shared_compression.p8` are 6502 algorithms whoever wrote them had to get right. |
| `Blitz.md` | was `docs/blitz/Blitz.md` | The C64 Blitz manual, OCR'd into one word per line with `## BLITZ` headers dropped through the middle of sentences. It cannot be read as prose. Kept only in case it is the last trace of that manual. |

The first two arrived in the very first commit, on 13th July 2026, and were never edited again.
They are the remains of the earlier attempt at this compiler, the self-hosted Prog8 one — see
`docs/memory/blitz-x16-prior-attempt.md`. The retired front end itself is elsewhere, tracked, under
`source/gpc/old-archive/`.
