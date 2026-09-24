@echo off
rem ---------------------------------------------------------------------------
rem  gpcerr-demo.bat -- GPC.ERR, the error-address lookup, in a VISIBLE window.
rem
rem  The bar has four items. MAP picks the debug map off the drive, ADDRESS takes
rem  an error address like $34A7, LINE takes a BASIC line straight, and QUIT
rem  leaves. ESC on the bar also leaves.
rem
rem  THE FIXTURE IS GPB.HELP. testing\GPB.HELP.MAP and testing\GPB.HELP.SRC.SYM
rem  are the map and the symbol file from samples\GPC-HELP, so $34A7 answers
rem  GPB.HELP.BASL, BASIC line 1669, near HELP.BOOT at source line 147.
rem
rem  Source: testing\GPC.ERR.BASL on fifteen modules -- GPB, THEME, STASH,
rem  STRCASE, BANKMGR, MENU.INC.BANKED, MENU, LINEINPUT, GUI, COMBO, CHECK,
rem  GUI-DIALOGS, FILEIO, FILEDIR and FILEPICK. The object is SHARED, so
rem  GPB.RT.nnn.BIN has to sit beside the PRG on the drive. Rebuild with:
rem
rem      python source\gpc\build_basl.py GPC.ERR.BASL GPC.ERR.PRG
rem      python source\gpc\compile_shared.py GPC.ERR.PRG C.GPC.ERR.PRG GPC.ERR.MAP
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
if not exist "%DRIVE%\C.GPC.ERR.PRG" (
	echo.
	echo   testing\C.GPC.ERR.PRG is not built. Rebuild it with the two
	echo   commands at the top of this file.
	echo.
	exit /b 1
)
if not exist "%DRIVE%\GPB.HELP.MAP" (
	echo.
	echo   testing\GPB.HELP.MAP is missing, so the picker will have nothing
	echo   to offer. Copy the fixture in with:
	echo.
	echo       copy samples\GPC-HELP\GPB.HELP.MAP testing\
	echo       copy samples\GPC-HELP\GPB.HELP.SRC.SYM testing\
	echo.
	exit /b 1
)

"%X16EMU%" -rom "%ROM%" -fsroot "%DRIVE%" -scale 2 -sound none -prg "%DRIVE%\C.GPC.ERR.PRG" -run
endlocal
