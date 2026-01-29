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
# ASH 0.6 by abfackeln@abfackeln.com Copyright 2001,2002

set -euo pipefail

# === MAPTOOLS.SH - UT99 MAP MENU SYSTEM v2.7 ===

if [[ -z "${PROJECT_ROOT:-}" ]]; then
  echo "ERROR: PROJECT_ROOT not set!"
  echo "This script must be called from utkeeper.sh"
  exit 1
fi

CONFIG_FILE="${PROJECT_ROOT}/.config"
LIBS_DIR="${PROJECT_ROOT}/libs"

# === LOAD & VALIDATE CONFIG ===
if [[ ! -f "$CONFIG_FILE" ]]; then
  echo "ERROR: Config file not found: $CONFIG_FILE"
  echo "Please run Configuration (Option 8 in main menu)"
  exit 1
fi

source "$CONFIG_FILE"

# Validate required variables
if [[ -z "${UPLOAD_DIR:-}" ]] || [[ -z "${UT_BASE_PATH:-}" ]]; then
  echo "ERROR: Config missing required variables!"
  echo "Required: UPLOAD_DIR, UT_BASE_PATH"
  echo "Please run Configuration (Option 8 in main menu)"
  exit 1
fi

# Export for sub-scripts
export UPLOAD_DIR
export UT_BASE_PATH
export UT_REDIRECT
export DRY_RUN="${DRY_RUN:-false}"
export CONFIG_FILE
export PROJECT_ROOT
export LIBS_DIR

# === FUNCTIONS ===
show_status() {
  clear
  echo "==========================================================================="
  echo "                          UTK MAPTOOLS v2.7"
  echo "==========================================================================="
  echo ""
  echo "Upload Dir:  $UPLOAD_DIR"
  echo "UT Base:     $UT_BASE_PATH"
  echo ""
  
  # Count files
  local uz_count=$(find "$UPLOAD_DIR" -maxdepth 1 -name "*.uz" -type f 2>/dev/null | wc -l)
  local extracted=$(find "$UPLOAD_DIR" -mindepth 1 -maxdepth 1 -type d ! -name "installed" 2>/dev/null | wc -l)
  local map_count_server=0
  local map_count_upload=0
  
  [[ -d "$UT_BASE_PATH/Maps" ]] && map_count_server=$(find "$UT_BASE_PATH/Maps" -name "*.unr" 2>/dev/null | wc -l)
  map_count_upload=$(find "$UPLOAD_DIR" -name "*.unr" 2>/dev/null | wc -l)
  
  echo "STATUS:"
  echo "  .uz packages:       $uz_count"
  echo "  Extracted folders:  $extracted"
  echo "  Maps on UT Server:  $map_count_server"
  echo "  Maps in upload:     $map_count_upload"
  echo ""
  
  [ "$DRY_RUN" = true ] && echo "*** DRY-RUN MODE ACTIVE ***" && echo ""
  
  echo "==========================================================================="
  echo "                              MENU"
  echo "==========================================================================="
  echo ""
  echo "  1) Extract Archives (zip, rar, tar, 7z)"
  echo "  2) Compress to .uz Format" 
  echo "  3) Distribute Files (UT Server + Web Redirect)"
  echo "  4) CleanUp /upload Directory"
  echo "  5) SNAFU-Fix (CaseSensitive + Permissions)"
  echo "  6) Verify UT Installation"
  echo "  7) Create DM Clones"
  echo "  8) Advanced Orphan Scanner"
  echo ""
  echo "  B) Back to Main Menu"
  echo ""
  echo "==========================================================================="
  echo ""
}

extract_files() {
  local script="${LIBS_DIR}/extract.sh"
  
  if [[ ! -f "$script" ]]; then
    echo "ERROR: extract.sh not found: $script"
    read -p "Press Enter..."
    return 1
  fi
  
  bash "$script"
  read -p "Press Enter to continue..."
}

compress_to_uz() {
  local script="${LIBS_DIR}/uzip.sh"
  
  if [[ ! -f "$script" ]]; then
    echo "ERROR: uzip.sh not found: $script"
    read -p "Press Enter..."
    return 1
  fi
  
  clear
  echo "==========================================================================="
  echo "                    COMPRESS TO .UZ FORMAT"
  echo "==========================================================================="
  echo ""
  
  # Count compressible files
  local package_count=0
  shopt -s nullglob
  for ext in unr utx uax umx u int; do
    files=("$UPLOAD_DIR"/*.$ext)
    package_count=$((package_count + ${#files[@]}))
  done
  shopt -u nullglob
  
  if [ "$package_count" -eq 0 ]; then
    echo "No compressible packages found in: $UPLOAD_DIR"
    echo ""
    echo "Supported formats: .unr .utx .uax .umx .u .int"
    read -p "Press Enter..."
    return 0
  fi
  
  echo "Found $package_count compressible file(s)"
  echo "Upload Dir: $UPLOAD_DIR"
  echo ""
  echo "Starting compression..."
  echo ""
  
  # Call uzip with FORCEAPPEND
  export FORCEAPPEND=1
  bash "$script" "$UPLOAD_DIR"/*.{unr,utx,uax,umx,u,int} 2>/dev/null || true
  
  echo ""
  read -p "Press Enter to continue..."
}

distribute_files() {
  local script="${LIBS_DIR}/distribution.sh"
  
  if [[ ! -f "$script" ]]; then
    echo "ERROR: distribution.sh not found: $script"
    read -p "Press Enter..."
    return 1
  fi
  
  bash "$script"
  read -p "Press Enter to continue..."
}

cleanup_upload() {
  clear 
  echo "==========================================================================="
  echo "                    CLEANUP UPLOAD DIRECTORY"
  echo "==========================================================================="
  echo ""
  echo "Upload Dir: $UPLOAD_DIR"
  echo ""
  
  # Count files and directories (excluding /installed)
  local file_count=$(find "$UPLOAD_DIR" -maxdepth 1 -type f 2>/dev/null | wc -l)
  local dir_count=$(find "$UPLOAD_DIR" -mindepth 1 -maxdepth 1 -type d ! -name "installed" 2>/dev/null | wc -l)
  
  if [ "$file_count" -eq 0 ] && [ "$dir_count" -eq 0 ]; then
    echo "Upload directory is already empty (except /installed)."
    read -p "Press Enter..."
    return 0
  fi
  
  echo "Found:"
  echo "  Files:       $file_count"
  echo "  Directories: $dir_count (excluding /installed)"
  echo ""
  
  if [ "$DRY_RUN" = true ]; then
    echo "[DRY-RUN] Would delete all content except /installed (no changes made)"
    read -p "Press Enter..."
    return 0
  fi
  
  echo "⚠ WARNING: This will remove ALL files and directories!"
  echo "(Except /installed directory which contains archived packages)"
  echo ""
  read -p "Type 'yes' to confirm deletion: " confirm
  
  if [[ "$confirm" == "yes" ]]; then
    echo ""
    echo "Cleaning upload directory (preserving /installed)..."
    
    # Delete all files in root
    find "$UPLOAD_DIR" -maxdepth 1 -type f -delete 2>/dev/null || true
    
    # Delete all directories except 'installed'
    find "$UPLOAD_DIR" -mindepth 1 -maxdepth 1 -type d ! -name "installed" -exec rm -rf {} + 2>/dev/null || true
    
    echo "✓ Upload directory cleaned (installed/ preserved)"
  else
    echo ""
    echo "Cancelled"
  fi
  
  read -p "Press Enter..."
}

snafu_func() {
  local script="${LIBS_DIR}/snafu_fix.sh"
  
  if [[ ! -f "$script" ]]; then
    echo "ERROR: snafu_fix.sh not found: $script"
    read -p "Press Enter..."
    return 1
  fi
  
  bash "$script"
}

ut_validation() {
  local script="${LIBS_DIR}/validation.sh"
  
  if [[ ! -f "$script" ]]; then
    echo "ERROR: validation.sh not found: $script"
    read -p "Press Enter..."
    return 1
  fi
  
  bash "$script"
  read -p "Press Enter to continue..."
}

create_dm_clones() {
  local script="${LIBS_DIR}/clone.sh"
  
  if [[ ! -f "$script" ]]; then
    echo "ERROR: clone.sh not found: $script"
    read -p "Press Enter..."
    return 1
  fi
  
  bash "$script"
  read -p "Press Enter to continue..."
}

orphan_scanner() {
  local script="${LIBS_DIR}/orphan.sh"
  
  if [[ ! -f "$script" ]]; then
    echo "ERROR: orphan.sh not found: $script"
    read -p "Press Enter..."
    return 1
  fi
  
  bash "$script"
  read -p "Press Enter to continue..."
}

# === MAIN LOOP ===
while true; do
  show_status
  read -p "Choose option [1-8, B]: " choice
  
  case "$choice" in
    1) extract_files ;;
    2) compress_to_uz ;;
    3) distribute_files ;;
    4) cleanup_upload ;;
    5) snafu_func ;;
    6) ut_validation ;;
    7) create_dm_clones ;;
    8) orphan_scanner ;;
    [bB])
      clear
      echo "Returning to main menu..."
      sleep 1
      break
      ;;
    [qQ])
      clear
      echo "Goodbye!"
      exit 0
      ;;
    *) 
      echo "Invalid choice!"
      sleep 1
      ;;
  esac
done

