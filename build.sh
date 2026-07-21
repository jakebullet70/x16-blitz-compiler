#!/bin/sh
# ***************************************************************************
#  build.sh -- full build of x16-blitz-compiler. POSIX; run from Git Bash.
#  Invoked by build.bat, or directly:  ./build.sh [gpc|run|clean]
# ***************************************************************************
set -e
cd "$(dirname "$0")"

case "$1" in
    clean)
        echo "== Cleaning source tree =="
        make -C source clean
        ;;
    gpc)
        echo "== make libs =="
        make libs
        echo "== make release =="
        make release
        echo "== make -C source/gpc release  (GPC.PRG) =="
        make -C source/gpc release
        echo "== make samples  (mirror samples/ -> testing/samples) =="
        make samples
        ;;
    run)
        # build.bat handles "run": it builds (default target) then launches the
        # emulator itself. If build.sh is called directly with "run", build and
        # launch here too.
        echo "== make libs =="
        make libs
        echo "== make release =="
        make release
        echo "== make samples  (mirror samples/ -> testing/samples) =="
        make samples
        echo "== launching x16emu with GPC.PRG =="
        cmd //c "x16emu.bat" GPC.PRG
        exit 0
        ;;
    "")
        echo "== make libs =="
        make libs
        echo "== make release =="
        make release
        echo "== make samples  (mirror samples/ -> testing/samples) =="
        make samples
        ;;
    *)
        echo "usage: build.sh [gpc|run|clean]" >&2
        exit 2
        ;;
esac

echo
echo "== BUILD OK =="
