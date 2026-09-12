@echo off
rem ---------------------------------------------------------------------------
rem  help-demo.bat -- GPB.HELP, the GP.BASIC and BASL reference, in a VISIBLE
rem  window.
rem
rem  A scrolling master index over 74 topics, built from GPC-BASIC/ -- the
rem  manual, the name register and the module banner headers -- so the help
rem  cannot drift from the library it documents.
rem
rem      up/down  PgUp/PgDn  HOME/END    move
rem      RETURN                          open a topic (index only)
rem      /  or F                         find in the index, N for the next
rem      L                               this topic's cross references
rem      X                               write this topic's code out as a .BL
rem      ?                               about
rem      ESC                             back, then quit
rem
rem  IT RUNS IN CP437 (charset 7, ROM R47+) at 80x30: the low half is ASCII so
rem  the text is mixed case with no re-ordered font, and the high half has real
rem  line drawing for the dialog frames. APPSYS.RESTORE hands the screen mode
rem  and the whole $0372 charset byte back on the way out.
rem
rem  EVERYTHING IT READS IS IN samples\GPC-HELP\HELP-TXT -- the index and the
rem  topics alike -- opened through the CMD path syntax "//HELP-TXT/:NAME", which
rem  is what CMDR-DOS documents and what a real SD card wants.
rem
rem  NOTE THAT THE DRIVE IS samples\GPC-HELP, so an "X" export lands in the repo
rem  beside the sources. git clean -f samples/GPC-HELP/ tidies up.
rem
rem  XFMGR IS ON THE DRIVE TOO, for looking at what an export actually wrote.
rem  Quit the help to READY, then:
rem
rem      RUN "XT"                  XFMGR, the file manager -- XT is a shim that
rem                                LOADs /XFMGR/XFMGR.PRG
rem
rem  XFMGR and XT are DEV ONLY, the same way tmp-emu.bat has them: they are
rem  staged here for this bat and are no part of what ships.
rem
rem  Source: samples\GPC-HELP\GPB.HELP.BASL on GPB, THEME, STASH, STRCASE, APPSYS,
rem  KB, MENUVERT, LINEINPUT, GUI and COMBO, all shipped in
rem  samples\GPC-HELP\GPC-BASIC\ beside the sample so a rebuild needs nothing
rem  from GPC-BASIC\. The object is SHARED, so GPB.RT.121.BIN has to sit beside
rem  the PRG on the drive. See samples\GPC-HELP\readme.md for the rebuild, and
rem  for the measurements behind the three design decisions.
rem ---------------------------------------------------------------------------
setlocal
set "ROOT=%~dp0"
set "DRIVE=%ROOT%samples\GPC-HELP"
set "X16EMU=%ROOT%bin\x16emu\x16emu.exe"
set "ROM=%ROOT%bin\x16emu\rom.bin"

if not exist "%X16EMU%" (
	echo x16emu not found: "%X16EMU%"
	exit /b 1
)
if not exist "%ROM%" (
	echo ROM not found: "%ROM%"
	exit /b 1
)
if not exist "%DRIVE%\GPB.HELP.PRG" (
	echo.
	echo   samples\GPC-HELP\GPB.HELP.PRG is not built.
	echo   See the rebuild section of samples\GPC-HELP\readme.md.
	echo.
	exit /b 1
)
if not exist "%DRIVE%\HELP-TXT\GPB.HELP.IDX" (
	echo.
	echo   samples\GPC-HELP\HELP-TXT\GPB.HELP.IDX is missing -- no index to
	echo   load and will say so and stop. Rebuild the content with:
	echo.
	echo       python samples\GPC-HELP\MKHELP.PY
	echo.
	exit /b 1
)

"%X16EMU%" -rom "%ROM%" -fsroot "%DRIVE%" -scale 2 -sound none -prg "%DRIVE%\GPB.HELP.PRG" -run
endlocal
