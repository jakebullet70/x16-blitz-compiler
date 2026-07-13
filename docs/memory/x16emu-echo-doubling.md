---
name: x16emu-echo-doubling
description: x16emu non-warp `-echo raw` prints every VM-emitted char TWICE; bench/run-bench.sh's `R=<n>` grep silently fails on it (returns ERR). De-double by every-2nd-char.
metadata:
  type: reference
  originSessionId: 574aca0d-1e65-4eab-aab1-acf026f5db05
---

When running a **compiled GPC .prg NON-WARP** under `x16emu -echo raw -run` (the mode `bench/run-bench.sh`
uses to read the real 60 Hz jiffy timer), **every character the VM prints is echoed TWICE** to the host
console: `PRINT 42` shows as `4422`, `PRINT "R=";206` shows as `RR==220066`. The KERNAL boot banner is
NOT doubled — only the program's own CHROUT output is. Under `-testbench` there is **no doubling** (which
is why the entire `scripts/test.sh` corpus — all `-testbench` — never sees it, and why output checks like
`PRINT "HELLO"` -> `HELLO` pass fine).

**Consequence:** `bench/run-bench.sh`'s `run_prg` greps `R= *[0-9]+`, which does NOT match the doubled
`RR==...` (the doubled `=` breaks it), so **every compiled row silently reports ERR / COMP_j blank** even
though the program ran correctly and POWEROFF'd. This is an EMULATOR/echo artifact, not a VM or compiler
bug: verified byte-for-byte identical output between a good baseline and a changed runtime.

**De-double recipe (recover the real value):** the doubling is exactly 2x, char-for-char. Take the doubled
digit run after the doubled `R=` (`RR==`) and keep every 2nd char:
```bash
s="$(tr -d '\r' | sed 's/.*RR==//' | grep -aoE '^[0-9]+' | head -1)"   # e.g. 220066
awk -v x="$s" 'BEGIN{o="";for(i=1;i<=length(x);i+=2)o=o substr(x,i,1);print o}'  # -> 206
```
This reproduced RESULTS.md's baseline jiffies (206/299/548/305/151/119/491/119) **exactly**, confirming the
method. A working de-doubling measurement script lived at scratchpad/measure.sh this session. NB: "collapse
consecutive pairs" (`sed 's/\(.\)\1/\1/g'`) is WRONG for repeated digits (200 -> `220000` -> `20`); use
every-2nd-char. Fix worth landing: make `run_prg`'s grep de-double, or have bench write the jiffy count to
the numeric mailbox instead of PRINT. Related: [[gpc-x16basic-look-act]], [[blitz-c64-benchmark-yardstick]].
