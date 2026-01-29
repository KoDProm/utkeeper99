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
# System Live Log Monitor

set -euo pipefail

# Check for root privileges
if [ "$EUID" -ne 0 ]; then 
  echo "ERROR: This script requires root privileges"
  echo "Please run with sudo"
  exit 1
fi

# PROJECT_ROOT was exported by utkeeper.sh
# We don't need config for this script, but check it's called correctly
if [[ -z "${PROJECT_ROOT:-}" ]]; then
  echo "WARNING: PROJECT_ROOT not set"
  echo "This script should be called from utkeeper.sh"
  echo "Continuing anyway..."
fi

# Detect Apache/httpd log paths
APACHE_ACCESS_LOG=""
APACHE_ERROR_LOG=""

if [ -f /var/log/apache2/access.log ]; then
  APACHE_ACCESS_LOG="/var/log/apache2/access.log"
  APACHE_ERROR_LOG="/var/log/apache2/error.log"
elif [ -f /var/log/httpd/access_log ]; then
  APACHE_ACCESS_LOG="/var/log/httpd/access_log"
  APACHE_ERROR_LOG="/var/log/httpd/error_log"
fi

# Display logs function
show_logs() {
  clear
  echo "==========================================================================="
  echo "                    SYSTEM LIVE LOG MONITOR"
  echo "==========================================================================="
  echo "Update: $(date '+%Y-%m-%d %H:%M:%S')"
  echo "==========================================================================="
  echo ""
  
  echo "--- SYSTEM & KERNEL LOG (last 10 entries) ---"
  journalctl -n 10 --no-pager 2>/dev/null || echo "journalctl not available"
  
  echo ""
  echo "--- FAIL2BAN LOG (last 10 entries) ---"
  if [ -f /var/log/fail2ban.log ]; then
    tail -n 10 /var/log/fail2ban.log 2>/dev/null || echo "Cannot read fail2ban.log"
  else
    echo "Fail2ban not installed or log not found"
  fi
  
  echo ""
  echo "--- AUTHENTICATION LOG (last 10 entries) ---"
  journalctl SYSLOG_FACILITY=10 -n 10 --no-pager 2>/dev/null || echo "Auth log not available"
  
  echo ""
  echo "--- WEB SERVER ACCESS LOG (last 10 entries) ---"
  if [ -n "$APACHE_ACCESS_LOG" ] && [ -f "$APACHE_ACCESS_LOG" ]; then
    tail -n 10 "$APACHE_ACCESS_LOG" 2>/dev/null || echo "Cannot read access log"
  else
    echo "Web server access log not found"
  fi
  
  echo ""
  echo "--- WEB SERVER ERROR LOG (last 10 entries) ---"
  if [ -n "$APACHE_ERROR_LOG" ] && [ -f "$APACHE_ERROR_LOG" ]; then
    tail -n 10 "$APACHE_ERROR_LOG" 2>/dev/null || echo "Cannot read error log"
  else
    echo "Web server error log not found"
  fi
  
  echo ""
  echo "==========================================================================="
  echo "[ Auto-refresh in 5 seconds | Press ENTER to quit ]"
  echo "==========================================================================="
}

# Main loop
echo "System Log Monitor starting..."
sleep 1

while true; do
  show_logs
  
  # Wait 5 seconds or until user presses Enter
  if read -r -t 5 -n 1 2>/dev/null; then
    echo ""
    echo "Exiting monitor..."
    break
  fi
done

exit 0