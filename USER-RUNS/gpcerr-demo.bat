@echo off
rem ---------------------------------------------------------------------------
rem  gpcerr-demo.bat -- GPC.ERR, the error-address lookup, in a VISIBLE window.
rem
rem  The bar has three items. FILE drops down LOAD MAP, BROWSE MAP and QUIT.
rem  LOAD MAP asks for the name, already filled in when the drive holds one
rem  .MAP file, and BROWSE MAP opens the picker. SEARCH drops down BY ADDRESS,
rem  which takes an error address like $34A7, and BY LINE, which takes a BASIC
rem  line straight. HELP drops down HOW TO, three lines on what LOAD MAP and
rem  the two searches each want typed, and ABOUT, three lines: what the program
rem  is, who it is for, and the total banks, the unused banks and the bytes
rem  free. ALT and a bar item's hot key opens that item's dropdown, LEFT and
rem  RIGHT walk from one dropdown to the next, and ESC closes the open one.
rem  QUIT under FILE is the way out.
rem
rem  The footer line is centred and carries the loaded map's project: files,
rem  source lines and compiled lines. Counting them reads two files end to
rem  end, 9.4 seconds on the GPB.HELP fixture.
rem
rem  Under the answer are seven lines of the source, the one looked up marked
rem  with a > and the three either side of it dimmed. The names are the crunched
rem  ones BASLOAD wrote. A names block under them turns six of those names back
rem  into real ones, two to a row, with the source line each was first seen on.
rem
rem  THE DRIVE IS samples\GPC-HELP, which is where the fixture already lives.
rem  GPB.HELP.MAP, GPB.HELP.SRC.SYM and GPB.HELP.SRC.PRG are the map, the symbol
rem  file and the tokenised source, so $34A7 answers GPB.HELP.BASL, BASIC line
rem  1669, near HELP.BOOT at source line 147. The names block for that line
rem  shows N6$ = HELP.ROW$, LINE 186.
rem
rem  The screen is 80x30.
rem
rem  Source: samples\GPC.ERR\GPC.ERR.BASL on twenty-two modules. Seventeen run
rem  from RAM banks 4, 5, 7, 8, 10 and 12 as GP.BANKED regions, and banks 61 and 62
rem  hold the keyword table and the menu rows, so the object is 10.0 KB of low RAM
rem  and the rest is the GPC.ERR.OVL beside it. Both files have to be on the
rem  drive, and so does GPB.RT.nnn.BIN: the object is SHARED.
rem  Rebuild with, from the repo root:
rem
rem      python source\gpc\build_basl.py --drive samples\GPC.ERR GPC.ERR.BASL GPC.ERR.SRC.PRG
rem      python source\gpc\compile_shared.py --drive samples\GPC.ERR GPC.ERR.SRC.PRG GPC.ERR.PRG GPC.ERR.MAP
rem
rem  then copy GPC.ERR.PRG and GPC.ERR.OVL into samples\GPC-HELP.
rem ---------------------------------------------------------------------------
setlocal
for %%I in ("%~dp0..") do set "ROOT=%%~fI\"
set "DRIVE=%ROOT%samples\GPC-HELP"
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
	echo   samples\GPC-HELP\GPC.ERR.PRG is not there. Rebuild it with the
	echo   commands at the top of this file.
	echo.
	exit /b 1
)
if not exist "%DRIVE%\GPC.ERR.OVL" (
	echo.
	echo   samples\GPC-HELP\GPC.ERR.OVL is missing. It carries the banked GUI
	echo   and the program cannot run without it. Rebuild with the commands at
	echo   the top of this file.
	echo.
	exit /b 1
)
if not exist "%DRIVE%\GPB.HELP.MAP" (
	echo.
	echo   samples\GPC-HELP\GPB.HELP.MAP is missing, so the picker will have
	echo   nothing to offer. Rebuild GPB.HELP with:
	echo.
	echo       python source\gpc\samplesbuild.py GPB.HELP
	echo.
	exit /b 1
)

"%X16EMU%" -rom "%ROM%" -fsroot "%DRIVE%" -scale 2 -sound none -prg "%DRIVE%\GPC.ERR.PRG" -run
endlocal
