# release/ — the release drop folder

Kept apart from `testing/`, which is the daily build and scratch area. Nothing in here is
edited by hand; both of the things that land here are products of `release.sh`, and both
are git-ignored. The folder itself is tracked so a fresh clone has it.

| | what it is |
|---|---|
| `TMP/` | the release **unpacked**, in the shape the zip will have |
| `gpc-release-<version>.zip` | the packaged download, named from `source/application/buildnum.txt` |

## The two steps

`release.sh` is the only release build file. Run it from Git Bash, or through
`release.bat`, which puts make and 64tass on PATH first.

```
./release.sh          build everything, stage release/TMP, then zip it
./release.sh stage    stage release/TMP from the current build -- no rebuild, no zip
./release.sh zip      zip release/TMP exactly as it stands -- no rebuild, no restage
```

Staging and packaging are separate on purpose. Stage the tree, look at it, correct it,
then zip from it — a hand edit in `TMP/` survives, because `zip` does not restage.

`tmp-emu.bat` boots the emulator with `TMP/` as its drive, so the release can be run
before it is packaged.

## What staging will not do

**It never compiles.** It takes whatever the last build left in `testing/` and the sample
folders. A program with no compiled object is staged as a **placeholder**: a two-line BASIC
stub that prints its own name and ends, so it can never be mistaken for a build.
`TMP/MANIFEST.TXT` lists every file with where it came from and names the placeholders,
and the zip step warns again about any it ships.

## XFMGR and XT

Staged into `TMP/` and **left out of the zip**. They are the file manager the staged drive
is navigated with and the BASIC shim that loads it — development tools, not part of the
product. `release.sh` enforces this by skipping those paths when it packages.
