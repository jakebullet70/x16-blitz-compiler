---
name: ask-before-adding-library-code
description: "Standing order 2026-10-05: ask before adding any routine or feature to a GPC-BASIC library module; one program's need belongs in that program"
metadata:
  node_type: memory
  type: feedback
  originSessionId: d662cdc7-bff8-47b0-95f7-b4086f5383d3
  modified: 2026-10-05T07:23:45.137Z
---

Ask before adding code to a GPC-BASIC library file (`GPB-MODS-TESTING/GPC-BASIC/*.INC.BL` or root `GPC-BASIC/`). Refactors and fixes of existing code are fine. New routines, new behaviour and new options need a yes first.

**Why:** without the dead-code option (off by default, and no repo build passes --strip) every program that `#INCLUDE`s a module carries every routine in it, called or not ([[basl-dead-code-elimination-measured]]: dead routines inside used modules cost GPBMODS 521 B). A feature only TURBO needs, added to FILEPICK or GUI, taxes every other program forever.

**How to apply:** when a program needs something a module lacks, first propose putting it in the program itself (or a program-local .INC.BL). Offer the library only when a second program will use it, and say what it costs every includer.
