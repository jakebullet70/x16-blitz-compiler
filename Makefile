# *******************************************************************************************
# *******************************************************************************************
#
#		Name : 		Makefile
#		Purpose :	Outer makefile
#		Date :		5th October 2023
#		Author : 	Paul Robson (paul@robsons.org.uk)
#
# *******************************************************************************************
# *******************************************************************************************

#
#		Bl**dy Windows.
#
ifeq ($(OS),Windows_NT)
include documents\common.make
else
include documents/common.make
endif

#
#		The revision of the current release. Must match the ROM in bin/x16emu/ --
#		bumping this without refreshing that rom.bin will mismatch emulator and ROM.
#
REVISION = r49

#
#		These are all commands, not files. "release" in particular used to collide with the
#		release/ directory (now merged into testing/) -- make would see the directory, decide the
#		target was already made, and skip it. Mark them phony so they always run regardless.
#
.PHONY: all libs release pullbuild latest samples

all: libs samples

#
#		Mirror the samples/ tree into testing/ (the emulator's drive and the root of the release
#		zip), so every sample is runnable in the emulator and ships in the release. samples/ is the
#		master; testing/samples is a build artifact, wiped and re-copied each time so a renamed or
#		deleted sample never lingers. Runs on every build (it is a prerequisite of `all`).
#
samples:
	rm -rf $(RELEASEDIR)samples
	cp -r samples $(RELEASEDIR)samples

#
#		Build the library version of the components. 
#
libs:	
	make $(MAKEOPTS) -C source
#
#		Build the release
#
release:
	make $(MAKEOPTS) -C source$(S)application release
#
#		Get the most recent version of the emulator & docs. Requires the three
#		repositories to be in the same directory as the blitz repository
#	
pullbuild:
	cd ..$(S)x16-docs ; git pull
	cd ..$(S)x16-rom ; git pull ; make
	cd ..$(S)x16-emulator ; git pull ; make
	$(CCOPY) ..$(S)x16-rom$(S)build$(S)x16$(S)rom.bin $(EMUDIR)
	$(CCOPY) ..$(S)x16-emulator$(S)x16emu$(APPSTEM) $(EMUDIR)
#
#		Get latest release. Unpacks into bin/x16emu/ -- NOT bin/ -- because
#		common.make reads the emulator and its rom.bin from there (and bin/box16/
#		holds a second emulator with an incompatible SDL2.dll). Keeps the .sym
#		files: they are how ROM addresses in x16_*_include.inc get verified.
#
#		wget(1) and unzip(1) are not present on a stock Windows box, so the
#		download and extract both go through Python's stdlib.
#
BTEMP = $(BINDIR)temp$(S)
EMUURL = https://github.com/X16Community/x16-emulator/releases/download/$(REVISION)

latest:
	$(PYTHON) -c "import os, urllib.request as u; d=r'$(BTEMP)'; os.makedirs(d, exist_ok=True); [u.urlretrieve('$(EMUURL)/'+z, os.path.join(d,z)) for z in ('x16emu_linux-x86_64-$(REVISION).zip','x16emu_win64-$(REVISION).zip')]"
	$(PYTHON) -c "import os, glob, zipfile; d=r'$(BTEMP)'; [zipfile.ZipFile(z).extractall(d) for z in glob.glob(os.path.join(d,'*.zip'))]"
	$(CDEL) $(BTEMP)*.pdf
	$(CDEL) $(BTEMP)*.zip
	$(CCOPY) $(BTEMP)x16emu $(EMUDIR)
	$(CCOPY) $(BTEMP)x16emu.exe $(EMUDIR)
	$(CCOPY) $(BTEMP)rom.bin $(EMUDIR)
	$(CCOPY) $(BTEMP)*.sym $(EMUDIR)
	$(CCOPY) $(BTEMP)*.dll $(EMUDIR)

