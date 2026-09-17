---
name: gpasm-label-cannot-start-with-a
description: "A GP.ASM label whose name starts with the letter A is refused as a syntax error, because the operand parser tests for accumulator mode before it tries an identifier"
metadata:
  type: project
---

**A `GP.ASM` label may not start with `A`.** `BNE ACLP`, `JSR ADDUP` and `LDA ARRAY` all stop the
compile with `PASS 1 SYNTAX ERROR @ <line>`, naming the line that uses the label rather than the one
that defines it. Found 2026-09-16 while writing the `ACPTR` probe, where a loop label `ACLP` cost a
build cycle.

The cause is in `AsmParseOperand`, `source/compiler/source/commands/gpasmcode.asm:665`. Accumulator
mode is tested before anything else, by looking at the operand's first character:

```asm
        cmp     #'A'                        ; a bare A is the accumulator, i.e. implied
        bne     _APOAbsolute
        jsr     GetNext                     ; consume it and see what follows
        jsr     LookNextNonSpace
        beq     _APODone
        cmp     #';'
        beq     _APODone
        jmp     AsmBadSyntax                ; A followed by anything else is not a form we have
```

So an operand beginning with `A` is only ever accepted when the `A` stands alone or is followed by a
comment. Every other name starting with that letter is refused.

**It is a defect, not a rule**, and a small one to fix: the parser should fall through to
`_APOAbsolute` when the character after the `A` can continue an identifier, rather than failing.
Nothing depends on the present behaviour -- no label in this tree starts with `A`, which is why it
went unnoticed. Not fixed as of 2026-09-16; working around it by renaming the label costs nothing.

Related: [[gpasm-implementation-status]], [[gpasm-fixups-retired-by-two-passes]],
[[overlay-in-prg-research]].
