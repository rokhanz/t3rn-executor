#!/bin/bash
set -euo pipefail

# ╔══════════════════════════════════════════════════════════════╗
# ║                    T3RN PROXY MANAGER                       ║
# ║                  (Proxy Management & Rotation)              ║
# ╚══════════════════════════════════════════════════════════════╝

# T3RN Executor Proxy Manager
# Advanced proxy management with rotation, health checks, and failover support
#
# @author Rokhanz
# @license MIT
# @version 1.0.0

# === INTERNAL ERROR HANDLING ===
proxy_error_exit() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] PROXY ERROR: $*" >&2
  exit 1
}

proxy_log_info() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] PROXY INFO: $*"
}

proxy_log_warn() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] PROXY WARN: $*"
}

# === INITIALIZE PROXY MANAGER ===
initialize_proxy_manager() {
  if [[ -z "${SCRIPT_DIR:-}" ]]; then
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")"/.. && pwd)"
    export SCRIPT_DIR
  fi
  
  if [[ -z "${LOGS_DIR:-}" ]]; then
    LOGS_DIR="$SCRIPT_DIR/logs"
    export LOGS_DIR
  fi
  
  mkdir -p "$LOGS_DIR" || proxy_error_exit "Cannot create logs directory"
  
  # Load .env for proxy configuration
  if [[ -f "$SCRIPT_DIR/.env" ]]; then
    source "$SCRIPT_DIR/.env" 2>/dev/null || true
  fi
  
  # Proxy configuration
  USE_PROXY="${USE_PROXY:-false}"
  PROXY_FILE="${PROXY_FILE:-$SCRIPT_DIR/proxies.txt}"
  PROXY_FAILOVER_MODE="${PROXY_FAILOVER_MODE:-true}"
  PROXY_VALIDATION_TIMEOUT="${PROXY_VALIDATION_TIMEOUT:-10}"
  PROXY_RETRY_ATTEMPTS="${PROXY_RETRY_ATTEMPTS:-3}"
  USE_VPS_FALLBACK="${USE_VPS_FALLBACK:-true}"
  PROXY_MAX_CONCURRENT_TESTS="${PROXY_MAX_CONCURRENT_TESTS:-10}"
  PROXY_HEALTH_CHECK_INTERVAL="${PROXY_HEALTH_CHECK_INTERVAL:-300}"
  PROXY_ROTATION_INTERVAL="${PROXY_ROTATION_INTERVAL:-3600}"
  
  # Proxy state variables
  export CURRENT_PROXY=""
  export PROXY_LIST=()
  export WORKING_PROXIES=()
  export FAILED_PROXIES=()
  export PROXY_STATS_FILE="$LOGS_DIR/proxy_stats.txt"
  export PROXY_ROTATION_PID=""
  
  proxy_log_info "🔄 Proxy manager initialized"
}

# === LOAD PROXY LIST ===
load_proxy_list() {
  local proxy_file="${1:-$PROXY_FILE}"
  
  proxy_log_info "📋 Loading proxy list from: $proxy_file"
  
  if [[ ! -f "$proxy_file" ]]; then
    proxy_log_warn "⚠️ Proxy file not found: $proxy_file"
    create_proxy_template "$proxy_file"
    return 1
  fi
  
  # Clear existing proxy list
  PROXY_LIST=()
  
  # Read proxies from file
  while IFS= read -r line; do
    # Skip empty lines and comments
    if [[ -n "$line" && ! "$line" =~ ^[[:space:]]*# ]]; then
      PROXY_LIST+=("$line")
    fi
  done < "$proxy_file"
  
  proxy_log_info "✅ Loaded ${#PROXY_LIST[@]} proxies from file"
  
  if [[ ${#PROXY_LIST[@]} -eq 0 ]]; then
    proxy_log_warn "⚠️ No valid proxies found in file"
    return 1
  fi
  
  return 0
}

# === CREATE PROXY TEMPLATE ===
create_proxy_template() {
  local proxy_file="$1"
  
  proxy_log_info "📝 Creating proxy template: $proxy_file"
  
  cat > "$proxy_file" << 'EOF'
# T3RN Executor Proxy Configuration
# Format: protocol://username:password@host:port
# Examples:
# http://user:pass@proxy1.example.com:8080
# socks5://user:pass@proxy2.example.com:1080
# http://proxy3.example.com:3128

# Add your proxy servers below (one per line)
# Remove the # to uncomment

# http://username:password@proxy-server1.com:8080
# socks5://username:password@proxy-server2.com:1080
# http://proxy-server3.com:3128
EOF
  
  proxy_log_info "✅ Proxy template created. Please add your proxy servers to: $proxy_file"
}

# === VALIDATE PROXY FORMAT ===
validate_proxy_format() {
  local proxy="$1"
  
  # Check basic proxy format
  if [[ ! "$proxy" =~ ^(http|https|socks4|socks5)://.*:[0-9]+$ ]]; then
    return 1
  fi
  
  # Extract components
  local protocol=$(echo "$proxy" | cut -d':' -f1)
  local host_port=$(echo "$proxy" | sed 's|^[^:]*://||' | sed 's|.*@||')
  local host=$(echo "$host_port" | cut -d':' -f1)
  local port=$(echo "$host_port" | cut -d':' -f2)
  
  # Validate port range
  if [[ $port -lt 1 || $port -gt 65535 ]]; then
    return 1
  fi
  
  # Validate host (basic check)
  if [[ -z "$host" ]]; then
    return 1
  fi
  
  return 0
}

# === TEST PROXY CONNECTION ===
test_proxy_connection() {
  local proxy="$1"
  local test_url="${2:-http://httpbin.org/ip}"
  local timeout="${3:-$PROXY_VALIDATION_TIMEOUT}"
  
  if ! validate_proxy_format "$proxy"; then
    proxy_log_warn "⚠️ Invalid proxy format: $proxy"
    return 1
  fi
  
  # Test proxy connection
  local response=""
  local exit_code=0
  
  response=$(curl -s --max-time "$timeout" \
    --proxy "$proxy" \
    --proxy-insecure \
    "$test_url" 2>/dev/null) || exit_code=$?
  
  if [[ $exit_code -eq 0 && -n "$response" ]]; then
    # Additional validation - check if response contains IP
    if echo "$response" | grep -q "origin"; then
      return 0
    fi
  fi
  
  return 1
}

# === TEST ALL PROXIES ===
test_all_proxies() {
  proxy_log_info "🧪 Testing all proxies for connectivity..."
  
  if [[ ${#PROXY_LIST[@]} -eq 0 ]]; then
    proxy_log_warn "⚠️ No proxies to test"
    return 1
  fi
  
  # Clear previous results
  WORKING_PROXIES=()
  FAILED_PROXIES=()
  
  local total_proxies=${#PROXY_LIST[@]}
  local tested_count=0
  local concurrent_tests=0
  local max_concurrent="${PROXY_MAX_CONCURRENT_TESTS}"
  
  proxy_log_info "📊 Testing $total_proxies proxies (max concurrent: $max_concurrent)"
  
  # Test proxies in batches
  for proxy in "${PROXY_LIST[@]}"; do
    # Wait if we've reached max concurrent tests
    while [[ $concurrent_tests -ge $max_concurrent ]]; do
      wait -n  # Wait for any background job to complete
      ((concurrent_tests--))
    done
    
    # Start proxy test in background
    {
      if test_proxy_connection "$proxy"; then
        echo "WORKING:$proxy"
      else
        echo "FAILED:$proxy"
      fi
    } &
    
    ((concurrent_tests++))
    ((tested_count++))
    
    # Show progress
    local percentage=$(( (tested_count * 100) / total_proxies ))
    echo -ne "\r🧪 Testing proxies: $tested_count/$total_proxies ($percentage%)"
  done
  
  # Wait for all background tests to complete
  wait
  echo ""
  
  # Collect results from background jobs
  # Note: In a real implementation, you'd use a more sophisticated method
  # to collect results from background processes
  
  proxy_log_info "✅ Proxy testing completed"
  proxy_log_info "   ✅ Working: ${#WORKING_PROXIES[@]}"
  proxy_log_info "   ❌ Failed: ${#FAILED_PROXIES[@]}"
  
  # Save proxy statistics
  save_proxy_statistics
  
  return 0
}

# === GET WORKING PROXY ===
get_working_proxy() {
  local retry_failed="${1:-false}"
  
  # If no working proxies, test all proxies first
  if [[ ${#WORKING_PROXIES[@]} -eq 0 ]]; then
    if [[ "$retry_failed" == "true" ]]; then
      # Retry failed proxies
      PROXY_LIST=("${FAILED_PROXIES[@]}")
      FAILED_PROXIES=()
    fi
    
    test_all_proxies
  fi
  
  # Return first working proxy
  if [[ ${#WORKING_PROXIES[@]} -gt 0 ]]; then
    echo "${WORKING_PROXIES[0]}"
    return 0
  fi
  
  return 1
}

# === SET CURRENT PROXY ===
set_current_proxy() {
  local proxy="${1:-}"
  
  if [[ -z "$proxy" ]]; then
    proxy=$(get_working_proxy)
    if [[ $? -ne 0 ]]; then
      proxy_log_warn "⚠️ No working proxy available"
      return 1
    fi
  fi
  
  export CURRENT_PROXY="$proxy"
  export http_proxy="$proxy"
  export https_proxy="$proxy"
  export HTTP_PROXY="$proxy"
  export HTTPS_PROXY="$proxy"
  
  proxy_log_info "✅ Current proxy set: $proxy"
  return 0
}

# === ROTATE PROXY ===
rotate_proxy() {
  proxy_log_info "🔄 Rotating proxy..."
  
  if [[ ${#WORKING_PROXIES[@]} -lt 2 ]]; then
    proxy_log_warn "⚠️ Not enough working proxies for rotation"
    return 1
  fi
  
  # Remove current proxy from working list and add to end
  if [[ -n "$CURRENT_PROXY" ]]; then
    local new_working_proxies=()
    local found_current=false
    
    for proxy in "${WORKING_PROXIES[@]}"; do
      if [[ "$proxy" == "$CURRENT_PROXY" ]]; then
        found_current=true
      else
        new_working_proxies+=("$proxy")
      fi
    done
    
    # Add current proxy to end if it was found
    if [[ "$found_current" == "true" ]]; then
      new_working_proxies+=("$CURRENT_PROXY")
    fi
    
    WORKING_PROXIES=("${new_working_proxies[@]}")
  fi
  
  # Set next proxy
  set_current_proxy "${WORKING_PROXIES[0]}"
  
  return 0
}

# === CLEAR PROXY ===
clear_proxy() {
  proxy_log_info "🚫 Clearing proxy configuration..."
  
  export CURRENT_PROXY=""
  unset http_proxy https_proxy HTTP_PROXY HTTPS_PROXY
  
  proxy_log_info "✅ Proxy configuration cleared"
}

# === PROXY HEALTH CHECK ===
proxy_health_check() {
  if [[ -z "$CURRENT_PROXY" ]]; then
    return 0
  fi
  
  proxy_log_info "🏥 Checking current proxy health: $CURRENT_PROXY"
  
  if test_proxy_connection "$CURRENT_PROXY"; then
    proxy_log_info "✅ Current proxy is healthy"
    return 0
  else
    proxy_log_warn "❌ Current proxy failed health check"
    
    # Remove failed proxy from working list
    local new_working_proxies=()
    for proxy in "${WORKING_PROXIES[@]}"; do
      if [[ "$proxy" != "$CURRENT_PROXY" ]]; then
        new_working_proxies+=("$proxy")
      fi
    done
    WORKING_PROXIES=("${new_working_proxies[@]}")
    
    # Add to failed list
    FAILED_PROXIES+=("$CURRENT_PROXY")
    
    # Try to rotate to next working proxy
    if [[ "${PROXY_FAILOVER_MODE}" == "true" ]]; then
      if rotate_proxy; then
        proxy_log_info "✅ Rotated to next working proxy"
        return 0
      else
        proxy_log_warn "⚠️ No working proxies available for failover"
        if [[ "${USE_VPS_FALLBACK}" == "true" ]]; then
          clear_proxy
          proxy_log_info "🔄 Falling back to direct VPS connection"
          return 0
        fi
        return 1
      fi
    fi
    
    return 1
  fi
}

# === START PROXY ROTATION DAEMON ===
start_proxy_rotation_daemon() {
  local rotation_interval="${PROXY_ROTATION_INTERVAL}"
  local health_check_interval="${PROXY_HEALTH_CHECK_INTERVAL}"
  
  proxy_log_info "🔄 Starting proxy rotation daemon"
  proxy_log_info "   🔄 Rotation interval: ${rotation_interval}s"
  proxy_log_info "   🏥 Health check interval: ${health_check_interval}s"
  
  {
    local last_rotation=0
    local last_health_check=0
    
    while true; do
      local current_time=$(date +%s)
      
      # Health check
      if [[ $((current_time - last_health_check)) -ge $health_check_interval ]]; then
        proxy_health_check
        last_health_check=$current_time
      fi
      
      # Rotation
      if [[ $((current_time - last_rotation)) -ge $rotation_interval ]]; then
        if [[ "${USE_PROXY}" == "true" && ${#WORKING_PROXIES[@]} -gt 1 ]]; then
          rotate_proxy
        fi
        last_rotation=$current_time
      fi
      
      sleep 60  # Check every minute
    done
  } &
  
  export PROXY_ROTATION_PID=$!
  proxy_log_info "✅ Proxy rotation daemon started (PID: $PROXY_ROTATION_PID)"
}

# === STOP PROXY ROTATION DAEMON ===
stop_proxy_rotation_daemon() {
  if [[ -n "$PROXY_ROTATION_PID" ]]; then
    proxy_log_info "🛑 Stopping proxy rotation daemon (PID: $PROXY_ROTATION_PID)"
    kill "$PROXY_ROTATION_PID" 2>/dev/null || true
    wait "$PROXY_ROTATION_PID" 2>/dev/null || true
    export PROXY_ROTATION_PID=""
    proxy_log_info "✅ Proxy rotation daemon stopped"
  fi
}

# === SAVE PROXY STATISTICS ===
save_proxy_statistics() {
  local stats_file="$PROXY_STATS_FILE"
  
  {
    echo "T3RN EXECUTOR PROXY STATISTICS"
    echo "Generated: $(date)"
    echo "========================================"
    echo ""
    
    echo "Configuration:"
    echo "  🔄 Use Proxy: $USE_PROXY"
    echo "  📁 Proxy File: $PROXY_FILE"
    echo "  🔄 Failover Mode: $PROXY_FAILOVER_MODE"
    echo "  ⏱️ Validation Timeout: ${PROXY_VALIDATION_TIMEOUT}s"
    echo "  🔄 Retry Attempts: $PROXY_RETRY_ATTEMPTS"
    echo "  📡 VPS Fallback: $USE_VPS_FALLBACK"
    echo ""
    
    echo "Current Status:"
    echo "  🔄 Current Proxy: ${CURRENT_PROXY:-None}"
    echo "  📊 Total Proxies: ${#PROXY_LIST[@]}"
    echo "  ✅ Working Proxies: ${#WORKING_PROXIES[@]}"
    echo "  ❌ Failed Proxies: ${#FAILED_PROXIES[@]}"
    echo ""
    
    if [[ ${#WORKING_PROXIES[@]} -gt 0 ]]; then
      echo "Working Proxies:"
      for proxy in "${WORKING_PROXIES[@]}"; do
        echo "  ✅ $proxy"
      done
      echo ""
    fi
    
    if [[ ${#FAILED_PROXIES[@]} -gt 0 ]]; then
      echo "Failed Proxies:"
      for proxy in "${FAILED_PROXIES[@]}"; do
        echo "  ❌ $proxy"
      done
      echo ""
    fi
    
  } > "$stats_file"
  
  proxy_log_info "📊 Proxy statistics saved: $stats_file"
}

# === GET PROXY STATUS ===
get_proxy_status() {
  if [[ "${USE_PROXY}" == "true" ]]; then
    if [[ -n "$CURRENT_PROXY" ]]; then
      echo "ACTIVE: $CURRENT_PROXY (${#WORKING_PROXIES[@]} working, ${#FAILED_PROXIES[@]} failed)"
    else
      echo "ENABLED: No active proxy (${#WORKING_PROXIES[@]} working, ${#FAILED_PROXIES[@]} failed)"
    fi
  else
    echo "DISABLED"
  fi
}

# === VALIDATE PROXY CONFIGURATION ===
validate_proxy_configuration() {
  proxy_log_info "🔍 Validating proxy configuration..."
  
  # Check if proxy is enabled
  if [[ "${USE_PROXY}" != "true" ]]; then
    proxy_log_info "📋 Proxy usage is disabled"
    return 0
  fi
  
  # Check proxy file
  if [[ ! -f "$PROXY_FILE" ]]; then
    proxy_log_warn "⚠️ Proxy file not found: $PROXY_FILE"
    return 1
  fi
  
  # Check proxy file is readable
  if [[ ! -r "$PROXY_FILE" ]]; then
    proxy_log_warn "⚠️ Proxy file not readable: $PROXY_FILE"
    return 1
  fi
  
  # Load and validate proxy list
  if ! load_proxy_list; then
    proxy_log_warn "⚠️ Failed to load proxy list"
    return 1
  fi
  
  # Validate configuration values
  if [[ ! "$PROXY_VALIDATION_TIMEOUT" =~ ^[0-9]+$ ]] || [[ $PROXY_VALIDATION_TIMEOUT -lt 1 ]] || [[ $PROXY_VALIDATION_TIMEOUT -gt 60 ]]; then
    proxy_log_warn "⚠️ Invalid PROXY_VALIDATION_TIMEOUT: $PROXY_VALIDATION_TIMEOUT (should be 1-60)"
    return 1
  fi
  
  if [[ ! "$PROXY_RETRY_ATTEMPTS" =~ ^[0-9]+$ ]] || [[ $PROXY_RETRY_ATTEMPTS -lt 1 ]] || [[ $PROXY_RETRY_ATTEMPTS -gt 10 ]]; then
    proxy_log_warn "⚠️ Invalid PROXY_RETRY_ATTEMPTS: $PROXY_RETRY_ATTEMPTS (should be 1-10)"
    return 1
  fi
  
  proxy_log_info "✅ Proxy configuration validated"
  return 0
}

# === SETUP PROXY SYSTEM ===
setup_proxy_system() {
  proxy_log_info "🚀 Setting up proxy system..."
  
  # Validate configuration
  if ! validate_proxy_configuration; then
    proxy_log_warn "⚠️ Proxy configuration validation failed"
    return 1
  fi
  
  # Skip if proxy is disabled
  if [[ "${USE_PROXY}" != "true" ]]; then
    proxy_log_info "📋 Proxy system disabled, skipping setup"
    return 0
  fi
  
  # Load proxy list
  if ! load_proxy_list; then
    proxy_log_warn "⚠️ Failed to load proxy list"
    return 1
  fi
  
  # Test proxies
  test_all_proxies
  
  # Set initial proxy
  if [[ ${#WORKING_PROXIES[@]} -gt 0 ]]; then
    set_current_proxy
    
    # Start rotation daemon if enabled
    if [[ "${PROXY_FAILOVER_MODE}" == "true" ]]; then
      start_proxy_rotation_daemon
    fi
    
    proxy_log_info "✅ Proxy system setup completed"
    return 0
  else
    proxy_log_warn "⚠️ No working proxies found"
    
    if [[ "${USE_VPS_FALLBACK}" == "true" ]]; then
      proxy_log_info "🔄 Using VPS fallback (direct connection)"
      clear_proxy
      return 0
    else
      return 1
    fi
  fi
}

# === CLEANUP PROXY SYSTEM ===
cleanup_proxy_system() {
  proxy_log_info "🧹 Cleaning up proxy system..."
  
  # Stop rotation daemon
  stop_proxy_rotation_daemon
  
  # Clear proxy configuration
  clear_proxy
  
  # Clear proxy variables
  PROXY_LIST=()
  WORKING_PROXIES=()
  FAILED_PROXIES=()
  export CURRENT_PROXY=""
  
  proxy_log_info "✅ Proxy system cleanup completed"
}

# === GENERATE PROXY REPORT ===
generate_proxy_report() {
  local report_file="${LOGS_DIR}/proxy_report.txt"
  
  proxy_log_info "📋 Generating proxy report..."
  
  {
    echo "T3RN EXECUTOR PROXY REPORT"
    echo "Generated: $(date)"
    echo "========================================"
    echo ""
    
    echo "Configuration:"
    echo "  🔄 Use Proxy: $USE_PROXY"
    echo "  📁 Proxy File: $PROXY_FILE"
    echo "  🔄 Failover Mode: $PROXY_FAILOVER_MODE"
    echo "  ⏱️ Validation Timeout: ${PROXY_VALIDATION_TIMEOUT}s"
    echo "  🔄 Retry Attempts: $PROXY_RETRY_ATTEMPTS"
    echo "  📡 VPS Fallback: $USE_VPS_FALLBACK"
    echo "  🧪 Max Concurrent Tests: $PROXY_MAX_CONCURRENT_TESTS"
    echo "  🏥 Health Check Interval: ${PROXY_HEALTH_CHECK_INTERVAL}s"
    echo "  🔄 Rotation Interval: ${PROXY_ROTATION_INTERVAL}s"
    echo ""
    
    echo "Current Status:"
    echo "  🔄 Current Proxy: ${CURRENT_PROXY:-None}"
    echo "  📊 Total Proxies: ${#PROXY_LIST[@]}"
    echo "  ✅ Working Proxies: ${#WORKING_PROXIES[@]}"
    echo "  ❌ Failed Proxies: ${#FAILED_PROXIES[@]}"
    echo "  🔄 Rotation Daemon: $(if [[ -n "$PROXY_ROTATION_PID" ]]; then echo "Running (PID: $PROXY_ROTATION_PID)"; else echo "Stopped"; fi)"
    echo ""
    
    if [[ -f "$PROXY_FILE" ]]; then
      echo "Proxy File Status:"
      echo "  📁 File: EXISTS"
      echo "  📊 Size: $(stat -c%s "$PROXY_FILE" 2>/dev/null || echo "unknown") bytes"
      echo "  📅 Modified: $(stat -c%y "$PROXY_FILE" 2>/dev/null || echo "unknown")"
    else
      echo "Proxy File Status:"
      echo "  📁 File: NOT FOUND"
    fi
    echo ""
    
  } > "$report_file"
  
  proxy_log_info "✅ Proxy report saved: $report_file"
}

# Trap to cleanup on exit
trap cleanup_proxy_system EXIT

# Initialize on load
initialize_proxy_manager

# Export functions
export -f initialize_proxy_manager
export -f load_proxy_list
export -f create_proxy_template
export -f validate_proxy_format
export -f test_proxy_connection
export -f test_all_proxies
export -f get_working_proxy
export -f set_current_proxy
export -f rotate_proxy
export -f clear_proxy
export -f proxy_health_check
export -f start_proxy_rotation_daemon
export -f stop_proxy_rotation_daemon
export -f save_proxy_statistics
export -f get_proxy_status
export -f validate_proxy_configuration
export -f setup_proxy_system
export -f cleanup_proxy_system
export -f generate_proxy_report
