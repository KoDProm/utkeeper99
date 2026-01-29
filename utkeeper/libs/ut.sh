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
# UT Server Live Log Viewer

set -euo pipefail

# Load configuration
# PROJECT_ROOT was exported by utkeeper.sh
if [[ -z "${PROJECT_ROOT:-}" ]]; then
  echo "ERROR: PROJECT_ROOT not set!"
  echo "This script must be called from utkeeper.sh"
  exit 1
fi

CONFIG_FILE="${PROJECT_ROOT}/.config"

if [[ ! -f "$CONFIG_FILE" ]]; then
  echo "ERROR: Config file not found: $CONFIG_FILE"
  echo "Please run configuration first (Option 8 in main menu)"
  exit 1
fi

source "$CONFIG_FILE"

# Check if required variables are set
if [[ -z "${UT_BASE_PATH:-}" ]]; then
  echo "ERROR: UT_BASE_PATH not set in config file!"
  echo "Please run configuration (Option 8 in main menu)"
  exit 1
fi

# Import variables
UT_LOG_FILE="${UT_BASE_PATH}/System/ut.log"

# Check if log file exists
if [[ ! -f "$UT_LOG_FILE" ]]; then
  echo "ERROR: UT log file not found: $UT_LOG_FILE"
  echo ""
  echo "Please check:"
  echo "  - UT Server is installed at: $UT_BASE_PATH"
  echo "  - UT Server has been started at least once"
  echo "  - Log file path is correct in config"
  exit 1
fi

# Display log function
show_logs() {
  clear
  echo "==========================================================================="
  echo "                    UT SERVER LIVE LOG (last 1200 lines)"
  echo "==========================================================================="
  echo "Log File: $UT_LOG_FILE"
  echo "==========================================================================="
  echo ""
  
  # Show last 1200 lines of log
  tail -n 1200 "$UT_LOG_FILE" 2>/dev/null || {
    echo "ERROR: Cannot read log file"
    echo "Check permissions for: $UT_LOG_FILE"
    return 1
  }
  
  echo ""
  echo "==========================================================================="
  echo "[ Auto-refresh in 10 seconds | Press ENTER to quit ]"
  echo "==========================================================================="
}

# Main loop with auto-refresh
while true; do
  show_logs
  
  # Wait 10 seconds or until user presses Enter
  if read -r -t 10 2>/dev/null; then
    echo "Exiting live log viewer..."
    break
  fi
done

exit 0