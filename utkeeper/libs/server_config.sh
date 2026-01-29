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
# UT Server & Web Config Editor v2.5

set -euo pipefail
IFS=$'\n\t'

# === PATHS ===
SCRIPT_PATH="$(realpath "$0")"
SCRIPT_DIR="$(dirname "$SCRIPT_PATH")"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
CONFIG_FILE="${PROJECT_ROOT}/.config"
UPLOAD_DIR="${PROJECT_ROOT}/upload"

# === COLORS ===
RED='\e[31m'
GREEN='\e[32m'
YELLOW='\e[33m'
RESET='\e[0m'

# === AUTO-DETECTION FUNCTIONS ===

# Find UT99 installation
find_ut_base() {
    local paths=(
        "/opt/utserver"
        "/opt/ut99"
        "/home/utserver/utserver"
        "/usr/local/games/ut99"
        "/srv/utserver"
    )
    
    # Check predefined paths first
    for path in "${paths[@]}"; do
        if [[ -d "$path/System" ]]; then
            if [[ -f "$path/System/UnrealTournament.ini" ]] || \
               [[ -f "$path/System/ut.ini" ]] || \
               [[ -f "$path/System/ucc-bin" ]]; then
                echo "$path"
                return 0
            fi
        fi
    done
    
    # Search filesystem
    local found=$(find /opt /home /srv -maxdepth 4 -type d -name "System" 2>/dev/null | while read -r sysdir; do
        local parent="$(dirname "$sysdir")"
        if [[ -d "$parent/Maps" ]] && [[ -d "$parent/Textures" ]]; then
            if [[ -f "$sysdir/ucc-bin" ]] || [[ -f "$sysdir/UnrealTournament.ini" ]]; then
                echo "$parent"
                return 0
            fi
        fi
    done | head -1)
    
    echo "$found"
}

# Detect web server root
detect_webserver() {
    local web_root="/var/www/html"
    
    # Try Apache
    if command -v apache2ctl &>/dev/null; then
        local detected=$(apache2ctl -t -D DUMP_VHOSTS 2>/dev/null | grep -oP 'DocumentRoot\s+\K\S+' | head -1)
        # Keep it simple - default to /var/www/html for Apache
        if [[ -n "$detected" ]] && [[ -d "$detected" ]]; then
            if [[ "$detected" == "/var/www"* ]]; then
                web_root="/var/www/html"
            else
                web_root="$detected"
            fi
        fi
    # Try Nginx
    elif command -v nginx &>/dev/null; then
        local detected=$(nginx -T 2>/dev/null | grep -oP '^\s*root\s+\K[^;]+' | head -1)
        if [[ -n "$detected" ]] && [[ -d "$detected" ]]; then
            web_root="$detected"
        fi
    fi
    
    echo "$web_root"
}

# Detect system services (auto-detect, stored in config, NO user prompts)
detect_services() {
    local ut_svc="utserver.service"
    local web_svc="apache2.service"
    
    # UT Service
    if systemctl list-unit-files 2>/dev/null | grep -q "^utserver.service"; then
        ut_svc="utserver.service"
    elif systemctl list-unit-files 2>/dev/null | grep -q "^ut-server.service"; then
        ut_svc="ut-server.service"
    elif systemctl list-unit-files 2>/dev/null | grep -q "^ut.service"; then
        ut_svc="ut.service"
    fi
    
    # Web Service
    if systemctl list-unit-files 2>/dev/null | grep -q "^apache2.service"; then
        web_svc="apache2.service"
    elif systemctl list-unit-files 2>/dev/null | grep -q "^httpd.service"; then
        web_svc="httpd.service"
    elif systemctl list-unit-files 2>/dev/null | grep -q "^nginx.service"; then
        web_svc="nginx.service"
    fi
    
    echo "$ut_svc:$web_svc"
}

# Auto-detect file owners
auto_detect_owners() {
    local ut_path="$1"
    local web_path="$2"
    
    local ut_user="utserver"
    local ut_group="utserver"
    local web_user="www-data"
    local web_group="www-data"
    
    if [[ -d "$ut_path" ]]; then
        ut_user=$(stat -c "%U" "$ut_path" 2>/dev/null || echo "utserver")
        ut_group=$(stat -c "%G" "$ut_path" 2>/dev/null || echo "utserver")
    fi
    
    if [[ -d "$web_path" ]]; then
        web_user=$(stat -c "%U" "$web_path" 2>/dev/null || echo "www-data")
        web_group=$(stat -c "%G" "$web_path" 2>/dev/null || echo "www-data")
    fi
    
    echo "$ut_user:$ut_group:$web_user:$web_group"
}

# Find UT redirect directory (scan for .uz files up to depth 5)
find_ut_redirect() {
    local web_root="$1"
    
    [[ ! -d "$web_root" ]] && echo "" && return
    
    # Search for .uz files and return their directory
    local found=$(find "$web_root" -maxdepth 5 -name "*.uz" -printf '%h\n' 2>/dev/null | sort -u | head -1)
    
    if [[ -n "$found" ]]; then
        echo "$found"
        return 0
    fi
    
    # Fallback: Check common paths
    local paths=(
        "$web_root/ut"
        "$web_root/redirect"
        "$web_root/ut99"
    )
    
    for path in "${paths[@]}"; do
        if [[ -d "$path" ]]; then
            echo "$path"
            return 0
        fi
    done
    
    echo ""
}

# === VALIDATION FUNCTIONS ===

validate_user() {
    local user="$1"
    
    if id "$user" &>/dev/null; then
        echo -e "${GREEN}✓${RESET} User '$user' exists"
        return 0
    else
        echo -e "${YELLOW}⚠${RESET} User '$user' does not exist"
        read -p "  Continue anyway? (y/N): " confirm
        if [[ "${confirm,,}" =~ ^y ]]; then
            echo -e "${YELLOW}!${RESET} User '$user' saved (create later: sudo useradd $user)"
            return 0
        fi
        return 1
    fi
}

validate_group() {
    local group="$1"
    
    if getent group "$group" &>/dev/null; then
        echo -e "${GREEN}✓${RESET} Group '$group' exists"
        return 0
    else
        echo -e "${YELLOW}⚠${RESET} Group '$group' does not exist"
        read -p "  Continue anyway? (y/N): " confirm
        if [[ "${confirm,,}" =~ ^y ]]; then
            echo -e "${YELLOW}!${RESET} Group '$group' saved (create later: sudo groupadd $group)"
            return 0
        fi
        return 1
    fi
}

validate_path() {
    local path="$1"
    local description="$2"
    
    if [[ -d "$path" ]]; then
        echo -e "${GREEN}✓${RESET} $description exists"
        return 0
    else
        echo -e "${YELLOW}⚠${RESET} $description does not exist: $path"
        read -p "  Continue anyway? (y/N): " confirm
        [[ "${confirm,,}" =~ ^y ]] && return 0
        return 1
    fi
}

verify_ut_installation() {
    local path="$1"
    
    [[ ! -d "$path" ]] && return 1
    
    local has_system=false
    local has_maps=false
    local has_config=false
    
    [[ -d "$path/System" ]] && has_system=true
    [[ -d "$path/Maps" ]] && has_maps=true
    [[ -f "$path/System/UnrealTournament.ini" ]] || [[ -f "$path/System/ut.ini" ]] && has_config=true
    
    if $has_system && ($has_maps || $has_config); then
        return 0
    fi
    return 1
}

# === LOAD/SAVE CONFIG ===

load_config() {
    if [[ -f "$CONFIG_FILE" ]]; then
        source "$CONFIG_FILE" 2>/dev/null
        return 0
    fi
    return 1
}

save_config() {
    cat > "$CONFIG_FILE" << EOF
# UTKeeper99 Configuration File
# Last updated: $(date)

# UT Server Settings
UT_BASE_PATH="$UT_BASE_PATH"
UT_USER="$UT_USER"
UT_GROUP="$UT_GROUP"
LOG_PATH="$LOG_PATH"
UT_SVC="$UT_SVC"

# Web Server Settings
UT_REDIRECT="$UT_REDIRECT"
WEB_ROOT="$WEB_ROOT"
WEB_USER="$WEB_USER"
WEB_GROUP="$WEB_GROUP"
AP_SVC="$AP_SVC"

# UTKeeper Settings
UPLOAD_DIR="$UPLOAD_DIR"
PROJECT_ROOT="$PROJECT_ROOT"
EOF
    
    chmod 644 "$CONFIG_FILE"
    echo ""
    echo -e "${GREEN}✓${RESET} Configuration saved to: $CONFIG_FILE"
}

# === MAIN PROGRAM ===

clear
echo "==========================================================================="
echo "               UTKEEPER99 - CONFIGURATION EDITOR v2.5"
echo "==========================================================================="
echo ""

# === SYSTEM INFO ===
echo "System Information:"
echo "  Running as:    $(whoami)"
echo "  Script dir:    $SCRIPT_DIR"
echo "  Project root:  $PROJECT_ROOT"
echo ""

# === AUTO-DETECTION ===
echo "Running auto-detection..."
echo ""

detected_ut=$(find_ut_base)
detected_web=$(detect_webserver)
detected_services=$(detect_services)
IFS=':' read -r detected_ut_svc detected_ap_svc <<< "$detected_services"

echo "==========================================================================="
echo "                         AUTO-DETECTED VALUES"
echo "==========================================================================="
echo ""

if [[ -n "$detected_ut" ]]; then
    echo -e "${GREEN}✓${RESET} UT Server:    $detected_ut"
else
    echo -e "${YELLOW}⚠${RESET} UT Server:    Not found (will prompt)"
fi

echo -e "${GREEN}✓${RESET} Web Root:     $detected_web"

# Detect redirect
detected_redirect=$(find_ut_redirect "$detected_web")
if [[ -n "$detected_redirect" ]]; then
    echo -e "${GREEN}✓${RESET} UT Redirect:  $detected_redirect (found .uz files)"
else
    echo -e "${YELLOW}⚠${RESET} UT Redirect:  Not found (will use default)"
fi

echo ""
echo "==========================================================================="
echo ""

# === LOAD EXISTING OR USE DETECTED ===
if load_config; then
    echo -e "${GREEN}✓${RESET} Loaded existing configuration"
    echo ""
    echo "Current values will be shown in [brackets]."
    echo "Press Enter to keep current value, or type new value."
else
    echo "No existing configuration found."
    echo "Using auto-detected values as defaults."
    
    UT_BASE_PATH="${detected_ut:-/opt/utserver}"
    WEB_ROOT="$detected_web"
    UT_SVC="$detected_ut_svc"
    AP_SVC="$detected_ap_svc"
    
    # Detect owners
    owners=$(auto_detect_owners "$UT_BASE_PATH" "$WEB_ROOT")
    IFS=':' read -r UT_USER UT_GROUP WEB_USER WEB_GROUP <<< "$owners"
    
    # Set redirect
    if [[ -n "$detected_redirect" ]]; then
        UT_REDIRECT="$detected_redirect"
    else
        UT_REDIRECT="$WEB_ROOT/ut"
    fi
    
    # Set log path (default: UT_BASE_PATH/Logs)
    LOG_PATH="$UT_BASE_PATH/Logs"
    
    UPLOAD_DIR="$PROJECT_ROOT/upload"
fi

echo ""
read -p "Press Enter to start configuration..."
echo ""

# === INTERACTIVE CONFIG ===

echo "==========================================================================="
echo "                          UT SERVER SETTINGS"
echo "==========================================================================="
echo ""

# UT Base Path
while true; do
    echo "[1/7] UT Server Installation Path"
    read -p "  Path [$UT_BASE_PATH]: " input
    UT_BASE_PATH="${input:-$UT_BASE_PATH}"
    
    if verify_ut_installation "$UT_BASE_PATH"; then
        echo -e "${GREEN}✓${RESET} Valid UT99 installation detected"
        break
    elif [[ -d "$UT_BASE_PATH" ]]; then
        echo -e "${YELLOW}⚠${RESET} Directory exists but may not be a complete UT installation"
        read -p "  Continue anyway? (y/N): " confirm
        [[ "${confirm,,}" =~ ^y ]] && break
    else
        if validate_path "$UT_BASE_PATH" "UT Base Path"; then
            break
        fi
    fi
done
echo ""

# UT User
echo "[2/7] UT Server Owner (User)"
while true; do
    read -p "  User [$UT_USER]: " input
    UT_USER="${input:-$UT_USER}"
    validate_user "$UT_USER" && break
done
echo ""

# UT Group
echo "[3/7] UT Server Owner (Group)"
while true; do
    read -p "  Group [$UT_GROUP]: " input
    UT_GROUP="${input:-$UT_GROUP}"
    validate_group "$UT_GROUP" && break
done
echo ""

# Log Path
echo "[4/7] UT Server Log Directory"
echo "  (Default: UT_BASE_PATH/Logs for Wordstat logs/tmps)"
LOG_PATH="${LOG_PATH:-$UT_BASE_PATH/Logs}"
read -p "  Log Path [$LOG_PATH]: " input
LOG_PATH="${input:-$LOG_PATH}"
echo ""

echo "==========================================================================="
echo "                          WEB SERVER SETTINGS"
echo "==========================================================================="
echo ""

# Web Root
echo "[5/7] Web Server Document Root"
while true; do
    read -p "  Path [$WEB_ROOT]: " input
    WEB_ROOT="${input:-$WEB_ROOT}"
    validate_path "$WEB_ROOT" "Web Root" && break
done
echo ""

# UT Redirect
echo "[6/7] UT Redirect Directory (for .uz files)"
while true; do
    read -p "  Path [$UT_REDIRECT]: " input
    UT_REDIRECT="${input:-$UT_REDIRECT}"
    
    if [[ -d "$UT_REDIRECT" ]]; then
        echo -e "${GREEN}✓${RESET} Directory exists"
        break
    else
        echo -e "${YELLOW}⚠${RESET} Directory does not exist: $UT_REDIRECT"
        read -p "  Create now? (Y/n): " confirm
        if [[ ! "${confirm,,}" =~ ^n ]]; then
            if mkdir -p "$UT_REDIRECT" 2>/dev/null; then
                echo -e "${GREEN}✓${RESET} Directory created"
                break
            else
                echo -e "${RED}✗${RESET} Failed to create directory"
            fi
        else
            read -p "  Save path anyway? (y/N): " confirm2
            [[ "${confirm2,,}" =~ ^y ]] && break
        fi
    fi
done
echo ""

# Web User & Group
echo "[7/7] Web Server Owner"
while true; do
    read -p "  User [$WEB_USER]: " input
    WEB_USER="${input:-$WEB_USER}"
    validate_user "$WEB_USER" && break
done

while true; do
    read -p "  Group [$WEB_GROUP]: " input
    WEB_GROUP="${input:-$WEB_GROUP}"
    validate_group "$WEB_GROUP" && break
done
echo ""

# === FINAL SUMMARY ===
clear
echo "==========================================================================="
echo "                       CONFIGURATION SUMMARY"
echo "==========================================================================="
echo ""
echo "UT SERVER:"
echo "  Installation:  $UT_BASE_PATH"
echo "  Owner:         $UT_USER:$UT_GROUP"
echo "  Logs:          $LOG_PATH"
echo "  Service:       $UT_SVC (auto-detected)"
echo ""
echo "WEB SERVER:"
echo "  Document Root: $WEB_ROOT"
echo "  UT Redirect:   $UT_REDIRECT"
echo "  Owner:         $WEB_USER:$WEB_GROUP"
echo "  Service:       $AP_SVC (auto-detected)"
echo ""
echo "UTKEEPER:"
echo "  Project Root:  $PROJECT_ROOT"
echo "  Upload Dir:    $UPLOAD_DIR"
echo "  Config File:   $CONFIG_FILE"
echo ""
echo "==========================================================================="
echo ""

read -p "Save this configuration? (Y/n): " confirm

if [[ ! "${confirm,,}" =~ ^n ]]; then
    save_config
    
    # Ensure upload directory structure exists
    if [[ ! -d "$UPLOAD_DIR" ]]; then
        mkdir -p "$UPLOAD_DIR/installed"
        chmod 755 "$UPLOAD_DIR"
        echo -e "${GREEN}✓${RESET} Upload directory created: $UPLOAD_DIR"
    fi
    
    if [[ ! -d "$UPLOAD_DIR/installed" ]]; then
        mkdir -p "$UPLOAD_DIR/installed"
        chmod 755 "$UPLOAD_DIR/installed"
        echo -e "${GREEN}✓${RESET} Installed directory created: $UPLOAD_DIR/installed"
    fi
    
    echo ""
    echo "==========================================================================="
    echo -e "${GREEN}                    CONFIGURATION COMPLETE!${RESET}"
    echo "==========================================================================="
    echo ""
    echo "All UTKeeper99 scripts will now use these settings."
else
    echo ""
    echo -e "${YELLOW}Configuration cancelled - no changes saved${RESET}"
fi

echo ""
read -p "Press Enter to return to main menu..."