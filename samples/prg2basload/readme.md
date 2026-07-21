# Sample — PRG2BASLOAD

`prg2basload.basl` is a real, non-trivial X16 program: it reads a **tokenised BASIC `.PRG`** and
writes it back out as text — either a plain `LIST`-style listing or proper **BASLOAD source** (no
line numbers, labels where the program branches, spaces put back around every keyword). It is a
detokenizer/converter, ~1000 lines of BASLOAD, included here as a sample because it is exactly the
kind of program the compiler is *for*: a tool you run now and then, doing enough work that the
interpreter's speed actually hurts.

The source is unmodified BASLOAD — it carries its own `#SAVEAS`, `#AUTONUM` and `#MAXCOLUMN`
directives at the top, so it tokenises through the ROM's BASLOAD utility as-is, and the resulting
`.PRG` is what you feed to the compiler.

## The point of this sample: the speed increase

The numbers below are real — taken off the X16 jiffy clock (`TI`), not host wall-clock time under
emulator warp. The test input was a **919-line, 17,883-byte** BASIC program (a paint program),
converted to BASLOAD source (the full two-pass job: pass 1 finds branch targets, pass 2 writes the
labelled source).

| Running the converter as… | Time |
| --- | --- |
| BASIC, ROM interpreter | **12 min 22 s** |
| BASIC compiled with GPC Blitz | **1 min 51 s** |

**Compiling is worth about 6.7×** on this program. Twelve minutes and change becomes under two —
the difference between "go make coffee" and "wait for it". The compiled output does the *identical*
work and produces byte-for-byte the same file. The speedup is pure — nothing is skipped.

The program's own header comments this directly (see `prg2basload.basl`, the `SHOW.ESTIMATE`
routine): there is **no fixed seconds-per-line figure**, because the same conversion runs ~6.6×
faster compiled, so any constant tuned for the interpreter is badly wrong for the compiled build.
The program sidesteps that by *timing itself* — it clocks how long a fixed 16,000-POKE table-clear
takes and scales its estimate from that, so the "estimated time" line stays honest whether you run
it interpreted or compiled.

### Why this program is a fair demonstration

- **It is real work, not a micro-benchmark.** Two full walks of a linked list of BASIC lines, a
  greedy token expander, label resolution across two 8,000-byte bit maps, and buffered file output.
  Nothing here is contrived to make the compiler look good.
- **The output is verifiable.** An independent detokenizer (written in a different language)
  produces byte-identical files, so "compiled" is not quietly cutting a corner the interpreter took.
- **You keep the source editable on the machine.** The win from the compiler is speed with no loss
  of the ability to open `prg2basload.basl` in an editor on the X16 and change it — which is the
  whole pitch of compiling BASIC rather than rewriting the tool in a systems language.

The practical read: **the compiler makes BASIC fast enough for a tool you run now and then, while
you keep BASIC source.**

## Compiling it

1. Tokenise the BASLOAD source into a `.PRG` — from the ROM prompt, `BASLOAD "PRG2BASLOAD.BASL"`
   yields `PRG2BASLOAD.PRG` (the source's own `#SAVEAS` names it).
2. Point the compiler at it with a `GPC.INPUT` control file (source on line 1, object on line 2):

   ```
   PRG2BASLOAD.PRG
   C.PRG2BASLOAD.PRG
   ```

   then run the engine (`GPC.BLITZ.BIN`), or drive it interactively with `GPC.PRG`.
3. Run `C.PRG2BASLOAD.PRG` and hand it a tokenised program to convert. Time a big one both ways
   (`C.` versus the plain tokenised BASIC) and you should see roughly the 6.7× above.
