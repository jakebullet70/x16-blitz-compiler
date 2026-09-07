---
name: array-element-sizes-measured
description: "A % array is TWO bytes an element and an untyped one is SIX. FILEDIR's header said six for a % array and sized a 682-byte buffer as 2,046."
metadata:
  node_type: memory
  type: reference
---

**Measured 2026-09-07 with `GP.ARRPTR` on adjacent arrays** (`work/stashvram/ARRSZ.BASL`):

| declaration | bytes an element | 10 elements + header |
|---|---:|---:|
| `DIM A%(n)` | **2** | 23 |
| `DIM A(n)` | **6** | 63 |

So `DIM A%(340)` is **682 bytes**, not 2,046. Confirmed the other way too: poking 20 bytes over
`A%(0..9)` sets `A%(9)` to `-1`, so 20 bytes covers exactly ten elements.

`GPB.INC.BL:96` and `GP-BASIC.md:434` have always said "2 bytes an element for a `%`". The X16
reference (`04 - BASIC.md:757`) says 2 / 5 / 3 for stock int / float / string; GPC's untyped is 6.

## The trap this caught

**`FILEDIR.INC.BL`'s low-RAM recipe was wrong**, and it is the recipe a caller copies:

```
DIM FD.BUF%(340)
FILE.DIR.PTR = GP.ARRPTR(FD.BUF%())
FILE.DIR.CAP = 341 * 6          <- 2,046 bytes of room in a 682-byte array
```

It also said "a numeric array is six bytes an element", which is true of an untyped array and not
of the `%` one it declares. A caller following it hands the directory reader **three times the room
it has**, and the read runs up to 1,364 bytes off the end into whatever the workspace put after it.
Latent rather than fired: the test directories were short enough never to reach 682 bytes. Fixed in
the header 2026-09-07 to `DIM FD.BUF%(1022)` / `1023 * 2`.

`testing/FILEDIRT.BASL` still sets `FILE.DIR.CAP = 2046` against `DIM FD.BUF%(340)` — another
agent's file, not edited.

**Where this bites generally:** any `GP.ARRPTR` buffer handed to assembly or to `memory_copy`.
The stride is yours to add and the compiler will not check it, so a wrong element size is a silent
overrun of the workspace, which is where every other variable lives. It cost a full debug cycle on
`work/stashvram/SVGCT.BASL`, where a 600-byte write into a 522-byte array corrupted the array
holding the test's own expectations and the symptom was a length reading back as `1.14529721E+31`.

See [[measure-before-changing-code]] and [[blitz-arrays-share-the-workspace]].
