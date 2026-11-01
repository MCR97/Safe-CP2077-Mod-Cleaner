# =====================================================================
# Safe Cyberpunk 2077 Mod Cleaner v1.0
# Copyright (c) 2026 MCR777
# Licensed under MIT License
# =====================================================================
#Requires -Version 5.1
<#
=====================================================================
 New-CleanManifest.ps1  v1.0
 ---------------------------------------------------------------------
 Creates a Vanilla manifest (Cyberpunk_clean.json) from a CLEAN
 Cyberpunk 2077 installation, used as whitelist by Safe_Mod_Cleaner.

 CRITICAL: Before running this script, ALL mods must be removed!
=====================================================================
#>
[CmdletBinding()]
param(
    [Parameter(Position = 0)][string]$GamePath,
    [string]$OutputPath,
    [switch]$IncludeHashes,
    [switch]$Force,
    [switch]$Yes
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'Continue'

function Get-LP {
    param([string]$Path)
    if ($Path.StartsWith('\\?\')) { return $Path }
    $p = $Path.TrimEnd('\')
    if ($p.Length -eq 2 -and $p[1] -eq ':') { $p += '\' }
    return '\\?\' + $p
}
function Remove-LP {
    param([string]$Path)
    if ($Path.StartsWith('\\?\')) { return $Path.Substring(4) }
    return $Path
}

try {
    if ([string]::IsNullOrWhiteSpace($GamePath)) {
        if ($PSScriptRoot) { $GamePath = $PSScriptRoot } else { $GamePath = (Get-Location).Path }
    }
    $GamePath = [System.IO.Path]::GetFullPath($GamePath).TrimEnd('\')

    # =============================================================
    # CRITICAL PREREQUISITE WARNING
    # =============================================================
    Write-Host ''
    Write-Host '######################################################################' -ForegroundColor Red
    Write-Host '#                                                                    #' -ForegroundColor Red
    Write-Host '#   CRITICAL PREREQUISITE: CLEAN VANILLA INSTALLATION REQUIRED       #' -ForegroundColor Red
    Write-Host '#                                                                    #' -ForegroundColor Red
    Write-Host '######################################################################' -ForegroundColor Red
    Write-Host ''
    Write-Host 'This tool creates a whitelist of all vanilla files in your game.' -ForegroundColor Yellow
    Write-Host ''
    Write-Host 'If you run this tool while MODS are installed, those mod files will' -ForegroundColor Yellow
    Write-Host 'be INCORRECTLY marked as "vanilla" and the cleaner will NOT remove' -ForegroundColor Yellow
    Write-Host 'them later. This will BREAK the tool!' -ForegroundColor Yellow
    Write-Host ''
    Write-Host 'REQUIRED WORKFLOW:' -ForegroundColor Cyan
    Write-Host '  1. Run "Verify integrity of game files" in GOG/Steam/Epic' -ForegroundColor White
    Write-Host '  2. Launch the game ONCE and reach the main menu' -ForegroundColor White
    Write-Host '  3. Close the game COMPLETELY' -ForegroundColor White
    Write-Host '  4. ONLY THEN run this script' -ForegroundColor White
    Write-Host ''
    Write-Host '######################################################################' -ForegroundColor Red
    Write-Host ''

    Write-Host '======================================================' -ForegroundColor Cyan
    Write-Host '  New-CleanManifest.ps1  v1.0' -ForegroundColor Cyan
    Write-Host '======================================================' -ForegroundColor Cyan
    Write-Host "  Target: $GamePath"
    Write-Host ''

    $exePath = Join-Path $GamePath 'bin\x64\Cyberpunk2077.exe'
    if (-not [System.IO.File]::Exists((Get-LP $exePath))) {
        throw "Not a valid Cyberpunk 2077 installation. Cyberpunk2077.exe is missing."
    }

    # ---- Check for mods ----
    $modIndicators = @('red4ext', 'archive\pc\mod', 'bin\x64\plugins', 'r6\scripts', 'r6\tweaks', 'V2077')
    $foundMods = @()
    foreach ($m in $modIndicators) {
        $p = Join-Path $GamePath $m
        if ([System.IO.Directory]::Exists((Get-LP $p))) {
            $entries = @([System.IO.Directory]::EnumerateFileSystemEntries((Get-LP $p)))
            if ($entries.Count -gt 0) { $foundMods += $m }
        }
    }
    if ($foundMods.Count -gt 0) {
        Write-Host ''
        Write-Host '!!! CRITICAL WARNING: Mod folders with content detected !!!' -ForegroundColor Red
        Write-Host ''
        foreach ($m in $foundMods) { Write-Host "  - $m" -ForegroundColor Yellow }
        Write-Host ''
        Write-Host 'Creating a manifest with installed mods will make the cleaner tool useless.' -ForegroundColor Red
        Write-Host 'Please run "Verify integrity of game files" in GOG/Steam/Epic FIRST.' -ForegroundColor Red
        Write-Host ''
        if (-not $Force) {
            if (-not $Yes) {
                $a = Read-Host 'Continue anyway? (NOT recommended!) [Y/N]'
                if ($a -notmatch '^[JjYy]') { Write-Host 'Aborted.'; exit 2 }
            }
        } else {
            Write-Host 'Override: -Force active, continuing.' -ForegroundColor Yellow
        }
    }

    # ---- Output path ----
    if ([string]::IsNullOrWhiteSpace($OutputPath)) {
        $base = $PSScriptRoot; if (-not $base) { $base = (Get-Location).Path }
        $OutputPath = Join-Path $base 'Cyberpunk_clean.json'
    }

    if ([System.IO.File]::Exists((Get-LP $OutputPath)) -and -not $Force) {
        if (-not $Yes) {
            $a = Read-Host "File already exists: $OutputPath`nOverwrite? [Y/N]"
            if ($a -notmatch '^[JjYy]') { Write-Host 'Aborted.'; exit 2 }
        }
    }

    # ---- Scan ----
    Write-Host "Scanning $GamePath ..." -ForegroundColor Cyan
    $sw = [System.Diagnostics.Stopwatch]::StartNew()

    $entries = [ordered]@{}
    $fileCount = 0
    $dirCount = 0
    $totalSize = 0L

    $stack = New-Object System.Collections.Generic.Stack[string]
    $stack.Push($GamePath)

    while ($stack.Count -gt 0) {
        $dir = $stack.Pop()
        $rel = ''
        if ($dir -ne $GamePath) {
            $rel = $dir.Substring($GamePath.Length + 1).Replace('\', '/')
        }

        $skip = $false
        foreach ($exclude in @('_MOD_REMOVER_BACKUPS', 'Cyberpunk_clean.json',
                               'Safe_Mod_Cleaner.ps1', 'Safe_Mod_Cleaner.bat',
                               'New-CleanManifest.ps1')) {
            if ($rel -ieq $exclude -or $rel.StartsWith("$exclude/", [System.StringComparison]::OrdinalIgnoreCase)) {
                $skip = $true; break
            }
        }
        if ($skip) { continue }

        if ($rel) {
            $entries[$rel] = 'dir'
            $dirCount++
        }

        try {
            foreach ($subRaw in [System.IO.Directory]::EnumerateDirectories((Get-LP $dir))) {
                $sub = Remove-LP $subRaw
                $attr = [System.IO.File]::GetAttributes((Get-LP $sub))
                if (($attr -band [System.IO.FileAttributes]::ReparsePoint) -ne 0) { continue }
                $stack.Push($sub)
            }
        } catch { }

        try {
            foreach ($fRaw in [System.IO.Directory]::EnumerateFiles((Get-LP $dir))) {
                $f = Remove-LP $fRaw
                $fRel = $f.Substring($GamePath.Length + 1).Replace('\', '/')
                $fileCount++
                try {
                    $fi = New-Object System.IO.FileInfo (Get-LP $f)
                    $totalSize += $fi.Length
                    if ($IncludeHashes -and $fi.Length -le 64MB) {
                        $hash = (Get-FileHash -LiteralPath $f -Algorithm SHA256).Hash
                        $entries[$fRel] = [PSCustomObject]@{
                            type   = 'file'
                            size   = $fi.Length
                            sha256 = $hash
                        }
                    } else {
                        $entries[$fRel] = 'file'
                    }
                } catch {
                    $entries[$fRel] = 'file'
                }
            }
        } catch { }

        if ($fileCount % 500 -eq 0 -and $fileCount -gt 0) {
            Write-Host "`r  ... $fileCount files scanned" -NoNewline
        }
    }
    Write-Host ''

    $sw.Stop()
    Write-Host ("Scan finished in {0:N1}s" -f $sw.Elapsed.TotalSeconds) -ForegroundColor Green
    Write-Host "  Files: $fileCount" -ForegroundColor Gray
    Write-Host "  Directories: $dirCount" -ForegroundColor Gray
    Write-Host ("  Size: {0:N2} GB" -f ($totalSize / 1GB)) -ForegroundColor Gray

    if ($fileCount -lt 500) {
        throw "Only $fileCount files found. This is not a complete installation."
    }
    if (-not $entries.Contains('bin/x64/Cyberpunk2077.exe')) {
        throw "bin/x64/Cyberpunk2077.exe missing from dump - installation incomplete."
    }

    $sortedEntries = [ordered]@{}
    foreach ($key in ($entries.Keys | Sort-Object)) {
        $sortedEntries[$key] = $entries[$key]
    }

    $doc = [ordered]@{
        folder      = $GamePath
        scanned_at  = (Get-Date -Format 'o')
        entry_count = $sortedEntries.Count
        file_count  = $fileCount
        dir_count   = $dirCount
        total_bytes = $totalSize
        tool        = 'New-CleanManifest.ps1 v1.0'
        note        = 'Vanilla whitelist for Safe_Mod_Cleaner. Do not edit manually.'
        entries     = $sortedEntries
    }

    $json = $doc | ConvertTo-Json -Depth 6
    $utf8 = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText((Get-LP $OutputPath), $json, $utf8)

    Write-Host ''
    Write-Host '======================================================' -ForegroundColor Green
    Write-Host '  MANIFEST CREATED SUCCESSFULLY' -ForegroundColor Green
    Write-Host '======================================================' -ForegroundColor Green
    Write-Host "  File:    $OutputPath" -ForegroundColor White
    Write-Host ("  Entries: {0} ({1} files, {2} directories)" -f $sortedEntries.Count, $fileCount, $dirCount) -ForegroundColor White
    Write-Host ''
    Write-Host 'Next steps:' -ForegroundColor Yellow
    Write-Host '  1. DO NOT delete or manually edit this file' -ForegroundColor White
    Write-Host '  2. Run Safe_Mod_Cleaner.bat - the tool uses the whitelist automatically' -ForegroundColor White
    Write-Host '  3. After game updates (GOG/Steam): recreate the manifest' -ForegroundColor White
    exit 0
}
catch {
    Write-Host ''
    Write-Host "ERROR: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}