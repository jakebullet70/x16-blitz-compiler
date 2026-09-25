# -*- coding: utf-8 -*-
#
#   The reference set for compiler changes that must not change an object.
#
#       dcref.py ref  [--gpc FILE] [--only A,B] [--dead]     compile the set, keep the result
#       dcref.py chk  [--gpc FILE] [--only A,B] [--dead]     compile it again and diff
#
#   Every program is compiled from a FIXED tokenised input: the .SRC.PRG and .SRC.SYM are
#   copied out of drive/ once, into work/dcref/inputs/, and never again. Only the compiler
#   changes between a ref and a chk, so a difference is the compiler's.
#
#   Each compile runs in a drive of its own under work/dcref/run/. drive/ is shared with
#   other sessions, and one of them rewriting GPC.INPUT between the write and the read has
#   already built the wrong program twice.
#
#   GPC.INPUT is written with FIVE lines, the fifth empty unless --dead names a removed-line
#   list. A four-line engine stops reading at line four, so the same file serves both.
#
import os, shutil, subprocess, sys, time, glob, filecmp
from concurrent.futures import ThreadPoolExecutor

ROOT = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
TESTING = os.path.join(ROOT, "drive")
WORK = os.path.join(ROOT, "work", "dcref")
EMUDIR = os.path.join(ROOT, "bin", "x16emu")
EMU = os.path.join(EMUDIR, "x16emu.exe")
ROM = os.path.join(EMUDIR, "rom.bin")

#   NAME compiles SHARED, NAME:E compiles EMBEDDED.
PROGRAMS = [
    "GPCTEST", "GPCTEST:E", "RGN", "GPC", "FORMEXP", "MENUDEMO",
    "MENUTST", "COLORTST", "MENUEXP", "RGT", "GUI2TST", "GUIEXP", "GPB.HELP",
    "RGM", "RGL", "GPBMODS",
]

TIMEOUT = 2400                      # three passes when --dead: GPBMODS took 509 s under four workers
WORKERS = 6


def split(entry):
    name, _, mode = entry.partition(":")
    return name, mode != "E"


def tag(entry):
    name, shared = split(entry)
    return name if shared else name + "-E"


def snapshot():
    inputs = os.path.join(WORK, "inputs")
    os.makedirs(inputs, exist_ok=True)
    for entry in PROGRAMS:
        name, _ = split(entry)
        for ext in (".SRC.PRG", ".SRC.SYM"):
            src = os.path.join(TESTING, name + ext)
            dst = os.path.join(inputs, name + ext)
            if os.path.exists(src) and not os.path.exists(dst):
                shutil.copy2(src, dst)
    for pattern in ("GPC.IMG.*.BIN", "GP1.IMG.*.BIN",
                    "GPB.RT.*.BIN", "GPC.RT.*.BIN", "GP1.RT.*.BIN"):
        for f in glob.glob(os.path.join(TESTING, pattern)):
            dst = os.path.join(inputs, os.path.basename(f))
            if not os.path.exists(dst):
                shutil.copy2(f, dst)
    return inputs


def compile_one(entry, gpc, inputs, dead, run="run"):
    name, shared = split(entry)
    drive = os.path.join(WORK, run, tag(entry))
    shutil.rmtree(drive, ignore_errors=True)
    os.makedirs(drive)
    shutil.copy2(gpc, os.path.join(drive, "GPC.BIN"))
    for f in os.listdir(inputs):
        if f.endswith(".BIN") or f.startswith(name + ".SRC."):
            shutil.copy2(os.path.join(inputs, f), drive)

    lines = [name + ".SRC.PRG", name + ".PRG", name + ".MAP", "SHARED" if shared else "",
             ("D." + name) if dead else ""]
    open(os.path.join(drive, "GPC.INPUT"), "w", newline="\n").write("\n".join(lines) + "\n")

    env = dict(os.environ)
    env["SDL_VIDEODRIVER"] = "dummy"
    logpath = os.path.join(drive, "CMP.LOG")
    started = time.time()
    verdict = "TIMEOUT"
    with open(logpath, "wb") as log:
        p = subprocess.Popen([EMU, "-rom", ROM, "-fsroot", ".", "-warp", "-sound", "none",
                              "-echo", "raw", "-prg", "GPC.BIN", "-run"],
                             cwd=drive, stdout=log, stderr=subprocess.STDOUT, env=env)
        try:
            deadline = time.time() + TIMEOUT
            while time.time() < deadline:
                time.sleep(0.5)
                echo = open(logpath, "rb").read()
                ok = echo.rfind(b"OK LOW CODE")
                if ok >= 0:
                    settle = time.time() + 20
                    while time.time() < settle and b"READY." not in open(logpath, "rb").read()[ok:]:
                        time.sleep(0.5)
                    time.sleep(1.0)
                    echo = open(logpath, "rb").read()
                    lines = echo[ok:].decode("latin-1").replace("\r", "\n").split("\n")
                    lines = [s.strip() for s in lines if s.strip()]
                    verdict = lines[0]
                    dead = [s for s in lines[1:] if s.startswith("DEAD CODE:")]
                    if dead:
                        verdict += " " + dead[0]
                    break
                at = echo.find(b"GPC SQUEALING")
                if at >= 0 and b"READY." in echo[at:]:
                    body = echo[at:echo.index(b"READY.", at)].decode("latin-1")
                    body = [s.strip() for s in body.replace("\r", "\n").split("\n") if s.strip()]
                    verdict = "STOPPED: " + " | ".join(body[-3:])
                    break
        finally:
            p.kill()
            try:
                p.wait(timeout=5)
            except subprocess.TimeoutExpired:
                pass
    return entry, verdict, time.time() - started, drive


def outputs(drive, name):
    found = []
    for f in sorted(os.listdir(drive)):
        if f in (name + ".PRG", name + ".MAP", name + ".OVL", "D." + name):
            found.append(f)
    return found


def main():
    args = sys.argv[1:]
    if not args or args[0] not in ("ref", "chk"):
        sys.exit(__doc__ or "usage: dcref.py ref|chk [--gpc FILE] [--only A,B] [--dead]")
    mode = args.pop(0)
    gpc = os.path.join(ROOT, "source", "application", "GPC.BIN")
    only = None
    dead = False
    while args:
        a = args.pop(0)
        if a == "--gpc":
            gpc = os.path.abspath(args.pop(0))
        elif a == "--only":
            only = set(args.pop(0).split(","))
        elif a == "--dead":
            dead = True
        else:
            sys.exit("unknown argument " + a)

    inputs = snapshot()
    entries = [e for e in PROGRAMS if only is None or e in only or split(e)[0] in only]
    store = os.path.join(WORK, mode)
    os.makedirs(store, exist_ok=True)
    print("%s: %d compiles with %s (%d bytes)%s" % (mode, len(entries), gpc, os.path.getsize(gpc),
                                                  ", option on" if dead else ""))

    failed = 0
    with ThreadPoolExecutor(WORKERS) as pool:
        for entry, verdict, secs, drive in pool.map(lambda e: compile_one(e, gpc, inputs, dead),
                                                    entries):
            name, _ = split(entry)
            dest = os.path.join(store, tag(entry))
            shutil.rmtree(dest, ignore_errors=True)
            os.makedirs(dest)
            for f in outputs(drive, name):
                shutil.copy2(os.path.join(drive, f), dest)
            shutil.copy2(os.path.join(drive, "CMP.LOG"), dest)
            open(os.path.join(dest, "VERDICT"), "w").write(verdict + "\n")

            note = ""
            if mode == "chk":
                ref = os.path.join(WORK, "ref", tag(entry))
                if not os.path.isdir(ref):
                    note = "NO REFERENCE"
                    failed += 1
                else:
                    diffs = []
                    rv = open(os.path.join(ref, "VERDICT")).read().strip()
                    if rv != verdict and not dead:
                        diffs.append("verdict was [%s]" % rv)
                    want = set(outputs(ref, name)) - {"D." + name}
                    have = set(outputs(dest, name)) - {"D." + name}
                    for f in sorted(want | have):
                        if f not in have or f not in want:
                            diffs.append(f + (" missing" if f not in have else " extra"))
                        elif not filecmp.cmp(os.path.join(ref, f), os.path.join(dest, f),
                                             shallow=False):
                            diffs.append(f + " differs")
                    note = "identical" if not diffs else "DIFFERENT: " + ", ".join(diffs)
                    failed += bool(diffs)
            print("  %-11s %5.0fs  %-44s %s" % (tag(entry), secs, verdict[:44], note))
            sys.stdout.flush()

    if mode == "chk":
        print("PASS" if failed == 0 else "%d DIFFERENT" % failed)


if __name__ == "__main__":
    main()
