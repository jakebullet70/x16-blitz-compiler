@echo off
rem ---------------------------------------------------------------------------
rem  gpbmods-demo.bat -- run GPB-MODS-TESTING, the library harness, in a
rem  VISIBLE window.
rem  EVERY PANEL IS WRITTEN. A chosen row runs the library call it names and
rem  leaves the answer on the bottom row. FILES writes to the drive -- every
rem  file and directory it makes is removed by the row that made it.
rem
rem ---------------------------------------------------------------------------
setlocal
for %%I in ("%~dp0..") do set "ROOT=%%~fI\"
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
