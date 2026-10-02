@echo off
rem ---------------------------------------------------------------------------
rem  kv-bin-store-demo.bat -- run KV-BIN-STORE, a registry editor for a KVBIN
rem  store, the file of fixed records KVBIN.INC.BL keeps keys and values in,
rem  in a VISIBLE window.
rem  The drive is the sample folder, and SETTINGS.KVB is made there on the
rem  first run.
rem  KV-BIN-STORE.PRG is compiled EMBEDDED, so it needs no GPC.RT.nnn.BIN
rem  beside it. Its KV-BIN-STORE.OVL must sit beside it.
rem
rem  Source: GPC-BASIC-TOOLS-SRC\KV-BIN-STORE\KV-BIN-STORE.BASL, on the modules
rem  in GPC-BASIC-TOOLS-SRC\KV-BIN-STORE\GPC-BASIC\.
rem  To rebuild it, from the repository root:
rem    python source\gpc\samplesbuild.py KV-BIN-STORE
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
for %%P in (KV-BIN-STORE.PRG KV-BIN-STORE.OVL) do (
	if not exist "%DRIVE%\%%P" (
		echo.
		echo   GPC-BASIC-TOOLS-SRC\KV-BIN-STORE\%%P is not built.
		echo   See the notes at the top of this file.
		echo.
		exit /b 1
	)
)

"%X16EMU%" -rom "%ROM%" -fsroot "%DRIVE%" -scale 2 -sound none -prg "%DRIVE%\KV-BIN-STORE.PRG" -run
endlocal
