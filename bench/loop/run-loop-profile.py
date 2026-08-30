# ************************************************************************************************
#
#   run-loop-profile.py : attribute the compiled empty-loop iteration cost to its components.
#
#   COMPILED ONLY. This profiles the p-code VM, so the stock-BASIC column that run-bench.sh
#   carries is not relevant here and is not measured.
#
#   Method is the one the array-access work validated (bench/RESULTS.md): TI (jiffies, 1/60 s)
#   read INSIDE the emulator, so it is independent of -warp; every variant runs the SAME
#   iteration count so each pair of programs differs in exactly one thing and the difference
#   is the cost of that thing.
#
#   cycles/iteration = jiffies * (8_000_000 / 60) / ITERATIONS      (X16 runs at 8 MHz)
#
#   Resolution is one jiffy = 133333/N cycles-per-iteration, so N is deliberately large
#   (60,000) to keep a single jiffy worth ~2.2 cycles rather than ~4.4 at the 30,000 the
#   headline 01_forloop uses.
#
#   Headless: SDL_VIDEODRIVER=dummy so the emulator never steals the desktop's keyboard focus,
#   and the process is killed BY PID -- never by image name, because other projects on this
#   box run x16emu too.
#
# ************************************************************************************************

import os, re, sys, time, shutil, subprocess, tempfile

HERE  = os.path.dirname(os.path.abspath(__file__))
ROOT  = os.path.abspath(os.path.join(HERE, "..", ".."))
EMU   = os.path.join(ROOT, "bin", "x16emu", "x16emu.exe")
ROM   = os.path.join(ROOT, "bin", "x16emu", "rom.bin")
BLITZ = os.path.join(ROOT, "source", "application", "GPC.BIN")
TOKEN = os.path.join(ROOT, "bin", "tokenise.zip")

ITERATIONS = 60000
CLOCK_HZ   = 8_000_000
JIFFY_HZ   = 60
CYC_PER_JIFFY_PER_ITER = (CLOCK_HZ / JIFFY_HZ) / ITERATIONS   # ~2.222

ENV = dict(os.environ)
ENV["SDL_VIDEODRIVER"] = "dummy"


def run(args, cwd, timeout, until=None):
    """Run the emulator, return its stdout. Killed BY PID -- never by image name.

    The compiler does not power the machine off when it finishes, so waiting for it to exit
    means waiting out the whole timeout. Pass `until` = a path to poll for instead: as soon as
    it appears and its size stops changing, the save is done and the emulator can be killed.
    That is the same wait-for-the-artefact trick source/gpc/build_basl.py uses."""
    p = subprocess.Popen(args, cwd=cwd, stdout=subprocess.PIPE,
                         stderr=subprocess.STDOUT, env=ENV)
    if until is not None:
        deadline = time.time() + timeout
        while time.time() < deadline:
            if p.poll() is not None:
                break
            if os.path.exists(until) and os.path.getsize(until) > 0:
                s1 = os.path.getsize(until)
                time.sleep(0.3)
                if os.path.getsize(until) == s1:
                    break
            time.sleep(0.2)
        p.kill()
        out, _ = p.communicate()
        return out.decode("latin-1", "replace").replace("\x00", "")
    try:
        out, _ = p.communicate(timeout=timeout)
    except subprocess.TimeoutExpired:
        p.kill()
        out, _ = p.communicate()
    return out.decode("latin-1", "replace").replace("\x00", "")


def measure(src):
    """Tokenise -> compile -> run one .bas. Returns jiffies, or None with a reason."""
    work = tempfile.mkdtemp(prefix="loopprof.")
    try:
        shutil.copy(BLITZ, work)
        prg = os.path.join(work, "SOURCE.PRG")
        r = subprocess.run([sys.executable, TOKEN, src, prg],
                           capture_output=True)
        if r.returncode != 0 or not os.path.exists(prg):
            return None, "TOKENISE-ERR"

        with open(os.path.join(work, "GPC.INPUT"), "w", newline="\n") as f:
            f.write("SOURCE.PRG\nOBJECT.PRG\n\n")

        obj = os.path.join(work, "OBJECT.PRG")
        run([EMU, "-rom", ROM, "-sound", "none", "-zeroram", "-fsroot", work,
             "-prg", "GPC.BIN", "-run", "-warp"], work, 120, until=obj)
        if not os.path.exists(obj):
            return None, "COMPILE-ERR"

        out = run([EMU, "-rom", ROM, "-sound", "none", "-zeroram", "-fsroot", work,
                   "-prg", "OBJECT.PRG", "-run", "-warp", "-echo", "raw"], work, 300)
        m = re.search(r"R=\s*(-?\d+)", out)
        if not m:
            return None, "NO-RESULT"
        return int(m.group(1)), None
    finally:
        shutil.rmtree(work, ignore_errors=True)


def main():
    for f, what in ((EMU, "x16emu.exe"), (ROM, "rom.bin"),
                    (BLITZ, "GPC.BIN"), (TOKEN, "tokenise.zip")):
        if not os.path.exists(f):
            sys.exit("missing %s (%s)" % (what, f))

    srcs = sorted(x for x in os.listdir(HERE) if x.endswith(".bas"))
    results = {}

    print("iterations = %d   |   1 jiffy = %.2f cycles/iteration\n" % (
        ITERATIONS, CYC_PER_JIFFY_PER_ITER))
    print("%-14s %9s %14s   %s" % ("program", "jiffies", "cycles/iter", "what it isolates"))
    print("%-14s %9s %14s   %s" % ("-" * 14, "-" * 9, "-" * 14, "-" * 40))

    for s in srcs:
        name = os.path.splitext(s)[0]
        jif, err = measure(os.path.join(HERE, s))
        if err:
            print("%-14s %9s %14s   %s" % (name, err, "-", ""))
            continue
        results[name] = jif
        cyc = jif * CYC_PER_JIFFY_PER_ITER
        note = "" if name != "L0_null" else "(harness overhead - expect ~0)"
        print("%-14s %9d %14.1f   %s" % (name, jif, cyc, note))

    print()
    print("=== attribution (cycles per iteration, net) ===")

    def delta(a, b, label):
        if a in results and b in results:
            d = (results[a] - results[b]) * CYC_PER_JIFFY_PER_ITER
            print("  %-46s %8.1f" % (label, d))

    delta("L1_empty", "L0_null", "FOR/NEXT empty iteration (total)")
    delta("L2_one",   "L1_empty", "one  K=I   (dispatch + var load + store)")
    delta("L3_two",   "L2_one",   "second K=I (marginal - linearity check)")
    delta("L4_four",  "L3_two",   "third+fourth K=I (marginal x2)")
    delta("L5_const", "L1_empty", "one  K=1   (dispatch + store, no var load)")
    delta("L2_one",   "L5_const", "  -> cost of the variable LOAD alone")
    delta("L6_desc",  "L1_empty", "NEXT without the integer fast path (descending)")
    delta("L7_step1", "L1_empty", "explicit STEP 1 vs implied")
    delta("L8_goto",  "L1_empty", "IF/GOTO loop vs FOR/NEXT")
    delta("L4_four",  "L9_4inline", "4 statements on 4 LINES vs 4 on ONE line")
    if "L4_four" in results and "L9_4inline" in results:
        per = (results["L4_four"] - results["L9_4inline"]) * CYC_PER_JIFFY_PER_ITER / 3.0
        print("  %-46s %8.1f" % ("  -> cost of one extra source LINE", per))
    delta("LA_fltassign", "L1_empty", "K=J   float scalar copy (6-byte)")
    delta("LB_intassign", "L1_empty", "K%=J% int scalar copy (2-byte path)")
    delta("LA_fltassign", "LB_intassign", "  -> what the 2-byte int path SAVES")
    print()


if __name__ == "__main__":
    main()
