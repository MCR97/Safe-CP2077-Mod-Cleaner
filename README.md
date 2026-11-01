# Safe Cyberpunk 2077 Mod Cleaner v1.0

A safe PowerShell tool for **complete and reversible removal of all mods** from a Cyberpunk 2077 installation. Unlike simple deletion scripts, **not a single file is actually deleted** – everything is moved to a backup and can be restored with a single click.

The tool is based on a **vanilla whitelist** (`Cyberpunk_clean.json`) and reliably protects all original game files from accidental removal.

---

## ⚠️ CRITICAL PREREQUISITE: CLEAN VANILLA INSTALLATION

> **This tool relies on a 100% accurate vanilla file list.**
> 
> If you generate the `Cyberpunk_clean.json` manifest while mods are still installed, those mod files will be **permanently marked as "vanilla"** and **will NOT be removed** by the cleaner. This will break the tool completely.

### ✅ The "Golden Path" (Required Workflow):

1. **Uninstall all mods** OR run **"Verify integrity of game files"** in GOG Galaxy / Steam / Epic Games.
2. **Launch the game once** and reach the main menu (this generates the base `final.redscripts` and `tweakdb.bin`).
3. **Close the game completely.**
4. **Run `New-CleanManifest.ps1`** to generate your personal, accurate `Cyberpunk_clean.json`.
5. You are now ready to install mods and use the `Safe_Mod_Cleaner` whenever you want a clean slate.

### ❌ What NOT to do:

- ❌ Do NOT generate the manifest with mods installed
- ❌ Do NOT manually edit the `Cyberpunk_clean.json` file
- ❌ Do NOT share your personal manifest with others (it's platform- and version-specific)

---

## 🛡️ How It Works: Whitelist-Based Approach

Unlike traditional mod cleaners that use **blacklists** (known mod folders to delete), this tool uses a **whitelist** approach - similar to how security software works:

1. **Step 1:** You generate a manifest of all vanilla game files using `New-CleanManifest.ps1`
2. **Step 2:** The cleaner compares your installation against this whitelist
3. **Step 3:** Only files **NOT in the whitelist** are moved to backup
4. **Step 4:** Vanilla files are **never touched** - guaranteed

### Why is this better?

| Approach | How it works | Risk |
|---|---|---|
| **Blacklist** (traditional) | Deletes known mod folders | ❌ Misses unknown mods, may delete wrong files |
| **Whitelist** (this tool) | Protects known vanilla files | ✅ Works with any mod, zero risk to vanilla |

### Benefits

- ✅ Works with **any mod**, even unknown or future mods
- ✅ Platform-agnostic (GOG, Steam, Epic Games)
- ✅ Version-agnostic (works after game updates when manifest is regenerated)
- ✅ Zero risk of accidentally deleting vanilla files
- ✅ No need to maintain a list of "known mods"

---

## ✨ Features

| Feature | Description |
|---|---|
| 🛡️ **Whitelist-based** | Only files **not** in the vanilla manifest are touched |
| 📦 **Move instead of delete** | All removed files go to `_MOD_REMOVER_BACKUPS/<timestamp>/` |
| 🔁 **One-click restore** | `RESTORE_HERE.bat` is included in each backup – just double-click |
| 🧬 **Vanilla Snapshot** | Creates a copy of cache & config files on first run |
| 🔧 **Automatic Auto-Repair** | Restores modified cache/config from snapshot to vanilla state |
| 🚀 **No GOG Verify needed** | Snapshot auto-repairs everything after clean |
| 📊 **Analysis mode** | Shows what would happen before making changes |
| 🎯 **Two modes** | Reset to Vanilla (recommended) + Nuclear Option |
| 🔒 **NeverTouch list** | `Cyberpunk2077.exe` and other critical files are hard-protected |
| 🚫 **Symlink protection** | Reparse points are not followed |
| 📝 **Complete logging** | Every action is documented in `cleaner.log` |
| 🧪 **Dry-run** | Simulates the process without changes |
| 🌐 **Platform-agnostic** | Works with GOG, Steam, and Epic Games installations |

---

## 📥 Installation

### 1. Place tool files in the game folder

Copy the following files to your Cyberpunk 2077 installation directory (where `bin\`, `engine\`, `r6\`, and `archive\` are located):

```
Cyberpunk 2077/
├── bin/
├── engine/
├── r6/
├── archive/
├── Safe_Mod_Cleaner.ps1        ← Main script
├── Safe_Mod_Cleaner.bat        ← Menu launcher (double-click)
├── New-CleanManifest.ps1       ← Generator for vanilla JSON
└── Uninstall.bat               ← Uninstaller
```

### 2. Create the vanilla manifest

Before using the cleaner for the first time, you must create a fresh vanilla manifest. See [The Vanilla Manifest](#-the-vanilla-manifest).

### 3. PowerShell Execution Policy (first time only)

If PowerShell blocks script execution, run **once** as Administrator:

```powershell
Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned
```

> 💡 The `Safe_Mod_Cleaner.bat` bypasses this restriction automatically via `-ExecutionPolicy Bypass`.

---

## 🎮 Quick Start

### Recommended Workflow for Beginners

1. **Open the game folder** (where the `.bat` is located)
2. **Double-click `Safe_Mod_Cleaner.bat`**
3. In the menu, choose **`[1] Analyze`** – the tool shows what it would find
4. If everything looks plausible: choose **`[3] RESET TO VANILLA`**
5. Confirm with `Y`
6. Done – all mods are secured in the backup folder, vanilla files auto-repaired

### Command Line Variant

```powershell
# Analyze only (no changes)
.\Safe_Mod_Cleaner.ps1 -CompareOnly

# Run Reset to Vanilla
.\Safe_Mod_Cleaner.ps1

# Restore latest backup
.\Safe_Mod_Cleaner.ps1 -Restore -Latest
```

---

## 📋 The Vanilla Manifest

### What is it?

The file `Cyberpunk_clean.json` is a **whitelist of all vanilla files** in your game installation. The cleaner compares every file in the game folder against this list:

- ✅ **In the list** → Vanilla → **never** touched
- ❌ **Not in the list** → potential mod file → will be removed

### How do I create the manifest?

#### Method 1: Generator Script (recommended)

1. **GOG Galaxy / Steam / Epic → Cyberpunk 2077 → Verify integrity of game files**
   - This restores all vanilla files
2. **Manually remove mods** (or use `Disable_All_Mods.bat`)
3. **Launch the game once** until the main menu (so `final.redscripts` is generated)
4. **Run `New-CleanManifest.ps1`** (via menu: option `[7]`)

```powershell
.\New-CleanManifest.ps1
```

The script automatically creates `Cyberpunk_clean.json` in the tool folder.

#### Method 2: With Hashes (for maximum safety)

```powershell
.\New-CleanManifest.ps1 -IncludeHashes
```

Stores size and SHA256 hash for each file. Enables later detection of **modified** vanilla files.

### When must the manifest be recreated?

- ✅ After a **game update** (GOG/Steam)
- ✅ After **switching game versions** (e.g., GOG ↔ Steam)
- ❌ **Not** after installing/removing mods

---

## 🎯 The Two Modes

### Mode `Reset to Vanilla` (Standard, recommended)

Removes **all mod files and folders**, then **automatically repairs** cache and config files from the vanilla snapshot:

| Category | Examples |
|---|---|
| **ModCore** | `red4ext/`, `r6/scripts/`, `r6/tweaks/`, `archive/pc/mod/`, `bin/x64/plugins/`, `mods/`, `V2077/` |
| **Cache (foreign)** | `r6/cache/modded/`, `*.redscripts.bk` |
| **Bin (foreign)** | `d3d11.dll`, `version.dll`, `winmm.dll`, `powrprof.dll` (DLL proxies) |
| **Config (foreign)** | Any non-vanilla config files |
| **Content (foreign)** | `archive/pc/content/*.archive` (with `-IncludeContentArchives`) |

**Auto-Repair:** After the clean, the tool automatically restores vanilla cache and config files from the snapshot. **No GOG/Steam Verify needed!**

**When to use?**
- Always when you just want to remove mods
- Standard mode for 99% of all use cases

### Mode `Nuclear Option` (Force Vanilla Reset)

**Force-resets ALL files to vanilla state from snapshot**:

- Removes all mod files
- Removes all vanilla cache files (final.redscripts, tweakdb.bin)
- Removes all vanilla config files
- **Automatically restores everything from vanilla snapshot**

**✅ No GOG/Steam Verify needed!** The snapshot restores all files to their exact vanilla state.

**When to use?**
- When you want to guarantee a 100% vanilla state
- When you suspect cache/config corruption
- For a complete "factory reset" of your installation

---

## 🧬 Vanilla Snapshot System

### What is it?

On the **very first run**, the tool automatically creates a snapshot of vanilla cache and config files:

```
_MOD_REMOVER_BACKUPS/
└── vanilla_snapshot/
    ├── info.json                  ← Metadata + SHA256 hashes
    ├── README_DO_NOT_DELETE.txt   ← Protection notice
    ├── r6/cache/final.redscripts  ← Vanilla copy
    ├── r6/cache/tweakdb.bin       ← Vanilla copy
    ├── engine/config/base/general.ini  ← Vanilla copy
    └── ... (all cache + config files)
```

### Why is this useful?

When you use mods with redscript/TweakDB, these files get modified. The cleaner can then **automatically repair them from the snapshot** – without GOG Verify, without download, in seconds.

### Process on every Reset

```
1. Validate snapshot (hash check)
2. Scan and move mod files
3. For each vanilla cache/config file:
   ├─ Hash identical to snapshot? → Already vanilla, do nothing
   └─ Hash different? → Modded!
        • Modded file → backup as .modded
        • Vanilla from snapshot → back to original location
4. Game starts guaranteed with vanilla cache/config
5. NO GOG/Steam Verify needed!
```

### If the snapshot is corrupted

The tool warns:

```
WARNING: Vanilla snapshot is invalid/corrupted!
  -> Run GOG/Steam Verify, then recreate snapshot.
```

**Solution:**
1. GOG Galaxy → Verify integrity of game files
2. Menu option `[8] Recreate Snapshot`

---

## 🔄 Restore

### Method 1: Via Menu

1. Start `Safe_Mod_Cleaner.bat`
2. **`[5] List Backups`** – shows all available backups
3. **`[6] Restore`** – interactive backup selection

### Method 2: RESTORE_HERE.bat in Backup

Each backup contains a `RESTORE_HERE.bat`:

```
_MOD_REMOVER_BACKUPS/
└── 2026-10-30_14-22-01/
    ├── manifest.json
    ├── cleaner.log
    ├── RESTORE_HERE.bat    ← Double-click!
    └── files/
        └── ... (secured mods)
```

### Method 3: Command Line

```powershell
# Restore latest backup
.\Safe_Mod_Cleaner.ps1 -Restore -Latest

# Restore specific backup
.\Safe_Mod_Cleaner.ps1 -Restore -BackupId 2026-10-30_14-22-01

# List all backups
.\Safe_Mod_Cleaner.ps1 -ListBackups
```

---

## ⚙️ Requirements

| Component | Requirement |
|---|---|
| Operating System | Windows 10 / 11 (64-bit) |
| PowerShell | Version 5.1 or newer (included in Windows) |
| Game | Cyberpunk 2077 (GOG, Steam, or Epic Games) |
| Vanilla Manifest | `Cyberpunk_clean.json` in tool folder (see [The Vanilla Manifest](#-the-vanilla-manifest)) |

**No additional installations needed** – no Python, no .NET, no external tools.

### Platform Support

This tool is **Windows-only**. This is intentional:
- Cyberpunk 2077 has no native macOS support
- Linux modding uses different toolchains (protontricks, shell scripts)
- ~95% of the modding community uses Windows

**Linux / macOS Users:** If you want to port this tool to your platform, the source code is available. Community ports are welcome – please open an issue to coordinate.

---

## 🔧 Parameter Reference

### Main Parameters

| Parameter | Description |
|---|---|
| `-GamePath <path>` | Game folder (default: script folder) |
| `-CleanJsonPath <path>` | Path to vanilla JSON (default: `Cyberpunk_clean.json` next to script) |

### Action Parameters

| Parameter | Description |
|---|---|
| `-CompareOnly` | Analyze only, no changes |
| `-DryRun` | Simulates the clean, shows what would happen |
| `-Yes` | Skips the confirmation prompt |
| `-OpenBackup` | Opens the backup folder after completion |

### Advanced Parameters

| Parameter | Description |
|---|---|
| `-NuclearOption` | Force vanilla reset (removes cache/config, restores from snapshot) |
| `-IncludeContentArchives` | Also removes foreign `archive/pc/content/*.archive` |
| `-IncludeUnknown` | Also removes files in unknown paths |
| `-NoAutoRepair` | Disables automatic cache/config repair from snapshot |
| `-ForceManifest` | Override: Ignores manifest plausibility checks |
| `-SkipVersionCheck` | Skips the version mismatch warning |
| `-Hash` | Calculates SHA256 for each moved file |

### Restore Parameters

| Parameter | Description |
|---|---|
| `-Restore` | Activates restore mode |
| `-BackupId <id>` | Restore specific backup |
| `-Latest` | Restore the newest backup |
| `-ListBackups` | Shows all available backups |

---

## 📝 Examples and Workflows

### Example 1: Safely remove mods (standard)

```powershell
.\Safe_Mod_Cleaner.ps1
```

**Result:**
- All mods are secured in backup
- Vanilla files are untouched
- Cache/config are automatically repaired from snapshot
- Game can start immediately
- **NO GOG/Steam Verify needed!**

### Example 2: Test first, then execute

```powershell
# Step 1: Just look
.\Safe_Mod_Cleaner.ps1 -CompareOnly

# Step 2: Simulate
.\Safe_Mod_Cleaner.ps1 -DryRun

# Step 3: Execute
.\Safe_Mod_Cleaner.ps1
```

### Example 3: Force vanilla reset (Nuclear)

```powershell
.\Safe_Mod_Cleaner.ps1 -NuclearOption
```

**Afterwards:**
- All mods removed
- All cache/config force-reset to vanilla
- **NO GOG/Steam Verify needed** - snapshot restores everything!

### Example 4: Automated (e.g., in a larger script)

```powershell
.\Safe_Mod_Cleaner.ps1 -Yes -OpenBackup
```

### Example 5: After a game update

```powershell
# 1. Run GOG/Steam Verify
# 2. Create new manifest
.\New-CleanManifest.ps1 -Force

# 3. Cleaner now runs with current whitelist
.\Safe_Mod_Cleaner.ps1
```

### Example 6: Restore backup

```powershell
# List all backups
.\Safe_Mod_Cleaner.ps1 -ListBackups

# Restore latest backup
.\Safe_Mod_Cleaner.ps1 -Restore -Latest

# Restore specific backup
.\Safe_Mod_Cleaner.ps1 -Restore -BackupId 2026-10-30_14-22-01
```

---

## 🗑️ Uninstallation

To completely remove the tool from your game directory:

1. Double-click `Uninstall.bat` in your game folder.
2. Type `UNINSTALL` to confirm.
3. The script deletes all tool files, the vanilla manifest, all backups, and itself.

**⚠️ WARNING:** All backups in `_MOD_REMOVER_BACKUPS` will be permanently deleted. If you want to restore mods later, use the Restore function BEFORE uninstalling!

---

## 🔍 Troubleshooting

### "Not a valid Cyberpunk 2077 installation"

**Cause:** The script was not started in the game folder.

**Solution:**
- Make sure `bin\x64\Cyberpunk2077.exe` exists in the target folder
- Or use `-GamePath "C:\Path\to\Game"`

### "Clean manifest not found"

**Cause:** `Cyberpunk_clean.json` is missing.

**Solution:**
- Run generator: `.\New-CleanManifest.ps1`
- Or place the file manually in the tool folder

### "Manifest does not list bin/x64/Cyberpunk2077.exe"

**Cause:** The manifest is incomplete or from a different game version.

**Solution:**
- Run GOG/Steam Verify
- Recreate with `.\New-CleanManifest.ps1 -Force`

### "NOTE: X % of all files are not in the vanilla manifest"

**Cause:** Many mods installed OR manifest doesn't match game version.

**Solution:**
- With many mods: Normal, just confirm with `Y`
- With version mismatch: Recreate manifest

### "Cyberpunk2077 is still running"

**Cause:** The game or REDprelauncher is still active.

**Solution:** Close the game completely, then try again.

### "WARNING: Vanilla snapshot is invalid/corrupted!"

**Cause:** Snapshot is corrupted or missing.

**Solution:**
1. Run GOG/Steam Verify
2. Recreate snapshot: Menu option `[8]` or `-ForceResnap`

### Restore doesn't restore files

**Cause:** Target folder already exists with different version.

**Solution:**
- Conflicts are in `_conflicts/` in the backup folder
- Check manually and move

### "PowerShell was not found"

**Cause:** Very old Windows or PowerShell uninstalled.

**Solution:**
- Windows 10/11 has PowerShell by default
- Otherwise: Install [PowerShell 7](https://github.com/PowerShell/PowerShell)

---

## 🛡️ Safety and Guarantees

### ✅ What the tool guarantees

1. **Vanilla files are never deleted** – they are protected by the whitelist
2. **NeverTouch list** – `Cyberpunk2077.exe` and critical DLLs are hard-protected
3. **Everything is moved, never deleted** – rollback is always possible
4. **Backup structure is self-explanatory** – `manifest.json` documents everything
5. **Symlinks are not followed** – no escaping from the game folder
6. **Running game is detected** – abort before making changes
7. **Auto-Repair** – Cache and config are automatically restored from snapshot
8. **No GOG/Steam Verify needed** – snapshot handles everything

### ⚠️ What you must keep in mind

1. **Manifest must match the game version** – otherwise vanilla files are detected as "foreign"
2. **Do not delete the snapshot** – otherwise auto-repair is no longer possible
3. **Clean up backups manually** – the tool never deletes old backups automatically

### 🛡️ Multi-level Security

```
Level 1: Whitelist check (Cyberpunk_clean.json)
Level 2: NeverTouch list (hard-coded protection list)
Level 3: Scope rules (only known mod folders are touched)
Level 4: Manifest plausibility (Cyberpunk2077.exe must be in it)
Level 5: Version mismatch warning (at >50% foreign files)
Level 6: Confirmation prompt (at Nuclear: type "NUCLEAR")
Level 7: Backup before every change
Level 8: Restore with conflict handling
Level 9: Auto-Repair from snapshot
```

---

## 🔬 Technical Details

### Decision Logic

```
For each file/folder in the game:

1. Is it in the NeverTouch list?
   → YES: Protect (never touch)

2. Is it in the vanilla manifest?
   → YES: 
      - Nuclear Option + Cache/Config? → Move (then restore from snapshot)
      - Otherwise → Protect
   → NO: Continue to step 3

3. Is it a foreign file?
   → YES: Move (Reset to Vanilla)
   → NO: Protect
```

### Performance

- **Directory pruning**: Folders without vanilla entries are moved as a whole (1 move op instead of thousands of file ops)
- **Long path support**: `\\?\` prefix for paths > 260 characters
- **Binary search**: For vanilla sub-folder checks
- **Typical runtime**: 5–30 seconds for scan + move (depending on mod count)

### Backup Structure

```
_MOD_REMOVER_BACKUPS/
├── vanilla_snapshot/             ← Vanilla cache + config (never delete!)
│   ├── info.json
│   ├── final.redscripts
│   ├── tweakdb.bin
│   └── ... (all cache + config)
│
├── 2026-10-30_14-22-01/          ← Backup #1
│   ├── manifest.json             ← Metadata
│   ├── cleaner.log               ← Action log
│   ├── Cyberpunk_clean.used.json ← Copy of used whitelist
│   ├── RESTORE_HERE.bat          ← One-click restore
│   └── files/                    ← Moved mods
│       ├── red4ext/
│       ├── r6/scripts/
│       └── ...
│
└── 2026-10-31_09-15-42/          ← Backup #2
    └── ...
```

---

## 📁 File Structure

```
Cyberpunk 2077/
│
├── bin/                              ← Vanilla
├── engine/                           ← Vanilla
├── r6/                               ← Vanilla
├── archive/                          ← Vanilla
├── tools/                            ← Vanilla (REDmod)
├── GOG/                              ← Vanilla
│
├── Safe_Mod_Cleaner.ps1              ← Main script
├── Safe_Mod_Cleaner.bat              ← Menu launcher
├── New-CleanManifest.ps1             ← Generator
├── Uninstall.bat                     ← Uninstaller
├── Cyberpunk_clean.json              ← Vanilla whitelist (generated)
│
├── _MOD_REMOVER_BACKUPS/             ← Backups (never delete!)
│   ├── vanilla_snapshot/             ← Vanilla cache + config
│   └── <timestamp>/                  ← Clean backups
│
└── red4ext/                          ← Mod folder (will be removed)
    r6/scripts/                       ← Mod scripts (will be removed)
    archive/pc/mod/                   ← Mod archives (will be removed)
    ...
```

---

## 🙏 Credits & Inspiration

This tool was heavily inspired by the original work found here:  
🔗 **[Cyberpunk 2077 Mod Cleaner (Original)](https://www.nexusmods.com/cyberpunk2077/mods/8597)**

A huge thank you to the original author for paving the way and inspiring the development of this advanced, whitelist-based cleanup tool!

---

## 📄 License & Transparency

This project is licensed under the **MIT License** - see the [LICENSE](LICENSE) file for details.

*Transparency Note: This tool was developed with the assistance of AI coding tools and has been thoroughly tested for safety and performance. However, it is provided "as-is" without warranty. Always ensure you have a valid backup of your game files before running mod management scripts.*

**Backup strategy:**
1. Before major changes: Copy the entire game folder.
2. After each clean: Check the backup folder.
3. If problems occur: Use `RESTORE_HERE.bat` to roll back.

---

**Have fun modding – and cleaning up safely!** 🚀