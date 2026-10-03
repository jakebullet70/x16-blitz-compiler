@echo off
rem ---------------------------------------------------------------------------
rem  turbo-gpc-demo.bat -- run TURBO GPC, the editor, in a window.
rem
rem  The emulator mounts GPC-BASIC-TOOLS-SRC. turbo-gpc-demo.bas changes into
rem  TURBO-GPC, loads TURBO.PRG and runs it. The runtime comes from /GPC/.
rem  A name typed at the Open prompt is a file of TURBO-GPC. TURBO.BASL is one.
rem
rem  -noemucmdkeys leaves Ctrl+F and the emulator's other command keys to
rem  the editor. Ctrl+V does not paste.
rem
rem  To rebuild TURBO.PRG, from the repository root:
rem    python GPC-BASIC-TOOLS-SRC\TURBO-GPC\build.py
rem ---------------------------------------------------------------------------
setlocal
for %%I in ("%~dp0..") do set "ROOT=%%~fI\"
set "SAMPLES=%ROOT%GPC-BASIC-TOOLS-SRC"
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
if not exist "%SAMPLES%\TURBO-GPC\TURBO.PRG" (
	echo.
	echo   GPC-BASIC-TOOLS-SRC\TURBO-GPC\TURBO.PRG is not built. From the project root:
	echo     python GPC-BASIC-TOOLS-SRC\TURBO-GPC\build.py
	echo.
	exit /b 1
)

"%X16EMU%" -rom "%ROM%" -fsroot "%SAMPLES%" -scale 2 -sound none -noemucmdkeys -bas "%~dp0turbo-gpc-demo.bas"
endlocal
