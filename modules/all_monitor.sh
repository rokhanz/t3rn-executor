#!/bin/bash
set -euo pipefail

# ╔══════════════════════════════════════════════════════════════╗
# ║                    T3RN ALL MONITOR                         ║
# ║                  (Comprehensive Monitoring)                 ║
# ╚══════════════════════════════════════════════════════════════╝

# T3RN Executor Comprehensive Monitoring System
# Real-time monitoring of system resources, network health, and executor performance
#
# @author Rokhanz
# @license MIT
# @version 1.0.0

# === INTERNAL ERROR HANDLING ===
monitor_error_exit() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] MONITOR ERROR: $*" >&2
  exit 1
}

monitor_log_info() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] MONITOR INFO: $*"
}

monitor_log_warn() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] MONITOR WARN: $*"
}

# === INITIALIZE MONITORING ===
initialize_monitoring() {
  if [[ -z "${SCRIPT_DIR:-}" ]]; then
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")"/.. && pwd)"
    export SCRIPT_DIR
  fi

  if [[ -z "${LOGS_DIR:-}" ]]; then
    LOGS_DIR="$SCRIPT_DIR/logs"
    export LOGS_DIR
  fi

  if [[ -z "${EXECUTOR_PATH:-}" ]]; then
    EXECUTOR_PATH="$SCRIPT_DIR/t3rn/executor/executor/bin/executor"
    export EXECUTOR_PATH
  fi
  
  mkdir -p "$LOGS_DIR" || monitor_error_exit "Cannot create logs directory"
  
  # Load .env for monitoring configuration
  if [[ -f "$SCRIPT_DIR/.env" ]]; then
    source "$SCRIPT_DIR/.env" || monitor_error_exit "Failed to load .env"
  else
    monitor_log_warn "⚠️ .env file not found, using default values"
  fi
}

# === RPC HEALTH MONITORING ===
monitor_rpc_health() {
  local interval="${RPC_HEALTH_CHECK_INTERVAL:-300}"
  
  monitor_log_info "🌐 Starting RPC health monitoring (interval: ${interval}s)"
  
  while true; do
    local networks=("arbitrum-sepolia" "base-sepolia" "blast-sepolia" "optimism-sepolia" "unichain-sepolia")
    
    for network in "${networks[@]}"; do
      local network_code=""
      case "$network" in
        "arbitrum-sepolia") network_code="ARBT" ;;
        "base-sepolia") network_code="BAST" ;;
        "blast-sepolia") network_code="BLST" ;;
        "optimism-sepolia") network_code="OPST" ;;
        "unichain-sepolia") network_code="UNIT" ;;
      esac
      
      local rpc_var="RPC_${network_code}"
      if [[ -n "${!rpc_var:-}" ]]; then
        local response=$(curl -s --max-time 10 -X POST "${!rpc_var}" \
          -H "Content-Type: application/json" \
          -d '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' 2>/dev/null || echo "")
        
        if [[ "$response" =~ "result" ]]; then
          monitor_log_info "✅ RPC $network: OK"
        else
          monitor_log_warn "❌ RPC $network: FAILED"
        fi
      fi
    done
    
    sleep $interval
  done
}

# === BALANCE MONITORING ===
monitor_balance() {
  local interval="${BALANCE_CHECK_INTERVAL:-600}"
  local threshold="${NOTIFY_BALANCE_THRESHOLD:-0.05}"
  
  monitor_log_info "💰 Starting balance monitoring (interval: ${interval}s, threshold: ${threshold} ETH)"
  
  while true; do
    if command -v check_all_network_balances >/dev/null 2>&1; then
      check_all_network_balances 2>/dev/null || monitor_log_warn "Balance check failed"
    fi
    
    sleep $interval
  done
}

# === EXECUTOR PERFORMANCE MONITORING ===
monitor_executor_performance() {
  local log_file="$LOGS_DIR/executor.log"
  
  monitor_log_info "📊 Starting executor performance monitoring"
  
  tail -f "$log_file" 2>/dev/null | while read -r line; do
    if [[ "$line" =~ "BidReceived" ]]; then
      echo "[$(date '+%Y-%m-%d %H:%M:%S')] 📈 METRIC: Bid received"
      
    elif [[ "$line" =~ "RemoteOrderCreated" ]]; then
      echo "[$(date '+%Y-%m-%d %H:%M:%S')] 📈 METRIC: Order created"
      
    elif [[ "$line" =~ "Bid submitted successfully" ]]; then
      echo "[$(date '+%Y-%m-%d %H:%M:%S')] 📈 METRIC: Bid submitted"
      
    elif [[ "$line" =~ "Order executed" ]]; then
      echo "[$(date '+%Y-%m-%d %H:%M:%S')] 📈 METRIC: Order executed"
      
    elif [[ "$line" =~ "Claim successful" ]]; then
      echo "[$(date '+%Y-%m-%d %H:%M:%S')] 📈 METRIC: Claim successful"
      
    elif [[ "$line" =~ "error\|Error\|ERROR" ]]; then
      echo "[$(date '+%Y-%m-%d %H:%M:%S')] 📈 METRIC: Error detected"
      
    elif [[ "$line" =~ "Connected to network" ]]; then
      local network=$(echo "$line" | grep -oP 'network \K[^\s]+' || echo "unknown")
      echo "[$(date '+%Y-%m-%d %H:%M:%S')] 📈 METRIC: Network connected - $network"
    fi
  done
}

# === SYSTEM RESOURCE MONITORING ===
monitor_system_resources() {
  local interval="${SYSTEM_MONITOR_INTERVAL:-60}"
  
  monitor_log_info "🖥️ Starting system resource monitoring (interval: ${interval}s)"
  
  while true; do
    local cpu_usage=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1 || echo "0")
    local mem_usage=$(free | grep Mem | awk '{printf "%.1f", $3/$2 * 100.0}' || echo "0")
    local disk_usage=$(df "$SCRIPT_DIR" | tail -1 | awk '{print $5}' | cut -d'%' -f1 || echo "0")
    
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] 📊 SYSTEM: CPU: ${cpu_usage}%, MEM: ${mem_usage}%, DISK: ${disk_usage}%"
    
    # Alert on high usage
    if [[ $(echo "$cpu_usage > 80" | bc -l 2>/dev/null || echo "0") -eq 1 ]] || \
       [[ $(echo "$mem_usage > 80" | bc -l 2>/dev/null || echo "0") -eq 1 ]] || \
       [[ $disk_usage -gt 80 ]]; then
      
      monitor_log_warn "⚠️ High resource usage detected"
    fi
    
    sleep $interval
  done
}

# === EXECUTOR PROCESS MONITORING (Enhanced) ===
monitor_executor_process() {
  local interval="${PROCESS_MONITOR_INTERVAL:-30}"
  
  monitor_log_info "🔍 Starting executor process monitoring (interval: ${interval}s)"
  
  while true; do
    local executor_pid=""
    
    # Method 1: Check PID file
    if [[ -f "$SCRIPT_DIR/executor.pid" ]]; then
      local file_pid=$(cat "$SCRIPT_DIR/executor.pid")
      if kill -0 $file_pid 2>/dev/null; then
        executor_pid="$file_pid"
      else
        monitor_log_warn "⚠️ Stale PID file detected, cleaning up"
        rm -f "$SCRIPT_DIR/executor.pid"
      fi
    fi
    
    # Method 2: Find by process name
    if [[ -z "$executor_pid" ]]; then
      executor_pid=$(pgrep -f "$EXECUTOR_PATH" | head -1)
    fi
    
    # Method 3: Find by command pattern
    if [[ -z "$executor_pid" ]]; then
      executor_pid=$(ps aux | grep -E "executor.*bin.*executor" | grep -v grep | awk '{print $2}' | head -1)
    fi
    
    if [[ -n "$executor_pid" ]]; then
      local cpu_percent=$(ps -p $executor_pid -o %cpu --no-headers 2>/dev/null | tr -d ' ' || echo "0")
      local mem_percent=$(ps -p $executor_pid -o %mem --no-headers 2>/dev/null | tr -d ' ' || echo "0")
      local uptime=$(ps -p $executor_pid -o etime --no-headers 2>/dev/null | tr -d ' ' || echo "unknown")
      
      echo "[$(date '+%Y-%m-%d %H:%M:%S')] 🔍 EXECUTOR: PID: $executor_pid, CPU: ${cpu_percent}%, MEM: ${mem_percent}%, UPTIME: $uptime"
      
      # Update PID file if not exists
      if [[ ! -f "$SCRIPT_DIR/executor.pid" ]]; then
        echo "$executor_pid" > "$SCRIPT_DIR/executor.pid"
        monitor_log_info "📝 Updated executor PID file: $executor_pid"
      fi
    else
      monitor_log_warn "❌ Executor process not running (PID: ${executor_pid:-unknown})"
    fi
    
    sleep $interval
  done
}

# === CHECK MONITORING PROCESSES ===
check_monitoring_processes() {
  local pids=("rpc_monitor.pid" "balance_monitor.pid" "performance_monitor.pid" "system_monitor.pid" "process_monitor.pid")
  local dead_processes=()
  
  for pid_file in "${pids[@]}"; do
    if [[ -f "$SCRIPT_DIR/$pid_file" ]]; then
      local pid=$(cat "$SCRIPT_DIR/$pid_file")
      if ! kill -0 $pid 2>/dev/null; then
        dead_processes+=("${pid_file%.pid}")
        rm -f "$SCRIPT_DIR/$pid_file"
      fi
    fi
  done
  
  if [[ ${#dead_processes[@]} -gt 0 ]]; then
    monitor_log_warn "⚠️ Dead monitoring processes detected: ${dead_processes[*]}"
  fi
}

# === START ALL MONITORING (Daemon Mode) ===
start_all_monitoring() {
  initialize_monitoring
  
  monitor_log_info "🚀 Starting comprehensive monitoring system in daemon mode..."
  
  # Use daemon mode dengan nohup dan disown
  if [[ "${ENABLE_RPC_HEALTH_CHECK:-true}" == "true" ]]; then
    nohup bash -c "$(declare -f monitor_rpc_health initialize_monitoring monitor_log_info monitor_log_warn monitor_error_exit); initialize_monitoring; monitor_rpc_health" >/dev/null 2>&1 &
    local rpc_pid=$!
    echo $rpc_pid > "$SCRIPT_DIR/rpc_monitor.pid"
    disown $rpc_pid
    monitor_log_info "✅ RPC health monitor started (PID: $rpc_pid)"
  fi
  
  if [[ "${ENABLE_BALANCE_MONITORING:-true}" == "true" ]]; then
    nohup bash -c "$(declare -f monitor_balance initialize_monitoring monitor_log_info monitor_log_warn monitor_error_exit); initialize_monitoring; monitor_balance" >/dev/null 2>&1 &
    local balance_pid=$!
    echo $balance_pid > "$SCRIPT_DIR/balance_monitor.pid"
    disown $balance_pid
    monitor_log_info "✅ Balance monitor started (PID: $balance_pid)"
  fi
  
  if [[ "${ENABLE_PERFORMANCE_MONITORING:-true}" == "true" ]]; then
    nohup bash -c "$(declare -f monitor_executor_performance initialize_monitoring monitor_log_info monitor_log_warn monitor_error_exit); initialize_monitoring; monitor_executor_performance" >/dev/null 2>&1 &
    local perf_pid=$!
    echo $perf_pid > "$SCRIPT_DIR/performance_monitor.pid"
    disown $perf_pid
    monitor_log_info "✅ Performance monitor started (PID: $perf_pid)"
  fi
  
  if [[ "${ENABLE_NETWORK_MONITORING:-true}" == "true" ]]; then
    nohup bash -c "$(declare -f monitor_system_resources initialize_monitoring monitor_log_info monitor_log_warn monitor_error_exit); initialize_monitoring; monitor_system_resources" >/dev/null 2>&1 &
    local system_pid=$!
    echo $system_pid > "$SCRIPT_DIR/system_monitor.pid"
    disown $system_pid
    monitor_log_info "✅ System monitor started (PID: $system_pid)"
  fi
  
  nohup bash -c "$(declare -f monitor_executor_process initialize_monitoring monitor_log_info monitor_log_warn monitor_error_exit); initialize_monitoring; monitor_executor_process" >/dev/null 2>&1 &
  local process_pid=$!
  echo $process_pid > "$SCRIPT_DIR/process_monitor.pid"
  disown $process_pid
  monitor_log_info "✅ Process monitor started (PID: $process_pid)"
  
  monitor_log_info "✅ All monitoring services started in daemon mode"
  
  # Keep monitoring script alive dengan signal handling
  trap 'monitor_log_info "📊 Monitoring received signal, continuing..."; sleep 1' TERM INT HUP
  
  while true; do
    sleep 60
    monitor_log_info "📊 Monitoring system heartbeat"
    check_monitoring_processes
  done
}

# === STOP ALL MONITORING ===
stop_all_monitoring() {
  monitor_log_info "🛑 Stopping all monitoring services..."
  
  local pids=("rpc_monitor.pid" "balance_monitor.pid" "performance_monitor.pid" "system_monitor.pid" "process_monitor.pid")
  
  for pid_file in "${pids[@]}"; do
    if [[ -f "$SCRIPT_DIR/$pid_file" ]]; then
      local pid=$(cat "$SCRIPT_DIR/$pid_file")
      if kill -0 $pid 2>/dev/null; then
        kill $pid 2>/dev/null || true
        monitor_log_info "✅ Stopped monitor: $pid_file (PID: $pid)"
      fi
      rm -f "$SCRIPT_DIR/$pid_file"
    fi
  done
  
  monitor_log_info "✅ All monitoring services stopped"
}

# === GET MONITORING STATUS ===
get_monitoring_status() {
  local pids=("rpc_monitor.pid" "balance_monitor.pid" "performance_monitor.pid" "system_monitor.pid" "process_monitor.pid")
  local active_count=0
  
  for pid_file in "${pids[@]}"; do
    if [[ -f "$SCRIPT_DIR/$pid_file" ]]; then
      local pid=$(cat "$SCRIPT_DIR/$pid_file")
      if kill -0 $pid 2>/dev/null; then
        ((active_count++))
      fi
    fi
  done
  
  echo "ACTIVE: $active_count/${#pids[@]} monitors running"
}

# === CLEANUP ===
cleanup_monitoring() {
  monitor_log_info "🧹 Cleaning up monitoring..."
  stop_all_monitoring
  jobs -p | xargs -r kill 2>/dev/null || true
}

trap cleanup_monitoring EXIT

# Initialize on load
initialize_monitoring

# Export functions
export -f start_all_monitoring
export -f stop_all_monitoring
export -f monitor_rpc_health
export -f monitor_balance
export -f monitor_executor_performance
export -f monitor_system_resources
export -f monitor_executor_process
export -f get_monitoring_status
export -f check_monitoring_processes
