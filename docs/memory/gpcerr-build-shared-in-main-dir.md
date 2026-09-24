---
name: gpcerr-build-shared-in-main-dir
description: GPC.ERR.PRG is always built SHARED and always in the main directory, then copied out — a standalone build of it is the wrong artifact
metadata:
  type: project
---

**User instruction, 2026-09-01.** `GPC.ERR` — the helper that turns a runtime `<MSG> @ $XXXX`
back into a BASIC line by reading a `M.<source>` debug map:

- **Always compile it SHARED, never standalone.**
- **Always compile it in the MAIN directory**, and copy the result out of there if it is wanted
  somewhere else.

**Why shared is not a preference.** Shared leaves the runtime out of the object, ~12 KB that a
standalone build would carry. That is the whole point of a helper you run *beside* the program you
are debugging. A standalone build is not a bigger version of this program, it is the wrong one.

**The object is 19,243 bytes after the phase 2 GUI rewrite (2026-09-24), against a 22,016 byte
ceiling.** It was ~1.6 KB as a two-prompt text helper; that figure is gone, not a target. See
`docs/blitz/GPC-ERR-GUI.PLAN.md` and [[gpc-shared-pcode-cap-is-rtbase]].

**The trap this closes:** the headless harness (`scratchpad/edbuild.py`) builds STANDALONE. So do
not let it write `testing/C.GPC.ERR.PRG` — building the source there to *check* it compiles is fine,
but the artifact it produces must not be copied over the tracked one. Both tracked binaries
(`testing/GPC.ERR.PRG`, `testing/C.GPC.ERR.PRG`) were left stale rather than overwritten for exactly
this reason when the source moved to [[retired-keyword-defers-to-runtime]]'s STRCASE port.

The rule is also written into the header of `testing/GPC.ERR.BASL` itself, where whoever rebuilds it
will actually be looking.
