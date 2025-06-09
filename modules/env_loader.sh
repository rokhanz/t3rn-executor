#!/bin/bash
set -euo pipefail

# ╔══════════════════════════════════════════════════════════════╗
# ║                    T3RN ENVIRONMENT LOADER                  ║
# ║                  (Configuration Management)                 ║
# ╚══════════════════════════════════════════════════════════════╝

# T3RN Executor Environment Loader
# Secure environment configuration loading with validation and backup management
#
# @author Rokhanz
# @license MIT
# @version 1.0.0


# === INTERNAL ERROR HANDLING ===
env_error_exit() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] ENV ERROR: $*" >&2
  exit 1
}

env_log_info() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] ENV INFO: $*"
}

env_log_warn() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] ENV WARN: $*"
}

# === INITIALIZE ENVIRONMENT LOADER ===
initialize_env_loader() {
  if [[ -z "${SCRIPT_DIR:-}" ]]; then
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")"/.. && pwd)"
    export SCRIPT_DIR
  fi
  
  if [[ -z "${LOGS_DIR:-}" ]]; then
    LOGS_DIR="$SCRIPT_DIR/logs"
    export LOGS_DIR
  fi
  
  mkdir -p "$LOGS_DIR" || env_error_exit "Cannot create logs directory"
  
  env_log_info "🔧 Environment loader initialized"
}

# === ENVIRONMENT FILE PATHS ===
ENV_FILE="$SCRIPT_DIR/.env"
ENV_TEMPLATE="$SCRIPT_DIR/.env.template"
ENV_BACKUP_DIR="$SCRIPT_DIR/.env_backups"
ENV_VALIDATION_LOG="$LOGS_DIR/env_validation.log"

# === CREATE ENV TEMPLATE ===
create_env_template() {
  env_log_info "📝 Creating .env template..."
  
  cat > "$ENV_TEMPLATE" << 'EOF'
# ╔══════════════════════════════════════════════════════════════╗
# ║                    T3RN EXECUTOR CONFIG                     ║
# ║                   (User Configuration)                      ║
# ╚══════════════════════════════════════════════════════════════╝

# === 🔧 EXECUTOR VERSION ===
EXECUTOR_USE_MANUAL_VERSION=false
EXECUTOR_VERSION=v0.88.0

# === 🌐 NETWORK CONFIGURATION ===
ENABLED_NETWORKS="arbitrum-sepolia,base-sepolia,blast-sepolia,optimism-sepolia,unichain-sepolia"
EXECUTOR_ENABLED_NETWORKS="arbitrum-sepolia,base-sepolia,blast-sepolia,optimism-sepolia,unichain-sepolia"
EXECUTOR_ENABLED_ASSETS="*"

# === 🔑 WALLET CONFIGURATION ===
PRIVATE_KEY_EXECUTOR="your_private_key_without_0x_prefix_64_characters_here"

# === 🏗️ ENVIRONMENT SETTINGS ===
ENVIRONMENT="testnet"
LOG_LEVEL="info"
LOG_PRETTY="false"
LOG_FORMAT="simple"
NODE_TYPE="alchemy-complete"
RUST_LOG="info"
RUST_BACKTRACE="0"
NODE_ENV="production"

# === 🔑 ALCHEMY API KEYS ===
ALCHEMY_KEY_1="your_first_alchemy_api_key"
ALCHEMY_KEY_2="your_second_alchemy_api_key"
ALCHEMY_KEY_3="your_third_alchemy_api_key"
ALCHEMY_KEY_4=""
ALCHEMY_KEY_5=""
ALCHEMY_KEY_6=""
ALCHEMY_KEY_7=""
ALCHEMY_KEY_8=""

# === 🌐 RPC OVERRIDES (Optional - kosongkan untuk gunakan default) ===
RPC_ARBT_OVERRIDE=""
RPC_BAST_OVERRIDE=""
RPC_BLST_OVERRIDE=""
RPC_OPST_OVERRIDE=""
RPC_UNIT_OVERRIDE=""
RPC_MONT_OVERRIDE=""
RPC_SEIT_OVERRIDE=""
RPC_ABST_OVERRIDE=""
RPC_LISK_OVERRIDE=""
RPC_BERA_OVERRIDE=""
RPC_BNB_OVERRIDE=""
RPC_L2RN_OVERRIDE=""

# === 🔒 PROXY CONFIGURATION ===
USE_PROXY=false
PROXY_FILE="proxies.txt"
PROXY_FAILOVER_MODE=true
PROXY_VALIDATION_TIMEOUT=10
PROXY_RETRY_ATTEMPTS=3
USE_VPS_FALLBACK=true
PROXY_MAX_CONCURRENT_TESTS=10
PROXY_HEALTH_CHECK_INTERVAL=300
PROXY_ROTATION_INTERVAL=3600

# === 🛡️ ANTI-MEV PROTECTION ===
ENABLE_ANTI_MEV=true
MEV_PROTECTION_LEVEL="medium"
SLIPPAGE_TOLERANCE="0.5"
MEV_PROTECTION_DELAY="2"
PRIVATE_MEMPOOL=false
FLASHLOAN_PROTECTION=true
SANDWICH_PROTECTION=true
FRONTRUN_PROTECTION=true

# === 🔄 AUTORESTART CONFIGURATION ===
AUTORESTART_MAX_ATTEMPTS=10
AUTORESTART_SLEEP_INTERVAL=15

# === 🎯 EXECUTOR SPECIFIC SETTINGS ===
EXECUTOR_PROCESS_BIDS_ENABLED="true"
EXECUTOR_PROCESS_ORDERS_ENABLED="true"
EXECUTOR_PROCESS_CLAIMS_ENABLED="true"
EXECUTOR_MAX_L3_GAS_PRICE="100000"
EXECUTOR_PROCESS_PENDING_ORDERS_FROM_API="false"

# === 💰 BALANCE THRESHOLDS ===
EXECUTOR_MIN_BALANCE_THRESHOLD_ETH="0.5"
BALANCE_MINIMUM_REQUIRED="0.5"
BALANCE_THRESHOLD_ARBT="0.3"
BALANCE_THRESHOLD_BAST="0.3"
BALANCE_THRESHOLD_BLST="0.5"
BALANCE_THRESHOLD_OPST="0.3"
BALANCE_THRESHOLD_UNIT="0.5"

# === 🔔 ENHANCED NOTIFICATION CONFIGURATION ===
ENABLE_NOTIFICATIONS=true
NOTIFICATION_LEVEL="all_success"
ENABLE_VERBOSE_LOGGING=false

# === 📱 TELEGRAM CONFIGURATION ===
TELEGRAM_BOT_TOKEN="your_bot_token_here"
TELEGRAM_CHAT_ID="your_chat_id_here"
TELEGRAM_ENABLE=true

# === 🎯 T3RN SPECIFIC NOTIFICATION SETTINGS ===
NOTIFY_BID_SUCCESS=true
NOTIFY_ORDER_SUCCESS=true
NOTIFY_CLAIM_SUCCESS=true
NOTIFY_PROFIT_THRESHOLD="0"
NOTIFY_BALANCE_THRESHOLD="0"
NOTIFY_NETWORK_ERRORS=true
NOTIFY_RESTART_EVENTS=true

# === 📊 NOTIFICATION FILTERS (DISABLED - POST EVERYTHING) ===
MIN_NOTIFICATION_VALUE="0"
MAX_NOTIFICATIONS_PER_HOUR=999999
NOTIFICATION_COOLDOWN=0
QUIET_HOURS_START=""
QUIET_HOURS_END=""

# === 📊 BALANCE REPORTING ENHANCEMENT ===
ENABLE_RICH_NOTIFICATIONS=true
BALANCE_REPORT_INTERVAL=600
ENABLE_BALANCE_REPORTING=true
BALANCE_REPORT_DETAILED=true

# === 🎨 RICH NOTIFICATION SETTINGS ===
SHOW_TRANSACTION_DETAILS=true
SHOW_NETWORK_LATENCY=true
SHOW_GAS_FEES=true
SHOW_ESTIMATED_REWARDS=true

# === 💰 GAS CONFIGURATION ===
GAS_PRICE_MULTIPLIER="1.1"
GAS_LIMIT_MULTIPLIER=1.2
MAX_GAS_PRICE=100000
TRANSACTION_RETRY_DELAY="2"
MAX_SLIPPAGE="0.5"

# === 🌐 NETWORK PERFORMANCE ===
NETWORK_TIMEOUT=30000
CONNECTION_POOL_SIZE=20
MAX_RETRIES_PER_REQUEST=3
KEEP_ALIVE_TIMEOUT=5000
SOCKET_TIMEOUT=30000

# === ⚡ EXECUTOR PERFORMANCE ===
EXECUTOR_MAX_CONCURRENT_REQUESTS=10
EXECUTOR_REQUEST_TIMEOUT=30000
EXECUTOR_RETRY_ATTEMPTS=3
EXECUTOR_RETRY_DELAY=1000

# === 🎯 EXECUTION STRATEGY ===
EXECUTION_STRATEGY="aggressive"
BID_STRATEGY="competitive"
CLAIM_STRATEGY="fast"
ORDER_PROCESSING_DELAY=1000
BID_PROCESSING_DELAY=500
CLAIM_PROCESSING_DELAY=2000
RISK_TOLERANCE="medium"
PROFIT_MARGIN="0.001"

# === 📊 MONITORING CONFIGURATION ===
ENABLE_RPC_HEALTH_CHECK=true
RPC_HEALTH_CHECK_INTERVAL=300
ENABLE_BALANCE_MONITORING=true
BALANCE_CHECK_INTERVAL=600
ENABLE_NETWORK_MONITORING=true
ENABLE_PERFORMANCE_MONITORING=true

# === 🔐 SECURITY SETTINGS ===
ENABLE_RATE_LIMITING=true
MAX_REQUESTS_PER_MINUTE=60
ENABLE_REQUEST_LOGGING=false
ENABLE_ERROR_REPORTING=true

# === 🎨 UI CONFIGURATION ===
ENABLE_PROGRESS_BAR=true
ENABLE_COLOR_OUTPUT=true
ENABLE_EMOJI_LOGGING=true
PROGRESS_BAR_STYLE="batch"

# === 🧪 TESTING CONFIGURATION ===
ENABLE_TEST_MODE=false
TEST_NETWORK_ONLY=false
MOCK_TRANSACTIONS=false
DRY_RUN_MODE=false

# === 📝 LOGGING CONFIGURATION ===
LOG_TO_FILE=true
LOG_ROTATION_SIZE="100M"
LOG_RETENTION_DAYS=7

# === 🔄 FAILOVER CONFIGURATION ===
ENABLE_FAILOVER=true
FAILOVER_THRESHOLD=3
FAILOVER_COOLDOWN=300
AUTO_RECOVERY=true

# === 📈 METRICS CONFIGURATION ===
ENABLE_METRICS=true
METRICS_PORT=9090
METRICS_PATH="/metrics"
ENABLE_PROMETHEUS=false

# === 🛠️ MAINTENANCE CONFIGURATION ===
ENABLE_AUTO_UPDATE=false
UPDATE_CHECK_INTERVAL=86400
MAINTENANCE_MODE=false
GRACEFUL_SHUTDOWN_TIMEOUT=30

# === 📁 PATH CONFIGURATION (Auto-detected, uncomment to override) ===
# SCRIPT_DIR="/path/to/t3rn-executor"
# T3RN_DIR="/path/to/t3rn-executor/t3rn"
# EXECUTOR_PATH="/path/to/t3rn-executor/t3rn/executor/executor/bin/executor"
# MODULES_DIR="/path/to/t3rn-executor/modules"
# LOGS_DIR="/path/to/t3rn-executor/logs"

# === 🔧 ADVANCED SETTINGS ===
ENABLE_DEBUG_MODE=false
ENABLE_PERFORMANCE_MONITORING=true

# === 🌐 NETWORK SPECIFIC RPC (Auto-generated by RPC manager) ===
# RPC_ARBT="https://arb-sepolia.g.alchemy.com/v2/YOUR_KEY"
# RPC_BAST="https://base-sepolia.g.alchemy.com/v2/YOUR_KEY"
# RPC_BLST="https://blast-sepolia.g.alchemy.com/v2/YOUR_KEY"
# RPC_OPST="https://opt-sepolia.g.alchemy.com/v2/YOUR_KEY"
# RPC_UNIT="https://sepolia.unichain.org"
# RPC_MONT="https://testnet-rpc.monad.xyz"
# RPC_SEIT="https://evm-rpc-testnet.sei-apis.com"
# RPC_L2RN="wss://rpc.t1rn.io"
EOF
  
  env_log_info "✅ .env template created: $ENV_TEMPLATE"
}

# === VALIDATE ENV FILE SYNTAX ===
validate_env_syntax() {
  local env_file="${1:-$ENV_FILE}"
  
  env_log_info "🔍 Validating .env file syntax: $env_file"
  
  if [[ ! -f "$env_file" ]]; then
    env_log_warn "⚠️ Environment file not found: $env_file"
    return 1
  fi
  
  # Test syntax by sourcing in a subshell
  if (source "$env_file") 2>/dev/null; then
    env_log_info "✅ .env file syntax is valid"
    return 0
  else
    env_log_warn "❌ .env file has syntax errors"
    return 1
  fi
}

# === VALIDATE REQUIRED VARIABLES ===
validate_required_variables() {
  local env_file="${1:-$ENV_FILE}"
  
  env_log_info "🔍 Validating required environment variables..."
  
  # Source the env file
  source "$env_file" || env_error_exit "Failed to source .env file"
  
  # Define required variables
  local required_vars=(
    "PRIVATE_KEY_EXECUTOR"
    "ENABLED_NETWORKS"
    "ENVIRONMENT"
    "LOG_LEVEL"
    "EXECUTOR_PROCESS_BIDS_ENABLED"
    "EXECUTOR_PROCESS_ORDERS_ENABLED"
    "EXECUTOR_PROCESS_CLAIMS_ENABLED"
  )
  
  local missing_vars=()
  local invalid_vars=()
  
  # Check each required variable
  for var in "${required_vars[@]}"; do
    if [[ -z "${!var:-}" ]]; then
      missing_vars+=("$var")
    else
      # Validate specific variables
      case "$var" in
        "PRIVATE_KEY_EXECUTOR")
          if [[ ${#PRIVATE_KEY_EXECUTOR} -ne 64 ]] || [[ ! "$PRIVATE_KEY_EXECUTOR" =~ ^[a-fA-F0-9]+$ ]]; then
            invalid_vars+=("$var (must be 64 hex characters)")
          fi
          ;;
        "ENVIRONMENT")
          if [[ ! "$ENVIRONMENT" =~ ^(testnet|mainnet)$ ]]; then
            invalid_vars+=("$var (must be testnet or mainnet)")
          fi
          ;;
        "LOG_LEVEL")
          if [[ ! "$LOG_LEVEL" =~ ^(debug|info|warn|error)$ ]]; then
            invalid_vars+=("$var (must be debug, info, warn, or error)")
          fi
          ;;
      esac
    fi
  done
  
  # Report results
  if [[ ${#missing_vars[@]} -gt 0 ]]; then
    env_log_warn "❌ Missing required variables: ${missing_vars[*]}"
    return 1
  fi
  
  if [[ ${#invalid_vars[@]} -gt 0 ]]; then
    env_log_warn "❌ Invalid variables: ${invalid_vars[*]}"
    return 1
  fi
  
  env_log_info "✅ All required variables are valid"
  return 0
}

# === VALIDATE OPTIONAL VARIABLES ===
validate_optional_variables() {
  local env_file="${1:-$ENV_FILE}"
  
  env_log_info "🔍 Validating optional environment variables..."
  
  source "$env_file" || return 1
  
  local warnings=()
  
  # Check Telegram configuration
  if [[ "${ENABLE_NOTIFICATIONS:-false}" == "true" && "${TELEGRAM_ENABLE:-false}" == "true" ]]; then
    if [[ -z "${TELEGRAM_BOT_TOKEN:-}" || "${TELEGRAM_BOT_TOKEN}" == "your_bot_token_here" ]]; then
      warnings+=("TELEGRAM_BOT_TOKEN not configured")
    fi
    
    if [[ -z "${TELEGRAM_CHAT_ID:-}" || "${TELEGRAM_CHAT_ID}" == "your_chat_id_here" ]]; then
      warnings+=("TELEGRAM_CHAT_ID not configured")
    fi
  fi
  
  # Check Alchemy keys
  local alchemy_keys=("${ALCHEMY_KEY_1:-}" "${ALCHEMY_KEY_2:-}" "${ALCHEMY_KEY_3:-}")
  local valid_alchemy_keys=0
  
  for key in "${alchemy_keys[@]}"; do
    if [[ -n "$key" && "$key" != "your_alchemy_api_key" ]]; then
      ((valid_alchemy_keys++))
    fi
  done
  
  if [[ $valid_alchemy_keys -eq 0 ]]; then
    warnings+=("No valid Alchemy API keys configured")
  fi
  
  # Check balance thresholds
  local balance_threshold="${EXECUTOR_MIN_BALANCE_THRESHOLD_ETH:-0.5}"
  if [[ ! "$balance_threshold" =~ ^[0-9]+\.?[0-9]*$ ]]; then
    warnings+=("Invalid EXECUTOR_MIN_BALANCE_THRESHOLD_ETH format")
  fi
  
  # Report warnings
  if [[ ${#warnings[@]} -gt 0 ]]; then
    for warning in "${warnings[@]}"; do
      env_log_warn "⚠️ $warning"
    done
  else
    env_log_info "✅ Optional variables validation passed"
  fi
  
  return 0
}

# === BACKUP ENV FILE ===
backup_env_file() {
  local env_file="${1:-$ENV_FILE}"
  
  if [[ ! -f "$env_file" ]]; then
    env_log_warn "⚠️ No .env file to backup"
    return 1
  fi
  
  mkdir -p "$ENV_BACKUP_DIR"
  
  local backup_file="$ENV_BACKUP_DIR/.env.backup.$(date +%Y%m%d_%H%M%S)"
  
  if cp "$env_file" "$backup_file"; then
    env_log_info "✅ .env file backed up to: $backup_file"
    return 0
  else
    env_log_warn "❌ Failed to backup .env file"
    return 1
  fi
}

# === RESTORE ENV FILE ===
restore_env_file() {
  local backup_file="$1"
  
  if [[ ! -f "$backup_file" ]]; then
    env_log_warn "⚠️ Backup file not found: $backup_file"
    return 1
  fi
  
  # Backup current .env before restore
  if [[ -f "$ENV_FILE" ]]; then
    backup_env_file "$ENV_FILE"
  fi
  
  if cp "$backup_file" "$ENV_FILE"; then
    env_log_info "✅ .env file restored from: $backup_file"
    return 0
  else
    env_log_warn "❌ Failed to restore .env file"
    return 1
  fi
}

# === LIST ENV BACKUPS ===
list_env_backups() {
  env_log_info "📋 Available .env backups:"
  
  if [[ ! -d "$ENV_BACKUP_DIR" ]]; then
    env_log_info "   No backups found"
    return 0
  fi
  
  local backups=($(ls -1t "$ENV_BACKUP_DIR"/.env.backup.* 2>/dev/null || true))
  
  if [[ ${#backups[@]} -eq 0 ]]; then
    env_log_info "   No backups found"
    return 0
  fi
  
  for backup in "${backups[@]}"; do
    local backup_name=$(basename "$backup")
    local backup_date=$(echo "$backup_name" | grep -oP '\d{8}_\d{6}')
    local formatted_date=$(echo "$backup_date" | sed 's/\([0-9]\{4\}\)\([0-9]\{2\}\)\([0-9]\{2\}\)_\([0-9]\{2\}\)\([0-9]\{2\}\)\([0-9]\{2\}\)/\1-\2-\3 \4:\5:\6/')
    local file_size=$(stat -c%s "$backup" 2>/dev/null || echo "unknown")
    
    env_log_info "   📄 $backup_name ($formatted_date, ${file_size} bytes)"
  done
}

# === LOAD ENVIRONMENT ===
load_environment() {
  local env_file="${1:-$ENV_FILE}"
  local validate="${2:-true}"
  
  env_log_info "🔧 Loading environment from: $env_file"
  
  # Check if file exists
  if [[ ! -f "$env_file" ]]; then
    env_log_warn "⚠️ .env file not found, creating from template..."
    
    if [[ ! -f "$ENV_TEMPLATE" ]]; then
      create_env_template
    fi
    
    cp "$ENV_TEMPLATE" "$env_file"
    env_log_info "📝 Please edit $env_file with your configuration"
    return 1
  fi
  
  # Validate syntax if requested
  if [[ "$validate" == "true" ]]; then
    if ! validate_env_syntax "$env_file"; then
      env_error_exit "Invalid .env file syntax"
    fi
  fi
  
  # Source the environment file
  source "$env_file" || env_error_exit "Failed to load .env file"
  
  # Validate required variables if requested
  if [[ "$validate" == "true" ]]; then
    validate_required_variables "$env_file"
    validate_optional_variables "$env_file"
  fi
  
  # Set derived variables
  export SCRIPT_DIR="${SCRIPT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")"/.. && pwd)}"
  export T3RN_DIR="${T3RN_DIR:-$SCRIPT_DIR/t3rn}"
  export EXECUTOR_PATH="${EXECUTOR_PATH:-$T3RN_DIR/executor/executor/bin/executor}"
  export MODULES_DIR="${MODULES_DIR:-$SCRIPT_DIR/modules}"
  export LOGS_DIR="${LOGS_DIR:-$SCRIPT_DIR/logs}"
  
  # Parse enabled networks into array
  IFS=',' read -ra ENABLED_NETWORKS_ARRAY <<< "${ENABLED_NETWORKS:-}"
  export ENABLED_NETWORKS_ARRAY
  
  env_log_info "✅ Environment loaded successfully"
  env_log_info "   📁 Script Directory: $SCRIPT_DIR"
  env_log_info "   📁 T3RN Directory: $T3RN_DIR"
  env_log_info "   📁 Logs Directory: $LOGS_DIR"
  env_log_info "   🌐 Enabled Networks: ${#ENABLED_NETWORKS_ARRAY[@]} networks"
  env_log_info "   🔧 Environment: ${ENVIRONMENT:-unknown}"
  env_log_info "   📊 Log Level: ${LOG_LEVEL:-unknown}"
  
  return 0
}

# === RELOAD ENVIRONMENT ===
reload_environment() {
  env_log_info "🔄 Reloading environment configuration..."
  
  # Backup current environment
  backup_env_file
  
  # Reload
  load_environment "$ENV_FILE" true
  
  env_log_info "✅ Environment reloaded"
}

# === UPDATE ENV VARIABLE ===
update_env_variable() {
  local var_name="$1"
  local var_value="$2"
  local env_file="${3:-$ENV_FILE}"
  
  env_log_info "🔧 Updating environment variable: $var_name"
  
  # Backup before modification
  backup_env_file "$env_file"
  
  # Update the variable
  if grep -q "^$var_name=" "$env_file"; then
    # Variable exists, update it
    sed -i "s/^$var_name=.*/$var_name=\"$var_value\"/" "$env_file"
    env_log_info "✅ Updated existing variable: $var_name"
  else
    # Variable doesn't exist, add it
    echo "$var_name=\"$var_value\"" >> "$env_file"
    env_log_info "✅ Added new variable: $var_name"
  fi
  
  # Validate after update
  if validate_env_syntax "$env_file"; then
    env_log_info "✅ .env file updated successfully"
    return 0
  else
    env_log_warn "❌ .env file syntax error after update, restoring backup..."
    restore_env_file "$ENV_BACKUP_DIR/.env.backup.$(date +%Y%m%d_%H%M%S)"
    return 1
  fi
}

# === GENERATE ENV REPORT ===
generate_env_report() {
  local report_file="${LOGS_DIR}/env_report.txt"
  
  env_log_info "📋 Generating environment report..."
  
  {
    echo "T3RN EXECUTOR ENVIRONMENT REPORT"
    echo "Generated: $(date)"
    echo "========================================"
    echo ""
    
    echo "Environment File Status:"
    if [[ -f "$ENV_FILE" ]]; then
      echo "  ✅ .env file: EXISTS"
      echo "  📁 Path: $ENV_FILE"
      echo "  📊 Size: $(stat -c%s "$ENV_FILE" 2>/dev/null || echo "unknown") bytes"
      echo "  📅 Modified: $(stat -c%y "$ENV_FILE" 2>/dev/null || echo "unknown")"
      echo "  🔧 Syntax: $(validate_env_syntax "$ENV_FILE" >/dev/null 2>&1 && echo "VALID" || echo "INVALID")"
    else
      echo "  ❌ .env file: NOT FOUND"
    fi
    echo ""
    
    echo "Template Status:"
    if [[ -f "$ENV_TEMPLATE" ]]; then
      echo "  ✅ Template: EXISTS"
      echo "  📁 Path: $ENV_TEMPLATE"
    else
      echo "  ❌ Template: NOT FOUND"
    fi
    echo ""
    
    echo "Backup Status:"
    if [[ -d "$ENV_BACKUP_DIR" ]]; then
      local backup_count=$(ls -1 "$ENV_BACKUP_DIR"/.env.backup.* 2>/dev/null | wc -l)
      echo "  📁 Backup Directory: EXISTS"
      echo "  📊 Backup Count: $backup_count"
      if [[ $backup_count -gt 0 ]]; then
        local latest_backup=$(ls -1t "$ENV_BACKUP_DIR"/.env.backup.* 2>/dev/null | head -1)
        echo "  📅 Latest Backup: $(basename "$latest_backup")"
      fi
    else
      echo "  📁 Backup Directory: NOT FOUND"
    fi
    echo ""
    
    if [[ -f "$ENV_FILE" ]]; then
      source "$ENV_FILE" 2>/dev/null || true
      
      echo "Configuration Summary:"
      echo "  🔧 Environment: ${ENVIRONMENT:-not set}"
      echo "  📊 Log Level: ${LOG_LEVEL:-not set}"
      echo "  🌐 Networks: ${ENABLED_NETWORKS:-not set}"
      echo "  🔑 Private Key: ${PRIVATE_KEY_EXECUTOR:+CONFIGURED}"
      echo "  📱 Notifications: ${ENABLE_NOTIFICATIONS:-false}"
      echo "  🎯 Rich Notifications: ${ENABLE_RICH_NOTIFICATIONS:-true}"
      echo "  🔒 Proxy: ${USE_PROXY:-false}"
      echo "  🛡️ Anti-MEV: ${ENABLE_ANTI_MEV:-false}"
      echo ""
      
      echo "Validation Results:"
      if validate_required_variables "$ENV_FILE" >/dev/null 2>&1; then
        echo "  ✅ Required Variables: VALID"
      else
        echo "  ❌ Required Variables: INVALID"
      fi
      
      if validate_optional_variables "$ENV_FILE" >/dev/null 2>&1; then
        echo "  ✅ Optional Variables: VALID"
      else
        echo "  ⚠️ Optional Variables: WARNINGS"
      fi
    fi
    echo ""
    
  } > "$report_file"
  
  env_log_info "✅ Environment report saved: $report_file"
}

# === GET ENV STATUS ===
get_env_status() {
  if [[ -f "$ENV_FILE" ]]; then
    if validate_env_syntax "$ENV_FILE" >/dev/null 2>&1; then
      echo "LOADED: $(wc -l < "$ENV_FILE") lines"
    else
      echo "SYNTAX_ERROR"
    fi
  else
    echo "NOT_FOUND"
  fi
}

# === VALIDATE ENV CONFIGURATION ===
validate_env_configuration() {
  env_log_info "🔍 Validating complete environment configuration..."
  
  local validation_passed=true
  
  # Check file existence
  if [[ ! -f "$ENV_FILE" ]]; then
    env_log_warn "❌ .env file not found"
    validation_passed=false
  fi
  
  # Check syntax
  if ! validate_env_syntax "$ENV_FILE"; then
    validation_passed=false
  fi
  
  # Check required variables
  if ! validate_required_variables "$ENV_FILE"; then
    validation_passed=false
  fi
  
  # Check optional variables (warnings only)
  validate_optional_variables "$ENV_FILE"
  
  if [[ "$validation_passed" == "true" ]]; then
    env_log_info "✅ Environment configuration validation passed"
    return 0
  else
    env_log_warn "❌ Environment configuration validation failed"
    return 1
  fi
}

# Initialize on load
initialize_env_loader

# Export functions
export -f initialize_env_loader
export -f create_env_template
export -f validate_env_syntax
export -f validate_required_variables
export -f validate_optional_variables
export -f backup_env_file
export -f restore_env_file
export -f list_env_backups
export -f load_environment
export -f reload_environment
export -f update_env_variable
export -f generate_env_report
export -f get_env_status
export -f validate_env_configuration
