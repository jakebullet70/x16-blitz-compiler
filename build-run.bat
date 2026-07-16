@echo off
rem ***************************************************************************
rem  build-run.bat -- self-contained: build EVERYTHING, then run the emulator.
rem
rem  Builds the libraries + compiler engine (make libs), packages the release
rem  (make release), builds the GPC.PRG front end (make -C source/gpc release),
rem  then launches x16emu on GPC.PRG (which chain-loads GPC.BLITZ.BIN).
rem
rem  The build recipes are all POSIX, so the make part is driven through Git
rem  Bash. The emulator is launched from this batch file (not nested in bash)
rem  so its SDL window is a normal child of cmd.
rem
rem  Just double-click it, or run:  build-run
rem ***************************************************************************
setlocal

rem --- locate Git Bash ------------------------------------------------------
set "BASH=C:\Program Files\Git\bin\bash.exe"
if not exist "%BASH%" set "BASH=C:\Program Files (x86)\Git\bin\bash.exe"
if not exist "%BASH%" (
    echo ERROR: Git Bash not found. Install Git for Windows.
    exit /b 1
)

rem --- build everything under bash (PATH set inside so make + 64tass resolve)-
echo == Building (libs, release, GPC.PRG) ==
"%BASH%" -lc "cd \"$(cygpath -u '%~dp0')\" && export PATH=\"/c/Users/Admin/AppData/Local/Microsoft/WinGet/Links:/c/8bitProgramming/64tass-1.60:$PATH\" && set -e && make libs && make release && make -C source/gpc release"
if errorlevel 1 (
    echo == BUILD FAILED -- not launching emulator ==
    exit /b %ERRORLEVEL%
)

rem --- launch the emulator on the freshly built compiler --------------------
echo == launching x16emu with GPC.PRG ==
call "%~dp0release\x16emu.bat" GPC.PRG
exit /b %ERRORLEVEL%
