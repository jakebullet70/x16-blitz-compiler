---
name: no-ship-language-this-is-dev
description: "Do not call anything shipped or released here; do not build unless asked, except in a play-test loop, where every requested change is built at once"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 5591d6bc-636d-4001-b0b0-d858156d6ec0
  modified: 2026-10-05T20:28:36.909Z
---

**Never say "ship", "shipped" or "release" about this repo.** Corrected on
2026-09-01: *"stop saying shipped, there is no ship, we are testing only, this is
dev work."*

**Why:** nothing here has an audience yet. Calling a commit "shipped" claims a
finality the work does not have, and it reads as spin rather than status.

**How to apply:** say what actually happened — committed, pushed, built, green.
Describe a checked-in artifact as *checked in*, not *shipped*.

**And do not build unless asked.** Same day: *"why are you building? did I say
build? just commit and push."* "Commit and push" means exactly that; refreshing a
checked-in binary is a separate request. Offer it in one line, do not do it.

**Nor regenerate the help text.** Corrected 2026-09-10: *"stop updating the help text, wait until the final design is done and bugs are fixed. U can ask me if I want but wait for me to tell u."* `GPC-BASIC-TOOLS-SRC/GPC-HELP/MKHELP.PY` rewrites 27 tracked files from the markdown, so running it mid-design buries the real diff under regenerated output and publishes an interface that is still moving. It is the LAST step of a design, not a step inside one -- ask, then wait for a yes.

**A source edit is not a build request.** Corrected 2026-09-16, after merging
three GP.BANKED regions in GPC.GUI.BASL and then rebuilding to check the sizes:
*"next time, do not build until I tell you."* The rule holds even when the edit
obviously needs a compile to be worth anything, and even when a build earlier in
the same session was asked for. Make the edit, say what a build would tell us,
and stop.

**The exception is a play-test loop.** Corrected 2026-10-02, on LANDER64, after a speed option
was edited in and left unbuilt: *"did you forget, its give and take, after interaction you auto
build?"* When the user is running a program by hand and sends back a change to it, the edit is
half the turn and the build is the other half. The user cannot test the change without the PRG. Build
that one sample in the background straight after the edit, then report the result.

**Feature work the user asked for counts too.** Said 2026-10-05, after TURBO's encoding switch was
written and left waiting for a "shall I build?": *"after these give and take edits just do a build"*.
When the user asks for a change to a program, build that program as soon as the edits land. Do not
ask first.

The rule still holds everywhere else: "commit and push" is not a build request, a refactor nobody
is about to run is not one, and the help text is never regenerated unasked.

Related: [[answer-the-question-asked]], [[user-runs-concurrent-agents-here]],
[[run-builds-in-background]].
