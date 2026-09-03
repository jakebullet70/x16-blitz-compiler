---
name: gpb-block-openers-must-not-defer
description: A block-opening statement must never fail with .error_syntax — defer-to-runtime rolls the opener back and silently corrupts enclosing block nesting
metadata:
  node_type: memory
  type: project
  originSessionId: d7531322-9a88-4f9a-8bdd-54f6afe99cb4
---

**Design rule, derived 2026-08-30 from `source/compiler/source/main/errorhandler.asm` (~line 31) and
`compiler.asm`. Reasoned from the code, NOT yet reproduced — treat the GP.SELECT half as a lead.**

While a statement compiles, `deferErrors` is armed and a **SYNTAX error does not abort**: the object
cursor rolls back to `stmtRecoverObj` and the statement is replaced with a runtime throw-stub
(`.deferror`). Deferral is keyed on the *syntax* message pointer specifically, so `.error_structure`
and `.error_type` still abort hard.

**Why that is dangerous for a block construct.** The rollback erases the opener's emitted tokens, but
the matching closer is a *separate statement on a later line* and still compiles and still emits. The
block is left with a closer and no opener, so an **enclosing** block's `FixBranches` scan counts one
extra close, closes a level early, and resolves its branches to the wrong place. No diagnostic.

**Rule: any statement that opens or closes a block raises `.error_structure`/`.error_type`, never
`.error_syntax`.** Every error macro is 3 bytes (`jmp ErrorV_*`), so this costs nothing.

**RESOLVED for `GP.SELECT` 2026-09-01:** the rule is applied — every error exit in
`compiler/commands/select.asm` aborts hard (`SelectFailSyntax` deliberately lands on
`.error_type`, with a comment saying why), and `GP.SELECT 1` was verified to stop the
compile with `TYPE MISMATCH @ n`, no object written. The original lead, kept for the
reasoning: `GP.SELECT` looked exposed — a bad selector expression defers, `gp.select`
vanishes, and the `GP.ENDSEL` on a later line is orphaned. Applies to the planned
[[gpb-block-if-design]] too, which is where the rule was noticed.
