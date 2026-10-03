"""Time MSEDIT on the spike's paths. This is the baseline the GP.BASIC benches are held to.

    python msedit_bench.py               both configurations
    python msedit_bench.py plain         syntax colouring off
    python msedit_bench.py syntax        syntax colouring on

MSEDIT's repository is not touched. Its sources are copied to source/scratch/msedit-bench,
MSBENCH.P8 is pasted into the copy of edit.p8, and the copy is built with MSEDIT's own
prog8c.jar. The emulator runs headless and without -warp, because the driver reads the
jiffy clock.

The line-number gutter is on in both configurations, as it is in the GP.BASIC benches.
"""

import os
import shutil
import struct
import subprocess
import sys
import time

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
MSEDIT = os.path.abspath(os.path.join(ROOT, "..", "x16-MSEDIT"))
WORK = os.path.join(ROOT, "source", "scratch", "msedit-bench")
EMU = os.path.join(ROOT, "bin", "x16emu", "x16emu.exe")
ROM = os.path.join(ROOT, "bin", "x16emu", "rom.bin")
JAVA_BIN = r"C:\dev\b4x\java19\bin"
TASS_BIN = r"C:\8bitProgramming\64tass-1.60"
OVERLAYS = ["misc", "tview", "picker", "menus"]
FIXTURE = "FIX2000.TXT"
RUN_TIMEOUT = 600
KEY_LOOP = "        g_running = true\n        while g_running {"
# MSEDIT fills low RAM to within 1 KB of $9F00, and the driver does not fit beside it. These
# routines lose their bodies in the copy. No timed path reaches them.
EMPTIED = ["    sub act_replace() {", "    sub comment_apply(ubyte mode) {"]
RESULT_NAMES = [
    "LOAD.JIFFIES", "LINES",
    "MOVE.JIFFIES", "SCROLL.JIFFIES", "SCROLL.LINE",
    "PAGE.DOWN.JIFFIES", "PAGE.DOWN.LINE", "PAGE.UP.JIFFIES", "PAGE.UP.LINE",
    "TYPE.JIFFIES", "TYPE.LENGTH",
    "RETURN.JIFFIES", "RETURN.LINES", "DELETE.JIFFIES", "DELETE.LINES",
    "SAVE.JIFFIES", "FIND.JIFFIES", "FIND.LINE",
]
# keys a path: the divisor that turns a path's jiffies into jiffies a key
KEYS = {
    "MOVE.JIFFIES": 27, "SCROLL.JIFFIES": 300, "PAGE.DOWN.JIFFIES": 60, "PAGE.UP.JIFFIES": 60,
    "TYPE.JIFFIES": 200, "RETURN.JIFFIES": 50, "DELETE.JIFFIES": 50,
}


def prog8(source, log_name):
    """Compile one Prog8 source of the copy into WORK/build."""
    env = dict(os.environ)
    env["PATH"] = JAVA_BIN + os.pathsep + TASS_BIN + os.pathsep + env["PATH"]
    build = os.path.join(WORK, "build")
    with open(os.path.join(WORK, log_name), "wb") as log:
        result = subprocess.run(
            ["java", "-jar", os.path.join(MSEDIT, "prog8c.jar"), "-target", "cx16",
             "-out", build, os.path.join(WORK, "SRC", source)],
            stdout=log, stderr=subprocess.STDOUT, env=env)
    if result.returncode != 0:
        tail = open(os.path.join(WORK, log_name), "rb").read()[-1500:]
        sys.exit("msedit_bench: %s did not build:\n%s" % (source, tail.decode("latin-1", "replace")))


def copy_sources():
    source = os.path.join(WORK, "SRC")
    if os.path.exists(source):
        shutil.rmtree(source)
    os.makedirs(source)
    for name in os.listdir(os.path.join(MSEDIT, "SRC")):
        if name.endswith(".p8"):
            shutil.copy(os.path.join(MSEDIT, "SRC", name), source)
    os.makedirs(os.path.join(WORK, "build"), exist_ok=True)


def inject(syntax_on):
    """Paste the driver into the copy of edit.p8 and call it ahead of the key loop."""
    pristine = open(os.path.join(MSEDIT, "SRC", "edit.p8"), "r", encoding="latin-1", newline="").read()
    text = pristine.replace("\r\n", "\n")
    driver = open(os.path.join(HERE, "MSBENCH.P8"), "r", encoding="latin-1").read()
    driver = driver.replace("@HL@", "true" if syntax_on else "false")
    if text.count(KEY_LOOP) != 1:
        sys.exit("msedit_bench: the key loop of edit.p8 is not where the driver expects it")
    text = text.replace(KEY_LOOP, "        bench_run()\n" + KEY_LOOP)
    for header in EMPTIED:
        start = text.find(header)
        end = text.find("\n    }\n", start)
        if start < 0 or end < 0:
            sys.exit("msedit_bench: cannot find %s" % header.strip())
        text = text[:start] + header + text[end:]
    closing = text.rstrip().rfind("}")
    text = text[:closing] + driver + "}\n"
    with open(os.path.join(WORK, "SRC", "edit.p8"), "w", encoding="latin-1", newline="\n") as f:
        f.write(text)


def stage():
    """Lay the built program out the way MSEDIT's run.bat does, with the fixture at the root."""
    run_dir = os.path.join(WORK, "run")
    if os.path.exists(run_dir):
        shutil.rmtree(run_dir)
    program = os.path.join(run_dir, "MSEDIT")
    os.makedirs(program)
    build = os.path.join(WORK, "build")
    shutil.copy(os.path.join(build, "edit.prg"), os.path.join(program, "EDIT.PRG"))
    for name in OVERLAYS:
        shutil.copy(os.path.join(build, name + ".ovl"), os.path.join(program, name.upper() + ".OVL"))
    shutil.copy(os.path.join(HERE, FIXTURE), os.path.join(run_dir, FIXTURE))
    # The root launcher MSEDIT reads its install folder from: 10 LOAD"/MSEDIT/EDIT.PRG"
    with open(os.path.join(run_dir, "ED"), "wb") as f:
        f.write(bytes([1, 8, 25, 8, 10, 0, 147, 34]) + b"/MSEDIT/EDIT.PRG" + bytes([34, 0, 0, 0]))
    return run_dir


def run(run_dir):
    result = os.path.join(run_dir, "MSBENCH.RES")
    env = dict(os.environ)
    env["SDL_VIDEODRIVER"] = "dummy"
    emulator = subprocess.Popen(
        [EMU, "-rom", ROM, "-fsroot", run_dir, "-sound", "none",
         "-prg", os.path.join(run_dir, "MSEDIT", "EDIT.PRG"), "-run"],
        cwd=run_dir, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, env=env)
    written = b""
    try:
        deadline = time.time() + RUN_TIMEOUT
        while time.time() < deadline:
            time.sleep(0.5)
            # The file is locked while the driver still has it open for writing.
            try:
                with open(result, "rb") as f:
                    written = f.read()
            except OSError:
                continue
            if len(written) >= 2 * len(RESULT_NAMES):
                break
    finally:
        emulator.kill()
        try:
            emulator.wait(timeout=5)
        except subprocess.TimeoutExpired:
            pass
    if len(written) < 2 * len(RESULT_NAMES):
        sys.exit("msedit_bench: no MSBENCH.RES within %ds" % RUN_TIMEOUT)
    return struct.unpack("<%dH" % len(RESULT_NAMES), written[:2 * len(RESULT_NAMES)])


def saved_file_differences(run_dir):
    """Count the lines of the saved document that differ from the fixture.

    The driver types 40 characters into each of lines 101 to 105, so five lines differ.
    """
    fixture = open(os.path.join(HERE, FIXTURE), "rb").read().split(b"\r\n")
    saved = open(os.path.join(run_dir, "MSBENCH.OUT"), "rb").read().split(b"\r\n")
    differing = sum(1 for a, b in zip(fixture, saved) if a != b)
    return differing + abs(len(fixture) - len(saved))


def report(label, values, differing):
    print("MSEDIT, %s" % label)
    for name, value in zip(RESULT_NAMES, values):
        if name in KEYS:
            print("  %-18s %5d   %.2f a key" % (name, value, value / KEYS[name]))
        else:
            print("  %-18s %5d" % (name, value))
    print("  %-18s %5d" % ("SAVED.LINES.DIFFER", differing))


def main():
    wanted = sys.argv[1:] or ["plain", "syntax"]
    copy_sources()
    for name in OVERLAYS:
        prog8(name + ".p8", name + ".log")
        shutil.move(os.path.join(WORK, "build", name + ".bin"), os.path.join(WORK, "build", name + ".ovl"))
    for label in wanted:
        inject(label == "syntax")
        prog8("edit.p8", "edit.log")
        run_dir = stage()
        values = run(run_dir)
        report(label, values, saved_file_differences(run_dir))


main()
