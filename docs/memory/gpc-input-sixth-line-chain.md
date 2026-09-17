---
name: gpc-input-sixth-line-chain
description: "Agreed design for BUILD ALL: a sixth GPC.INPUT line naming a PRG to run after a successful compile"
metadata:
  type: project
---

**BUILD ALL in GPC.GUI needs a sixth GPC.INPUT line, and the user chose that route
on 2026-09-16.** No asm has been written; this is the agreed design, waiting on a
scoping pass and a go-ahead under [[ask-before-writing-asm]].

**The block it solves.** `GG.COMPILE` in `samples/GPC-GUI-HELPER/GPC.GUI.BASL`
ends `LOAD "GPC.BIN" : END` and never returns. GPC.BIN compiles one file and stops
at READY. GPC.INPUT is five lines -- source PRG, output PRG, map, `SHARED` or
blank, dead-list name -- and none of them says where to go next, so a loop over
the project's rows cannot exist in BASIC alone.

**The design.** GPC.INPUT gains a sixth line: the name of a PRG to LOAD and RUN
after a compile that succeeded. Empty keeps today's behaviour. GPC.GUI writes a
queue of the remaining rows, sets line six to itself, and reloads; on the way up
it takes the next row off the queue. One keypress builds every file in a project.

**Where it lands.** `source/application/source/file-io/control.asm` reads the
control file and `source/compiler/start.asm` acts on it; both were read on
2026-09-16 and confirmed to have no chain hook of any kind.

**The alternative, rejected as the feature but still the fallback.** Pure BASIC:
BUILD ALL compiles row one, and the next launch of GPC.GUI sees the queue and
offers CONTINUE. It costs the user one relaunch a file.

Related: [[gpc-gui-size-not-a-constraint]], [[load-chain-clears-memory]].
