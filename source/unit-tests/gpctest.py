# -*- coding: utf-8 -*-
#
#   Compiler tests in two tiers (docs/blitz/COMPILER-TESTS.PLAN.md).
#
#       gpctest.py ref    [--gpc FILE] [--only A,B]
#       gpctest.py quick  [--gpc FILE] [--only A,B]
#       gpctest.py full   [--gpc FILE] [--only A,B]
#
#   ref compiles dcref.py's set with the option off and on, and keeps the results in
#   work/gpctest/ref/off/<tag>/ and work/gpctest/ref/on/<tag>/. Run it with the compiler from
#   before the change.
#
#   quick and full compile the set again and check each compile:
#
#       off       against ref/off: the object, map, every .Bnn and the OK line
#       on        against ref/on: the same, and the removed-line list D.NAME
#       stripped  the dcstrip.py identity: D.NAME's lines deleted from the source, compiled
#                 with the option off, must give the option-on object. When D.NAME is empty
#                 the stripped source is the source, and the off compile stands in for it.
#       dctest    dctest.py's removed lines against hand analysis, DC1-DC12
#       dcstrip   the identity on dcstrip.py's DC programs
#
#   quick runs off, on and stripped on the small programs, off alone on GUIFRMT and GPB.HELP,
#   off and on on GPBMODS, and the DC tests. It leaves out RGM. full runs off, on and stripped
#   on every program, and the DC tests.
#
#   Every compile shares one pool of WORKERS emulators, slowest first. Run nothing else that
#   starts an emulator alongside it.
#
#   Drives: work/gpctest/off/<tag>/, on/<tag>/ and stripped/<tag>/, with the stripped source
#   in in-stripped/<tag>/. The DC tests keep work/dctest/ and work/dcstrip/.
#
import os, sys, time, glob, shutil, filecmp, traceback
from concurrent.futures import ThreadPoolExecutor, as_completed

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import dcref
import dcstrip
import dctest

WORK = os.path.join(dcref.ROOT, "work", "gpctest")
REF = os.path.join(WORK, "ref")
WORKERS = 7

MIDDLE = {"GUIFRMT", "GPB.HELP"}
SLOWEST = ["GPBMODS", "RGM", "GPB.HELP", "GUIFRMT"]


def jobs_for(mode, only):
    """The jobs of a run, slowest first: (kind, entry, stripped)."""
    jobs = []
    for entry in dcref.PROGRAMS:
        name, _ = dcref.split(entry)
        if only is not None and entry not in only and name not in only:
            continue
        if mode == "quick" and name == "RGM":
            continue
        jobs.append(("off", entry, False))
        if mode == "ref":
            jobs.append(("on", entry, False))
        elif mode == "full" or (name not in MIDDLE and name != "GPBMODS"):
            jobs.append(("on", entry, True))
        elif name == "GPBMODS":
            jobs.append(("on", entry, False))
    if mode != "ref":
        for name in dctest.EXPECT:
            if only is None or name in only:
                jobs.append(("dctest", name, False))
        for entry in dcstrip.TESTS:
            if only is None or entry in only or dcref.split(entry)[0] in only:
                jobs.append(("dcstrip", entry, False))

    def rank(job):
        kind, entry, _ = job
        name, _ = dcref.split(entry)
        slow = SLOWEST.index(name) if name in SLOWEST else len(SLOWEST)
        return (kind in ("dctest", "dcstrip"), slow, kind != "on")
    return sorted(jobs, key=rank)


def store(kind, entry, verdict, drive):
    name, _ = dcref.split(entry)
    dest = os.path.join(REF, kind, dcref.tag(entry))
    shutil.rmtree(dest, ignore_errors=True)
    os.makedirs(dest)
    for f in dcref.outputs(drive, name) + ["CMP.LOG"]:
        shutil.copy2(os.path.join(drive, f), dest)
    open(os.path.join(dest, "VERDICT"), "w").write(verdict + "\n")
    if verdict.startswith("OK CODE"):
        return True, "stored"
    return False, "stored, DID NOT COMPILE"


def against(kind, entry, verdict, drive):
    name, _ = dcref.split(entry)
    ref = os.path.join(REF, kind, dcref.tag(entry))
    if not os.path.isdir(ref):
        return False, "NO REFERENCE"
    diffs = []
    if not verdict.startswith("OK CODE"):
        diffs.append("did not compile")
    was = open(os.path.join(ref, "VERDICT")).read().strip()
    if was != verdict:
        diffs.append("verdict was [%s]" % was)
    want = set(dcref.outputs(ref, name))
    have = set(dcref.outputs(drive, name))
    for f in sorted(want | have):
        if f not in have or f not in want:
            diffs.append(f + (" missing" if f not in have else " extra"))
        elif not filecmp.cmp(os.path.join(ref, f), os.path.join(drive, f), shallow=False):
            diffs.append(f + " differs")
    if diffs:
        return False, "DIFFERENT: " + ", ".join(diffs)
    return True, "identical"


def settle(mode, kind, entry, verdict, drive):
    return store(kind, entry, verdict, drive) if mode == "ref" else against(kind, entry, verdict, drive)


def off_job(mode, entry, gpc, inputs):
    _, verdict, secs, drive = dcref.compile_one(entry, gpc, inputs, False, run=os.path.join(WORK, "off"))
    ok, note = settle(mode, "off", entry, verdict, drive)
    return [("off", dcref.tag(entry), secs, verdict, ok, note)], (verdict, drive)


def on_job(mode, entry, gpc, inputs, stripped):
    """The on check, and the stripped check after it. The second value is the on compile when
    D.NAME is empty, left for the off compile to check against."""
    name, _ = dcref.split(entry)
    t = dcref.tag(entry)
    _, v_on, secs, d_on = dcref.compile_one(entry, gpc, inputs, True, run=os.path.join(WORK, "on"))
    ok, note = settle(mode, "on", entry, v_on, d_on)
    checks = [("on", t, secs, v_on, ok, note)]
    if not stripped:
        return checks, None

    def fail(why):
        checks.append(("stripped", t, 0, "", False, why))
        return checks, None

    if not v_on.startswith("OK CODE"):
        return fail("not run: option on did not compile")
    listed = os.path.join(d_on, "D." + name)
    if not os.path.exists(listed):
        return fail("no D." + name)
    removed = [int(n) for n in open(listed).read().split()]
    if len(set(removed)) != len(removed):
        return fail("the list names a line twice")
    if not removed:
        return checks, (v_on, d_on)

    source = os.path.join(WORK, "in-stripped", t)
    shutil.rmtree(source, ignore_errors=True)
    os.makedirs(source)
    for f in glob.glob(os.path.join(inputs, "*.BIN")):
        shutil.copy2(f, source)
    sym = os.path.join(inputs, name + ".SRC.SYM")
    if os.path.exists(sym):
        shutil.copy2(sym, source)
    missing = dcstrip.strip(os.path.join(inputs, name + ".SRC.PRG"),
                            os.path.join(source, name + ".SRC.PRG"), removed)
    if missing:
        return fail("listed lines not in the source: %s" % missing[:8])

    _, v_off, secs, d_off = dcref.compile_one(entry, gpc, source, False,
                                              run=os.path.join(WORK, "stripped"))
    if not v_off.startswith("OK CODE"):
        return fail("stripped, option off: " + v_off)
    note = dcstrip.identity(name, removed, v_on, d_on, v_off, d_off)
    checks.append(("stripped", t, secs, v_off, note.startswith("identical"), note))
    return checks, None


def dctest_job(name, gpc):
    started = time.time()
    verdict, problems = dctest.check(name, gpc)
    return [("dctest", name, time.time() - started, verdict, not problems,
             "ok" if not problems else "; ".join(problems))], None


def dcstrip_job(entry, gpc):
    _, secs, _, note = dcstrip.one(entry, gpc)
    return [("dcstrip", dcref.tag(entry), secs, "", note.startswith("identical"), note)], None


def run(job, mode, gpc, inputs):
    kind, entry, stripped = job
    try:
        if kind == "off":
            return off_job(mode, entry, gpc, inputs)
        if kind == "on":
            return on_job(mode, entry, gpc, inputs, stripped)
        if kind == "dctest":
            return dctest_job(entry, gpc)
        return dcstrip_job(entry, gpc)
    except Exception:
        why = traceback.format_exc().strip().splitlines()[-1]
        return [(kind, dcref.tag(entry), 0, "", False, "EXCEPTION: " + why)], None


def show(check):
    kind, t, secs, verdict, ok, note = check
    print("  %-8s %-11s %5.0fs  %-44s %s" % (kind, t, secs, verdict[:44], note))
    sys.stdout.flush()
    return not ok


def main():
    args = sys.argv[1:]
    if not args or args[0] not in ("ref", "quick", "full"):
        sys.exit("usage: gpctest.py ref|quick|full [--gpc FILE] [--only A,B]")
    mode = args.pop(0)
    gpc = os.path.join(dcref.ROOT, "source", "application", "GPC.BIN")
    only = None
    while args:
        a = args.pop(0)
        if a == "--gpc":
            gpc = os.path.abspath(args.pop(0))
        elif a == "--only":
            only = set(args.pop(0).split(","))
        else:
            sys.exit("unknown argument " + a)

    inputs = dcref.snapshot()
    jobs = jobs_for(mode, only)
    print("%s: %d jobs on %d workers with %s (%d bytes)" % (mode, len(jobs), WORKERS, gpc,
                                                            os.path.getsize(gpc)))
    sys.stdout.flush()

    started = time.time()
    failed = 0
    offs, pending = {}, {}
    with ThreadPoolExecutor(WORKERS) as pool:
        futures = {pool.submit(run, job, mode, gpc, inputs): job for job in jobs}
        for future in as_completed(futures):
            kind, entry, _ = futures[future]
            checks, kept = future.result()
            if kind == "off":
                offs[entry] = kept
            elif kept is not None:
                pending[entry] = kept
            for check in checks:
                failed += show(check)

    for entry, (v_on, d_on) in pending.items():
        name, _ = dcref.split(entry)
        if entry not in offs:
            failed += show(("stripped", dcref.tag(entry), 0, "", False, "nothing removed, no off compile"))
            continue
        v_off, d_off = offs[entry]
        note = dcstrip.identity(name, [], v_on, d_on, v_off, d_off)
        failed += show(("stripped", dcref.tag(entry), 0, v_off, note.startswith("identical"),
                        note + ", against the off compile"))

    print("%s in %.0f s" % ("PASS" if failed == 0 else "%d FAILED" % failed, time.time() - started))
    sys.exit(0 if failed == 0 else 1)


if __name__ == "__main__":
    main()
