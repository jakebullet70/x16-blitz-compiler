@echo off
rem ---------------------------------------------------------------------------
rem  gpbmods-demo.bat -- run GPB-MODS-TESTING, the library harness, in a
rem  VISIBLE window.
rem
rem      <- ->      walk the menu bar
rem      DOWN       open the dropdown under the marked item
rem      <- ->      with a dropdown open, move to the next one
rem      UP DOWN    walk the dropdown, RETURN chooses
rem      ESC        closes the dropdown, then leaves the program
rem
rem  EVERY PANEL IS A STUB. A chosen row opens GUI.SAY naming itself. The bar,
rem  the dropdowns and the screen save under them are real.
rem
rem  THE DRIVE IS testing\, NOT the sample directory. GPBMODS.PRG is compiled
rem  SHARED, so it loads the resident GPC.RT.nnn.BIN rather than carrying a
rem  copy, and testing\ is where that runtime lives.
rem
rem  Source: samples\GPB-MODS-TESTING\GPBMODS.BASL, on the twelve modules
rem  shipped in samples\GPB-MODS-TESTING\GPC-BASIC\ beside it. See that
rem  folder's readme.md for the two-step rebuild.
rem ---------------------------------------------------------------------------
setlocal
set "ROOT=%~dp0"
set "DRIVE=%ROOT%testing"
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
if not exist "%DRIVE%\GPBMODS.PRG" (
	echo.
	echo   testing\GPBMODS.PRG is not built. From the project root:
	echo     python source\gpc\build_basl.py GPBMODS.BASL GPBMODS.SRC.PRG
	echo     python source\gpc\compile_shared.py GPBMODS.SRC.PRG GPBMODS.PRG GPBMODS.MAP
	echo   with GPBMODS.BASL and GPC-BASIC\*.INC.BL copied into testing\ first.
	echo.
	exit /b 1
)

"%X16EMU%" -rom "%ROM%" -fsroot "%DRIVE%" -scale 2 -sound none -prg "%DRIVE%\GPBMODS.PRG" -run
endlocal
