@echo off
rem ---------------------------------------------------------------------------
rem  help-demo.bat -- GPB.HELP, the GP.BASIC and BASL reference, in a VISIBLE
rem  window.
rem
rem  EVERYTHING IT READS IS IN samples\GPC-HELP\HELP-TXT -- the index and the
rem  topics alike -- opened through the CMD path syntax "//HELP-TXT/:NAME", which
rem  is what CMDR-DOS documents and what a real SD card wants.
rem
rem  Source: samples\GPC-HELP\GPB.HELP.BASL on GPB, THEME, STASH, STRCASE, APPSYS,
rem  KB, MENUVERT, LINEINPUT, GUI and COMBO, all shipped in
rem  samples\GPC-HELP\GPC-BASIC\ beside the sample so a rebuild needs nothing
rem  from GPC-BASIC\. The object is SHARED, so the GPB.RT and GP1.RT files of
rem  its build have to sit beside the PRG on the drive. See samples\GPC-HELP\readme.md for the rebuild, and
rem  for the measurements behind the three design decisions.
rem ---------------------------------------------------------------------------
setlocal
for %%I in ("%~dp0..") do set "ROOT=%%~fI\"
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
