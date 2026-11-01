@echo off
setlocal EnableExtensions EnableDelayedExpansion

title Safe CP2077 Mod Cleaner v1.1 - Uninstaller
color 0C

echo.
echo  ======================================================================
echo   Safe CP2077 Mod Cleaner v1.1 - UNINSTALLER
echo  ======================================================================
echo.
echo   This will PERMANENTLY DELETE the following from this folder:
echo.
echo     - Safe_Mod_Cleaner.ps1
echo     - Safe_Mod_Cleaner.bat
echo     - New-CleanManifest.ps1
echo     - Cyberpunk_clean.json
echo     - RESTORE_HERE.bat (if present in this folder)
echo     - _MOD_REMOVER_BACKUPS\  (including ALL your backups!)
echo     - Uninstall.bat          (this file)
echo.
echo  ======================================================================
echo.
echo   [!] WARNING: All backups in _MOD_REMOVER_BACKUPS will be LOST!
echo       If you still need to restore mods, run Safe_Mod_Cleaner.bat
echo       and use the Restore option BEFORE uninstalling.
echo.
echo  ======================================================================
echo.

set /p CONFIRM="  Type 'UNINSTALL' to confirm: "

if /i not "%CONFIRM%"=="UNINSTALL" (
    echo.
    echo   Aborted. Nothing was deleted.
    echo.
    pause
    exit /b 2
)

echo.
echo   Deleting files...
echo.

set "SCRIPT_DIR=%~dp0"

if exist "%SCRIPT_DIR%Safe_Mod_Cleaner.ps1" (
    del /f /q "%SCRIPT_DIR%Safe_Mod_Cleaner.ps1" >nul 2>&1
    if not exist "%SCRIPT_DIR%Safe_Mod_Cleaner.ps1" echo     [OK] Safe_Mod_Cleaner.ps1
    else echo     [!] Safe_Mod_Cleaner.ps1 (locked or missing)
)

if exist "%SCRIPT_DIR%Safe_Mod_Cleaner.bat" (
    del /f /q "%SCRIPT_DIR%Safe_Mod_Cleaner.bat" >nul 2>&1
    if not exist "%SCRIPT_DIR%Safe_Mod_Cleaner.bat" echo     [OK] Safe_Mod_Cleaner.bat
    else echo     [!] Safe_Mod_Cleaner.bat (locked or missing)
)

if exist "%SCRIPT_DIR%New-CleanManifest.ps1" (
    del /f /q "%SCRIPT_DIR%New-CleanManifest.ps1" >nul 2>&1
    if not exist "%SCRIPT_DIR%New-CleanManifest.ps1" echo     [OK] New-CleanManifest.ps1
    else echo     [!] New-CleanManifest.ps1 (locked or missing)
)

if exist "%SCRIPT_DIR%Cyberpunk_clean.json" (
    del /f /q "%SCRIPT_DIR%Cyberpunk_clean.json" >nul 2>&1
    if not exist "%SCRIPT_DIR%Cyberpunk_clean.json" echo     [OK] Cyberpunk_clean.json
    else echo     [!] Cyberpunk_clean.json (locked or missing)
)

if exist "%SCRIPT_DIR%RESTORE_HERE.bat" (
    del /f /q "%SCRIPT_DIR%RESTORE_HERE.bat" >nul 2>&1
    if not exist "%SCRIPT_DIR%RESTORE_HERE.bat" echo     [OK] RESTORE_HERE.bat
    else echo     [!] RESTORE_HERE.bat (locked or missing)
)

for %%f in ("%SCRIPT_DIR%_modclean_report_*.json") do (
    del /f /q "%%f" >nul 2>&1
)

if exist "%SCRIPT_DIR%_MOD_REMOVER_BACKUPS" (
    rmdir /s /q "%SCRIPT_DIR%_MOD_REMOVER_BACKUPS" >nul 2>&1
    if not exist "%SCRIPT_DIR%_MOD_REMOVER_BACKUPS" echo     [OK] _MOD_REMOVER_BACKUPS\
    else echo     [!] _MOD_REMOVER_BACKUPS\ (some files may be locked)
)

echo.
echo   Cleanup complete.
echo.

set "SELF=%~f0"
set "HELPER=%TEMP%\uninstall_helper_%RANDOM%.bat"

(
    echo @echo off
    echo timeout /t 1 /nobreak ^>nul
    echo if exist "!SELF!" del /f /q "!SELF!"
    echo del /f /q "%%~f0"
) > "%HELPER%"

start "" /b cmd /c "%HELPER%" >nul 2>&1

echo   Uninstaller will close itself now.
echo.
timeout /t 2 /nobreak >nul

exit /b 0