@echo off
rem ---------------------------------------------------------------------------
rem  tmp-shell.bat -- open a command prompt inside the staged release, release\TMP.
rem
rem  This is the release tree as a user gets it out of the zip, so a DIR here is
rem  what they see after extracting. Nothing outside release\TMP is in the zip.
rem
rem  Stage it first, from Git Bash:
rem
rem      ./release.sh stage        stage release\TMP from the current build
rem      ./release.sh zip          zip release\TMP once it looks right
rem
rem  WARNING: release.sh stage WIPES release\TMP and refills it. Anything edited
rem  by hand in there is gone on the next stage. Change release.sh instead.
rem
rem  XFMGR\ and XT are DEV ONLY. They are staged for tmp-emu.bat and left out of
rem  the zip, so ignore them when judging what a user receives.
rem
rem  A new console window opens on release\TMP. Type EXIT to close it.
rem  tmp-emu.bat boots the emulator on this same tree.
rem ---------------------------------------------------------------------------
setlocal
for %%I in ("%~dp0..") do set "ROOT=%%~fI\"
set "DRIVE=%ROOT%release\TMP"

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

echo.
echo   Staged release: %DRIVE%
echo   This is the zip contents. XFMGR\ and XT are dev only and are not zipped.
echo   A console window is opening there. Type EXIT to close it.
echo.

start "RELEASE TMP" /D "%DRIVE%" cmd /k dir
endlocal
