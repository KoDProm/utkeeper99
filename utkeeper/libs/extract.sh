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

# === EXTRACT.SH - Archive Extraction Tool v2.7 ===

# Load configuration
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

# Import variables (with fallbacks)
UPLOAD_DIR="${UPLOAD_DIR:-${PROJECT_ROOT}/upload}"
INSTALLED_DIR="${UPLOAD_DIR}/installed"
DRY_RUN="${DRY_RUN:-false}"

# Get real user (not root when using sudo)
REAL_USER="${SUDO_USER:-$USER}"
REAL_GROUP=$(id -gn "$REAL_USER" 2>/dev/null || echo "$REAL_USER")

# Ensure upload and installed directories exist
if [ "$DRY_RUN" = false ]; then
  mkdir -p "$UPLOAD_DIR"
  mkdir -p "$INSTALLED_DIR"
  chown "$REAL_USER:$REAL_GROUP" "$INSTALLED_DIR" 2>/dev/null || true
fi

# === DEPENDENCY CHECK ===
check_dependencies() {
  local missing=()
  
  command -v unzip >/dev/null 2>&1 || missing+=("unzip")
  command -v unrar >/dev/null 2>&1 || missing+=("unrar")
  command -v 7z >/dev/null 2>&1 || missing+=("7z (p7zip-full)")
  command -v tar >/dev/null 2>&1 || missing+=("tar")
  
  if [ ${#missing[@]} -gt 0 ]; then
    echo "WARNING: Missing tools: ${missing[*]}"
    echo "Install with: sudo apt install unzip unrar-free p7zip-full tar"
    echo ""
    read -p "Continue anyway? (y/N): " confirm
    [[ ! "${confirm,,}" =~ ^y ]] && exit 1
  fi
}

# === EXTRACTION FUNCTIONS ===

extract_archive() {
  local archive="$1"
  local extract_dir="$2"
  local filename=$(basename "$archive")
  
  # Create extraction directory
  if [ "$DRY_RUN" = true ]; then
    echo "[DRY-RUN] Would create: $extract_dir"
  else
    mkdir -p "$extract_dir"
    chown "$REAL_USER:$REAL_GROUP" "$extract_dir" 2>/dev/null || true
  fi
  
  echo "  Extracting: $filename"
  
  # Extract based on file type
  case "${archive,,}" in
    *.zip)
      if [ "$DRY_RUN" = true ]; then
        echo "  [DRY-RUN] unzip \"$archive\" -d \"$extract_dir\""
      else
        unzip -q -o "$archive" -d "$extract_dir" 2>/dev/null || {
          echo "  ✗ Failed to extract: $filename"
          return 1
        }
      fi
      ;;
      
    *.rar)
      if [ "$DRY_RUN" = true ]; then
        echo "  [DRY-RUN] unrar x -o+ \"$archive\" \"$extract_dir/\""
      else
        unrar x -o+ -inul "$archive" "$extract_dir/" 2>/dev/null || {
          echo "  ✗ Failed to extract: $filename"
          return 1
        }
      fi
      ;;
      
    *.7z)
      if [ "$DRY_RUN" = true ]; then
        echo "  [DRY-RUN] 7z x \"$archive\" -o\"$extract_dir\""
      else
        7z x "$archive" -o"$extract_dir" -y >/dev/null 2>&1 || {
          echo "  ✗ Failed to extract: $filename"
          return 1
        }
      fi
      ;;
      
    *.tar.gz|*.tgz)
      if [ "$DRY_RUN" = true ]; then
        echo "  [DRY-RUN] tar -xzf \"$archive\" -C \"$extract_dir\""
      else
        tar -xzf "$archive" -C "$extract_dir" 2>/dev/null || {
          echo "  ✗ Failed to extract: $filename"
          return 1
        }
      fi
      ;;
      
    *.tar.bz2|*.tbz2)
      if [ "$DRY_RUN" = true ]; then
        echo "  [DRY-RUN] tar -xjf \"$archive\" -C \"$extract_dir\""
      else
        tar -xjf "$archive" -C "$extract_dir" 2>/dev/null || {
          echo "  ✗ Failed to extract: $filename"
          return 1
        }
      fi
      ;;
      
    *.tar)
      if [ "$DRY_RUN" = true ]; then
        echo "  [DRY-RUN] tar -xf \"$archive\" -C \"$extract_dir\""
      else
        tar -xf "$archive" -C "$extract_dir" 2>/dev/null || {
          echo "  ✗ Failed to extract: $filename"
          return 1
        }
      fi
      ;;
      
    *)
      echo "  ⚠ Unsupported format: $filename"
      return 1
      ;;
  esac
  
  echo "  ✓ Extracted: $filename"
  return 0
}

extract_recursive() {
  local current_dir="$1"
  local current_depth="${2:-0}"
  local max_depth=10
  
  if [ "$current_depth" -ge "$max_depth" ]; then
    echo "  ⚠ Max depth ($max_depth) reached, stopping recursion"
    return 0
  fi
  
  # Only show scanning message for subdirectories (depth > 0)
  if [ "$current_depth" -gt 0 ]; then
    echo ""
    echo "=== Scanning level $current_depth: $(basename "$current_dir") ==="
  fi
  
  local archives=()
  while IFS= read -r -d '' archive; do
    archives+=("$archive")
  done < <(find "$current_dir" -maxdepth 1 -type f \( \
    -iname "*.zip" -o \
    -iname "*.rar" -o \
    -iname "*.7z" -o \
    -iname "*.tar" -o \
    -iname "*.tar.gz" -o \
    -iname "*.tgz" -o \
    -iname "*.tar.bz2" -o \
    -iname "*.tbz2" \
  \) -print0 2>/dev/null)
  
  if [ ${#archives[@]} -eq 0 ]; then
    # Only show message for subdirectories
    if [ "$current_depth" -gt 0 ]; then
      echo "  (no nested archives)"
    fi
    return 0
  fi
  
  # Show count for subdirectories
  if [ "$current_depth" -gt 0 ]; then
    echo "  Found ${#archives[@]} nested archive(s)"
  fi
  
  for archive in "${archives[@]}"; do
    local filename=$(basename "$archive")
    local name_without_ext="${filename%.*}"
    
    if [[ "$filename" =~ \.(tar\.gz|tar\.bz2|tgz|tbz2)$ ]]; then
      name_without_ext="${filename%%.*}"
    fi
    
    local extract_dir="${current_dir}/${name_without_ext}"
    
    if extract_archive "$archive" "$extract_dir"; then
      if [ "$DRY_RUN" = false ]; then
        chown -R "$REAL_USER:$REAL_GROUP" "$extract_dir" 2>/dev/null || true
      fi
      
      if [ "$DRY_RUN" = true ]; then
        echo "  [DRY-RUN] Would move to installed: $(basename "$archive")"
      else
        local archive_name=$(basename "$archive")
        local installed_target="$INSTALLED_DIR/$archive_name"
        
        if [ -f "$installed_target" ]; then
          local counter=1
          local base_name="${archive_name%.*}"
          local ext="${archive_name##*.}"
          while [ -f "$INSTALLED_DIR/${base_name}_${counter}.$ext" ]; do
            ((counter++))
          done
          installed_target="$INSTALLED_DIR/${base_name}_${counter}.$ext"
        fi
        
        if mv "$archive" "$installed_target" 2>/dev/null; then
          echo "  ✓ Archived: $(basename "$archive") → installed/"
        else
          echo "  ⚠ Failed to move archive, deleting instead"
          rm -f "$archive"
        fi
      fi
      
      if [ -d "$extract_dir" ]; then
        extract_recursive "$extract_dir" $((current_depth + 1))
      fi
    fi
  done
}

# === COLLECT UT FILES FROM SUBDIRECTORIES ===

collect_ut_files() {
  echo ""
  echo "==========================================================================="
  echo "                    COLLECTING UT FILES TO UPLOAD ROOT"
  echo "==========================================================================="
  echo ""
  echo "Moving all UT packages from subdirectories to: $UPLOAD_DIR"
  echo "File types: .unr, .utx, .uax, .umx, .u, .int, .uz"
  echo "Scanning up to 6 levels deep..."
  echo ""
  
  if [ "$DRY_RUN" = true ]; then
    echo "[DRY-RUN] Files would be collected (no actual changes)"
    echo ""
  fi
  
  local collected=0
  local skipped=0
  local failed=0
  
  # Use process substitution instead of pipe to avoid subshell
  # Scan from mindepth 2 to maxdepth 6
  local files_to_move=()
  while IFS= read -r -d '' file; do
    local file_dir=$(dirname "$file")
    
    # Skip if file is already in upload root
    if [ "$file_dir" = "$UPLOAD_DIR" ]; then
      continue
    fi
    
    # Skip files in /installed
    if [[ "$file" == "$INSTALLED_DIR/"* ]]; then
      continue
    fi
    
    files_to_move+=("$file")
  done < <(find "$UPLOAD_DIR" -mindepth 2 -maxdepth 6 -type f \( \
    -iname "*.unr" -o \
    -iname "*.utx" -o \
    -iname "*.uax" -o \
    -iname "*.umx" -o \
    -iname "*.u" -o \
    -iname "*.int" -o \
    -iname "*.uz" \
  \) ! -path "$INSTALLED_DIR/*" -print0 2>/dev/null)
  
  # Show count of found files
  echo "Found ${#files_to_move[@]} UT files in subdirectories (levels 2-6)"
  echo ""
  
  if [ ${#files_to_move[@]} -eq 0 ]; then
    echo "No files to collect."
    return 0
  fi
  
  # Temporarily disable errexit for this loop to handle errors gracefully
  set +e
  
  # Move the files
  for file in "${files_to_move[@]}"; do
    # Safety check - file still exists?
    if [ ! -f "$file" ]; then
      echo "  [WARN] File disappeared: $(basename "$file")"
      ((failed++))
      continue
    fi
    
    local filename=$(basename "$file")
    local target="$UPLOAD_DIR/$filename"
    
    # Check if target file already exists
    if [ -f "$target" ]; then
      # Advanced check: Are source and target the same file (same inode)?
      if [ "$(stat -c %i "$file" 2>/dev/null)" = "$(stat -c %i "$target" 2>/dev/null)" ]; then
        echo "  [SKIP] File is already in root: $filename"
        ((skipped++))
        continue
      fi
      
      echo "  [SKIP] File exists in root: $filename"
      ((skipped++))
      continue
    fi
    
    # Move file to upload root
    if [ "$DRY_RUN" = true ]; then
      echo "  [DRY-RUN] Would move: $filename"
      ((collected++))
    else
      if mv "$file" "$target" 2>/dev/null; then
        # Double-check if move was successful
        if [ -f "$target" ]; then
          chown "$REAL_USER:$REAL_GROUP" "$target" 2>/dev/null
          echo "  [OK] Collected: $filename"
          ((collected++))
        else
          echo "  [FAIL] Move succeeded but file not found: $filename"
          ((failed++))
        fi
      else
        echo "  [FAIL] Could not move: $filename"
        ((failed++))
      fi
    fi
  done
  
  # Re-enable errexit
  set -e
  
  echo ""
  echo "==========================================================================="
  echo "Collection Summary:"
  echo "  Collected: $collected files"
  [ "$skipped" -gt 0 ] && echo "  Skipped:   $skipped files (already in root)"
  [ "$failed" -gt 0 ] && echo "  Failed:    $failed files"
  echo "==========================================================================="
  
  if [ "$DRY_RUN" = false ] && [ "$collected" -gt 0 ]; then
    echo ""
    echo "Cleaning up empty directories..."
    find "$UPLOAD_DIR" -mindepth 1 -type d ! -path "$INSTALLED_DIR" ! -path "$INSTALLED_DIR/*" -empty -delete 2>/dev/null || true
    echo "Done."
  fi
}

# === MAIN EXECUTION ===
clear
echo "==========================================================================="
echo "                 UTK ARCHIVE EXTRACTION TOOL v2.7"
echo "==========================================================================="
echo ""
echo "Upload Directory: $UPLOAD_DIR"
echo "Max Recursion Depth: 10 levels"
echo ""

if [ "$DRY_RUN" = true ]; then
  echo "*** DRY-RUN MODE ACTIVE ***"
  echo "No files will be modified"
  echo ""
fi

echo "Supported formats:"
echo "  - ZIP (.zip)"
echo "  - RAR (.rar)"
echo "  - 7-Zip (.7z)"
echo "  - TAR (.tar, .tar.gz, .tgz, .tar.bz2, .tbz2)"
echo ""
echo "Extracted archives will be moved to: $INSTALLED_DIR"
echo ""
echo "==========================================================================="

check_dependencies

if [ ! -d "$UPLOAD_DIR" ]; then
  echo ""
  echo "ERROR: Upload directory does not exist: $UPLOAD_DIR"
  exit 1
fi

archive_count=$(find "$UPLOAD_DIR" -maxdepth 1 -type f \( \
  -iname "*.zip" -o \
  -iname "*.rar" -o \
  -iname "*.7z" -o \
  -iname "*.tar" -o \
  -iname "*.tar.gz" -o \
  -iname "*.tgz" -o \
  -iname "*.tar.bz2" -o \
  -iname "*.tbz2" \
\) 2>/dev/null | wc -l)

if [ "$archive_count" -eq 0 ]; then
  echo ""
  echo "No archives found in: $UPLOAD_DIR"
  echo ""
  echo "Place archive files (.zip, .rar, .7z, .tar) in the upload directory first."
  exit 0
fi

echo ""
echo "Found $archive_count archive(s) in upload directory"
echo ""
read -p "Start extraction? (y/N): " confirm

if [[ ! "${confirm,,}" =~ ^y ]]; then
  echo "Cancelled."
  exit 0
fi

echo ""
echo "=== STARTING EXTRACTION ==="
extract_recursive "$UPLOAD_DIR" 0

echo ""
echo "==========================================================================="
echo "                    EXTRACTION COMPLETE"
echo "==========================================================================="
echo ""

if [ "$DRY_RUN" = false ]; then
  extracted_dirs=$(find "$UPLOAD_DIR" -mindepth 1 -maxdepth 1 -type d ! -name "installed" 2>/dev/null | wc -l)
  remaining_archives=$(find "$UPLOAD_DIR" -maxdepth 1 -type f \( \
    -iname "*.zip" -o \
    -iname "*.rar" -o \
    -iname "*.7z" -o \
    -iname "*.tar" -o \
    -iname "*.tar.gz" -o \
    -iname "*.tgz" -o \
    -iname "*.tar.bz2" -o \
    -iname "*.tbz2" \
  \) 2>/dev/null | wc -l)
  
  installed_archives=$(find "$INSTALLED_DIR" -type f 2>/dev/null | wc -l)
  
  echo "Extraction Summary:"
  echo "  Extracted directories: $extracted_dirs"
  echo "  Archived originals: $installed_archives (in ./installed/)"
  echo "  Remaining archives: $remaining_archives"
  
  if [ "$remaining_archives" -gt 0 ]; then
    echo ""
    echo "⚠ Some archives could not be extracted (unsupported format or errors)"
  fi
fi

# Always run collection (function checks internally if files exist)
collect_ut_files

echo ""
echo "==========================================================================="
echo "                    ALL OPERATIONS COMPLETE"
echo "==========================================================================="
echo ""

# Final file count in upload root
if [ "$DRY_RUN" = false ]; then
  unr_count=$(find "$UPLOAD_DIR" -maxdepth 1 -type f -iname "*.unr" 2>/dev/null | wc -l)
  utx_count=$(find "$UPLOAD_DIR" -maxdepth 1 -type f -iname "*.utx" 2>/dev/null | wc -l)
  uax_count=$(find "$UPLOAD_DIR" -maxdepth 1 -type f -iname "*.uax" 2>/dev/null | wc -l)
  umx_count=$(find "$UPLOAD_DIR" -maxdepth 1 -type f -iname "*.umx" 2>/dev/null | wc -l)
  u_count=$(find "$UPLOAD_DIR" -maxdepth 1 -type f -iname "*.u" 2>/dev/null | wc -l)
  int_count=$(find "$UPLOAD_DIR" -maxdepth 1 -type f -iname "*.int" 2>/dev/null | wc -l)
  uz_count=$(find "$UPLOAD_DIR" -maxdepth 1 -type f -iname "*.uz" 2>/dev/null | wc -l)
  
  echo "Files ready in upload root:"
  echo "  Maps (.unr):        $unr_count"
  echo "  Textures (.utx):    $utx_count"
  echo "  Sounds (.uax):      $uax_count"
  echo "  Music (.umx):       $umx_count"
  echo "  Packages (.u):      $u_count"
  echo "  Int files (.int):   $int_count"
  echo "  Compressed (.uz):   $uz_count"
  echo ""
  echo "Total UT files: $((unr_count + utx_count + uax_count + umx_count + u_count + int_count + uz_count))"
fi

echo ""
echo "==========================================================================="
echo "Next steps:"
echo "  2) Compress to .uz format"
echo "  3) Distribute files to UT Server & Web Redirect"
echo "==========================================================================="
echo ""
read -p "Press Enter to return to menu..."

