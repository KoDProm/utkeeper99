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
# === ORPHAN.SH - UT Package Orphan Scanner & Cleanup v2.0 ===

set -euo pipefail
IFS=$'\n\t'

# === LOAD CONFIG ===
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
if [[ -z "${UT_BASE_PATH:-}" ]] || [[ -z "${UT_REDIRECT:-}" ]]; then
  echo "ERROR: Config missing required variables!"
  echo "Please run Configuration (Option 8 in main menu)"
  exit 1
fi

# === PATHS ===
export UT_BASE_PATH="${UT_BASE_PATH%/}"
export UT_REDIRECT="${UT_REDIRECT%/}"
export SYSTEM_DIR="${UT_BASE_PATH}/System"
export MAPS_DIR="${UT_BASE_PATH}/Maps"
export TEXTURES_DIR="${UT_BASE_PATH}/Textures"
export SOUNDS_DIR="${UT_BASE_PATH}/Sounds"
export MUSIC_DIR="${UT_BASE_PATH}/Music"

# Dependency files (persistent in libs)
LIBS_DIR="${PROJECT_ROOT}/libs"
mkdir -p "$LIBS_DIR"
WHITELIST_FILE="${LIBS_DIR}/dependency_whitelist.txt"
DEPENDENCY_FILE="${LIBS_DIR}/all_map_dependencies.txt"

# === LOGGING ===
log_info() { echo "[INFO] $*"; }
log_warn() { echo "[WARN] $*" >&2; }
log_error() { echo "[ERROR] $*" >&2; }

# === HELPER FUNCTIONS ===

# Human-readable file sizes
human_size() {
  local bytes=$1
  export LC_NUMERIC=C
  
  if (( bytes < 1024 )); then
    echo "${bytes}B"
  elif (( bytes < 1048576 )); then
    printf "%.1fKB" $(echo "scale=1; $bytes/1024" | bc)
  elif (( bytes < 1073741824 )); then
    printf "%.1fMB" $(echo "scale=1; $bytes/1048576" | bc)
  else
    printf "%.2fGB" $(echo "scale=2; $bytes/1073741824" | bc)
  fi
}

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

# Check if filename is an exception
is_exception() {
  local filename=$1
  [[ "$filename" == "koth_BaseStationTheta.unr" ]]
}

# Find UT ini file (ut.ini, UnrealTournament.ini, unrealtournament.ini)
find_ut_ini() {
  local ini_file=""
  
  # Check common names (case-insensitive)
  if [ -f "$SYSTEM_DIR/ut.ini" ]; then
    ini_file="$SYSTEM_DIR/ut.ini"
  elif [ -f "$SYSTEM_DIR/UnrealTournament.ini" ]; then
    ini_file="$SYSTEM_DIR/UnrealTournament.ini"
  elif [ -f "$SYSTEM_DIR/unrealtournament.ini" ]; then
    ini_file="$SYSTEM_DIR/unrealtournament.ini"
  else
    # Case-insensitive search
    ini_file=$(find "$SYSTEM_DIR" -maxdepth 1 -type f -iname "unrealtournament.ini" 2>/dev/null | head -1)
    if [ -z "$ini_file" ]; then
      ini_file=$(find "$SYSTEM_DIR" -maxdepth 1 -type f -iname "ut.ini" 2>/dev/null | head -1)
    fi
  fi
  
  echo "$ini_file"
}

#######################################
# DEPENDENCY EXTRACTION
#######################################

extract_all_dependencies() {
    clear
    echo "==========================================================================="
    echo "                    DEPENDENCY EXTRACTION"
    echo "==========================================================================="
    echo ""
    
    # Check if dependency file exists and fix permissions if needed
    if [ -f "$DEPENDENCY_FILE" ]; then
        # Ensure we can read/write the file
        if [ "$EUID" -eq 0 ]; then
            chmod 644 "$DEPENDENCY_FILE" 2>/dev/null || {
                log_warn "Cannot modify permissions on $DEPENDENCY_FILE"
            }
        fi
        
        echo "Found existing dependency file: $DEPENDENCY_FILE"
        file_age=$(( $(date +%s) - $(stat -c %Y "$DEPENDENCY_FILE") ))
        hours=$(( file_age / 3600 ))
        echo "File age: ${hours} hours"
        echo ""
        read -p "Re-extract dependencies? This takes several minutes. (y/N): " choice
        if [[ ! "$choice" =~ ^[Yy]$ ]]; then
            log_info "Using existing dependency file."
            echo ""
            read -p "Press Enter to continue..."
            return 0
        fi
    fi
    
    echo "Extracting dependencies from all .unr files..."
    echo "This will take several minutes..."
    echo ""
    
    local total_maps=$(find "$MAPS_DIR" -maxdepth 1 -type f -name "*.unr" 2>/dev/null | wc -l)
    echo "Total maps to process: ${total_maps}"
    echo ""
    
    # Check if ucc-bin exists
    if [ ! -f "$SYSTEM_DIR/ucc-bin" ]; then
        log_error "UCC binary not found: $SYSTEM_DIR/ucc-bin"
        echo ""
        read -p "Press Enter to continue..."
        return 1
    fi
    
    # Create header
    echo "# UT99 Map Dependencies - Extracted $(date)" > "$DEPENDENCY_FILE"
    echo "# Format: MapName|Package1,Package2,Package3,..." >> "$DEPENDENCY_FILE"
    echo "" >> "$DEPENDENCY_FILE"
    
    # Use temporary file for accumulation (avoid subshell variable loss)
    local temp_results="/tmp/extraction_results_$$.txt"
    > "$temp_results"
    
    local current=0
    
    find "$MAPS_DIR" -maxdepth 1 -type f -name "*.unr" 2>/dev/null | sort | while read -r mapfile; do
        current=$((current + 1))
        mapname=$(basename "$mapfile")
        
        echo -ne "[$current/$total_maps] $mapname ... "
        
        # Run packagedump and extract dependencies
        if cd "$SYSTEM_DIR" && ./ucc-bin packagedump "../Maps/$mapname" 2>&1 | \
           sed -n '/^Import Table:/,/^Export Table:/p' | \
           grep -A 3 "Package/Group: None" | \
           grep "ObjectName:" | \
           awk '{print $2}' | \
           sort -u > /tmp/deps_temp_$$.txt; then
            
            deps=$(cat /tmp/deps_temp_$$.txt | tr '\n' ',' | sed 's/,$//')
            count=$(cat /tmp/deps_temp_$$.txt | wc -l)
            
            if [ -n "$deps" ]; then
                echo "${mapname}|${deps}" >> "$DEPENDENCY_FILE"
                echo "OK ($count packages)"
                echo "SUCCESS" >> "$temp_results"
            else
                echo "WARN (no dependencies)"
                echo "${mapname}|NONE" >> "$DEPENDENCY_FILE"
                echo "SUCCESS" >> "$temp_results"
            fi
        else
            echo "FAIL"
            echo "${mapname}|ERROR" >> "$DEPENDENCY_FILE"
            echo "FAILED" >> "$temp_results"
        fi
        
        rm -f /tmp/deps_temp_$$.txt
    done
    
    # Count results from temp file
    local success=$(grep -c "SUCCESS" "$temp_results" 2>/dev/null || echo "0")
    local failed=$(grep -c "FAILED" "$temp_results" 2>/dev/null || echo "0")
    
    rm -f "$temp_results"
    
    echo ""
    echo "==========================================================================="
    echo "Extraction complete!"
    echo "  Success: $success maps"
    echo "  Failed:  $failed maps"
    echo "==========================================================================="
    echo ""
    
    read -p "Press Enter to continue..."
}

#######################################
# WHITELIST GENERATION
#######################################

generate_whitelist() {
    clear
    echo "==========================================================================="
    echo "                    WHITELIST GENERATION"
    echo "==========================================================================="
    echo ""
    
    if [ ! -f "$DEPENDENCY_FILE" ]; then
        log_error "Dependency file not found: $DEPENDENCY_FILE"
        echo "Please run 'Extract Map Dependencies' first."
        echo ""
        read -p "Press Enter to continue..."
        return 1
    fi
    
    echo "Generating whitelist from multiple sources..."
    echo ""
    
    # Force delete existing whitelist (always regenerate)
    rm -f "$WHITELIST_FILE" 2>/dev/null
    
    # Create header
    echo "# UT99 Package Whitelist - Generated $(date)" > "$WHITELIST_FILE"
    echo "# This list contains ALL packages that should NEVER be deleted" >> "$WHITELIST_FILE"
    echo "# Sources: System packages, Map dependencies, ServerPackages, Pattern-based" >> "$WHITELIST_FILE"
    echo "" >> "$WHITELIST_FILE"
    
    # 1. SYSTEM PACKAGES (hardcoded core packages)
    echo "# ====================================================================" >> "$WHITELIST_FILE"
    echo "# SYSTEM PACKAGES (Core UT99 - NEVER DELETE)" >> "$WHITELIST_FILE"
    echo "# ====================================================================" >> "$WHITELIST_FILE"
    cat >> "$WHITELIST_FILE" << 'SYSTEM_PACKAGES'
Core
Engine
Botpack
UnrealShare
UnrealI
IpDrv
UWeb
UBrowser
Fire
UTMenu
UWindowFonts
LadderFonts

SYSTEM_PACKAGES
    
    echo "[1/4] Added system packages (hardcoded)"
    
    # 2. MAP DEPENDENCIES (from packagedump)
    echo "# ====================================================================" >> "$WHITELIST_FILE"
    echo "# MAP DEPENDENCIES (from UCC packagedump)" >> "$WHITELIST_FILE"
    echo "# ====================================================================" >> "$WHITELIST_FILE"
    
    local map_deps=$(grep -v "^#" "$DEPENDENCY_FILE" | grep -v "^$" | grep -v "ERROR" | grep -v "NONE" | \
        cut -d'|' -f2 | tr ',' '\n' | sort -u | wc -l)
    
    grep -v "^#" "$DEPENDENCY_FILE" | grep -v "^$" | grep -v "ERROR" | grep -v "NONE" | \
        cut -d'|' -f2 | tr ',' '\n' | sort -u >> "$WHITELIST_FILE"
    
    echo "" >> "$WHITELIST_FILE"
    echo "[2/4] Added map dependencies ($map_deps packages)"
    
    # 3. SERVERPACKAGES (from UT ini file)
    echo "# ====================================================================" >> "$WHITELIST_FILE"
    echo "# SERVERPACKAGES (from UT configuration)" >> "$WHITELIST_FILE"
    echo "# ====================================================================" >> "$WHITELIST_FILE"
    
    local ini_file=$(find_ut_ini)
    local server_pkgs=0
    
    if [ -n "$ini_file" ] && [ -f "$ini_file" ]; then
        echo "[3/4] Parsing ServerPackages from: $(basename "$ini_file")"
        echo "# Source: $(basename "$ini_file")" >> "$WHITELIST_FILE"
        
        # Extract ServerPackages entries
        grep "^ServerPackages=" "$ini_file" 2>/dev/null | cut -d'=' -f2 | while read -r pkg; do
            # Remove any trailing comments or whitespace
            pkg=$(echo "$pkg" | sed 's/[[:space:]]*;.*//' | xargs)
            if [ -n "$pkg" ]; then
                echo "$pkg" >> "$WHITELIST_FILE"
                server_pkgs=$((server_pkgs + 1))
            fi
        done
        
        server_pkgs=$(grep "^ServerPackages=" "$ini_file" 2>/dev/null | wc -l)
        echo "    Found $server_pkgs ServerPackages entries"
    else
        echo "[3/4] No UT ini file found - skipping ServerPackages"
        echo "# No ini file found" >> "$WHITELIST_FILE"
    fi
    
    echo "" >> "$WHITELIST_FILE"
    
    # 4. PATTERN-BASED PROTECTION (Skins, Fonts, FX, Menu, Voice, Announce, Tech, Female, Male)
    echo "# ====================================================================" >> "$WHITELIST_FILE"
    echo "# PATTERN-BASED PROTECTION (auto-detected by filename)" >> "$WHITELIST_FILE"
    echo "# Patterns: *kin*, *ont*, *fx*, *enu*, *oice*, *nnounce*, *ech*, *Fem*, *Male*" >> "$WHITELIST_FILE"
    echo "# ====================================================================" >> "$WHITELIST_FILE"
    
    # Use temporary file to collect pattern matches
    local pattern_temp="/tmp/pattern_matches_$$.txt"
    > "$pattern_temp"
    
    # Scan all package directories for pattern matches
    for dir in "$TEXTURES_DIR" "$SOUNDS_DIR" "$MUSIC_DIR"; do
        if [ -d "$dir" ]; then
            find "$dir" -maxdepth 1 -type f \( -name "*.utx" -o -name "*.uax" -o -name "*.umx" \) 2>/dev/null | while read -r file; do
                local basename=$(basename "$file")
                local name_no_ext="${basename%.*}"
                local lower="${name_no_ext,,}"
                
                # Check patterns (case-insensitive)
                if [[ "$lower" == *"kin"* ]] || \
                   [[ "$lower" == *"ont"* ]] || \
                   [[ "$lower" == *"fx"* ]] || \
                   [[ "$lower" == *"enu"* ]] || \
                   [[ "$lower" == *"oice"* ]] || \
                   [[ "$lower" == *"nnounce"* ]] || \
                   [[ "$lower" == *"ech"* ]] || \
                   [[ "$lower" == *"fem"* ]] || \
                   [[ "$lower" == *"male"* ]]; then
                    echo "$name_no_ext" >> "$pattern_temp"
                fi
            done
        fi
    done
    
    # Count and append to whitelist
    local pattern_count=$(wc -l < "$pattern_temp" 2>/dev/null || echo "0")
    cat "$pattern_temp" >> "$WHITELIST_FILE"
    rm -f "$pattern_temp"
    
    echo "[4/4] Added pattern-based packages ($pattern_count packages)"
    echo "" >> "$WHITELIST_FILE"
    
    # Remove duplicates and sort
    local temp_whitelist="/tmp/whitelist_temp_$$.txt"
    grep -v "^#" "$WHITELIST_FILE" | grep -v "^$" | sort -u > "$temp_whitelist"
    
    # Rebuild with header
    local total_protected=$(wc -l < "$temp_whitelist")
    
    cat > "$WHITELIST_FILE" << EOF
# UT99 Package Whitelist - Generated $(date)
# Total protected packages: $total_protected
# Sources: System, Map Dependencies, ServerPackages, Pattern-based
#
# DO NOT MANUALLY EDIT - regenerate with orphan.sh option 2

EOF
    
    cat "$temp_whitelist" >> "$WHITELIST_FILE"
    rm -f "$temp_whitelist"
    
    echo ""
    echo "==========================================================================="
    log_info "Whitelist generated: $WHITELIST_FILE"
    log_info "Total protected packages: $total_protected"
    echo "==========================================================================="
    echo ""
    
    read -p "Press Enter to continue..."
}

#######################################
# ORPHAN DETECTION & DELETION
#######################################

detect_and_delete_orphans() {
    clear
    echo "==========================================================================="
    echo "                    ORPHAN DETECTION"
    echo "==========================================================================="
    echo ""
    
    if [ ! -f "$WHITELIST_FILE" ]; then
        log_error "Whitelist file not found: $WHITELIST_FILE"
        echo "Please run 'Generate Whitelist' first."
        echo ""
        read -p "Press Enter to continue..."
        return 1
    fi
    
    echo "Scanning for orphaned packages..."
    echo ""
    
    local orphan_count=0
    local total_size=0
    local orphan_list="/tmp/orphan_list_$$.txt"
    
    > "$orphan_list"
    
    # Scan Textures
    echo "Scanning: $TEXTURES_DIR (*.utx)"
    if [ -d "$TEXTURES_DIR" ]; then
        find "$TEXTURES_DIR" -maxdepth 1 -type f -name "*.utx" 2>/dev/null | while read -r file; do
            basename_no_ext=$(basename "$file" .utx)
            
            # Check if in whitelist (case-insensitive)
            if ! grep -Fxq "$basename_no_ext" "$WHITELIST_FILE" && \
               ! grep -iFxq "$basename_no_ext" "$WHITELIST_FILE"; then
                size=$(stat -c%s "$file" 2>/dev/null || echo "0")
                echo "ORPHAN|$file|$size|utx" >> "$orphan_list"
            fi
        done
    fi
    
    # Scan Sounds
    echo "Scanning: $SOUNDS_DIR (*.uax)"
    if [ -d "$SOUNDS_DIR" ]; then
        find "$SOUNDS_DIR" -maxdepth 1 -type f -name "*.uax" 2>/dev/null | while read -r file; do
            basename_no_ext=$(basename "$file" .uax)
            
            if ! grep -Fxq "$basename_no_ext" "$WHITELIST_FILE" && \
               ! grep -iFxq "$basename_no_ext" "$WHITELIST_FILE"; then
                size=$(stat -c%s "$file" 2>/dev/null || echo "0")
                echo "ORPHAN|$file|$size|uax" >> "$orphan_list"
            fi
        done
    fi
    
    # Scan Music
    echo "Scanning: $MUSIC_DIR (*.umx)"
    if [ -d "$MUSIC_DIR" ]; then
        find "$MUSIC_DIR" -maxdepth 1 -type f -name "*.umx" 2>/dev/null | while read -r file; do
            basename_no_ext=$(basename "$file" .umx)
            
            if ! grep -Fxq "$basename_no_ext" "$WHITELIST_FILE" && \
               ! grep -iFxq "$basename_no_ext" "$WHITELIST_FILE"; then
                size=$(stat -c%s "$file" 2>/dev/null || echo "0")
                echo "ORPHAN|$file|$size|umx" >> "$orphan_list"
            fi
        done
    fi
    
    echo ""
    echo "==========================================================================="
    
    orphan_count=$(wc -l < "$orphan_list" 2>/dev/null || echo "0")
    
    if [ "$orphan_count" -eq 0 ]; then
        log_info "No orphaned packages found!"
        echo "All textures, sounds, and music files are protected by whitelist."
        rm -f "$orphan_list"
        echo ""
        read -p "Press Enter to continue..."
        return 0
    fi
    
    total_size=$(awk -F'|' '{sum+=$3} END {print sum}' "$orphan_list")
    size_mb=$(echo "scale=2; $total_size / 1024 / 1024" | bc)
    
    echo "Found $orphan_count orphaned packages"
    echo "Total size: ${size_mb} MB"
    echo ""
    
    # WARNING: Too many orphans (50+)
    if [ "$orphan_count" -gt 50 ]; then
        echo "==========================================================================="
        echo "⚠⚠⚠ WARNING: $orphan_count ORPHANED PACKAGES FOUND! ⚠⚠⚠"
        echo "==========================================================================="
        echo ""
        echo "This is an unusually high number of orphaned packages."
        echo "This typically indicates:"
        echo "  - Incomplete UT installation"
        echo "  - Missing mod/bonuspack files"
        echo "  - Corrupted package structure"
        echo ""
        echo "RECOMMENDATION: Consider a clean server reinstallation instead of cleanup."
        echo ""
        read -p "Return to menu? (Y/n): " return_choice
        if [[ ! "${return_choice,,}" =~ ^n ]]; then
            log_info "Returning to menu - no changes made"
            rm -f "$orphan_list"
            return 0
        fi
        echo ""
        echo "Continuing with orphan cleanup..."
        echo ""
    fi
    
    # Show breakdown
    echo "Breakdown by type:"
    for ext in utx uax umx; do
        count=$(grep "|$ext$" "$orphan_list" 2>/dev/null | wc -l)
        if [ "$count" -gt 0 ]; then
            ext_size=$(grep "|$ext$" "$orphan_list" | awk -F'|' '{sum+=$3} END {print sum}')
            ext_mb=$(echo "scale=2; $ext_size / 1024 / 1024" | bc)
            echo "  .$ext: $count files (${ext_mb} MB)"
        fi
    done
    echo ""
    
    # Show ALL orphaned files (sorted by size)
    echo "All orphaned files (sorted by size):"
    echo "==========================================================================="
    
    local index=1
    sort -t'|' -k3 -rn "$orphan_list" | while IFS='|' read -r tag filepath size ext; do
        filename=$(basename "$filepath")
        size_mb=$(echo "scale=2; $size / 1024 / 1024" | bc)
        printf "%4d) [ ] %-45s %10s MB\n" "$index" "$filename" "$size_mb"
        index=$((index + 1))
    done
    
    echo "==========================================================================="
    echo ""
    
    # Interactive selection
    echo "Options:"
    echo "  a) Delete ALL orphaned packages"
    echo "  s) Select numbers to DELETE (comma-separated, e.g. 1,5,8)"
    echo "  k) Select numbers to KEEP (comma-separated, everything else deleted)"
    echo "  c) Cancel (back to menu)"
    echo ""
    read -p "Choice [a/s/k/c]: " selection_mode
    
    case "${selection_mode,,}" in
        a)
            # Delete all
            echo ""
            echo "⚠ WARNING: This will permanently delete ALL $orphan_count files!"
            echo ""
            read -p "Type 'DELETE ALL' to confirm: " confirm
            
            if [ "$confirm" != "DELETE ALL" ]; then
                log_info "Deletion cancelled"
                rm -f "$orphan_list"
                echo ""
                read -p "Press Enter to continue..."
                return 0
            fi
            
            # Create list of all files to delete
            local files_to_delete="$orphan_list"
            ;;
            
        s)
            # Select to DELETE
            echo ""
            echo "Enter numbers to DELETE (comma-separated, e.g. 1,5,8):"
            read -p "Numbers: " numbers
            
            if [ -z "$numbers" ]; then
                log_info "No selection made - cancelled"
                rm -f "$orphan_list"
                echo ""
                read -p "Press Enter to continue..."
                return 0
            fi
            
            # Parse selection and create filtered list
            local files_to_delete="/tmp/orphan_selected_$$.txt"
            > "$files_to_delete"
            
            IFS=',' read -ra nums <<< "$numbers"
            for num in "${nums[@]}"; do
                num=$(echo "$num" | xargs)
                if [[ "$num" =~ ^[0-9]+$ ]] && [ "$num" -ge 1 ] && [ "$num" -le "$orphan_count" ]; then
                    sort -t'|' -k3 -rn "$orphan_list" | sed -n "${num}p" >> "$files_to_delete"
                fi
            done
            
            local selected_count=$(wc -l < "$files_to_delete")
            if [ "$selected_count" -eq 0 ]; then
                log_warn "No valid files selected"
                rm -f "$orphan_list" "$files_to_delete"
                echo ""
                read -p "Press Enter to continue..."
                return 0
            fi
            
            echo ""
            echo "Selected $selected_count file(s) for deletion"
            echo ""
            read -p "Proceed with deletion? (y/N): " confirm
            
            if [[ ! "${confirm,,}" =~ ^y ]]; then
                log_info "Deletion cancelled"
                rm -f "$orphan_list" "$files_to_delete"
                echo ""
                read -p "Press Enter to continue..."
                return 0
            fi
            ;;
            
        k)
            # Select to KEEP
            echo ""
            echo "Enter numbers to KEEP (comma-separated, e.g. 1,5,8):"
            echo "(Everything else will be DELETED)"
            read -p "Numbers: " numbers
            
            if [ -z "$numbers" ]; then
                # No selection = keep nothing = delete all
                echo ""
                echo "No files selected to keep - will delete ALL"
                echo ""
                read -p "Continue? (y/N): " confirm
                
                if [[ ! "${confirm,,}" =~ ^y ]]; then
                    log_info "Deletion cancelled"
                    rm -f "$orphan_list"
                    echo ""
                    read -p "Press Enter to continue..."
                    return 0
                fi
                
                local files_to_delete="$orphan_list"
            else
                # Parse KEEP selection and create DELETE list (inverse)
                local files_to_delete="/tmp/orphan_selected_$$.txt"
                local keep_list="/tmp/orphan_keep_$$.txt"
                > "$keep_list"
                
                IFS=',' read -ra nums <<< "$numbers"
                for num in "${nums[@]}"; do
                    num=$(echo "$num" | xargs)
                    if [[ "$num" =~ ^[0-9]+$ ]] && [ "$num" -ge 1 ] && [ "$num" -le "$orphan_count" ]; then
                        sort -t'|' -k3 -rn "$orphan_list" | sed -n "${num}p" >> "$keep_list"
                    fi
                done
                
                # Create delete list (all except keep list)
                > "$files_to_delete"
                while IFS='|' read -r tag filepath size ext; do
                    if ! grep -F "$filepath" "$keep_list" &>/dev/null; then
                        echo "$tag|$filepath|$size|$ext" >> "$files_to_delete"
                    fi
                done < <(sort -t'|' -k3 -rn "$orphan_list")
                
                rm -f "$keep_list"
                
                local selected_count=$(wc -l < "$files_to_delete")
                local keep_count=$(( orphan_count - selected_count ))
                
                echo ""
                echo "Keeping: $keep_count file(s)"
                echo "Deleting: $selected_count file(s)"
                echo ""
                read -p "Proceed with deletion? (y/N): " confirm
                
                if [[ ! "${confirm,,}" =~ ^y ]]; then
                    log_info "Deletion cancelled"
                    rm -f "$orphan_list" "$files_to_delete"
                    echo ""
                    read -p "Press Enter to continue..."
                    return 0
                fi
            fi
            ;;
            
        c|*)
            log_info "Cancelled - no changes made"
            rm -f "$orphan_list"
            echo ""
            read -p "Press Enter to continue..."
            return 0
            ;;
    esac
    
    # Proceed with deletion
    echo ""
    echo "Deleting orphaned files..."
    echo ""
    
    local deleted=0
    local failed=0
    
    while IFS='|' read -r tag filepath size ext; do
        filename=$(basename "$filepath")
        echo -ne "Deleting: $filename ... "
        
        if rm -f "$filepath" 2>/dev/null; then
            echo "OK"
            deleted=$((deleted + 1))
        else
            echo "FAILED"
            failed=$((failed + 1))
        fi
    done < "$files_to_delete"
    
    echo ""
    echo "==========================================================================="
    echo "Deleted: $deleted files"
    echo "Failed: $failed files"
    echo "==========================================================================="
    echo ""
    
    rm -f "$orphan_list" "$files_to_delete"
    
    read -p "Press Enter to continue..."
}

#######################################
# WEB REDIRECT ORPHAN CLEANUP
#######################################

cleanup_orphan_uz() {
    clear
    echo "==========================================================================="
    echo "                    ORPHANED .UZ FILE CLEANUP"
    echo "==========================================================================="
    echo ""
    
    if [ ! -d "$UT_REDIRECT" ]; then
        log_warn "UT Redirect directory not found: $UT_REDIRECT"
        echo ""
        read -p "Press Enter to continue..."
        return 0
    fi
    
    echo "Scanning: $UT_REDIRECT"
    echo "UT Server: $UT_BASE_PATH"
    echo ""
    echo "This will find .uz files that have no matching package on the UT server."
    echo ""
    
    declare -a orphans=()
    local checked=0
    
    shopt -s nullglob
    for uz_file in "$UT_REDIRECT"/*.uz; do
        [ -e "$uz_file" ] || continue
        checked=$((checked + 1))
        
        local filename=$(basename "$uz_file")
        
        # Skip exceptions
        if is_exception "${filename%.uz}"; then
            continue
        fi
        
        # Parse filename
        local content_file="${filename%.uz}"
        local raw_ext="${content_file##*.}"
        local extension=$(echo "$raw_ext" | tr '[:upper:]' '[:lower:]')
        local filename_base="${content_file%.*}"
        
        # Normalize prefix for search
        local search_base=$(normalize_prefix "$filename_base")
        local search_file="$search_base.$extension"
        
        # Determine where to check based on extension
        local check_path=""
        case "$extension" in
            unr) check_path="$MAPS_DIR" ;;
            utx) check_path="$TEXTURES_DIR" ;;
            uax) check_path="$SOUNDS_DIR" ;;
            umx) check_path="$MUSIC_DIR" ;;
            u|int|ini) check_path="$SYSTEM_DIR" ;;
            *) continue ;;
        esac
        
        # Check if original file exists (case-insensitive)
        local found=false
        
        if [ -f "$check_path/$search_file" ]; then
            found=true
        else
            # Case-insensitive search
            while IFS= read -r -d '' existing; do
                local existing_lower=$(basename "$existing" | tr '[:upper:]' '[:lower:]')
                local search_lower=$(echo "$search_file" | tr '[:upper:]' '[:lower:]')
                
                if [ "$existing_lower" = "$search_lower" ]; then
                    found=true
                    break
                fi
            done < <(find "$check_path" -maxdepth 1 -xdev -type f -iname "$search_file" -print0 2>/dev/null)
        fi
        
        if [ "$found" = false ]; then
            orphans+=("$uz_file")
        fi
    done
    shopt -u nullglob
    
    log_info "Checked $checked .uz file(s)"
    
    local orphan_count=${#orphans[@]}
    
    if [ "$orphan_count" -eq 0 ]; then
        echo ""
        log_info "No orphaned .uz files found - all redirect files have matching packages!"
        echo ""
        read -p "Press Enter to continue..."
        return 0
    fi
    
    echo ""
    echo "Found $orphan_count orphaned .uz file(s):"
    echo ""
    for orphan in "${orphans[@]}"; do
        local size=$(stat -c%s "$orphan" 2>/dev/null || echo "0")
        printf "  %-50s %10s\n" "$(basename "$orphan")" "$(human_size $size)"
    done
    echo ""
    
    # Calculate total size
    local total_size=0
    for orphan in "${orphans[@]}"; do
        local size=$(stat -c%s "$orphan" 2>/dev/null || echo "0")
        total_size=$((total_size + size))
    done
    
    echo "Total space to reclaim: $(human_size $total_size)"
    echo ""
    
    echo "⚠ WARNING: This will permanently delete these files!"
    echo ""
    read -p "Delete these orphaned .uz files? (y/N): " cleanup_confirm
    
    if [[ ! "${cleanup_confirm,,}" =~ ^y ]]; then
        log_info "Cleanup cancelled"
        echo ""
        read -p "Press Enter to continue..."
        return 0
    fi
    
    echo ""
    echo "Deleting orphaned files..."
    echo ""
    
    local deleted=0
    local failed=0
    
    for uz_file in "${orphans[@]}"; do
        if rm -f "$uz_file" 2>/dev/null; then
            echo "  Deleted: $(basename "$uz_file")"
            deleted=$((deleted + 1))
        else
            log_error "Failed to delete: $(basename "$uz_file")"
            failed=$((failed + 1))
        fi
    done
    
    echo ""
    echo "==========================================================================="
    echo "Result: $deleted deleted, $failed failed"
    echo "==========================================================================="
    echo ""
    
    read -p "Press Enter to continue..."
    
    [ "$failed" -gt 0 ] && return 1
    return 0
}

#######################################
# MAIN MENU
#######################################

show_menu() {
    clear
    echo "==========================================================================="
    echo "              UT PACKAGE ORPHAN SCANNER & CLEANUP v2.0"
    echo "==========================================================================="
    echo ""
    echo "UT Server:   $UT_BASE_PATH"
    echo "UT Redirect: $UT_REDIRECT"
    echo ""
    echo "==========================================================================="
    echo "                              MENU"
    echo "==========================================================================="
    echo ""
    echo "  DEPENDENCY-BASED ORPHAN DETECTION:"
    echo "  1) Extract Map Dependencies (scan all .unr files)"
    echo "  2) Generate Whitelist (create protection list)"
    echo "  3) Detect & Delete Orphaned Packages (.utx/.uax/.umx)"
    echo ""
    echo "  WEB REDIRECT CLEANUP:"
    echo "  4) Cleanup Orphaned .uz Files"
    echo ""
    echo "  B) Back to MapTools"
    echo ""
    echo "==========================================================================="
    echo ""
    
    # Show status
    if [ -f "$DEPENDENCY_FILE" ]; then
        dep_count=$(grep -v "^#" "$DEPENDENCY_FILE" | grep -v "^$" | wc -l)
        echo "Status: Dependencies extracted ($dep_count maps)"
    else
        echo "Status: Dependencies not extracted"
    fi
    
    if [ -f "$WHITELIST_FILE" ]; then
        wl_count=$(grep -v "^#" "$WHITELIST_FILE" | grep -v "^$" | wc -l)
        echo "Status: Whitelist generated ($wl_count packages protected)"
    else
        echo "Status: Whitelist not generated"
    fi
    
    echo ""
    echo "==========================================================================="
    echo ""
}

#######################################
# MAIN LOOP
#######################################

while true; do
    show_menu
    read -p "Choose option [1-4, B]: " choice
    
    case "$choice" in
        1) extract_all_dependencies ;;
        2) generate_whitelist ;;
        3) detect_and_delete_orphans ;;
        4) cleanup_orphan_uz ;;
        [bB])
            clear
            echo "Returning to MapTools menu..."
            sleep 1
            break
            ;;
        *)
            echo "Invalid choice!"
            sleep 1
            ;;
    esac
done

exit 0
