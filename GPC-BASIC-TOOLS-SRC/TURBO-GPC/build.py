"""Build TURBO.PRG, the editor, in this folder.

    python build.py        write TGKEYS.BIN, tokenise TURBO.BASL, compile it SHARED

The #GPC lines at the head of TURBO.BASL name TURBO.PRG, TURBO.MAP and TURBO.DEAD and pick SHARED.
TURBO.DEAD lists the source lines dead-code removal left out, one number a line.

The emulator mounts GPC-BASIC-TOOLS-SRC and changes into this folder. The tools come from
/GPC/, the tool home that make install fills. TURBO.MAP and TURBO.SRC.SYM stay beside
TURBO.PRG. The tokenised source and GPC.INPUT are removed.
"""

import os
import subprocess
import sys
import time

sys.dont_write_bytecode = True
HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
GPC = os.path.join(ROOT, "source", "gpc")
NAME = "TURBO"

import tgkeys


SYM_CACHE_BYTES = 32768


def step(script, *args):
    """Run a build script on this folder, print how long it took, and stop on its failure."""
    started = time.time()
    result = subprocess.run([sys.executable, os.path.join(GPC, script), "--drive", HERE] + list(args))
    print("build: %s took %d s" % (script, time.time() - started))
    if result.returncode != 0:
        sys.exit("build: %s failed" % script)


def symbol_cache_bytes():
    """Bytes the compiler's GP.ASM {VAR} cache needs for NAME.SRC.SYM: each VARIABLES name and three.

    WARNING: past SYM_CACHE_BYTES (application/source/compiler/symfile.asm) the compiler reads the
    whole .SYM from disk for every {VAR}, and a compile takes minutes instead of seconds.
    """
    with open(os.path.join(HERE, NAME + ".SRC.SYM"), "rb") as symbols:
        lines = symbols.read().replace(b"\r\n", b"\n").replace(b"\r", b"\n").split(b"\n")
    in_variables = False
    needed = 0
    for line in lines:
        if not line.startswith(b" "):
            in_variables = in_variables or line.startswith(b"VARIABLES")
            continue
        fields = line[1:].split(b" ", 1)
        if in_variables and len(fields) == 2:
            needed += len(fields[1].split(b" ")[0]) + 3
    return needed


def main():
    # build_basl.py compares only the .BASL with the .SRC.PRG, so an edited #INCLUDE
    # is not seen. Removing the .SRC.PRG forces the tokenise.
    stale = os.path.join(HERE, NAME + ".SRC.PRG")
    if os.path.exists(stale):
        os.remove(stale)
    print("TGKEYS.BIN %d bytes" % tgkeys.write_table())
    step("build_basl.py", NAME + ".BASL", NAME + ".SRC.PRG")
    needed = symbol_cache_bytes()
    print("build: {VAR} cache needs %d of %d bytes" % (needed, SYM_CACHE_BYTES))
    if needed > SYM_CACHE_BYTES:
        print("build: WARNING the cache overflows, so this compile will be slow")
    # compile_shared.py checks the object it is given, so NAME.PRG must match #GPC OBJECT.
    step("compile_shared.py", NAME + ".SRC.PRG", NAME + ".PRG")
    for scratch in (NAME + ".SRC.PRG", "GPC.INPUT"):
        if os.path.exists(os.path.join(HERE, scratch)):
            os.remove(os.path.join(HERE, scratch))
    print("%s.PRG %d bytes" % (NAME, os.path.getsize(os.path.join(HERE, NAME + ".PRG"))))


main()
