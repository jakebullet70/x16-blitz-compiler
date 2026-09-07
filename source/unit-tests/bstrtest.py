# -*- coding: utf-8 -*-
#
#   GP.BANKEDSTR / GP.BSTR / GP.BSTRCOUNT -- tokenise, compile and RUN.
#
#   What is being tested is that the TEXT COMES BACK, byte for byte, from a bank -- so
#   the test compares printed output against the literals the source went in with,
#   including leading and trailing spaces.  A test that only checked "it compiled"
#   would pass with every string reading as the wrong one.
#
#   The named-group test is the one the flat design would fail: BSTRB inserts a line
#   into the MIDDLE of the first group, and every string in the SECOND group must still
#   come out where it belongs.
#
import os, re, subprocess, sys, time

ROOT = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
ROOT = os.path.abspath(os.path.join(ROOT, ".."))
T = os.path.join(ROOT, "testing")
E = os.path.join(ROOT, "bin", "x16emu")
PY = r"C:\Users\Admin\AppData\Local\Programs\Python\Python313\python.exe"

GPC_ERRORS = re.findall(
    r'\.text\s+"([^"]+)"',
    open(os.path.join(ROOT, "source", "common-source", "source", "generated",
                      "errors.asm"), encoding="latin-1").read())

env = dict(os.environ)
env["SDL_VIDEODRIVER"] = "dummy"


def emu(args, secs, stop=None, log="BS.LOG"):
    lp = os.path.join(T, log)
    with open(lp, "wb") as lf:
        p = subprocess.Popen([os.path.join(E, "x16emu.exe"), "-rom", os.path.join(E, "rom.bin"),
                              "-fsroot", "."] + args + ["-sound", "none", "-echo"],
                             cwd=T, stdout=lf, stderr=subprocess.STDOUT, env=env)
        dl = time.time() + secs
        while time.time() < dl:
            time.sleep(1)
            t = open(lp, "rb").read().decode("latin-1")
            if stop and stop in t:
                time.sleep(1.5)
                break
        p.kill()
        try:
            p.wait(timeout=5)
        except Exception:
            pass
    return open(lp, "rb").read().decode("latin-1")


def tokenise(name):
    src = os.path.join(T, name + ".SRC.PRG")
    if os.path.exists(src):
        os.remove(src)
    subprocess.run([PY, os.path.join(ROOT, "source", "gpc", "build_basl.py"),
                    name + ".BASL", name + ".SRC.PRG"], cwd=ROOT, capture_output=True, text=True)
    return os.path.exists(src)


def compile_one(name, mode="SHARED"):
    #   SHARED, not embedded: the bank image is moved by the BOOTSTRAP, and an embedded
    #   program has no bootstrap -- the same reason GP.BANKED needs shared.
    open(os.path.join(T, "GPC.INPUT"), "w", newline="\n").write(
        "%s.SRC.PRG\n%s.PRG\n%s.MAP\n%s\n" % (name, name, name, mode))
    p = os.path.join(T, name + ".PRG")
    if os.path.exists(p):
        os.remove(p)
    t = emu(["-warp", "-prg", "GPC.BIN", "-run"], 90, "OK CODE")
    #   GPC echoes its whole error-message TABLE right after the banner, so nothing
    #   before the "OUT:" line is a result.
    i = t.rfind("OUT:")
    tail = t[i:] if i >= 0 else t
    j = tail.find("OK CODE")
    if j >= 0:
        return "OK", tail[j:j + 30].split("\r")[0].strip()
    #   The object bytes are echoed too -- that is what -echo does to the output channel --
    #   so a compile error arrives GLUED to binary with no newline in front of it. Search
    #   the text; splitting it into lines and using startswith() finds nothing here.
    hits = [(tail.find(e), e) for e in GPC_ERRORS if tail.find(e) >= 0]
    if hits:
        k, _ = min(hits)
        return "ERR", tail[k:k + 40].split("\r")[0].strip()
    return "???", tail[-140:].replace("\r\n", " | ")


def run_one(name):
    t = emu(["-warp", "-prg", name + ".PRG", "-run"], 60, "READY.", log=name + ".RUN.LOG")
    #   Everything between the RUN and the final READY, marker lines only. The marker is
    #   "|" either side so leading and trailing SPACES in the text are visible and
    #   comparable -- losing those is the most likely way for this to be subtly wrong.
    out = []
    for line in t.replace("\r\n", "\n").replace("\r", "\n").split("\n"):
        s = line.rstrip("\n")
        m = re.match(r"^\|(.*)\|\s*$", s.strip())
        if m:
            out.append(m.group(1))
    return out


#   ---- the sources ---------------------------------------------------------------

BSTRA = """#SAVEAS "@:BSTRA.SRC.PRG"
#INCLUDE "GPB.INC.BL"
#SYMFILE "@:BSTRA.SRC.SYM"
    GP.BANKEDSTR 6 MENU.FILE
  " Open "
  " Save As... "
  "MiXeD cAsE 123"
    GP.ENDBANKEDSTR
    GP.BANKEDSTR 6 MENU.EDIT
  " Cut "
  " Paste "
    GP.ENDBANKEDSTR
    FOR I = 0 TO GP.BSTRCOUNT(MENU.FILE) - 1
      PRINT "|" + GP.BSTR(MENU.FILE, I) + "|"
    NEXT I
    FOR I = 0 TO GP.BSTRCOUNT(MENU.EDIT) - 1
      PRINT "|" + GP.BSTR(MENU.EDIT, I) + "|"
    NEXT I
    END
"""

#   The same, with one line inserted into the MIDDLE of the first group. Every string
#   in the SECOND group must still be the same -- this is what naming buys.
BSTRB = BSTRA.replace("BSTRA.SRC.PRG", "BSTRB.SRC.PRG") \
             .replace("BSTRA.SRC.SYM", "BSTRB.SRC.SYM") \
             .replace('  " Save As... "\n', '  " Save As... "\n  " INSERTED "\n')

#   A name no GP.BANKEDSTR block ever declared.
BSTRC = """#SAVEAS "@:BSTRC.SRC.PRG"
#INCLUDE "GPB.INC.BL"
    GP.BANKEDSTR 6 MENU.FILE
  " Open "
    GP.ENDBANKEDSTR
    PRINT GP.BSTR(MENU.EDIT, 0)
    END
"""

#   The same name twice.
BSTRD = """#SAVEAS "@:BSTRD.SRC.PRG"
#INCLUDE "GPB.INC.BL"
    GP.BANKEDSTR 6 MENU.FILE
  " Open "
    GP.ENDBANKEDSTR
    GP.BANKEDSTR 6 MENU.FILE
  " Close "
    GP.ENDBANKEDSTR
    PRINT GP.BSTR(MENU.FILE, 0)
    END
"""

#   Two blocks naming different banks -- one region a program.
BSTRE = """#SAVEAS "@:BSTRE.SRC.PRG"
#INCLUDE "GPB.INC.BL"
    GP.BANKEDSTR 6 MENU.FILE
  " Open "
    GP.ENDBANKEDSTR
    GP.BANKEDSTR 7 MENU.EDIT
  " Cut "
    GP.ENDBANKEDSTR
    PRINT GP.BSTR(MENU.FILE, 0)
    END
"""

#   An empty block.
BSTRF = """#SAVEAS "@:BSTRF.SRC.PRG"
#INCLUDE "GPB.INC.BL"
    GP.BANKEDSTR 6 MENU.FILE
    GP.ENDBANKEDSTR
    PRINT "X"
    END
"""

SOURCES = {"BSTRA": BSTRA, "BSTRB": BSTRB, "BSTRC": BSTRC,
           "BSTRD": BSTRD, "BSTRE": BSTRE, "BSTRF": BSTRF}

WANT_A = [" Open ", " Save As... ", "MiXeD cAsE 123", " Cut ", " Paste "]
WANT_B = [" Open ", " Save As... ", " INSERTED ", "MiXeD cAsE 123", " Cut ", " Paste "]
BAD = ["BSTRC", "BSTRD", "BSTRE", "BSTRF"]

for n, s in SOURCES.items():
    open(os.path.join(T, n + ".BASL"), "w", newline="\r\n").write(s)

results = {}
for n in SOURCES:
    ok = tokenise(n)
    kind, msg = compile_one(n) if ok else ("TOKFAIL", "")
    out = run_one(n) if (kind == "OK" and n not in BAD) else []
    results[n] = (kind, msg, out)
    print("%-6s tok=%-5s %-4s %-26s %s" % (n, ok, kind, msg, out))

print()
fails = 0

for n, want in (("BSTRA", WANT_A), ("BSTRB", WANT_B)):
    k, m, out = results[n]
    good = (k == "OK" and out == want)
    print("%-6s text back byte for byte   %s" % (n, "YES" if good else "*** NO ***"))
    if not good:
        fails += 1
        print("       want:", want)
        print("       got :", out)

#   The point of naming: MENU.EDIT is untouched by an insert into MENU.FILE.
ea = results["BSTRA"][2][-2:]
eb = results["BSTRB"][2][-2:]
good = (ea == eb == [" Cut ", " Paste "])
print("%-6s insert mid-group leaves the next group alone   %s"
      % ("BSTRB", "YES" if good else "*** NO ***"))
if not good:
    fails += 1
    print("       BSTRA tail:", ea, " BSTRB tail:", eb)

for n in BAD:
    k, m, _ = results[n]
    good = (k == "ERR")
    print("%-6s refused      %s   (%s)" % (n, "YES" if good else "*** NO ***", m))
    if not good:
        fails += 1

print()
print("ALL PASS" if fails == 0 else "%d FAILURE(S)" % fails)
sys.exit(0 if fails == 0 else 1)
