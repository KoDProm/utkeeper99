#!/bin/bash
# UTKeeper99 UTK by [KoD]Prom in 2026 
# >>> Killers on demand <<< Clan since 1999
#
# UTKeeper99 is free software and comes with ABSOLUTELY NO WARRANTY!
# 
# READ README FIRST! Modular design for easy expansion/customization.
# And dont trust me...always make config and backup first!
# Modify freely, keep original credits. No reselling.
#
# Credits:
# uzip 1.0 by [es]Rush Copyright 2005
# ASH 0.6 by [abfackeln@abfackeln.com](mailto:abfackeln@abfackeln.com) Copyright 2001,2002

set -euo pipefail

# === CLONE.SH - CREATE DM CLONES FROM GAMETYPE MAPS v2.5 ===

if [[ -z "${PROJECT_ROOT:-}" ]]; then
  echo "ERROR: PROJECT_ROOT not set!"
  echo "This script must be called from maptools.sh"
  exit 1
fi

CONFIG_FILE="${PROJECT_ROOT}/.config"

if [[ ! -f "$CONFIG_FILE" ]]; then
  echo "ERROR: Config file not found: $CONFIG_FILE"
  echo "Please run Configuration (Option 8 in main menu)"
  exit 1
fi

source "$CONFIG_FILE"

# Validate required variables
if [[ -z "${UPLOAD_DIR:-}" ]]; then
  echo "ERROR: Config missing UPLOAD_DIR!"
  echo "Please run Configuration (Option 8 in main menu)"
  exit 1
fi

# Validate upload directory
if [[ ! -d "$UPLOAD_DIR" ]]; then
  echo "ERROR: Upload directory not found: $UPLOAD_DIR"
  echo "Please check your configuration"
  exit 1
fi

# Get real user for ownership
REAL_USER="${SUDO_USER:-$USER}"
REAL_GROUP=$(id -gn "$REAL_USER" 2>/dev/null || echo "$REAL_USER")

clear
echo "==========================================================================="
echo "                CREATE DM CLONES FROM GAMETYPE MAPS v2.5"
echo "==========================================================================="
echo ""
echo "This tool creates DM- (Deathmatch) clones from gametype-specific maps"
echo ""
echo "Source Directory: $UPLOAD_DIR"
echo "File Type:        *.unr (Unreal Tournament Map files)"
echo "Source Prefixes:  CTF-, DOM-, AS-, RA-, BR-, MH-, MA-"
echo "Target Prefix:    DM-"
echo "Owner:            $REAL_USER:$REAL_GROUP"
echo ""
echo "Note: Only files in the root of upload will be processed"
echo "      (no subdirectories, no archives)"
echo ""
echo "==========================================================================="
echo ""

# Define map prefixes to clone
PREFIXES="CTF- BR- AS- DOM- RA- MH- MA-"

# === SCAN FOR FILES ===
echo "Scanning for gametype maps..."
echo ""

count_total=0
files_to_clone=()

for prefix in $PREFIXES; do
  shopt -s nullglob
  for file in "$UPLOAD_DIR"/${prefix}*.unr; do
    [[ -f "$file" ]] || continue
    
    basename=$(basename "$file")
    
    # Skip if already DM- prefix
    if [[ "$basename" =~ ^DM- ]]; then 
      continue
    fi
    
    # Extract everything after first dash
    rest="${basename#*-}"
    newname="DM-$rest"
    newpath="$UPLOAD_DIR/$newname"
    
    # Check if target already exists
    if [[ -f "$newpath" ]]; then
      echo "  [SKIP] $basename → $newname (target already exists)"
    else
      echo "  [COPY] $basename → $newname"
      files_to_clone+=("$file|$newpath")
      count_total=$((count_total + 1))
    fi
  done
  shopt -u nullglob
done

echo ""
echo "==========================================================================="
echo "Found: $count_total file(s) to clone as DM- maps"
echo "==========================================================================="
echo ""

# Exit if nothing to do
if [[ $count_total -eq 0 ]]; then
  echo "No gametype maps found to clone."
  echo ""
  read -p "Press Enter to return to menu..."
  exit 0
fi

# === CONFIRMATION ===
read -p "Do you want to proceed with cloning? (yes/no): " confirm

if [[ ! "$confirm" =~ ^[yY][eE][sS]$ ]]; then
  echo ""
  echo "Operation cancelled."
  echo ""
  read -p "Press Enter to return to menu..."
  exit 0
fi

# === CLONING ===
echo ""
echo "=== CLONING MAPS ==="
echo ""

count_success=0
count_failed=0

for entry in "${files_to_clone[@]}"; do
  IFS='|' read -r source_file target_file <<< "$entry"
  
  basename_source=$(basename "$source_file")
  basename_target=$(basename "$target_file")
  
  if cp "$source_file" "$target_file" 2>/dev/null; then
    # Fix ownership - cloned file should belong to real user, not root
    if ! chown "$REAL_USER:$REAL_GROUP" "$target_file" 2>/dev/null; then
      echo "  [WARN] Created $basename_target but couldn't set ownership"
    fi
    echo "  [OK] $basename_source → $basename_target"
    count_success=$((count_success + 1))
  else
    echo "  [FAIL] $basename_source → $basename_target"
    count_failed=$((count_failed + 1))
  fi
done

echo ""
echo "==========================================================================="
echo "                           CLONING COMPLETE"
echo "==========================================================================="
echo ""
echo "Successfully cloned: $count_success map(s)"
[[ $count_failed -gt 0 ]] && echo "Failed:              $count_failed map(s)"
echo ""

# Show new DM- files
echo "New DM- clones in upload directory:"
echo ""

# Temporarily disable strict error handling for listing
set +e
set +u
set +o pipefail

total_count=0

# listing newest
cd "$UPLOAD_DIR" 2>/dev/null || true
for entry in "${files_to_clone[@]}"; do
  IFS='|' read -r source_file target_file <<< "$entry"
  basename_target=$(basename "$target_file")
  
  if [[ -f "$basename_target" ]]; then
    size_bytes=$(stat -c%s "$basename_target" 2>/dev/null || echo "0")
    if (( size_bytes < 1024 )); then
      size="${size_bytes}B"
    elif (( size_bytes < 1048576 )); then
      size="$((size_bytes / 1024))K"
    else
      size="$((size_bytes / 1048576))M"
    fi
    
    owner=$(stat -c '%U:%G' "$basename_target" 2>/dev/null || echo "unknown")
    echo "  $basename_target ($size) [$owner]"
    ((total_count++))
  fi
done

if [[ $total_count -eq 0 ]]; then
  echo "  (none found)"
fi


# Re-enable strict error handling
set -e
set -u
set -o pipefail

echo ""
echo "==========================================================================="
echo ""
read -p "Press Enter to return to menu..."

