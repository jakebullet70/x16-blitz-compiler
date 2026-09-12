@echo off
rem ---------------------------------------------------------------------------
rem  tmp-emu.bat -- boot the emulator on the STAGED RELEASE, release\TMP.
rem
rem  This is how the release gets looked at before it is packaged: the drive the
rem  emulator mounts is the release tree itself, so what runs here is exactly what
rem  a user extracts from the zip.
rem
rem  Stage it first, from Git Bash:
rem
rem      ./release.sh stage        stage release\TMP from the current build
rem      ./release.sh zip          zip release\TMP once it looks right
rem
rem  It boots to READY, not into a program, because there are several to try:
rem
rem      RUN "XT"                  XFMGR, the file manager -- XT is a shim that
rem                                LOADs /XFMGR/XFMGR.PRG
rem      RUN "GPC.PRG"             the compiler front end
rem      RUN "GPB.HELP.PRG"        the on-machine reference
rem      DOS"$                     the directory
rem
rem  A sample lives in its own folder, so CD into it and run it:
rem
rem      DOS"CD:SAMPLES"           then CD:GPBMODS, then RUN "GPBMODS.PRG"
rem
rem  Both of the things a sample loads still resolve from down there. A region
rem  overlay (.Bnn) is loaded from beside the program, and the shared runtime is
rem  fetched from the drive root with a leading slash.
rem
rem  XFMGR AND XT ARE DEV ONLY. release.sh stages them into TMP for this bat and
rem  leaves them out of the zip.
rem ---------------------------------------------------------------------------
setlocal
set "ROOT=%~dp0"
set "DRIVE=%ROOT%release\TMP"
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
if not exist "%DRIVE%" (
	echo.
	echo   release\TMP does not exist -- nothing is staged.
	echo   From Git Bash:   ./release.sh stage
	echo.
	exit /b 1
)
if not exist "%DRIVE%\GPC.BIN" (
	echo.
	echo   release\TMP has no GPC.BIN, so the staging is incomplete.
	echo   From Git Bash:   ./release.sh stage
	echo.
	exit /b 1
)

"%X16EMU%" -rom "%ROM%" -fsroot "%DRIVE%" -scale 2 -sound none
endlocal
