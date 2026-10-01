@echo off
rem ---------------------------------------------------------------------------
rem  mandel-demo.bat -- the Mandelbrot speed duel, in a VISIBLE window. The
rem  drive is the sample folder.
rem
rem    mandel-demo.bat          all three in turn; close the window for the next
rem    mandel-demo.bat BASIC    MANDEL.SRC.PRG in ROM BASIC
rem    mandel-demo.bat GPC      MANDEL.PRG, the same source compiled
rem    mandel-demo.bat ASM      MANDELASM.PRG, the inner loop in GP.ASM
rem
rem  Source: GPC-BASIC-TOOLS-SRC\MANDELBROT-SPEED\MANDEL.BASL and MANDELASM.BASL.
rem  Both PRGs are compiled EMBEDDED and need no runtime file beside them.
rem  To rebuild them, from the repository root:
rem    python source\gpc\samplesbuild.py MANDEL MANDELASM
rem ---------------------------------------------------------------------------
setlocal
for %%I in ("%~dp0..") do set "ROOT=%%~fI\"
set "DRIVE=%ROOT%GPC-BASIC-TOOLS-SRC\MANDELBROT-SPEED"
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
for %%P in (MANDEL.SRC.PRG MANDEL.PRG MANDELASM.PRG) do (
	if not exist "%DRIVE%\%%P" (
		echo.
		echo   GPC-BASIC-TOOLS-SRC\MANDELBROT-SPEED\%%P is not built.
		echo   See the notes at the top of this file.
		echo.
		exit /b 1
	)
)

if /i "%~1"=="BASIC" call :run MANDEL.SRC.PRG & goto :done
if /i "%~1"=="GPC" call :run MANDEL.PRG & goto :done
if /i "%~1"=="ASM" call :run MANDELASM.PRG & goto :done
call :run MANDEL.SRC.PRG
call :run MANDEL.PRG
call :run MANDELASM.PRG
:done
endlocal
exit /b 0

:run
"%X16EMU%" -rom "%ROM%" -fsroot "%DRIVE%" -scale 2 -sound none -prg "%DRIVE%\%1" -run
exit /b 0
