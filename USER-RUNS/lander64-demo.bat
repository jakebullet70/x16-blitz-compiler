@echo off
rem ---------------------------------------------------------------------------
rem  lander64-demo.bat -- the Lander64 port, in a VISIBLE window with sound.
rem  The drive is the sample folder.
rem
rem  Cursor keys fly the ship. A gamepad plugged in plays as SNES port 1.
rem  Source: GPC-BASIC-TOOLS-SRC\LANDER64\LANDER64.BASL. The PRG is compiled
rem  EMBEDDED and needs no runtime file beside it. To rebuild it, from the
rem  repository root:
rem    python source\gpc\samplesbuild.py LANDER64
rem ---------------------------------------------------------------------------
setlocal
for %%I in ("%~dp0..") do set "ROOT=%%~fI\"
set "DRIVE=%ROOT%GPC-BASIC-TOOLS-SRC\LANDER64"
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
if not exist "%DRIVE%\LANDER64.PRG" (
	echo.
	echo   GPC-BASIC-TOOLS-SRC\LANDER64\LANDER64.PRG is not built.
	echo   See the notes at the top of this file.
	echo.
	exit /b 1
)

"%X16EMU%" -rom "%ROM%" -fsroot "%DRIVE%" -scale 2 -joy1 -prg "%DRIVE%\LANDER64.PRG" -run
endlocal
exit /b 0
