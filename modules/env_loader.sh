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
  # Initialize SCRIPT_DIR first (safe with default)
  local script_dir="${SCRIPT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")"/.. && pwd)}"
  export SCRIPT_DIR="$script_dir"
  
  # Initialize LOGS_DIR based on SCRIPT_DIR (safe with default)
  local logs_dir="${LOGS_DIR:-$script_dir/logs}"
  export LOGS_DIR="$logs_dir"
  
  # Now safe to create directory
  mkdir -p "$LOGS_DIR" || env_error_exit "Cannot create logs directory: $LOGS_DIR"
  
  env_log_info "🔧 Environment loader initialized"
}

# === ENVIRONMENT FILE PATHS ===
ENV_FILE="$SCRIPT_DIR/.env"
ENV_TEMPLATE="$SCRIPT_DIR/.env.example"
ENV_BACKUP_DIR="$SCRIPT_DIR/.env_backups"
ENV_VALIDATION_LOG="$LOGS_DIR/env_validation.log"

# === LOAD ENVIRONMENT ===
load_environment() {
  local env_file="${1:-$ENV_FILE}"
  local validate="${2:-true}"
  
  env_log_info "🔧 Loading environment from: $env_file"
  
  # Check if file exists - NO AUTO CREATE
  if [[ ! -f "$env_file" ]]; then
    env_error_exit ".env file not found: $env_file. Please copy from .env.example and configure it."
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
  
  # Set derived variables (safe with defaults)
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
export -f validate_env_syntax
export -f validate_required_variables
export -f validate_optional_variables
export -f load_environment
export -f get_env_status
export -f validate_env_configuration
