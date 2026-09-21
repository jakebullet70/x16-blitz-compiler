@echo off
rem
rem  C.EDITOR.PRG is the COMPILED object and is checked in beside the source.
rem  To rebuild it:
rem    1. copy the .INC.BL files up out of samples\edit\GPC-BASIC\
rem       so they sit beside EDITOR.BASL (all eight of them)
rem    2. python source\gpc\build_basl.py EDITOR.BASL EDITOR.PRG
rem    3. compile EDITOR.PRG with GPC.BIN, and keep the object as C.EDITOR.PRG
rem ---------------------------------------------------------------------------
setlocal
for %%I in ("%~dp0..") do set "ROOT=%%~fI\"
set "DRIVE=%ROOT%samples\edit"
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
if not exist "%DRIVE%\C.EDITOR.PRG" (
	echo.
	echo   samples\edit\C.EDITOR.PRG is not built.
	echo   See the notes at the top of this file for the three steps.
	echo.
	exit /b 1
)

"%X16EMU%" -rom "%ROM%" -fsroot "%DRIVE%" -scale 2 -sound none -prg "%DRIVE%\C.EDITOR.PRG" -run
endlocal
