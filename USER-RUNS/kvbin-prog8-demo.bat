@echo off
rem ---------------------------------------------------------------------------
rem  kvbin-prog8-demo.bat -- run KVBIN-PROG8, the Prog8 program on a KVBIN
rem  store, in a VISIBLE window.
rem  The drive is the sample folder. It works on SETTINGS.KVB, the store
rem  KV-BIN-STORE.PRG and KVBIN-BASIC.PRG work on, and makes an empty one when
rem  there is none.
rem
rem  Source: GPC-BASIC-TOOLS-SRC\KV-BIN-STORE\KVBIN-PROG8.P8.
rem  To rebuild it, from the repository root:
rem    python source\gpc\samplesbuild.py KVBIN-PROG8
rem ---------------------------------------------------------------------------
setlocal
for %%I in ("%~dp0..") do set "ROOT=%%~fI\"
set "DRIVE=%ROOT%GPC-BASIC-TOOLS-SRC\KV-BIN-STORE"
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
for %%P in (KVBIN-PROG8.PRG) do (
	if not exist "%DRIVE%\%%P" (
		echo.
		echo   GPC-BASIC-TOOLS-SRC\KV-BIN-STORE\%%P is not built.
		echo   See the notes at the top of this file.
		echo.
		exit /b 1
	)
)

"%X16EMU%" -rom "%ROM%" -fsroot "%DRIVE%" -scale 2 -sound none -prg "%DRIVE%\KVBIN-PROG8.PRG" -run
endlocal
