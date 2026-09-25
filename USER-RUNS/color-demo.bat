@echo off
rem ---------------------------------------------------------------------------
rem  color-demo.bat -- run COLORTST, the colour scheme picker, in a VISIBLE window.
rem  The drive is the sample folder. COLORTST.PRG is compiled EMBEDDED, so it
rem  carries the runtime and needs no GPC.RT.nnn.BIN beside it.
rem
rem  Source: samples\color-test\COLORTST.BASL, on GPB, APPSYS and THEME, all three
rem  in samples\color-test\GPC-BASIC\ beside it.
rem  To rebuild it, from the repository root:
rem    python source\gpc\samplesbuild.py COLORTST
rem ---------------------------------------------------------------------------
setlocal
for %%I in ("%~dp0..") do set "ROOT=%%~fI\"
set "DRIVE=%ROOT%samples\color-test"
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
if not exist "%DRIVE%\COLORTST.PRG" (
	echo.
	echo   samples\color-test\COLORTST.PRG is not built.
	echo   See the notes at the top of this file.
	echo.
	exit /b 1
)

"%X16EMU%" -rom "%ROM%" -fsroot "%DRIVE%" -scale 2 -sound none -prg "%DRIVE%\COLORTST.PRG" -run
endlocal
