@echo off
rem ***************************************************************************
rem  build.bat -- one-click full build of x16-blitz-compiler on Windows.
rem
rem  Every recipe in this tree is POSIX, so the build is driven through Git
rem  Bash. This wrapper just puts GNU make + 64tass on PATH and calls it.
rem
rem  Usage:
rem     build            build libs + release (the compiler + BLITZ.PRG)
rem     build gpc        also build GPC.PRG (the BASLOAD front end)
rem     build run        build libs + release, then launch x16emu on GPC.PRG
rem     build clean      clean the source tree
rem ***************************************************************************
setlocal

rem --- locate Git Bash ------------------------------------------------------
set "BASH=C:\Program Files\Git\bin\bash.exe"
if not exist "%BASH%" set "BASH=C:\Program Files (x86)\Git\bin\bash.exe"
if not exist "%BASH%" (
    echo ERROR: Git Bash not found. Install Git for Windows.
    exit /b 1
)

rem --- "run" = build (libs + release) here, then launch the emulator below ----
rem  The emulator is launched from this batch file, NOT from inside bash, so the
rem  SDL window is a normal child of cmd instead of nested two shells deep.
set "BUILDARG=%*"
if /i "%~1"=="run" set "BUILDARG="

rem --- run the build under bash (PATH set inside so make + 64tass resolve) ---
"%BASH%" -lc "cd \"$(cygpath -u '%~dp0')\" && export PATH=\"/c/Users/Admin/AppData/Local/Microsoft/WinGet/Links:/c/8bitProgramming/64tass-1.60:$PATH\" && ./build.sh %BUILDARG%"
if errorlevel 1 exit /b %ERRORLEVEL%

rem --- if "run" was requested, launch the emulator on the freshly built PRG ----
if /i "%~1"=="run" (
    echo == launching x16emu with GPC.PRG ==
    call "%~dp0x16emu.bat" GPC.PRG
)
exit /b %ERRORLEVEL%
