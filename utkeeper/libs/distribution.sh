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
# Enable strict error handling
set -euo pipefail

# === DISTRIBUTION.SH - UT99 File Distribution System v2.7 ===
# Step 1: Collect all UT packages from subdirectories to /upload root
# Step 2: Distribute files to UT Server and Web Redirect
# Step 3: Post-distribution cleanup

# Load configuration
# PROJECT_ROOT, CONFIG_FILE, and LIBS_DIR were exported by maptools.sh
if [[ -z "${PROJECT_ROOT:-}" ]]; then
  echo "ERROR: PROJECT_ROOT not set!"
  echo "This script must be called from maptools.sh"
  exit 1
fi

CONFIG_FILE="${PROJECT_ROOT}/.config"
LIBS_DIR="${PROJECT_ROOT}/libs"

if [[ ! -f "$CONFIG_FILE" ]]; then
  echo "ERROR: Config file not found: $CONFIG_FILE"
  echo "Please run Configuration (Option 8 in main menu)"
  exit 1
fi

source "$CONFIG_FILE"

# Import required variables from config
# No fallbacks - config must have all values!
if [[ -z "${UPLOAD_DIR:-}" ]] || [[ -z "${UT_BASE_PATH:-}" ]] || [[ -z "${UT_REDIRECT:-}" ]]; then
  echo "ERROR: Config file is missing required variables!"
  echo "Required: UPLOAD_DIR, UT_BASE_PATH, UT_REDIRECT"
  echo "Please run Configuration (Option 8 in main menu)"
  exit 1
fi

export UPLOAD_DIR
export UT_BASE_PATH
export UT_REDIRECT
export DRY_RUN="${DRY_RUN:-false}"

# Get owner information from config
if [[ -z "${UT_USER:-}" ]] || [[ -z "${UT_GROUP:-}" ]] || [[ -z "${WEB_USER:-}" ]] || [[ -z "${WEB_GROUP:-}" ]]; then
  echo "ERROR: Config file is missing owner information!"
  echo "Required: UT_USER, UT_GROUP, WEB_USER, WEB_GROUP"
  echo "Please run Configuration (Option 8 in main menu)"
  exit 1
fi

# Package types and their target directories
declare -A UT_TARGETS=(
  [".unr"]="Maps"
  [".utx"]="Textures"
  [".uax"]="Sounds"
  [".umx"]="Music"
  [".u"]="System"
  [".int"]="System"
)

# Global variables for tracking
DIST_MOVED=0
DIST_SKIPPED=0

# Logging functions
log_info() { echo "[INFO] $*"; }
log_warn() { echo "[WARN] $*" >&2; }
log_error() { echo "[ERROR] $*" >&2; }

# === PRE-FLIGHT OVERVIEW ===
show_preflight_overview() {
  clear
  echo "==========================================================================="
  echo "                    DISTRIBUTION PRE-FLIGHT OVERVIEW"
  echo "==========================================================================="
  echo ""
  
  if [ "$DRY_RUN" = true ]; then
    echo "==========================================================================="
    echo "                     *** DRY-RUN MODE ACTIVE ***                       "
    echo "                   *** NO FILES WILL BE MODIFIED ***                   "
    echo "==========================================================================="
    echo ""
  fi
  
  echo "=== STEP 1: FILE COLLECTION ========================================"
  
  # Scan for files in subdirectories
  local subdirs_count=0
  while IFS= read -r -d '' file; do
    local file_dir=$(dirname "$file")
    if [ "$file_dir" != "$UPLOAD_DIR" ] && [[ "$file" != *"/installed/"* ]]; then
      subdirs_count=$((subdirs_count + 1))
    fi
  done < <(find "$UPLOAD_DIR" -maxdepth 5 -type f \( \
    -iname "*.unr" -o -iname "*.utx" -o -iname "*.uax" -o \
    -iname "*.umx" -o -iname "*.u" -o -iname "*.int" -o -iname "*.uz" \
  \) -print0 2>/dev/null)
  
  if [ "$subdirs_count" -gt 0 ]; then
    echo "  → Found $subdirs_count file(s) in subdirectories"
    echo "  → Will move to: $UPLOAD_DIR"
  else
    echo "  → No files in subdirectories (nothing to collect)"
  fi
  
  echo ""
  echo "=== STEP 2: DISTRIBUTION ==========================================="
  
  # Count files to distribute
  declare -A dist_counts
  local total_to_dist=0
  
  for ext in "${!UT_TARGETS[@]}"; do
    local count=$(find "$UPLOAD_DIR" -maxdepth 1 -type f -iname "*$ext" 2>/dev/null | wc -l)
    if [ "$count" -gt 0 ]; then
      dist_counts["$ext"]=$count
      total_to_dist=$((total_to_dist + count))
    fi
  done
  
  # Count .uz files
  local uz_count=$(find "$UPLOAD_DIR" -maxdepth 1 -type f -iname "*.uz" 2>/dev/null | wc -l)
  
  if [ "$total_to_dist" -gt 0 ] || [ "$uz_count" -gt 0 ]; then
    echo "  Files to distribute:"
    for ext in "${!dist_counts[@]}"; do
      local count=${dist_counts[$ext]}
      echo "    • $ext: $count → UT Server (${UT_TARGETS[$ext]}/)"
    done
    
    if [ "$uz_count" -gt 0 ]; then
      echo "    • .uz: $uz_count → Web Redirect ($UT_REDIRECT)"
    fi
  else
    echo "  → No files ready for distribution"
  fi
  
  echo ""
  echo "=== STEP 3: POST-DISTRIBUTION CLEANUP =============================="
  echo "  → Case-fixing for distributed files"
  echo "  → Orphaned .uz cleanup in Web Redirect"
  
  echo ""
  echo "=== SUMMARY ========================================================"
  local total_operations=$((subdirs_count + total_to_dist + uz_count))
  
  if [ "$total_operations" -eq 0 ]; then
    echo "  ⚠ No file operations planned - nothing to do"
    echo ""
    echo "==========================================================================="
    echo ""
    read -p "Press Enter to return to menu..."
    exit 0
  fi
  
  echo "  Total files to process: $total_operations"
  echo ""
  echo "==========================================================================="
  echo ""
  
  if [ "$DRY_RUN" = true ]; then
    read -p "Press Enter to start DRY-RUN..."
  else
    read -p "Proceed with distribution? (y/N): " confirm
    if [[ ! "${confirm,,}" =~ ^y ]]; then
      echo "Distribution cancelled"
      echo ""
      read -p "Press Enter to return to menu..."
      exit 0
    fi
  fi
  
  echo ""
}

# === STEP 1: COLLECT PACKAGE FILES ===
collect_package_files() {
  echo "==========================================================================="
  echo "                    STEP 1: COLLECT PACKAGE FILES"
  echo "==========================================================================="
  echo ""
  echo "Upload Directory: $UPLOAD_DIR"
  echo ""
  
  if [ "$DRY_RUN" = true ]; then
    echo "*** DRY-RUN MODE ACTIVE ***"
    echo ""
  fi
  
  # Find all UT package files in subdirectories
  local found_files=()
  
  echo "Scanning for UT package files in subdirectories (max depth 5)..."
  
  while IFS= read -r -d '' file; do
    # Skip files already in upload root
    local file_dir=$(dirname "$file")
    if [ "$file_dir" = "$UPLOAD_DIR" ]; then
      continue
    fi
    
    # Skip files in /installed subdirectory
    if [[ "$file" == *"/installed/"* ]]; then
      continue
    fi
    
    found_files+=("$file")
  done < <(find "$UPLOAD_DIR" -maxdepth 5 -type f \( \
    -iname "*.unr" -o \
    -iname "*.utx" -o \
    -iname "*.uax" -o \
    -iname "*.umx" -o \
    -iname "*.u" -o \
    -iname "*.int" -o \
    -iname "*.uz" \
  \) -print0 2>/dev/null)
  
  local file_count=${#found_files[@]}
  
  if [ "$file_count" -eq 0 ]; then
    log_info "No package files found in subdirectories"
    echo ""
    return 0
  fi
  
  echo ""
  echo "Found $file_count package file(s) in subdirectories:"
  
  # Group by type for display
  for file in "${found_files[@]}"; do
    local rel_path="${file#$UPLOAD_DIR/}"
    echo "  - $rel_path"
  done
  
  echo ""
  
  if [ "$DRY_RUN" = true ]; then
    log_info "[DRY-RUN] Would move $file_count files to upload root"
    echo ""
    return 0
  fi
  
  read -p "Move these files to upload root? (y/N): " confirm
  
  if [[ ! "${confirm,,}" =~ ^y ]]; then
    log_info "Skipped file collection"
    echo ""
    return 0
  fi
  
  echo ""
  echo "Moving files to upload root..."
  echo ""
  
  local moved=0
  local failed=0
  
  for file in "${found_files[@]}"; do
    local filename=$(basename "$file")
    local target="$UPLOAD_DIR/$filename"
    
    # Check if target exists
    if [ -f "$target" ]; then
      log_warn "File already exists in root: $filename (skipping)"
      ((failed++)) || true
      continue
    fi
    
    # Move file
    if mv "$file" "$target" 2>/dev/null; then
      echo "  [OK] Moved: $filename"
      ((moved++)) || true
    else
      log_error "Failed to move: $filename"
      ((failed++)) || true
    fi
  done
  
  echo ""
  log_info "Collection complete: $moved moved, $failed skipped/failed"
  echo ""
}

# === STEP 2: DISTRIBUTE FILES ===
distribute_to_ut_server() {
  echo "==========================================================================="
  echo "                    STEP 2: DISTRIBUTE TO UT SERVER"
  echo "==========================================================================="
  echo ""
  echo "UT Base Path: $UT_BASE_PATH"
  echo "Web Redirect: $UT_REDIRECT"
  echo ""
  
  if [ "$DRY_RUN" = true ]; then
    echo "*** DRY-RUN MODE ACTIVE ***"
    echo ""
  fi
  
  # Count files to distribute
  declare -A file_counts
  local uz_count=0
  
  # Count package files
  for ext in "${!UT_TARGETS[@]}"; do
    local count=$(find "$UPLOAD_DIR" -maxdepth 1 -type f -iname "*$ext" 2>/dev/null | wc -l)
    file_counts["$ext"]=$count
  done
  
  # Count .uz files separately
  uz_count=$(find "$UPLOAD_DIR" -maxdepth 1 -type f -iname "*.uz" 2>/dev/null | wc -l)
  
  # Check if there's anything to distribute
  local total_files=0
  for count in "${file_counts[@]}"; do
    total_files=$((total_files + count))
  done
  
  if [ "$total_files" -eq 0 ] && [ "$uz_count" -eq 0 ]; then
    log_info "No files to distribute"
    echo ""
    return 0
  fi
  
  echo "Files to distribute:"
  for ext in "${!UT_TARGETS[@]}"; do
    local count=${file_counts[$ext]}
    [ "$count" -gt 0 ] && echo "  ${ext}: $count file(s) → UT Server (${UT_TARGETS[$ext]}/)"
  done
  
  if [ "$uz_count" -gt 0 ]; then
    echo "  .uz: $uz_count file(s) → Web Redirect ($UT_REDIRECT)"
    echo ""
    echo "NOTE: If files exist, you will be asked to confirm overwrite."
    echo "      Default is to keep existing files (No)."
  fi
  
  echo ""
  
  if [ "$DRY_RUN" = true ]; then
    log_info "[DRY-RUN] Would distribute files"
    echo ""
    return 0
  fi
  
  read -p "Proceed with distribution? (y/N): " confirm
  
  if [[ ! "${confirm,,}" =~ ^y ]]; then
    log_info "Distribution cancelled"
    echo ""
    return 0
  fi
  
  echo ""
  echo "=== DISTRIBUTING FILES ==="
  echo ""
  
  # Reset counters
  DIST_MOVED=0
  DIST_SKIPPED=0
  
  # Distribute UT packages
  for ext in "${!UT_TARGETS[@]}"; do
    local target_dir="${UT_BASE_PATH}/${UT_TARGETS[$ext]}"
    
    # Create target directory if it doesn't exist
    if [[ ! -d "$target_dir" ]]; then
      log_warn "Target directory does not exist: $target_dir"
      read -p "  Create it? (Y/n): " create_confirm
      if [[ ! "${create_confirm,,}" =~ ^n ]]; then
        if mkdir -p "$target_dir" 2>/dev/null; then
          log_info "✓ Created: $target_dir"
        else
          log_error "Failed to create directory: $target_dir"
          continue
        fi
      else
        log_warn "Skipping $ext files"
        continue
      fi
    fi
    
    # Find all files with this extension
    shopt -s nullglob
    local files=("$UPLOAD_DIR"/*$ext)
    shopt -u nullglob
    
    for file in "${files[@]}"; do
      local filename=$(basename "$file")
      local target="$target_dir/$filename"
      
      # Check if file exists
      if [ -f "$target" ]; then
        echo "  [EXISTS] $filename in ${UT_TARGETS[$ext]}/"
        read -p "    Overwrite? (y/N): " overwrite
        if [[ ! "${overwrite,,}" =~ ^y ]]; then
          log_info "  [SKIP] Kept existing: $filename"
          ((DIST_SKIPPED++)) || true
          continue
        fi
      fi
      
      # Copy file
      if cp "$file" "$target" 2>/dev/null; then
        # Set ownership
        chown "$UT_USER:$UT_GROUP" "$target" 2>/dev/null || true
        chmod 644 "$target" 2>/dev/null || true
        
        echo "  [OK] Copied: $filename → ${UT_TARGETS[$ext]}/"
        ((DIST_MOVED++)) || true
      else
        log_error "  [FAIL] Could not copy: $filename"
        ((DIST_SKIPPED++)) || true
      fi
    done
  done
  
  # Distribute .uz files to web redirect
  if [ "$uz_count" -gt 0 ]; then
    echo ""
    echo "=== DISTRIBUTING .UZ FILES TO WEB REDIRECT ==="
    echo ""
    
    # Create redirect directory if it doesn't exist
    if [[ ! -d "$UT_REDIRECT" ]]; then
      log_warn "Web Redirect directory does not exist: $UT_REDIRECT"
      read -p "  Create it? (Y/n): " create_confirm
      if [[ ! "${create_confirm,,}" =~ ^n ]]; then
        if mkdir -p "$UT_REDIRECT" 2>/dev/null; then
          chown "$WEB_USER:$WEB_GROUP" "$UT_REDIRECT" 2>/dev/null || true
          chmod 755 "$UT_REDIRECT"
          log_info "✓ Created: $UT_REDIRECT"
        else
          log_error "Failed to create directory: $UT_REDIRECT"
          uz_count=0
        fi
      else
        log_warn "Skipping .uz distribution"
        uz_count=0
      fi
    fi
    
    if [ "$uz_count" -gt 0 ]; then
      shopt -s nullglob
      local uz_files=("$UPLOAD_DIR"/*.uz)
      shopt -u nullglob
      
      for file in "${uz_files[@]}"; do
        local filename=$(basename "$file")
        local target="$UT_REDIRECT/$filename"
        
        # Check if file exists
        if [ -f "$target" ]; then
          echo "  [EXISTS] $filename in redirect"
          read -p "    Overwrite? (y/N): " overwrite
          if [[ ! "${overwrite,,}" =~ ^y ]]; then
            log_info "  [SKIP] Kept existing: $filename"
            ((DIST_SKIPPED++)) || true
            continue
          fi
        fi
        
        # Copy file
        if cp "$file" "$target" 2>/dev/null; then
          # Set ownership
          chown "$WEB_USER:$WEB_GROUP" "$target" 2>/dev/null || true
          chmod 644 "$target" 2>/dev/null || true
          
          echo "  [OK] Copied: $filename → redirect/"
          ((DIST_MOVED++)) || true
        else
          log_error "  [FAIL] Could not copy: $filename"
          ((DIST_SKIPPED++)) || true
        fi
      done
    fi
  fi
  
  echo ""
  log_info "Distribution complete: $DIST_MOVED moved, $DIST_SKIPPED skipped"
  echo ""
}

# === STEP 3: POST-DISTRIBUTION CLEANUP ===
post_distribution_cleanup() {
  # Skip if nothing was distributed
  if [ "$DIST_MOVED" -eq 0 ]; then
    log_info "No files distributed, skipping cleanup"
    return 0
  fi
  
  echo "==========================================================================="
  echo "                    STEP 3: POST-DISTRIBUTION CLEANUP"
  echo "==========================================================================="
  echo ""
  
  if [ "$DRY_RUN" = true ]; then
    echo "*** DRY-RUN MODE ACTIVE ***"
    echo ""
    log_info "[DRY-RUN] Would perform post-distribution cleanup"
    echo ""
    return 0
  fi
  
  # Ask for cleanup
  read -p "Run SNAFU-Fix (case-fixing & permissions)? (Y/n): " cleanup_confirm
  
  if [[ "${cleanup_confirm,,}" =~ ^n ]]; then
    log_info "Cleanup skipped"
    echo ""
    return 0
  fi
  
  # Call snafu_fix.sh
  local snafu_script="${LIBS_DIR}/snafu_fix.sh"
  
  if [[ ! -f "$snafu_script" ]]; then
    log_error "snafu_fix.sh not found: $snafu_script"
    echo ""
    return 1
  fi
  
  echo ""
  log_info "Launching SNAFU-Fix..."
  echo ""
  
  bash "$snafu_script"
  
  echo ""
}

# === MAIN EXECUTION ===

# Show overview and get confirmation
show_preflight_overview

# STEP 1: Collect files from subdirectories
collect_package_files

# STEP 2: Distribute to UT Server and Web Redirect
distribute_to_ut_server

# STEP 3: Post-distribution cleanup
post_distribution_cleanup

# === FINAL SUMMARY ===
echo "==========================================================================="
echo "                    DISTRIBUTION COMPLETE"
echo "==========================================================================="
echo ""

if [ "$DRY_RUN" = true ]; then
  echo "*** DRY-RUN MODE - NO CHANGES WERE MADE ***"
else
  echo "Files distributed: $DIST_MOVED"
  echo "Files skipped:     $DIST_SKIPPED"
fi

echo ""
echo "==========================================================================="
echo ""

read -p "Press Enter to return to menu..."
