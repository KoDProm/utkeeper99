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
# System Logs Overview - Shows filtered logs from all services

set -euo pipefail

# Auto-elevate to root if needed
if [ "$EUID" -ne 0 ]; then
  exec sudo -E bash "$0" "$@"
fi

# Load configuration
# PROJECT_ROOT was exported by utkeeper.sh
if [[ -z "${PROJECT_ROOT:-}" ]]; then
  echo "ERROR: PROJECT_ROOT not set!"
  echo "This script must be called from utkeeper.sh"
  exit 1
fi

CONFIG_FILE="${PROJECT_ROOT}/.config"

# Initialize variables with defaults
UT_LOG_FILE=""
APACHE_ACCESS_LOG=""
APACHE_ERROR_LOG=""

# Load config if available
if [[ -f "$CONFIG_FILE" ]]; then
  source "$CONFIG_FILE" 2>/dev/null || true
  
  if [[ -n "${UT_BASE_PATH:-}" ]]; then
    UT_LOG_FILE="${UT_BASE_PATH}/System/ut.log"
  fi
fi

# Detect Apache/httpd log paths
if [ -f /var/log/apache2/access.log ]; then
  APACHE_ACCESS_LOG="/var/log/apache2/access.log"
  APACHE_ERROR_LOG="/var/log/apache2/error.log"
elif [ -f /var/log/httpd/access_log ]; then
  APACHE_ACCESS_LOG="/var/log/httpd/access_log"
  APACHE_ERROR_LOG="/var/log/httpd/error_log"
fi

clear
echo "==========================================================================="
echo "                    SYSTEM LOGS OVERVIEW"
echo "==========================================================================="
echo ""

# === SYSTEM & KERNEL LOGS ===
echo "=== [System/Core] (last 100 entries) ===================================="
if journalctl -n 100 --no-pager 2>/dev/null; then
  :
else
  echo "journalctl not available"
fi
echo ""

# === FAIL2BAN LOGS ===
echo "=== [Fail2Ban] (Ban/Failed/Rejected - last 100) ========================="
if [ -f /var/log/fail2ban.log ]; then
  if grep --color=always -iE 'Ban|Failed|Rejected|$' /var/log/fail2ban.log 2>/dev/null | tail -n 100; then
    :
  else
    echo "No Ban/Failed/Rejected entries found"
  fi
else
  echo "Fail2ban log not found"
fi
echo ""

# === AUTHENTICATION LOGS ===
echo "=== [Authentication] (last 100 entries) =================================="
if journalctl SYSLOG_FACILITY=10 -n 100 --no-pager 2>/dev/null; then
  :
else
  echo "Authentication log not available"
fi
echo ""

# === APACHE ACCESS LOGS ===
echo "=== [Web Server Access] (Errors: 404/500/403 - last 100) ================"
if [ -n "$APACHE_ACCESS_LOG" ] && [ -f "$APACHE_ACCESS_LOG" ]; then
  if grep --color=always -iE '404|500|403|Forbidden|$' "$APACHE_ACCESS_LOG" 2>/dev/null | tail -n 100; then
    :
  else
    echo "No errors found in access log"
  fi
else
  echo "Web server access log not found"
fi
echo ""

# === APACHE ERROR LOGS ===
echo "=== [Web Server Error] (Errors/Warnings - last 100) ====================="
if [ -n "$APACHE_ERROR_LOG" ] && [ -f "$APACHE_ERROR_LOG" ]; then
  if grep --color=always -iE 'error|warn|fail|AH[0-9]{4}' "$APACHE_ERROR_LOG" 2>/dev/null | tail -n 100; then
    :
  else
    echo "No errors/warnings found"
  fi
else
  echo "Web server error log not found"
fi
echo ""

# === UT SERVER LOGS ===
echo "=== [UT Server] (Warnings/Errors - last 1200) ==========================="
if [ -n "$UT_LOG_FILE" ] && [ -f "$UT_LOG_FILE" ]; then
  if grep --color=always -iE "Warning|Error|Critical|NetComeUnreliable|$" "$UT_LOG_FILE" 2>/dev/null | tail -n 1200; then
    :
  else
    echo "No warnings/errors found in UT log"
  fi
else
  if [ -z "$UT_LOG_FILE" ]; then
    echo "UT Server path not configured - run Configuration (Option 8 in main menu)"
  else
    echo "UT Server log not found: $UT_LOG_FILE"
  fi
fi
echo ""

echo "==========================================================================="
echo "                    END OF LOG OVERVIEW"
echo "==========================================================================="
echo ""
echo "Press ENTER to return to menu"
read -r

exit 0