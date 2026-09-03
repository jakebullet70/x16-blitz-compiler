---
name: answer-the-question-asked
description: "User feedback - answer the costing question actually asked, do not substitute an adjacent easier problem or pad with edge cases nobody writes"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: b55260da-8747-488d-aedc-fab566bdcc78
  modified: 2026-08-30T19:47:53.906Z
---

Given sharply on 2026-08-30, after I was asked what it would cost in runtime bytes to let a
plain `GOTO` leave a `GP.DO` / `GP.SELECT` cleanly. Three corrections in one message:

- **"Compile cost is not an issue. Only runtime cost."** Stop pricing compile-time memory or
  compiler work in an answer. See [[compiler-must-not-cap-program-size]] for the one way
  compiler size still matters — it caps max program size — and nothing else does.
- **"No one writes code like that. NO ONE."** I had hedged the answer with a caveat about
  `GOTO` *into* a block. Do not spend the reader's attention on edge cases nobody writes.
- **"`GP.EXITSEL` does not fix ANY issue at all."** I recommended a structured exit when the
  question was about an arbitrary `GOTO`. It was an adjacent, easier problem, and offering it
  as the recommendation read as not having understood the question.

**Why:** the answer was actually **zero runtime bytes** and I had already found the pieces
that prove it — I buried it under a menu of options, a wrong recommendation and an irrelevant
caveat. The user had to ask twice.

**How to apply:** when asked what something *costs*, lead with the number for the thing that
was asked about, then the mechanism. Options and alternatives only if they beat it on that
same number. If a proposal does not do what was asked, do not list it as a choice — say it
does not do the job, or leave it out. See [[gpb-goto-out-of-block-design]] for the answer that
should have come first.
