# UTKeeper99 (UTK)

```
 ____ ___ ___________ ____  __.                                      ________  ________  
|    |   \\__    ___/|    |/ _| ____   ____  ______    ____ _______ /   __   \/   __   \ 
|    |   /  |    |   |      < _/ __ \_/ __ \ \____ \ _/ __ \\_  __ \\____    /\____    / 
|    |  /   |    |   |    |  \\  ___/\  ___/ |  |_> >\  ___/ |  | \/   /    /    /    /  
|______/    |____|   |____|__ \\___  >\___  >|   __/  \___  >|__|     /____/    /____/   
                             \/    \/     \/ |__|         \/                             
                                                                                         
```

**Comprehensive Unreal Tournament 99 / Web Server Management Suite**

By **[KoD]Prom** - Killers on Demand Clan (since 1999)

---

## 📋 Table of Contents

- [Overview](#overview)
- [Features](#features)
- [Requirements](#requirements)
- [Installation](#installation)
- [First Run Setup](#first-run-setup)
- [Main Menu](#main-menu)
- [MapTools Features](#maptools-features)
- [Orphan Scanner](#orphan-scanner)
- [SmartBackup](#smartbackup)
- [Configuration](#configuration)
- [Safety Features](#safety-features)
- [Credits](#credits)
- [Support](#support)
- [License](#license)

---

## 🎯 Overview

UTKeeper99 is a comprehensive server management suite for Unreal Tournament 99 (UT99) Linux servers. 
Born from a simple service start/stop script, it has evolved into a full-featured administration toolkit designed to make server management easier and safer.

**Forged on Debian 12 Trixie**

### What Makes UTKeeper99 Special?

- **Smart Auto-Configuration** - First-run setup with intelligent path detection
- **DryRun Mode** - Test operations safely before executing
- **Modular Design** - Easy to expand and customize
- **Comprehensive Backup** - Integrated SmartBackup system
- **Advanced Orphan Detection** - Find and remove unused packages safely

---

## ✨ Features

### Core Features

- ✅ **Auto-Configuration** - Intelligent detection of UT server and web paths
- ✅ **Service Management** - Start/Stop UT server and Apache/Nginx
- ✅ **Log Monitoring** - Real-time system and UT log viewing
- ✅ **MapTools Suite** - Complete map management toolkit
- ✅ **SmartBackup** - Automated backup with disk space validation
- ✅ **Orphan Scanner** - Advanced dependency-based cleanup
- ✅ **DryRun Mode** - Safe testing before actual operations
- ✅ **SNAFU Fix** - Emergency repair tool for permissions

### MapTools Features

- **Recursive Archive Extraction** (up to 10 levels deep)
- **Smart File Collection** (gathers all UT files from subdirs)
- **UCC Compression** (.uz format creation)
- **Automated Distribution** (to UT server and web redirect)
- **Map Cloning** (convert CTF/AS/DOM maps to DM format)
- **Case-Sensitive Fixes** (Linux filename normalization)
- **Permission Management** (chmod/chown automation)
- **Installation Verification** (corrupt file detection)

### Orphan Scanner Features

- **Dependency Extraction** - UCC packagedump-based analysis
- **Whitelist Generation** - 4-source protection system:
  - System packages (hardcoded)
  - Map dependencies (extracted)
  - ServerPackages (from INI)
  - Pattern-based (Skins, Fonts, FX, etc.)
- **Interactive Cleanup** - Choose what to keep/delete
- **Web Redirect Cleanup** - Remove orphaned .uz files
- **50+ Warning System** - Alerts for unusual orphan counts

---

## 📦 Requirements

### System Requirements

- **OS**: Linux (tested on Debian 12 Trixie)
- **Shell**: Bash 4.x or higher
- **Tools**: sudo, coreutils, grep, sed, awk, find
- **Disk Space**: Sufficient for backup operations

### UT99 Server Requirements

- **32-bit UT99 Server** (locally installed)
- **UCC Binary** (for compression and dependency extraction)
- **Web Redirect** (optional, but recommended for full functionality)

### Additional Packages

```bash
# Debian/Ubuntu
sudo apt install zip unzip p7zip-full p7zip-rar unrar bc

# For web server (choose one)
sudo apt install apache2  # or nginx
```

---

## 🚀 Installation

### Method 1: User Desktop (Recommended for Testing)

```bash
# Extract to your desktop
cd ~/Desktop
unzip utkeeper99.zip
cd utkeeper

# Make executable
chmod +x utkeeper.sh
chmod +x libs/*.sh

# Run (will prompt for sudo when needed)
./utkeeper.sh
```

### Method 2: System-Wide Installation

```bash
# Install to /opt
sudo mkdir -p /opt/utkeeper99
sudo unzip utkeeper99.zip -d /opt/utkeeper99
cd /opt/utkeeper99

# Set permissions
sudo chmod +x utkeeper.sh libs/*.sh
sudo chown -R root:root .

# Create symlink (optional)
sudo ln -s /opt/utkeeper99/utkeeper.sh /usr/local/bin/utkeeper

# Run
sudo utkeeper
```

### Method 3: User-Local Installation

```bash
# Install to home directory
mkdir -p ~/.local/share/utkeeper99
unzip utkeeper99.zip -d ~/.local/share/utkeeper99
cd ~/.local/share/utkeeper99

chmod +x utkeeper.sh libs/*.sh

# Add to PATH (optional)
echo 'export PATH="$HOME/.local/share/utkeeper99:$PATH"' >> ~/.bashrc
source ~/.bashrc
```

---

## ⚙️ First Run Setup

On first run, UTKeeper99 will guide you through automatic configuration:

### Auto-Detection Features

1. **UT Server Path Detection**
   - Searches common paths: `/opt/utserver`, `/opt/ut99`, `/home/utserver`, etc.
   - Validates installation (checks for System, Maps, Textures directories)

2. **Web Server Detection**
   - Auto-detects Apache or Nginx
   - Finds DocumentRoot automatically
   - Locates UT redirect directory (searches for .uz files)

3. **Service Detection**
   - Finds UT service: `utserver.service`, `ut-server.service`, `ut.service`
   - Finds web service: `apache2.service`, `httpd.service`, `nginx.service`

4. **Ownership Detection**
   - Auto-detects file owners (user:group)
   - Applies to both UT server and web server

### Manual Configuration

If auto-detection fails or you want custom paths:

1. Run: **Option 8 - Configuration**
2. Follow prompts to set:
   - UT Server path
   - UT user/group
   - Web server path
   - Web redirect path
   - Web user/group

### Configuration File

Settings are saved to `.config` in project root:
```bash
# Example .config
UT_BASE_PATH="/opt/utserver"
UT_USER="utserver"
UT_GROUP="utserver"
WEB_ROOT="/var/www/html"
UT_REDIRECT="/var/www/html/ut"
WEB_USER="www-data"
WEB_GROUP="www-data"
```

**⚠️ Important:** Do NOT edit `.config` manually - use Option 8!

---

## 📖 Main Menu

```
UTKEEPER99 v2.5 - MAIN MENU

1. Start Services       - Start UT server + web server
2. Stop Services        - Stop UT server + web server
3. System Logs          - Real-time system-wide logs
4. UT Server Log        - Real-time UT server log
5. Log Overview         - Complete system and UT log overview
6. Clean Logs           - Delete/truncate system and UT logs
7. MapTools            - Map management suite (see below)
8. Configuration        - Edit server paths and settings
9. Toggle DryRun        - Enable/disable safe testing mode
S. SmartBackup         - Backup management system
R. README              - Show this file

Q. Quit
```

---

## 🗺️ MapTools Features

Access via **Main Menu → 7. MapTools**

### MapTools Menu

```
1. Extract Archives     - Decompress all files in /upload
2. Compress to .uz      - Create .uz files with UCC
3. Distribution         - Deploy to UT server and web
4. Cleanup Upload       - Clear /upload directory
5. SNAFU Fix           - Emergency permission repair
6. Verify Installation  - Check for corrupt files
7. Clone Maps          - Create DM variants from other gametypes
8. Orphan Scanner      - Advanced orphan detection (see below)

B. Back to Main Menu
```

### Workflow Example

**Installing New Maps:**

1. Drop files into `/upload/` directory:
   ```
   upload/
   ├── MyMaps.zip
   ├── CoolTextures.rar
   └── NewSounds.7z
   ```

2. **Option 1: Extract Archives**
   - Recursively extracts (up to 10 levels)
   - Moves archives to `/upload/installed/` for backup
   - Collects all UT files to `/upload/`

3. **Option 2: Compress to .uz**
   - Creates .uz compressed versions
   - Uses UCC compression

4. **Option 3: Distribution**
   - Maps (.unr) → UT `/Maps` + Web redirect
   - Textures (.utx) → UT `/Textures` + Web redirect
   - Sounds (.uax) → UT `/Sounds` + Web redirect
   - Music (.umx) → UT `/Music` + Web redirect
   - Code (.u) → UT `/System`
   - Sets correct permissions (chmod/chown)

5. **Option 4: Cleanup**
   - Clears `/upload/` (keeps `/installed/` and `/Backups/`)

### SNAFU Fix

Emergency repair tool for when things go wrong:

- Fixes all chmod (755 for dirs, 644 for files)
- Fixes all chown (UT and web ownership)
- Makes UCC binaries executable
- Normalizes map filenames (case-sensitive)
- Supports map prefixes: DM-, CTF-, DOM-, AS-, MH-, MA-, RA-, BR-

**When to use:**
- for Map extraction from compressed files and distribution
- After manual file operations
- When UT server can't read files
- After web server permission issues
- When in doubt!

---

## 🔍 Orphan Scanner

Access via **MapTools → 8. Orphan Scanner**

Advanced dependency-based orphan detection system.

### How It Works

**Step 1: Extract Map Dependencies**
- Scans all .unr files with UCC packagedump
- Extracts Import Table package references
- Takes 10-15 minutes for ~200 maps
- Creates: `libs/all_map_dependencies.txt`

**Step 2: Generate Whitelist**

Builds protection list from 4 sources:

1. **System Packages** (hardcoded)
   ```
   Core, Engine, Botpack, UnrealShare, UnrealI
   IpDrv, UWeb, UBrowser, Fire, UTMenu
   UWindowFonts, LadderFonts
   ```

2. **Map Dependencies** (extracted)
   - All packages referenced by maps
   - Example: RainFX, Starship, GenFX, UTtech1

3. **ServerPackages** (from ut.ini)
   - Parses `ServerPackages=` lines
   - Auto-detects: ut.ini, UnrealTournament.ini, unrealtournament.ini

4. **Pattern-Based** (filesystem scan)
   ```
   *kin*       - Skins (SoldierSkins, CommandoSkins, etc.)
   *Fem*       - Female skins (GothFem, DacomaFem, SGirlSkins)
   *Male*      - Male skins
   *ech*       - Tech textures (SCTech1, UTtech1, UTtech2)
   *ont*       - Fonts
   *fx*        - Effects
   *enu*       - Menu packages
   *oice*      - Voice packs
   *nnounce*   - Announcer packs
   ```

Creates: `libs/dependency_whitelist.txt`

**Step 3: Detect & Delete Orphans**

Scans `/Textures/*.utx`, `/Sounds/*.uax`, `/Music/*.umx`

Shows all orphaned files with interactive selection:

```
Found 28 orphaned packages (39.14 MB)

   1) [ ] chaostex.utx           19.53 MB
   2) [ ] chaossounds.uax         5.02 MB
   3) [ ] SCTech1.utx             4.10 MB
   ...

Options:
  a) Delete ALL orphans
  s) Select numbers to DELETE (comma-separated, e.g. 1,5,8)
  k) Select numbers to KEEP (comma-separated, everything else deleted)
  c) Cancel (back to menu)
```

**Step 4: Web Redirect Cleanup**

Scans web redirect for orphaned .uz files:
- Checks if original file exists on UT server
- Supports all extensions: .unr, .utx, .uax, .umx, .u, .int, .ini
- Case-insensitive matching

### Safety Features

- ✅ **50+ Warning** - Alerts if too many orphans (suggests reinstall)
- ✅ **Whitelist Protection** - Multiple layers of protection
- ✅ **Interactive Selection** - Choose exactly what to delete
- ✅ **Cancel Anytime** - No changes until confirmed
- ✅ **Read-Only Scanning** - Detection doesn't modify anything

### Workflow Example

```bash
# First time setup (do once)
1. Extract Map Dependencies    # 10-15 min, creates dependency database
2. Generate Whitelist          # Few seconds, creates protection list

# Regular use (after adding/removing maps)
1. Extract Map Dependencies    # Re-scan if maps changed
2. Generate Whitelist          # Always regenerate after extraction
3. Detect & Delete Orphans     # Clean up unused packages

# Web cleanup (as needed)
4. Web Redirect Cleanup        # Remove orphaned .uz files
```

---

## 💾 SmartBackup

Access via **Main Menu → S. SmartBackup**

Comprehensive backup system with safety checks.

### Features

- **Disk Space Validation** - Checks available space before backup
- **Size Estimation** - Shows backup size before creation
- **Timestamp Format** - YYMMDD-HHMM for easy sorting
- **Selective Backup** - UT server, web redirect, or both
- **Backup Management** - List, delete by age, restore
- **Script Backup** - Includes UTKeeper itself + /upload/installed

### SmartBackup Menu

```
1. Backup UT Server         - Backup entire UT installation
2. Backup Web Redirect      - Backup web redirect directory
3. Backup Both             - UT + Web in one operation
4. Backup This Script      - Backup UTKeeper + /upload/installed
5. List Backups            - Show all available backups
6. Delete Old Backups      - Remove backups by age
7. Show Disk Space         - Current usage statistics

B. Back to Main Menu
```

### Backup Location

All backups saved to: `./Backups/`

```
Backups/
├── ut_backup_260127-1430.zip      # UT server backup
├── web_backup_260127-1432.zip     # Web redirect backup
├── both_backup_260127-1435.zip    # Combined backup
└── script_backup_260127-1440.zip  # UTKeeper backup
```

### Backup Strategy

**Recommended Schedule:**

- **Before major changes** - Always backup before running Distribution
- **Weekly** - Regular UT server backups
- **After map installs** - Backup after successful installations
- **Before orphan cleanup** - Backup before deleting orphans

**Retention:**

- Keep last 7 daily backups
- Keep last 4 weekly backups
- Keep monthly backups for 6 months

---

## 🔧 Configuration

Access via **Main Menu → 8. Configuration**

### Interactive Configuration Wizard

Guides you through all settings with intelligent defaults:

```
[1/7] UT Server Installation Path
  Path [/opt/utserver]: _

[2/7] UT Server Owner (User)
  User [utserver]: _

[3/7] UT Server Owner (Group)
  Group [utserver]: _

[4/7] UT Server Log Directory
  Log Path [/opt/utserver/Logs]: _

[5/7] Web Server Document Root
  Path [/var/www/html]: _

[6/7] UT Redirect Directory (for .uz files)
  Path [/var/www/html/ut]: _

[7/7] Web Server Owner
  User [www-data]: _
  Group [www-data]: _
```

### Validation Features

- ✅ **Path Existence** - Warns if path doesn't exist
- ✅ **User/Group Check** - Validates system users/groups
- ✅ **UT Installation** - Verifies complete UT structure
- ✅ **Continue Anyway** - Option to save invalid paths (for later creation)
- ✅ **Summary Review** - Shows all settings before saving

### Configuration Summary

Before saving, reviews all settings:

```
=========================================================================
                     CONFIGURATION SUMMARY
=========================================================================

UT SERVER:
  Installation:  /opt/utserver
  Owner:         utserver:utserver
  Logs:          /opt/utserver/Logs
  Service:       utserver.service (auto-detected)

WEB SERVER:
  Document Root: /var/www/html
  UT Redirect:   /var/www/html/ut
  Owner:         www-data:www-data
  Service:       apache2.service (auto-detected)

UTKEEPER:
  Project Root:  /home/user/Desktop/utkeeper
  Upload Dir:    /home/user/Desktop/utkeeper/upload
  Config File:   /home/user/Desktop/utkeeper/.config

=========================================================================

Save this configuration? (Y/n): _
```

---

## 🛡️ Safety Features

UTKeeper99 includes multiple layers of safety to prevent accidents:

### DryRun Mode

Toggle via **Main Menu → 9. Toggle DryRun**

When enabled:
- ✅ Shows what WOULD happen
- ✅ No actual file operations
- ✅ No deletions
- ✅ No moves/copies
- ❌ Does NOT execute changes

**Always test in DryRun first!**

### Critical Path Protection

- ❌ Rejects `/` as a path
- ❌ Warns about system directories
- ✅ Validates UT installation structure
- ✅ Checks for write permissions

### Backup Integration

- ✅ SmartBackup before major operations
- ✅ Archives moved to /installed instead of deleted
- ✅ Disk space checks before operations
- ✅ Permission validation

### User Confirmations

- ⚠️ Deletion operations require typing "DELETE" or "DELETE ALL"
- ⚠️ Major operations show summary before execution
- ⚠️ Interactive selection for orphan cleanup
- ⚠️ Cancel options everywhere

### SNAFU Fix

Emergency repair tool:
- Fixes permissions when things go wrong
- Normalizes filenames
- Restores ownership
- Safe to run multiple times

---

## 📁 Directory Structure

```
utkeeper/
├── utkeeper.sh              # Main script
├── .config                  # Configuration (auto-generated)
├── README.txt              # This file (text version)
├── README.md               # This file (markdown version)
│
├── libs/                   # Core modules
│   ├── backup.sh           # Backup system
│   ├── check_logs.sh       # Log viewing
│   ├── clean_logs.sh       # Log cleanup
│   ├── clone.sh            # Map cloning
│   ├── distribution.sh     # File distribution
│   ├── extract.sh          # Archive extraction
│   ├── maptools.sh         # MapTools menu
│   ├── orphan.sh           # Orphan scanner
│   ├── server_config.sh    # Configuration wizard
│   ├── snafu_fix.sh        # Emergency repair
│   ├── system.sh           # System management
│   ├── ut.sh               # UT service control
│   ├── uzip.sh             # UCC compression
│   └── validation.sh       # Installation verification
│
├── examples/               # Example configurations
│   ├── ucc.txt             # UCC binary info
│   ├── utservices.txt      # UT systemd service examples
│   └── webservices.txt     # Web server service examples
│
├── upload/                 # Working directory (user files)
│   └── installed/          # Archive backup
│
└── Backups/                # Backup storage
    ├── ut_backup_*.zip
    ├── web_backup_*.zip
    └── script_backup_*.zip
```

---

## 🔨 UCC Binary Update

The UCC binary is used for compression (.uz creation) and dependency extraction.

**Location:** `UT_BASE_PATH/System/ucc-bin`

If your UCC is from a UT client (not server), it may not support compression.

### Update UCC (if needed)

1. Check `examples/ucc.txt` for UCC binary info
2. Replace your UCC with a server-compatible version
3. Make executable: `chmod +x System/ucc-bin System64/ucc-bin`

**Note:** SNAFU Fix automatically sets UCC permissions.

---

## ⚡ Quick Start Guide

### For New Users

```bash
# 1. Extract and setup
unzip utkeeper99.zip
cd utkeeper
chmod +x utkeeper.sh libs/*.sh

# 2. First run (auto-configure)
./utkeeper.sh
# Follow configuration wizard

# 3. Test in DryRun
# Main Menu → 9. Toggle DryRun

# 4. Test MapTools
# Drop a test file in upload/
# Main Menu → 7. MapTools
# Try each option (Extract, Compress, Distribution, Cleanup)

# 5. Create backup
# Main Menu → S. SmartBackup
# Option 1: Backup UT Server

# 6. Disable DryRun when ready
# Main Menu → 9. Toggle DryRun
```

### For Experienced Users

```bash
# Quick install
sudo unzip utkeeper99.zip -d /opt/utkeeper99
cd /opt/utkeeper99
sudo chmod +x utkeeper.sh libs/*.sh

# Auto-configure
sudo ./utkeeper.sh
# Accept defaults or customize

# Map installation workflow
# 1. Drop files to /opt/utkeeper99/upload/
# 2. Main Menu → 7 → 1 (Extract)
# 3. Main Menu → 7 → 2 (Compress)
# 4. Main Menu → 7 → 3 (Distribution)
# 5. Main Menu → 7 → 4 (Cleanup)

# Orphan cleanup (first time)
# 1. Main Menu → 7 → 8 → 1 (Extract Dependencies) - takes time!
# 2. Main Menu → 7 → 8 → 2 (Generate Whitelist)
# 3. Main Menu → 7 → 8 → 3 (Detect & Delete)
```

---

## 🐛 Troubleshooting

### Common Issues

**"ERROR: PROJECT_ROOT not set!"**
- You called a lib script directly
- Always run: `./utkeeper.sh`

**"Config file not found"**
- Run: Main Menu → 8. Configuration
- Complete the setup wizard

**"UCC binary not found"**
- Check: `UT_BASE_PATH/System/ucc-bin`
- See `examples/ucc.txt` for replacement

**"Permission denied"**
- Run with: `sudo ./utkeeper.sh`
- Or fix ownership: `sudo chown -R $USER:$USER .`

**"No orphans found" (but you know there are some)**
- Re-run: Extract Dependencies (Option 1)
- Then: Generate Whitelist (Option 2)
- The database may be outdated

**"Too many orphans (50+)"**
- This indicates a problem
- Consider clean UT reinstall
- Or review whitelist patterns

### Log Files

Check for errors:
```bash
# System logs
sudo journalctl -u utserver -n 50

# UT server log
tail -f /opt/utserver/System/UnrealTournament.log

# Apache/Nginx logs
sudo tail -f /var/log/apache2/error.log
sudo tail -f /var/log/nginx/error.log
```

### Getting Help

1. Read the README (you're here!)
2. Check `examples/` directory for service configs
3. Test in DryRun mode first
4. Create SmartBackup before risky operations
5. Use SNAFU Fix if permissions break

---

## 📜 Credits

### Original Authors

**UTKeeper99**
- **Author:** [KoD]Prom
- **Clan:** Killers on Demand (since 1999)
- **Year:** 2026
- **Website:** http://killersondemand.ddns.net

**uzip 1.0**
- **Author:** [es]Rush
- **Copyright:** 2005
- **Contact:** rush@u.one.pl, PM on unrealadmin.org

**ASH (abfackeln's server utilities) 0.6**
- **Author:** abfackeln@abfackeln.com
- **Copyright:** 2001, 2002
- **License:** GNU GPL v2+

### Special Thanks

Greetings to:
- BBWG, THCO, ASN, UTClanDortmund
- Baumkuschler, MercedesBenzClan
- UnrealAdmin.org, OldUnreal.com
- UnrealArchive.org, ut99.org
- utzone.de, ut99maps.net
- All MasterServer operators
- The entire UT99 community

### Code Review

AI-assisted code review and best practices: Claude. ai (01/2026)

### In Memory

Dedicated to [KoD] clan members and all the LAN parties with "Blauer-Klaus" (blue menthol schnaps).

*"You can't kill an idea. Ideas are bulletproof!"*

---

## 📄 License

**GNU General Public License**

UTKeeper99 is free software and comes with **ABSOLUTELY NO WARRANTY!**

- ✅ Free to use
- ✅ Free to modify
- ✅ Keep original credits
- ❌ NO commercial use
- ❌ NO reselling

**Run at your own risk!**

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.

---

## 🔗 Support & Community

### Resources

- **Website:** http://killersondemand.ddns.net
- **UT99 Community:** UnrealAdmin.org
- **Archives:** UnrealArchive.org
- **Maps:** ut99maps.net
- **General:** ut99.org, utzone.de

### Bug Reports & Feature Requests

> **Note:** This may be the final version. I might not update or accept pull requests. Take it as is - it works for me! 😊

### Philosophy

This script started simple and grew organically. It's done "just for fun" and as proof of existence. If it helps someone else, that's a bonus!

---

## 🎮 Final Words

Stay healthy and smash some fascists!

**>>> GL & HF! <<<**

**[KoD]Prom**

---

*Keep the archive intact. Thank you!*

*Version: 2.5 | Last Updated: January 2026*
