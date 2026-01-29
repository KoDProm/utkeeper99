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
# UT Installation Verification Tool

set -euo pipefail
IFS=$'\n\t'

# === LOAD CONFIGURATION ===
# PROJECT_ROOT and CONFIG_FILE were exported by maptools.sh
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

# Import variables
UT_BASE_PATH="${UT_BASE_PATH:-/home/utserver/utserver}"
DRY_RUN="${DRY_RUN:-false}"

# Logging functions
log_info() { echo "[INFO] $*"; }
log_warn() { echo "[WARN] $*" >&2; }
log_error() { echo "[ERROR] $*" >&2; }

# === MAIN VERIFICATION FUNCTION ===
clear
echo "==========================================================================="
echo "                    UT INSTALLATION VERIFICATION"
echo "==========================================================================="
echo ""
echo "UT Base Path: $UT_BASE_PATH"
echo ""

if [ "$DRY_RUN" = true ]; then
  echo "╔═══════════════════════════════════════════════════════════════════════╗"
  echo "║                     *** DRY-RUN MODE ACTIVE ***                       ║"
  echo "║                   *** NO FILES WILL BE MODIFIED ***                   ║"
  echo "╚═══════════════════════════════════════════════════════════════════════╝"
  echo ""
fi

echo "This will check for:"
echo "  1. Core dump files (crash files)"
echo "  2. 0-byte or corrupt package files"
echo "  3. Missing critical files"
echo "  4. Executable permissions"
echo "  5. Duplicate files (case-different)"
echo ""
echo "==========================================================================="
echo ""

# Check if UT directory exists
if [ ! -d "$UT_BASE_PATH" ]; then
  log_error "UT Base Path not found: $UT_BASE_PATH"
  echo ""
  read -p "Press Enter to return to menu..."
  exit 1
fi

errors=0
warnings=0

# ===================================
# 1. CHECK FOR CORE DUMPS
# ===================================
echo "--- Checking for Core Dumps ---"

if [ -f "$UT_BASE_PATH/System/core" ]; then
  log_warn "Found core dump file in System/"
  warnings=$((warnings + 1))
  
  if [ "$DRY_RUN" = true ]; then
    echo "  [DRY-RUN] Would ask to remove core dump"
  else
    read -p "Remove core dump? (y/N): " confirm
    if [[ "${confirm,,}" =~ ^y ]]; then
      rm -f "$UT_BASE_PATH/System/core" && \
        log_info "Removed core dump" || \
        log_error "Failed to remove core dump"
    else
      log_info "Keeping core dump"
    fi
  fi
else
  log_info "✓ No core dumps found"
fi

echo ""

# ===================================
# 2. CHECK FOR 0-BYTE FILES
# ===================================
echo "--- Checking for 0-Byte Files ---"

zero_byte_files=()

for dir in Maps Textures Sounds Music System; do
  if [ ! -d "$UT_BASE_PATH/$dir" ]; then
    continue
  fi
  
  while IFS= read -r -d '' file; do
    zero_byte_files+=("$file")
  done < <(find "$UT_BASE_PATH/$dir" -maxdepth 1 -type f -size 0 -print0 2>/dev/null)
done

if [ ${#zero_byte_files[@]} -gt 0 ]; then
  log_warn "Found ${#zero_byte_files[@]} zero-byte file(s):"
  
  for file in "${zero_byte_files[@]}"; do
    filename=$(basename "$file")
    dirname=$(basename "$(dirname "$file")")
    echo "      [$dirname] $filename"
  done
  
  errors=$((errors + 1))
  
  if [ "$DRY_RUN" = true ]; then
    echo ""
    log_info "[DRY-RUN] Would ask to delete zero-byte files"
  else
    echo ""
    read -p "Delete all zero-byte files? (y/N): " confirm
    if [[ "${confirm,,}" =~ ^y ]]; then
      deleted=0
      for file in "${zero_byte_files[@]}"; do
        if rm -f "$file" 2>/dev/null; then
          deleted=$((deleted + 1))
        fi
      done
      log_info "Deleted $deleted zero-byte file(s)"
    else
      log_info "Keeping zero-byte files"
    fi
  fi
else
  log_info "✓ No zero-byte files found"
fi

echo ""

# ===================================
# 3. CHECK CRITICAL FILES
# ===================================
echo "--- Checking Critical Files ---"

critical_files=(
  "System/ucc-bin"
  "System/Core.u"
  "System/Engine.u"
  "System/UnrealTournament.ini"
)

missing=0

for critical in "${critical_files[@]}"; do
  if [ ! -f "$UT_BASE_PATH/$critical" ]; then
    log_error "Missing: $critical"
    missing=$((missing + 1))
    errors=$((errors + 1))
  fi
done

if [ $missing -eq 0 ]; then
  log_info "✓ All critical files present"
else
  log_error "Missing $missing critical file(s) - Installation may be incomplete!"
fi

echo ""

# ===================================
# 4. CHECK EXECUTABLE PERMISSIONS
# ===================================
echo "--- Checking Executable Permissions ---"

perm_issues=0

# Check ucc-bin
if [ -f "$UT_BASE_PATH/System/ucc-bin" ]; then
  if [ ! -x "$UT_BASE_PATH/System/ucc-bin" ]; then
    log_warn "ucc-bin is not executable"
    perm_issues=$((perm_issues + 1))
    warnings=$((warnings + 1))
    
    if [ "$DRY_RUN" = true ]; then
      echo "  [DRY-RUN] Would ask to fix executable permission"
    else
      read -p "Fix permission? (y/N): " confirm
      if [[ "${confirm,,}" =~ ^y ]]; then
        chmod +x "$UT_BASE_PATH/System/ucc-bin" && \
          log_info "Fixed ucc-bin permission" || \
          log_error "Failed to fix permission"
      fi
    fi
  fi
fi

# Check .so libraries
if [ -d "$UT_BASE_PATH/System" ]; then
  non_exec_libs=0
  while IFS= read -r -d '' lib; do
    if [ ! -x "$lib" ]; then
      non_exec_libs=$((non_exec_libs + 1))
    fi
  done < <(find "$UT_BASE_PATH/System" -maxdepth 1 -name "*.so" -type f -print0 2>/dev/null)
  
  if [ $non_exec_libs -gt 0 ]; then
    log_warn "Found $non_exec_libs non-executable .so library files"
    perm_issues=$((perm_issues + 1))
    warnings=$((warnings + 1))
    
    if [ "$DRY_RUN" = true ]; then
      echo "  [DRY-RUN] Would ask to fix library permissions"
    else
      read -p "Fix library permissions? (y/N): " confirm
      if [[ "${confirm,,}" =~ ^y ]]; then
        find "$UT_BASE_PATH/System" -maxdepth 1 -name "*.so" -type f -exec chmod +x {} + && \
          log_info "Fixed library permissions" || \
          log_error "Failed to fix permissions"
      fi
    fi
  fi
fi

if [ $perm_issues -eq 0 ]; then
  log_info "✓ All executable permissions correct"
fi

echo ""

# ===================================
# 5. CHECK FOR DUPLICATE FILES
# ===================================
echo "--- Checking for Duplicate Files ---"

duplicates=()

for dir in Maps Textures Sounds Music System; do
  if [ ! -d "$UT_BASE_PATH/$dir" ]; then
    continue
  fi
  
  # Find files with same name but different case
  while IFS= read -r file; do
    filename=$(basename "$file")
    lower=$(echo "$filename" | tr '[:upper:]' '[:lower:]')
    
    # Check if other files with same lowercase name exist
    count=$(find "$UT_BASE_PATH/$dir" -maxdepth 1 -type f -iname "$filename" 2>/dev/null | wc -l)
    
    if [ $count -gt 1 ]; then
      # Only add once per duplicate set
      if ! printf '%s\n' "${duplicates[@]}" 2>/dev/null | grep -q "^$lower:$dir$"; then
        duplicates+=("$lower:$dir")
      fi
    fi
  done < <(find "$UT_BASE_PATH/$dir" -maxdepth 1 -type f 2>/dev/null)
done

if [ ${#duplicates[@]} -gt 0 ]; then
  log_warn "Found ${#duplicates[@]} file(s) with case-different duplicates:"
  
  for dup in "${duplicates[@]}"; do
    name="${dup%%:*}"
    dir="${dup#*:}"
    echo "      [$dir] $name (multiple case variations)"
  done
  
  warnings=$((warnings + 1))
  
  echo ""
  log_info "Use SNAFU-Fix (MapTools → Option 6) to normalize file names"
else
  log_info "✓ No duplicate files found"
fi

echo ""

# ===================================
# SUMMARY
# ===================================
echo "==========================================================================="
echo "                    VERIFICATION SUMMARY"
echo "==========================================================================="
echo ""

if [ $errors -eq 0 ] && [ $warnings -eq 0 ]; then
  echo "  ✓ Installation looks healthy!"
  echo "  ✓ No errors or warnings found"
elif [ $errors -eq 0 ]; then
  echo "  ⚠ Installation OK with $warnings warning(s)"
  echo "  ⚠ Consider fixing warnings for optimal performance"
else
  echo "  ✗ Found $errors error(s) and $warnings warning(s)"
  echo "  ✗ Installation may have issues"
  
  if [ $missing -gt 0 ]; then
    echo ""
    echo "  Critical files are missing!"
    echo "  Consider reinstalling UT99 Server"
  fi
fi

echo ""
echo "==========================================================================="
echo ""

read -p "Press Enter to return to menu..."

exit 0