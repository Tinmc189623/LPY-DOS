@echo off
REM ===========================================================================
REM  LPY-DOS SDK build script (Windows CMD / BAT)
REM  Auto-locate FASM: LPYDOS_FASM env var -> PATH -> common install dirs.
REM  If not found, print install hint; otherwise compile examples under
REM  sdk\examples to .COM.
REM
REM  Usage: build.bat [all|hello|app]     default all
REM  Copyright (C) 2026 Nexsteaduser. Licensed under GPL v3 or later.
REM ===========================================================================
setlocal

REM ---- Example source dir (relative to this script) ----
set "EXDIR=%~dp0examples"

REM ---- Locate FASM ----
set "FASM="

REM 1) env var LPYDOS_FASM
if defined LPYDOS_FASM (
    if exist "%LPYDOS_FASM%" set "FASM=%LPYDOS_FASM%"
)

REM 2) search PATH
if not defined FASM (
    where fasm.exe >nul 2>&1
    if not errorlevel 1 set "FASM=fasm"
)

REM 3) common install paths
if not defined FASM (
    for %%p in ("D:\fasm\FASM.EXE" "C:\fasm\FASM.EXE" "D:\fasm\fasm.exe" "C:\fasm\fasm.exe") do (
        if exist "%%~p" set "FASM=%%~p"
    )
)

if not defined FASM (
    echo [ERROR] FASM assembler not found.
    echo   Please download it from https://flatassembler.net/
    echo   Or set the environment variable LPYDOS_FASM to its path.
    exit /b 1
)
echo Using FASM: %FASM%

REM ---- Select target ----
set "TARGET=%~1"
if "%TARGET%"=="" set "TARGET=all"

echo == LPY-DOS SDK example build ==

if /i "%TARGET%"=="all" (
    for %%f in ("%EXDIR%\*.asm") do (
        echo   FASM  %%~nxf
        "%FASM%" "%%f" "%%~dpnf.COM"
        if errorlevel 1 echo Build failed: %%~nxf
    )
) else (
    "%FASM%" "%EXDIR%\%TARGET%.asm" "%EXDIR%\%TARGET%.COM"
    if errorlevel 1 (
        echo Build failed: %TARGET%.
        exit /b 1
    )
)

echo == Done. Put the generated .COM into the system image to run it. ==
endlocal