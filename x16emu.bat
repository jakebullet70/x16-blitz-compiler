@echo off
setlocal

rem ---------------------------------------------------------------------------
rem  Launch x16emu with the testing/ directory as its drive, so LOAD "GPC.PRG"
rem  and the rest just work. This .bat lives in the project root; the programs
rem  live in testing/ (the shipping release), and the emulator in bin/x16emu/.
rem
rem      x16emu.bat                boot to BASIC in testing/
rem      x16emu.bat GPC.PRG        load the compiler and RUN it
rem      x16emu.bat OBJECT.PRG     run a compiled program
rem
rem  x16emu is the emulator the test suites drive; box16.bat runs the other one
rem  (the debugger). Two things differ from Box16 and will bite you otherwise:
rem  x16emu calls the host-directory flag -fsroot, NOT -hypercall_path, and it
rem  boots the program with -run (issues RUN, which a BASIC-stubbed compiled
rem  .PRG needs). Sprite collision is worth a mention: x16emu emulates VERA
rem  sprite collisions, so games that read $9F27 behave here as on hardware.
rem ---------------------------------------------------------------------------

set "ROOT=%~dp0"
set "ROOT=%ROOT:~0,-1%"
set "DRIVE=%ROOT%\testing"
set "X16EMU=%ROOT%\bin\x16emu\x16emu.exe"
set "ROM=%ROOT%\bin\x16emu\rom.bin"

rem  If x16emu exits at once complaining "SDL_OpenAudioDevice failed", this box
rem  has no usable audio endpoint -- uncomment the next line to run it silent.
rem set "SOUND=-sound none"

if not exist "%X16EMU%" (
	echo x16emu not found: "%X16EMU%"
	exit /b 1
)
if not exist "%ROM%" (
	echo ROM not found: "%ROM%"
	exit /b 1
)

pushd "%DRIVE%"
if "%~1"=="" (
	"%X16EMU%" -rom "%ROM%" -fsroot "%DRIVE%" -scale 2 %SOUND%
) else (
	"%X16EMU%" -rom "%ROM%" -fsroot "%DRIVE%" -scale 2 %SOUND% -prg "%~1" -run
)
popd

endlocal
