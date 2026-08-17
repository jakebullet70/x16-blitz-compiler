@echo off
rem ---------------------------------------------------------------------------
rem  bmx-demo.bat -- run the compiled GP.BASIC BMX viewer in a VISIBLE window.
rem
rem  Type a file name at the prompt and press RETURN. The .BMX is optional.
rem  Any key returns from the picture; RETURN on its own quits and puts your
rem  screen mode and colour back.
rem
rem      CAT1   TREE1   XMASCARD   SNOWMAN   PIZZACAT   ROBOCAT
rem
rem  Source: GPC-BASIC\BMXVIEW.EXP.BL  (+ GP.INC.BL, APPHELP.INC.BL)
rem
rem  demo\ is BUILD OUTPUT and is not in git. To make it:
rem    1. copy GP.INC.BL, APPHELP.INC.BL and BMXVIEW.EXP.BL from GPC-BASIC\
rem       into testing\
rem    2. python source\gpc\build_basl.py BMXVIEW.EXP.BL BMXVIEW.PRG
rem    3. compile testing\BMXVIEW.PRG with GPC.BLITZ.BIN, and put the object
rem       in demo\ as C.BMXVIEW.PRG
rem    4. copy any .BMX files you want into demo\ -- samples\BMXVIEWER\SAMPLES
rem       has about thirty
rem ---------------------------------------------------------------------------
setlocal
set "ROOT=%~dp0"
set "DEMO=%ROOT%demo"

if not exist "%DEMO%\C.BMXVIEW.PRG" (
	echo.
	echo   demo\C.BMXVIEW.PRG is not built yet.
	echo   See the notes at the top of this file for the four steps.
	echo.
	exit /b 1
)

"%ROOT%bin\x16emu\x16emu.exe" -rom "%ROOT%bin\x16emu\rom.bin" -fsroot "%DEMO%" -scale 2 -sound none -prg "%DEMO%\C.BMXVIEW.PRG" -run
endlocal
