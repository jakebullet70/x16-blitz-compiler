@echo off
rem ---------------------------------------------------------------------------
rem  editor-demo.bat -- run GPC EDIT, the sample text editor, in a VISIBLE window.
rem
rem      ESC             open the menu bar (lands on File)
rem      ALT+F/S/H       open File, Search or Help directly
rem      F/S/H           switch menus once the bar is open, as do LEFT/RIGHT
rem      UP/DOWN         move the highlight     RETURN chooses     ESC cancels
rem      F2              save                   F3      find next
rem      HOME/END        start/end of line      PGUP/PGDN  a screen at a time
rem      INS             toggle insert/overwrite
rem
rem  It opens TEST.MD from the drive directory on startup, so there is something
rem  on screen to move around in. NOTE THAT SAVES LAND IN samples\editor -- the
rem  editor's drive is that directory, so File>Save overwrites the real TEST.MD.
rem  git restore samples/editor/TEST.MD puts it back.
rem
rem  Source: samples\editor\EDITOR.BASL + STORE.BASL, on GPB, THEME, APPSYS,
rem  STASH, MENUVERT, MENUBAR, LINEINPUT and GUI -- all shipped in
rem  samples\editor\GPC-BASIC\ beside the sample, so a rebuild needs nothing
rem  from GPC-BASIC\. MENUBAR draws and measures the bar; MENUVERT drives the
rem  dropdown; STASH is what GUI.OPEN saves the covered cells with.
rem
rem  C.EDITOR.PRG is the COMPILED object and is checked in beside the source.
rem  To rebuild it:
rem    1. copy the .INC.BL files up out of samples\editor\GPC-BASIC\
rem       so they sit beside EDITOR.BASL (all eight of them)
rem    2. python source\gpc\build_basl.py EDITOR.BASL EDITOR.PRG
rem    3. compile EDITOR.PRG with GPC.BIN, and keep the object as C.EDITOR.PRG
rem ---------------------------------------------------------------------------
setlocal
set "ROOT=%~dp0"
set "DRIVE=%ROOT%samples\editor"
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
if not exist "%DRIVE%\C.EDITOR.PRG" (
	echo.
	echo   samples\editor\C.EDITOR.PRG is not built.
	echo   See the notes at the top of this file for the three steps.
	echo.
	exit /b 1
)

"%X16EMU%" -rom "%ROM%" -fsroot "%DRIVE%" -scale 2 -sound none -prg "%DRIVE%\C.EDITOR.PRG" -run
endlocal
