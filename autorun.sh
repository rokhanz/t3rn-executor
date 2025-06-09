#!/bin/bash
set -euo pipefail

# ╔══════════════════════════════════════════════════════════════╗
# ║                    T3RN EXECUTOR AUTORUN                    ║
# ║                  (Automated Execution Script)              ║
# ╚══════════════════════════════════════════════════════════════╝

# T3RN Executor Autorun Script
# Automated execution with monitoring, restart capabilities, and comprehensive logging
#
# @author Rokhanz
# @license MIT
# @version 1.0.0

# === SCRIPT INITIALIZATION ===
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT_NAME="$(basename "${BASH_SOURCE[0]}")"
SCRIPT_VERSION="1.0.0"

# === INTERNAL ERROR HANDLING ===
autorun_error_exit() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] AUTORUN ERROR: $*" >&2
  exit 1
}

autorun_log_info() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] AUTORUN INFO: $*"
}

autorun_log_warn() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] AUTORUN WARN: $*"
}

# === LOAD MODULES ===
load_required_modules() {
  autorun_log_info "📦 Loading required modules..."
  
  # Load environment configuration
  if [[ -f "$SCRIPT_DIR/modules/env_loader.sh" ]]; then
    source "$SCRIPT_DIR/modules/env_loader.sh" || autorun_error_exit "Failed to load env_loader.sh"
    autorun_log_info "✅ Environment loader loaded"
  else
    autorun_error_exit "env_loader.sh not found"
  fi
  
  # Load validation module
  if [[ -f "$SCRIPT_DIR/modules/validation.sh" ]]; then
    source "$SCRIPT_DIR/modules/validation.sh" || autorun_error_exit "Failed to load validation.sh"
    autorun_log_info "✅ Validation module loaded"
  else
    autorun_error_exit "validation.sh not found"
  fi
  
  # Load screen manager
  if [[ -f "$SCRIPT_DIR/modules/screen_manager.sh" ]]; then
    source "$SCRIPT_DIR/modules/screen_manager.sh" || autorun_error_exit "Failed to load screen_manager.sh"
    autorun_log_info "✅ Screen manager loaded"
  else
    autorun_error_exit "screen_manager.sh not found"
  fi
  
  # Load progress bar for visual feedback
  if [[ -f "$SCRIPT_DIR/modules/progress_bar_batch.sh" ]]; then
    source "$SCRIPT_DIR/modules/progress_bar_batch.sh" 2>/dev/null || true
    autorun_log_info "✅ Progress bar loaded"
  fi
  
  # Load dependency checker
  if [[ -f "$SCRIPT_DIR/modules/dependency_checker.sh" ]]; then
    source "$SCRIPT_DIR/modules/dependency_checker.sh" || autorun_error_exit "Failed to load dependency_checker.sh"
    autorun_log_info "✅ Dependency checker loaded"
  fi
  
  # Load downloader
  if [[ -f "$SCRIPT_DIR/modules/downloader.sh" ]]; then
    source "$SCRIPT_DIR/modules/downloader.sh" || autorun_error_exit "Failed to load downloader.sh"
    autorun_log_info "✅ Downloader loaded"
  fi
  
  # Load monitoring
  if [[ -f "$SCRIPT_DIR/modules/all_monitor.sh" ]]; then
    source "$SCRIPT_DIR/modules/all_monitor.sh" 2>/dev/null || true
    autorun_log_info "✅ Monitoring module loaded"
  fi
}

# === INITIALIZE AUTORUN ===
initialize_autorun() {
  autorun_log_info "🚀 Initializing T3RN Executor Autorun v$SCRIPT_VERSION"
  autorun_log_info "📁 Script directory: $SCRIPT_DIR"
  autorun_log_info "👤 Running as user: $(whoami)"
  autorun_log_info "🖥️ System: $(uname -s) $(uname -m)"
  
  # Create necessary directories
  mkdir -p "$SCRIPT_DIR/logs" || autorun_error_exit "Cannot create logs directory"
  
  # Load modules
  load_required_modules
  
  # Load environment configuration
  autorun_log_info "🔧 Loading environment configuration..."
  if ! load_environment "$SCRIPT_DIR/.env" true; then
    autorun_error_exit "Failed to load environment configuration"
  fi
  
  autorun_log_info "✅ Autorun initialization completed"
}

# === PRE-EXECUTION CHECKS ===
run_pre_execution_checks() {
  autorun_log_info "🔍 Running pre-execution checks..."
  
  # System dependencies check
  autorun_log_info "📦 Checking system dependencies..."
  if command -v check_all_dependencies >/dev/null 2>&1; then
    if ! check_all_dependencies >/dev/null 2>&1; then
      autorun_log_warn "⚠️ Some dependencies are missing, attempting to install..."
      if command -v auto_install_dependencies >/dev/null 2>&1; then
        auto_install_dependencies || autorun_log_warn "⚠️ Dependency installation failed"
      fi
    fi
  fi
  
  # Environment validation
  autorun_log_info "🔧 Validating environment configuration..."
  if command -v validate_env_configuration >/dev/null 2>&1; then
    if ! validate_env_configuration; then
      autorun_error_exit "Environment validation failed"
    fi
  fi
  
  # Network configuration validation
  autorun_log_info "🌐 Validating network configuration..."
  if command -v validate_network_configuration >/dev/null 2>&1; then
    if ! validate_network_configuration; then
      autorun_error_exit "Network configuration validation failed"
    fi
  fi
  
  # Executor binary check
  autorun_log_info "⚙️ Checking executor binary..."
  local executor_path="${EXECUTOR_PATH:-$SCRIPT_DIR/t3rn/executor/executor/bin/executor}"
  
  if [[ ! -f "$executor_path" ]]; then
    autorun_log_warn "⚠️ Executor binary not found, downloading..."
    if command -v download_executor_binary >/dev/null 2>&1; then
      download_executor_binary || autorun_error_exit "Failed to download executor binary"
      extract_executor_binary || autorun_error_exit "Failed to extract executor binary"
      set_permissions_and_validate || autorun_error_exit "Failed to set permissions"
    else
      autorun_error_exit "Downloader module not available"
    fi
  fi
  
  # Validate executor binary
  if command -v validate_executor_binary >/dev/null 2>&1; then
    if ! validate_executor_binary; then
      autorun_error_exit "Executor binary validation failed"
    fi
  fi
  
  autorun_log_info "✅ Pre-execution checks completed"
}

# === SETUP EXECUTION ENVIRONMENT ===
setup_execution_environment() {
  autorun_log_info "🔧 Setting up execution environment..."
  
  # Setup RPC endpoints
  autorun_log_info "🌐 Setting up RPC endpoints..."
  if command -v setup_rpc_endpoints_from_env >/dev/null 2>&1; then
    setup_rpc_endpoints_from_env || autorun_log_warn "⚠️ RPC setup failed"
  fi
  
  # Setup proxy system if enabled
  if [[ "${USE_PROXY:-false}" == "true" ]]; then
    autorun_log_info "🔄 Setting up proxy system..."
    if command -v setup_proxy_system >/dev/null 2>&1; then
      setup_proxy_system || autorun_log_warn "⚠️ Proxy setup failed"
    fi
  fi
  
  # Setup wallet security
  autorun_log_info "🔐 Setting up wallet security..."
  if command -v secure_wallet_setup >/dev/null 2>&1; then
    secure_wallet_setup || autorun_log_warn "⚠️ Wallet security setup failed"
  fi
  
  # Setup monitoring if enabled
  if [[ "${ENABLE_MONITORING:-true}" == "true" ]]; then
    autorun_log_info "📊 Starting monitoring services..."
    if command -v start_all_monitoring >/dev/null 2>&1; then
      start_all_monitoring &
      autorun_log_info "✅ Monitoring services started in background"
    fi
  fi
  
  autorun_log_info "✅ Execution environment setup completed"
}

# === EXECUTION MODES ===

# Screen mode execution
execute_screen_mode() {
  autorun_log_info "📺 Starting executor in screen mode..."
  
  local session_name="${T3RN_SCREEN_NAME:-t3rn-executor}"
  local main_script="$SCRIPT_DIR/main.sh"
  
  # Check if main.sh exists
  if [[ ! -f "$main_script" ]]; then
    autorun_error_exit "main.sh not found: $main_script"
  fi
  
  # Start in screen session
  if command -v start_t3rn_executor_screen >/dev/null 2>&1; then
    start_t3rn_executor_screen "$main_script"
    
    autorun_log_info "✅ Executor started in screen session: $session_name"
    autorun_log_info "💡 To attach to session: screen -r $session_name"
    autorun_log_info "💡 To detach from session: Ctrl+A then D"
    autorun_log_info "💡 To view logs: tail -f $SCRIPT_DIR/logs/executor.log"
    
    # Monitor session health
    monitor_screen_session_health "$session_name"
  else
    autorun_error_exit "Screen manager not available"
  fi
}

# Direct mode execution
execute_direct_mode() {
  autorun_log_info "🎯 Starting executor in direct mode..."
  
  local main_script="$SCRIPT_DIR/main.sh"
  
  # Check if main.sh exists
  if [[ ! -f "$main_script" ]]; then
    autorun_error_exit "main.sh not found: $main_script"
  fi
  
  # Make executable
  chmod +x "$main_script"
  
  # Execute directly
  cd "$SCRIPT_DIR" || autorun_error_exit "Cannot change to script directory"
  exec "$main_script"
}

# Background mode execution
execute_background_mode() {
  autorun_log_info "🔄 Starting executor in background mode..."
  
  local main_script="$SCRIPT_DIR/main.sh"
  local log_file="$SCRIPT_DIR/logs/autorun.log"
  local pid_file="$SCRIPT_DIR/autorun.pid"
  
  # Check if main.sh exists
  if [[ ! -f "$main_script" ]]; then
    autorun_error_exit "main.sh not found: $main_script"
  fi
  
  # Make executable
  chmod +x "$main_script"
  
  # Start in background
  cd "$SCRIPT_DIR" || autorun_error_exit "Cannot change to script directory"
  nohup "$main_script" >> "$log_file" 2>&1 &
  local executor_pid=$!
  
  # Save PID
  echo "$executor_pid" > "$pid_file"
  
  autorun_log_info "✅ Executor started in background (PID: $executor_pid)"
  autorun_log_info "💡 To view logs: tail -f $log_file"
  autorun_log_info "💡 To stop: kill $executor_pid"
  
  # Monitor process health
  monitor_background_process_health "$executor_pid"
}

# === MONITORING FUNCTIONS ===

# Monitor screen session health
monitor_screen_session_health() {
  local session_name="$1"
  local check_interval="${HEALTH_CHECK_INTERVAL:-60}"
  
  autorun_log_info "👁️ Starting screen session health monitoring..."
  
  while true; do
    sleep "$check_interval"
    
    if command -v screen_health_check >/dev/null 2>&1; then
      if ! screen_health_check "$session_name"; then
        autorun_log_warn "⚠️ Screen session health check failed"
        
        # Attempt restart if enabled
        if [[ "${ENABLE_AUTO_RESTART:-true}" == "true" ]]; then
          autorun_log_info "🔄 Attempting to restart screen session..."
          if command -v restart_t3rn_executor_screen >/dev/null 2>&1; then
            restart_t3rn_executor_screen "$SCRIPT_DIR/main.sh"
          fi
        fi
      fi
    fi
  done
}

# Monitor background process health
monitor_background_process_health() {
  local pid="$1"
  local check_interval="${HEALTH_CHECK_INTERVAL:-60}"
  
  autorun_log_info "👁️ Starting background process health monitoring..."
  
  while true; do
    sleep "$check_interval"
    
    if ! kill -0 "$pid" 2>/dev/null; then
      autorun_log_warn "⚠️ Background process died (PID: $pid)"
      
      # Attempt restart if enabled
      if [[ "${ENABLE_AUTO_RESTART:-true}" == "true" ]]; then
        autorun_log_info "🔄 Attempting to restart background process..."
        execute_background_mode
        break
      else
        autorun_error_exit "Background process died and auto-restart is disabled"
      fi
    fi
  done
}

# === CLEANUP FUNCTIONS ===
cleanup_autorun() {
  autorun_log_info "🧹 Cleaning up autorun..."
  
  # Stop monitoring services
  if command -v stop_all_monitoring >/dev/null 2>&1; then
    stop_all_monitoring 2>/dev/null || true
  fi
  
  # Cleanup proxy system
  if command -v cleanup_proxy_system >/dev/null 2>&1; then
    cleanup_proxy_system 2>/dev/null || true
  fi
  
  # Kill any background jobs
  jobs -p | xargs -r kill 2>/dev/null || true
  
  autorun_log_info "✅ Autorun cleanup completed"
}

# === SIGNAL HANDLERS ===
setup_signal_handlers() {
  trap 'autorun_log_info "🛑 Received SIGINT, shutting down..."; cleanup_autorun; exit 0' INT
  trap 'autorun_log_info "🛑 Received SIGTERM, shutting down..."; cleanup_autorun; exit 0' TERM
  trap 'cleanup_autorun' EXIT
}

# === USAGE INFORMATION ===
show_usage() {
  cat << EOF
T3RN Executor Autorun v$SCRIPT_VERSION
Author: Rokhanz | License: MIT

Usage: $SCRIPT_NAME [OPTIONS]

OPTIONS:
  -m, --mode MODE       Execution mode: screen, direct, background (default: screen)
  -c, --check           Run pre-execution checks only
  -v, --validate        Validate configuration only
  -s, --status          Show executor status
  -h, --help            Show this help message
  --no-checks           Skip pre-execution checks
  --no-monitoring       Disable monitoring services
  --force               Force execution even if checks fail

EXECUTION MODES:
  screen                Run in screen session (recommended)
  direct                Run directly in current terminal
  background            Run as background daemon

EXAMPLES:
  $SCRIPT_NAME                          # Run in screen mode (default)
  $SCRIPT_NAME -m direct                # Run in direct mode
  $SCRIPT_NAME -m background            # Run in background mode
  $SCRIPT_NAME -c                       # Run checks only
  $SCRIPT_NAME -v                       # Validate configuration only
  $SCRIPT_NAME -s                       # Show status

ENVIRONMENT VARIABLES:
  EXECUTION_MODE                        Default execution mode
  ENABLE_AUTO_RESTART                   Enable automatic restart (default: true)
  HEALTH_CHECK_INTERVAL                 Health check interval in seconds (default: 60)
  ENABLE_MONITORING                     Enable monitoring services (default: true)

EOF
}

# === STATUS FUNCTIONS ===
show_executor_status() {
  autorun_log_info "📊 T3RN Executor Status Report"
  echo "==============================="
  
  # Environment status
  echo "🔧 Environment: $(get_env_status 2>/dev/null || echo "Unknown")"
  
  # Screen session status
  if command -v get_screen_status >/dev/null 2>&1; then
    echo "📺 Screen Session: $(get_screen_status)"
  fi
  
  # Executor binary status
  if command -v get_download_status >/dev/null 2>&1; then
    echo "⚙️ Executor Binary: $(get_download_status)"
  fi
  
  # Monitoring status
  if command -v get_monitoring_status >/dev/null 2>&1; then
    echo "📊 Monitoring: $(get_monitoring_status)"
  fi
  
  # Balance status
  if command -v get_balance_summary >/dev/null 2>&1; then
    echo ""
    echo "💰 Balance Summary:"
    get_balance_summary | sed 's/^/    /'
  fi
  
  # Log file status
  echo ""
  echo "📝 Log Files:"
  for log_file in "$SCRIPT_DIR/logs"/*.log; do
    if [[ -f "$log_file" ]]; then
      local size=$(stat -c%s "$log_file" 2>/dev/null || echo "0")
      local name=$(basename "$log_file")
      echo "    $name: $size bytes"
    fi
  done
}

# === MAIN EXECUTION ===
main() {
  # Default values
  local execution_mode="${EXECUTION_MODE:-screen}"
  local skip_checks=false
  local skip_monitoring=false
  local force_execution=false
  local check_only=false
  local validate_only=false
  local status_only=false
  
  # Parse command line arguments
  while [[ $# -gt 0 ]]; do
    case $1 in
      -m|--mode)
        execution_mode="$2"
        shift 2
        ;;
      -c|--check)
        check_only=true
        shift
        ;;
      -v|--validate)
        validate_only=true
        shift
        ;;
      -s|--status)
        status_only=true
        shift
        ;;
      --no-checks)
        skip_checks=true
        shift
        ;;
      --no-monitoring)
        skip_monitoring=true
        shift
        ;;
      --force)
        force_execution=true
        shift
        ;;
      -h|--help)
        show_usage
        exit 0
        ;;
      *)
        autorun_log_warn "⚠️ Unknown option: $1"
        show_usage
        exit 1
        ;;
    esac
  done
  
  # Setup signal handlers
  setup_signal_handlers
  
  # Initialize
  initialize_autorun
  
  # Handle special modes
  if [[ "$status_only" == "true" ]]; then
    show_executor_status
    exit 0
  fi
  
  if [[ "$validate_only" == "true" ]]; then
    autorun_log_info "🔍 Running validation only..."
    if command -v validate_env_configuration >/dev/null 2>&1; then
      validate_env_configuration
    fi
    exit 0
  fi
  
  # Run pre-execution checks
  if [[ "$skip_checks" != "true" ]]; then
    if ! run_pre_execution_checks && [[ "$force_execution" != "true" ]]; then
      autorun_error_exit "Pre-execution checks failed. Use --force to override."
    fi
  fi
  
  if [[ "$check_only" == "true" ]]; then
    autorun_log_info "✅ Pre-execution checks completed successfully"
    exit 0
  fi
  
  # Setup execution environment
  if [[ "$skip_monitoring" == "true" ]]; then
    export ENABLE_MONITORING=false
  fi
  
  setup_execution_environment
  
  # Execute based on mode
  case "$execution_mode" in
    "screen")
      execute_screen_mode
      ;;
    "direct")
      execute_direct_mode
      ;;
    "background")
      execute_background_mode
      ;;
    *)
      autorun_error_exit "Invalid execution mode: $execution_mode. Valid modes: screen, direct, background"
      ;;
  esac
}

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi
