@echo off
setlocal EnableExtensions EnableDelayedExpansion

title Safe Cyberpunk 2077 Mod Cleaner v1.1
color 0E

set "SCRIPT_DIR=%~dp0"
set "PS_SCRIPT=%SCRIPT_DIR%Safe_Mod_Cleaner.ps1"
set "JSON_FILE=%SCRIPT_DIR%Cyberpunk_clean.json"
set "GEN_SCRIPT=%SCRIPT_DIR%New-CleanManifest.ps1"

REM ============================================================
REM Pre-checks
REM ============================================================

where powershell >nul 2>nul
if errorlevel 1 (
    echo.
    echo   [!] CRITICAL: PowerShell runtime not found.
    echo       System cannot initialize cyberdeck interface.
    echo.
    pause
    exit /b 1
)

if not exist "%PS_SCRIPT%" (
    echo.
    echo   [!] CRITICAL: Core module missing.
    echo       Path: %PS_SCRIPT%
    echo.
    pause
    exit /b 1
)

REM ============================================================
REM Determine target path
REM ============================================================

if "%~1"=="" (
    for %%I in ("%~dp0.") do set "GAME_PATH=%%~fI"
) else (
    for %%I in ("%~1.") do set "GAME_PATH=%%~fI"
)

REM ============================================================
REM CYBERPUNK MENU
REM ============================================================

:MENU
cls
echo.
echo   =================================================================
echo        SAFE CYBERPUNK 2077 MOD CLEANER  //  v1.1
echo        [ CYBERDECK INTERFACE ]
echo   =================================================================
echo.
echo   TARGET: %GAME_PATH%
echo   -----------------------------------------------------------------
echo.
echo   [1] // SCAN_SYSTEM        - Analyze installation (safe, no changes)
echo   [2] // SIMULATE_BREACH    - Dry-run: preview what would be removed
echo   [3] // RESET_TO_VANILLA   - Full reset, auto-repair cache/config
echo   [4] // LIST_ARCHIVES      - Show all available backups
echo   [5] // RESTORE_BACKUP     - Restore mods from backup
echo   [6] // GEN_MANIFEST       - Create whitelist + initial snapshot
echo   [7] // REBUILD_SNAPSHOT   - Recreate vanilla cache/config snapshot
echo   [0] // JACK_OUT           - Exit cyberdeck
echo.
echo   -----------------------------------------------------------------
echo.

if not exist "%JSON_FILE%" (
    echo   [!] WARNING: Cyberpunk_clean.json not detected.
    echo       Run option [6] GEN_MANIFEST first to initialize whitelist.
    echo.
)

set "CHOICE="
set /p CHOICE="   root@cyberdeck:~# "

if "%CHOICE%"=="1" goto OPT_SCAN
if "%CHOICE%"=="2" goto OPT_DRYRUN
if "%CHOICE%"=="3" goto OPT_RESET
if "%CHOICE%"=="4" goto OPT_LIST
if "%CHOICE%"=="5" goto OPT_RESTORE
if "%CHOICE%"=="6" goto OPT_GEN_MANIFEST
if "%CHOICE%"=="7" goto OPT_REBUILD_SNAPSHOT
if "%CHOICE%"=="0" goto END

echo.
echo   [!] INVALID COMMAND - Access denied.
timeout /t 2 >nul
goto MENU

REM ============================================================
REM Operations
REM ============================================================

:OPT_SCAN
cls
echo.
echo   =================================================================
echo   [01] SCAN_SYSTEM - Analyzing installation...
echo   =================================================================
echo.
powershell -NoProfile -ExecutionPolicy Bypass -File "%PS_SCRIPT%" -GamePath "%GAME_PATH%" -CompareOnly
goto AFTER

:OPT_DRYRUN
cls
echo.
echo   =================================================================
echo   [02] SIMULATE_BREACH - Previewing removal targets...
echo   =================================================================
echo.
powershell -NoProfile -ExecutionPolicy Bypass -File "%PS_SCRIPT%" -GamePath "%GAME_PATH%" -DryRun
goto AFTER

:OPT_RESET
cls
echo.
echo   =================================================================
echo   [03] RESET_TO_VANILLA
echo   =================================================================
echo.
echo   This operation will:
echo     - Move all non-whitelisted files to a secure backup
echo     - Force cache/config back to vanilla state
echo     - Restore protected vanilla files from snapshot
echo.
echo   All vanilla files are protected by whitelist.
echo   -----------------------------------------------------------------
echo.
set /p CONFIRM="   Confirm operation? [Y/N]: "
if /i not "%CONFIRM%"=="Y" goto MENU
echo.
powershell -NoProfile -ExecutionPolicy Bypass -File "%PS_SCRIPT%" -GamePath "%GAME_PATH%"
goto AFTER

:OPT_LIST
cls
echo.
echo   =================================================================
echo   [04] LIST_ARCHIVES - Retrieving backup catalog...
echo   =================================================================
echo.
powershell -NoProfile -ExecutionPolicy Bypass -File "%PS_SCRIPT%" -GamePath "%GAME_PATH%" -ListBackups
goto AFTER

:OPT_RESTORE
cls
echo.
echo   =================================================================
echo   [05] RESTORE_BACKUP - Initiating restore protocol...
echo   =================================================================
echo.
powershell -NoProfile -ExecutionPolicy Bypass -File "%PS_SCRIPT%" -GamePath "%GAME_PATH%" -Restore
goto AFTER

:OPT_GEN_MANIFEST
cls
if not exist "%GEN_SCRIPT%" (
    echo.
    echo   [!] CRITICAL: Generator module not found.
    echo       Path: %GEN_SCRIPT%
    echo.
    pause
    goto MENU
)

echo.
echo   =================================================================
echo   [06] GEN_MANIFEST - Initializing whitelist generator...
echo   =================================================================
echo.
echo   This operation will:
echo     - Create Cyberpunk_clean.json from the current installation
echo     - Create the vanilla snapshot afterwards
echo.
echo   CRITICAL: Game must be in CLEAN VANILLA state!
echo   Run GOG/Steam Verify BEFORE executing this operation.
echo   -----------------------------------------------------------------
echo.
set /p CONFIRM="   Continue? [Y/N]: "
if /i not "%CONFIRM%"=="Y" goto MENU
echo.

powershell -NoProfile -ExecutionPolicy Bypass -File "%GEN_SCRIPT%" -GamePath "%GAME_PATH%"
if errorlevel 1 goto AFTER

echo.
echo   Creating initial vanilla snapshot...
echo.
powershell -NoProfile -ExecutionPolicy Bypass -File "%PS_SCRIPT%" -GamePath "%GAME_PATH%" -RebuildSnapshotOnly -Yes
goto AFTER

:OPT_REBUILD_SNAPSHOT
cls
echo.
echo   =================================================================
echo   [07] REBUILD_SNAPSHOT
echo   =================================================================
echo.
echo   WARNING: Game must be in CLEAN VANILLA state!
echo   This will overwrite the existing vanilla snapshot.
echo   -----------------------------------------------------------------
echo.
set /p CONFIRM="   Confirm rebuild? [Y/N]: "
if /i not "%CONFIRM%"=="Y" goto MENU
echo.
powershell -NoProfile -ExecutionPolicy Bypass -File "%PS_SCRIPT%" -GamePath "%GAME_PATH%" -RebuildSnapshotOnly -Yes
goto AFTER

:AFTER
echo.
echo   -----------------------------------------------------------------
echo.
set /p BACK="   Return to main menu? [Y/N]: "
if /i "%BACK%"=="Y" goto MENU
goto END

:END
cls
echo.
echo   =================================================================
echo        [ CONNECTION TERMINATED ]
echo        [ CYBERDECK OFFLINE ]
echo   =================================================================
echo.
endlocal
exit /b 0