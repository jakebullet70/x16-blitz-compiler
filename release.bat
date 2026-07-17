@echo off
rem ***************************************************************************
rem  release.bat -- build x16-blitz-compiler and package it into release.zip.
rem
rem  Every recipe in this tree is POSIX, so the build is driven through Git
rem  Bash. This wrapper just puts GNU make + 64tass on PATH and calls release.sh.
rem
rem  Usage:
rem     release          full build (libs, engine, shared runtime, front end),
rem                      then package testing/ + docs into release.zip
rem     release zip      package the CURRENT build only -- no rebuild, no bump
rem ***************************************************************************
setlocal

rem --- locate Git Bash ------------------------------------------------------
set "BASH=C:\Program Files\Git\bin\bash.exe"
if not exist "%BASH%" set "BASH=C:\Program Files (x86)\Git\bin\bash.exe"
if not exist "%BASH%" (
    echo ERROR: Git Bash not found. Install Git for Windows.
    exit /b 1
)

rem --- run under bash (PATH set inside so make + 64tass resolve) -------------
"%BASH%" -lc "cd \"$(cygpath -u '%~dp0')\" && export PATH=\"/c/Users/Admin/AppData/Local/Microsoft/WinGet/Links:/c/8bitProgramming/64tass-1.60:$PATH\" && ./release.sh %*"
exit /b %ERRORLEVEL%
