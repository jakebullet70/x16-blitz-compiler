@echo off
rem ---------------------------------------------------------------------------
rem  color-demo.bat -- run COLOR-TEST, the colour scheme picker, in a VISIBLE window.
rem
rem  Three knobs, each a palette index 0-15. B, F and X arm one; the next 0-9 or
rem  A-F sets it, and any other key cancels the arm.
rem
rem      B   background      the page, shared by every role
rem      F   foreground      the text
rem      X   box             the frame
rem      T   next theme      CLASSIC, DARK, LIGHT -- and the knobs follow it
rem      Q   quit            restores the screen you started with
rem
rem  The bottom three lines are the scheme as THEME.CLR assignments, to copy into
rem  a THEME.LOAD branch in GPC-BASIC\THEME.INC.BL.
rem
rem  THE DRIVE IS testing\, NOT the sample directory. COLORTST.PRG is compiled
rem  SHARED, so it loads the resident GPC.RT.nnn.BIN rather than carrying a copy,
rem  and testing\ is where that runtime lives. The other demos point at their own
rem  sample folder because their objects are embedded.
rem
rem  Source: samples\color-test\COLORTST.BASL, on GPB, APPSYS and THEME, all three
rem  shipped in samples\color-test\GPC-BASIC\ beside it. See that folder's
rem  readme.md for the two-step rebuild.
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
if not exist "%DRIVE%\COLORTST.PRG" (
	echo.
	echo   testing\COLORTST.PRG is not built. From the project root:
	echo     python source\gpc\build_basl.py COLORTST.BASL COLORTST.SRC.PRG
	echo     python source\gpc\compile_shared.py COLORTST.SRC.PRG COLORTST.PRG
	echo   with samples\color-test\COLORTST.BASL copied into testing\ first.
	echo.
	exit /b 1
)

"%X16EMU%" -rom "%ROM%" -fsroot "%DRIVE%" -scale 2 -sound none -prg "%DRIVE%\COLORTST.PRG" -run
endlocal
