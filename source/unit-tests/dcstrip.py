# -*- coding: utf-8 -*-
#
#   Dead-code removal, the identity (docs/blitz/DEAD-CODE-ELIMINATION.PLAN.md, section 5.1).
#
#       dcstrip.py [--gpc FILE] [--only A,B]
#
#   For each program:
#
#       1. compile it with the option on, giving object A and the removed-line list L
#       2. delete L's lines from the tokenised source and relink it
#       3. compile the stripped source with the option off, giving object B
#
#   A and B must be byte-identical, and so must the map and the .OVL overlay. The OK line
#   must match too, bar A's DEAD figures, and DEAD's line count must be the length of L.
#   Identical objects run identically, so neither is run.
#
#   The programs are dcref.py's set, compiled from its fixed inputs, and the deadcode-tests/
#   programs dctest.py builds. DC6 and DC9-DC11 are not here: they stop on purpose.
#
#   Work: work/dcstrip/<tag>/, with in-on/ and in-off/ as the two input sets and on/ and off/
#   as the two drives.
#
import os, re, shutil, sys, glob, filecmp, time
from concurrent.futures import ThreadPoolExecutor, as_completed

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import dcref
import dctest

WORK = os.path.join(dcref.ROOT, "work", "dcstrip")
TESTS = ["DC1:E", "DC2:E", "DC3:E", "DC4", "DC5:E", "DC7", "DC8:E", "DC12:E"]


def strip(src, dst, removed):
    """Write src without the lines numbered in removed. Returns the numbers not found."""
    data = open(src, "rb").read()
    load = data[0] | data[1] << 8
    body = data[2:]
    want = set(removed)
    kept, found, i = [], set(), 0
    while not (body[i] == 0 and body[i + 1] == 0):
        num = body[i + 2] | body[i + 3] << 8
        end = body.index(0, i + 4)
        if num in want:
            found.add(num)
        else:
            kept.append(body[i + 2:end + 1])
        i = end + 1
    out = bytearray(data[:2])
    addr = load
    for line in kept:
        addr = (addr + 2 + len(line)) & 0xFFFF  # a big program's links wrap past $FFFF
        out += bytes([addr & 0xFF, addr >> 8]) + line
    out += body[i:]
    open(dst, "wb").write(out)
    return sorted(want - found)


def one(entry, gpc):
    name, _ = dcref.split(entry)
    tag = dcref.tag(entry)
    base = os.path.join(WORK, tag)
    shutil.rmtree(base, ignore_errors=True)
    in_on = os.path.join(base, "in-on")
    in_off = os.path.join(base, "in-off")
    os.makedirs(in_on)
    os.makedirs(in_off)
    for f in glob.glob(os.path.join(dcref.WORK, "inputs", "*.BIN")):
        shutil.copy2(f, in_on)
        shutil.copy2(f, in_off)
    if name.startswith("DC"):
        problem = dctest.make_source(name, in_on)
        if problem:
            return entry, 0, None, problem
    else:
        for ext in (".SRC.PRG", ".SRC.SYM"):
            f = os.path.join(dcref.WORK, "inputs", name + ext)
            if os.path.exists(f):
                shutil.copy2(f, in_on)
    sym = os.path.join(in_on, name + ".SRC.SYM")
    if os.path.exists(sym):
        shutil.copy2(sym, in_off)

    started = time.time()
    _, v_on, _, d_on = dcref.compile_one(entry, gpc, in_on, True, run=os.path.join(base, "on"))
    if not v_on.startswith("OK LOW CODE"):
        return entry, time.time() - started, None, "option on: " + v_on
    listed = os.path.join(d_on, "D." + name)
    if not os.path.exists(listed):
        return entry, time.time() - started, None, "no D." + name
    removed = [int(n) for n in open(listed).read().split()]
    if len(set(removed)) != len(removed):
        return entry, time.time() - started, removed, "the list names a line twice"
    missing = strip(os.path.join(in_on, name + ".SRC.PRG"), os.path.join(in_off, name + ".SRC.PRG"),
                    removed)
    if missing:
        return entry, time.time() - started, removed, "listed lines not in the source: %s" % missing[:8]

    _, v_off, _, d_off = dcref.compile_one(entry, gpc, in_off, False, run=os.path.join(base, "off"))
    if not v_off.startswith("OK LOW CODE"):
        return entry, time.time() - started, removed, "stripped, option off: " + v_off
    return entry, time.time() - started, removed, identity(name, removed, v_on, d_on, v_off, d_off)


def identity(name, removed, v_on, d_on, v_off, d_off):
    """The option-on compile against the stripped option-off compile. 'identical, ...' or 'DIFFERENT: ...'."""
    diffs = []
    m = re.match(r"(.*) DEAD CODE: +([0-9]+) LINES REMOVED, +([0-9]+) BYTES SAVED$", v_on)
    if not m:
        diffs.append("no DEAD figures in [%s]" % v_on)
    else:
        if m.group(1) != v_off:
            diffs.append("OK line [%s] against [%s]" % (m.group(1), v_off))
        if int(m.group(2)) != len(removed):
            diffs.append("DEAD says %s lines, the list has %d" % (m.group(2), len(removed)))
    have_on = set(dcref.outputs(d_on, name)) - {"D." + name}
    have_off = set(dcref.outputs(d_off, name))
    for f in sorted(have_on | have_off):
        if f not in have_on or f not in have_off:
            diffs.append(f + (" only with the option on" if f in have_on else " only stripped"))
        elif not filecmp.cmp(os.path.join(d_on, f), os.path.join(d_off, f), shallow=False):
            diffs.append(f + " differs")
    if m and not diffs:
        return "identical, DEAD %s %s" % (m.group(2), m.group(3))
    return "DIFFERENT: " + "; ".join(diffs)


def main():
    args = sys.argv[1:]
    gpc = os.path.join(dcref.ROOT, "source", "application", "GPC.BIN")
    only = None
    while args:
        a = args.pop(0)
        if a == "--gpc":
            gpc = os.path.abspath(args.pop(0))
        elif a == "--only":
            only = set(args.pop(0).split(","))
        else:
            sys.exit("usage: dcstrip.py [--gpc FILE] [--only A,B]")

    entries = TESTS + list(reversed(dcref.PROGRAMS))
    if only is not None:
        entries = [e for e in entries if e in only or dcref.split(e)[0] in only]
    print("dcstrip: %d programs with %s (%d bytes)" % (len(entries), gpc, os.path.getsize(gpc)))
    sys.stdout.flush()

    failed = 0
    with ThreadPoolExecutor(dcref.WORKERS) as pool:
        jobs = [pool.submit(one, e, gpc) for e in entries]
        for job in as_completed(jobs):
            entry, secs, removed, note = job.result()
            failed += not note.startswith("identical")
            print("  %-11s %5.0fs  %s" % (dcref.tag(entry), secs, note))
            sys.stdout.flush()
    print("PASS" if failed == 0 else "%d FAILED" % failed)


if __name__ == "__main__":
    main()
