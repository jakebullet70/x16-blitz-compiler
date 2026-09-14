---
name: review-findings-must-be-reachable
description: Report a code-review finding only if valid BASIC that BASLOAD accepts can trigger it; drop anything that needs invalid source
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 422a7b37-5897-4def-9e69-98fb13f87ae9
  modified: 2026-09-14T02:40:15.504Z
---

Report a compiler or runtime review finding only when valid BASIC, which BASLOAD accepts, can reach
it. A finding that needs source BASIC would reject, such as `;GP.BANKED 5`, is noise. Drop it before
reporting, even when the compiler's two code paths disagree on it.

**Why:** 2026-09-14, the `.bgosub` review reported that the region scan skips `:` but not `;`. The
user pointed out that no valid program starts a line with `;`, and asked why that came up and not
`!GP.BANKED`.

**How to apply:** before relaying a review agent's findings, ask of each one what real source
triggers it. If the answer is a typo or invalid syntax, leave it out. Keep the report short: say
whether it works, then only the reachable problems. See [[answer-the-question-asked]].
