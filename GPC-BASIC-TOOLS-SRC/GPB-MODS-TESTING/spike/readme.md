# The banked p-code spike

`SPIKE.BASL` answers one question: does GPC p-code execute from a RAM bank? It does. Two `GP.ASM`
blobs and a copy loop, with no ABI change, no runtime change and no compiler change.

`GOSUB SPIKE.CAPTURE` runs `SPIKE.MARK = 111 : RETURN` in low RAM while a blob records
`codePtr + Y`. 64 bytes are copied to bank 7 at `$A000` with the `111` patched to `222`. A second
blob points `codePtr` at the window, and `MARK` comes back **222**.

It is a spike, not a design: it writes the saved Y at `$0103 + S`, which depends on `CommandSYS`'s
exact prologue. The design that came out of it is in `../PLAN.md` section 10.
