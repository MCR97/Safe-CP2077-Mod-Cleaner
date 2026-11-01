#Requires -Version 5.1

<#
New-CleanManifest.ps1 v1.1

Creates a Vanilla manifest (Cyberpunk_clean.json) from a CLEAN
Cyberpunk 2077 installation, used as whitelist by Safe_Mod_Cleaner.

CRITICAL: Before running this script, ALL mods must be removed!
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

$Script:LongPathPrefix = '\\?\'
$Script:ExcludeNames = New-Object System.Collections.Generic.List[string]

function Get-LP {
    param([string]$Path)

    if ([string]::IsNullOrEmpty($Path)) {
        return $Path
    }

    if ($Path.StartsWith($Script:LongPathPrefix)) {
        return $Path
    }

    $p = $Path.TrimEnd([System.IO.Path]::DirectorySeparatorChar)

    if ($p.Length -eq 2 -and $p[1] -eq ':') {
        $p += [System.IO.Path]::DirectorySeparatorChar
    }

    return $Script:LongPathPrefix + $p
}

function Remove-LP {
    param([string]$Path)

    if ([string]::IsNullOrEmpty($Path)) {
        return $Path
    }

    if ($Path.StartsWith($Script:LongPathPrefix)) {
        return $Path.Substring(4)
    }

    return $Path
}

function Get-NormRel {
    param([string]$Path)

    $p = $Path.Trim()
    $p = $p.Replace([System.IO.Path]::DirectorySeparatorChar.ToString(), '/')
    $p = $p.Replace([System.IO.Path]::AltDirectorySeparatorChar.ToString(), '/')

    while ($p.StartsWith('./')) {
        $p = $p.Substring(2)
    }

    return $p.Trim('/')
}

function Get-RelPath {
    param([string]$Root, [string]$Full)

    return (Get-NormRel $Full.Substring($Root.Length))
}

function Test-ToolExclusion {
    param([string]$Rel)

    if ([string]::IsNullOrWhiteSpace($Rel)) {
        return $false
    }

    $leafIndex = $Rel.LastIndexOf('/')
    $leaf = if ($leafIndex -ge 0) { $Rel.Substring($leafIndex + 1) } else { $Rel }

    if ($leaf -like '_modclean_report_*.json') {
        return $true
    }

    foreach ($e in $Script:ExcludeNames) {
        if ([string]::IsNullOrWhiteSpace($e)) { continue }

        if ($Rel -ieq $e) {
            return $true
        }

        if ($Rel.StartsWith($e + '/', [System.StringComparison]::OrdinalIgnoreCase)) {
            return $true
        }
    }

    return $false
}

try {
    if ([string]::IsNullOrWhiteSpace($GamePath)) {
        if ($PSScriptRoot) {
            $GamePath = $PSScriptRoot
        }
        else {
            $GamePath = (Get-Location).Path
        }
    }

    $GamePath = [System.IO.Path]::GetFullPath($GamePath)
    $GamePath = $GamePath.TrimEnd([System.IO.Path]::DirectorySeparatorChar)

    if ($GamePath.Length -eq 2 -and $GamePath[1] -eq ':') {
        $GamePath = $GamePath + [System.IO.Path]::DirectorySeparatorChar
    }

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
    Write-Host '  New-CleanManifest.ps1 v1.1' -ForegroundColor Cyan
    Write-Host '======================================================' -ForegroundColor Cyan
    Write-Host "  Target: $GamePath"
    Write-Host ''

    $exePath = Join-Path $GamePath 'bin\x64\Cyberpunk2077.exe'

    if (-not [System.IO.File]::Exists((Get-LP $exePath))) {
        throw "Not a valid Cyberpunk 2077 installation. Cyberpunk2077.exe is missing."
    }

    # ---- Check for mods ----
    $modIndicators = @(
        'red4ext',
        'archive\pc\mod',
        'bin\x64\plugins',
        'r6\scripts',
        'r6\tweaks',
        'V2077',
        'reshade-shaders',
        'bin\x64\reshade-shaders',
        'bin\x64\mods'
    )

    $foundMods = @()

    foreach ($m in $modIndicators) {
        $p = Join-Path $GamePath $m

        if ([System.IO.Directory]::Exists((Get-LP $p))) {
            $entries = @([System.IO.Directory]::EnumerateFileSystemEntries((Get-LP $p)))

            if ($entries.Count -gt 0) {
                $foundMods += $m
            }
        }
    }

    if ($foundMods.Count -gt 0) {
        Write-Host ''
        Write-Host '!!! CRITICAL WARNING: Mod folders with content detected !!!' -ForegroundColor Red
        Write-Host ''

        foreach ($m in $foundMods) {
            Write-Host "  - $m" -ForegroundColor Yellow
        }

        Write-Host ''
        Write-Host 'Creating a manifest with installed mods will make the cleaner tool useless.' -ForegroundColor Red
        Write-Host 'Please run "Verify integrity of game files" in GOG/Steam/Epic FIRST.' -ForegroundColor Red
        Write-Host ''

        if (-not $Force) {
            if (-not $Yes) {
                $a = Read-Host 'Continue anyway? (NOT recommended!) [Y/N]'

                if ($a -notmatch '^[JjYy]') {
                    Write-Host 'Aborted.'
                    exit 2
                }
            }
        }
        else {
            Write-Host 'Override: -Force active, continuing.' -ForegroundColor Yellow
        }
    }

    # ---- Output path ----
    if ([string]::IsNullOrWhiteSpace($OutputPath)) {
        $base = $PSScriptRoot
        if (-not $base) {
            $base = (Get-Location).Path
        }

        $OutputPath = Join-Path $base 'Cyberpunk_clean.json'
    }

    $OutputPath = [System.IO.Path]::GetFullPath($OutputPath)

    if ([System.IO.File]::Exists((Get-LP $OutputPath)) -and -not $Force) {
        if (-not $Yes) {
            $a = Read-Host "File already exists: $OutputPath`nOverwrite? [Y/N]"

            if ($a -notmatch '^[JjYy]') {
                Write-Host 'Aborted.'
                exit 2
            }
        }
    }

    # ---- Exclusions ----
    foreach ($item in @(
        '_MOD_REMOVER_BACKUPS',
        'Cyberpunk_clean.json',
        'Safe_Mod_Cleaner.ps1',
        'Safe_Mod_Cleaner.bat',
        'New-CleanManifest.ps1',
        'Uninstall.bat',
        'RESTORE_HERE.bat'
    )) {
        $Script:ExcludeNames.Add($item)
    }

    if ($OutputPath.StartsWith($GamePath, [System.StringComparison]::OrdinalIgnoreCase)) {
        $Script:ExcludeNames.Add((Get-RelPath -Root $GamePath -Full $OutputPath))
    }

    $scriptDir = $PSScriptRoot
    if (-not $scriptDir) {
        $scriptDir = [System.IO.Path]::GetDirectoryName($PSCommandPath)
    }

    $toolFiles = @(
        'Safe_Mod_Cleaner.ps1',
        'Safe_Mod_Cleaner.bat',
        'New-CleanManifest.ps1',
        'Uninstall.bat',
        'Cyberpunk_clean.json',
        'RESTORE_HERE.bat'
    )

    $toolBases = @($scriptDir, $GamePath)

    foreach ($base in $toolBases) {
        if ([string]::IsNullOrWhiteSpace($base)) { continue }

        foreach ($toolFile in $toolFiles) {
            $full = Join-Path $base $toolFile

            if ([System.IO.File]::Exists((Get-LP $full))) {
                if ($full.StartsWith($GamePath, [System.StringComparison]::OrdinalIgnoreCase)) {
                    $Script:ExcludeNames.Add((Get-RelPath -Root $GamePath -Full $full))
                }
            }
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
            $rel = Get-RelPath -Root $GamePath -Full $dir
        }

        if ($rel -and (Test-ToolExclusion $rel)) {
            continue
        }

        if ($rel) {
            $entries[$rel] = 'dir'
            $dirCount++
        }

        try {
            foreach ($subRaw in [System.IO.Directory]::EnumerateDirectories((Get-LP $dir))) {
                $sub = Remove-LP $subRaw
                $attr = [System.IO.File]::GetAttributes((Get-LP $sub))

                if (($attr -band [System.IO.FileAttributes]::ReparsePoint) -ne 0) {
                    continue
                }

                $stack.Push($sub)
            }
        }
        catch { }

        try {
            foreach ($fRaw in [System.IO.Directory]::EnumerateFiles((Get-LP $dir))) {
                $f = Remove-LP $fRaw
                $fRel = Get-RelPath -Root $GamePath -Full $f

                if (Test-ToolExclusion $fRel) {
                    continue
                }

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
                    }
                    else {
                        $entries[$fRel] = 'file'
                    }
                }
                catch {
                    $entries[$fRel] = 'file'
                }
            }
        }
        catch { }

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
    Write-Host '  2. Safe_Mod_Cleaner.bat will use this whitelist automatically' -ForegroundColor White
    Write-Host '  3. After game updates: recreate the manifest' -ForegroundColor White

    exit 0
}
catch {
    Write-Host ''
    Write-Host "ERROR: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}