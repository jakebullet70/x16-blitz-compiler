#!/bin/bash
# ************************************************************************************************
#
#   run-bench.sh : time each benchmark interpreted (stock X16 BASIC) vs compiled (Blitz).
#
#   Timing is TI (jiffies, 1/60s) read inside the emulator, so it is independent of -warp;
#   verified by running the same program with and without -warp and getting identical counts.
#
#   Each program powers the machine off when done so the emulator exits straight away. Both
#   sides now just use POWEROFF: Blitz compiles it, so the I2CPOKE 66,1,0 substitution this
#   script used to make is gone and the two columns run byte-identical source.
#
#   Stock BASIC is injected with -bas, which types the listing in through the keyboard, so
#   those sources must be UPPERCASE.
#
# ************************************************************************************************
set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
EMU="$ROOT/bin/x16emu/x16emu.exe"
ROM="$ROOT/bin/x16emu/rom.bin"
BLITZ="$ROOT/source/application/GPC.BLITZ.BIN"
WORK="${TMPDIR:-/tmp}/blitzbench.$$"
mkdir -p "$WORK"
trap 'rm -rf "$WORK"' EXIT

jiffies() { grep -oE "R= *-?[0-9]+" | head -1 | grep -oE "[0-9]+"; }

printf "%-14s %10s %10s %8s\n" "benchmark" "stock" "compiled" "speedup"
printf "%-14s %10s %10s %8s\n" "-------------" "----------" "----------" "--------"

for src in "$ROOT"/bench/*.bas; do
    name=$(basename "$src" .bas)
    w="$WORK/$name"; mkdir -p "$w"

    # --- interpreted: stock X16 BASIC, uppercased, POWEROFF to exit
    tr 'a-z' 'A-Z' < "$src" > "$w/stock.bas"
    stock=$( cd "$w" && timeout 300 "$EMU" -rom "$ROM" -sound none -zeroram -bas stock.bas -run -warp -echo raw 2>&1 \
             | tr -d '\000' | jiffies )

    # --- compiled: Blitz. Same source, unedited: tokenise, compile, run.
    #     GPC.INPUT is how the compiler is told what to build; it has no defaults and will
    #     print NO GPC.INPUT FILE and stop without one.
    cp "$BLITZ" "$w/"
    printf 'SOURCE.PRG\nOBJECT.PRG\n\n' >"$w/GPC.INPUT"
    ( cd "$ROOT" && python bin/tokenise.zip "$src" "$w/SOURCE.PRG" >/dev/null 2>&1 )
    ( cd "$w" && timeout 120 "$EMU" -rom "$ROM" -sound none -zeroram -fsroot "$w" -prg GPC.BLITZ.BIN -run -warp >/dev/null 2>&1 )
    if [ ! -f "$w/OBJECT.PRG" ]; then
        printf "%-14s %10s %10s %8s\n" "$name" "${stock:-?}" "COMPILE-ERR" "-"
        continue
    fi
    comp=$( cd "$w" && timeout 300 "$EMU" -rom "$ROM" -sound none -zeroram -fsroot "$w" -prg OBJECT.PRG -run -warp -echo raw 2>&1 \
            | tr -d '\000' | jiffies )

    if [ -n "${stock:-}" ] && [ -n "${comp:-}" ] && [ "${comp:-0}" -gt 0 ]; then
        sp=$(python -c "print(f'{$stock/$comp:.2f}x')")
    else
        sp="-"
    fi
    printf "%-14s %10s %10s %8s\n" "$name" "${stock:-?}" "${comp:-HANG}" "$sp"
done
