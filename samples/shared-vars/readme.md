# Sample — shared variables across a LOAD chain

Two tiny programs that hand variables to each other. `PRG1` sets some variables, waits for a key,
then `LOAD`s `PRG2` — and `PRG2` finds every variable still there and prints them back. It is a
demonstration of program **chaining** with **variable carry-over**, using the compiler's shared
runtime.

```
PRG1                                   PRG2
----                                   ----
nm$ = "ada" : gn$ = "linus"            (reads nm$, gn$, ct, yr, av)
ct = 4 : yr = 2026 : av = 42.5         *** all variables survived the load ***
LOAD "C.PRG2.PRG"          ─────────►
```

## This only works compiled

Run these two programs through the **interpreter** and the variables are **gone** after the `LOAD` —
`PRG2` sees zeros and empty strings. That was measured on the X16 (R49), not assumed: a program-mode
`LOAD` on this machine does not preserve variables the way some older Commodore machines' chaining
did.

**Compiled by GPC Blitz, the variables carry across.** That is the whole point of the sample. The
compiled runtime keeps its variables and strings in high RAM (around `$8100`), which a `LOAD` and the
ROM's `CLR` never touch; the compiler's `LOAD` arms a small signature that tells the *loaded*
program's runtime "this is a chain — skip your memory clear", so the data survives intact. See
`source/runtime/source/system-specific/x16/commands/load.asm` in the tree for the mechanism.

## Two rules the sample follows

1. **Declare the shared variables in the same order in both programs.** The compiler assigns each
   variable a fixed address by order of *first appearance*. If `PRG1` first touches `nm$, gn$, ct,
   yr, av` in that order, `PRG2` must too, or the addresses won't line up and it will read the wrong
   values. Here both programs first touch them in the identical order.

2. **Scalars carry; arrays do not.** String and numeric *scalars* (`nm$`, `ct`, …) survive the chain
   cleanly — verified end to end. A **string array does not**: the loaded program needs a `DIM` to
   use the array, and that `DIM` re-initializes it, wiping the values the chain just carried over.
   (Omitting the `DIM` doesn't help — the array has no descriptor on the loaded side.) So this sample
   deliberately uses scalars. If you need to pass many values, pass them as scalars, or write them to
   a file in `PRG1` and read them back in `PRG2`.

## The shared runtime

Both programs are compiled in **shared-runtime mode**. Instead of each binary embedding its own copy
of the ~11 KB runtime, they share **one** resident copy: the first program to run loads `GPC.RT.BIN`
(about 11 KB) once, and every chained program reuses it. The compiled programs themselves are then
tiny — in this sample about **0.5 KB each** — which is exactly what you want when several programs
chain together: one runtime in memory, not one per program.

## Files

| File | What it is |
| --- | --- |
| `PRG1.BASL`, `PRG2.BASL` | the readable [BASLOAD](https://github.com/stefan-b-jakobsson/basload-rom) source (label-based, no line numbers) |
| `PRG1.PRG`, `PRG2.PRG` | the tokenised programs — the input you feed to the compiler |

The `.PRG` files are the tokenised BASIC that the compiler reads; the `.BASL` files are the readable
source. Each carries a `#SAVEAS "@:PRGn.PRG"` directive, so editing a `.BASL` and re-tokenising it
overwrites its `.PRG` in place.

## Build and run

Both programs must be compiled in **shared** mode, and `GPC.RT.BIN` must be on the drive at run time.

1. Tokenise each BASLOAD source to a `.PRG`. From the ROM prompt, `BASLOAD "PRG1.BASL"` (and again for
   `PRG2.BASL`) writes `PRG1.PRG` / `PRG2.PRG` via the source's own `#SAVEAS`. The tokenised `.PRG`
   files are already included here, so you can skip this unless you edit the source.

2. Compile each program, selecting the resident/shared runtime. With the interactive front end
   `GPC.PRG`, answer **yes** to "resident runtime?"; scripted, write a `GPC.INPUT` whose fourth line
   is `shared`:

   ```
   PRG1.PRG        (input)          PRG2.PRG
   C.PRG1.PRG      (output)         C.PRG2.PRG
                   (no map)
   shared          (mode)           shared
   ```

   This produces `C.PRG1.PRG` and `C.PRG2.PRG`.

3. `PRG1` chains with `LOAD "C.PRG2.PRG"`, so the compiled second program **must** be named
   `C.PRG2.PRG` (rename it if your compile step named it something else). Make sure `GPC.RT.BIN`,
   `C.PRG1.PRG` and `C.PRG2.PRG` are all on the same drive.

4. Run `C.PRG1.PRG`. Press a key when prompted; it chains to `C.PRG2.PRG`, which prints the variables
   and `*** all variables survived the load ***`.

> If `PRG2` reports the variables were lost, the usual cause is running one of them interpreted, or
> compiling only one of the two — both must be compiled for the carry-over to work.
