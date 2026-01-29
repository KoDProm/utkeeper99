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
# === just a try to maximise ===

if [[ -n "$DISPLAY" ]]; then
  if command -v wmctrl &>/dev/null && command -v xdotool &>/dev/null; then
    WINDOW_ID=$(xdotool getactivewindow 2>/dev/null)
    if [[ -n "$WINDOW_ID" ]]; then
      wmctrl -i -r "$WINDOW_ID" -b add,maximized_vert,maximized_horz 2>/dev/null || true
    fi
  elif command -v xdotool &>/dev/null && command -v xdpyinfo &>/dev/null; then
    WINDOW_ID=$(xdotool getactivewindow 2>/dev/null)
    if [[ -n "$WINDOW_ID" ]]; then
      DIMENSIONS=$(xdpyinfo 2>/dev/null | awk '/dimensions:/ {print $2}')
      if [[ -n "$DIMENSIONS" ]]; then
        SCREEN_WIDTH=$(echo "$DIMENSIONS" | cut -d'x' -f1)
        SCREEN_HEIGHT=$(echo "$DIMENSIONS" | cut -d'x' -f2)
        if [[ "$SCREEN_WIDTH" =~ ^[0-9]+$ ]] && [[ "$SCREEN_HEIGHT" =~ ^[0-9]+$ ]]; then
          xdotool windowsize "$WINDOW_ID" "$SCREEN_WIDTH" "$SCREEN_HEIGHT" 2>/dev/null || true
          xdotool windowmove "$WINDOW_ID" 0 0 2>/dev/null || true
        fi
      fi
    fi
  fi
fi
set -euo pipefail
IFS=$'\n\t'

# === PATHS ===
SCRIPT_PATH="$(realpath "$0")"
SCRIPT_DIR="$(dirname "$SCRIPT_PATH")"
PROJECT_ROOT="$SCRIPT_DIR"
CONFIG_FILE="${PROJECT_ROOT}/.config"
LIBS_DIR="${PROJECT_ROOT}/libs"

# Export paths for sub-scripts
export PROJECT_ROOT
export CONFIG_FILE
export LIBS_DIR

# === SUDO CHECK ===
if [ "$EUID" -ne 0 ]; then
  echo "This script requires root privileges."
  echo "Restarting with sudo..."
  exec sudo -E bash "$SCRIPT_PATH" "$@"
fi

# === FIRST-RUN SETUP WIZARD ===
first_run_setup() {
  clear
  echo "==========================================================================="
  echo "                   UTKEEPER99 - FIRST TIME SETUP"
  echo "==========================================================================="
  echo ""
  echo "No configuration found. Let's set up UTKeeper99!"
  echo ""
  echo "This wizard will auto-detect most settings."
  echo "Press Enter to accept defaults, or type a custom value."
  echo ""
  sleep 2
  
  # === AUTO-DETECTION FUNCTIONS (inline for first-run) ===
  
  # Find UT99 installation
  local detected_ut=""
  local paths=(
    "/opt/utserver"
    "/opt/ut99"
    "/home/utserver/utserver"
    "/usr/local/games/ut99"
    "/srv/utserver"
  )
  
  for path in "${paths[@]}"; do
    if [[ -d "$path/System" ]]; then
      if [[ -f "$path/System/UnrealTournament.ini" ]] || \
         [[ -f "$path/System/ut.ini" ]] || \
         [[ -f "$path/System/ucc-bin" ]]; then
        detected_ut="$path"
        break
      fi
    fi
  done
  
  # Detect web root
  local detected_web="/var/www/html"
  if command -v apache2ctl &>/dev/null; then
    local temp=$(apache2ctl -t -D DUMP_VHOSTS 2>/dev/null | grep -oP 'DocumentRoot\s+\K\S+' | head -1)
    if [[ -n "$temp" ]] && [[ -d "$temp" ]]; then
      if [[ "$temp" == "/var/www"* ]]; then
        detected_web="/var/www/html"
      else
        detected_web="$temp"
      fi
    fi
  elif command -v nginx &>/dev/null; then
    local temp=$(nginx -T 2>/dev/null | grep -oP '^\s*root\s+\K[^;]+' | head -1)
    if [[ -n "$temp" ]] && [[ -d "$temp" ]]; then
      detected_web="$temp"
    fi
  fi
  
  # Detect services
  local detected_ut_svc="utserver.service"
  local detected_ap_svc="apache2.service"
  
  if systemctl list-unit-files 2>/dev/null | grep -q "^utserver.service"; then
    detected_ut_svc="utserver.service"
  elif systemctl list-unit-files 2>/dev/null | grep -q "^ut-server.service"; then
    detected_ut_svc="ut-server.service"
  elif systemctl list-unit-files 2>/dev/null | grep -q "^ut.service"; then
    detected_ut_svc="ut.service"
  fi
  
  if systemctl list-unit-files 2>/dev/null | grep -q "^apache2.service"; then
    detected_ap_svc="apache2.service"
  elif systemctl list-unit-files 2>/dev/null | grep -q "^httpd.service"; then
    detected_ap_svc="httpd.service"
  elif systemctl list-unit-files 2>/dev/null | grep -q "^nginx.service"; then
    detected_ap_svc="nginx.service"
  fi
  
  # === PATH VALIDATION FUNCTION ===
  validate_path() {
    local path="$1"
    local path_name="$2"
    
    # Reject dangerous single-character or root paths
    if [[ "$path" == "/" ]] || \
       [[ "$path" == "~" ]] || \
       [[ "$path" == "/bin" ]] || \
       [[ "$path" == "/usr" ]] || \
       [[ "$path" == "/etc" ]] || \
       [[ "$path" == "/var" ]] || \
       [[ "$path" == "/home" ]] || \
       [[ "$path" == "/root" ]] || \
       [[ -z "$path" ]]; then
      echo ""
      echo "  ⚠️  ERROR: Path rejected for safety!"
      echo "      Path: '$path'"
      echo "      Reason: Critical system path or empty"
      echo ""
      echo "  ✗ Please specify a full path like:"
      echo "      /opt/utserver"
      echo "      /home/utserver/utserver"
      echo "      /srv/utserver"
      echo ""
      return 1
    fi
    
    return 0
  }
  
  # === DETECT UT SERVER PATH ===
  echo "[1/7] Detecting UT99 Server Installation..."
  
  if [ -n "$detected_ut" ]; then
    echo "  ✓ Auto-detected: $detected_ut"
    read -p "  UT Server path [$detected_ut]: " user_input
    UT_BASE_PATH="${user_input:-$detected_ut}"
  else
    echo "  ⚠ Could not auto-detect UT99 server"
    read -p "  UT Server path [/opt/utserver]: " user_input
    UT_BASE_PATH="${user_input:-/opt/utserver}"
  fi
  
  # Validate UT_BASE_PATH
  while ! validate_path "$UT_BASE_PATH" "UT Server"; do
    read -p "  Try again? Enter UT Server path (or 'quit' to exit): " user_input
    
    if [[ "${user_input,,}" == "quit" ]]; then
      echo ""
      echo "Setup cancelled. Run UTKeeper99 again to retry."
      exit 0
    fi
    
    UT_BASE_PATH="$user_input"
  done
  
  if [ ! -d "$UT_BASE_PATH/System" ]; then
    echo "  ⚠ WARNING: System directory not found in $UT_BASE_PATH"
  fi
  echo ""
  
  # === DETECT UT USER/GROUP ===
  echo "[2/7] Detecting UT Server Owner..."
  if [ -d "$UT_BASE_PATH" ]; then
    UT_USER=$(stat -c %U "$UT_BASE_PATH" 2>/dev/null || echo "utserver")
    UT_GROUP=$(stat -c %G "$UT_BASE_PATH" 2>/dev/null || echo "utserver")
    echo "  ✓ Detected: $UT_USER:$UT_GROUP"
  else
    UT_USER="utserver"
    UT_GROUP="utserver"
    echo "  ✓ Using default: $UT_USER:$UT_GROUP"
  fi
  echo ""
  
  # === DETECT LOG PATH ===
  echo "[3/7] Setting up Log Path..."
  LOG_PATH="$UT_BASE_PATH/Logs"
  echo "  ✓ Using: $LOG_PATH"
  echo ""
  
  # === DETECT WEB ROOT ===
  echo "[4/7] Detecting Web Server Root..."
  echo "  ✓ Detected: $detected_web"
  WEB_ROOT="$detected_web"
  echo ""
  
  # === DETECT UT REDIRECT ===
  echo "[5/7] Detecting UT Redirect Directory..."
  
  # Scan for .uz files (depth 5)
  local detected_redirect=""
  if [ -d "$WEB_ROOT" ]; then
    detected_redirect=$(find "$WEB_ROOT" -maxdepth 5 -name "*.uz" -printf '%h\n' 2>/dev/null | sort -u | head -1)
  fi
  
  if [ -n "$detected_redirect" ]; then
    echo "  ✓ Found .uz files in: $detected_redirect"
    read -p "  UT Redirect path [$detected_redirect]: " user_input
    UT_REDIRECT="${user_input:-$detected_redirect}"
  else
    echo "  ⚠ No .uz files found (will use default)"
    read -p "  UT Redirect path [$WEB_ROOT/ut]: " user_input
    UT_REDIRECT="${user_input:-$WEB_ROOT/ut}"
  fi
  
  # Validate UT_REDIRECT
  while ! validate_path "$UT_REDIRECT" "UT Redirect"; do
    read -p "  Try again? Enter UT Redirect path (or 'quit' to exit): " user_input
    
    if [[ "${user_input,,}" == "quit" ]]; then
      echo ""
      echo "Setup cancelled. Run UTKeeper99 again to retry."
      exit 0
    fi
    
    UT_REDIRECT="$user_input"
  done
  
  echo ""
  
  # === DETECT WEB USER/GROUP ===
  echo "[6/7] Detecting Web Server Owner..."
  if [ -d "$WEB_ROOT" ]; then
    WEB_USER=$(stat -c %U "$WEB_ROOT" 2>/dev/null || echo "www-data")
    WEB_GROUP=$(stat -c %G "$WEB_ROOT" 2>/dev/null || echo "www-data")
    echo "  ✓ Detected: $WEB_USER:$WEB_GROUP"
  else
    WEB_USER="www-data"
    WEB_GROUP="www-data"
    echo "  ✓ Using default: $WEB_USER:$WEB_GROUP"
  fi
  echo ""
  
  # === SETUP UPLOAD DIRECTORY ===
  echo "[7/7] Setting up Upload Directory..."
  UPLOAD_DIR="${PROJECT_ROOT}/upload"
  echo "  ✓ Using: $UPLOAD_DIR"
  echo ""
  
  # Services (auto-detected, no prompts)
  UT_SVC="$detected_ut_svc"
  AP_SVC="$detected_ap_svc"
  
  # === SUMMARY ===
  echo "==========================================================================="
  echo "                          CONFIGURATION SUMMARY"
  echo "==========================================================================="
  echo ""
  echo "UT SERVER:"
  echo "  Path:       $UT_BASE_PATH"
  echo "  Owner:      $UT_USER:$UT_GROUP"
  echo "  Logs:       $LOG_PATH"
  echo "  Service:    $UT_SVC (auto-detected)"
  echo ""
  echo "WEB SERVER:"
  echo "  Root:       $WEB_ROOT"
  echo "  Redirect:   $UT_REDIRECT"
  echo "  Owner:      $WEB_USER:$WEB_GROUP"
  echo "  Service:    $AP_SVC (auto-detected)"
  echo ""
  echo "UTKEEPER:"
  echo "  Project:    $PROJECT_ROOT"
  echo "  Upload Dir: $UPLOAD_DIR"
  echo ""
  echo "==========================================================================="
  echo ""
  
  read -p "Save this configuration? (Y/n): " confirm
  
  if [[ "${confirm,,}" =~ ^n ]]; then
    echo ""
    echo "Setup cancelled. Run UTKeeper99 again to retry."
    exit 0
  fi
  
  # === SAVE CONFIGURATION ===
  echo ""
  echo "Saving configuration..."
  
  cat > "$CONFIG_FILE" << EOF
# UTKeeper99 Configuration File
# Auto-generated on $(date)

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
  
  echo "✓ Configuration saved to: $CONFIG_FILE"
  echo ""
  
  # Create upload directory structure
  echo "Creating upload directory structure..."
  mkdir -p "$UPLOAD_DIR/installed"
  
  # Set correct ownership
  local real_user="${SUDO_USER:-$USER}"
  local real_group=$(id -gn "$real_user" 2>/dev/null || echo "$real_user")
  chown -R "$real_user:$real_group" "$UPLOAD_DIR" 2>/dev/null || true
  chmod -R 755 "$UPLOAD_DIR"
  
  echo "✓ Upload directory created: $UPLOAD_DIR"
  echo ""
  
  echo "==========================================================================="
  echo "                     SETUP COMPLETE!"
  echo "==========================================================================="
  echo ""
  echo "UTKeeper99 is now configured and ready to use."
  echo ""
  echo "Press Enter to continue to main menu..."
  read
}

# === LOAD CONFIG ===
load_config() {
  if [[ -f "$CONFIG_FILE" ]]; then
    source "$CONFIG_FILE" 2>/dev/null || {
      echo "WARNING: Failed to parse config file!"
      echo "Please check: $CONFIG_FILE"
      return 1
    }
    
    # Export all config variables for sub-scripts
    export UT_BASE_PATH
    export LOG_PATH
    export UT_USER
    export UT_GROUP
    export UT_REDIRECT
    export WEB_ROOT
    export WEB_USER
    export WEB_GROUP
    export UPLOAD_DIR
    export UT_SVC
    export AP_SVC
    
    return 0
  else
    return 1
  fi
}

# === CHECK AND RUN FIRST-RUN SETUP IF NEEDED ===
CONFIG_LOADED=false

if ! load_config; then
  # No config found - run first-time setup
  first_run_setup
  
  # Load newly created config
  if load_config; then
    CONFIG_LOADED=true
  else
    echo "ERROR: Configuration failed to load after setup!"
    exit 1
  fi
else
  CONFIG_LOADED=true
fi

# === SESSION VARIABLES (not saved to config) ===
DRY_RUN="${DRY_RUN:-false}"
export DRY_RUN

# === DISPLAY STATUS ===
show_status() {
  clear
  
  # Check service status
  local ut_status="Inactive"
  local ap_status="Inactive"
  local ut_color="\e[31m"  # Red
  local ap_color="\e[31m"  # Red
  
  if systemctl is-active "$UT_SVC" >/dev/null 2>&1; then 
    ut_status="Active"
    ut_color="\e[32m"  # Green
  fi
  
  if systemctl is-active "$AP_SVC" >/dev/null 2>&1; then 
    ap_status="Active"
    ap_color="\e[32m"  # Green
  fi
  
  echo "========================================================================"
  echo "                          UTKeeper99 v2.5"
  echo "========================================================================"
  echo ""
  
  echo "=== SERVICE STATUS ====================================================="
  printf "UT Server:   ${ut_color}%-10s\e[0m (Service: %s)\n" "$ut_status" "$UT_SVC"
  printf "Web Server:  ${ap_color}%-10s\e[0m (Service: %s)\n" "$ap_status" "$AP_SVC"
  echo ""
  echo "=== CONFIGURATION ======================================================"
  printf "Config File: \e[32m%-10s\e[0m\n" "Active"
  printf "DryRun Mode: %s\n" "$( [[ "$DRY_RUN" == "true" ]] && echo "[ENABLED - MapTools Only]" || echo "OFF" )"
  echo ""
  echo "=== PATHS =============================================================="
  printf "Project Root: %s\n" "$PROJECT_ROOT"
  printf "UT Base:      %s\n" "$UT_BASE_PATH"
  printf "Upload Dir:   %s\n" "$UPLOAD_DIR"
  echo ""
  echo "=== MAIN MENU =========================================================="
  echo "  1) Start UT & Web Server"
  echo "  2) Stop UT & Web Server"
  echo ""
  echo "  3) System Live Log"
  echo "  4) UT Live Log"
  echo "  5) Log Overview"
  echo "  6) !Delete Systemwide Logs"
  echo ""
  echo "  7) MapTools"
  echo ""
  echo "  8) Configuration"
  echo ""
  echo "  9) Toggle DryRun Mode (MapTools only)"
  echo "  S) SmartBackup" 
  echo ""
  echo "  R) Show README"
  echo "  Q) Quit"
  echo "========================================================================"
  echo ""
}

# === FUNCTIONS ===

# Start Services
ut_apache_start() {
  local manager_script="/usr/local/bin/server_manager.sh"
  
  if [[ ! -x "$manager_script" ]]; then
    echo "ERROR: server_manager.sh not found!"
    echo "Please install it first. See ${PROJECT_ROOT}/examples for setup instructions."
    sleep 3
    return 1
  fi
  
  echo "Starting UT Server & Web Server..."
  
  "$manager_script" start || {
    echo "ERROR: Failed to start services!"
    sleep 3
    return 1
  }
  
  echo "[OK] Services started"
  sleep 2
}

# Stop Services
ut_apache_stop() {
  local manager_script="/usr/local/bin/server_manager.sh"
  
  if [[ ! -x "$manager_script" ]]; then
    echo "ERROR: server_manager.sh not found!"
    echo "Please install it first. See ${PROJECT_ROOT}/examples for setup instructions."
    sleep 3
    return 1
  fi
  
  echo "Stopping UT Server & Web Server..."
  
  "$manager_script" stop || {
    echo "ERROR: Failed to stop services!"
    sleep 3
    return 1
  }
  
  echo "[OK] Services stopped"
  sleep 2
}

# Run Script from /libs
run_script() {
  local script_name="$1"
  local script_path="${LIBS_DIR}/${script_name}"
  
  if [[ ! -f "$script_path" ]]; then
    echo "ERROR: Script not found: $script_path"
    sleep 2
    return 1
  fi
  
  bash "$script_path"
}

# SmartBackup
smart_backup() {
  local backup_script="${LIBS_DIR}/backup.sh"
  
  if [[ ! -f "$backup_script" ]]; then
    clear
    echo "==========================================================================="
    echo "                        SMARTBACKUP NOT FOUND"
    echo "==========================================================================="
    echo ""
    echo ""
    read -p "Press Enter to return to menu..."
    return 1
  fi
  
  bash "$backup_script"
}

# DryRun Toggle (Session only, NOT saved to config)
dryrun_toggle() {
  if [ "$DRY_RUN" = "false" ]; then
    DRY_RUN="true"
    export DRY_RUN
    echo ""
    echo "========================================="
    echo "  DRY-RUN MODE ACTIVATED"
    echo "========================================="
    echo ""
    echo "MapTools commands will be SIMULATED only."
    echo "This applies to:"
    echo "  - File extraction"
    echo "  - File distribution"
    echo "  - File deletion"
    echo "  - Directory cleanup"
    echo ""
    echo "All other functions run NORMALLY."
    echo "========================================="
  else
    DRY_RUN="false"
    export DRY_RUN
    echo ""
    echo "========================================="
    echo "  DRY-RUN MODE DISABLED"
    echo "========================================="
    echo ""
    echo "All commands will be executed normally."
    echo "========================================="
  fi
  
  sleep 2
}

# Show README
show_readme() {
  local readme="${PROJECT_ROOT}/README.txt"
  
  if [[ -f "$readme" ]]; then
    less "$readme"
  else
    echo "README.txt not found at: $readme"
    sleep 2
  fi
}

# Check Config exists
check_config() {
  if [[ ! -f "$CONFIG_FILE" ]]; then
    echo ""
    echo "WARNING: No configuration file found!"
    echo ""
    echo "Please run configuration first (Option 8)"
    echo ""
    read -p "Press Enter to continue..."
    return 1
  fi
  return 0
}

# === VALIDATE CRITICAL PATHS ===
validate_environment() {
  local errors=0
  
  # Check if /libs directory exists
  if [[ ! -d "$LIBS_DIR" ]]; then
    echo "ERROR: /libs directory not found: $LIBS_DIR"
    echo "Please ensure all library scripts are in the /libs directory"
    errors=$((errors + 1))
  fi
  
  if [[ ! -d "$UT_BASE_PATH" ]]; then
    echo "WARNING: UT Base Path not found: $UT_BASE_PATH"
    errors=$((errors + 1))
  fi
  
  # Ensure upload directory exists
  if [[ ! -d "$UPLOAD_DIR" ]]; then
    mkdir -p "$UPLOAD_DIR/installed"
    
    local real_user="${SUDO_USER:-$USER}"
    local real_group=$(id -gn "$real_user" 2>/dev/null || echo "$real_user")
    
    chown -R "$real_user:$real_group" "$UPLOAD_DIR" 2>/dev/null || true
    chmod -R 755 "$UPLOAD_DIR"
  else
    # Ensure installed subdirectory exists
    local installed_dir="${UPLOAD_DIR}/installed"
    if [[ ! -d "$installed_dir" ]]; then
      mkdir -p "$installed_dir"
      
      local real_user="${SUDO_USER:-$USER}"
      local real_group=$(id -gn "$real_user" 2>/dev/null || echo "$real_user")
      
      chown "$real_user:$real_group" "$installed_dir" 2>/dev/null || true
      chmod 755 "$installed_dir"
    fi
  fi
  
  if [[ $errors -gt 0 ]]; then
    echo ""
    echo "Found $errors configuration issue(s)."
    echo "Consider running: Configuration (Option 8)"
    echo ""
    read -p "Continue anyway? (y/N): " confirm
    [[ ! "${confirm,,}" =~ ^y ]] && exit 1
  fi
}

# === MAIN LOOP ===
validate_environment

while true; do
  show_status
  read -p "Choose an option: " choice
  
  case "$choice" in
    1) ut_apache_start ;;
    2) ut_apache_stop ;;
    3) run_script "system.sh" ;;
    4) run_script "ut.sh" ;;
    5) run_script "check_logs.sh" ;;
    6) run_script "clean_logs.sh" ;;
    7) 
      if check_config; then
        export DRY_RUN
        bash "${LIBS_DIR}/maptools.sh"
      fi
      ;;
    8) 
      run_script "server_config.sh"
      # Reload config after changes and re-export all variables
      if [[ -f "$CONFIG_FILE" ]]; then
        if load_config; then
          CONFIG_LOADED=true
          
          # Re-export all config variables for sub-scripts
          export UT_BASE_PATH
          export LOG_PATH
          export UT_USER
          export UT_GROUP
          export UT_REDIRECT
          export WEB_ROOT
          export WEB_USER
          export WEB_GROUP
          export UPLOAD_DIR
          export UT_SVC
          export AP_SVC
          
          echo ""
          echo "[OK] Config reloaded and exported successfully"
          echo "     All scripts will use updated configuration"
          sleep 2
        else
          echo ""
          echo "[ERROR] Failed to reload configuration"
          sleep 2
        fi
      fi
      ;;
    9) dryrun_toggle ;;
    s|S) smart_backup ;;
    r|R) show_readme ;;
    q|Q) 
      echo ""
      echo "Good bye. GL+HF!"
      exit 0
      ;;
    *) 
      echo "Invalid choice: $choice"
      sleep 1
      ;;
  esac
done
