#
#   helpbuild.py -- rebuild GPB.HELP alone, from the samples/GPC-HELP working copy.
#   Usage: helpbuild.py
#
#   A one-program shortcut into samplesbuild.py, which holds the table and does the work.
#   The build is SHARED, so the object needs GPB.RT.nnn.BIN on the drive: samplesbuild.py
#   copies the current runtimes into samples/GPC-HELP beside it, which is the drive
#   help-demo.bat mounts.
#
#   THIS BUILDS THE PROGRAM, NOT THE CONTENT.  The topics, the index and the two Markdown
#   files come from MKHELP.PY and are a separate command; the viewer reads
#   HELP-TXT/GPB.HELP.IDX at run time, so the two rebuild independently.
#
import os, subprocess, sys

HERE = os.path.dirname(os.path.abspath(__file__))
rc = subprocess.call([sys.executable, os.path.join(HERE, "samplesbuild.py"), "GPB.HELP"])

print()
print("The topics and the index are NOT rebuilt by this script. To rebuild them:")
print("    python samples/GPC-HELP/MKHELP.PY --md-only --out <scratch> --md-name CHECK.md")
print("    python samples/GPC-HELP/MKHELP.PY")
raise SystemExit(rc)
