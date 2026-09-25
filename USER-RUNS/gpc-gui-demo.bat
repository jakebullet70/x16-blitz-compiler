@echo off
rem ---------------------------------------------------------------------------
rem  gpc-gui-demo.bat -- run GPC.GUI, the compiler's form front end, in a
rem  VISIBLE window.
rem
rem      <- ->      walk the menu bar
rem      DOWN       open the dropdown under the marked item
rem      TAB        move between the controls on the settings form
rem      ESC        closes the dropdown, then leaves the program
rem
rem  THE DRIVE IS GPC-BASIC-TOOLS-SRC\GPC-GUI-HELPER. GPC.GUI.PRG is compiled SHARED, so
rem  the GPB.RT and GP1.RT files of its build sit beside it, with its region
rem  overlays. GPC.BIN is there too: BUILD > COMPILE writes GPC.INPUT and
rem  LOADs it.
rem
rem  Rebuild, from the project root:
rem    python source\gpc\build_basl.py     --drive GPC-BASIC-TOOLS-SRC\GPC-GUI-HELPER GPC.GUI.BASL GPC.GUI.SRC.PRG
rem    python source\gpc\compile_shared.py --drive GPC-BASIC-TOOLS-SRC\GPC-GUI-HELPER GPC.GUI.SRC.PRG GPC.GUI.PRG GPC.GUI.MAP
rem ---------------------------------------------------------------------------
setlocal
for %%I in ("%~dp0..") do set "ROOT=%%~fI\"
set "DRIVE=%ROOT%GPC-BASIC-TOOLS-SRC\GPC-GUI-HELPER"
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
if not exist "%DRIVE%\GPC.GUI.PRG" (
	echo.
	echo   GPC-BASIC-TOOLS-SRC\GPC-GUI-HELPER\GPC.GUI.PRG is not built.
	echo   See the rebuild lines at the top of this file.
	echo.
	exit /b 1
)
if not exist "%DRIVE%\GPC.BIN" (
	echo.
	echo   GPC-BASIC-TOOLS-SRC\GPC-GUI-HELPER\GPC.BIN is missing -- COMPILE has nothing
	echo   to hand off to. Copy it from GPC-BASIC-TOOLS-SRC\GPB-MODS-TESTING.
	echo.
	exit /b 1
)

"%X16EMU%" -rom "%ROM%" -fsroot "%DRIVE%" -scale 2 -sound none -prg "%DRIVE%\GPC.GUI.PRG" -run
endlocal
