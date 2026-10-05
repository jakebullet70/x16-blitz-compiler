"""Build one bench and run it at real speed.

    python spike.py SCROLLBEN            tokenise, compile, run, print SCROLLBEN.RES
    python spike.py SCROLLBEN colour     the same, with syntax colouring on
    python spike.py SCROLLBEN both       one build, then a run with colouring off and one on
    python spike.py SCROLLBEN --keep     leave the build and the run's files in this folder

The editor's modules are in the folder above. A BASLOAD #INCLUDE cannot name ../, so they
are copied here for the build. They are removed after the run, with everything the build
and the run wrote. Edit a module in the folder above, never the copy.

WARNING: after a run, clean() deletes every file in this folder whose name does not end in
one of KEPT. The endings are matched in the case KEPT gives them.

The bench writes NAME.RES and ends it with a DONE line. The run stops there.
BENCH.CFG holds 1 for a run with colouring on and 0 for a run with it off. BEN.CONFIG reads
it.
A bench that saves the document writes NAME.OUT. Its lines are compared with the fixture.
A bench that dumps its pane writes NAME.PANE. A bench that dumps the classes of every
line writes NAME.CLS. Both files are compared with the rules in tgkeys.py.
UNDOBEN also saves UNDOBEN.WRP, .NEW, .UND and .RED. Each is compared with the document
undo_bench_documents() returns for it.
KEYBEN reads its keys from KEYBEN.KEY, which keymodel.py writes. Its documents, its
cursor and its selection are compared with what keymodel.py makes of the same keys.
TURBOTEST is the editor itself, ../TURBO.BASL, with TURBOTEST-DRIVER.BASL typing the keys
of turbomodel.py into it. Its settings store is SETTINGS.KVB in this folder, and a run
starts with the store turbomodel.py gives. Its documents, its cursor, its pane, its two
bars and its store are compared with what turbomodel.py expects.
The emulator runs headless and without -warp. The benches read TI.
"""

import os
import shutil
import subprocess
import sys
import time

sys.dont_write_bytecode = True
HERE = os.path.dirname(os.path.abspath(__file__))
EDITOR = os.path.abspath(os.path.join(HERE, ".."))
sys.path.insert(0, EDITOR)

import keymodel
import tgkeys
import turbomodel

ROOT = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
SAMPLES = os.path.join(ROOT, "GPC-BASIC-TOOLS-SRC")
EMU = os.path.join(ROOT, "bin", "x16emu", "x16emu.exe")
ROM = os.path.join(ROOT, "bin", "x16emu", "rom.bin")
GPC = os.path.join(ROOT, "source", "gpc")
DRIVER = "SPIKERUN.BAS"
FIXTURE = "FIX2000.TXT"
CONFIG = "BENCH.CFG"
RUN_TIMEOUT = 300
MODULES = ["TG-STORE.BASL", "TG-FIND.BASL", "TG-UNDO.BASL", "TG-VIEW.BASL", "TG-CLIP.BASL", "TG-KEYS.BASL", "TG-LOW.BASL", "TGKEYS.BIN"]
LIBRARY = "GPC-BASIC"
# The name endings of the files this folder keeps. clean() deletes every other file in it.
KEPT = (".BASL", ".py", ".P8", ".TXT")
# The editor's source with the test driver in it. turbo_test_source() writes it.
TURBO_TEST = "TURBOTEST"
# TURBOTEST's settings store, and the layout of KVBIN.INC.BL's records.
SETTINGS = "SETTINGS.KVB"
STORE_RECORD = 128
STORE_KEY = 12


def step(script, *args):
    """Run a build script on this folder and stop on its failure."""
    result = subprocess.run([sys.executable, os.path.join(GPC, script), "--drive", HERE] + list(args))
    if result.returncode != 0:
        sys.exit("spike: %s failed" % script)


def stage(name):
    """Write TGKEYS.BIN in the editor's folder, then copy the editor's modules and its
    library folder into this folder. For TURBOTEST, write TURBOTEST.BASL as well."""
    tgkeys.write_table()
    if name == TURBO_TEST:
        turbo_test_source()
    for module in MODULES:
        shutil.copy(os.path.join(EDITOR, module), os.path.join(HERE, module))
    library = os.path.join(HERE, LIBRARY)
    if os.path.exists(library):
        shutil.rmtree(library)
    shutil.copytree(os.path.join(EDITOR, LIBRARY), library)


def clean():
    """Remove the staged modules and everything a build or a run wrote."""
    library = os.path.join(HERE, LIBRARY)
    if os.path.exists(library):
        shutil.rmtree(library)
    for name in os.listdir(HERE):
        path = os.path.join(HERE, name)
        if not os.path.isfile(path):
            continue
        if name in MODULES or name == TURBO_TEST + ".BASL" or not name.endswith(KEPT):
            os.remove(path)


def turbo_test_source():
    """Write TURBOTEST.BASL. It is the editor's source with its key wait and its exit
    handed to TURBOTEST-DRIVER.BASL, and its settings store in this folder.

    Each of the nine strings replaced must occur once in TURBO.BASL. The run stops when
    one does not. TURBO.BASL is read with its line endings made LF, so the strings ending
    in a newline match a CRLF copy too."""
    source = open(os.path.join(EDITOR, "TURBO.BASL"), "r", encoding="latin-1").read()
    changes = [
        ('#SAVEAS "@:TURBO.SRC.PRG"', '#SAVEAS "@:TURBOTEST.SRC.PRG"'),
        ('#SYMFILE "@:TURBO.SRC.SYM"', '#SYMFILE "@:TURBOTEST.SRC.SYM"'),
        ('#GPC OBJECT "TURBO.PRG"', '#GPC OBJECT "TURBOTEST.PRG"'),
        ('#GPC MAP "TURBO.MAP"', '#GPC MAP "TURBOTEST.MAP"'),
        ('#GPC DEADLIST "TURBO.DEAD"', '#GPC DEADLIST "TURBOTEST.DEAD"'),
        (' IF TURBO.KEY$ = "" THEN GOTO TURBO.KEY.IDLE\n', ' IF TURBO.KEY$ = "" THEN GOTO TEST.FEED\n'),
        ('GOSUB APPSYS.RESTORE\nEND\n', 'TEST.QUIT.SEEN = 1\nGOTO TEST.REPORT\n'),
        ('KVBIN.FNAME$ = "/SETTINGS.KVB"', 'KVBIN.FNAME$ = "%s"' % SETTINGS),
        ('#INCLUDE "TG-LOW.BASL"\n',
         '#INCLUDE "TURBOTEST-DRIVER.BASL"\n#INCLUDE "TG-BENCH-CHECK.BASL"\n#INCLUDE "TG-LOW.BASL"\n'),
    ]
    for old, new in changes:
        if source.count(old) != 1:
            sys.exit("spike: TURBO.BASL holds %d of %r, not 1" % (source.count(old), old))
        source = source.replace(old, new)
    with open(os.path.join(HERE, TURBO_TEST + ".BASL"), "w", encoding="latin-1", newline="") as f:
        f.write(source)


def build(name):
    # build_basl.py compares only the .BASL with the .SRC.PRG, so an edited #INCLUDE
    # is not seen. Removing the .SRC.PRG forces the tokenise.
    stale = os.path.join(HERE, name + ".SRC.PRG")
    if os.path.exists(stale):
        os.remove(stale)
    step("build_basl.py", name + ".BASL", name + ".SRC.PRG")
    step("compile_shared.py", name + ".SRC.PRG", name + ".PRG", name + ".MAP")


def saved_file_differences(saved_path):
    """Count the lines of a saved document that differ from the fixture."""
    fixture = open(os.path.join(HERE, FIXTURE), "rb").read().split(b"\r\n")
    saved = open(saved_path, "rb").read().split(b"\r\n")
    differing = sum(1 for a, b in zip(fixture, saved) if a != b)
    return differing + abs(len(fixture) - len(saved))


def document_lines(path):
    """Return the lines of a CRLF file. The empty line after a final CRLF is dropped."""
    lines = open(path, "rb").read().split(b"\r\n")
    if lines and lines[-1] == b"":
        lines.pop()
    return lines


def class_line_differences(classes_path):
    """Count the fixture lines whose dumped classes differ from tgkeys.classify().

    The dump is the classes of every line, end to end, with no separator. Class 6 in the
    dump counts as 0. A difference in total length is added to the count. The first
    differing line is printed."""
    statements, functions = tgkeys.keywords()
    dumped = open(classes_path, "rb").read()
    differing = 0
    first = None
    position = 0
    for number, line in enumerate(document_lines(os.path.join(HERE, FIXTURE))):
        expected = bytes(tgkeys.classify(line.decode("latin-1"), statements, functions))
        got = bytes(0 if c == 6 else c for c in dumped[position:position + len(line)])
        position += len(line)
        if got != expected:
            differing += 1
            if first is None:
                first = (number, line, expected, got)
    if first is not None:
        print("CLASS.FIRST.DIFFERENCE line %d\n  %s\n  want %s\n  got  %s" % (
            first[0], first[1].decode("latin-1"),
            "".join(str(c) for c in first[2]), "".join(str(c) for c in first[3])))
    return differing + abs(len(dumped) - position)


def pane_cell_differences(pane_path, document_path, report):
    """Count the bytes of a dumped pane that differ from tgkeys.expected_pane().

    report holds the numbers of NAME.RES: COLOUR, PANE.TOP, PANE.LEFT, PANE.CURSOR.LINE
    and PANE.CURSOR.COL. A bench that ends with a selection on adds SELECT.ON,
    SELECT.ANCHOR.LINE and SELECT.ANCHOR.COL. A difference in length is added to the
    count. The first differing byte is printed."""
    cursor = (report["PANE.CURSOR.LINE"], report["PANE.CURSOR.COL"])
    selection = None
    if report.get("SELECT.ON", 0) != 0:
        selection = keymodel.ordered((report["SELECT.ANCHOR.LINE"], report["SELECT.ANCHOR.COL"]), *cursor)
    expected = tgkeys.expected_pane(
        document_lines(document_path), report["PANE.TOP"], report["PANE.LEFT"],
        cursor[0], cursor[1], report["COLOUR"] != 0, selection)
    dumped = open(pane_path, "rb").read()
    differing = [i for i, (a, b) in enumerate(zip(expected, dumped)) if a != b]
    if differing:
        i = differing[0]
        print("PANE.FIRST.DIFFERENCE row %d cell %d byte %d want %d got %d" % (
            i // 160, i % 160 // 2, i % 2, expected[i], dumped[i]))
    return len(differing) + abs(len(expected) - len(dumped))


def undo_bench_documents():
    """Return the documents UNDOBEN.WRP, .NEW, .UND and .RED must hold. Each is a list of
    lines, keyed by the file's name. The edits are those of UNDOBEN.BASL. A typed
    character 88 is saved as x and 89 as y."""
    fixture = document_lines(os.path.join(HERE, FIXTURE))
    edited = list(fixture)
    edited[100] = b"x" * 40 + edited[100]
    edited[100:101] = [edited[100][:20], edited[100][20:]]
    del edited[111:114]
    edited[111] = b"y" * 5 + edited[111]
    return {
        "UNDOBEN.WRP": fixture[:200] + [b"", b""] + fixture[200:],
        "UNDOBEN.NEW": edited,
        "UNDOBEN.UND": fixture,
        "UNDOBEN.RED": edited,
    }


def key_bench_documents():
    """Return the documents KEYBEN.OUT, .UND, .RED and .TIM must hold, keyed by the file's
    name, the cursor's line and column, and the selection's anchor or None, after the
    keys of KEYBEN.KEY."""
    fixture = document_lines(os.path.join(HERE, FIXTURE))
    edited, line, column, anchor = keymodel.play(fixture, keymodel.script())
    return {"KEYBEN.OUT": edited, "KEYBEN.UND": fixture, "KEYBEN.RED": edited,
            "KEYBEN.TIM": fixture}, line, column, anchor


def document_differences(saved_path, expected):
    """Count the lines of a saved document that differ from the expected lines. A
    difference in length is added to the count. The first differing line is printed."""
    saved = document_lines(saved_path)
    differing = [i for i, (a, b) in enumerate(zip(expected, saved)) if a != b]
    if differing:
        i = differing[0]
        print("DOCUMENT.FIRST.DIFFERENCE %s line %d\n  want %s\n  got  %s" % (
            os.path.basename(saved_path), i,
            expected[i].decode("latin-1"), saved[i].decode("latin-1")))
    return len(differing) + abs(len(expected) - len(saved))


def store_values(store_path):
    """Return the keys and values of a KVBIN store, as bytes. A free slot is left out."""
    data = open(store_path, "rb").read()
    values = {}
    for start in range(STORE_RECORD, len(data) - STORE_RECORD + 1, STORE_RECORD):
        record = data[start:start + STORE_RECORD]
        if record[0] != 0:
            values[record[:STORE_KEY].split(b"\0")[0]] = record[STORE_KEY:].split(b"\0")[0]
    return values


def store_image(values, slots=40):
    """Return a KVBIN store of slots slots that holds values, a key and its value as bytes
    each, in the first slots."""
    header = b"*KVBIN" + bytes([1, STORE_KEY, STORE_RECORD, slots % 256, slots // 256])
    image = header.ljust(STORE_RECORD, b"\0")
    for key, value in values.items():
        image += (key.ljust(STORE_KEY, b"\0") + value).ljust(STORE_RECORD, b"\0")
    return image.ljust(STORE_RECORD * (slots + 1), b"\0")


def settings_differences(store_path, expected):
    """Count the keys of the store that do not hold their expected values. A key expected
    as None must be missing. Each difference is printed."""
    if not os.path.exists(store_path):
        print("  no %s" % os.path.basename(store_path))
        return 1
    values = store_values(store_path)
    faults = 0
    for key, want in expected.items():
        if values.get(key) != want:
            faults += 1
            print("  %s: want %r got %r" % (key.decode(), want, values.get(key)))
    return faults


def bar_faults(bars_path, expected):
    """Count the parts of the dumped title bar and status bar that are not as expected.
    Each fault is printed."""
    if not os.path.exists(bars_path):
        print("  no %s" % os.path.basename(bars_path))
        return 1
    dumped = open(bars_path, "rb").read()
    title = turbomodel.bar_text(dumped[:160])
    status = turbomodel.bar_text(dumped[160:320])
    line, column = expected["cursor"]
    checks = [
        ("menu bar", title[0:34], " File  Edit  Search  Window  Help "),
        ("name", title[66:75], "TURBO GPC"),
        ("documents", title[76:79], "ABC"),
        ("document attributes", tuple(dumped[2 * column + 1] for column in range(76, 79)),
         expected["document attributes"]),
        ("line label", status[1:5], "Line"),
        ("line number", status[6:10].strip(), str(line + 1)),
        ("column label", status[12:15], "Col"),
        ("column number", status[16:20].strip(), str(column + 1)),
        ("change mark", status[22:23], " "),
        ("file name", status[24:44].rstrip(), expected["name"]),
        ("message", status[46:80].rstrip(), expected["message"]),
    ]
    faults = 0
    for what, got, want in checks:
        if got != want:
            faults += 1
            print("  %s: want %r got %r" % (what, want, got))
    return faults


def run(name, colour):
    result = os.path.join(HERE, name + ".RES")
    saved = os.path.join(HERE, name + ".OUT")
    pane = os.path.join(HERE, name + ".PANE")
    classes = os.path.join(HERE, name + ".CLS")
    bars = os.path.join(HERE, name + ".BAR")
    expected_documents = {}
    expected_cursor = None
    expected_anchor = False
    expected_bars = None
    pane_document = saved
    if name == "UNDOBEN":
        expected_documents = undo_bench_documents()
    if name == "KEYBEN":
        keymodel.write_script()
        expected_documents, cursor_line, cursor_column, expected_anchor = key_bench_documents()
        expected_cursor = (cursor_line, cursor_column)
    if name == TURBO_TEST:
        turbomodel.write_script()
        expected_bars = turbomodel.expected()
        expected_documents = expected_bars["documents"]
        expected_cursor = expected_bars["cursor"]
        pane_document = os.path.join(HERE, turbomodel.WORK_NAME)
    store = os.path.join(HERE, SETTINGS)
    for stale in [result, saved, pane, classes, bars, store] + [os.path.join(HERE, n) for n in expected_documents]:
        if os.path.exists(stale):
            os.remove(stale)
    if name == TURBO_TEST:
        shutil.copy(os.path.join(HERE, FIXTURE), pane_document)
        with open(store, "wb") as f:
            f.write(store_image(turbomodel.SETTINGS_BEFORE))
    with open(os.path.join(HERE, CONFIG), "wb") as f:
        f.write(b"1\r" if colour else b"0\r")
    home = os.path.relpath(HERE, SAMPLES).replace(os.sep, "/")
    with open(os.path.join(HERE, DRIVER), "w", newline="\n") as f:
        f.write('DOS"CD:/%s"\nLOAD"%s.PRG"\nRUN\n' % (home, name))
    env = dict(os.environ)
    env["SDL_VIDEODRIVER"] = "dummy"
    log = open(os.path.join(HERE, "SPIKERUN.LOG"), "wb")
    emulator = subprocess.Popen(
        [EMU, "-rom", ROM, "-fsroot", SAMPLES, "-sound", "none", "-echo", "-bas", DRIVER],
        cwd=HERE, stdout=log, stderr=subprocess.STDOUT, env=env)
    finished = False
    try:
        deadline = time.time() + RUN_TIMEOUT
        while time.time() < deadline:
            time.sleep(0.5)
            # The file is locked while the bench still has it open for writing.
            try:
                with open(result, "rb") as f:
                    written = f.read()
            except OSError:
                continue
            if b"DONE" in written:
                finished = True
                break
    finally:
        emulator.kill()
        try:
            emulator.wait(timeout=5)
        except subprocess.TimeoutExpired:
            pass
        log.close()
        os.remove(os.path.join(HERE, DRIVER))
    if not finished:
        tail = open(os.path.join(HERE, "SPIKERUN.LOG"), "rb").read()[-600:]
        sys.exit("spike: %s wrote no DONE within %ds. Echo log tail:\n%s"
                 % (name, RUN_TIMEOUT, tail.decode("latin-1", "replace")))
    os.remove(os.path.join(HERE, "SPIKERUN.LOG"))
    text = open(result, "rb").read().decode("latin-1")
    print(text.replace("\r\n", "\n").replace("\r", "\n").strip())
    if os.path.exists(saved) and name + ".OUT" not in expected_documents:
        print("SAVED.LINES.DIFFER %d" % saved_file_differences(saved))
    for document_name, expected in expected_documents.items():
        document = os.path.join(HERE, document_name)
        if os.path.exists(document):
            print("LINES.DIFFER %s %d" % (document_name, document_differences(document, expected)))
        else:
            print("LINES.DIFFER %s no file" % document_name)
    if os.path.exists(classes):
        print("CLASS.LINES.DIFFER %d" % class_line_differences(classes))
    report = {}
    for row in text.replace("\r", "\n").split("\n"):
        parts = row.split()
        if len(parts) == 2 and parts[1].lstrip("-").isdigit():
            report[parts[0]] = int(parts[1])
    if expected_cursor is not None:
        cursor = (report.get("PANE.CURSOR.LINE"), report.get("PANE.CURSOR.COL"))
        print("CURSOR.DIFFERS %d" % (cursor != expected_cursor))
        if cursor != expected_cursor:
            print("  want %s got %s" % (expected_cursor, cursor))
    if expected_anchor is not False:
        anchor = None
        if report.get("SELECT.ON", 0) != 0:
            anchor = (report.get("SELECT.ANCHOR.LINE"), report.get("SELECT.ANCHOR.COL"))
        print("SELECTION.DIFFERS %d" % (anchor != expected_anchor))
        if anchor != expected_anchor:
            print("  want %s got %s" % (expected_anchor, anchor))
    if os.path.exists(pane):
        document = pane_document if os.path.exists(pane_document) else os.path.join(HERE, FIXTURE)
        print("PANE.BYTES.DIFFER %d" % pane_cell_differences(pane, document, report))
    if expected_bars is not None:
        print("BAR.FAULTS %d" % bar_faults(bars, expected_bars))
        print("SETTINGS.DIFFER %d" % settings_differences(store, expected_bars["settings"]))


def main():
    args = sys.argv[1:]
    if not args:
        sys.exit(__doc__)
    name = args[0]
    try:
        stage(name)
        build(name)
        if "both" in args:
            run(name, False)
            run(name, True)
        else:
            run(name, "colour" in args)
    finally:
        if "--keep" not in args:
            clean()


main()
