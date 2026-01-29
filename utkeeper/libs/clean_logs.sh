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
# Clean System & Server Logs v2.2

set -euo pipefail
IFS=$'\n\t'

# === ROOT CHECK ===
if [[ $EUID -ne 0 ]]; then
  exec sudo -E bash "$0" "$@"
fi

# === PATHS ===
if [[ -z "${PROJECT_ROOT:-}" ]]; then
  echo "ERROR: PROJECT_ROOT not set!"
  echo "This script must be called from utkeeper.sh"
  exit 1
fi

CONFIG_FILE="${PROJECT_ROOT}/.config"

# === COLORS ===
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

clear
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  Clean System & Server Logs v2.2${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

# === LOAD CONFIG ===
if [[ ! -f "$CONFIG_FILE" ]]; then
    echo -e "${RED}ERROR: Config file not found: $CONFIG_FILE${NC}"
    echo "Please run Configuration (Option 8 in main menu)"
    exit 1
fi

source "$CONFIG_FILE"

# Validate UT_BASE_PATH (optional for this script)
if [[ -z "${UT_BASE_PATH:-}" ]]; then
    echo -e "${YELLOW}[!]${NC} UT_BASE_PATH not set in config"
    echo -e "${YELLOW}[!]${NC} UT Server logs will be skipped"
    UT_BASE_PATH=""
else
    echo -e "${GREEN}[OK]${NC} UT Base Path: $UT_BASE_PATH"
fi

# Use LOG_PATH from config if available
LOG_PATH="${LOG_PATH:-}"
[[ -z "$LOG_PATH" ]] && [[ -n "$UT_BASE_PATH" ]] && LOG_PATH="$UT_BASE_PATH/Logs"

echo ""

# === DETECT WEBSERVER ===
WEBSERVER_TYPE="none"
WEBSERVER_LOG_DIR=""

if [[ -x "$(command -v apache2ctl)" ]] || [[ -x "$(command -v apache2)" ]]; then
    WEBSERVER_TYPE="apache"
    WEBSERVER_LOG_DIR="/var/log/apache2"
elif [[ -x "$(command -v httpd)" ]]; then
    WEBSERVER_TYPE="httpd"
    WEBSERVER_LOG_DIR="/var/log/httpd"
elif [[ -x "$(command -v nginx)" ]]; then
    WEBSERVER_TYPE="nginx"
    WEBSERVER_LOG_DIR="/var/log/nginx"
fi

echo "Detected Webserver: ${WEBSERVER_TYPE}"
echo ""

# === CONFIRMATION ===
echo -e "${YELLOW}WARNING: This will clear all log files!${NC}"
echo ""
echo "This will affect:"
echo "  - System journal (journalctl)"
echo "  - Fail2Ban logs"
if [[ "$WEBSERVER_TYPE" != "none" ]]; then
    echo "  - ${WEBSERVER_TYPE^} logs (access & error)"
fi
if [[ -n "$UT_BASE_PATH" ]] && [[ -d "$UT_BASE_PATH" ]]; then
    echo "  - UT Server logs"
    [[ -n "$LOG_PATH" ]] && [[ -d "$LOG_PATH" ]] && echo "  - UT Logs directory: $LOG_PATH"
fi
echo ""
read -p "Are you sure you want to continue? (yes/no): " confirm

if [[ "${confirm,,}" != "yes" ]]; then
    echo "Cancelled."
    exit 0
fi

echo ""

# === SAFE TRUNCATE FUNCTION ===
truncate_log() {
    local logfile="$1"
    local description="${2:-$logfile}"
    
    if [[ -f "$logfile" ]]; then
        if truncate -s 0 "$logfile" 2>/dev/null; then
            echo -e "  ${GREEN}[OK]${NC} ${description} cleared"
            return 0
        else
            echo -e "  ${YELLOW}[!]${NC} ${description} - permission denied"
            return 1
        fi
    else
        echo -e "  ${YELLOW}[-]${NC} ${description} - not found (skipped)"
        return 0
    fi
}

# === REMOVE FILES IN DIRECTORY ===
clean_directory() {
    local dir="$1"
    local pattern="${2:-*.*}"
    local description="${3:-$dir}"
    
    if [[ -d "$dir" ]]; then
        local count=$(find "$dir" -maxdepth 1 -name "$pattern" -type f 2>/dev/null | wc -l)
        if [[ $count -gt 0 ]]; then
            rm -f "$dir"/$pattern 2>/dev/null && \
                echo -e "  ${GREEN}[OK]${NC} ${description} - removed $count file(s)" || \
                echo -e "  ${YELLOW}[!]${NC} ${description} - permission denied"
        else
            echo -e "  ${YELLOW}[-]${NC} ${description} - no files found"
        fi
    else
        echo -e "  ${YELLOW}[-]${NC} ${description} - directory not found"
    fi
}

# ========================================
# === CLEANING PROCESS ===
# ========================================

# === 1. SYSTEM JOURNAL ===
echo -e "${GREEN}=== System Journal ===${NC}"
if command -v journalctl >/dev/null 2>&1; then
    JOURNAL_SIZE_BEFORE=$(journalctl --disk-usage 2>/dev/null | grep -oP '\d+(\.\d+)?[KMGT]?' | head -1 || echo 'unknown')
    echo "Current size: ${JOURNAL_SIZE_BEFORE}"
    
    if journalctl --vacuum-size=1M --vacuum-time=1s >/dev/null 2>&1; then
        JOURNAL_SIZE_AFTER=$(journalctl --disk-usage 2>/dev/null | grep -oP '\d+(\.\d+)?[KMGT]?' | head -1 || echo 'unknown')
        echo -e "  ${GREEN}[OK]${NC} Journal vacuumed (${JOURNAL_SIZE_BEFORE} -> ${JOURNAL_SIZE_AFTER})"
    else
        echo -e "  ${YELLOW}[!]${NC} Journal vacuum failed"
    fi
else
    echo -e "  ${YELLOW}[-]${NC} journalctl not available"
fi
echo ""

# === 2. FAIL2BAN LOGS ===
echo -e "${GREEN}=== Fail2Ban Logs ===${NC}"
truncate_log "/var/log/fail2ban.log" "fail2ban.log"
echo ""

# === 3. WEBSERVER LOGS ===
if [[ "$WEBSERVER_TYPE" != "none" ]]; then
    echo -e "${GREEN}=== ${WEBSERVER_TYPE^} Logs ===${NC}"
    
    # Main logs
    truncate_log "${WEBSERVER_LOG_DIR}/access.log" "${WEBSERVER_TYPE} access.log"
    truncate_log "${WEBSERVER_LOG_DIR}/error.log" "${WEBSERVER_TYPE} error.log"
    
    # Apache specific
    if [[ "$WEBSERVER_TYPE" == "apache" ]]; then
        truncate_log "${WEBSERVER_LOG_DIR}/access_log" "apache access_log"
        truncate_log "${WEBSERVER_LOG_DIR}/error_log" "apache error_log"
        truncate_log "${WEBSERVER_LOG_DIR}/other_vhosts_access.log" "apache other vhosts"
    fi
    
    # HTTPD specific (RHEL/CentOS)
    if [[ "$WEBSERVER_TYPE" == "httpd" ]]; then
        truncate_log "${WEBSERVER_LOG_DIR}/access_log" "httpd access_log"
        truncate_log "${WEBSERVER_LOG_DIR}/error_log" "httpd error_log"
    fi
    
    # Nginx specific - rotated logs
    if [[ "$WEBSERVER_TYPE" == "nginx" ]]; then
        clean_directory "${WEBSERVER_LOG_DIR}" "*.log.[0-9]*" "nginx rotated logs"
        clean_directory "${WEBSERVER_LOG_DIR}" "*.log.gz" "nginx compressed logs"
    fi
else
    echo -e "${YELLOW}=== Webserver Logs ===${NC}"
    echo -e "  ${YELLOW}[-]${NC} No webserver detected"
fi
echo ""

# === 4. UT SERVER LOGS ===
echo -e "${GREEN}=== Unreal Tournament Logs ===${NC}"
if [[ -n "$UT_BASE_PATH" ]] && [[ -d "$UT_BASE_PATH" ]]; then
    # Main log
    truncate_log "${UT_BASE_PATH}/System/ut.log" "UT Server Log"
    
    # Additional logs
    truncate_log "${UT_BASE_PATH}/System/ucc.log" "UCC Log"
    truncate_log "${UT_BASE_PATH}/System/Launch.log" "Launch Log"
    truncate_log "${UT_BASE_PATH}/System/Server.log" "Server Log"
    truncate_log "${UT_BASE_PATH}/System/UnrealTournament.log" "UnrealTournament.log"
    
    # Logs directory from config
    if [[ -n "$LOG_PATH" ]] && [[ -d "$LOG_PATH" ]]; then
        clean_directory "$LOG_PATH" "*.*" "UT Logs directory ($LOG_PATH)"
    fi
    
    # Rotated logs
    clean_directory "${UT_BASE_PATH}/System" "*.log.*" "UT rotated logs"
    clean_directory "${UT_BASE_PATH}/System" "*.log.bak" "UT backup logs"
elif [[ -z "$UT_BASE_PATH" ]]; then
    echo -e "  ${YELLOW}[!]${NC} UT Base Path not configured"
    echo -e "  ${YELLOW}[!]${NC} Run Configuration (Option 8 in main menu)"
else
    echo -e "  ${YELLOW}[!]${NC} UT Base Path not found: $UT_BASE_PATH"
fi
echo ""

# ========================================
# === FINAL STATUS ===
# ========================================

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  Cleaning Summary${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

# Journal status
if command -v journalctl >/dev/null 2>&1; then
    JOURNAL_FINAL=$(journalctl --disk-usage 2>/dev/null | grep -oP '\d+(\.\d+)?[KMGT]?' | head -1 || echo 'unknown')
    echo "Journal size: ${JOURNAL_FINAL}"
fi

# Fail2Ban status
if [[ -f "/var/log/fail2ban.log" ]]; then
    FAIL2BAN_LINES=$(wc -l < /var/log/fail2ban.log 2>/dev/null || echo "0")
    echo "Fail2Ban log: ${FAIL2BAN_LINES} lines"
fi

# Webserver status
if [[ "$WEBSERVER_TYPE" != "none" ]]; then
    if [[ -f "${WEBSERVER_LOG_DIR}/access.log" ]]; then
        ACCESS_LINES=$(wc -l < "${WEBSERVER_LOG_DIR}/access.log" 2>/dev/null || echo "0")
        echo "${WEBSERVER_TYPE^} access.log: ${ACCESS_LINES} lines"
    fi
    if [[ -f "${WEBSERVER_LOG_DIR}/error.log" ]]; then
        ERROR_LINES=$(wc -l < "${WEBSERVER_LOG_DIR}/error.log" 2>/dev/null || echo "0")
        echo "${WEBSERVER_TYPE^} error.log: ${ERROR_LINES} lines"
        if [[ $ERROR_LINES -gt 0 ]]; then
            echo "  Last error entry:"
            tail -n 1 "${WEBSERVER_LOG_DIR}/error.log" 2>/dev/null | sed 's/^/  /' || true
        fi
    fi
fi

# UT Server status
if [[ -n "$UT_BASE_PATH" ]] && [[ -f "${UT_BASE_PATH}/System/ut.log" ]]; then
    UT_LINES=$(wc -l < "${UT_BASE_PATH}/System/ut.log" 2>/dev/null || echo "0")
    echo "UT Server log: ${UT_LINES} lines"
    if [[ $UT_LINES -gt 0 ]]; then
        echo "  Last log entry:"
        tail -n 1 "${UT_BASE_PATH}/System/ut.log" 2>/dev/null | sed 's/^/  /' || true
    fi
fi

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  All logs cleaned successfully!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
read -p "Press Enter to return to menu..."

exit 0