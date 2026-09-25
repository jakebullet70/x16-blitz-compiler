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
rem  Source: GPC-BASIC\BMXVIEW.EXP.BL, on GPC-BASIC\BMX.INC.BL
rem
rem  source\scratch\demo\ is BUILD OUTPUT and is not in git. To make it:
rem    1. copy GPB.INC.BL, APPSYS.INC.BL, BMX.INC.BL and BMXVIEW.EXP.BL
rem       from GPC-BASIC\ into source\drive\
rem    2. python source\gpc\build_basl.py BMXVIEW.EXP.BL BMXVIEW.PRG
rem    3. compile source\drive\BMXVIEW.PRG with GPC.BIN, and put the object
rem       in source\scratch\demo\ as C.BMXVIEW.PRG
rem    4. copy any .BMX files you want into source\scratch\demo\ -- GPC-BASIC-TOOLS-SRC\BMXVIEWER\SAMPLES
rem       has eight, one for each header shape the viewer has to handle
rem ---------------------------------------------------------------------------
setlocal
for %%I in ("%~dp0..") do set "ROOT=%%~fI\"
set "DEMO=%ROOT%source\scratch\demo"

if not exist "%DEMO%\C.BMXVIEW.PRG" (
	echo.
	echo   source\scratch\demo\C.BMXVIEW.PRG is not built yet.
	echo   See the notes at the top of this file for the four steps.
	echo.
	exit /b 1
)

"%ROOT%bin\x16emu\x16emu.exe" -rom "%ROOT%bin\x16emu\rom.bin" -fsroot "%DEMO%" -scale 2 -sound none -prg "%DEMO%\C.BMXVIEW.PRG" -run
endlocal
