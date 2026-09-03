@echo off
rem ---------------------------------------------------------------------------
rem  cruncher-demo.bat -- run CRUNCH, the BASL source cruncher, in a VISIBLE window.
rem
rem  It asks seven questions. Bare RETURN takes the default on every one:
rem
rem      SOURCE FILE             DEMO.BASL   (bare RETURN quits)
rem      OUTPUT EXTENSION        CRU         -- the original is never touched
rem      JOIN LINES?             yes         -- the whole point
rem      COLLAPSE GP.IF BLOCKS?  yes         -- a simple block becomes one plain IF
rem      STRIP TRAILING REMS?    yes/no      -- ASK: it throws the comment away
rem      KEEP COMMENTS IN PLACE? yes         -- no = pack 32 more lines, comments drift
rem      MAX LINE LENGTH         250         -- BASLOAD's #MAXCOLUMN default
rem
rem  Then it chain-loads CRUNCH.BIN, which does the work and prints what it did.
rem  DEMO.BASL is deliberately loose -- one statement per line -- and carries every
rem  trap the engine has to survive: a colon inside a string, THEN inside a string
rem  and inside an identifier, a real IF..THEN, a label, DATA, and three GP.IF
rem  blocks of which only some may be collapsed. Read DEMO.CRU afterwards.
rem
rem  NOTE THAT THE DRIVE IS samples\cruncher, so DEMO.CRU lands in the repo beside
rem  the source. git clean -f samples/cruncher/DEMO.CRU tidies up.
rem
rem  TO CRUNCH THE EDITOR instead: copy CRUNCH.PRG and CRUNCH.BIN into
rem  samples\editor, point this script's DRIVE at that directory, and answer
rem  EDITOR.BASL. Measured there: 449 joins and one collapse, object 26,411 ->
rem  26,189, and the editor's own self-check output byte-identical afterwards.
rem
rem  Source: samples\cruncher\CRUNCH.BASL (front end) + CRUNCHER.BASL (engine),
rem  on GPB and STRCASE, both shipped in samples\cruncher\GPC-BASIC\ beside the
rem  sample so a rebuild needs nothing from GPC-BASIC\. Both objects are EMBEDDED
rem  and checked in. See samples\cruncher\readme.md for the rebuild.
rem ---------------------------------------------------------------------------
setlocal
set "ROOT=%~dp0"
set "DRIVE=%ROOT%samples\cruncher"
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
if not exist "%DRIVE%\CRUNCH.PRG" (
	echo.
	echo   samples\cruncher\CRUNCH.PRG is not built.
	echo   See the rebuild section of samples\cruncher\readme.md.
	echo.
	exit /b 1
)
if not exist "%DRIVE%\CRUNCH.BIN" (
	echo.
	echo   samples\cruncher\CRUNCH.BIN is not built -- the front end has
	echo   nothing to hand off to. See samples\cruncher\readme.md.
	echo.
	exit /b 1
)

"%X16EMU%" -rom "%ROM%" -fsroot "%DRIVE%" -scale 2 -sound none -prg "%DRIVE%\CRUNCH.PRG" -run
endlocal
