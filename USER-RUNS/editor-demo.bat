@echo off
rem
rem  EDIT.PRG is the compiled object, checked in beside the source.
rem  To rebuild it, from the repository root:
rem    python source\gpc\build_basl.py --drive GPC-BASIC-TOOLS-SRC\edit EDIT.BASL EDIT.SRC.PRG
rem    python source\gpc\compile_shared.py --drive GPC-BASIC-TOOLS-SRC\edit --embedded EDIT.SRC.PRG EDIT.PRG EDIT.MAP
rem  Delete EDIT.SRC.PRG first: build_basl.py does not notice an edited #INCLUDE.
rem ---------------------------------------------------------------------------
setlocal
for %%I in ("%~dp0..") do set "ROOT=%%~fI\"
set "DRIVE=%ROOT%GPC-BASIC-TOOLS-SRC\edit"
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
if not exist "%DRIVE%\EDIT.PRG" (
	echo.
	echo   GPC-BASIC-TOOLS-SRC\edit\EDIT.PRG is not built.
	echo   See the notes at the top of this file.
	echo.
	exit /b 1
)

"%X16EMU%" -rom "%ROM%" -fsroot "%DRIVE%" -scale 2 -sound none -prg "%DRIVE%\EDIT.PRG" -run
endlocal
