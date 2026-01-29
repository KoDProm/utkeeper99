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
# === BACKUP.SH - UTKeeper99 Backup System v1.1 ===

set -euo pipefail
IFS=$'\n\t'

# === LOAD CONFIG ===
if [[ -z "${PROJECT_ROOT:-}" ]]; then
  echo "ERROR: PROJECT_ROOT not set!"
  echo "This script must be called from utkeeper.sh"
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
if [[ -z "${UT_BASE_PATH:-}" ]] || [[ -z "${UT_REDIRECT:-}" ]] || [[ -z "${UPLOAD_DIR:-}" ]]; then
  echo "ERROR: Config missing required variables!"
  echo "Required: UT_BASE_PATH, UT_REDIRECT, UPLOAD_DIR"
  echo "Please run Configuration (Option 8 in main menu)"
  exit 1
fi

# === PATHS ===
BACKUP_DIR="${PROJECT_ROOT}/Backups"
LIBS_DIR="${PROJECT_ROOT}/libs"
EXAMPLES_DIR="${PROJECT_ROOT}/examples"
UPLOAD_INSTALLED="${UPLOAD_DIR}/installed"

# === OWNERSHIP DETECTION ===
# If PROJECT_ROOT is under /opt, use root:root
# Otherwise use SUDO_USER
if [[ "$PROJECT_ROOT" == /opt/* ]]; then
  BACKUP_OWNER="root"
  BACKUP_GROUP="root"
else
  BACKUP_OWNER="${SUDO_USER:-$USER}"
  BACKUP_GROUP=$(id -gn "$BACKUP_OWNER" 2>/dev/null || echo "$BACKUP_OWNER")
fi

# === ENSURE BACKUP DIRECTORY EXISTS ===
if [[ ! -d "$BACKUP_DIR" ]]; then
  mkdir -p "$BACKUP_DIR"
  chown "$BACKUP_OWNER:$BACKUP_GROUP" "$BACKUP_DIR" 2>/dev/null || true
  chmod 755 "$BACKUP_DIR"
fi

# === LOGGING ===
log_info() { echo "[INFO] $*"; }
log_warn() { echo "[WARN] $*" >&2; }
log_error() { echo "[ERROR] $*" >&2; }

# === TIMESTAMP FUNCTION ===
get_timestamp() {
  date +"%y%m%d-%H%M"
}

# === HUMAN READABLE SIZE ===
human_size() {
  local bytes=$1
  if (( bytes < 1024 )); then
    echo "${bytes}B"
  elif (( bytes < 1048576 )); then
    echo "$((bytes / 1024))KB"
  elif (( bytes < 1073741824 )); then
    echo "$((bytes / 1048576))MB"
  else
    echo "$((bytes / 1073741824))GB"
  fi
}

# === CHECK DISK SPACE ===
check_disk_space() {
  local required_mb=$1
  local target_dir="$2"
  
  local available_kb=$(df -k "$target_dir" | tail -1 | awk '{print $4}')
  local available_mb=$((available_kb / 1024))
  
  if (( available_mb < required_mb )); then
    log_error "Insufficient disk space!"
    log_error "Required: ${required_mb}MB, Available: ${available_mb}MB"
    return 1
  fi
  
  log_info "Disk space check: ${available_mb}MB available"
  return 0
}

# === CHECK PERMISSIONS ===
check_write_permission() {
  local dir="$1"
  
  if [[ ! -w "$dir" ]]; then
    log_error "No write permission for: $dir"
    return 1
  fi
  
  return 0
}

# === ESTIMATE DIRECTORY SIZE ===
estimate_size() {
  local dir="$1"
  
  if [[ ! -d "$dir" ]]; then
    echo "0"
    return
  fi
  
  local size_kb=$(du -sk "$dir" 2>/dev/null | cut -f1)
  local size_mb=$((size_kb / 1024))
  
  echo "$size_mb"
}

# === BACKUP UT SERVER ===
backup_ut_server() {
  clear
  echo "==========================================================================="
  echo "                    BACKUP UT SERVER"
  echo "==========================================================================="
  echo ""
  
  if [[ ! -d "$UT_BASE_PATH" ]]; then
    log_error "UT Server path not found: $UT_BASE_PATH"
    read -p "Press Enter to continue..."
    return 1
  fi
  
  local timestamp=$(get_timestamp)
  local backup_file="${BACKUP_DIR}/ut-server_${timestamp}.zip"
  
  echo "Source:      $UT_BASE_PATH"
  echo "Target:      $backup_file"
  echo "Owner:       $BACKUP_OWNER:$BACKUP_GROUP"
  echo ""
  echo "Excludes:    Logs, cache, *.tmp, *.log files"
  echo ""
  
  # Estimate size
  local est_size=$(estimate_size "$UT_BASE_PATH")
  echo "Estimated backup size: ~${est_size}MB (before compression)"
  echo ""
  
  # Check permissions
  if ! check_write_permission "$BACKUP_DIR"; then
    read -p "Press Enter to continue..."
    return 1
  fi
  
  # Check disk space (estimate 50% compression)
  local required_mb=$((est_size / 2))
  if ! check_disk_space "$required_mb" "$BACKUP_DIR"; then
    read -p "Press Enter to continue..."
    return 1
  fi
  
  echo ""
  read -p "Start backup? (y/N): " confirm
  
  if [[ ! "${confirm,,}" =~ ^y ]]; then
    log_info "Backup cancelled"
    read -p "Press Enter to continue..."
    return 0
  fi
  
  echo ""
  log_info "Creating backup..."
  echo ""
  
  # Create backup with exclusions
  cd "$UT_BASE_PATH/.."
  local base_name=$(basename "$UT_BASE_PATH")
  
  if zip -r "$backup_file" "$base_name" \
    -x "*/Logs/*" \
    -x "*/cache/*" \
    -x "*/*.tmp" \
    -x "*/*.log" 2>&1 | grep -E "adding:|deflated"; then
    
    # Set ownership
    chown "$BACKUP_OWNER:$BACKUP_GROUP" "$backup_file" 2>/dev/null || true
    chmod 644 "$backup_file"
    
    local final_size=$(stat -c%s "$backup_file" 2>/dev/null || echo "0")
    echo ""
    log_info "✓ Backup complete!"
    log_info "File: $(basename "$backup_file")"
    log_info "Size: $(human_size $final_size)"
  else
    log_error "Backup failed!"
  fi
  
  echo ""
  read -p "Press Enter to continue..."
}

# === BACKUP WEB REDIRECT ===
backup_web_redirect() {
  clear
  echo "==========================================================================="
  echo "                    BACKUP WEB REDIRECT"
  echo "==========================================================================="
  echo ""
  
  if [[ ! -d "$UT_REDIRECT" ]]; then
    log_error "Web Redirect path not found: $UT_REDIRECT"
    read -p "Press Enter to continue..."
    return 1
  fi
  
  local timestamp=$(get_timestamp)
  local backup_file="${BACKUP_DIR}/web-redirect_${timestamp}.zip"
  
  # Count .uz files
  local uz_count=$(find "$UT_REDIRECT" -maxdepth 1 -name "*.uz" -type f 2>/dev/null | wc -l)
  
  echo "Source:      $UT_REDIRECT"
  echo "Target:      $backup_file"
  echo "Owner:       $BACKUP_OWNER:$BACKUP_GROUP"
  echo ""
  echo "Files:       $uz_count .uz files"
  echo ""
  
  if [[ $uz_count -eq 0 ]]; then
    log_warn "No .uz files found in $UT_REDIRECT"
    read -p "Press Enter to continue..."
    return 0
  fi
  
  # Estimate size
  local est_kb=0
  while IFS= read -r -d '' file; do
    local size=$(stat -c%s "$file" 2>/dev/null || echo "0")
    est_kb=$((est_kb + size / 1024))
  done < <(find "$UT_REDIRECT" -maxdepth 1 -name "*.uz" -type f -print0 2>/dev/null)
  
  local est_mb=$((est_kb / 1024))
  echo "Estimated backup size: ~${est_mb}MB"
  echo ""
  
  # Check permissions
  if ! check_write_permission "$BACKUP_DIR"; then
    read -p "Press Enter to continue..."
    return 1
  fi
  
  # Check disk space
  if ! check_disk_space "$est_mb" "$BACKUP_DIR"; then
    read -p "Press Enter to continue..."
    return 1
  fi
  
  echo ""
  read -p "Start backup? (y/N): " confirm
  
  if [[ ! "${confirm,,}" =~ ^y ]]; then
    log_info "Backup cancelled"
    read -p "Press Enter to continue..."
    return 0
  fi
  
  echo ""
  log_info "Creating backup..."
  echo ""
  
  # Create backup (only .uz files)
  cd "$UT_REDIRECT"
  
  if zip "$backup_file" *.uz 2>&1 | grep -E "adding:|deflated"; then
    
    # Set ownership
    chown "$BACKUP_OWNER:$BACKUP_GROUP" "$backup_file" 2>/dev/null || true
    chmod 644 "$backup_file"
    
    local final_size=$(stat -c%s "$backup_file" 2>/dev/null || echo "0")
    echo ""
    log_info "✓ Backup complete!"
    log_info "File: $(basename "$backup_file")"
    log_info "Size: $(human_size $final_size)"
  else
    log_error "Backup failed!"
  fi
  
  echo ""
  read -p "Press Enter to continue..."
}

# === BACKUP UT + WEB COMPLETE ===
backup_complete() {
  clear
  echo "==========================================================================="
  echo "                 BACKUP UT SERVER + WEB REDIRECT"
  echo "==========================================================================="
  echo ""
  
  if [[ ! -d "$UT_BASE_PATH" ]]; then
    log_error "UT Server path not found: $UT_BASE_PATH"
    read -p "Press Enter to continue..."
    return 1
  fi
  
  if [[ ! -d "$UT_REDIRECT" ]]; then
    log_error "Web Redirect path not found: $UT_REDIRECT"
    read -p "Press Enter to continue..."
    return 1
  fi
  
  local timestamp=$(get_timestamp)
  local backup_file="${BACKUP_DIR}/ut-webserver-complete_${timestamp}.zip"
  
  echo "Sources:"
  echo "  - UT Server:    $UT_BASE_PATH"
  echo "  - Web Redirect: $UT_REDIRECT"
  echo ""
  echo "Target:      $backup_file"
  echo "Owner:       $BACKUP_OWNER:$BACKUP_GROUP"
  echo ""
  echo "Excludes:    Logs, cache, *.tmp, *.log files"
  echo ""
  
  # Estimate total size
  local est_ut=$(estimate_size "$UT_BASE_PATH")
  local est_web=$(estimate_size "$UT_REDIRECT")
  local est_total=$((est_ut + est_web))
  
  echo "Estimated backup size: ~${est_total}MB (before compression)"
  echo ""
  
  # Check permissions
  if ! check_write_permission "$BACKUP_DIR"; then
    read -p "Press Enter to continue..."
    return 1
  fi
  
  # Check disk space
  local required_mb=$((est_total / 2))
  if ! check_disk_space "$required_mb" "$BACKUP_DIR"; then
    read -p "Press Enter to continue..."
    return 1
  fi
  
  echo ""
  read -p "Start backup? (y/N): " confirm
  
  if [[ ! "${confirm,,}" =~ ^y ]]; then
    log_info "Backup cancelled"
    read -p "Press Enter to continue..."
    return 0
  fi
  
  echo ""
  log_info "Creating backup..."
  echo ""
  
  # Create backup with TWO separate zip operations
  # 1. UT Server first
  cd "$UT_BASE_PATH/.."
  local ut_base=$(basename "$UT_BASE_PATH")
  
  if zip -r "$backup_file" "$ut_base" \
    -x "*/Logs/*" \
    -x "*/cache/*" \
    -x "*/*.tmp" \
    -x "*/*.log" 2>&1 | grep -E "adding:|deflated"; then
    
    log_info "✓ UT Server added to backup"
  else
    log_error "Failed to add UT Server!"
    read -p "Press Enter to continue..."
    return 1
  fi
  
  # 2. Add Web Redirect to existing backup
  cd "$UT_REDIRECT/.."
  local web_base=$(basename "$UT_REDIRECT")
  
  # Count .uz files
  local uz_count=$(find "$UT_REDIRECT" -maxdepth 1 -name "*.uz" -type f 2>/dev/null | wc -l)
  
  if [[ $uz_count -gt 0 ]]; then
    echo ""
    log_info "Adding Web Redirect ($uz_count .uz files)..."
    
    if zip -g "$backup_file" "$UT_REDIRECT"/*.uz 2>&1 | grep -E "adding:|deflated"; then
      log_info "✓ Web Redirect added to backup"
    else
      log_warn "Failed to add Web Redirect (backup contains only UT Server)"
    fi
  else
    log_warn "No .uz files found in Web Redirect"
  fi
  
  # Set ownership
  chown "$BACKUP_OWNER:$BACKUP_GROUP" "$backup_file" 2>/dev/null || true
  chmod 644 "$backup_file"
  
  local final_size=$(stat -c%s "$backup_file" 2>/dev/null || echo "0")
  echo ""
  log_info "✓ Backup complete!"
  log_info "File: $(basename "$backup_file")"
  log_info "Size: $(human_size $final_size)"
  
  echo ""
  read -p "Press Enter to continue..."
}

# === BACKUP SCRIPT ROOT ===
backup_script_root() {
  clear
  echo "==========================================================================="
  echo "                    BACKUP UTKEEPER SCRIPT ROOT"
  echo "==========================================================================="
  echo ""
  
  local timestamp=$(get_timestamp)
  local backup_file="${BACKUP_DIR}/utkeeper_${timestamp}.zip"
  
  echo "Sources:"
  echo "  - Main Scripts:     utkeeper.sh, README.txt, README.md"
  echo "  - Backups:          $BACKUP_DIR/*.zip"
  echo "  - Libraries:        $LIBS_DIR"
  [[ -d "$EXAMPLES_DIR" ]] && echo "  - Examples:         $EXAMPLES_DIR"
  [[ -d "$UPLOAD_INSTALLED" ]] && echo "  - Installed:        $UPLOAD_INSTALLED"
  echo ""
  echo "Target:      $backup_file"
  echo "Owner:       $BACKUP_OWNER:$BACKUP_GROUP"
  echo ""
  echo "Note: .config is NOT backed up (forces users to run Configuration)"
  echo "Note: The backup being created will NOT include itself"
  echo ""
  
  # Estimate size
  local est_total=0
  [[ -d "$LIBS_DIR" ]] && est_total=$((est_total + $(estimate_size "$LIBS_DIR")))
  [[ -d "$EXAMPLES_DIR" ]] && est_total=$((est_total + $(estimate_size "$EXAMPLES_DIR")))
  [[ -d "$UPLOAD_INSTALLED" ]] && est_total=$((est_total + $(estimate_size "$UPLOAD_INSTALLED")))
  
  # Add existing backup sizes
  local backup_size=0
  while IFS= read -r -d '' file; do
    local size=$(stat -c%s "$file" 2>/dev/null || echo "0")
    backup_size=$((backup_size + size / 1024 / 1024))
  done < <(find "$BACKUP_DIR" -maxdepth 1 -name "*.zip" -type f -print0 2>/dev/null)
  
  est_total=$((est_total + backup_size))
  
  echo "Estimated backup size: ~${est_total}MB"
  echo ""
  
  # Check permissions
  if ! check_write_permission "$BACKUP_DIR"; then
    read -p "Press Enter to continue..."
    return 1
  fi
  
  # Check disk space
  if ! check_disk_space "$est_total" "$BACKUP_DIR"; then
    read -p "Press Enter to continue..."
    return 1
  fi
  
  echo ""
  read -p "Start backup? (y/N): " confirm
  
  if [[ ! "${confirm,,}" =~ ^y ]]; then
    log_info "Backup cancelled"
    read -p "Press Enter to continue..."
    return 0
  fi
  
  echo ""
  log_info "Creating backup..."
  echo ""
  
  cd "$PROJECT_ROOT"
  
  # Start with main scripts
  local has_files=false
  
  # Add utkeeper.sh if exists
  if [[ -f "utkeeper.sh" ]]; then
    zip "$backup_file" utkeeper.sh 2>&1 | grep -E "adding:|deflated"
    has_files=true
  fi
  
  # Add README files if they exist (both txt and md)
  if [[ -f "README.txt" ]]; then
    zip -g "$backup_file" README.txt 2>&1 | grep -E "adding:|deflated"
  fi
  
  if [[ -f "README.md" ]]; then
    zip -g "$backup_file" README.md 2>&1 | grep -E "adding:|deflated"
  fi
  
  # Add existing backups
  if ls "$BACKUP_DIR"/*.zip >/dev/null 2>&1; then
    # Exclude the file being created
    for backup in "$BACKUP_DIR"/*.zip; do
      if [[ "$backup" != "$backup_file" ]]; then
        zip -g "$backup_file" "$backup" 2>&1 | grep -E "adding:|deflated"
        has_files=true
      fi
    done
  fi
  
  # Add directories
  if [[ -d "libs" ]]; then
    zip -r -g "$backup_file" libs 2>&1 | grep -E "adding:|deflated"
    has_files=true
  fi
  
  if [[ -d "examples" ]]; then
    zip -r -g "$backup_file" examples 2>&1 | grep -E "adding:|deflated"
  fi
  
  if [[ -d "upload/installed" ]]; then
    zip -r -g "$backup_file" upload/installed 2>&1 | grep -E "adding:|deflated"
  fi
  
  if [[ "$has_files" = true ]]; then
    # Set ownership
    chown "$BACKUP_OWNER:$BACKUP_GROUP" "$backup_file" 2>/dev/null || true
    chmod 644 "$backup_file"
    
    local final_size=$(stat -c%s "$backup_file" 2>/dev/null || echo "0")
    echo ""
    log_info "✓ Backup complete!"
    log_info "File: $(basename "$backup_file")"
    log_info "Size: $(human_size $final_size)"
  else
    log_error "No files found to backup!"
    rm -f "$backup_file" 2>/dev/null
  fi
  
  echo ""
  read -p "Press Enter to continue..."
}

# === LIST BACKUPS ===
list_backups() {
  clear
  echo "==========================================================================="
  echo "                         BACKUP LIST"
  echo "==========================================================================="
  echo ""
  
  mapfile -t backup_files < <(find "$BACKUP_DIR" -maxdepth 1 -name "*.zip" -type f 2>/dev/null | sort)
  
  if [[ ${#backup_files[@]} -eq 0 ]]; then
    echo "No backups found in: $BACKUP_DIR"
    echo ""
    read -p "Press Enter to continue..."
    return 0
  fi
  
  echo "Found ${#backup_files[@]} backup(s):"
  echo ""
  printf "%-4s %-35s %-12s %-15s %s\n" "No." "Filename" "Size" "Owner" "Date"
  echo "───────────────────────────────────────────────────────────────────────────"
  
  local index=1
  for file in "${backup_files[@]}"; do
    local basename=$(basename "$file")
    local size=$(stat -c%s "$file" 2>/dev/null || echo "0")
    local size_human=$(human_size "$size")
    local owner=$(stat -c '%U:%G' "$file" 2>/dev/null || echo "unknown")
    local date=$(stat -c %y "$file" 2>/dev/null | cut -d' ' -f1,2 | cut -d'.' -f1)
    
    printf "%-4d %-35s %-12s %-15s %s\n" "$index" "$basename" "$size_human" "$owner" "$date"
    ((index++)) || true
  done
  
  # Calculate total size
  local total_size=0
  for file in "${backup_files[@]}"; do
    local size=$(stat -c%s "$file" 2>/dev/null || echo "0")
    total_size=$((total_size + size))
  done
  
  echo "───────────────────────────────────────────────────────────────────────────"
  echo "Total: ${#backup_files[@]} backup(s), $(human_size $total_size)"
  echo ""
  read -p "Press Enter to continue..."
}

# === DELETE BACKUPS ===
delete_backups() {
  clear
  echo "==========================================================================="
  echo "                         DELETE BACKUPS"
  echo "==========================================================================="
  echo ""
  
  mapfile -t backup_files < <(find "$BACKUP_DIR" -maxdepth 1 -name "*.zip" -type f 2>/dev/null | sort)
  
  if [[ ${#backup_files[@]} -eq 0 ]]; then
    echo "No backups found in: $BACKUP_DIR"
    echo ""
    read -p "Press Enter to continue..."
    return 0
  fi
  
  echo "Delete Options:"
  echo ""
  echo "  1) Delete by number (select from list)"
  echo "  2) Delete all backups older than 30 days"
  echo "  B) Back to menu"
  echo ""
  read -p "Choose option [1/2/B]: " delete_option
  
  case "${delete_option,,}" in
    1)
      # Delete by number
      clear
      echo "==========================================================================="
      echo "                    DELETE BACKUP BY NUMBER"
      echo "==========================================================================="
      echo ""
      
      printf "%-4s %-35s %-12s %s\n" "No." "Filename" "Size" "Date"
      echo "───────────────────────────────────────────────────────────────────────────"
      
      local index=1
      for file in "${backup_files[@]}"; do
        local basename=$(basename "$file")
        local size=$(stat -c%s "$file" 2>/dev/null || echo "0")
        local size_human=$(human_size "$size")
        local date=$(stat -c %y "$file" 2>/dev/null | cut -d' ' -f1)
        
        printf "%-4d %-35s %-12s %s\n" "$index" "$basename" "$size_human" "$date"
        ((index++)) || true
      done
      
      echo ""
      read -p "Enter backup number to delete (or 0 to cancel): " backup_num
      
      if [[ "$backup_num" =~ ^[0-9]+$ ]] && (( backup_num > 0 )) && (( backup_num <= ${#backup_files[@]} )); then
        local file_to_delete="${backup_files[$((backup_num - 1))]}"
        local basename=$(basename "$file_to_delete")
        
        echo ""
        echo "Selected: $basename"
        read -p "Are you sure you want to delete this backup? (yes/no): " confirm
        
        if [[ "$confirm" == "yes" ]]; then
          if rm -f "$file_to_delete" 2>/dev/null; then
            log_info "✓ Deleted: $basename"
          else
            log_error "Failed to delete: $basename"
          fi
        else
          log_info "Deletion cancelled"
        fi
      else
        log_info "Cancelled"
      fi
      ;;
      
    2)
      # Delete older guys
      clear
      echo "==========================================================================="
      echo "                 DELETE BACKUPS OLDER THAN 30 DAYS"
      echo "==========================================================================="
      echo ""
      
      local old_backups=()
      local now=$(date +%s)
      local thirty_days=$((30 * 24 * 60 * 60))
      
      for file in "${backup_files[@]}"; do
        local file_time=$(stat -c %Y "$file" 2>/dev/null || echo "0")
        local age=$((now - file_time))
        
        if (( age > thirty_days )); then
          old_backups+=("$file")
        fi
      done
      
      if [[ ${#old_backups[@]} -eq 0 ]]; then
        echo "No backups older than 30 days found."
        echo ""
        read -p "Press Enter to continue..."
        return 0
      fi
      
      echo "Found ${#old_backups[@]} backup(s) older than 30 days:"
      echo ""
      
      for file in "${old_backups[@]}"; do
        local basename=$(basename "$file")
        local date=$(stat -c %y "$file" 2>/dev/null | cut -d' ' -f1)
        local size=$(stat -c%s "$file" 2>/dev/null || echo "0")
        echo "  - $basename ($date, $(human_size $size))"
      done
      
      echo ""
      read -p "Delete all these backups? (yes/no): " confirm
      
      if [[ "$confirm" == "yes" ]]; then
        local deleted=0
        for file in "${old_backups[@]}"; do
          if rm -f "$file" 2>/dev/null; then
            ((deleted++)) || true
          fi
        done
        log_info "✓ Deleted $deleted backup(s)"
      else
        log_info "Deletion cancelled"
      fi
      ;;
      
    b|B)
      return 0
      ;;
      
    *)
      log_error "Invalid option"
      ;;
  esac
  
  echo ""
  read -p "Press Enter to continue..."
}

# === MAIN MENU ===
show_menu() {
  clear
  echo "==========================================================================="
  echo "                    UTKEEPER99 - BACKUP SYSTEM v1.1"
  echo "==========================================================================="
  echo ""
  echo "Backup Directory: $BACKUP_DIR"
  echo "Owner:            $BACKUP_OWNER:$BACKUP_GROUP"
  echo ""
  
  # Show backup count and total size
  local backup_count=$(find "$BACKUP_DIR" -maxdepth 1 -name "*.zip" -type f 2>/dev/null | wc -l)
  if [[ $backup_count -gt 0 ]]; then
    local total_size=0
    while IFS= read -r -d '' file; do
      local size=$(stat -c%s "$file" 2>/dev/null || echo "0")
      total_size=$((total_size + size))
    done < <(find "$BACKUP_DIR" -maxdepth 1 -name "*.zip" -type f -print0 2>/dev/null)
    
    echo "Existing Backups: $backup_count ($(human_size $total_size))"
  else
    echo "Existing Backups: None"
  fi
  
  echo ""
  echo "==========================================================================="
  echo "                              MENU"
  echo "==========================================================================="
  echo ""
  echo "  1) Backup UT Server"
  echo "  2) Backup Web Redirect"
  echo "  3) Backup UT Server + Web Redirect (Complete)"
  echo "  4) Backup UTKeeper Script Root /Backup /libs /examples /upload/installed"
  echo "  5) List Backups"
  echo "  6) Delete Backups"
  echo ""
  echo "  B) Back to Main Menu"
  echo ""
  echo "==========================================================================="
  echo ""
}

# === MAIN LOOP ===
while true; do
  show_menu
  read -p "Choose option [1-6, B]: " choice
  
  case "${choice,,}" in
    1) backup_ut_server ;;
    2) backup_web_redirect ;;
    3) backup_complete ;;
    4) backup_script_root ;;
    5) list_backups ;;
    6) delete_backups ;;
    b) 
      clear
      echo "Returning to main menu..."
      sleep 1
      break
      ;;
    *)
      echo "Invalid choice!"
      sleep 1
      ;;
  esac
done
