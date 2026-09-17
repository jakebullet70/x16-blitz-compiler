---
name: help-topic-writing-rules
description: The standing brief for help-topic prose — document current behaviour only, no history, no theory; it overrides hand edits
metadata:
  node_type: memory
  type: feedback
  modified: 2026-09-17
---

The user gave this brief on 2026-09-17 and made it the default for all help work:

> Document the software as it currently works. Do not discuss its history, previous behavior,
> deprecated approaches, or background theory. Write concise, practical programmer documentation
> with clear headings, exact details, and one or two useful examples. Include prerequisites, usage,
> parameters, outputs, errors, defaults, and limitations when relevant. Use code blocks for code and
> commands. Do not speculate or add filler.

It applies every time a help topic is touched, not only to new topics: **a topic being edited is
rewritten to this brief.** The user's own hand rewrites of `.HLP` files are included and may be
overwritten.

**Why:** the reader is a programmer looking something up. History, rationale and "it used to" cost
them screens and answer nothing.

**How to apply:** write in the `GPC-BASIC/` markdown masters, never in `HELP-TXT/*.HLP`
(see [[hlp-files-carry-hand-edits]]), then render with `MKHELP.PY`. The brief is written into
`.claude/agents/doc-style.md` under "The help system", so invoking `doc-style` carries it. It sits
on top of [[prose-style-is-flat-reference]] — flat voice, fixed entry slots, no Why slot — and
narrows it: no history at all. The brief's "one or two examples" is settled at **one** here
(2026-09-17) — the `Example` slot, omitted rather than padded with a thin one.
