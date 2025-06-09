#!/bin/bash
set -euo pipefail

# ╔══════════════════════════════════════════════════════════════╗
# ║                    T3RN VALIDATION                          ║
# ║                  (Comprehensive Validation)                 ║
# ╚══════════════════════════════════════════════════════════════╝

# T3RN Executor Comprehensive Validation
# Complete system validation including configuration, dependencies, and security
#
# @author Rokhanz
# @license MIT
# @version 1.0.0

# === INTERNAL ERROR HANDLING ===
validation_error_exit() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] VALIDATION ERROR: $*" >&2
  exit 1
}

validation_log_info() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] VALIDATION INFO: $*"
}

validation_log_warn() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] VALIDATION WARN: $*"
}

# === INITIALIZE VALIDATION ===
initialize_validation() {
  if [[ -z "${SCRIPT_DIR:-}" ]]; then
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")"/.. && pwd)"
    export SCRIPT_DIR
  fi

  if [[ -z "${MODULES_DIR:-}" ]]; then
    MODULES_DIR="$SCRIPT_DIR/modules"
    export MODULES_DIR
  fi

  if [[ -z "${LOGS_DIR:-}" ]]; then
    LOGS_DIR="$SCRIPT_DIR/logs"
    export LOGS_DIR
  fi

  if [[ -z "${T3RN_DIR:-}" ]]; then
    T3RN_DIR="$SCRIPT_DIR/t3rn"
    export T3RN_DIR
  fi

  if [[ -z "${EXECUTOR_PATH:-}" ]]; then
    EXECUTOR_PATH="$T3RN_DIR/executor/executor/bin/executor"
    export EXECUTOR_PATH
  fi
}

# === SYSTEM DEPENDENCIES VALIDATION ===
validate_system_dependencies() {
  validation_log_info "🔍 Validating system dependencies..."
  
  local required_commands=("curl" "tar" "screen" "find" "stat" "grep" "awk" "bc" "ps" "kill" "pkill" "nc" "free" "top" "df")
  local missing_commands=()
  local optional_commands=("jq" "htop" "tmux")
  
  # Check required commands
  for cmd in "${required_commands[@]}"; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
      missing_commands+=("$cmd")
    fi
  done
  
  if [[ ${#missing_commands[@]} -gt 0 ]]; then
    validation_error_exit "Missing required commands: ${missing_commands[*]}. Install with: sudo apt update && sudo apt install ${missing_commands[*]} -y"
  fi
  
  # Check optional commands
  for cmd in "${optional_commands[@]}"; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
      validation_log_warn "Optional command missing: $cmd (recommended but not required)"
    fi
  done
  
  validation_log_info "✅ System dependencies validated"
  return 0
}

# === DIRECTORY STRUCTURE VALIDATION ===
validate_directory_structure() {
  validation_log_info "📁 Validating directory structure..."
  
  local required_dirs=("$SCRIPT_DIR" "$MODULES_DIR" "$LOGS_DIR")
  local required_files=("$SCRIPT_DIR/.env" "$SCRIPT_DIR/main.sh" "$SCRIPT_DIR/autorun.sh")
  local required_modules=("downloader.sh" "screen_manager.sh" "executor_binary.sh" "env_loader.sh" "wallet_manager.sh" "rpc_manager.sh" "all_monitor.sh")
  
  # Check directories
  for dir in "${required_dirs[@]}"; do
    if [[ ! -d "$dir" ]]; then
      validation_error_exit "Required directory not found: $dir"
    fi
    if [[ ! -w "$dir" ]]; then
      validation_error_exit "Directory not writable: $dir"
    fi
  done
  
  # Check main files
  for file in "${required_files[@]}"; do
    if [[ ! -f "$file" ]]; then
      validation_error_exit "Required file not found: $file"
    fi
    if [[ ! -r "$file" ]]; then
      validation_error_exit "File not readable: $file"
    fi
  done
  
  # Check modules
  for module in "${required_modules[@]}"; do
    local module_path="$MODULES_DIR/$module"
    if [[ ! -f "$module_path" ]]; then
      validation_error_exit "Required module not found: $module_path"
    fi
    if [[ ! -r "$module_path" ]]; then
      validation_error_exit "Module not readable: $module_path"
    fi
  done
  
  validation_log_info "✅ Directory structure validated"
  return 0
}

# === ENVIRONMENT FILE VALIDATION ===
validate_env_file() {
  validation_log_info "🔧 Validating .env file..."
  
  local env_file="$SCRIPT_DIR/.env"
  
  # Check file exists and readable
  [[ -f "$env_file" ]] || validation_error_exit ".env file not found: $env_file"
  [[ -r "$env_file" ]] || validation_error_exit ".env file not readable: $env_file"
  
  # Test .env syntax
  if ! bash -n <(echo "source '$env_file'") 2>/dev/null; then
    validation_error_exit ".env file has syntax errors"
  fi
  
  # Load .env for validation
  source "$env_file" || validation_error_exit "Failed to load .env file"
  
  # Validate critical variables
  local required_vars=("PRIVATE_KEY_EXECUTOR" "ENABLED_NETWORKS" "ENVIRONMENT")
  for var in "${required_vars[@]}"; do
    if [[ -z "${!var:-}" ]]; then
      validation_error_exit "Required environment variable not set: $var"
    fi
  done
  
  validation_log_info "✅ Environment file validated"
  return 0
}

# === PRIVATE KEY VALIDATION ===
validate_private_key() {
  validation_log_info "🔑 Validating private key..."
  
  # Load .env if not already loaded
  source "$SCRIPT_DIR/.env" 2>/dev/null || validation_error_exit "Failed to load .env"
  
  local private_key="${PRIVATE_KEY_EXECUTOR:-}"
  
  # Check if private key exists
  [[ -n "$private_key" ]] || validation_error_exit "PRIVATE_KEY_EXECUTOR not set in .env"
  
  # Check length (64 characters for private key without 0x)
  if [[ ${#private_key} -ne 64 ]]; then
    validation_error_exit "PRIVATE_KEY_EXECUTOR must be exactly 64 characters (got ${#private_key})"
  fi
  
  # Check format (hex characters only)
  if [[ ! "$private_key" =~ ^[a-fA-F0-9]+$ ]]; then
    validation_error_exit "PRIVATE_KEY_EXECUTOR must contain only hexadecimal characters (0-9, a-f, A-F)"
  fi
  
  # Check no 0x prefix
  if [[ "$private_key" =~ ^0x ]]; then
    validation_error_exit "PRIVATE_KEY_EXECUTOR should not start with 0x prefix"
  fi
  
  # Check not default/example values
  local invalid_keys=("1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef" "your_private_key_without_0x_prefix_64_characters_here" "0000000000000000000000000000000000000000000000000000000000000000")
  for invalid_key in "${invalid_keys[@]}"; do
    if [[ "$private_key" == "$invalid_key" ]]; then
      validation_error_exit "PRIVATE_KEY_EXECUTOR appears to be a placeholder/example value"
    fi
  done
  
  validation_log_info "✅ Private key validated (format correct)"
  return 0
}

# === NETWORK CONFIGURATION VALIDATION (Complete Network List) ===
validate_network_configuration() {
  validation_log_info "🌐 Validating network configuration..."
  
  # Load .env if not already loaded
  source "$SCRIPT_DIR/.env" 2>/dev/null || validation_error_exit "Failed to load .env"
  
  local enabled_networks="${ENABLED_NETWORKS:-}"
  [[ -n "$enabled_networks" ]] || validation_error_exit "ENABLED_NETWORKS not set in .env"
  
  # Parse networks
  IFS=',' read -ra networks <<< "$enabled_networks"
  
  if [[ ${#networks[@]} -eq 0 ]]; then
    validation_error_exit "No networks specified in ENABLED_NETWORKS"
  fi
  
  # Validate each network (Complete List dengan Alchemy Support Info)
  local valid_networks=("arbitrum-sepolia" "base-sepolia" "blast-sepolia" "optimism-sepolia" "unichain-sepolia" "monad-testnet" "sei-testnet" "abstract-testnet" "lisk-sepolia" "berachain-bepolia" "bnb-testnet" "l2rn")
  local alchemy_supported_networks=("arbitrum-sepolia" "base-sepolia" "blast-sepolia" "optimism-sepolia" "unichain-sepolia" "sei-testnet" "abstract-testnet" "berachain-bepolia" "monad-testnet" "bnb-testnet")
  local public_rpc_networks=("lisk-sepolia" "l2rn")
  
  for network in "${networks[@]}"; do
    network=$(echo "$network" | xargs)  # Trim whitespace
    
    local is_valid=false
    local alchemy_support=""
    
    for valid_network in "${valid_networks[@]}"; do
      if [[ "$network" == "$valid_network" ]]; then
        is_valid=true
        
        # Check Alchemy support
        if [[ " ${alchemy_supported_networks[*]} " =~ " ${network} " ]]; then
          alchemy_support="(Alchemy Supported)"
        elif [[ " ${public_rpc_networks[*]} " =~ " ${network} " ]]; then
          alchemy_support="(Public RPC Only)"
        fi
        
        break
      fi
    done
    
    if [[ "$is_valid" == "false" ]]; then
      validation_error_exit "Invalid network specified: $network. Valid networks: ${valid_networks[*]}"
    else
      validation_log_info "✅ Valid network: $network $alchemy_support"
    fi
  done
  
  validation_log_info "✅ Network configuration validated (${#networks[@]} networks)"
  return 0
}

# === RPC ENDPOINTS VALIDATION (Complete) ===
validate_rpc_endpoints() {
  validation_log_info "🔗 Validating RPC endpoints..."
  
  # Load .env if not already loaded
  source "$SCRIPT_DIR/.env" 2>/dev/null || validation_error_exit "Failed to load .env"
  
  local alchemy_keys=("${ALCHEMY_KEY_1:-}" "${ALCHEMY_KEY_2:-}" "${ALCHEMY_KEY_3:-}" "${ALCHEMY_KEY_4:-}" "${ALCHEMY_KEY_5:-}" "${ALCHEMY_KEY_6:-}" "${ALCHEMY_KEY_7:-}" "${ALCHEMY_KEY_8:-}")
  local has_alchemy_key=false
  
  # Check if at least one Alchemy key is provided
  for key in "${alchemy_keys[@]}"; do
    if [[ -n "$key" && "$key" != "your_alchemy_api_key" ]]; then
      has_alchemy_key=true
      break
    fi
  done
  
  if [[ "$has_alchemy_key" == "false" ]]; then
    validation_log_warn "⚠️ No valid Alchemy API keys found. RPC endpoints may not work properly."
  else
    validation_log_info "✅ Alchemy API keys found"
  fi
  
  # Test basic RPC connectivity (if curl available)
  if command -v curl >/dev/null 2>&1; then
    local test_rpc="https://arb-sepolia.g.alchemy.com/v2/${ALCHEMY_KEY_1:-demo}"
    local response=$(curl -s --max-time 5 -X POST "$test_rpc" \
      -H "Content-Type: application/json" \
      -d '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' 2>/dev/null || echo "")
    
    if [[ "$response" =~ "result" ]]; then
      validation_log_info "✅ RPC connectivity test passed"
    else
      validation_log_warn "⚠️ RPC connectivity test failed (may be due to invalid API key)"
    fi
  fi
  
  validation_log_info "✅ RPC endpoints configuration validated"
  return 0
}

# === EXECUTOR BINARY VALIDATION ===
validate_executor_binary() {
  validation_log_info "⚙️ Validating executor binary..."
  
  # Check if binary exists
  if [[ ! -f "$EXECUTOR_PATH" ]]; then
    validation_log_warn "⚠️ Executor binary not found: $EXECUTOR_PATH (will be downloaded)"
    return 0
  fi
  
  # Check if binary is executable
  if [[ ! -x "$EXECUTOR_PATH" ]]; then
    validation_log_warn "⚠️ Executor binary not executable, attempting to fix..."
    chmod +x "$EXECUTOR_PATH" 2>/dev/null || validation_error_exit "Cannot set executable permission on: $EXECUTOR_PATH"
  fi
  
  # Check binary type
  local file_info=$(file "$EXECUTOR_PATH" 2>/dev/null || echo "Unknown")
  if [[ ! "$file_info" =~ "ELF 64-bit" ]]; then
    validation_error_exit "Executor binary is not a valid 64-bit ELF executable: $file_info"
  fi
  
  # Check architecture
  if [[ "$file_info" =~ "ARM" ]]; then
    validation_error_exit "Executor binary is ARM architecture, need x86_64"
  fi
  
  # Check file size (should be reasonable size)
  local file_size=$(stat -c%s "$EXECUTOR_PATH" 2>/dev/null || echo "0")
  if [[ $file_size -lt 1000000 ]]; then  # Less than 1MB
    validation_error_exit "Executor binary too small ($file_size bytes), possibly corrupted"
  fi
  
  # Test binary execution (with timeout)
  if timeout 10 "$EXECUTOR_PATH" --help >/dev/null 2>&1; then
    validation_log_info "✅ Executor binary test passed"
  else
    validation_log_warn "⚠️ Executor binary test failed (may need dependencies)"
  fi
  
  validation_log_info "✅ Executor binary validated"
  return 0
}

# === SCREEN SESSION VALIDATION ===
validate_screen_functionality() {
  validation_log_info "📺 Validating screen functionality..."
  
  # Check if screen is installed
  if ! command -v screen >/dev/null 2>&1; then
    validation_error_exit "screen not installed. Install with: sudo apt install screen -y"
  fi
  
  # Check screen version
  local screen_version=$(screen -v 2>&1 | head -1 || echo "unknown")
  validation_log_info "📋 Screen version: $screen_version"
  
  # Test screen functionality
  local test_output=$(screen -list 2>&1)
  local test_exit_code=$?
  
  # Exit code 0 = sessions exist, 1 = no sessions (both are normal)
  if [[ $test_exit_code -gt 1 ]]; then
    validation_error_exit "Screen command failed: $test_output"
  fi
  
  # Test screen directory permissions
  if [[ -d "/run/screen" ]]; then
    local screen_perms=$(ls -ld /run/screen 2>/dev/null | awk '{print $1}' || echo "unknown")
    validation_log_info "📋 Screen directory permissions: $screen_perms"
  else
    validation_log_warn "⚠️ Screen directory /run/screen not found (will be created)"
  fi
  
  validation_log_info "✅ Screen functionality validated"
  return 0
}

# === NOTIFICATION SYSTEM VALIDATION ===
validate_notification_system() {
  validation_log_info "📱 Validating notification system..."
  
  # Load .env if not already loaded
  source "$SCRIPT_DIR/.env" 2>/dev/null || validation_error_exit "Failed to load .env"
  
  local enable_notifications="${ENABLE_NOTIFICATIONS:-false}"
  
  if [[ "$enable_notifications" == "true" ]]; then
    local telegram_enable="${TELEGRAM_ENABLE:-false}"
    
    if [[ "$telegram_enable" == "true" ]]; then
      local bot_token="${TELEGRAM_BOT_TOKEN:-}"
      local chat_id="${TELEGRAM_CHAT_ID:-}"
      
      if [[ -z "$bot_token" || "$bot_token" == "your_bot_token_here" ]]; then
        validation_error_exit "TELEGRAM_BOT_TOKEN not properly configured"
      fi
      
      if [[ -z "$chat_id" || "$chat_id" == "your_chat_id_here" ]]; then
        validation_error_exit "TELEGRAM_CHAT_ID not properly configured"
      fi
      
      # Test Telegram API connectivity
      if command -v curl >/dev/null 2>&1; then
        local test_response=$(curl -s --max-time 10 "https://api.telegram.org/bot${bot_token}/getMe" 2>/dev/null || echo "")
        if [[ "$test_response" =~ "\"ok\":true" ]]; then
          validation_log_info "✅ Telegram bot token validated"
        else
          validation_log_warn "⚠️ Telegram bot token test failed"
        fi
      fi
    fi
  else
    validation_log_info "📱 Notifications disabled in configuration"
  fi
  
  validation_log_info "✅ Notification system validated"
  return 0
}

# === DISK SPACE VALIDATION ===
validate_disk_space() {
  validation_log_info "💾 Validating disk space..."
  
  local required_space_mb=500  # 500MB minimum
  local available_space=$(df "$SCRIPT_DIR" | tail -1 | awk '{print $4}')
  local available_space_mb=$((available_space / 1024))
  
  if [[ $available_space_mb -lt $required_space_mb ]]; then
    validation_error_exit "Insufficient disk space. Required: ${required_space_mb}MB, Available: ${available_space_mb}MB"
  fi
  
  validation_log_info "✅ Disk space validated (${available_space_mb}MB available)"
  return 0
}

# === MEMORY VALIDATION ===
validate_memory() {
  validation_log_info "🧠 Validating system memory..."
  
  local required_memory_mb=1024  # 1GB minimum
  local total_memory=$(free -m | grep '^Mem:' | awk '{print $2}')
  local available_memory=$(free -m | grep '^Mem:' | awk '{print $7}')
  
  if [[ $total_memory -lt $required_memory_mb ]]; then
    validation_log_warn "⚠️ Low total memory. Recommended: ${required_memory_mb}MB, Available: ${total_memory}MB"
  fi
  
  if [[ $available_memory -lt 512 ]]; then
    validation_log_warn "⚠️ Low available memory: ${available_memory}MB"
  fi
  
  validation_log_info "✅ Memory validated (${total_memory}MB total, ${available_memory}MB available)"
  return 0
}

# === COMPREHENSIVE VALIDATION ===
run_comprehensive_validation() {
  validation_log_info "🚀 Starting comprehensive validation..."
  
  initialize_validation
  
  # Run all validations
  validate_system_dependencies
  validate_directory_structure
  validate_env_file
  validate_private_key
  validate_network_configuration
  validate_rpc_endpoints
  validate_executor_binary
  validate_screen_functionality
  validate_notification_system
  validate_disk_space
  validate_memory
  
  validation_log_info "✅ Comprehensive validation completed successfully"
  return 0
}

# === QUICK VALIDATION (Essential Only) ===
run_quick_validation() {
  validation_log_info "⚡ Starting quick validation..."
  
  initialize_validation
  
  # Run essential validations only
  validate_system_dependencies
  validate_directory_structure
  validate_env_file
  validate_private_key
  
  validation_log_info "✅ Quick validation completed successfully"
  return 0
}

# === PRE-RUN VALIDATION ===
run_pre_run_validation() {
  validation_log_info "🔍 Starting pre-run validation..."
  
  initialize_validation
  
  # Run validations needed before execution
  validate_executor_binary
  validate_screen_functionality
  validate_notification_system
  
  validation_log_info "✅ Pre-run validation completed successfully"
  return 0
}

# === VALIDATION REPORT (Complete Network Info) ===
generate_validation_report() {
  local report_file="$LOGS_DIR/validation_report.txt"
  
  validation_log_info "📋 Generating validation report..."
  
  {
    echo "T3RN EXECUTOR VALIDATION REPORT"
    echo "Generated: $(date)"
    echo "========================================"
    echo ""
    
    echo "System Information:"
    echo "  OS: $(uname -s)"
    echo "  Architecture: $(uname -m)"
    echo "  Kernel: $(uname -r)"
    echo "  User: $(whoami)"
    echo "  Working Directory: $SCRIPT_DIR"
    echo ""
    
    echo "Dependencies:"
    local commands=("curl" "tar" "screen" "find" "stat" "grep" "awk" "bc")
    for cmd in "${commands[@]}"; do
      if command -v "$cmd" >/dev/null 2>&1; then
        echo "  ✅ $cmd: $(command -v "$cmd")"
      else
        echo "  ❌ $cmd: NOT FOUND"
      fi
    done
    echo ""
    
    echo "Configuration:"
    if [[ -f "$SCRIPT_DIR/.env" ]]; then
      source "$SCRIPT_DIR/.env" 2>/dev/null || true
      echo "  ✅ .env file: EXISTS"
      echo "  🔑 Private key: ${PRIVATE_KEY_EXECUTOR:+CONFIGURED}"
      echo "  🌐 Networks: ${ENABLED_NETWORKS:-NOT SET}"
      echo "  🏗️ Environment: ${ENVIRONMENT:-NOT SET}"
      echo "  📱 Notifications: ${ENABLE_NOTIFICATIONS:-false}"
      echo "  🎯 Rich notifications: ${ENABLE_RICH_NOTIFICATIONS:-true}"
    else
      echo "  ❌ .env file: NOT FOUND"
    fi
    echo ""
    
    echo "Network Support Matrix:"
    local networks=("arbitrum-sepolia" "base-sepolia" "blast-sepolia" "optimism-sepolia" "unichain-sepolia" "monad-testnet" "sei-testnet" "abstract-testnet" "lisk-sepolia" "berachain-bepolia" "bnb-testnet" "l2rn")
    local alchemy_supported=("arbitrum-sepolia" "base-sepolia" "blast-sepolia" "optimism-sepolia" "unichain-sepolia" "monad-testnet" "sei-testnet" "abstract-testnet" "berachain-bepolia" "bnb-testnet")
    
    for network in "${networks[@]}"; do
      if [[ " ${alchemy_supported[*]} " =~ " ${network} " ]]; then
        echo "  ✅ $network: Alchemy Supported"
      else
        echo "  🔗 $network: Public RPC Only"
      fi
    done
    echo ""
    
    echo "Executor Binary:"
    if [[ -f "$EXECUTOR_PATH" ]]; then
      echo "  ✅ Binary: EXISTS"
      echo "  📁 Path: $EXECUTOR_PATH"
      echo "  📊 Size: $(stat -c%s "$EXECUTOR_PATH" 2>/dev/null || echo "unknown") bytes"
      echo "  🔧 Executable: $(test -x "$EXECUTOR_PATH" && echo "YES" || echo "NO")"
    else
      echo "  ❌ Binary: NOT FOUND"
    fi
    echo ""
    
    echo "System Resources:"
    echo "  💾 Disk Space: $(df -h "$SCRIPT_DIR" | tail -1 | awk '{print $4}') available"
    echo "  🧠 Memory: $(free -h | grep '^Mem:' | awk '{print $7}') available"
    echo "  🖥️ CPU Cores: $(nproc)"
    echo ""
    
  } > "$report_file"
  
  validation_log_info "✅ Validation report saved: $report_file"
  return 0
}

# Initialize on load
initialize_validation

# Export functions
export -f run_comprehensive_validation
export -f run_quick_validation
export -f run_pre_run_validation
export -f validate_system_dependencies
export -f validate_directory_structure
export -f validate_env_file
export -f validate_private_key
export -f validate_network_configuration
export -f validate_rpc_endpoints
export -f validate_executor_binary
export -f validate_screen_functionality
export -f validate_notification_system
export -f validate_disk_space
export -f validate_memory
export -f generate_validation_report
