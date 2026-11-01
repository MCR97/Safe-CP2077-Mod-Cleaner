# =====================================================================
# Safe Cyberpunk 2077 Mod Cleaner v1.0
# Copyright (c) 2026 MCR777
# Licensed under MIT License
# =====================================================================
@echo off
setlocal EnableExtensions EnableDelayedExpansion
title Safe Cyberpunk 2077 Mod Cleaner v1.0
color 0B

set "SCRIPT_DIR=%~dp0"
set "PS_SCRIPT=%SCRIPT_DIR%Safe_Mod_Cleaner.ps1"
set "JSON_FILE=%SCRIPT_DIR%Cyberpunk_clean.json"
set "GEN_SCRIPT=%SCRIPT_DIR%New-CleanManifest.ps1"

where powershell >nul 2>nul
if errorlevel 1 (
    echo [ERROR] PowerShell was not found.
    pause
    exit /b 1
)
if not exist "%PS_SCRIPT%" (
    echo [ERROR] Safe_Mod_Cleaner.ps1 is missing in folder:
    echo   %PS_SCRIPT%
    pause
    exit /b 1
)
if not exist "%JSON_FILE%" (
    echo [WARNING] Cyberpunk_clean.json is missing.
    echo   Please run New-CleanManifest.ps1 first (menu option 7)
    echo   or place the file manually in this folder.
    echo.
)

if "%~1"=="" (
    for %%I in ("%~dp0.") do set "GAME_PATH=%%~fI"
) else (
    for %%I in ("%~1.") do set "GAME_PATH=%%~fI"
)

:MENU
cls
echo.
echo  ================================================================
echo   Safe Cyberpunk 2077 Mod Cleaner v1.0
echo  ================================================================
echo   Target folder: %GAME_PATH%
echo  ----------------------------------------------------------------
echo.
echo   [1]  Analyze                  Show only, no changes
echo   [2]  Dry-Run                  Simulates Reset
echo   [3]  RESET TO VANILLA         Removes all mods, auto-repairs
echo                                 cache/config from snapshot
echo   [4]  NUCLEAR OPTION           Full reset + force vanilla
echo                                 cache/config (no GOG verify needed)
echo   [5]  List Backups             Show all available backups
echo   [6]  Restore                  Restore from backup
echo   [7]  Create Vanilla Manifest  (Generator)
echo   [8]  Recreate Snapshot        Recreate Vanilla Snapshot
echo   [0]  Exit
echo.
echo  ----------------------------------------------------------------
echo   Advanced usage:
echo     Safe_Mod_Cleaner.bat "C:\Path\to\Game"
echo  ================================================================
echo.
set "CHOICE="
set /p CHOICE="  Selection (0-8): "

if "%CHOICE%"=="1" goto OPT_1
if "%CHOICE%"=="2" goto OPT_2
if "%CHOICE%"=="3" goto OPT_3
if "%CHOICE%"=="4" goto OPT_4
if "%CHOICE%"=="5" goto OPT_5
if "%CHOICE%"=="6" goto OPT_6
if "%CHOICE%"=="7" goto OPT_7
if "%CHOICE%"=="8" goto OPT_8
if "%CHOICE%"=="0" goto END
echo.
echo  [!] Invalid selection.
timeout /t 2 >nul
goto MENU

:OPT_1
powershell -NoProfile -ExecutionPolicy Bypass -File "%PS_SCRIPT%" -GamePath "%GAME_PATH%" -CompareOnly
goto AFTER

:OPT_2
powershell -NoProfile -ExecutionPolicy Bypass -File "%PS_SCRIPT%" -GamePath "%GAME_PATH%" -DryRun
goto AFTER

:OPT_3
powershell -NoProfile -ExecutionPolicy Bypass -File "%PS_SCRIPT%" -GamePath "%GAME_PATH%"
goto AFTER

:OPT_4
echo.
echo  ======================================================================
echo   You have selected the NUCLEAR OPTION.
echo   This will force-reset ALL files to vanilla state.
echo   No GOG/Steam Verify needed - snapshot restores everything!
echo  ======================================================================
echo.
set /p CONFIRM="  Really proceed? (Y/N): "
if /i not "%CONFIRM%"=="Y" goto MENU
powershell -NoProfile -ExecutionPolicy Bypass -File "%PS_SCRIPT%" -GamePath "%GAME_PATH%" -NuclearOption
goto AFTER

:OPT_5
powershell -NoProfile -ExecutionPolicy Bypass -File "%PS_SCRIPT%" -GamePath "%GAME_PATH%" -ListBackups
goto AFTER

:OPT_6
powershell -NoProfile -ExecutionPolicy Bypass -File "%PS_SCRIPT%" -GamePath "%GAME_PATH%" -Restore
goto AFTER

:OPT_7
if not exist "%GEN_SCRIPT%" (
    echo.
    echo  [ERROR] New-CleanManifest.ps1 is missing:
    echo    %GEN_SCRIPT%
    pause
    goto MENU
)
powershell -NoProfile -ExecutionPolicy Bypass -File "%GEN_SCRIPT%" -GamePath "%GAME_PATH%"
goto AFTER

:OPT_8
echo.
echo  [!] Snapshot will be recreated.
echo      Make sure the game is VANILLA (no active mods).
echo.
set /p CONFIRM="  Continue? (Y/N): "
if /i not "%CONFIRM%"=="Y" goto MENU
powershell -NoProfile -ExecutionPolicy Bypass -File "%PS_SCRIPT%" -GamePath "%GAME_PATH%" -CompareOnly -ForceResnap
goto AFTER

:AFTER
echo.
echo  ---------------------------------------------------------------
set /p BACK="  Return to menu? (Y/N): "
if /i "%BACK%"=="Y" goto MENU
goto END

:END
endlocal
exit /b 0