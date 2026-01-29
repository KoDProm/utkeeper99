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
#
# UT Server CaseFix + Permissions Management v2.6

set -euo pipefail
IFS=$'\n\t'

# === LOAD CONFIGURATION ===
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

# === VALIDATE REQUIRED CONFIG VARIABLES ===
validate_config() {
  local missing=()
  
  [[ -z "${UT_BASE_PATH:-}" ]] && missing+=("UT_BASE_PATH")
  [[ -z "${UT_REDIRECT:-}" ]] && missing+=("UT_REDIRECT")
  [[ -z "${WEB_ROOT:-}" ]] && missing+=("WEB_ROOT")
  [[ -z "${UT_USER:-}" ]] && missing+=("UT_USER")
  [[ -z "${UT_GROUP:-}" ]] && missing+=("UT_GROUP")
  [[ -z "${WEB_USER:-}" ]] && missing+=("WEB_USER")
  [[ -z "${WEB_GROUP:-}" ]] && missing+=("WEB_GROUP")
  
  if [ ${#missing[@]} -gt 0 ]; then
    echo "ERROR: Config file is missing required variables:"
    for var in "${missing[@]}"; do
      echo "  - $var"
    done
    echo ""
    echo "Please run Configuration (Option 8 in main menu)"
    exit 1
  fi
  
  return 0
}

validate_config

# === EXPORT VALIDATED VARIABLES ===
export UT_BASE_PATH="${UT_BASE_PATH%/}"  # Remove trailing slash
export UT_REDIRECT="${UT_REDIRECT%/}"
export WEB_ROOT="${WEB_ROOT%/}"
export UT_USER
export UT_GROUP
export WEB_USER
export WEB_GROUP
export DRY_RUN="${DRY_RUN:-false}"

# === LOGGING ===
log_info() { echo "[INFO] $*"; }
log_warn() { echo "[WARN] $*" >&2; }
log_error() { echo "[ERROR] $*" >&2; }

# === PRE-FLIGHT SAFETY CHECKS ===
preflight_checks() {
  clear
  echo "==========================================================================="
  echo "                      PRE-FLIGHT SAFETY CHECKS"
  echo "==========================================================================="
  echo ""
  
  local errors=0
  local warnings=0
  
  # Check UT Server directory
  echo "[1/7] Checking UT Server Path..."
  if [ ! -d "$UT_BASE_PATH" ]; then
    log_error "UT Server path does not exist: $UT_BASE_PATH"
    errors=$((errors + 1))
  else
    log_info "✓ Path exists: $UT_BASE_PATH"
    
    # Check if it's a symlink
    if [ -L "$UT_BASE_PATH" ]; then
      log_warn "⚠ Path is a SYMLINK - operations will follow symlink"
      warnings=$((warnings + 1))
    fi
    
    # Check ownership
    local current_owner=$(stat -c '%U:%G' "$UT_BASE_PATH" 2>/dev/null || echo "unknown")
    if [ "$current_owner" != "$UT_USER:$UT_GROUP" ]; then
      log_warn "⚠ Current owner is $current_owner (expected $UT_USER:$UT_GROUP)"
      warnings=$((warnings + 1))
    else
      log_info "✓ Ownership correct: $current_owner"
    fi
  fi
  echo ""
  
  # Check UT Server subdirectories
  echo "[2/7] Checking UT Server Subdirectories..."
  local required_dirs=("Maps" "Textures" "Sounds" "Music" "System")
  local found_dirs=0
  
  for dir in "${required_dirs[@]}"; do
    if [ -d "$UT_BASE_PATH/$dir" ]; then
      found_dirs=$((found_dirs + 1))
    fi
  done
  
  if [ "$found_dirs" -eq 0 ]; then
    log_error "No UT99 subdirectories found - is this a valid UT installation?"
    errors=$((errors + 1))
  else
    log_info "✓ Found $found_dirs/$((${#required_dirs[@]})) UT99 directories"
  fi
  echo ""
  
  # Check Web Root
  echo "[3/7] Checking Web Server Root..."
  if [ ! -d "$WEB_ROOT" ]; then
    log_warn "⚠ Web Root does not exist: $WEB_ROOT"
    log_warn "  Web Root permissions will be skipped"
    warnings=$((warnings + 1))
  else
    log_info "✓ Web Root exists: $WEB_ROOT"
    
    if [ -L "$WEB_ROOT" ]; then
      log_warn "⚠ Web Root is a SYMLINK"
      warnings=$((warnings + 1))
    fi
  fi
  echo ""
  
  # Check UT Redirect
  echo "[4/7] Checking UT Redirect Directory..."
  if [ ! -d "$UT_REDIRECT" ]; then
    log_warn "⚠ UT Redirect does not exist: $UT_REDIRECT"
    log_warn "  Orphan cleanup will be skipped"
    warnings=$((warnings + 1))
  else
    log_info "✓ UT Redirect exists: $UT_REDIRECT"
    
    if [ -L "$UT_REDIRECT" ]; then
      log_warn "⚠ UT Redirect is a SYMLINK"
      warnings=$((warnings + 1))
    fi
  fi
  echo ""
  
  # Check users exist
  echo "[5/7] Checking System Users..."
  if ! id "$UT_USER" &>/dev/null; then
    log_error "UT user does not exist: $UT_USER"
    errors=$((errors + 1))
  else
    log_info "✓ UT user exists: $UT_USER"
  fi
  
  if ! id "$WEB_USER" &>/dev/null; then
    log_error "Web user does not exist: $WEB_USER"
    errors=$((errors + 1))
  else
    log_info "✓ Web user exists: $WEB_USER"
  fi
  echo ""
  
  # Check groups exist
  echo "[6/7] Checking System Groups..."
  if ! getent group "$UT_GROUP" &>/dev/null; then
    log_error "UT group does not exist: $UT_GROUP"
    errors=$((errors + 1))
  else
    log_info "✓ UT group exists: $UT_GROUP"
  fi
  
  if ! getent group "$WEB_GROUP" &>/dev/null; then
    log_error "Web group does not exist: $WEB_GROUP"
    errors=$((errors + 1))
  else
    log_info "✓ Web group exists: $WEB_GROUP"
  fi
  echo ""
  
  # Filesystem info
  echo "[7/7] Checking Filesystem..."
  local fs_type=$(stat -f -c %T "$UT_BASE_PATH" 2>/dev/null || echo "unknown")
  log_info "Filesystem type: $fs_type"
  
  # Check if we're root
  if [ "$EUID" -ne 0 ]; then
    log_error "This script must be run with sudo!"
    errors=$((errors + 1))
  else
    log_info "✓ Running as root"
  fi
  echo ""
  
  # Summary
  echo "==========================================================================="
  echo "                      PRE-FLIGHT CHECK SUMMARY"
  echo "==========================================================================="
  echo ""
  echo "  Errors:   $errors"
  echo "  Warnings: $warnings"
  echo ""
  
  if [ "$errors" -gt 0 ]; then
    echo "❌ CRITICAL ERRORS FOUND - Cannot continue safely!"
    echo ""
    read -p "Press Enter to exit..."
    exit 1
  fi
  
  if [ "$warnings" -gt 0 ]; then
    echo "⚠ Warnings found - review above before continuing"
  else
    echo "✓ All checks passed"
  fi
  
  echo ""
  echo "==========================================================================="
  echo ""
  
  return 0
}

# === HELPER FUNCTIONS ===

# Normalize map prefix (DM-, CTF-, etc)
normalize_prefix() {
  local name=$1
  local lower="${name,,}"
  
  case "$lower" in
    dm-*)  echo "DM-${name:3}" ;;
    ctf-*) echo "CTF-${name:4}" ;;
    dom-*) echo "DOM-${name:4}" ;;
    as-*)  echo "AS-${name:3}" ;;
    mh-*)  echo "MH-${name:3}" ;;
    ma-*)  echo "MA-${name:3}" ;;
    br-*)  echo "BR-${name:3}" ;;
    ra-*)  echo "RA-${name:3}" ;;
    *)     echo "$name" ;;
  esac
}

# Check if filename has map prefix
has_map_prefix() {
  local filename=$1
  [[ "$filename" =~ ^(DM-|CTF-|DOM-|AS-|MH-|MA-|RA-|BR-|dm-|ctf-|dom-|as-|mh-|ma-|ra-|br-) ]]
}

# Check if filename is an exception (don't rename)
is_exception() {
  local filename=$1
  [[ "$filename" == "koth_BaseStationTheta.unr" ]]
}

# Safe rename with case-sensitivity handling
safe_rename() {
  local source=$1
  local target=$2
  
  # Source must exist
  if [ ! -e "$source" ]; then
    log_error "Source does not exist: $source"
    return 1
  fi
  
  # Same name? Nothing to do
  if [ "$source" = "$target" ]; then
    return 0
  fi
  
  # Check if target already exists (different file)
  if [ -e "$target" ]; then
    local source_inode=$(stat -c %i "$source" 2>/dev/null || echo "0")
    local target_inode=$(stat -c %i "$target" 2>/dev/null || echo "0")
    
    if [ "$source_inode" != "$target_inode" ]; then
      log_warn "Target already exists (different file): $(basename "$target")"
      return 1
    fi
  fi
  
  # Case-only change? Use temp file
  local source_lower=$(basename "$source" | tr '[:upper:]' '[:lower:]')
  local target_lower=$(basename "$target" | tr '[:upper:]' '[:lower:]')
  
  if [ "$source_lower" = "$target_lower" ]; then
    # Case-only rename requires temp file
    local temp_name="${source}.tmp$$"
    
    if ! mv "$source" "$temp_name" 2>/dev/null; then
      log_error "Failed temporary rename: $(basename "$source")"
      return 1
    fi
    
    if ! mv "$temp_name" "$target" 2>/dev/null; then
      log_error "Failed final rename: $(basename "$source")"
      # Try to restore
      mv "$temp_name" "$source" 2>/dev/null || true
      return 1
    fi
  else
    # Normal rename
    if ! mv -n "$source" "$target" 2>/dev/null; then
      log_error "Failed to rename: $(basename "$source")"
      return 1
    fi
  fi
  
  return 0
}

# === FILE RENAMING ===
fix_extension_case() {
  local target_dir="$1"
  
  echo ""
  echo "==========================================================================="
  echo "SCANNING: $target_dir"
  echo "==========================================================================="
  echo ""
  
  if [ ! -d "$target_dir" ]; then
    log_warn "Directory does not exist, skipping"
    return 0
  fi
  
  local is_maps_dir=false
  [[ "$target_dir" == *"Maps"* ]] && is_maps_dir=true
  
  # Collect files that need renaming
  declare -a to_rename=()
  
  while IFS= read -r -d '' file; do
    [ -z "$file" ] && continue
    
    # Skip symlinks
    if [ -L "$file" ]; then
      log_warn "Skipping symlink: $(basename "$file")"
      continue
    fi
    
    local filename=$(basename "$file")
    
    # Skip exceptions
    if is_exception "$filename"; then
      continue
    fi
    
    local extension=""
    local basename_part=""
    
    # Handle .uz files specially
    if [[ "$filename" == *.uz ]]; then
      local content_file="${filename%.uz}"
      local ext_raw="${content_file##*.}"
      extension="$(echo "$ext_raw" | tr '[:upper:]' '[:lower:]').uz"
      basename_part="${content_file%.*}"
    else
      extension=$(echo "${filename##*.}" | tr '[:upper:]' '[:lower:]')
      basename_part="${filename%.*}"
    fi
    
    # Maps directory: only rename files with map prefixes
    if [ "$is_maps_dir" = true ]; then
      if [[ "$extension" =~ ^unr(\.uz)?$ ]]; then
        if ! has_map_prefix "$filename"; then
          continue
        fi
      fi
    fi
    
    # Normalize prefix
    local new_basename=$(normalize_prefix "$basename_part")
    local new_name="$new_basename.$extension"
    
    # Add to rename list if changed
    if [ "$filename" != "$new_name" ]; then
      to_rename+=("$file|$new_name")
    fi
  done < <(find "$target_dir" -maxdepth 1 -xdev -type f \( \
    -iname '*.unr' -o -iname '*.unr.uz' -o \
    -iname '*.utx' -o -iname '*.utx.uz' -o \
    -iname '*.uax' -o -iname '*.uax.uz' -o \
    -iname '*.umx' -o -iname '*.umx.uz' -o \
    -iname '*.u' -o -iname '*.u.uz' -o \
    -iname '*.int' -o -iname '*.int.uz' -o \
    -iname '*.ini' -o -iname '*.log' \) -print0 2>/dev/null)
  
  local count=${#to_rename[@]}
  
  if [ "$count" -eq 0 ]; then
    log_info "No files need renaming"
    return 0
  fi
  
  echo "Found $count file(s) that need renaming:"
  for pair in "${to_rename[@]}"; do
    local old="${pair%%|*}"
    local new="${pair#*|}"
    printf '  %s → %s\n' "$(basename "$old")" "$new"
  done
  echo ""
  
  if [ "$DRY_RUN" = true ]; then
    log_info "[DRY-RUN] Would rename $count files (no changes made)"
    return 0
  fi
  
  read -p "Rename these files? (y/N): " rename_confirm
  
  if [[ ! "${rename_confirm,,}" =~ ^y ]]; then
    log_info "Renaming cancelled"
    return 0
  fi
  
  # Perform renaming
  local renamed=0
  local failed=0
  
  echo ""
  for pair in "${to_rename[@]}"; do
    local file="${pair%%|*}"
    local new_name="${pair#*|}"
    local target="${file%/*}/$new_name"
    
    if safe_rename "$file" "$target"; then
      echo "  ✓ $(basename "$file") → $new_name"
      renamed=$((renamed + 1))
    else
      failed=$((failed + 1))
    fi
  done
  
  echo ""
  echo "Result: $renamed renamed, $failed failed"
  
  [ "$failed" -gt 0 ] && return 1
  return 0
}

# === PERMISSION MANAGEMENT ===
set_permissions() {
  echo ""
  echo "==========================================================================="
  echo "PERMISSION MANAGEMENT"
  echo "==========================================================================="
  echo ""
  
  if [ "$DRY_RUN" = true ]; then
    log_info "[DRY-RUN] Would set the following permissions:"
    echo ""
    
    if [ -d "$UT_BASE_PATH" ]; then
      echo "UT Server: $UT_BASE_PATH"
      echo "  Owner:       $UT_USER:$UT_GROUP"
      echo "  Directories: 755"
      echo "  Files:       644"
      echo "  Executables: 755 (ucc*, *.so)"
      echo ""
    fi
    
    if [ -d "$UT_REDIRECT" ]; then
      echo "UT Redirect: $UT_REDIRECT"
      echo "  Owner:       $WEB_USER:$WEB_GROUP"
      echo "  Directories: 755"
      echo "  Files:       644"
      echo ""
    fi
    
    if [ -d "$WEB_ROOT" ]; then
      echo "Web Root: $WEB_ROOT"
      echo "  Owner:       $WEB_USER:$WEB_GROUP"
      echo "  Directories: 755"
      echo "  Files:       644"
      echo ""
    fi
    
    return 0
  fi
  
  echo "This will recursively change ownership and permissions for:"
  [ -d "$UT_BASE_PATH" ] && echo "  - UT Server:    $UT_BASE_PATH"
  [ -d "$UT_REDIRECT" ] && echo "  - UT Redirect:  $UT_REDIRECT"
  [ -d "$WEB_ROOT" ] && echo "  - Web Root:     $WEB_ROOT"
  echo ""
  echo "⚠ WARNING: This affects ALL files in these directories!"
  echo ""
  
  read -p "Proceed with permission changes? (y/N): " perm_confirm
  
  if [[ ! "${perm_confirm,,}" =~ ^y ]]; then
    log_info "Permission changes cancelled"
    return 0
  fi
  
  echo ""
  local errors=0
  
  # UT Server permissions
  if [ -d "$UT_BASE_PATH" ]; then
    log_info "Setting UT Server permissions..."
    
    if ! chown -R "$UT_USER:$UT_GROUP" "$UT_BASE_PATH" 2>/dev/null; then
      log_error "Failed to set UT Server ownership"
      errors=$((errors + 1))
    else
      # Set directory permissions
      find "$UT_BASE_PATH" -xdev -type d -exec chmod 755 {} + 2>/dev/null || {
        log_error "Failed to set directory permissions"
        errors=$((errors + 1))
      }
      
      # Set file permissions
      find "$UT_BASE_PATH" -xdev -type f -exec chmod 644 {} + 2>/dev/null || {
        log_error "Failed to set file permissions"
        errors=$((errors + 1))
      }
      
      # Set executable permissions
      if [ -d "$UT_BASE_PATH/System" ]; then
        chmod 755 "$UT_BASE_PATH/System"/ucc* 2>/dev/null || true
        find "$UT_BASE_PATH/System" -xdev -name "*.so" -exec chmod 755 {} + 2>/dev/null || true
      fi
      
      if [ -d "$UT_BASE_PATH/System64" ]; then
        find "$UT_BASE_PATH/System64" -xdev -name "*.so" -exec chmod 755 {} + 2>/dev/null || true
      fi
      
      log_info "✓ UT Server permissions set"
    fi
  fi
  
  # UT Redirect permissions
  if [ -d "$UT_REDIRECT" ]; then
    log_info "Setting UT Redirect permissions..."
    
    if ! chown -R "$WEB_USER:$WEB_GROUP" "$UT_REDIRECT" 2>/dev/null; then
      log_error "Failed to set UT Redirect ownership"
      errors=$((errors + 1))
    else
      find "$UT_REDIRECT" -xdev -type d -exec chmod 755 {} + 2>/dev/null || errors=$((errors + 1))
      find "$UT_REDIRECT" -xdev -type f -exec chmod 644 {} + 2>/dev/null || errors=$((errors + 1))
      log_info "✓ UT Redirect permissions set"
    fi
  fi
  
  # Web Root permissions
  if [ -d "$WEB_ROOT" ]; then
    log_info "Setting Web Root permissions..."
    
    if ! chown -R "$WEB_USER:$WEB_GROUP" "$WEB_ROOT" 2>/dev/null; then
      log_error "Failed to set Web Root ownership"
      errors=$((errors + 1))
    else
      find "$WEB_ROOT" -xdev -type d -exec chmod 755 {} + 2>/dev/null || errors=$((errors + 1))
      find "$WEB_ROOT" -xdev -type f -exec chmod 644 {} + 2>/dev/null || errors=$((errors + 1))
      log_info "✓ Web Root permissions set"
    fi
  fi
  
  echo ""
  
  [ "$errors" -gt 0 ] && return 1
  return 0
}

# === MAIN EXECUTION ===
main() {
  clear
  echo "==========================================================================="
  echo "                    UTK SNAFU-FIX SCRIPT v2.6"
  echo "==========================================================================="
  echo ""
  
  if [ "$DRY_RUN" = true ]; then
    echo "╔═══════════════════════════════════════════════════════════════════════╗"
    echo "║                     *** DRY-RUN MODE ACTIVE ***                       ║"
    echo "║                   *** NO FILES WILL BE MODIFIED ***                   ║"
    echo "║              *** ALL OPERATIONS ARE SIMULATED ONLY ***                ║"
    echo "╚═══════════════════════════════════════════════════════════════════════╝"
    echo ""
  fi
  
  echo "Running as:   $(whoami)"
  echo "UT Server:    $UT_BASE_PATH"
  echo "UT Redirect:  $UT_REDIRECT"
  echo "Web Root:     $WEB_ROOT"
  echo ""
  
  # Pre-flight safety checks
  preflight_checks
  
  # === OPERATION OVERVIEW ===
  echo "==========================================================================="
  echo "                        OPERATION OVERVIEW"
  echo "==========================================================================="
  echo ""
  echo "This script will perform the following operations:"
  echo ""
  echo "1. FILE RENAMING (Case-Sensitive Normalization)"
  echo "   → Normalizes file extensions (.unr, .utx, .uax, .umx, .u, .int)"
  echo "   → Normalizes map prefixes (DM-, CTF-, DOM-, AS-, MH-, etc.)"
  echo "   → Directories to process:"
  [ -d "$UT_BASE_PATH/Maps" ] && echo "     • $UT_BASE_PATH/Maps"
  [ -d "$UT_BASE_PATH/Textures" ] && echo "     • $UT_BASE_PATH/Textures"
  [ -d "$UT_BASE_PATH/Sounds" ] && echo "     • $UT_BASE_PATH/Sounds"
  [ -d "$UT_BASE_PATH/Music" ] && echo "     • $UT_BASE_PATH/Music"
  [ -d "$UT_BASE_PATH/System" ] && echo "     • $UT_BASE_PATH/System"
  [ -d "$UT_REDIRECT" ] && echo "     • $UT_REDIRECT (Web Redirect)"
  echo ""
  
  echo "2. PERMISSION MANAGEMENT"
  echo "   → Sets correct ownership and permissions"
  [ -d "$UT_BASE_PATH" ] && echo "   → UT Server:   $UT_BASE_PATH ($UT_USER:$UT_GROUP)"
  [ -d "$UT_REDIRECT" ] && echo "   → UT Redirect: $UT_REDIRECT ($WEB_USER:$WEB_GROUP)"
  [ -d "$WEB_ROOT" ] && echo "   → Web Root:    $WEB_ROOT ($WEB_USER:$WEB_GROUP)"
  echo ""
  echo ""
  echo "==========================================================================="
  echo ""
  
  if [ "$DRY_RUN" = true ]; then
    echo "⚠ DRY-RUN MODE: No actual changes will be made"
    echo ""
    read -p "Continue with simulation? (y/N): " continue_confirm
  else
    echo "⚠ WARNING: This will modify files and permissions!"
    echo ""
    read -p "Proceed with SNAFU-Fix? (y/N): " continue_confirm
  fi
  
  if [[ ! "${continue_confirm,,}" =~ ^y ]]; then
    echo ""
    log_info "Operation cancelled by user"
    echo ""
    read -p "Press Enter to return to menu..."
    exit 0
  fi
  
  echo ""
  echo "Starting SNAFU-Fix operations..."
  
  local has_errors=false
  
  # STEP 1: File Renaming
  [ -d "$UT_BASE_PATH/Maps" ] && { fix_extension_case "$UT_BASE_PATH/Maps" || has_errors=true; }
  [ -d "$UT_BASE_PATH/Textures" ] && { fix_extension_case "$UT_BASE_PATH/Textures" || has_errors=true; }
  [ -d "$UT_BASE_PATH/Sounds" ] && { fix_extension_case "$UT_BASE_PATH/Sounds" || has_errors=true; }
  [ -d "$UT_BASE_PATH/Music" ] && { fix_extension_case "$UT_BASE_PATH/Music" || has_errors=true; }
  [ -d "$UT_BASE_PATH/System" ] && { fix_extension_case "$UT_BASE_PATH/System" || has_errors=true; }
  [ -d "$UT_REDIRECT" ] && { fix_extension_case "$UT_REDIRECT" || has_errors=true; }
  
  # STEP 2: Permissions (orphan cleanup moved to orphan.sh)
  set_permissions || has_errors=true
  
  # Final Summary
  echo ""
  echo "==========================================================================="
  echo "                           FINAL SUMMARY"
  echo "==========================================================================="
  echo ""
  
  if [ "$has_errors" = true ]; then
    echo "  Script completed with ERRORS"
    echo "   Review error messages above"
    echo ""
    read -p "Press Enter to return to menu..."
    exit 1
  else
    echo "  Script completed SUCCESSFULLY"
    echo "   All operations finished without errors"
    echo ""
    read -p "Press Enter to return to menu..."
    exit 0
  fi
}

# Trap cleanup on interrupt
trap 'echo ""; log_error "Script interrupted by user"; exit 130' INT TERM

# Execute main
main
