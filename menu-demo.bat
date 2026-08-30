@echo off
rem ---------------------------------------------------------------------------
rem  menu-demo.bat -- run the compiled GP.BASIC menu demo in a VISIBLE window.
rem
rem      cursor up / down   move the highlight
rem      RETURN             choose            N L O Q  hotkeys, no case
rem      ESC                cancel (the demo just redraws)
rem      QUIT               restores your screen mode and colour, then exits
rem
rem  Source: GPC-BASIC\MENU.EXP.BL  (+ THEME.INC.BL, APPHELP.INC.BL)
rem
rem  demo\ is BUILD OUTPUT and is not in git. To make it:
rem    1. copy GP.INC.BL, THEME.INC.BL, APPHELP.INC.BL and MENU.EXP.BL from
rem       GPC-BASIC\ into testing\
rem    2. python source\gpc\build_basl.py MENU.EXP.BL MENU.PRG
rem    3. compile testing\MENU.PRG with GPC.BIN, and put the object in
rem       demo\ as C.MENU.PRG
rem ---------------------------------------------------------------------------
setlocal
set "ROOT=%~dp0"
set "DEMO=%ROOT%demo"

if not exist "%DEMO%\C.MENU.PRG" (
	echo.
	echo   demo\C.MENU.PRG is not built yet.
	echo   See the notes at the top of this file for the three steps.
	echo.
	exit /b 1
)

"%ROOT%bin\x16emu\x16emu.exe" -rom "%ROOT%bin\x16emu\rom.bin" -fsroot "%DEMO%" -scale 2 -sound none -prg "%DEMO%\C.MENU.PRG" -run
endlocal
