@echo off
rem ---------------------------------------------------------------------------
rem  gpcerr-demo.bat -- GPC.ERR, the error-address lookup, in a VISIBLE window.
rem
rem  THE DRIVE IS GPC-BASIC-TOOLS-SRC\GPC-HELP, which is where the fixture already lives.
rem  GPC.HELP.MAP, GPC.HELP.SRC.SYM and GPC.HELP.SRC.PRG are the map, the symbol
rem  file and the tokenised source, so $0C:AAF4 answers GPC-BASIC/GUI.INC.BL,
rem  BASIC line 1000, near GUI.FORM.PAINT at source line 322. The names block for
rem  that line shows G8% = GUI.CTRL.TYPE%, LINE 147. $027E answers GPC.HELP.BASL,
rem  BASIC line 1669, near HELP.GUIEND at source line 61.
rem
rem  The screen is 80x30.
rem
rem  Source: GPC-BASIC-TOOLS-SRC\GPC.ERR\GPC.ERR.BASL on twenty-two modules. Seventeen run
rem  from RAM banks 4, 5, 7, 8, 10 and 12 as GP.BANKED regions, and banks 61 and 62
rem  hold the keyword table and the menu rows, so the object is 10.3 KB of low RAM
rem  and the rest is the GPC.ERR.OVL beside it. Both files have to be on the
rem  drive, and so does GPB.RT.nnn.BIN: the object is SHARED.
rem  Rebuild with, from the repo root:
rem
rem      python source\gpc\build_basl.py --drive GPC-BASIC-TOOLS-SRC\GPC.ERR GPC.ERR.BASL GPC.ERR.SRC.PRG
rem      python source\gpc\compile_shared.py --drive GPC-BASIC-TOOLS-SRC\GPC.ERR GPC.ERR.SRC.PRG GPC.ERR.PRG GPC.ERR.MAP
rem
rem  then copy GPC.ERR.PRG and GPC.ERR.OVL into GPC-BASIC-TOOLS-SRC\GPC-HELP.
rem ---------------------------------------------------------------------------
setlocal
for %%I in ("%~dp0..") do set "ROOT=%%~fI\"
set "DRIVE=%ROOT%GPC-BASIC-TOOLS-SRC\GPC-HELP"
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
if not exist "%DRIVE%\GPC.ERR.PRG" (
	echo.
	echo   GPC-BASIC-TOOLS-SRC\GPC-HELP\GPC.ERR.PRG is not there. Rebuild it with the
	echo   commands at the top of this file.
	echo.
	exit /b 1
)
if not exist "%DRIVE%\GPC.ERR.OVL" (
	echo.
	echo   GPC-BASIC-TOOLS-SRC\GPC-HELP\GPC.ERR.OVL is missing. It carries the banked GUI
	echo   and the program cannot run without it. Rebuild with the commands at
	echo   the top of this file.
	echo.
	exit /b 1
)
if not exist "%DRIVE%\GPC.HELP.MAP" (
	echo.
	echo   GPC-BASIC-TOOLS-SRC\GPC-HELP\GPC.HELP.MAP is missing, so the picker will have
	echo   nothing to offer. Rebuild GPC.HELP with:
	echo.
	echo       python source\gpc\samplesbuild.py GPC.HELP
	echo.
	exit /b 1
)

"%X16EMU%" -rom "%ROM%" -fsroot "%DRIVE%" -scale 2 -sound none -prg "%DRIVE%\GPC.ERR.PRG" -run
endlocal
