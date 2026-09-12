---
name: filedir-bank-split
description: "BUILT: FILEDIR banks whole, by moving the bank switch out of BASIC and into its two GP.ASM blobs. No split was needed, and the '78% cannot move' that stopped it was a line count, not a byte count."
metadata:
  node_type: memory
  type: project
---

**BUILT 2026-09-07.** `FILEDIR.INC.BL` now lives in a `GP.BANKED` region. It was not split, and the
earlier entry here talked itself out of the right answer with a bad measurement.

## What the old note got wrong

It said `FILE.DIR.FILL` (93 lines) and `FILE.DIR.STEP` (112 lines) were "205 of 264 code lines,
**78%**, in the two that cannot move". **Those two routines are `GP.ASM` blobs**, and that count is
of `REM` assembly. Measured from the map instead — the method in [[measure-pcode-per-module]] —
they are **16 and 12 bytes of p-code, 28 of 507, 5.5%**. A blob's body never occupies a region
either way: the pool is appended at the object tail in low RAM and the call is an absolute `.word`.

The same note's own recommendation — push the window switch below BASIC — was right, and it is
cheap precisely because the two blobs already exist.

## What was done

The four `BANK` statements are gone. Both blobs now take the data bank at entry and put the
caller's back at **every** exit:

```
REM LDA $00
REM STA {FILE.DIR.WAS%}
REM LDA {FILE.DIR.BNK%}
REM BEQ <skip>            ; 0 is low RAM: leave the window alone
REM STA $00
```

`FILE.DIR.BANKHOLD` and `FILE.DIR.OWAS%` were deleted with them. **The restore is not optional and
not merely tidy**: control returns to banked p-code at `$A000`, so a blob that left the data bank
selected would have the interpreter fetch its next byte from it.

`FILE.DIR.BNK%` carries the bank into the assembly because `{FILE.DIR.BANK}` is an untyped variable
— a 6-byte float slot, where `LDA` would read the mantissa's low byte and work only by accident.

The three entry points became `.BODY` and got shims in `SHIM.GUIBANK.INC.BL`, exactly as `MENUVERT` in
the same directory already does.

## Numbers

| | bytes |
|---|---:|
| `FILEDIR.INC.BL` before | 507 |
| after — the bank handling deleted itself | **435** |
| of which bankable before | 213 |
| of which bankable after | **435, all of it** |

`TODO.md` said 878 for FILEDIR and 900 for FILEIO. Both were wrong; FILEIO measures 833.

## The gate, and it passed

`FILE.DIR.OPEN` runs `OPEN`, `INPUT#` and two `CLOSE`s. Banked, that p-code is fetched from `$A000`
**while those KERNAL calls run**, so a call that left the RAM bank changed would kill the next
instruction with no diagnostic. Probed on the machine with a `GP.ASM` reader of `$00` —
`PEEK(0)` cannot see it — and **`OPEN`, `INPUT#` and `CLOSE` on device 8 all leave `$00` alone**.
That extends [[kernal-preserves-ram-bank]], which covered only the screen calls.

## The one behaviour change

**A banked build no longer preserves the caller's RAM bank across a `FILE.DIR` call.** That is the
shim's doing, not the module's — a `SHIM.GUIBANK` shim deliberately leaves its own bank selected, see
[[gp-banked-call-out-loses-the-bank]]. The blobs preserve the bank they are entered with. Callers
in low memory do not care; a caller that did would have to re-select.

`testing/FILEDIRT.BASL`'s `D08 BANKAFTEROPEN` and `D09 BANKAFTERNEXT` assert the unbanked contract
and still hold for the `.BODY` labels called directly.

Related: [[pcode-runs-from-a-bank-proven]], [[gp-banked-region-relocation]],
[[macptr-wraps-banks-itself]], [[gpbmods-resident-pcode-breakdown]].
