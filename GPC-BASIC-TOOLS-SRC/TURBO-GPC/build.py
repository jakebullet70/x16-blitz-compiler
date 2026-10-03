"""Build TURBO.PRG, the editor, in this folder.

    python build.py        write TGKEYS.BIN, tokenise TURBO.BASL, compile it SHARED

The emulator mounts GPC-BASIC-TOOLS-SRC and changes into this folder. The tools come from
/GPC/, the tool home that make install fills. TURBO.MAP and TURBO.SRC.SYM stay beside
TURBO.PRG. The tokenised source and GPC.INPUT are removed.
"""

import os
import subprocess
import sys

sys.dont_write_bytecode = True
HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
GPC = os.path.join(ROOT, "source", "gpc")
NAME = "TURBO"

import tgkeys


def step(script, *args):
    """Run a build script on this folder and stop on its failure."""
    result = subprocess.run([sys.executable, os.path.join(GPC, script), "--drive", HERE] + list(args))
    if result.returncode != 0:
        sys.exit("build: %s failed" % script)


def main():
    # build_basl.py compares only the .BASL with the .SRC.PRG, so an edited #INCLUDE
    # is not seen. Removing the .SRC.PRG forces the tokenise.
    stale = os.path.join(HERE, NAME + ".SRC.PRG")
    if os.path.exists(stale):
        os.remove(stale)
    print("TGKEYS.BIN %d bytes" % tgkeys.write_table())
    step("build_basl.py", NAME + ".BASL", NAME + ".SRC.PRG")
    step("compile_shared.py", NAME + ".SRC.PRG", NAME + ".PRG", NAME + ".MAP")
    for scratch in (NAME + ".SRC.PRG", "GPC.INPUT"):
        if os.path.exists(os.path.join(HERE, scratch)):
            os.remove(os.path.join(HERE, scratch))
    print("%s.PRG %d bytes" % (NAME, os.path.getsize(os.path.join(HERE, NAME + ".PRG"))))


main()
