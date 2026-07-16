@echo off
setlocal

rem ---------------------------------------------------------------------------
rem  Launch Box16 with the testing/ directory as its drive, so LOAD "GPC.PRG"
rem  and the rest just work. This .bat lives in the project root; the programs
rem  live in testing/ (the shipping release), and the emulator in bin/box16/.
rem
rem      box16.bat                 boot to BASIC in testing/
rem      box16.bat GPC.PRG         load the compiler and RUN it
rem      box16.bat OBJECT.PRG      run a compiled program
rem
rem  Box16 is the emulator with the debugger; x16emu is the one the test suites
rem  drive. Two things differ from x16emu and will bite you otherwise: Box16
rem  calls the host-directory flag -hypercall_path, NOT -fsroot, and -debug
rem  takes a break address rather than standing alone.
rem ---------------------------------------------------------------------------

set "ROOT=%~dp0"
set "ROOT=%ROOT:~0,-1%"
set "DRIVE=%ROOT%\testing"
set "BOX16=%ROOT%\bin\box16\Box16.exe"
set "ROM=%ROOT%\bin\box16\rom.bin"

rem  If Box16 exits at once complaining "SDL_OpenAudioDevice failed", this box
rem  has no usable audio endpoint -- uncomment the next line to run it silent.
rem set "SOUND=-sound none"

if not exist "%BOX16%" (
	echo Box16 not found: "%BOX16%"
	exit /b 1
)
if not exist "%ROM%" (
	echo ROM not found: "%ROM%"
	exit /b 1
)

pushd "%DRIVE%"
if "%~1"=="" (
	"%BOX16%" -rom "%ROM%" -hypercall_path "%DRIVE%" -scale 2 %SOUND%
) else (
	"%BOX16%" -rom "%ROM%" -hypercall_path "%DRIVE%" -scale 2 %SOUND% -prg "%~1" -run
)
popd

endlocal
