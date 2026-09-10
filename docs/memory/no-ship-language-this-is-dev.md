---
name: no-ship-language-this-is-dev
description: "Do not call anything shipped or released here; it is dev and test work, and do not build unless asked"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 5591d6bc-636d-4001-b0b0-d858156d6ec0
  modified: 2026-09-01T07:13:14.301Z
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

**Nor regenerate the help text.** Corrected 2026-09-10: *"stop updating the help text, wait until the final design is done and bugs are fixed. U can ask me if I want but wait for me to tell u."* `samples/GPC-HELP/MKHELP.PY` rewrites 27 tracked files from the markdown, so running it mid-design buries the real diff under regenerated output and publishes an interface that is still moving. It is the LAST step of a design, not a step inside one -- ask, then wait for a yes.

Related: [[answer-the-question-asked]], [[user-runs-concurrent-agents-here]].
