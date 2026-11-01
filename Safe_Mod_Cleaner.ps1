#Requires -Version 5.1

<#
Safe Cyberpunk 2077 Mod Cleaner v1.1
Copyright (c) 2026 MCR777
Licensed under MIT License

Whitelist-based (Cyberpunk_clean.json) = Vanilla files PROTECTED
Vanilla Snapshot on first run (cache + config files)
Automatic Auto-Repair from Snapshot after every clean
Moves files to quarantine backup (nothing is deleted)

Single mode: Reset to Vanilla
This mode integrates the former Nuclear behavior:
- all non-whitelisted files are moved to backup
- cache/config files are forced back to vanilla state
- vanilla files are restored automatically from snapshot
#>

[CmdletBinding()]
param(
    [Parameter(Position = 0)][string]$GamePath,
    [string]$CleanJsonPath,
    [switch]$CompareOnly,
    [switch]$DryRun,
    [switch]$Yes,
    [switch]$ForceManifest,
    [switch]$SkipVersionCheck,
    [switch]$Hash,
    [switch]$Restore,
    [string]$BackupId,
    [switch]$Latest,
    [switch]$ListBackups,
    [switch]$OpenBackup,
    [switch]$ForceResnap,
    [switch]$RebuildSnapshotOnly
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'Continue'

$Script:LogFile = $null
$Script:ToolName = 'Safe CP2077 Mod Cleaner v1.1'
$BackupRootName = '_MOD_REMOVER_BACKUPS'
$Script:SnapshotRoot = $null
$Script:PayloadRoot = $null
$Script:LongPathPrefix = '\\?\'

# =================================================================
# SECTION 1 - Helper Functions
# =================================================================

function Write-Log {
    param(
        [Parameter(Mandatory)][AllowEmptyString()][string]$Message,
        [ValidateSet('INFO', 'OK', 'WARN', 'ERROR', 'PROTECT', 'MOVE', 'SKIP')][string]$Level = 'INFO'
    )

    $line = '[{0}] [{1,-7}] {2}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Level, $Message
    $color = switch ($Level) {
        'OK'      { 'Green' }
        'WARN'    { 'Yellow' }
        'ERROR'   { 'Red' }
        'PROTECT' { 'DarkCyan' }
        'MOVE'    { 'Gray' }
        'SKIP'    { 'DarkGray' }
        default   { 'White' }
    }

    Write-Host $line -ForegroundColor $color

    if ($Script:LogFile) {
        Add-Content -LiteralPath $Script:LogFile -Value $line -Encoding UTF8
    }
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

function Get-WinRel {
    param([string]$Rel)

    if ([string]::IsNullOrWhiteSpace($Rel)) {
        return ''
    }

    return $Rel.Replace('/', [System.IO.Path]::DirectorySeparatorChar.ToString())
}

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

function Get-RelPath {
    param([string]$Root, [string]$Full)

    return (Get-NormRel $Full.Substring($Root.Length))
}

function Test-ReparsePoint {
    param([string]$Path)

    try {
        $attr = [System.IO.File]::GetAttributes((Get-LP $Path))
        return (($attr -band [System.IO.FileAttributes]::ReparsePoint) -ne 0)
    }
    catch {
        return $false
    }
}

function Get-DirSize {
    param([string]$Path)

    $sum = 0L

    try {
        $stack = New-Object System.Collections.Generic.Stack[string]
        $stack.Push($Path)

        while ($stack.Count -gt 0) {
            $d = $stack.Pop()

            foreach ($f in [System.IO.Directory]::EnumerateFiles((Get-LP $d))) {
                try {
                    $sum += (New-Object System.IO.FileInfo $f).Length
                }
                catch { }
            }

            foreach ($sub in [System.IO.Directory]::EnumerateDirectories((Get-LP $d))) {
                $stack.Push((Remove-LP $sub))
            }
        }
    }
    catch { }

    return $sum
}

function Format-Size {
    param([double]$Bytes)

    if ($Bytes -ge 1GB) { return ('{0:N2} GB' -f ($Bytes / 1GB)) }
    if ($Bytes -ge 1MB) { return ('{0:N2} MB' -f ($Bytes / 1MB)) }
    if ($Bytes -ge 1KB) { return ('{0:N2} KB' -f ($Bytes / 1KB)) }

    return ('{0} B' -f [int]$Bytes)
}

function Move-UnitSafe {
    param(
        [string]$Source,
        [string]$Destination,
        [switch]$IsDirectory
    )

    $destParent = [System.IO.Path]::GetDirectoryName($Destination)

    if (-not [System.IO.Directory]::Exists((Get-LP $destParent))) {
        [System.IO.Directory]::CreateDirectory((Get-LP $destParent)) | Out-Null
    }

    if ($IsDirectory) {
        [System.IO.Directory]::Move((Get-LP $Source), (Get-LP $Destination))
    }
    else {
        $fi = New-Object System.IO.FileInfo (Get-LP $Source)
        if ($fi.IsReadOnly) {
            $fi.IsReadOnly = $false
        }

        [System.IO.File]::Move((Get-LP $Source), (Get-LP $Destination))
    }
}

# =================================================================
# SECTION 2 - JSON Manifest (Whitelist)
# =================================================================

function Import-CleanManifest {
    param([string]$JsonPath)

    if (-not [System.IO.File]::Exists((Get-LP $JsonPath))) {
        throw "Clean manifest not found: $JsonPath"
    }

    $raw = [System.IO.File]::ReadAllText((Get-LP $JsonPath))

    try {
        $json = $raw | ConvertFrom-Json
    }
    catch {
        throw "Clean manifest is invalid (parse error): $($_.Exception.Message)"
    }

    $map = $null

    if ($json.PSObject.Properties.Name -contains 'entries') {
        $map = $json.entries
    }
    elseif ($json.PSObject.Properties.Name -contains 'files') {
        $map = $json.files
    }
    else {
        $map = $json
    }

    $cmp = [System.StringComparer]::OrdinalIgnoreCase
    $files = New-Object 'System.Collections.Generic.HashSet[string]' $cmp
    $dirs = New-Object 'System.Collections.Generic.HashSet[string]' $cmp

    foreach ($prop in $map.PSObject.Properties) {
        $rel = Get-NormRel $prop.Name
        if ([string]::IsNullOrWhiteSpace($rel)) { continue }

        $type = 'file'

        if ($prop.Value -is [string]) {
            $type = $prop.Value.Trim().ToLowerInvariant()
        }
        elseif ($prop.Value.PSObject.Properties.Name -contains 'type') {
            $type = "$($prop.Value.type)".Trim().ToLowerInvariant()
        }

        if ($type -like 'dir*') {
            [void]$dirs.Add($rel)
        }
        else {
            [void]$files.Add($rel)
        }

        $parent = $rel
        while ($parent.Contains('/')) {
            $parent = $parent.Substring(0, $parent.LastIndexOf('/'))
            if ($parent) {
                [void]$dirs.Add($parent)
            }
        }
    }

    if ($files.Count -lt 100) {
        throw "Clean manifest contains only $($files.Count) files - this is not a complete vanilla dump."
    }

    $all = New-Object 'System.Collections.Generic.List[string]'
    $all.AddRange([string[]]@($files))
    $all.AddRange([string[]]@($dirs))

    $sorted = $all.ToArray()
    [System.Array]::Sort($sorted, $cmp)

    return [PSCustomObject]@{
        Files  = $files
        Dirs   = $dirs
        Sorted = $sorted
        Path   = $JsonPath
    }
}

function Test-VanillaFile {
    param($M, [string]$Rel)
    return $M.Files.Contains($Rel)
}

function Test-VanillaDir {
    param($M, [string]$Rel)
    return $M.Dirs.Contains($Rel)
}

function Test-VanillaUnder {
    param($M, [string]$Rel)

    $prefix = $Rel + '/'
    $cmp = [System.StringComparer]::OrdinalIgnoreCase
    $idx = [System.Array]::BinarySearch($M.Sorted, $prefix, $cmp)

    if ($idx -lt 0) {
        $idx = -bnot $idx
    }

    if ($idx -ge $M.Sorted.Length) {
        return $false
    }

    return $M.Sorted[$idx].StartsWith($prefix, [System.StringComparison]::OrdinalIgnoreCase)
}

# =================================================================
# SECTION 3 - Scope Rules & Decision Logic
# =================================================================

$Script:ModCoreRoots = @(
    'archive/pc/mod',
    'bin/x64/plugins',
    'red4ext',
    'mods',
    'r6/scripts',
    'r6/tweaks',
    'r6/input',
    'r6/inputs',
    'r6/audioware',
    'r6/logs',
    'r6/cache/modded',
    'engine/tools',
    'V2077',
    'reshade-shaders',
    'bin/x64/reshade-shaders',
    'bin/x64/mods'
)

$Script:ConfigRoots = @('engine/config', 'r6/config')
$Script:CacheRoots = @('r6/cache')
$Script:BinRoots = @('bin')
$Script:ContentRoots = @('archive')

$Script:NeverTouch = @(
    'bin/x64/cyberpunk2077.exe',
    'bin/x64/cyberpunk2077.exe.config',
    'uninstall.exe'
)

function Test-UnderRoots {
    param([string]$Rel, [string[]]$Roots)

    foreach ($r in $Roots) {
        if ($Rel -ieq $r) {
            return $true
        }

        if ($Rel.StartsWith($r + '/', [System.StringComparison]::OrdinalIgnoreCase)) {
            return $true
        }
    }

    return $false
}

function Get-Scope {
    param([string]$Rel)

    if (Test-UnderRoots $Rel $Script:ModCoreRoots) { return 'ModCore' }
    if (Test-UnderRoots $Rel $Script:ConfigRoots) { return 'Config' }
    if (Test-UnderRoots $Rel $Script:CacheRoots) { return 'Cache' }
    if (Test-UnderRoots $Rel $Script:ContentRoots) { return 'Content' }
    if (Test-UnderRoots $Rel $Script:BinRoots) { return 'Bin' }

    return 'Unknown'
}

function Get-Decision {
    param(
        [string]$Scope,
        [bool]$IsVanilla,
        [string]$Rel
    )

    if ($Script:NeverTouch -contains $Rel.ToLowerInvariant()) {
        return 'Protect'
    }

    if ($IsVanilla) {
        # Reset to Vanilla integrates the former Nuclear behavior:
        # vanilla cache/config files are secured and restored from snapshot.
        if (Test-UnderRoots $Rel $Script:CacheRoots) { return 'Move' }
        if (Test-UnderRoots $Rel $Script:ConfigRoots) { return 'Move' }

        return 'Protect'
    }

    # Every non-whitelisted file/folder is moved to backup.
    return 'Move'
}

# =================================================================
# SECTION 4 - Scan with JSON Comparison
# =================================================================

function Get-ScanResult {
    param(
        [string]$Root,
        $Manifest,
        [string[]]$ExcludeRel
    )

    $units = New-Object System.Collections.Generic.List[object]
    $totalFiles = 0
    $cmp = [System.StringComparison]::OrdinalIgnoreCase

    $isExcluded = {
        param([string]$rel)

        if ([string]::IsNullOrWhiteSpace($rel)) {
            return $true
        }

        $leafIndex = $rel.LastIndexOf('/')
        $leaf = if ($leafIndex -ge 0) { $rel.Substring($leafIndex + 1) } else { $rel }

        if ($leaf -like '_modclean_report_*.json') {
            return $true
        }

        foreach ($e in $ExcludeRel) {
            if ($rel -ieq $e) {
                return $true
            }

            if ($rel.StartsWith($e + '/', $cmp)) {
                return $true
            }
        }

        return $false
    }

    $stack = New-Object System.Collections.Generic.Stack[string]
    $stack.Push($Root)

    while ($stack.Count -gt 0) {
        $dir = $stack.Pop()
        $subDirs = @()

        try {
            $subDirs = [System.IO.Directory]::EnumerateDirectories((Get-LP $dir))
        }
        catch {
            Write-Log "Cannot access directory: $dir" 'WARN'
        }

        foreach ($subRaw in $subDirs) {
            $sub = Remove-LP $subRaw
            $rel = Get-RelPath -Root $Root -Full $sub

            if ([string]::IsNullOrWhiteSpace($rel)) { continue }
            if (& $isExcluded $rel) { continue }

            if (Test-ReparsePoint $sub) {
                Write-Log "Symlink/Junction skipped: $rel" 'WARN'
                continue
            }

            if (Test-VanillaDir $Manifest $rel) {
                $stack.Push($sub)
                continue
            }

            if (Test-VanillaUnder $Manifest $rel) {
                $stack.Push($sub)
                continue
            }

            $scope = Get-Scope $rel

            $units.Add([PSCustomObject]@{
                Rel     = $rel
                Full    = $sub
                IsDir   = $true
                Scope   = $scope
                Vanilla = $false
                Size    = (Get-DirSize $sub)
                Action  = (Get-Decision $scope $false $rel)
            })
        }

        $files = @()

        try {
            $files = [System.IO.Directory]::EnumerateFiles((Get-LP $dir))
        }
        catch { }

        foreach ($fRaw in $files) {
            $f = Remove-LP $fRaw
            $rel = Get-RelPath -Root $Root -Full $f

            if ([string]::IsNullOrWhiteSpace($rel)) { continue }
            if (& $isExcluded $rel) { continue }

            $totalFiles++

            $van = Test-VanillaFile $Manifest $rel
            $scope = Get-Scope $rel
            $action = Get-Decision $scope $van $rel

            if ($action -eq 'Protect') { continue }

            $len = 0L

            try {
                $len = (New-Object System.IO.FileInfo (Get-LP $f)).Length
            }
            catch { }

            $units.Add([PSCustomObject]@{
                Rel     = $rel
                Full    = $f
                IsDir   = $false
                Scope   = $scope
                Vanilla = $van
                Size    = $len
                Action  = $action
            })
        }
    }

    return [PSCustomObject]@{
        Units      = $units
        TotalFiles = $totalFiles
    }
}

# =================================================================
# SECTION 5 - Vanilla Snapshot (Cache + Config)
# =================================================================

function Get-SnapshotDir {
    param([string]$BackupRoot)
    return Join-Path $BackupRoot 'vanilla_snapshot'
}

function Test-SnapshotValid {
    param([string]$SnapshotDir)

    $infoPath = Join-Path $SnapshotDir 'info.json'

    if (-not [System.IO.File]::Exists((Get-LP $infoPath))) {
        return $false
    }

    try {
        $info = Get-Content -LiteralPath $infoPath -Raw -Encoding UTF8 | ConvertFrom-Json

        foreach ($entry in $info.files) {
            $filePath = Join-Path $SnapshotDir $entry.rel

            if (-not [System.IO.File]::Exists((Get-LP $filePath))) {
                return $false
            }

            $actualHash = (Get-FileHash -LiteralPath $filePath -Algorithm SHA256).Hash

            if ($actualHash -ine $entry.sha256) {
                return $false
            }
        }

        return $true
    }
    catch {
        return $false
    }
}

function New-VanillaSnapshot {
    param(
        [string]$GamePath,
        [string]$SnapshotDir
    )

    $snapshotFiles = @(
        'r6\cache\final.redscripts',
        'r6\cache\tweakdb.bin',
        'r6\cache\tweakdb_ep1.bin',
        'engine\config\base\animation.ini',
        'engine\config\base\general.ini',
        'engine\config\base\multiplayer.ini',
        'engine\config\base\rendering.ini',
        'engine\config\base\resources.ini',
        'engine\config\base\scenesystem.ini',
        'engine\config\base\smartobjects.ini',
        'engine\config\giweights.json',
        'engine\config\galaxy\pc\REDGalaxyPeer_default.json',
        'engine\config\platform\pc\platformgameplay.ini',
        'engine\config\platform\pc\rendering.ini',
        'r6\config\bumpersSettings.json',
        'r6\config\inputContexts.xml',
        'r6\config\inputDeadzones.xml',
        'r6\config\inputUserMappings.xml',
        'r6\config\uiInputActions.xml',
        'r6\config\settings\options.json',
        'r6\config\settings\platform\pc\options.json',
        'r6\config\settings\platform\winGDK\options.json'
    )

    $files = New-Object System.Collections.Generic.List[object]
    $copied = 0

    foreach ($rel in $snapshotFiles) {
        $src = Join-Path $GamePath $rel

        if (-not [System.IO.File]::Exists((Get-LP $src))) {
            Write-Log "Snapshot file missing (ignored): $rel" 'WARN'
            continue
        }

        $destRel = Get-NormRel $rel
        $dest = Join-Path $SnapshotDir $destRel
        $destParent = [System.IO.Path]::GetDirectoryName($dest)

        if (-not [System.IO.Directory]::Exists((Get-LP $destParent))) {
            [System.IO.Directory]::CreateDirectory((Get-LP $destParent)) | Out-Null
        }

        try {
            [System.IO.File]::Copy((Get-LP $src), (Get-LP $dest), $true)

            $hash = (Get-FileHash -LiteralPath $dest -Algorithm SHA256).Hash
            $size = (New-Object System.IO.FileInfo (Get-LP $dest)).Length

            $files.Add([PSCustomObject]@{
                name   = [System.IO.Path]::GetFileName($src)
                rel    = $destRel
                sha256 = $hash
                size   = $size
                type   = if ($rel -like '*cache*') { 'cache' } else { 'config' }
            })

            $copied++

            $shortHash = $hash.Substring(0, [Math]::Min(12, $hash.Length))
            Write-Log "Snapshot: $destRel ($shortHash...)" 'OK'
        }
        catch {
            Write-Log "Snapshot failed for $rel : $($_.Exception.Message)" 'ERROR'
        }
    }

    if ($copied -eq 0) {
        Write-Log 'No files could be snapshotted (game may not have been started yet).' 'WARN'
        return $false
    }

    $info = [ordered]@{
        createdAt = (Get-Date -Format 'o')
        gamePath  = $GamePath
        note      = 'VANILLA SNAPSHOT - DO NOT DELETE! Includes cache and config files.'
        fileCount = $files.Count
        files     = $files
    }

    $json = $info | ConvertTo-Json -Depth 5

    [System.IO.File]::WriteAllText(
        (Get-LP (Join-Path $SnapshotDir 'info.json')),
        $json,
        (New-Object System.Text.UTF8Encoding($false))
    )

    $readme = @"
==============================================================
VANILLA SNAPSHOT - PROTECTED ZONE

This folder contains COPIES of vanilla files from:

CACHE:
r6/cache/final.redscripts
r6/cache/tweakdb.bin
r6/cache/tweakdb_ep1.bin

CONFIGS:
engine/config/base/*.ini
engine/config/giweights.json
engine/config/galaxy/pc/*.json
engine/config/platform/pc/*.ini
r6/config/*.xml, *.json
r6/config/settings/options.json

THESE FILES ARE AUTOMATICALLY RESTORED on every clean run,
ensuring your game always starts with vanilla files.

NO GOG/Steam Verify needed!
DO NOT DELETE!

Created: $($info.createdAt)
Files: $($info.fileCount)
"@

    [System.IO.File]::WriteAllText(
        (Get-LP (Join-Path $SnapshotDir 'README_DO_NOT_DELETE.txt')),
        $readme,
        (New-Object System.Text.UTF8Encoding($false))
    )

    return $true
}

function Repair-VanillaFilesFromSnapshot {
    param(
        [string]$GamePath,
        [string]$SnapshotDir
    )

    # Fallback for PayloadRoot if repair runs without a normal backup payload.
    if (-not $Script:PayloadRoot) {
        $Script:PayloadRoot = Join-Path $SnapshotDir '_repaired_temp'
        Write-Log "PayloadRoot was null - using fallback: $Script:PayloadRoot" 'WARN'

        if (-not [System.IO.Directory]::Exists((Get-LP $Script:PayloadRoot))) {
            [System.IO.Directory]::CreateDirectory((Get-LP $Script:PayloadRoot)) | Out-Null
        }
    }

    $infoPath = Join-Path $SnapshotDir 'info.json'

    if (-not [System.IO.File]::Exists((Get-LP $infoPath))) {
        Write-Log 'Snapshot info.json missing - repair not possible.' 'ERROR'
        return 0
    }

    $info = Get-Content -LiteralPath $infoPath -Raw -Encoding UTF8 | ConvertFrom-Json
    $repaired = 0

    foreach ($entry in $info.files) {
        $snapshotFile = Join-Path $SnapshotDir $entry.rel
        $targetFile = Join-Path $GamePath (Get-WinRel $entry.rel)

        if (-not [System.IO.File]::Exists((Get-LP $snapshotFile))) {
            Write-Log "Snapshot file missing: $($entry.rel)" 'ERROR'
            continue
        }

        $targetDir = [System.IO.Path]::GetDirectoryName($targetFile)

        if (-not [System.IO.Directory]::Exists((Get-LP $targetDir))) {
            [System.IO.Directory]::CreateDirectory((Get-LP $targetDir)) | Out-Null
        }

        if ([System.IO.File]::Exists((Get-LP $targetFile))) {
            $currentHash = (Get-FileHash -LiteralPath $targetFile -Algorithm SHA256).Hash

            if ($currentHash -ieq $entry.sha256) {
                continue
            }

            $moddedDest = Join-Path $Script:PayloadRoot ((Get-WinRel $entry.rel) + '.modded')
            $moddedDir = [System.IO.Path]::GetDirectoryName($moddedDest)

            if (-not [System.IO.Directory]::Exists((Get-LP $moddedDir))) {
                [System.IO.Directory]::CreateDirectory((Get-LP $moddedDir)) | Out-Null
            }

            try {
                Move-UnitSafe -Source $targetFile -Destination $moddedDest
                Write-Log "Modded file secured: $($entry.rel).modded" 'MOVE'
            }
            catch {
                Write-Log "Could not secure modded file: $($_.Exception.Message)" 'ERROR'
            }
        }
        else {
            Write-Log "File missing, restoring from snapshot: $($entry.rel)" 'WARN'
        }

        try {
            [System.IO.File]::Copy((Get-LP $snapshotFile), (Get-LP $targetFile), $true)
            Write-Log "Restored from vanilla snapshot: $($entry.rel)" 'OK'
            $repaired++
        }
        catch {
            Write-Log "Repair failed: $($entry.rel) - $($_.Exception.Message)" 'ERROR'
        }
    }

    return $repaired
}

# =================================================================
# SECTION 6 - Restore
# =================================================================

function Restore-SingleFile {
    param(
        [string]$Source,
        [string]$Destination,
        [string]$ConflictDir
    )

    if ([System.IO.File]::Exists((Get-LP $Destination))) {
        $sLen = (New-Object System.IO.FileInfo (Get-LP $Source)).Length
        $dLen = (New-Object System.IO.FileInfo (Get-LP $Destination)).Length

        if ($sLen -eq $dLen) {
            try {
                $sHash = (Get-FileHash -LiteralPath (Get-LP $Source) -Algorithm SHA256).Hash
                $dHash = (Get-FileHash -LiteralPath (Get-LP $Destination) -Algorithm SHA256).Hash

                if ($sHash -ieq $dHash) {
                    [System.IO.File]::Delete((Get-LP $Source))
                    return
                }
            }
            catch { }
        }

        if (-not [System.IO.Directory]::Exists((Get-LP $ConflictDir))) {
            [System.IO.Directory]::CreateDirectory((Get-LP $ConflictDir)) | Out-Null
        }

        $conflictPath = Join-Path $ConflictDir ([System.IO.Path]::GetFileName($Destination))
        $n = 1

        while ([System.IO.File]::Exists((Get-LP $conflictPath))) {
            $conflictPath = Join-Path $ConflictDir ("{0}_{1}" -f [System.IO.Path]::GetFileName($Destination), $n)
            $n++
        }

        Move-UnitSafe -Source $Destination -Destination $conflictPath
        Write-Log "Conflict secured: $conflictPath" 'WARN'
    }

    Move-UnitSafe -Source $Source -Destination $Destination
    Write-Log "Restored: $Destination" 'OK'
}

function Restore-DirectoryMerge {
    param(
        [string]$Source,
        [string]$Destination,
        [string]$ConflictDir
    )

    if (-not [System.IO.Directory]::Exists((Get-LP $Destination))) {
        [System.IO.Directory]::CreateDirectory((Get-LP $Destination)) | Out-Null
    }

    $stack = New-Object System.Collections.Generic.Stack[string]
    $stack.Push($Source)

    while ($stack.Count -gt 0) {
        $d = $stack.Pop()
        $rel = Get-RelPath -Root $Source -Full $d
        $destDir = $Destination

        if ($rel) {
            $destDir = Join-Path $Destination (Get-WinRel $rel)
        }

        if (-not [System.IO.Directory]::Exists((Get-LP $destDir))) {
            [System.IO.Directory]::CreateDirectory((Get-LP $destDir)) | Out-Null
        }

        foreach ($fRaw in [System.IO.Directory]::EnumerateFiles((Get-LP $d))) {
            $f = Remove-LP $fRaw
            $name = [System.IO.Path]::GetFileName($f)
            $destFile = Join-Path $destDir $name

            Restore-SingleFile -Source $f -Destination $destFile -ConflictDir $ConflictDir
        }

        foreach ($sRaw in [System.IO.Directory]::EnumerateDirectories((Get-LP $d))) {
            $stack.Push((Remove-LP $sRaw))
        }
    }

    try {
        [System.IO.Directory]::Delete((Get-LP $Source), $true)
    }
    catch { }
}

function Invoke-Restore {
    param(
        [string]$Root,
        [string]$Id,
        [switch]$UseLatest
    )

    $backupRoot = Join-Path $Root $BackupRootName

    if (-not [System.IO.Directory]::Exists((Get-LP $backupRoot))) {
        throw "No backup directory found: $backupRoot"
    }

    $backups = @(
        Get-ChildItem -LiteralPath $backupRoot -Directory |
        Where-Object { $_.Name -ne 'vanilla_snapshot' } |
        Sort-Object Name -Descending
    )

    if ($backups.Count -eq 0) {
        throw "No backups available."
    }

    if ($ListBackups) {
        Write-Host "`nAvailable backups:" -ForegroundColor Cyan

        foreach ($b in $backups) {
            $mp = Join-Path $b.FullName 'manifest.json'
            $info = ''

            if (Test-Path -LiteralPath $mp) {
                try {
                    $m = Get-Content -LiteralPath $mp -Raw -Encoding UTF8 | ConvertFrom-Json
                    $info = " | $($m.totalEntries) entries | $(Format-Size $m.totalSizeBytes)"
                }
                catch { }
            }

            Write-Host ("  {0}{1}" -f $b.Name, $info)
        }

        return
    }

    $selected = $null

    if ($Id) {
        $selected = $backups | Where-Object { $_.Name -eq $Id } | Select-Object -First 1

        if (-not $selected) {
            throw "Backup ID not found: $Id"
        }
    }
    elseif ($UseLatest -or $backups.Count -eq 1) {
        $selected = $backups[0]
    }
    else {
        Write-Host "`nAvailable backups:" -ForegroundColor Cyan

        for ($i = 0; $i -lt $backups.Count; $i++) {
            Write-Host ("  [{0}] {1}" -f ($i + 1), $backups[$i].Name)
        }

        $sel = Read-Host "`nSelection (1-$($backups.Count)), press ENTER to cancel"

        if ([string]::IsNullOrWhiteSpace($sel)) {
            Write-Host 'Cancelled.'
            return
        }

        $n = 0

        if (-not [int]::TryParse($sel, [ref]$n)) {
            throw 'Invalid selection.'
        }

        if ($n -lt 1 -or $n -gt $backups.Count) {
            throw 'Invalid selection.'
        }

        $selected = $backups[$n - 1]
    }

    $manifestPath = Join-Path $selected.FullName 'manifest.json'

    if (-not (Test-Path -LiteralPath $manifestPath)) {
        throw "manifest.json missing in $($selected.FullName)"
    }

    $manifest = Get-Content -LiteralPath $manifestPath -Raw -Encoding UTF8 | ConvertFrom-Json

    $Script:LogFile = Join-Path $selected.FullName 'restore.log'
    Write-Log "=== RESTORE started: $($selected.Name) ===" 'INFO'

    $payloadRoot = Join-Path $selected.FullName 'files'
    $conflictDir = Join-Path $selected.FullName '_conflicts'
    $entries = @($manifest.entries)

    Write-Host ""
    Write-Host ("Restoring {0} entries to: {1}" -f $entries.Count, $Root) -ForegroundColor Yellow

    if (-not $Yes) {
        $a = Read-Host 'Continue? [Y/N]'

        if ($a -notmatch '^[JjYy]') {
            Write-Host 'Cancelled.'
            return
        }
    }

    $ok = 0
    $fail = 0

    foreach ($e in $entries) {
        $relWin = Get-WinRel $e.rel
        $src = Join-Path $payloadRoot $relWin
        $dst = Join-Path $Root $relWin

        try {
            if ($e.isDir) {
                if ([System.IO.Directory]::Exists((Get-LP $src))) {
                    Restore-DirectoryMerge -Source $src -Destination $dst -ConflictDir $conflictDir
                    $ok++
                }
            }
            else {
                if ([System.IO.File]::Exists((Get-LP $src))) {
                    Restore-SingleFile -Source $src -Destination $dst -ConflictDir $conflictDir
                    $ok++
                }
            }
        }
        catch {
            $fail++
            Write-Log "Error at $($e.rel): $($_.Exception.Message)" 'ERROR'
        }
    }

    Write-Log "RESTORE finished. Successful: $ok  Failed: $fail" 'OK'
}

# =================================================================
# SECTION 7 - MAIN
# =================================================================

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

    Write-Host ''
    Write-Host '======================================================' -ForegroundColor Cyan
    Write-Host "  $Script:ToolName" -ForegroundColor Cyan
    Write-Host '======================================================' -ForegroundColor Cyan
    Write-Host "  Target: $GamePath"
    Write-Host ''

    if ($Restore -or $ListBackups) {
        Invoke-Restore -Root $GamePath -Id $BackupId -UseLatest:$Latest
        exit 0
    }

    foreach ($req in @('bin\x64\Cyberpunk2077.exe', 'engine', 'r6', 'archive')) {
        $p = Join-Path $GamePath $req

        if (-not ([System.IO.File]::Exists((Get-LP $p)) -or [System.IO.Directory]::Exists((Get-LP $p)))) {
            throw "Not a valid Cyberpunk 2077 installation. Missing: $req"
        }
    }

    foreach ($procName in @('Cyberpunk2077', 'REDprelauncher', 'redmod')) {
        $pr = Get-Process -Name $procName -ErrorAction SilentlyContinue

        if ($pr) {
            throw "$procName is still running. Please close it first."
        }
    }

    # ---- Create backup root early ----
    $backupRoot = Join-Path $GamePath $BackupRootName

    if (-not [System.IO.Directory]::Exists((Get-LP $backupRoot))) {
        [System.IO.Directory]::CreateDirectory((Get-LP $backupRoot)) | Out-Null
    }

    # ---- Dedicated rebuild mode ----
    if ($RebuildSnapshotOnly) {
        $Script:LogFile = Join-Path $backupRoot 'snapshot_rebuild.log'

        Write-Host ''
        Write-Host '================================================================' -ForegroundColor Yellow
        Write-Host '  REBUILD VANILLA SNAPSHOT' -ForegroundColor Yellow
        Write-Host '================================================================' -ForegroundColor Yellow
        Write-Host ''
        Write-Host 'The game must be CLEAN VANILLA before rebuilding the snapshot.' -ForegroundColor Yellow
        Write-Host 'If mods are installed, run GOG/Steam Verify first.' -ForegroundColor Yellow
        Write-Host ''

        if (-not $Yes) {
            $a = Read-Host 'Continue? [Y/N]'

            if ($a -notmatch '^[JjYy]') {
                Write-Host 'Cancelled.'
                exit 2
            }
        }

        $Script:SnapshotRoot = Get-SnapshotDir -BackupRoot $backupRoot

        if ([System.IO.Directory]::Exists((Get-LP $Script:SnapshotRoot))) {
            [System.IO.Directory]::Delete((Get-LP $Script:SnapshotRoot), $true)
        }

        [System.IO.Directory]::CreateDirectory((Get-LP $Script:SnapshotRoot)) | Out-Null

        if (-not (New-VanillaSnapshot -GamePath $GamePath -SnapshotDir $Script:SnapshotRoot)) {
            throw 'Snapshot could not be created.'
        }

        Write-Host ''
        Write-Host '======================================================' -ForegroundColor Green
        Write-Host '  SNAPSHOT REBUILT SUCCESSFULLY' -ForegroundColor Green
        Write-Host '======================================================' -ForegroundColor Green
        Write-Log "Snapshot location: $Script:SnapshotRoot" 'OK'

        exit 0
    }

    # ---- Load JSON manifest ----
    if ([string]::IsNullOrWhiteSpace($CleanJsonPath)) {
        $base = $PSScriptRoot
        if (-not $base) {
            $base = (Get-Location).Path
        }

        $CleanJsonPath = Join-Path $base 'Cyberpunk_clean.json'
    }

    $CleanJsonPath = [System.IO.Path]::GetFullPath($CleanJsonPath)

    Write-Log "Loading vanilla manifest: $CleanJsonPath"
    $manifest = Import-CleanManifest -JsonPath $CleanJsonPath
    Write-Log ("Vanilla entries: {0} files / {1} directories" -f $manifest.Files.Count, $manifest.Dirs.Count) 'OK'

    if (-not (Test-VanillaFile $manifest 'bin/x64/Cyberpunk2077.exe')) {
        $msg = 'Manifest does not list bin/x64/Cyberpunk2077.exe -> incomplete manifest.'

        if (-not $ForceManifest) {
            throw "$msg Aborted. (Override: -ForceManifest)"
        }

        Write-Log "$msg Override active!" 'WARN'
    }

    # ---- Initialize vanilla snapshot ----
    $Script:SnapshotRoot = Get-SnapshotDir -BackupRoot $backupRoot
    $needResnap = [bool]$ForceResnap

    if (-not [System.IO.Directory]::Exists((Get-LP $Script:SnapshotRoot))) {
        $needResnap = $true
    }
    elseif (-not (Test-SnapshotValid -SnapshotDir $Script:SnapshotRoot)) {
        Write-Host ''
        Write-Log 'WARNING: Vanilla snapshot is invalid/corrupted!' 'WARN'
        Write-Log '  -> Run GOG/Steam Verify, then recreate snapshot.' 'WARN'
        $needResnap = $true
    }

    if ($needResnap) {
        if ($CompareOnly -or $DryRun) {
            Write-Log 'Vanilla snapshot missing/invalid. Compare/Dry-run will not create it.' 'WARN'
        }
        else {
            Write-Host ''
            Write-Log 'Vanilla snapshot missing/invalid. A new snapshot must be created.' 'WARN'
            Write-Log 'The game must be CLEAN VANILLA. Run GOG/Steam Verify if unsure.' 'WARN'

            if (-not $Yes) {
                $a = Read-Host 'Create snapshot now? [Y/N]'

                if ($a -notmatch '^[JjYy]') {
                    Write-Host 'Cancelled.'
                    exit 2
                }
            }

            if ([System.IO.Directory]::Exists((Get-LP $Script:SnapshotRoot))) {
                [System.IO.Directory]::Delete((Get-LP $Script:SnapshotRoot), $true)
            }

            [System.IO.Directory]::CreateDirectory((Get-LP $Script:SnapshotRoot)) | Out-Null

            if (-not (New-VanillaSnapshot -GamePath $GamePath -SnapshotDir $Script:SnapshotRoot)) {
                throw 'Snapshot could not be created.'
            }
        }
    }
    else {
        Write-Log "Vanilla snapshot OK" 'OK'
    }

    # ---- Exclusions ----
    $excludeRel = New-Object System.Collections.Generic.List[string]
    $excludeRel.Add((Get-NormRel $BackupRootName))

    $toolFiles = @(
        'Safe_Mod_Cleaner.ps1',
        'Safe_Mod_Cleaner.bat',
        'New-CleanManifest.ps1',
        'Uninstall.bat',
        'Cyberpunk_clean.json',
        'RESTORE_HERE.bat'
    )

    $scriptDir = $PSScriptRoot
    if (-not $scriptDir) {
        $scriptDir = [System.IO.Path]::GetDirectoryName($PSCommandPath)
    }

    $toolBases = @($scriptDir, $GamePath)

    foreach ($base in $toolBases) {
        if ([string]::IsNullOrWhiteSpace($base)) { continue }

        foreach ($toolFile in $toolFiles) {
            $full = Join-Path $base $toolFile

            if ([System.IO.File]::Exists((Get-LP $full))) {
                if ($full.StartsWith($GamePath, [System.StringComparison]::OrdinalIgnoreCase)) {
                    $excludeRel.Add((Get-RelPath -Root $GamePath -Full $full))
                }
            }
        }
    }

    foreach ($self in @($PSCommandPath, $CleanJsonPath)) {
        if ($self -and $self.StartsWith($GamePath, [System.StringComparison]::OrdinalIgnoreCase)) {
            $excludeRel.Add((Get-RelPath -Root $GamePath -Full $self))
        }
    }

    # ---- Scan ----
    Write-Log "Scanning installation ..."

    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    $scan = Get-ScanResult -Root $GamePath -Manifest $manifest -ExcludeRel $excludeRel.ToArray()
    $sw.Stop()

    $toMove = @($scan.Units | Where-Object { $_.Action -eq 'Move' })
    $moveSize = ($toMove | Measure-Object -Property Size -Sum).Sum

    if (-not $moveSize) {
        $moveSize = 0
    }

    Write-Log ("Scan finished in {0:N1}s - {1} files checked" -f $sw.Elapsed.TotalSeconds, $scan.TotalFiles) 'OK'

    # ---- Version mismatch warning ----
    if (-not $SkipVersionCheck) {
        $foreignFiles = @($scan.Units | Where-Object { -not $_.Vanilla -and -not $_.IsDir })
        $foreignRatio = if ($scan.TotalFiles -gt 0) { $foreignFiles.Count / [double]$scan.TotalFiles } else { 0 }

        if ($foreignRatio -gt 0.5) {
            Write-Log ("NOTE: {0:P0} of all files are not in the vanilla manifest." -f $foreignRatio) 'WARN'
            Write-Log "This can be normal with many mods. Verify that the JSON matches your game version." 'WARN'
        }
    }

    # ---- Report ----
    Write-Host ''
    Write-Host '------------------- ANALYSIS -------------------' -ForegroundColor Cyan

    $toMove | Group-Object Scope | Sort-Object Name | ForEach-Object {
        $s = ($_.Group | Measure-Object -Property Size -Sum).Sum
        Write-Host ("  [MOVE] {0,-9} {1,5} entries   {2,12}" -f $_.Name, $_.Count, (Format-Size $s)) -ForegroundColor Yellow
    }

    Write-Host ("  Total to secure: {0} entries / {1}" -f $toMove.Count, (Format-Size $moveSize)) -ForegroundColor Cyan
    Write-Host '------------------------------------------------' -ForegroundColor Cyan

    # ---- Compare/DryRun ----
    if ($CompareOnly -or $DryRun) {
        Write-Host ''

        $label = if ($DryRun) { 'DRY-RUN' } else { 'COMPARE' }
        Write-Host "=== $label - NO CHANGES WILL BE MADE ===" -ForegroundColor Yellow

        $i = 0

        foreach ($u in $toMove) {
            $tag = if ($u.IsDir) { 'DIR ' } else { 'FILE' }
            Write-Host ("  [{0}] {1}  ({2})" -f $tag, $u.Rel, (Format-Size $u.Size))

            $i++
            if ($i -ge 300) {
                Write-Host "  ... and $($toMove.Count - 300) more"
                break
            }
        }

        if ($CompareOnly) {
            $reportPath = Join-Path $GamePath ("_modclean_report_{0}.json" -f (Get-Date -Format 'yyyy-MM-dd_HH-mm-ss'))

            [PSCustomObject]@{
                createdAt = (Get-Date -Format 'o')
                gamePath  = $GamePath
                mode      = 'Reset'
                manifest  = $CleanJsonPath
                scanned   = $scan.TotalFiles
                move      = $toMove
                report    = @()
            } | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $reportPath -Encoding UTF8

            Write-Log "Report saved: $reportPath" 'OK'
        }

        exit 0
    }

    # ---- No move targets ----
    if ($toMove.Count -eq 0) {
        if ([System.IO.Directory]::Exists((Get-LP $Script:SnapshotRoot)) -and
            (Test-SnapshotValid -SnapshotDir $Script:SnapshotRoot)) {

            Write-Log 'No mod files found. Checking vanilla files against snapshot...' 'INFO'

            $Script:PayloadRoot = Join-Path $backupRoot '_maintenance'
            $repairedCount = Repair-VanillaFilesFromSnapshot -GamePath $GamePath -SnapshotDir $Script:SnapshotRoot

            if ($repairedCount -gt 0) {
                Write-Log "Auto-Repair: $repairedCount files restored to vanilla state." 'OK'
            }
            else {
                Write-Log 'No mod files found - installation is clean.' 'OK'
            }
        }
        else {
            Write-Log 'No mod files found - installation is clean.' 'OK'
        }

        exit 0
    }

    # ---- Confirmation ----
    if (-not $Yes) {
        Write-Host ''
        Write-Host 'All affected files will be MOVED to a backup (not deleted).' -ForegroundColor Green
        Write-Host 'Vanilla cache and config files will be auto-repaired from snapshot.' -ForegroundColor Green

        $a = Read-Host 'Continue? [Y/N]'

        if ($a -notmatch '^[JjYy]') {
            Write-Host 'Cancelled.'
            exit 2
        }
    }

    # ---- Backup directory ----
    $stamp = Get-Date -Format 'yyyy-MM-dd_HH-mm-ss'
    $id = $stamp
    $n = 1

    while ([System.IO.Directory]::Exists((Get-LP (Join-Path $backupRoot $id)))) {
        $id = "{0}_{1}" -f $stamp, $n
        $n++
    }

    $backupDir = Join-Path $backupRoot $id
    $Script:PayloadRoot = Join-Path $backupDir 'files'

    [System.IO.Directory]::CreateDirectory((Get-LP $Script:PayloadRoot)) | Out-Null

    $Script:LogFile = Join-Path $backupDir 'cleaner.log'

    Write-Log "Backup: $backupDir"
    Write-Log "Mode: Reset | Manifest: $CleanJsonPath"

    try {
        Copy-Item -LiteralPath $CleanJsonPath -Destination (Join-Path $backupDir 'Cyberpunk_clean.used.json') -Force
    }
    catch { }

    # ---- Move files ----
    $movedEntries = New-Object System.Collections.Generic.List[object]
    $failed = 0
    $done = 0

    $sorted = @($toMove | Sort-Object { $_.Rel.Length })

    foreach ($u in $sorted) {
        $done++

        if ($sorted.Count -gt 20) {
            Write-Progress -Activity 'Securing mod files' -Status $u.Rel -PercentComplete (($done / $sorted.Count) * 100)
        }

        $dest = Join-Path $Script:PayloadRoot (Get-WinRel $u.Rel)

        try {
            if ($u.IsDir) {
                if (-not [System.IO.Directory]::Exists((Get-LP $u.Full))) { continue }
            }
            else {
                if (-not [System.IO.File]::Exists((Get-LP $u.Full))) { continue }
            }

            $sha = $null

            if ($Hash -and -not $u.IsDir -and $u.Size -le 32MB) {
                try {
                    $sha = (Get-FileHash -LiteralPath $u.Full -Algorithm SHA256).Hash
                }
                catch { }
            }

            Move-UnitSafe -Source $u.Full -Destination $dest -IsDirectory:$u.IsDir

            $movedEntries.Add([PSCustomObject]@{
                rel     = $u.Rel
                isDir   = [bool]$u.IsDir
                size    = $u.Size
                scope   = $u.Scope
                vanilla = [bool]$u.Vanilla
                sha256  = $sha
            })

            Write-Log "Secured: $($u.Rel)" 'MOVE'
        }
        catch {
            $failed++
            Write-Log "ERROR at $($u.Rel): $($_.Exception.Message)" 'ERROR'
        }
    }

    Write-Progress -Activity 'Securing mod files' -Completed

    # ---- Auto-Repair from snapshot ----
    if ([System.IO.Directory]::Exists((Get-LP $Script:SnapshotRoot)) -and
        (Test-SnapshotValid -SnapshotDir $Script:SnapshotRoot)) {

        Write-Host ''
        Write-Log 'Auto-Repair: Checking vanilla files against snapshot...' 'INFO'

        $repairedCount = Repair-VanillaFilesFromSnapshot -GamePath $GamePath -SnapshotDir $Script:SnapshotRoot

        if ($repairedCount -gt 0) {
            Write-Log "Auto-Repair: $repairedCount files restored to vanilla state." 'OK'
            Write-Log '  (Cache + Config files automatically restored from snapshot)' 'OK'
            Write-Log '  NO GOG/Steam Verify needed!' 'OK'
        }
        else {
            Write-Log 'All vanilla files already intact - no repair needed.' 'OK'
        }
    }
    else {
        Write-Log 'Auto-Repair skipped: snapshot unavailable.' 'WARN'
    }

    # ---- Restore mods/.stub ----
    $stubPath = Join-Path $GamePath 'mods\.stub'

    if ((Test-VanillaFile $manifest 'mods/.stub') -and -not [System.IO.File]::Exists((Get-LP $stubPath))) {
        try {
            [System.IO.Directory]::CreateDirectory((Get-LP (Split-Path $stubPath))) | Out-Null
            [System.IO.File]::WriteAllBytes((Get-LP $stubPath), (New-Object byte[] 0))
            Write-Log 'mods/.stub restored (vanilla placeholder).' 'OK'
        }
        catch {
            Write-Log 'mods/.stub could not be created.' 'WARN'
        }
    }

    # ---- Clean up empty foreign directories ----
    foreach ($root in @('archive\pc\mod', 'r6\scripts', 'r6\tweaks', 'bin\x64\plugins', 'red4ext', 'r6\cache\modded')) {
        $p = Join-Path $GamePath $root

        if (-not [System.IO.Directory]::Exists((Get-LP $p))) { continue }

        $rel = Get-NormRel $root

        if (Test-VanillaDir $manifest $rel) { continue }

        try {
            $enum = [System.IO.Directory]::EnumerateFileSystemEntries((Get-LP $p))

            if (-not $enum.GetEnumerator().MoveNext()) {
                [System.IO.Directory]::Delete((Get-LP $p), $false)
            }
        }
        catch { }
    }

    # ---- Write manifest ----
    $manifestOut = [ordered]@{
        tool           = $Script:ToolName
        createdAt      = (Get-Date -Format 'o')
        backupId       = $id
        gamePath       = $GamePath
        mode           = 'Reset'
        cleanManifest  = $CleanJsonPath
        totalEntries   = $movedEntries.Count
        totalSizeBytes = $moveSize
        failed         = $failed
        entries        = $movedEntries
        note           = 'Moved, not deleted. Restore: Safe_Mod_Cleaner.ps1 -Restore -BackupId <id>'
    }

    $jsonOut = $manifestOut | ConvertTo-Json -Depth 8

    [System.IO.File]::WriteAllText(
        (Get-LP (Join-Path $backupDir 'manifest.json')),
        $jsonOut,
        (New-Object System.Text.UTF8Encoding($false))
    )

    # ---- Write Restore BAT ----
    $restoreBat = @"
@echo off
setlocal

set "PS1=%~dp0..\..\Safe_Mod_Cleaner.ps1"
if not exist "%PS1%" set "PS1=$PSCommandPath"

if not exist "%PS1%" (
    echo Safe_Mod_Cleaner.ps1 not found.
    pause
    exit /b 1
)

powershell -NoProfile -ExecutionPolicy Bypass -File "%PS1%" -GamePath "$GamePath" -Restore -BackupId "$id"
pause
"@

    [System.IO.File]::WriteAllText(
        (Get-LP (Join-Path $backupDir 'RESTORE_HERE.bat')),
        $restoreBat,
        (New-Object System.Text.UTF8Encoding($false))
    )

    # ---- Summary ----
    Write-Host ''
    Write-Host '======================================================' -ForegroundColor Green
    Write-Host '  CLEANUP COMPLETED SUCCESSFULLY' -ForegroundColor Green
    Write-Host '======================================================' -ForegroundColor Green

    Write-Log "Secured: $($movedEntries.Count) entries / $(Format-Size $moveSize)" 'OK'
    Write-Log "Failed: $failed" 'OK'

    Write-Host ''
    Write-Host "  Backup : $backupDir"
    Write-Host "  Log    : $Script:LogFile"
    Write-Host "  Restore: RESTORE_HERE.bat in backup folder (double-click)"
    Write-Host ''
    Write-Host '  NO GOG/Steam Verify needed - vanilla files auto-repaired!' -ForegroundColor Green
    Write-Host ''

    if ($OpenBackup) {
        Invoke-Item -LiteralPath $backupDir
    }

    if ($failed -gt 0) {
        exit 3
    }

    exit 0
}
catch {
    Write-Host ''
    Write-Host "ERROR: $($_.Exception.Message)" -ForegroundColor Red

    if ($Script:LogFile) {
        Add-Content -LiteralPath $Script:LogFile -Value "[ERROR] $($_.Exception.Message)" -Encoding UTF8
    }

    exit 1
}