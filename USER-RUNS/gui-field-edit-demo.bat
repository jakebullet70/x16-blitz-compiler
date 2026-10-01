@echo off
rem ---------------------------------------------------------------------------
rem  gui-field-edit-demo.bat -- run GUI-FIELD-EDIT, the rental counter of a
rem  video store on one full-screen form of 28 controls, in a VISIBLE window.
rem  The drive is the sample folder.
rem  GUI-FIELD-EDIT.PRG is compiled EMBEDDED, so it needs no GPC.RT.nnn.BIN
rem  beside it. Its GUI-FIELD-EDIT.OVL must sit beside it.
rem
rem  Source: GPC-BASIC-TOOLS-SRC\GUI-FIELD-EDIT\GUI-FIELD-EDIT.BASL,
rem  on the modules in GPC-BASIC-TOOLS-SRC\GUI-FIELD-EDIT\GPC-BASIC\.
rem  To rebuild it, from the repository root:
rem    python source\gpc\samplesbuild.py GUI-FIELD-EDIT
rem ---------------------------------------------------------------------------
setlocal
for %%I in ("%~dp0..") do set "ROOT=%%~fI\"
set "DRIVE=%ROOT%GPC-BASIC-TOOLS-SRC\GUI-FIELD-EDIT"
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
for %%P in (GUI-FIELD-EDIT.PRG GUI-FIELD-EDIT.OVL) do (
	if not exist "%DRIVE%\%%P" (
		echo.
		echo   GPC-BASIC-TOOLS-SRC\GUI-FIELD-EDIT\%%P is not built.
		echo   See the notes at the top of this file.
		echo.
		exit /b 1
	)
)

"%X16EMU%" -rom "%ROM%" -fsroot "%DRIVE%" -scale 2 -sound none -prg "%DRIVE%\GUI-FIELD-EDIT.PRG" -run
endlocal
