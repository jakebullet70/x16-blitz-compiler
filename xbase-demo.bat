@echo off
rem ---------------------------------------------------------------------------
rem  xbase-demo.bat -- run XBASE, the dBASE-shaped record keeper, in a VISIBLE
rem  window.
rem
rem      ESC        opens the menu bar, and closes it again
rem      <- ->      walk the bar
rem      DOWN       open the dropdown under the marked item
rem      UP DOWN    walk the dropdown, RETURN chooses
rem      TAB        moves between the two areas of the screen
rem
rem  THERE ARE NO FUNCTION KEYS AND NO SHORTCUTS, and File Exit is the only way
rem  out. A disabled item is still drawn and still selectable; it says why when
rem  it is chosen. Nine commands are stubs that name what they need first --
rem  samples\XBASE\readme.md section 3 lists them.
rem
rem  NO DATABASE IS ON THE DRIVE YET. PARTS.DBF and SUPPLR.DBF come from
rem  MKFIX.BASL, which has not been built or run, so Open Database has nothing
rem  to open. The menus, the bar, the dialogs and the GUI in bank 4 are what
rem  this launch exercises.
rem
rem  THE DRIVE IS testing\, NOT the sample directory, and it needs more than the
rem  PRG. XBASE.PRG is compiled SHARED, so it loads the resident GPC.RT.nnn.BIN
rem  rather than carrying a copy; and it has one overlay, XBASE.B04, the CUA GUI
rem  library, which the bootstrap LOADs into bank 4 at startup. A missing one
rem  stops with ?OVL. Both live in testing\ beside the PRG.
rem
rem  Source: samples\XBASE\XBASE.BASL and XBMENUS.BASL, on the modules in
rem  samples\XBASE\GPC-BASIC\ beside them. See that folder's readme.md, and
rem  GPC-BASIC\BANKED-OR-NOT.md for why six of those modules come in two files.
rem ---------------------------------------------------------------------------
setlocal
set "ROOT=%~dp0"
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
if not exist "%DRIVE%\XBASE.PRG" (
	echo.
	echo   testing\XBASE.PRG is not built. From the project root:
	echo     python source\gpc\xbasebuild.py XBASE
	echo   which copies the sources and the library into testing\ and runs both
	echo   steps. Nothing else needs doing by hand.
	echo.
	exit /b 1
)
if not exist "%DRIVE%\XBASE.B04" (
	echo.
	echo   testing\XBASE.B04 is missing -- that is the GUI library overlay, and
	echo   XBASE stops with ?OVL without it. Rebuild:
	echo     python source\gpc\xbasebuild.py XBASE
	echo.
	exit /b 1
)

"%X16EMU%" -rom "%ROM%" -fsroot "%DRIVE%" -scale 2 -sound none -prg "%DRIVE%\XBASE.PRG" -run
endlocal
