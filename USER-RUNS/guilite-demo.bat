@echo off
rem ---------------------------------------------------------------------------
rem  guilite-demo.bat -- run GUI-LITE, a message box and a menu in low memory, in a VISIBLE
rem  window. The drive is the sample folder. GUI-LITE.PRG is compiled EMBEDDED,
rem  so it carries the runtime and needs no GPC.RT.nnn.BIN beside it, and it
rem  has no .OVL.
rem
rem  Source: GPC-BASIC-TOOLS-SRC\GUI-LITE\GUI-LITE.BASL, on GPB, APPSYS, THEME,
rem  GUI-LITE and DOS, all in GPC-BASIC-TOOLS-SRC\GUI-LITE\GPC-BASIC\.
rem  To rebuild it, from the repository root:
rem    python source\gpc\samplesbuild.py GUI-LITE
rem ---------------------------------------------------------------------------
setlocal
for %%I in ("%~dp0..") do set "ROOT=%%~fI\"
set "DRIVE=%ROOT%GPC-BASIC-TOOLS-SRC\GUI-LITE"
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
if not exist "%DRIVE%\GUI-LITE.PRG" (
	echo.
	echo   GPC-BASIC-TOOLS-SRC\GUI-LITE\GUI-LITE.PRG is not built.
	echo   See the notes at the top of this file.
	echo.
	exit /b 1
)

"%X16EMU%" -rom "%ROM%" -fsroot "%DRIVE%" -scale 2 -sound none -prg "%DRIVE%\GUI-LITE.PRG" -run
endlocal
