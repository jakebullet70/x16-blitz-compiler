---
name: tech-doc-structure-spec
description: The user's standing spec for technical documentation: engineering register, named structural sections, document inputs and outputs and errors, never invent a detail
metadata:
  node_type: memory
  type: feedback
---

Standing instruction given 2026-09-29, in the user's own words:

> Write professional technical documentation for programmers and experienced developers.
> Use a precise, concise, engineering-focused style. Avoid marketing language, unnecessary
> explanations, and vague statements. Use correct technical terminology and do not
> oversimplify.
>
> Structure the documentation logically with relevant sections such as: Overview,
> Architecture, Requirements, Setup, Configuration, API, Components, Data Flow, Usage, Code
> Examples, Errors, Testing, Troubleshooting, Security, Performance, and Limitations.
>
> Document APIs, configuration, inputs, outputs, errors, dependencies, edge cases, and
> important implementation details where relevant.
>
> Do not invent technical details. If information is missing or uncertain, clearly state it
> or ask for clarification.
>
> Write the documentation as a practical reference that a programmer can use to build,
> debug, deploy, and maintain the software.

**Why:** the reader is a working programmer with a question. The section list is a checklist
of what such a reader arrives needing, so a page that omits a relevant one is incomplete
rather than short.

**How to apply:** pick only the sections the page actually has content for, and name them.
An overview page carries Overview, Architecture, Components, Requirements, Usage and
Limitations; a keyword entry carries its fixed slots instead. Every number, address and count
comes from the source or a measurement, never from the previous draft. Where a fact is not
established, write that it is not established.

This sits on top of [[prose-style-is-flat-reference]], which still owns voice: one fact a
sentence, present tense, no history, no justification, caps only in a labelled WARNING. The
two agree. This one adds structure and coverage. `.claude/agents/doc-style.md` holds the
voice rules, so invoke `doc-style` for the prose and apply this spec for the shape.

Related: [[help-topic-writing-rules]], [[hlp-files-carry-hand-edits]],
[[comments-light-code-should-flow]].
