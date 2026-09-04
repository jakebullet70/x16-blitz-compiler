---
name: gp-drawing-targets-layer-1
description: "Every GP drawing command writes to layer 1's map; there is no row clamp, and L1_MAPBASE is a POKEable register"
metadata:
  type: reference
---

**`GP.FILL` / `GP.BOX` / `GP.PRINTAT` / `GP.CHAR` all address LAYER 1 and nothing else.**
`GPDrawAddress` (`gpdraw.asm`) hands off to `TileSetAddress` (`runtime/.../commands/tiles.asm`),
whose header says it plainly: "Point VERA data port 0 at the **layer 1** map entry". `samples/editor`
found the same seam from the other side -- "every GP command addresses layer 1 only" -- which is why
it needs its own `ED.ROW.STREAM` assembly to paint a document on layer 0.

**There is NO clamp to the visible screen.** `TileSetAddress` is pure arithmetic on a 24-bit
accumulator, "because a 256 x 256 map of two byte entries is 128K -- the whole of VRAM". It derives
the map base AND the row stride from VERA at every call. So `GP.PRINTAT x, 119, ...` writes to map
row 119 with no new primitive -- an off-screen map area is reachable with the drawing commands
already in the runtime. `gpdY` is one byte, so rows 0..255.

**`VERAL1MapBase` is a register, and BASIC can POKE it.** Because the base is re-read on every call,
pointing it somewhere else aims the ordinary GP drawing commands at another layer's map or at a
scratch map -- then point it back. That is the asm-free way to draw on layer 0, at the cost of
layer 1 displaying the other map until it is restored. `ED.L0.ON` is the trick for hiding that:
switch the layer on only AFTER the first full render, so no row is ever visible before it is painted.

Bears on [[scrolling-a-screen-region]] option 3, which costs you layer 0 program-wide -- this note is
WHY it costs that. See also [[gpc-editor-branch-and-gui-next]], [[vera-fx-cache-write-is-aligned]].
