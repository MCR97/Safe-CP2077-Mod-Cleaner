# Safe Cyberpunk 2077 Mod Cleaner v1.1

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B-blue.svg)](https://microsoft.com/powershell)
[![Cyberpunk 2077](https://img.shields.io/badge/Cyberpunk%202077-2.0%2B%20%7C%20Phantom%20Liberty-red.svg)](https://www.cyberpunk.net)

A robust, fail-safe, whitelist-based mod cleaner for **Cyberpunk 2077**. 

Unlike conventional cleaners that delete files or rely on static blacklist rules (which become obsolete when new mods emerge), **Safe CP2077 Mod Cleaner** uses an exact JSON snapshot of a clean game installation (`Cyberpunk_clean.json`) to guarantee that all vanilla files are protected while non-vanilla files are quarantined into backups.

---

## 🌟 Key Features

* **🛡️ Whitelist Guarantee (Zero Data Loss):** Uses an exact file manifest of a clean vanilla installation. **Nothing is permanently deleted**; all non-whitelisted files are moved to a quarantine backup folder (`_MOD_REMOVER_BACKUPS/`).
* **📦 Automatic Vanilla Snapshot & Repair:** On initial run, the tool creates an internal snapshot of critical cache and configuration files (`.redscripts`, `tweakdb.bin`, `.ini`, `.xml`, `.json`). During a reset, changed cache/config files are auto-repaired using SHA-256 validation **without requiring a Steam/GOG file integrity check**.
* **🖥️ Interactive Cyberdeck CLI:** A custom Cyberpunk-themed batch launcher (`Safe_Mod_Cleaner.bat`) provides an easy-to-use menu system.
* **⚡ Dry-Run & Scan Modes:** Preview all affected files and total disk space to be moved before making any actual system changes.
* **🔄 One-Click Restore System:** Restores previous mod configurations from quarantine backups with automated conflict handling.
* **🛠️ Custom Manifest Generator:** Included script (`New-CleanManifest.ps1`) allows users to generate an updated whitelist for future game patches or customized vanilla baselines.
* **⚡ Long-Path & Special Character Support:** Built-in Win32 API long-path prefixing (`\\?\`) handles deep folder trees without crashing.

---

## 📁 Repository & File Structure

| File / Folder | Purpose |
| :--- | :--- |
| `Safe_Mod_Cleaner.bat` | Interactive Cyberdeck launcher (CMD UI). |
| `Safe_Mod_Cleaner.ps1` | Primary logic engine (PowerShell 5.1+). |
| `New-CleanManifest.ps1` | Standalone script to generate `Cyberpunk_clean.json`. |
| `Cyberpunk_clean.json` | Master whitelist manifest containing all vanilla file structures. |
| `Uninstall.bat` | Automated clean uninstaller for the tool and its backups. |
| `_MOD_REMOVER_BACKUPS/` | *(Auto-generated)* Quarantine directory containing backups and snapshots. |

---

## 🚀 Quick Start Guide

### Installation
1. Download the latest release.
2. Extract all contents directly into your **Cyberpunk 2077 main game directory** (e.g., `C:\Program Files (x86)\Steam\steamapps\common\Cyberpunk 2077\`).

### Usage
1. Make sure **Cyberpunk 2077**, **REDprelauncher**, and **REDmod** are closed.
2. Double-click `Safe_Mod_Cleaner.bat`.
3. Choose an option from the Cyberdeck interface:
   * **`[1] SCAN_SYSTEM`**: Analyzes the installation and lists non-vanilla files (read-only).
   * **`[2] SIMULATE_BREACH`**: Previews files that will be moved in a reset operation (Dry-Run).
   * **`[3] RESET_TO_VANILLA`**: Performs the full cleanup. Moves mods to quarantine and restores cached vanilla files from the snapshot.
   * **`[4] LIST_ARCHIVES`**: Displays all previous backup archives.
   * **`[5] RESTORE_BACKUP`**: Prompts you to restore a chosen backup archive.
   * **`[6] GEN_MANIFEST`**: Generates a fresh `Cyberpunk_clean.json` (requires clean vanilla game).
   * **`[7] REBUILD_SNAPSHOT`**: Re-initializes the vanilla cache/config snapshot.

---

## ⚙️ Advanced PowerShell Parameters

If you prefer running via PowerShell console directly:

```powershell
.\Safe_Mod_Cleaner.ps1 [-GamePath <Path>] [-CleanJsonPath <Path>] [-CompareOnly] [-DryRun] [-Yes] [-Restore] [-BackupId <ID>] [-ListBackups] [-RebuildSnapshotOnly]
```

### Parameter Reference

* `-GamePath "<Path>"`: Explicitly specify the target game folder (defaults to script directory).
* `-CleanJsonPath "<Path>"`: Path to `Cyberpunk_clean.json` whitelist.
* `-CompareOnly`: Analyzes installation and outputs a detailed `_modclean_report_<date>.json` report file.
* `-DryRun`: Previews file movements in console without altering files.
* `-Yes`: Suppresses interactive confirmation prompts (silent execution mode).
* `-Restore`: Initiates backup restoration workflow.
* `-BackupId "<ID>"`: Target backup folder timestamp to restore directly.
* `-RebuildSnapshotOnly`: Re-creates the vanilla snapshot directory without executing cleanup.

---

## 🏗️ Generating a Custom Clean Manifest

If a new major game update is released by CD Projekt Red:

1. Perform a **Verify Integrity of Game Files** in Steam/GOG/Epic.
2. Run the game **once** to reach the main menu, then exit.
3. Run `New-CleanManifest.ps1` or select **Option `[6]`** in `Safe_Mod_Cleaner.bat`.
4. The tool will scan all vanilla files and generate an updated `Cyberpunk_clean.json`.

---

## 🔒 Safety & Exclusions

The cleaner strictly avoids touching critical launcher/installer binaries and tool execution files:
* `bin/x64/Cyberpunk2077.exe`
* `bin/x64/Cyberpunk2077.exe.config`
* `uninstall.exe`
* All cleaner scripts (`Safe_Mod_Cleaner.*`, `New-CleanManifest.ps1`, `Cyberpunk_clean.json`)

---

## 📜 License

Distributed under the **MIT License**. See `LICENSE` for more information.
