#!/bin/bash
set -euo pipefail

# ╔══════════════════════════════════════════════════════════════╗
# ║                    T3RN EXECUTOR MAIN                       ║
# ║                  (Main Execution Script)                    ║
# ╚══════════════════════════════════════════════════════════════╝

# T3RN Executor Main Script
# Primary execution script with comprehensive monitoring and error handling
#
# @author Rokhanz
# @license MIT
# @version 1.0.0

# === SCRIPT INITIALIZATION ===
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT_NAME="$(basename "${BASH_SOURCE[0]}")"
SCRIPT_VERSION="1.0.0"
SCRIPT_START_TIME=$(date +%s)

# === INTERNAL ERROR HANDLING ===
main_error_exit() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] MAIN ERROR: $*" >&2
  cleanup_main
  exit 1
}

main_log_info() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] MAIN INFO: $*"
}

main_log_warn() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] MAIN WARN: $*"
}

# === LOAD CORE MODULES ===
load_core_modules() {
  main_log_info "📦 Loading core modules..."
  
  # Load environment loader first
  if [[ -f "$SCRIPT_DIR/modules/env_loader.sh" ]]; then
    source "$SCRIPT_DIR/modules/env_loader.sh" || main_error_exit "Failed to load env_loader.sh"
    main_log_info "✅ Environment loader loaded"
  else
    main_error_exit "env_loader.sh not found"
  fi
  
  # Load environment configuration
  main_log_info "🔧 Loading environment configuration..."
  if ! load_environment "$SCRIPT_DIR/.env" true; then
    main_error_exit "Failed to load environment configuration"
  fi
  
  # Load validation module
  if [[ -f "$SCRIPT_DIR/modules/validation.sh" ]]; then
    source "$SCRIPT_DIR/modules/validation.sh" || main_error_exit "Failed to load validation.sh"
    main_log_info "✅ Validation module loaded"
  fi
  
  # Load executor binary module
  if [[ -f "$SCRIPT_DIR/modules/executor_binary.sh" ]]; then
    source "$SCRIPT_DIR/modules/executor_binary.sh" || main_error_exit "Failed to load executor_binary.sh"
    main_log_info "✅ Executor binary module loaded"
  else
    main_error_exit "executor_binary.sh not found"
  fi
  
  # Load RPC manager
  if [[ -f "$SCRIPT_DIR/modules/rpc_manager.sh" ]]; then
    source "$SCRIPT_DIR/modules/rpc_manager.sh" || main_error_exit "Failed to load rpc_manager.sh"
    main_log_info "✅ RPC manager loaded"
  fi
  
  # Load balance checker
  if [[ -f "$SCRIPT_DIR/modules/balance_checker.sh" ]]; then
    source "$SCRIPT_DIR/modules/balance_checker.sh" || main_error_exit "Failed to load balance_checker.sh"
    main_log_info "✅ Balance checker loaded"
  fi
  
  # Load wallet manager
  if [[ -f "$SCRIPT_DIR/modules/wallet_manager.sh" ]]; then
    source "$SCRIPT_DIR/modules/wallet_manager.sh" || main_error_exit "Failed to load wallet_manager.sh"
    main_log_info "✅ Wallet manager loaded"
  fi
  
  # Load optional modules
  load_optional_modules
}

# === LOAD OPTIONAL MODULES ===
load_optional_modules() {
  main_log_info "📦 Loading optional modules..."
  
  # Load progress bars
  if [[ -f "$SCRIPT_DIR/modules/progress_bar_batch.sh" ]]; then
    source "$SCRIPT_DIR/modules/progress_bar_batch.sh" 2>/dev/null || true
    main_log_info "✅ Progress bar loaded"
  fi
  
  # Load monitoring
  if [[ -f "$SCRIPT_DIR/modules/all_monitor.sh" ]]; then
    source "$SCRIPT_DIR/modules/all_monitor.sh" 2>/dev/null || true
    main_log_info "✅ Monitoring module loaded"
  fi
  
  # Load proxy manager
  if [[ -f "$SCRIPT_DIR/modules/proxy_manager.sh" ]]; then
    source "$SCRIPT_DIR/modules/proxy_manager.sh" 2>/dev/null || true
    main_log_info "✅ Proxy manager loaded"
  fi
  
  # Load anti-MEV
  if [[ -f "$SCRIPT_DIR/modules/anti_mev.sh" ]]; then
    source "$SCRIPT_DIR/modules/anti_mev.sh" 2>/dev/null || true
    main_log_info "✅ Anti-MEV module loaded"
  fi
  
  # Load log manager
  if [[ -f "$SCRIPT_DIR/modules/log_manager.sh" ]]; then
    source "$SCRIPT_DIR/modules/log_manager.sh" 2>/dev/null || true
    main_log_info "✅ Log manager loaded"
  fi
}

# === INITIALIZE MAIN EXECUTION ===
initialize_main() {
  main_log_info "🚀 Initializing T3RN Executor Main v$SCRIPT_VERSION"
  main_log_info "📁 Script directory: $SCRIPT_DIR"
  main_log_info "👤 Running as user: $(whoami)"
  main_log_info "🖥️ System: $(uname -s) $(uname -m)"
  main_log_info "⏰ Start time: $(date)"
  
  # Create necessary directories
  mkdir -p "$SCRIPT_DIR/logs" || main_error_exit "Cannot create logs directory"
  
  # Load core modules
  load_core_modules
  
  # Setup signal handlers
  setup_signal_handlers
  
  main_log_info "✅ Main initialization completed"
}

# === PRE-EXECUTION VALIDATION ===
run_pre_execution_validation() {
  main_log_info "🔍 Running pre-execution validation..."
  
  # Comprehensive validation
  if command -v run_comprehensive_validation >/dev/null 2>&1; then
    if ! run_comprehensive_validation; then
      main_error_exit "Comprehensive validation failed"
    fi
  else
    main_log_warn "⚠️ Comprehensive validation not available"
  fi
  
  # Wallet configuration validation
  if command -v validate_wallet_configuration >/dev/null 2>&1; then
    if ! validate_wallet_configuration; then
      main_error_exit "Wallet configuration validation failed"
    fi
  fi
  
  # Network configuration validation
  if command -v validate_network_configuration >/dev/null 2>&1; then
    if ! validate_network_configuration; then
      main_error_exit "Network configuration validation failed"
    fi
  fi
  
  main_log_info "✅ Pre-execution validation completed"
}

# === SETUP EXECUTION ENVIRONMENT ===
setup_execution_environment() {
  main_log_info "🔧 Setting up execution environment..."
  
  # Setup RPC endpoints
  main_log_info "🌐 Setting up RPC endpoints..."
  if command -v setup_rpc_endpoints_from_env >/dev/null 2>&1; then
    setup_rpc_endpoints_from_env || main_log_warn "⚠️ RPC setup failed"
  fi
  
  # Display RPC configuration
  if command -v display_rpc_configuration >/dev/null 2>&1; then
    display_rpc_configuration
  fi
  
  # Setup proxy system if enabled
  if [[ "${USE_PROXY:-false}" == "true" ]]; then
    main_log_info "🔄 Setting up proxy system..."
    if command -v setup_proxy_system >/dev/null 2>&1; then
      setup_proxy_system || main_log_warn "⚠️ Proxy setup failed"
    fi
  fi
  
  # Setup wallet security
  main_log_info "🔐 Setting up wallet security..."
  if command -v secure_wallet_setup >/dev/null 2>&1; then
    secure_wallet_setup || main_log_warn "⚠️ Wallet security setup failed"
  fi
  
  # Check initial balances
  main_log_info "💰 Checking initial balances..."
  if command -v check_all_network_balances >/dev/null 2>&1; then
    check_all_network_balances || main_log_warn "⚠️ Balance check failed"
  fi
  
  main_log_info "✅ Execution environment setup completed"
}

# === START BACKGROUND SERVICES ===
start_background_services() {
  main_log_info "🔄 Starting background services..."
  
  # Start monitoring services
  if [[ "${ENABLE_MONITORING:-true}" == "true" ]]; then
    main_log_info "📊 Starting monitoring services..."
    if command -v start_all_monitoring >/dev/null 2>&1; then
      start_all_monitoring &
      main_log_info "✅ Monitoring services started"
    fi
  fi
  
  # Start balance monitoring
  if [[ "${ENABLE_BALANCE_MONITORING:-true}" == "true" ]]; then
    main_log_info "💰 Starting balance monitoring..."
    if command -v start_balance_monitoring >/dev/null 2>&1; then
      start_balance_monitoring &
      main_log_info "✅ Balance monitoring started"
    fi
  fi
  
  # Start proxy rotation daemon
  if [[ "${USE_PROXY:-false}" == "true" && "${PROXY_FAILOVER_MODE:-true}" == "true" ]]; then
    main_log_info "🔄 Starting proxy rotation daemon..."
    if command -v start_proxy_rotation_daemon >/dev/null 2>&1; then
      start_proxy_rotation_daemon &
      main_log_info "✅ Proxy rotation daemon started"
    fi
  fi
  
  # Start MEV detector if enabled
  if [[ "${ENABLE_MEV_DETECTION:-false}" == "true" ]]; then
    main_log_info "🛡️ Starting MEV detector..."
    if [[ -f "$SCRIPT_DIR/anti_mev/mev_detector.js" ]] && command -v node >/dev/null 2>&1; then
      cd "$SCRIPT_DIR" && node anti_mev/mev_detector.js &
      main_log_info "✅ MEV detector started"
    fi
  fi
  
  # Start log rotation daemon
  if [[ "${LOG_TO_FILE:-true}" == "true" ]]; then
    main_log_info "📝 Starting log rotation daemon..."
    if command -v start_log_rotation_daemon >/dev/null 2>&1; then
      start_log_rotation_daemon &
      main_log_info "✅ Log rotation daemon started"
    fi
  fi
  
  main_log_info "✅ Background services started"
}

# === MAIN EXECUTOR EXECUTION ===
execute_main_executor() {
  main_log_info "🎯 Starting main executor execution..."
  
  # Send startup notification
  if command -v send_notification >/dev/null 2>&1; then
    local wallet_address=""
    if command -v derive_wallet_address >/dev/null 2>&1; then
      wallet_address=$(derive_wallet_address 2>/dev/null || echo "Unknown")
    fi
    
    local startup_message="🚀 <b>T3RN EXECUTOR STARTED</b> 🚀%0A"
    startup_message+="%0A🌐 <b>Networks:</b> ${ENABLED_NETWORKS}%0A"
    startup_message+="%0A💰 <b>Min Balance:</b> ${EXECUTOR_MIN_BALANCE_THRESHOLD_ETH:-0.5} ETH%0A"
    startup_message+="%0A📱 <b>Notifications:</b> ${NOTIFICATION_LEVEL:-error}%0A"
    startup_message+="%0A🎯 <b>Rich Reporting:</b> ${ENABLE_RICH_NOTIFICATIONS:-true}%0A"
    startup_message+="%0A🔑 <b>Wallet:</b> <code>${wallet_address:0:6}...${wallet_address: -4}</code>%0A"
    startup_message+="%0A⏰ <b>Time:</b> $(date '+%H:%M:%S')%0A"
    startup_message+="%0A📅 <b>Date:</b> $(date '+%Y-%m-%d')"
    
    send_notification "info" "$startup_message"
  fi
  
  # Execute with autorestart
  if command -v start_executor_with_autorestart >/dev/null 2>&1; then
    start_executor_with_autorestart
  else
    main_error_exit "Executor binary module not available"
  fi
}

# === SIGNAL HANDLERS ===
setup_signal_handlers() {
  trap 'main_log_info "🛑 Received SIGINT, shutting down gracefully..."; cleanup_main; exit 0' INT
  trap 'main_log_info "🛑 Received SIGTERM, shutting down gracefully..."; cleanup_main; exit 0' TERM
  trap 'cleanup_main' EXIT
}

# === CLEANUP FUNCTION ===
cleanup_main() {
  main_log_info "🧹 Cleaning up main execution..."
  
  local cleanup_start_time=$(date +%s)
  
  # Stop executor
  if command -v stop_executor >/dev/null 2>&1; then
    stop_executor 2>/dev/null || true
  fi
  
  # Stop monitoring services
  if command -v stop_all_monitoring >/dev/null 2>&1; then
    stop_all_monitoring 2>/dev/null || true
  fi
  
  # Stop proxy rotation daemon
  if command -v stop_proxy_rotation_daemon >/dev/null 2>&1; then
    stop_proxy_rotation_daemon 2>/dev/null || true
  fi
  
  # Cleanup proxy system
  if command -v cleanup_proxy_system >/dev/null 2>&1; then
    cleanup_proxy_system 2>/dev/null || true
  fi
  
  # Cleanup wallet cache
  if command -v cleanup_wallet_cache >/dev/null 2>&1; then
    cleanup_wallet_cache 2>/dev/null || true
  fi
  
  # Kill any remaining background jobs
  jobs -p | xargs -r kill 2>/dev/null || true
  
  # Send shutdown notification
  if command -v send_notification >/dev/null 2>&1; then
    local runtime=$(($(date +%s) - SCRIPT_START_TIME))
    local runtime_formatted=$(printf "%02d:%02d:%02d" $((runtime/3600)) $((runtime%3600/60)) $((runtime%60)))
    
    local shutdown_message="🛑 <b>T3RN EXECUTOR SHUTDOWN</b> 🛑%0A"
    shutdown_message+="%0A⏱️ <b>Runtime:</b> $runtime_formatted%0A"
    shutdown_message+="%0A⏰ <b>Shutdown Time:</b> $(date '+%H:%M:%S')%0A"
    shutdown_message+="%0A📅 <b>Date:</b> $(date '+%Y-%m-%d')"
    
    send_notification "info" "$shutdown_message"
  fi
  
  # Generate final reports
  generate_final_reports
  
  local cleanup_time=$(($(date +%s) - cleanup_start_time))
  main_log_info "✅ Main cleanup completed in ${cleanup_time}s"
}

# === GENERATE FINAL REPORTS ===
generate_final_reports() {
  main_log_info "📋 Generating final reports..."
  
  # Generate wallet report
  if command -v generate_wallet_report >/dev/null 2>&1; then
    generate_wallet_report 2>/dev/null || true
  fi
  
  # Generate balance report
  if command -v generate_balance_report >/dev/null 2>&1; then
    generate_balance_report 2>/dev/null || true
  fi
  
  # Generate proxy report
  if command -v generate_proxy_report >/dev/null 2>&1; then
    generate_proxy_report 2>/dev/null || true
  fi
  
  # Generate log report
  if command -v generate_log_report >/dev/null 2>&1; then
    generate_log_report 2>/dev/null || true
  fi
  
  # Generate execution summary
  generate_execution_summary
}

# === GENERATE EXECUTION SUMMARY ===
generate_execution_summary() {
  local summary_file="$SCRIPT_DIR/logs/execution_summary.txt"
  local runtime=$(($(date +%s) - SCRIPT_START_TIME))
  local runtime_formatted=$(printf "%02d:%02d:%02d" $((runtime/3600)) $((runtime%3600/60)) $((runtime%60)))
  
  {
    echo "T3RN EXECUTOR EXECUTION SUMMARY"
    echo "Generated: $(date)"
    echo "========================================"
    echo ""
    
    echo "Execution Information:"
    echo "  🚀 Script Version: $SCRIPT_VERSION"
    echo "  📁 Script Directory: $SCRIPT_DIR"
    echo "  👤 User: $(whoami)"
    echo "  🖥️ System: $(uname -s) $(uname -m)"
    echo "  ⏰ Start Time: $(date -d @$SCRIPT_START_TIME)"
    echo "  🏁 End Time: $(date)"
    echo "  ⏱️ Total Runtime: $runtime_formatted"
    echo ""
    
    echo "Configuration Summary:"
    echo "  🌐 Enabled Networks: ${ENABLED_NETWORKS:-not set}"
    echo "  🔧 Environment: ${ENVIRONMENT:-not set}"
    echo "  📊 Log Level: ${LOG_LEVEL:-not set}"
    echo "  💰 Min Balance Threshold: ${EXECUTOR_MIN_BALANCE_THRESHOLD_ETH:-0.5} ETH"
    echo "  📱 Notifications: ${ENABLE_NOTIFICATIONS:-false}"
    echo "  🎯 Rich Notifications: ${ENABLE_RICH_NOTIFICATIONS:-true}"
    echo "  🔄 Proxy Usage: ${USE_PROXY:-false}"
    echo "  🛡️ Anti-MEV: ${ENABLE_ANTI_MEV:-false}"
    echo ""
    
    echo "Service Status:"
    echo "  📊 Monitoring: ${ENABLE_MONITORING:-true}"
    echo "  💰 Balance Monitoring: ${ENABLE_BALANCE_MONITORING:-true}"
    echo "  📝 Log Rotation: ${LOG_TO_FILE:-true}"
    echo "  🔄 Proxy Rotation: ${PROXY_FAILOVER_MODE:-false}"
    echo "  🛡️ MEV Detection: ${ENABLE_MEV_DETECTION:-false}"
    echo ""
    
    echo "Final Status:"
    if command -v get_wallet_status >/dev/null 2>&1; then
      echo "  🔑 Wallet: $(get_wallet_status)"
    fi
    
    if command -v get_balance_summary >/dev/null 2>&1; then
      echo "  💰 Final Balances:"
      get_balance_summary | sed 's/^/      /'
    fi
    
    echo ""
    echo "Log Files Generated:"
    for log_file in "$SCRIPT_DIR/logs"/*.{log,txt,json} 2>/dev/null; do
      if [[ -f "$log_file" ]]; then
        local size=$(stat -c%s "$log_file" 2>/dev/null || echo "0")
        local name=$(basename "$log_file")
        echo "  📄 $name: $size bytes"
      fi
    done
    echo ""
    
  } > "$summary_file"
  
  main_log_info "✅ Execution summary saved: $summary_file"
}

# === HEALTH CHECK FUNCTION ===
run_health_check() {
  main_log_info "🏥 Running health check..."
  
  local health_issues=()
  
  # Check executor binary
  if command -v validate_executor_binary >/dev/null 2>&1; then
    if ! validate_executor_binary >/dev/null 2>&1; then
      health_issues+=("Executor binary validation failed")
    fi
  fi
  
  # Check wallet configuration
  if command -v validate_wallet_configuration >/dev/null 2>&1; then
    if ! validate_wallet_configuration >/dev/null 2>&1; then
      health_issues+=("Wallet configuration invalid")
    fi
  fi
  
  # Check network connectivity
  if command -v validate_all_rpc_endpoints >/dev/null 2>&1; then
    if ! validate_all_rpc_endpoints >/dev/null 2>&1; then
      health_issues+=("Network connectivity issues")
    fi
  fi
  
  # Check balances
  if command -v get_low_balance_networks >/dev/null 2>&1; then
    local low_balance_networks=$(get_low_balance_networks)
    if [[ "$low_balance_networks" != "All networks have sufficient balance" ]]; then
      health_issues+=("Low balance detected")
    fi
  fi
  
  # Report health status
  if [[ ${#health_issues[@]} -eq 0 ]]; then
    main_log_info "✅ Health check passed"
    return 0
  else
    main_log_warn "⚠️ Health check issues found:"
    for issue in "${health_issues[@]}"; do
      main_log_warn "   - $issue"
    done
    return 1
  fi
}

# === USAGE INFORMATION ===
show_usage() {
  cat << EOF
T3RN Executor Main v$SCRIPT_VERSION
Author: Rokhanz | License: MIT

Usage: $SCRIPT_NAME [OPTIONS]

OPTIONS:
  -h, --help            Show this help message
  -v, --version         Show version information
  -c, --check           Run health check only
  --validate            Run validation only
  --no-services         Skip background services
  --dry-run             Validate configuration without execution

ENVIRONMENT VARIABLES:
  ENABLE_MONITORING                     Enable monitoring services (default: true)
  ENABLE_BALANCE_MONITORING             Enable balance monitoring (default: true)
  ENABLE_RICH_NOTIFICATIONS             Enable rich notifications (default: true)
  USE_PROXY                             Enable proxy usage (default: false)
  ENABLE_ANTI_MEV                       Enable anti-MEV protection (default: false)
  ENABLE_MEV_DETECTION                  Enable MEV detection (default: false)

EXAMPLES:
  $SCRIPT_NAME                          # Run with all services
  $SCRIPT_NAME --no-services            # Run without background services
  $SCRIPT_NAME -c                       # Run health check only
  $SCRIPT_NAME --validate               # Validate configuration only

EOF
}

# === MAIN EXECUTION FUNCTION ===
main() {
  # Default options
  local skip_services=false
  local check_only=false
  local validate_only=false
  local dry_run=false
  
  # Parse command line arguments
  while [[ $# -gt 0 ]]; do
    case $1 in
      -h|--help)
        show_usage
        exit 0
        ;;
      -v|--version)
        echo "T3RN Executor Main v$SCRIPT_VERSION"
        echo "Author: Rokhanz | License: MIT"
        exit 0
        ;;
      -c|--check)
        check_only=true
        shift
        ;;
      --validate)
        validate_only=true
        shift
        ;;
      --no-services)
        skip_services=true
        shift
        ;;
      --dry-run)
        dry_run=true
        shift
        ;;
      *)
        main_log_warn "⚠️ Unknown option: $1"
        show_usage
        exit 1
        ;;
    esac
  done
  
  # Initialize
  initialize_main
  
  # Handle special modes
  if [[ "$validate_only" == "true" ]]; then
    main_log_info "🔍 Running validation only..."
    run_pre_execution_validation
    main_log_info "✅ Validation completed successfully"
    exit 0
  fi
  
  if [[ "$check_only" == "true" ]]; then
    main_log_info "🏥 Running health check only..."
    run_health_check
    exit $?
  fi
  
  # Run pre-execution validation
  run_pre_execution_validation
  
  # Setup execution environment
  setup_execution_environment
  
  if [[ "$dry_run" == "true" ]]; then
    main_log_info "🧪 Dry run completed successfully"
    exit 0
  fi
  
  # Start background services
  if [[ "$skip_services" != "true" ]]; then
    start_background_services
  fi
  
  # Execute main executor
  execute_main_executor
}

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi
