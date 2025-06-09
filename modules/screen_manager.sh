#!/bin/bash
set -euo pipefail

# ╔══════════════════════════════════════════════════════════════╗
# ║                    T3RN SCREEN MANAGER                      ║
# ║                  (Screen Session Management)                ║
# ╚══════════════════════════════════════════════════════════════╝

# T3RN Executor Screen Manager
# Advanced screen session management with health monitoring and auto-restart
#
# @author Rokhanz
# @license MIT
# @version 1.0.0

# === INTERNAL ERROR HANDLING ===
screen_error_exit() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] SCREEN ERROR: $*" >&2
  exit 1
}

screen_log_info() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] SCREEN INFO: $*"
}

screen_log_warn() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] SCREEN WARN: $*"
}

# === INITIALIZE SCREEN MANAGER ===
initialize_screen_manager() {
  if [[ -z "${SCRIPT_DIR:-}" ]]; then
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")"/.. && pwd)"
    export SCRIPT_DIR
  fi
  
  if [[ -z "${LOGS_DIR:-}" ]]; then
    LOGS_DIR="$SCRIPT_DIR/logs"
    export LOGS_DIR
  fi
  
  mkdir -p "$LOGS_DIR" || screen_error_exit "Cannot create logs directory"
  
  # Load .env for screen configuration
  if [[ -f "$SCRIPT_DIR/.env" ]]; then
    source "$SCRIPT_DIR/.env" 2>/dev/null || true
  fi
  
  # Screen configuration
  T3RN_SCREEN_NAME="${T3RN_SCREEN_NAME:-t3rn-executor}"
  SCREEN_LOG_FILE="${SCREEN_LOG_FILE:-$LOGS_DIR/screen.log}"
  ENABLE_SCREEN_LOGGING="${ENABLE_SCREEN_LOGGING:-true}"
  SCREEN_SHELL="${SCREEN_SHELL:-/bin/bash}"
  
  # Check if screen is available
  if ! command -v screen >/dev/null 2>&1; then
    screen_error_exit "screen command not found. Install with: sudo apt install screen -y"
  fi
  
  screen_log_info "📺 Screen manager initialized"
}

# === CHECK SCREEN SESSION EXISTS ===
screen_session_exists() {
  local session_name="${1:-$T3RN_SCREEN_NAME}"
  
  screen -list 2>/dev/null | grep -q "\.${session_name}[[:space:]]"
}

# === GET SCREEN SESSION STATUS ===
get_screen_session_status() {
  local session_name="${1:-$T3RN_SCREEN_NAME}"
  
  if screen_session_exists "$session_name"; then
    local status=$(screen -list 2>/dev/null | grep "\.${session_name}[[:space:]]" | awk '{print $2}' | tr -d '()')
    echo "$status"
  else
    echo "not_found"
  fi
}

# === LIST ALL SCREEN SESSIONS ===
list_screen_sessions() {
  screen_log_info "📋 Listing all screen sessions..."
  
  local sessions=$(screen -list 2>/dev/null | grep -E "^\s+[0-9]+\." || echo "")
  
  if [[ -z "$sessions" ]]; then
    screen_log_info "   No screen sessions found"
    return 0
  fi
  
  echo "$sessions" | while read -r line; do
    local session_id=$(echo "$line" | awk '{print $1}')
    local session_status=$(echo "$line" | awk '{print $2}' | tr -d '()')
    local session_date=$(echo "$line" | awk '{for(i=3;i<=NF;i++) printf "%s ", $i; print ""}' | sed 's/[()]//' | xargs)
    
    if [[ "$session_id" =~ "$T3RN_SCREEN_NAME" ]]; then
      screen_log_info "   🎯 $session_id ($session_status) - $session_date [T3RN]"
    else
      screen_log_info "   📺 $session_id ($session_status) - $session_date"
    fi
  done
}

# === CREATE SCREEN SESSION ===
create_screen_session() {
  local session_name="${1:-$T3RN_SCREEN_NAME}"
  local command="${2:-$SCREEN_SHELL}"
  local working_dir="${3:-$SCRIPT_DIR}"
  
  screen_log_info "🚀 Creating screen session: $session_name"
  
  # Check if session already exists
  if screen_session_exists "$session_name"; then
    screen_log_warn "⚠️ Screen session already exists: $session_name"
    return 1
  fi
  
  # Change to working directory
  cd "$working_dir" || screen_error_exit "Cannot change to directory: $working_dir"
  
  # Create screen session with logging if enabled
  if [[ "${ENABLE_SCREEN_LOGGING}" == "true" ]]; then
    screen -dmS "$session_name" -L -Logfile "$SCREEN_LOG_FILE" "$command"
  else
    screen -dmS "$session_name" "$command"
  fi
  
  # Wait a moment for session to start
  sleep 1
  
  # Verify session was created
  if screen_session_exists "$session_name"; then
    screen_log_info "✅ Screen session created successfully: $session_name"
    return 0
  else
    screen_log_warn "❌ Failed to create screen session: $session_name"
    return 1
  fi
}

# === ATTACH TO SCREEN SESSION ===
attach_screen_session() {
  local session_name="${1:-$T3RN_SCREEN_NAME}"
  
  screen_log_info "🔗 Attaching to screen session: $session_name"
  
  if ! screen_session_exists "$session_name"; then
    screen_log_warn "⚠️ Screen session not found: $session_name"
    return 1
  fi
  
  # Attach to session
  screen -r "$session_name"
}

# === DETACH FROM SCREEN SESSION ===
detach_screen_session() {
  local session_name="${1:-$T3RN_SCREEN_NAME}"
  
  screen_log_info "🔌 Detaching from screen session: $session_name"
  
  if ! screen_session_exists "$session_name"; then
    screen_log_warn "⚠️ Screen session not found: $session_name"
    return 1
  fi
  
  # Send detach command to session
  screen -S "$session_name" -X detach
  
  screen_log_info "✅ Detached from screen session: $session_name"
}

# === SEND COMMAND TO SCREEN SESSION ===
send_command_to_screen() {
  local session_name="$1"
  local command="$2"
  local wait_time="${3:-1}"
  
  screen_log_info "📤 Sending command to screen session $session_name: $command"
  
  if ! screen_session_exists "$session_name"; then
    screen_log_warn "⚠️ Screen session not found: $session_name"
    return 1
  fi
  
  # Send command to screen session
  screen -S "$session_name" -p 0 -X stuff "$command"
  screen -S "$session_name" -p 0 -X stuff $'\n'
  
  # Wait for command to execute
  sleep "$wait_time"
  
  screen_log_info "✅ Command sent to screen session: $session_name"
}

# === KILL SCREEN SESSION ===
kill_screen_session() {
  local session_name="${1:-$T3RN_SCREEN_NAME}"
  
  screen_log_info "🔪 Killing screen session: $session_name"
  
  if ! screen_session_exists "$session_name"; then
    screen_log_warn "⚠️ Screen session not found: $session_name"
    return 1
  fi
  
  # Kill screen session
  screen -S "$session_name" -X quit
  
  # Wait a moment
  sleep 1
  
  # Verify session was killed
  if ! screen_session_exists "$session_name"; then
    screen_log_info "✅ Screen session killed successfully: $session_name"
    return 0
  else
    screen_log_warn "❌ Failed to kill screen session: $session_name"
    return 1
  fi
}

# === START T3RN EXECUTOR IN SCREEN ===
start_t3rn_executor_screen() {
  local session_name="${T3RN_SCREEN_NAME}"
  local executor_script="${1:-$SCRIPT_DIR/main.sh}"
  
  screen_log_info "🚀 Starting T3RN executor in screen session..."
  
  # Kill existing session if it exists
  if screen_session_exists "$session_name"; then
    screen_log_info "🔄 Killing existing session: $session_name"
    kill_screen_session "$session_name"
    sleep 2
  fi
  
  # Create new session
  if create_screen_session "$session_name" "$SCREEN_SHELL" "$SCRIPT_DIR"; then
    # Wait for session to be ready
    sleep 2
    
    # Send executor command
    send_command_to_screen "$session_name" "cd '$SCRIPT_DIR'" 1
    send_command_to_screen "$session_name" "chmod +x '$executor_script'" 1
    send_command_to_screen "$session_name" "'$executor_script'" 2
    
    screen_log_info "✅ T3RN executor started in screen session: $session_name"
    screen_log_info "💡 To attach: screen -r $session_name"
    screen_log_info "💡 To detach: Ctrl+A then D"
    
    return 0
  else
    screen_log_warn "❌ Failed to start T3RN executor in screen"
    return 1
  fi
}

# === STOP T3RN EXECUTOR SCREEN ===
stop_t3rn_executor_screen() {
  local session_name="${T3RN_SCREEN_NAME}"
  
  screen_log_info "🛑 Stopping T3RN executor screen session..."
  
  if screen_session_exists "$session_name"; then
    # Send Ctrl+C to stop executor
    send_command_to_screen "$session_name" $'\003' 2  # Ctrl+C
    
    # Wait for graceful shutdown
    sleep 5
    
    # Kill session
    kill_screen_session "$session_name"
    
    screen_log_info "✅ T3RN executor screen session stopped"
  else
    screen_log_warn "⚠️ T3RN executor screen session not found"
  fi
}

# === RESTART T3RN EXECUTOR SCREEN ===
restart_t3rn_executor_screen() {
  local executor_script="${1:-$SCRIPT_DIR/main.sh}"
  
  screen_log_info "🔄 Restarting T3RN executor screen session..."
  
  stop_t3rn_executor_screen
  sleep 3
  start_t3rn_executor_screen "$executor_script"
}

# === GET SCREEN SESSION INFO ===
get_screen_session_info() {
  local session_name="${1:-$T3RN_SCREEN_NAME}"
  
  if ! screen_session_exists "$session_name"; then
    echo "Session not found"
    return 1
  fi
  
  local session_info=$(screen -list 2>/dev/null | grep "\.${session_name}[[:space:]]")
  local session_id=$(echo "$session_info" | awk '{print $1}')
  local session_status=$(echo "$session_info" | awk '{print $2}' | tr -d '()')
  local session_date=$(echo "$session_info" | awk '{for(i=3;i<=NF;i++) printf "%s ", $i; print ""}' | sed 's/[()]//g' | xargs)
  
  echo "Session ID: $session_id"
  echo "Status: $session_status"
  echo "Created: $session_date"
  
  # Additional info if session is running
  if [[ "$session_status" == "Attached" || "$session_status" == "Detached" ]]; then
    local pid=$(echo "$session_id" | cut -d'.' -f1)
    if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null; then
      echo "PID: $pid"
      echo "CPU: $(ps -p "$pid" -o %cpu --no-headers 2>/dev/null | xargs || echo "N/A")"
      echo "Memory: $(ps -p "$pid" -o %mem --no-headers 2>/dev/null | xargs || echo "N/A")"
      echo "Runtime: $(ps -p "$pid" -o etime --no-headers 2>/dev/null | xargs || echo "N/A")"
    fi
  fi
}

# === MONITOR SCREEN SESSION ===
monitor_screen_session() {
  local session_name="${1:-$T3RN_SCREEN_NAME}"
  local interval="${2:-10}"
  
  screen_log_info "👁️ Monitoring screen session: $session_name (interval: ${interval}s)"
  
  while true; do
    if screen_session_exists "$session_name"; then
      local status=$(get_screen_session_status "$session_name")
      local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
      
      echo "[$timestamp] Session $session_name: $status"
      
      # Show additional info every 5 checks
      if [[ $(($(date +%s) % 50)) -eq 0 ]]; then
        get_screen_session_info "$session_name"
        echo ""
      fi
    else
      echo "[$timestamp] Session $session_name: NOT FOUND"
      screen_log_warn "⚠️ Screen session disappeared: $session_name"
      break
    fi
    
    sleep "$interval"
  done
}

# === CAPTURE SCREEN SESSION OUTPUT ===
capture_screen_output() {
  local session_name="${1:-$T3RN_SCREEN_NAME}"
  local output_file="${2:-$LOGS_DIR/screen_capture.txt}"
  local lines="${3:-100}"
  
  screen_log_info "📸 Capturing screen output: $session_name"
  
  if ! screen_session_exists "$session_name"; then
    screen_log_warn "⚠️ Screen session not found: $session_name"
    return 1
  fi
  
  # Capture screen content
  screen -S "$session_name" -p 0 -X hardcopy "$output_file"
  
  if [[ -f "$output_file" ]]; then
    # Show last N lines
    tail -n "$lines" "$output_file"
    screen_log_info "✅ Screen output captured to: $output_file"
    return 0
  else
    screen_log_warn "❌ Failed to capture screen output"
    return 1
  fi
}

# === SCREEN SESSION HEALTH CHECK ===
screen_health_check() {
  local session_name="${1:-$T3RN_SCREEN_NAME}"
  
  screen_log_info "🏥 Performing health check for screen session: $session_name"
  
  if ! screen_session_exists "$session_name"; then
    screen_log_warn "❌ Health check failed: Session not found"
    return 1
  fi
  
  local status=$(get_screen_session_status "$session_name")
  
  case "$status" in
    "Attached")
      screen_log_info "✅ Health check passed: Session is attached"
      return 0
      ;;
    "Detached")
      screen_log_info "✅ Health check passed: Session is detached (running in background)"
      return 0
      ;;
    "Dead")
      screen_log_warn "❌ Health check failed: Session is dead"
      return 1
      ;;
    *)
      screen_log_warn "⚠️ Health check uncertain: Unknown status ($status)"
      return 1
      ;;
  esac
}

# === CLEANUP DEAD SCREEN SESSIONS ===
cleanup_dead_screen_sessions() {
  screen_log_info "🧹 Cleaning up dead screen sessions..."
  
  # Get list of dead sessions
  local dead_sessions=$(screen -list 2>/dev/null | grep "Dead" | awk '{print $1}' || echo "")
  
  if [[ -z "$dead_sessions" ]]; then
    screen_log_info "   No dead sessions found"
    return 0
  fi
  
  local cleaned_count=0
  
  echo "$dead_sessions" | while read -r session_id; do
    if [[ -n "$session_id" ]]; then
      screen_log_info "🗑️ Cleaning dead session: $session_id"
      screen -S "$session_id" -X quit 2>/dev/null || true
      ((cleaned_count++))
    fi
  done
  
  # Run screen cleanup
  screen -wipe >/dev/null 2>&1 || true
  
  screen_log_info "✅ Cleaned up dead screen sessions"
}

# === GENERATE SCREEN REPORT ===
generate_screen_report() {
  local report_file="${LOGS_DIR}/screen_report.txt"
  
  screen_log_info "📋 Generating screen report..."
  
  {
    echo "T3RN EXECUTOR SCREEN REPORT"
    echo "Generated: $(date)"
    echo "========================================"
    echo ""
    
    echo "Screen Configuration:"
    echo "  📺 Session Name: $T3RN_SCREEN_NAME"
    echo "  📝 Log File: $SCREEN_LOG_FILE"
    echo "  📊 Logging Enabled: $ENABLE_SCREEN_LOGGING"
    echo "  🐚 Shell: $SCREEN_SHELL"
    echo ""
    
    echo "Screen Status:"
    if command -v screen >/dev/null 2>&1; then
      echo "  ✅ Screen Command: Available"
      echo "  📋 Version: $(screen -v 2>&1 | head -1 || echo "unknown")"
    else
      echo "  ❌ Screen Command: NOT FOUND"
    fi
    echo ""
    
    echo "T3RN Session Status:"
    if screen_session_exists "$T3RN_SCREEN_NAME"; then
      echo "  ✅ Session: EXISTS"
      get_screen_session_info "$T3RN_SCREEN_NAME" | sed 's/^/  /'
    else
      echo "  ❌ Session: NOT FOUND"
    fi
    echo ""
    
    echo "All Screen Sessions:"
    local all_sessions=$(screen -list 2>/dev/null | grep -E "^\s+[0-9]+\." || echo "")
    if [[ -n "$all_sessions" ]]; then
      echo "$all_sessions" | sed 's/^/  /'
    else
      echo "  No sessions found"
    fi
    echo ""
    
    if [[ -f "$SCREEN_LOG_FILE" ]]; then
      echo "Screen Log File:"
      echo "  📁 File: EXISTS"
      echo "  📊 Size: $(stat -c%s "$SCREEN_LOG_FILE" 2>/dev/null || echo "unknown") bytes"
      echo "  📅 Modified: $(stat -c%y "$SCREEN_LOG_FILE" 2>/dev/null || echo "unknown")"
      echo "  📋 Lines: $(wc -l < "$SCREEN_LOG_FILE" 2>/dev/null || echo "unknown")"
    else
      echo "Screen Log File:"
      echo "  📁 File: NOT FOUND"
    fi
    echo ""
    
  } > "$report_file"
  
  screen_log_info "✅ Screen report saved: $report_file"
}

# === GET SCREEN STATUS ===
get_screen_status() {
  local session_name="${T3RN_SCREEN_NAME}"
  
  if screen_session_exists "$session_name"; then
    local status=$(get_screen_session_status "$session_name")
    echo "ACTIVE: $status"
  else
    echo "NOT_FOUND"
  fi
}

# === VALIDATE SCREEN CONFIGURATION ===
validate_screen_configuration() {
  screen_log_info "🔍 Validating screen configuration..."
  
  # Check if screen command is available
  if ! command -v screen >/dev/null 2>&1; then
    screen_log_warn "❌ screen command not found"
    return 1
  fi
  
  # Check screen session name
  if [[ -z "$T3RN_SCREEN_NAME" ]]; then
    screen_log_warn "❌ T3RN_SCREEN_NAME not set"
    return 1
  fi
  
  # Check logs directory
  if [[ ! -d "$LOGS_DIR" ]]; then
    screen_log_warn "❌ Logs directory not found: $LOGS_DIR"
    return 1
  fi
  
  # Check write permissions
  if [[ ! -w "$LOGS_DIR" ]]; then
    screen_log_warn "❌ No write permission to logs directory"
    return 1
  fi
  
  # Test screen functionality
  local test_session="test_screen_$$"
  if screen -dmS "$test_session" echo "test" 2>/dev/null; then
    screen -S "$test_session" -X quit 2>/dev/null || true
    screen_log_info "✅ Screen functionality test passed"
  else
    screen_log_warn "❌ Screen functionality test failed"
    return 1
  fi
  
  screen_log_info "✅ Screen configuration validated"
  return 0
}

# === SCREEN QUICK ACTIONS ===
screen_quick_status() {
  echo "T3RN Screen Quick Status:"
  echo "========================"
  echo "Session Name: $T3RN_SCREEN_NAME"
  echo "Status: $(get_screen_status)"
  
  if screen_session_exists "$T3RN_SCREEN_NAME"; then
    echo ""
    get_screen_session_info "$T3RN_SCREEN_NAME"
  fi
}

screen_quick_attach() {
  if screen_session_exists "$T3RN_SCREEN_NAME"; then
    echo "Attaching to T3RN screen session..."
    attach_screen_session "$T3RN_SCREEN_NAME"
  else
    echo "T3RN screen session not found. Starting new session..."
    start_t3rn_executor_screen
  fi
}

screen_quick_logs() {
  local lines="${1:-50}"
  
  echo "T3RN Screen Logs (last $lines lines):"
  echo "====================================="
  
  if [[ -f "$SCREEN_LOG_FILE" ]]; then
    tail -n "$lines" "$SCREEN_LOG_FILE"
  else
    echo "Screen log file not found: $SCREEN_LOG_FILE"
  fi
}

# Initialize on load
initialize_screen_manager

# Export functions
export -f initialize_screen_manager
export -f screen_session_exists
export -f get_screen_session_status
export -f list_screen_sessions
export -f create_screen_session
export -f attach_screen_session
export -f detach_screen_session
export -f send_command_to_screen
export -f kill_screen_session
export -f start_t3rn_executor_screen
export -f stop_t3rn_executor_screen
export -f restart_t3rn_executor_screen
export -f get_screen_session_info
export -f monitor_screen_session
export -f capture_screen_output
export -f screen_health_check
export -f cleanup_dead_screen_sessions
export -f generate_screen_report
export -f get_screen_status
export -f validate_screen_configuration
export -f screen_quick_status
export -f screen_quick_attach
export -f screen_quick_logs
