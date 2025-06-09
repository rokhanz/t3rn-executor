#!/bin/bash
set -euo pipefail

# ╔══════════════════════════════════════════════════════════════╗
# ║                    T3RN LOG MANAGER                         ║
# ║                  (Log Management & Rotation)                ║
# ╚══════════════════════════════════════════════════════════════╝

# T3RN Executor Log Manager
# Comprehensive log management with rotation, archival, and colorful output
#
# @author Rokhanz
# @license MIT
# @version 1.0.0


# === INTERNAL ERROR HANDLING ===
log_manager_error_exit() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] LOG_MANAGER ERROR: $*" >&2
  exit 1
}

log_manager_log_info() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] LOG_MANAGER INFO: $*"
}

log_manager_log_warn() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] LOG_MANAGER WARN: $*"
}

# === INITIALIZE LOG MANAGER ===
initialize_log_manager() {
  if [[ -z "${SCRIPT_DIR:-}" ]]; then
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")"/.. && pwd)"
    export SCRIPT_DIR
  fi
  
  if [[ -z "${LOGS_DIR:-}" ]]; then
    LOGS_DIR="$SCRIPT_DIR/logs"
    export LOGS_DIR
  fi
  
  # Create logs directory structure
  mkdir -p "$LOGS_DIR" || log_manager_error_exit "Cannot create logs directory"
  mkdir -p "$LOGS_DIR/archive" || log_manager_error_exit "Cannot create archive directory"
  mkdir -p "$LOGS_DIR/daily" || log_manager_error_exit "Cannot create daily directory"
  
  # Load .env for log configuration
  if [[ -f "$SCRIPT_DIR/.env" ]]; then
    source "$SCRIPT_DIR/.env" 2>/dev/null || true
  fi
  
  log_manager_log_info "📝 Log manager initialized"
}

# === LOG CONFIGURATION ===
LOG_ROTATION_SIZE="${LOG_ROTATION_SIZE:-100M}"
LOG_RETENTION_DAYS="${LOG_RETENTION_DAYS:-7}"
LOG_FORMAT="${LOG_FORMAT:-simple}"
LOG_TO_FILE="${LOG_TO_FILE:-true}"
ENABLE_COLOR_OUTPUT="${ENABLE_COLOR_OUTPUT:-true}"
ENABLE_EMOJI_LOGGING="${ENABLE_EMOJI_LOGGING:-true}"

# === LOG LEVELS ===
declare -A LOG_LEVELS=(
  ["DEBUG"]=0
  ["INFO"]=1
  ["WARN"]=2
  ["ERROR"]=3
  ["FATAL"]=4
)

declare -A LOG_COLORS=(
  ["DEBUG"]="\033[36m"    # Cyan
  ["INFO"]="\033[32m"     # Green
  ["WARN"]="\033[33m"     # Yellow
  ["ERROR"]="\033[31m"    # Red
  ["FATAL"]="\033[35m"    # Magenta
  ["RESET"]="\033[0m"     # Reset
)

declare -A LOG_EMOJIS=(
  ["DEBUG"]="🔍"
  ["INFO"]="ℹ️"
  ["WARN"]="⚠️"
  ["ERROR"]="❌"
  ["FATAL"]="💀"
)

# === CONVERT SIZE TO BYTES ===
convert_size_to_bytes() {
  local size="$1"
  local number=$(echo "$size" | grep -oP '\d+')
  local unit=$(echo "$size" | grep -oP '[A-Za-z]+' | tr '[:lower:]' '[:upper:]')
  
  case "$unit" in
    "B"|"") echo "$number" ;;
    "K"|"KB") echo $((number * 1024)) ;;
    "M"|"MB") echo $((number * 1024 * 1024)) ;;
    "G"|"GB") echo $((number * 1024 * 1024 * 1024)) ;;
    *) echo "$number" ;;
  esac
}

# === GET LOG LEVEL NUMBER ===
get_log_level_number() {
  local level="$1"
  echo "${LOG_LEVELS[${level^^}]:-1}"
}

# === CHECK IF LOG LEVEL SHOULD BE LOGGED ===
should_log() {
  local level="$1"
  local current_level="${LOG_LEVEL:-INFO}"
  
  local level_num=$(get_log_level_number "$level")
  local current_level_num=$(get_log_level_number "$current_level")
  
  [[ $level_num -ge $current_level_num ]]
}

# === FORMAT LOG MESSAGE ===
format_log_message() {
  local level="$1"
  local component="$2"
  local message="$3"
  local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
  
  case "${LOG_FORMAT:-simple}" in
    "json")
      echo "{\"timestamp\":\"$timestamp\",\"level\":\"$level\",\"component\":\"$component\",\"message\":\"$message\"}"
      ;;
    "detailed")
      echo "[$timestamp] [$level] [$component] $message"
      ;;
    "simple"|*)
      if [[ "${ENABLE_EMOJI_LOGGING:-true}" == "true" ]]; then
        echo "[$timestamp] ${LOG_EMOJIS[$level]} $component: $message"
      else
        echo "[$timestamp] $level $component: $message"
      fi
      ;;
  esac
}

# === WRITE LOG MESSAGE ===
write_log() {
  local level="$1"
  local component="$2"
  local message="$3"
  local log_file="${4:-$LOGS_DIR/executor.log}"
  
  # Check if we should log this level
  if ! should_log "$level"; then
    return 0
  fi
  
  # Format message
  local formatted_message=$(format_log_message "$level" "$component" "$message")
  
  # Output to console with color if enabled
  if [[ "${ENABLE_COLOR_OUTPUT:-true}" == "true" && -t 1 ]]; then
    echo -e "${LOG_COLORS[$level]}$formatted_message${LOG_COLORS[RESET]}"
  else
    echo "$formatted_message"
  fi
  
  # Write to file if enabled
  if [[ "${LOG_TO_FILE:-true}" == "true" ]]; then
    echo "$formatted_message" >> "$log_file"
  fi
}

# === LOG FUNCTIONS ===
log_debug() {
  write_log "DEBUG" "${1:-SYSTEM}" "$2" "${3:-}"
}

log_info() {
  write_log "INFO" "${1:-SYSTEM}" "$2" "${3:-}"
}

log_warn() {
  write_log "WARN" "${1:-SYSTEM}" "$2" "${3:-}"
}

log_error() {
  write_log "ERROR" "${1:-SYSTEM}" "$2" "${3:-}"
}

log_fatal() {
  write_log "FATAL" "${1:-SYSTEM}" "$2" "${3:-}"
}

# === GET LOG FILE SIZE ===
get_log_file_size() {
  local log_file="$1"
  
  if [[ -f "$log_file" ]]; then
    stat -c%s "$log_file" 2>/dev/null || echo "0"
  else
    echo "0"
  fi
}

# === CHECK IF LOG ROTATION NEEDED ===
needs_rotation() {
  local log_file="$1"
  local max_size_bytes=$(convert_size_to_bytes "$LOG_ROTATION_SIZE")
  local current_size=$(get_log_file_size "$log_file")
  
  [[ $current_size -gt $max_size_bytes ]]
}

# === ROTATE LOG FILE ===
rotate_log_file() {
  local log_file="$1"
  
  if [[ ! -f "$log_file" ]]; then
    log_manager_log_warn "Log file not found for rotation: $log_file"
    return 1
  fi
  
  log_manager_log_info "🔄 Rotating log file: $log_file"
  
  local base_name=$(basename "$log_file" .log)
  local archive_dir="$LOGS_DIR/archive"
  local timestamp=$(date '+%Y%m%d_%H%M%S')
  local rotated_file="$archive_dir/${base_name}_${timestamp}.log"
  
  # Move current log to archive
  if mv "$log_file" "$rotated_file"; then
    log_manager_log_info "✅ Log rotated to: $rotated_file"
    
    # Compress rotated log
    if command -v gzip >/dev/null 2>&1; then
      if gzip "$rotated_file"; then
        log_manager_log_info "✅ Log compressed: ${rotated_file}.gz"
      fi
    fi
    
    # Create new log file
    touch "$log_file"
    
    return 0
  else
    log_manager_log_warn "❌ Failed to rotate log file"
    return 1
  fi
}

# === CLEANUP OLD LOGS ===
cleanup_old_logs() {
  local retention_days="${LOG_RETENTION_DAYS:-7}"
  
  log_manager_log_info "🧹 Cleaning up logs older than $retention_days days..."
  
  local archive_dir="$LOGS_DIR/archive"
  local daily_dir="$LOGS_DIR/daily"
  
  # Clean archive logs
  if [[ -d "$archive_dir" ]]; then
    local deleted_count=0
    while IFS= read -r -d '' file; do
      if rm "$file"; then
        ((deleted_count++))
      fi
    done < <(find "$archive_dir" -name "*.log*" -type f -mtime +$retention_days -print0 2>/dev/null)
    
    if [[ $deleted_count -gt 0 ]]; then
      log_manager_log_info "✅ Deleted $deleted_count old archive files"
    fi
  fi
  
  # Clean daily logs
  if [[ -d "$daily_dir" ]]; then
    local deleted_count=0
    while IFS= read -r -d '' file; do
      if rm "$file"; then
        ((deleted_count++))
      fi
    done < <(find "$daily_dir" -name "*.log*" -type f -mtime +$retention_days -print0 2>/dev/null)
    
    if [[ $deleted_count -gt 0 ]]; then
      log_manager_log_info "✅ Deleted $deleted_count old daily files"
    fi
  fi
}

# === AUTO ROTATE LOGS ===
auto_rotate_logs() {
  log_manager_log_info "🔄 Checking logs for rotation..."
  
  local log_files=(
    "$LOGS_DIR/executor.log"
    "$LOGS_DIR/autorun.log"
    "$LOGS_DIR/main.log"
    "$LOGS_DIR/downloader.log"
    "$LOGS_DIR/validation.log"
    "$LOGS_DIR/rpc_manager.log"
    "$LOGS_DIR/balance_checker.log"
    "$LOGS_DIR/monitoring.log"
  )
  
  local rotated_count=0
  
  for log_file in "${log_files[@]}"; do
    if [[ -f "$log_file" ]] && needs_rotation "$log_file"; then
      if rotate_log_file "$log_file"; then
        ((rotated_count++))
      fi
    fi
  done
  
  if [[ $rotated_count -gt 0 ]]; then
    log_manager_log_info "✅ Rotated $rotated_count log files"
  else
    log_manager_log_info "📋 No logs need rotation"
  fi
  
  # Cleanup old logs
  cleanup_old_logs
}

# === CREATE DAILY LOG ===
create_daily_log() {
  local component="$1"
  local date_str=$(date '+%Y-%m-%d')
  local daily_log="$LOGS_DIR/daily/${component}_${date_str}.log"
  
  # Create daily directory if it doesn't exist
  mkdir -p "$LOGS_DIR/daily"
  
  # Touch the file to create it
  touch "$daily_log"
  
  echo "$daily_log"
}

# === TAIL LOG FILE ===
tail_log() {
  local log_file="${1:-$LOGS_DIR/executor.log}"
  local lines="${2:-50}"
  
  if [[ -f "$log_file" ]]; then
    tail -n "$lines" "$log_file"
  else
    log_manager_log_warn "Log file not found: $log_file"
  fi
}

# === GREP LOG FILE ===
grep_log() {
  local pattern="$1"
  local log_file="${2:-$LOGS_DIR/executor.log}"
  local context="${3:-0}"
  
  if [[ -f "$log_file" ]]; then
    if [[ $context -gt 0 ]]; then
      grep -C "$context" "$pattern" "$log_file"
    else
      grep "$pattern" "$log_file"
    fi
  else
    log_manager_log_warn "Log file not found: $log_file"
  fi
}

# === GET LOG STATISTICS ===
get_log_statistics() {
  local log_file="${1:-$LOGS_DIR/executor.log}"
  
  if [[ ! -f "$log_file" ]]; then
    echo "Log file not found: $log_file"
    return 1
  fi
  
  log_manager_log_info "📊 Log statistics for: $log_file"
  
  local total_lines=$(wc -l < "$log_file")
  local file_size=$(get_log_file_size "$log_file")
  local file_size_human=$(numfmt --to=iec "$file_size" 2>/dev/null || echo "${file_size} bytes")
  
  echo "📋 Total lines: $total_lines"
  echo "📊 File size: $file_size_human"
  
  # Count by log level
  for level in DEBUG INFO WARN ERROR FATAL; do
    local count=$(grep -c "\[$level\]" "$log_file" 2>/dev/null || echo "0")
    local emoji="${LOG_EMOJIS[$level]}"
    echo "$emoji $level: $count"
  done
  
  # Recent activity
  echo ""
  echo "📅 Recent activity (last 10 lines):"
  tail -n 10 "$log_file"
}

# === MONITOR LOG FILE ===
monitor_log() {
  local log_file="${1:-$LOGS_DIR/executor.log}"
  local pattern="${2:-}"
  
  log_manager_log_info "👁️ Monitoring log file: $log_file"
  
  if [[ -n "$pattern" ]]; then
    log_manager_log_info "🔍 Filtering for pattern: $pattern"
    tail -f "$log_file" | grep --line-buffered "$pattern"
  else
    tail -f "$log_file"
  fi
}

# === COMPRESS LOG FILE ===
compress_log() {
  local log_file="$1"
  
  if [[ ! -f "$log_file" ]]; then
    log_manager_log_warn "Log file not found: $log_file"
    return 1
  fi
  
  log_manager_log_info "🗜️ Compressing log file: $log_file"
  
  if command -v gzip >/dev/null 2>&1; then
    if gzip "$log_file"; then
      log_manager_log_info "✅ Log compressed: ${log_file}.gz"
      return 0
    else
      log_manager_log_warn "❌ Failed to compress log"
      return 1
    fi
  else
    log_manager_log_warn "❌ gzip not available"
    return 1
  fi
}

# === DECOMPRESS LOG FILE ===
decompress_log() {
  local compressed_file="$1"
  
  if [[ ! -f "$compressed_file" ]]; then
    log_manager_log_warn "Compressed file not found: $compressed_file"
    return 1
  fi
  
  log_manager_log_info "📂 Decompressing log file: $compressed_file"
  
  if command -v gunzip >/dev/null 2>&1; then
    if gunzip "$compressed_file"; then
      local decompressed_file="${compressed_file%.gz}"
      log_manager_log_info "✅ Log decompressed: $decompressed_file"
      return 0
    else
      log_manager_log_warn "❌ Failed to decompress log"
      return 1
    fi
  else
    log_manager_log_warn "❌ gunzip not available"
    return 1
  fi
}

# === EXPORT LOGS ===
export_logs() {
  local export_dir="${1:-$SCRIPT_DIR/log_export_$(date +%Y%m%d_%H%M%S)}"
  local days="${2:-7}"
  
  log_manager_log_info "📦 Exporting logs from last $days days to: $export_dir"
  
  mkdir -p "$export_dir"
  
  # Export current logs
  local current_logs=("$LOGS_DIR"/*.log)
  for log_file in "${current_logs[@]}"; do
    if [[ -f "$log_file" ]]; then
      cp "$log_file" "$export_dir/"
    fi
  done
  
  # Export recent archived logs
  if [[ -d "$LOGS_DIR/archive" ]]; then
    find "$LOGS_DIR/archive" -name "*.log*" -mtime -$days -exec cp {} "$export_dir/" \;
  fi
  
  # Export recent daily logs
  if [[ -d "$LOGS_DIR/daily" ]]; then
    find "$LOGS_DIR/daily" -name "*.log*" -mtime -$days -exec cp {} "$export_dir/" \;
  fi
  
  # Create export summary
  {
    echo "T3RN EXECUTOR LOG EXPORT"
    echo "Generated: $(date)"
    echo "Export Period: Last $days days"
    echo "========================================"
    echo ""
    echo "Exported Files:"
    ls -la "$export_dir"
    echo ""
    echo "Log Statistics:"
    for log_file in "$export_dir"/*.log; do
      if [[ -f "$log_file" ]]; then
        echo "$(basename "$log_file"): $(wc -l < "$log_file") lines, $(stat -c%s "$log_file") bytes"
      fi
    done
  } > "$export_dir/export_summary.txt"
  
  log_manager_log_info "✅ Logs exported to: $export_dir"
  log_manager_log_info "📋 Export summary: $export_dir/export_summary.txt"
}

# === START LOG ROTATION DAEMON ===
start_log_rotation_daemon() {
  local interval="${1:-3600}"  # 1 hour default
  
  log_manager_log_info "🔄 Starting log rotation daemon (interval: ${interval}s)"
  
  while true; do
    auto_rotate_logs
    sleep "$interval"
  done
}

# === GENERATE LOG REPORT ===
generate_log_report() {
  local report_file="${LOGS_DIR}/log_report.txt"
  
  log_manager_log_info "📋 Generating log management report..."
  
  {
    echo "T3RN EXECUTOR LOG MANAGEMENT REPORT"
    echo "Generated: $(date)"
    echo "========================================"
    echo ""
    
    echo "Log Configuration:"
    echo "  📁 Logs Directory: $LOGS_DIR"
    echo "  🔄 Rotation Size: $LOG_ROTATION_SIZE"
    echo "  📅 Retention Days: $LOG_RETENTION_DAYS"
    echo "  📝 Log Format: $LOG_FORMAT"
    echo "  💾 Log to File: $LOG_TO_FILE"
    echo "  🎨 Color Output: $ENABLE_COLOR_OUTPUT"
    echo "  😀 Emoji Logging: $ENABLE_EMOJI_LOGGING"
    echo ""
    
    echo "Current Log Files:"
    if [[ -d "$LOGS_DIR" ]]; then
      for log_file in "$LOGS_DIR"/*.log; do
        if [[ -f "$log_file" ]]; then
          local size=$(get_log_file_size "$log_file")
          local size_human=$(numfmt --to=iec "$size" 2>/dev/null || echo "${size} bytes")
          local lines=$(wc -l < "$log_file" 2>/dev/null || echo "0")
          echo "  📄 $(basename "$log_file"): $lines lines, $size_human"
        fi
      done
    else
      echo "  ❌ Logs directory not found"
    fi
    echo ""
    
    echo "Archive Status:"
    if [[ -d "$LOGS_DIR/archive" ]]; then
      local archive_count=$(ls -1 "$LOGS_DIR/archive"/*.log* 2>/dev/null | wc -l)
      echo "  📁 Archive Directory: EXISTS"
      echo "  📊 Archived Files: $archive_count"
      if [[ $archive_count -gt 0 ]]; then
        local total_size=$(du -sb "$LOGS_DIR/archive" 2>/dev/null | cut -f1)
        local total_size_human=$(numfmt --to=iec "$total_size" 2>/dev/null || echo "${total_size} bytes")
        echo "  💾 Total Archive Size: $total_size_human"
      fi
    else
      echo "  📁 Archive Directory: NOT FOUND"
    fi
    echo ""
    
    echo "Daily Logs Status:"
    if [[ -d "$LOGS_DIR/daily" ]]; then
      local daily_count=$(ls -1 "$LOGS_DIR/daily"/*.log* 2>/dev/null | wc -l)
      echo "  📁 Daily Directory: EXISTS"
      echo "  📊 Daily Files: $daily_count"
    else
      echo "  📁 Daily Directory: NOT FOUND"
    fi
    echo ""
    
  } > "$report_file"
  
  log_manager_log_info "✅ Log report saved: $report_file"
}

# === GET LOG STATUS ===
get_log_status() {
  local main_log="$LOGS_DIR/executor.log"
  
  if [[ -f "$main_log" ]]; then
    local size=$(get_log_file_size "$main_log")
    local lines=$(wc -l < "$main_log" 2>/dev/null || echo "0")
    echo "ACTIVE: $lines lines, $size bytes"
  else
    echo "NOT_FOUND"
  fi
}

# === VALIDATE LOG CONFIGURATION ===
validate_log_configuration() {
  log_manager_log_info "🔍 Validating log configuration..."
  
  # Check logs directory
  if [[ ! -d "$LOGS_DIR" ]]; then
    log_manager_log_warn "❌ Logs directory not found: $LOGS_DIR"
    return 1
  fi
  
  # Check write permissions
  if [[ ! -w "$LOGS_DIR" ]]; then
    log_manager_log_warn "❌ No write permission to logs directory"
    return 1
  fi
  
  # Check rotation size format
  local size_bytes=$(convert_size_to_bytes "$LOG_ROTATION_SIZE")
  if [[ $size_bytes -eq 0 ]]; then
    log_manager_log_warn "❌ Invalid log rotation size: $LOG_ROTATION_SIZE"
    return 1
  fi
  
  # Check retention days
  if [[ ! "$LOG_RETENTION_DAYS" =~ ^[0-9]+$ ]]; then
    log_manager_log_warn "❌ Invalid log retention days: $LOG_RETENTION_DAYS"
    return 1
  fi
  
  log_manager_log_info "✅ Log configuration validated"
  return 0
}

# Initialize on load
initialize_log_manager

# Export functions
export -f initialize_log_manager
export -f write_log
export -f log_debug
export -f log_info
export -f log_warn
export -f log_error
export -f log_fatal
export -f rotate_log_file
export -f auto_rotate_logs
export -f cleanup_old_logs
export -f create_daily_log
export -f tail_log
export -f grep_log
export -f get_log_statistics
export -f monitor_log
export -f compress_log
export -f decompress_log
export -f export_logs
export -f start_log_rotation_daemon
export -f generate_log_report
export -f get_log_status
export -f validate_log_configuration
