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
# Modernized 2026 with simplified in-place compression
#
###########################################################
# Unreal Tournament Package Compression Utility For Linux #
#                        > uzip <                         #
#	 Author: [es]Rush	 Copyright 2005           #
#                     Unreal Zip 2.0                      #
###########################################################
# v2.0: Simplified - UCC compresses in-place, no copy/move!
###########################################################

set -uo pipefail
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
if [[ -z "${UT_BASE_PATH:-}" ]] || [[ -z "${UPLOAD_DIR:-}" ]]; then
  echo "ERROR: Config missing required variables!"
  echo "Required: UT_BASE_PATH, UPLOAD_DIR"
  echo "Please run Configuration (Option 8 in main menu)"
  exit 1
fi

# CONFIG
UCC_BIN="${UT_BASE_PATH}/System/ucc-bin"
VERBOSE=${VERBOSE:-0}
FORCEAPPEND=${FORCEAPPEND:-0}
IGNOREWARNINGS=${IGNOREWARNINGS:-0}
DRY_RUN=${DRY_RUN:-false}

# Get real user for chown
REAL_USER="${SUDO_USER:-$USER}"
REAL_GROUP=$(id -gn "$REAL_USER" 2>/dev/null || echo "$REAL_USER")

# Logging
log_info() { echo "[INFO] $*"; }
log_warn() { echo "[WARN] $*" >&2; }
log_error() { echo "[ERROR] $*" >&2; }

# Default UT packages (don't compress these)
DEFAULTPACKAGES="BotPack.u Core.u Engine.u Fire.u IpDrv.u IpServer.u UBrowser.u UMenu.u UTBrowser.u UTMenu.u UTServerAdmin.u UWeb.u UWindow.u UnrealI.u UnrealShare.u de.u AS-Frigate.unr AS-Guardia.unr AS-HiSpeed.unr AS-Mazon.unr AS-OceanFloor.unr AS-Overlord.unr AS-Rook.unr CTF-Command.unr CTF-Coret.unr CTF-Dreary.unr CTF-EternalCave.unr CTF-Face.unr CTF-Gauntlet.unr CTF-LavaGiant.unr CTF-Niven.unr CTF-November.unr DM-Barricade.unr DM-Codex.unr DM-Conveyor.unr DM-Curse][.unr DM-Deck16][.unr DM-Fetid.unr DM-Fractal.unr DM-Gothic.unr DM-Grinder.unr DM-HyperBlast.unr DM-KGalleon.unr DM-Liandri.unr DM-Morbias][.unr DM-Morpheus.unr DM-Oblivion.unr DM-Peak.unr DM-Phobos.unr DM-Pressure.unr DM-Pyramid.unr DM-Stalwart.unr DM-StalwartXL.unr DM-Tempest.unr DM-Turbine.unr DM-Zeto.unr DOM-Cinder.unr DOM-Condemned.unr DOM-Cryptic.unr DOM-Gearbolt.unr DOM-Ghardhen.unr DOM-Lament.unr DOM-Leadworks.unr DOM-MetalDream.unr DOM-Olden.unr DOM-Sesmar.unr Entry.unr"

# === ENVIRONMENT CHECKS ===
if [[ ! -x "$UCC_BIN" ]]; then
    log_error "UCC executable not found or not executable: $UCC_BIN"
    exit 1
fi

if [[ ! -d "$UPLOAD_DIR" ]]; then
    log_error "Upload directory does not exist: $UPLOAD_DIR"
    exit 1
fi

if [[ ! -r "$UPLOAD_DIR" ]] || [[ ! -x "$UPLOAD_DIR" ]] || [[ ! -w "$UPLOAD_DIR" ]]; then
    log_error "Insufficient permissions for directory $UPLOAD_DIR (need rwx)"
    exit 1
fi

# === CHECK FILE EXTENSION ===
checkext() {
    local ext="${1##*.}"
    case "$ext" in
        unr|uax|utx|umx|u|int) return 0 ;;
        *) return 1 ;;
    esac
}

# === HELP ===
if [[ "$#" -eq 0 ]] || [[ "${1:-}" == "--help" ]]; then
    echo "Unreal Zip 2.0 - Simplified In-Place Compression"
    echo "Usage: uzip FILE1 FILE2 FILE3 ..."
    echo ""
    echo "Config loaded from: $CONFIG_FILE"
    echo "UT Server:    $UT_BASE_PATH"
    echo "Upload Dir:   $UPLOAD_DIR"
    echo "UCC Binary:   $UCC_BIN"
    [[ "$DRY_RUN" = true ]] && echo "DRY-RUN MODE: Enabled"
    exit 0
fi

# === BUILD FILE LIST ===
wrongext=0
filelist=()
answer=""
append=0

for arg in "$@"; do
    if [[ ! -f "$arg" ]]; then
        log_warn "File not found: $arg"
        continue
    fi
    
    file=$(basename "$arg")
    
    # Check extension
    if ! checkext "$file"; then
        ((wrongext++)) || true
        continue
    fi
    
    # Check if default package
    if echo "$DEFAULTPACKAGES" | grep -qF "$file"; then
        [[ "$IGNOREWARNINGS" == "0" ]] && log_warn "Skipping default UT package: $file"
        continue
    fi
    
    # Check if already compressed
    if [[ -e "${arg}.uz" ]]; then
        [[ "$IGNOREWARNINGS" == "0" ]] && log_info "Already compressed, skipping: $file"
        continue
    fi
    
    # Ask or auto-append
    if [[ "$append" != "1" ]] && [[ "$FORCEAPPEND" == "0" ]]; then
        while [[ "$answer" != "y" ]] && [[ "$answer" != "n" ]] && [[ "$answer" != "A" ]]; do
            read -p "Compress $file ? (y/n/A): " -n 1 answer
            echo ""
            case "$answer" in
                A) append=1; filelist+=("$arg") ;;
                y) filelist+=("$arg") ;;
            esac
        done
        answer=""
    else
        log_info "Package $file will be compressed."
        filelist+=("$arg")
    fi
done

# === WARNINGS ===
if [[ "$wrongext" -eq 1 ]]; then
    log_warn "1 file with invalid extension was ignored."
elif [[ "$wrongext" -gt 0 ]]; then
    log_warn "$wrongext files with invalid extensions were ignored."
fi

if [[ "${#filelist[@]}" -eq 0 ]]; then
    [[ -n "$answer" ]] && log_info "No packages selected for compression." || log_info "No packages found matching your pattern."
    exit 0
fi

# === SHOW SUMMARY AND CONFIRM ===
echo ""
echo "==========================================================================="
echo "                    PACKAGES SELECTED FOR COMPRESSION"
echo "==========================================================================="
echo ""
echo "The following ${#filelist[@]} package(s) will be compressed:"
echo ""

for filepath in "${filelist[@]}"; do
    file=$(basename "$filepath")
    size=$(stat -c%s "$filepath" 2>/dev/null || echo "0")
    size_kb=$((size / 1024))
    echo "  - $file (${size_kb} KB)"
done

echo ""
echo "Output directory: $UPLOAD_DIR"
echo ""
echo "==========================================================================="
echo ""

# Use /dev/tty to ensure read gets user input even when called from script
echo -n "Proceed with compression? (y/N): "
read final_confirm < /dev/tty

if [[ ! "${final_confirm,,}" =~ ^y ]]; then
    echo "Cancelled."
    exit 0
fi

# === DRY-RUN ===
if [[ "$DRY_RUN" = true ]]; then
    log_info "[DRY-RUN] Would compress the following packages:"
    for file in "${filelist[@]}"; do
        echo "  - $file"
    done
    log_info "[DRY-RUN] No actual compression performed"
    exit 0
fi

# === COMPRESSION ===
total=0
succeed=0
file_count=${#filelist[@]}
current=0

echo ""
echo "==========================================================================="
echo "                    COMPRESSION PROGRESS"
echo "==========================================================================="
echo "Total packages to compress: $file_count"
echo ""

for filepath in "${filelist[@]}"; do
    ((current++)) || true
    ((total++)) || true
    
    file=$(basename "$filepath")
    
    echo ""
    echo "───────────────────────────────────────────────────────────────────────────"
    echo "[$current/$file_count] Processing: $file"
    echo "───────────────────────────────────────────────────────────────────────────"
    
    if [[ "$VERBOSE" == "1" ]]; then
        log_info "Compressing: $filepath"
        echo "-----------STARTING UCC---------------"
        "$UCC_BIN" compress "$filepath"
        compression_result=$?
        echo "--------------------------------------"
    else
        printf "  [%3d%%] Compressing %-40s " "$((current * 100 / file_count))" "$file"
        
        # Run UCC compress (in-place compression)
        ratio=$("$UCC_BIN" compress "$filepath" 2>&1 | grep "Compressed" || true)
        compression_result=$?
        
        if [[ "$compression_result" -eq 0 ]] && [[ -n "$ratio" ]]; then
            # Extract ratio from output: "Compressed ... (45%)"
            ratio_pct=$(echo "$ratio" | grep -oP '\(\K[0-9]+%' || echo "?%")
            echo "✓ DONE! ($ratio_pct)"
        else
            echo "✗ FAILED!"
            log_warn "Turning on Verbose mode and repeating compression."
            echo "-----------STARTING UCC---------------"
            "$UCC_BIN" compress "$filepath"
            compression_result=$?
            echo "--------------------------------------"
        fi
    fi
    
    # Check if .uz was created
    uz_file="${filepath}.uz"
    
    if [[ -f "$uz_file" ]]; then
        # Fix ownership (UCC runs as root, files should belong to real user)
        chown "$REAL_USER:$REAL_GROUP" "$uz_file" 2>/dev/null || true
        chmod 644 "$uz_file" 2>/dev/null || true
        
        ((succeed++)) || true
        log_info "✓ Created: $(basename "$uz_file")"
    else
        log_error "✗ File not created: $(basename "$uz_file")"
        [[ "$compression_result" -eq 0 ]] && log_warn "UCC exit code was 0 but no .uz file found"
    fi
done

echo ""
echo "==========================================================================="
echo "                    COMPRESSION COMPLETE"
echo "==========================================================================="
echo ""
log_info "Results: $succeed/$total packages successfully compressed!"
if [[ "$total" -gt 0 ]]; then
    log_info "Success rate: $((succeed * 100 / total))%"
fi
log_info "Compressed files in: $UPLOAD_DIR"
echo "==========================================================================="
echo ""

if [[ "$succeed" -gt 0 ]]; then
    return 0
else
    return 1
fi

