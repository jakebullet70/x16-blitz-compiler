@echo off
rem ---------------------------------------------------------------------------
rem  kvbanked-demo.bat -- run KV-BANKED, a settings editor whose library runs
rem  from RAM banks and whose settings sit in a KV bank, in a VISIBLE window.
rem  The drive is the sample folder, and SETTINGS.KV is saved there.
rem  KV-BANKED.PRG is compiled EMBEDDED, so it needs no GPC.RT.nnn.BIN beside
rem  it. Its KV-BANKED.OVL must sit beside it.
rem
rem  Source: GPC-BASIC-TOOLS-SRC\KV-BANKED\KV-BANKED.BASL, on the modules in
rem  GPC-BASIC-TOOLS-SRC\KV-BANKED\GPC-BASIC\.
rem  To rebuild it, from the repository root:
rem    python source\gpc\samplesbuild.py KV-BANKED
rem ---------------------------------------------------------------------------
setlocal
for %%I in ("%~dp0..") do set "ROOT=%%~fI\"
set "DRIVE=%ROOT%GPC-BASIC-TOOLS-SRC\KV-BANKED"
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
for %%P in (KV-BANKED.PRG KV-BANKED.OVL) do (
	if not exist "%DRIVE%\%%P" (
		echo.
		echo   GPC-BASIC-TOOLS-SRC\KV-BANKED\%%P is not built.
		echo   See the notes at the top of this file.
		echo.
		exit /b 1
	)
)

"%X16EMU%" -rom "%ROM%" -fsroot "%DRIVE%" -scale 2 -sound none -prg "%DRIVE%\KV-BANKED.PRG" -run
endlocal
