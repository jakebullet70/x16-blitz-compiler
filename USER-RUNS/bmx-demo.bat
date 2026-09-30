@echo off
rem ---------------------------------------------------------------------------
rem  bmx-demo.bat -- run the compiled GP.BASIC BMX viewer in a VISIBLE window.
rem
rem  Type a file name at the prompt and press RETURN. The .BMX is optional.
rem  Any key returns from the picture; RETURN on its own quits and puts your
rem  screen mode and colour back.
rem
rem      XMASCARD   CANDLE   CAT1   BEARDGUY   TREE7   ROBOSPIDER
rem
rem  Source: GPC-BASIC-TOOLS-SRC/BMXVIEWER/BMXVIEW.BASL, on that folder's own
rem  GPC-BASIC/BMX.INC.BL. GPC-BASIC/BMXVIEW.EXP.BL is the library copy of the
rem  same program, and is not what this runs.
rem
rem  The sample folder IS the drive. It holds the object and the .BMX images.
rem  To build or rebuild it:
rem      python source/gpc/samplesbuild.py BMXVIEW
rem ---------------------------------------------------------------------------
setlocal
for %%I in ("%~dp0..") do set "ROOT=%%~fI\"
set "DRIVE=%ROOT%GPC-BASIC-TOOLS-SRC\BMXVIEWER"

if not exist "%DRIVE%\BMXVIEW.PRG" (
	echo.
	echo   GPC-BASIC-TOOLS-SRC\BMXVIEWER\BMXVIEW.PRG is not built yet.
	echo   Build it with:  python source\gpc\samplesbuild.py BMXVIEW
	echo.
	exit /b 1
)

"%ROOT%bin\x16emu\x16emu.exe" -rom "%ROOT%bin\x16emu\rom.bin" -fsroot "%DRIVE%" -scale 2 -sound none -prg "%DRIVE%\BMXVIEW.PRG" -run
endlocal
