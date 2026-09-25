@echo off
rem ---------------------------------------------------------------------------
rem  help-demo.bat -- GPB.HELP, the GP.BASIC and BASL reference, in a VISIBLE
rem  window.
rem
rem  EVERYTHING IT READS IS IN GPC-BASIC-TOOLS-SRC\GPC-HELP\HELP-TXT -- the index and the
rem  topics alike -- opened through the CMD path syntax "//HELP-TXT/:NAME", which
rem  is what CMDR-DOS documents and what a real SD card wants.
rem
rem  Source: GPC-BASIC-TOOLS-SRC\GPC-HELP\GPB.HELP.BASL on thirteen modules -- GPB, THEME,
rem  STASH, STRCASE, APPSYS, BANKMGR, MENU.INC.BANKED, MENU, LINEINPUT, GUI,
rem  COMBO, CHECK and GUI-DIALOGS -- all shipped in GPC-BASIC-TOOLS-SRC\GPC-HELP\GPC-BASIC\
rem  beside the sample so a rebuild needs nothing from GPC-BASIC\. The object is
rem  SHARED, so GPB.RT.nnn.BIN, GPC.RT.nnn.BIN, GP1.RT.nnn.BIN and GPB.HELP.OVL
rem  have to sit beside the PRG on the drive. See GPC-BASIC-TOOLS-SRC\GPC-HELP\readme.md for
rem  the rebuild, and for the measurements behind the design decisions.
rem ---------------------------------------------------------------------------
setlocal
for %%I in ("%~dp0..") do set "ROOT=%%~fI\"
set "DRIVE=%ROOT%GPC-BASIC-TOOLS-SRC\GPC-HELP"
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
	echo   GPC-BASIC-TOOLS-SRC\GPC-HELP\GPB.HELP.PRG is not built.
	echo   See the rebuild section of GPC-BASIC-TOOLS-SRC\GPC-HELP\readme.md.
	echo.
	exit /b 1
)
if not exist "%DRIVE%\HELP-TXT\GPB.HELP.IDX" (
	echo.
	echo   GPC-BASIC-TOOLS-SRC\GPC-HELP\HELP-TXT\GPB.HELP.IDX is missing -- no index to
	echo   load and will say so and stop. Rebuild the content with:
	echo.
	echo       python GPC-BASIC-TOOLS-SRC\GPC-HELP\MKHELP.PY
	echo.
	exit /b 1
)

"%X16EMU%" -rom "%ROM%" -fsroot "%DRIVE%" -scale 2 -sound none -prg "%DRIVE%\GPB.HELP.PRG" -run
endlocal
