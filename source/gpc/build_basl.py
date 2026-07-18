# ************************************************************************************************
# ************************************************************************************************
#
#		Name:		build_basl.py
#		Purpose:	Build testing/GPC.PRG from testing/GPC.BASL by running BASLOAD headless.
#				With args "BASL PRG" it instead tokenises that one extra tool the same way
#				(no version bump, no source mirror) -- used to freshen GPC.ERR.PRG on a release.
#
# ************************************************************************************************
# ************************************************************************************************
#
#		The GPC front end is written in BASLOAD source (GPC.BASL). BASLOAD is an X16 ROM utility,
#		so there is no host-side tokeniser for it: we tokenise by booting the bundled emulator,
#		"typing"  BASLOAD "GPC.BASL"  at the BASIC prompt, and letting the source's own
#		  #SAVEAS "@:GPC.PRG"  option write the tokenised program to the drive. This replaces the
#		old Prog8/Java build of GPC.PRG (now in source/gpc/old-archive/).
#
#		DIRECTION: the MASTER copy is testing/GPC.BASL -- that is where the front end is edited
#		and interactively BASLOAD-tested (testing/ is the emulator's drive). This build tokenises
#		it IN PLACE and, on success, mirrors it back into the source tree (source/gpc/GPC.BASL)
#		so the committed copy always matches what was last built. On a fresh checkout with no
#		testing/GPC.BASL, the committed mirror is used to seed it.
#
#		BUILD NUMBER: every front-end build first bumps  VERSION$ = "0.9.<n>" -> "0.9.<n+1>"  in
#		the master, so the banner always shows the exact build you are on. It is a daily-work
#		counter tracked in testing/ (mirrored to source/), NOT the release version.
#
#		EXTRA TOOLS: run  build_basl.py GPC.ERR.BASL GPC.ERR.PRG  to tokenise a companion tool the
#		same headless way. These live only in testing/ (no source/ mirror) and carry no VERSION$,
#		so this mode just tokenises -- no bump, no mirror. It skips when the source is absent, and
#		when the PRG is already up to date (BASLOAD writes 2 nondeterministic trailing bytes past
#		the program's end marker, so re-tokenising an unchanged source would only churn those). The
#		Makefile's "release" target uses it to freshen GPC.ERR.PRG when its source has changed.
#
#		Headless, exactly like the other emulator-driven steps in this tree (see
#		source/unit-tests/shared-runtime/shared_test.py): SDL_VIDEODRIVER=dummy so the emulator
#		never steals the desktop's keyboard focus, and it is killed by PID -- NEVER by image name,
#		because other projects on this box run x16emu too.
#
# ************************************************************************************************

import os, re, sys, time, subprocess

HERE    = os.path.dirname(os.path.abspath(__file__))
ROOT    = os.path.abspath(os.path.join(HERE, "..", ".."))
TESTING = os.path.join(ROOT, "testing")
EMU     = os.path.join(ROOT, "bin", "x16emu", "x16emu.exe")
ROM     = os.path.join(ROOT, "bin", "x16emu", "rom.bin")

MASTER = os.path.join(TESTING, "GPC.BASL")  # the master you edit + interactively BASLOAD-test
MIRROR = os.path.join(HERE, "GPC.BASL")     # committed mirror in the source tree, kept in sync
BASL   = "GPC.BASL"                          # its name on the emulator drive (= testing/)
PRG    = "GPC.PRG"                           # #SAVEAS "@:GPC.PRG" writes this
SYM    = "GPC.SYM"                           # #SYMFILE "@:GPC.SYM" writes this
DRIVER = "GPCBLD.BAS"                        # scratch: the one line we "type" at BASIC
LOG    = "GPCBLD.LOG"                        # scratch: the emulator echo log


def die(msg):
    print("  build_basl: FAIL -- " + msg)
    sys.exit(1)


def bump_version(path):
    """Increment the last dotted component of  VERSION$ = "a.b.n"  in the BASL master, in place,
    preserving the rest of the line and the file's exact line endings. Returns the new version.
    This is the daily-work build counter (tracked in testing/), NOT the release version."""
    with open(path, "r", encoding="utf-8", newline="") as f:
        text = f.read()
    m = re.search(r'(VERSION\$\s*=\s*")([0-9]+(?:\.[0-9]+)*)(")', text)
    if not m:
        die('cannot find  VERSION$ = "..."  in %s -- cannot bump the build number' % path)
    parts = m.group(2).split(".")
    if not parts[-1].isdigit():
        die('VERSION$ = "%s": last component is not numeric -- cannot bump' % m.group(2))
    parts[-1] = str(int(parts[-1]) + 1)
    newver = ".".join(parts)
    text = text[:m.start(2)] + newver + text[m.end(2):]
    with open(path, "w", encoding="utf-8", newline="") as f:
        f.write(text)
    return newver


def tokenise(basl_name, prg_name, also_clean=()):
    """Boot the emulator headless and run  BASLOAD "<basl_name>"  so the source's own #SAVEAS
    writes testing/<prg_name>. Returns the tokenised PRG's bytes; dies on failure. also_clean
    lists extra outputs (e.g. a #SYMFILE) to remove up front so a stale one can't fake success."""
    with open(os.path.join(TESTING, DRIVER), "w", newline="\n") as f:
        f.write('BASLOAD "%s"\n' % basl_name)

    # Start from a clean slate so we can poll for the freshly written file (#SAVEAS overwrites,
    # but we want to detect a NEW PRG, not mistake a stale one for success).
    for f in (prg_name,) + tuple(also_clean):
        p = os.path.join(TESTING, f)
        if os.path.exists(p):
            os.remove(p)

    env = dict(os.environ); env["SDL_VIDEODRIVER"] = "dummy"
    args = [EMU, "-rom", ROM, "-fsroot", ".", "-warp", "-pastewarp", "-echo", "-bas", DRIVER]
    logpath = os.path.join(TESTING, LOG)
    target  = os.path.join(TESTING, prg_name)

    lf = open(logpath, "wb")
    proc = subprocess.Popen(args, cwd=TESTING, stdout=lf, stderr=subprocess.STDOUT, env=env)
    ok = False
    try:
        deadline = time.time() + 30
        while time.time() < deadline:
            time.sleep(0.4)
            if os.path.exists(target) and os.path.getsize(target) > 0:
                s1 = os.path.getsize(target); time.sleep(0.4)
                if os.path.getsize(target) == s1:      # size stable -> save finished
                    ok = True
                    break
    finally:
        proc.kill()
        try: proc.wait(timeout=5)
        except subprocess.TimeoutExpired: pass
        lf.close()

    log = open(logpath, "rb").read()

    for f in (DRIVER, LOG):
        p = os.path.join(TESTING, f)
        if os.path.exists(p):
            try: os.remove(p)
            except OSError: pass

    if not ok:
        die("BASLOAD wrote no %s within 30s -- echo log tail:\n%s"
            % (prg_name, log[-400:].decode("latin-1", "replace")))

    data = open(target, "rb").read()
    if len(data) < 3 or data[0] != 0x01 or data[1] != 0x08:
        die("%s does not load at $0801 (first bytes %s)" % (prg_name, data[:2].hex()))
    return data


def build_front_end():
    """The GPC.BASL flow: seed the master from the mirror if missing, bump the build number,
    tokenise to GPC.PRG, then mirror the master back to source/gpc/GPC.BASL."""
    if not os.path.exists(MASTER):
        if not os.path.exists(MIRROR):
            die("no GPC.BASL in testing/ or source/gpc/ -- nothing to build")
        with open(MIRROR, "rb") as a, open(MASTER, "wb") as b:
            b.write(a.read())
        print("  build_basl: seeded testing/GPC.BASL from source/gpc/GPC.BASL")

    newver = bump_version(MASTER)
    print("  build_basl: bumped VERSION$ -> %s" % newver)

    data = tokenise(BASL, PRG, also_clean=(SYM,))

    # Mirror the master back into the source tree so the committed source/gpc/GPC.BASL always
    # matches what was last built. Only write when it actually changed (avoid mtime/git churn).
    master_bytes = open(MASTER, "rb").read()
    mirror_bytes = open(MIRROR, "rb").read() if os.path.exists(MIRROR) else None
    mirrored = master_bytes != mirror_bytes
    if mirrored:
        with open(MIRROR, "wb") as b:
            b.write(master_bytes)

    print("  build_basl: OK -- testing/%s (%d bytes, loads $0801) tokenised from testing/GPC.BASL"
          % (PRG, len(data)))
    if mirrored:
        print("             mirrored testing/GPC.BASL -> source/gpc/GPC.BASL")


def build_tool(basl_name, prg_name):
    """Tokenise a companion tool (e.g. GPC.ERR.BASL -> GPC.ERR.PRG) that lives only in testing/.
    No version bump, no source mirror. "If needed": skip when the source is absent, or when the
    PRG is already at least as new as its source. (BASLOAD writes 2 nondeterministic trailing
    bytes past the program's end marker, so re-tokenising an unchanged source only churns those.)"""
    basl = os.path.join(TESTING, basl_name)
    prg  = os.path.join(TESTING, prg_name)
    if not os.path.exists(basl):
        print("  build_basl: skip -- no testing/%s (nothing to tokenise for %s)" % (basl_name, prg_name))
        return
    if os.path.exists(prg) and os.path.getmtime(prg) >= os.path.getmtime(basl):
        print("  build_basl: skip -- testing/%s is up to date (source no newer)" % prg_name)
        return
    sym = os.path.splitext(prg_name)[0] + ".SYM"    # a #SYMFILE, if any, sits beside the PRG
    data = tokenise(basl_name, prg_name, also_clean=(sym,))
    print("  build_basl: OK -- testing/%s (%d bytes, loads $0801) tokenised from testing/%s"
          % (prg_name, len(data), basl_name))


def main():
    for f, what in ((EMU, "x16emu.exe"), (ROM, "rom.bin")):
        if not os.path.exists(f):
            die("missing %s (%s)" % (what, f))
    if len(sys.argv) >= 3:
        build_tool(sys.argv[1], sys.argv[2])
    else:
        build_front_end()
    sys.exit(0)


if __name__ == "__main__":
    main()
