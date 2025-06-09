#!/bin/bash
set -euo pipefail

# ╔══════════════════════════════════════════════════════════════╗
# ║                    T3RN EXECUTOR BINARY                     ║
# ║                  (Enhanced with Wallet Info)               ║
# ╚══════════════════════════════════════════════════════════════╝

# T3RN Executor Binary Management
# Enhanced executor management with rich Telegram notifications and wallet integration
#
# @author Rokhanz
# @license MIT
# @version 1.0.0

# === INTERNAL ERROR HANDLING ===
executor_error_exit() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] EXECUTOR ERROR: $*" >&2
  exit 1
}

executor_log_info() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] EXECUTOR INFO: $*"
}

executor_log_warn() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] EXECUTOR WARN: $*"
}

# === INTERNAL VALIDATION ===
validate_executor_environment() {
  executor_log_info "🔍 Validating executor environment..."
  
  if ! command -v validate_executor_binary >/dev/null 2>&1; then
    if [[ -f "$SCRIPT_DIR/modules/validation.sh" ]]; then
      source "$SCRIPT_DIR/modules/validation.sh" || executor_error_exit "Failed to load validation.sh"
    fi
  fi
  
  if command -v validate_executor_binary >/dev/null 2>&1; then
    validate_executor_binary || executor_error_exit "Executor binary validation failed"
    validate_private_key || executor_error_exit "Private key validation failed"
    validate_network_configuration || executor_error_exit "Network configuration validation failed"
    validate_notification_system || executor_error_exit "Notification system validation failed"
  fi
  
  [[ -n "${SCRIPT_DIR:-}" ]] || executor_error_exit "SCRIPT_DIR not set"
  [[ -n "${EXECUTOR_PATH:-}" ]] || executor_error_exit "EXECUTOR_PATH not set"
  [[ -n "${LOGS_DIR:-}" ]] || executor_error_exit "LOGS_DIR not set"
  
  mkdir -p "$LOGS_DIR" || executor_error_exit "Cannot create logs directory: $LOGS_DIR"
  
  executor_log_info "✅ Executor environment validated"
  return 0
}

# === INITIALIZE EXECUTOR BINARY ===
initialize_executor_binary() {
  if [[ -z "${SCRIPT_DIR:-}" ]]; then
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")"/.. && pwd)"
    export SCRIPT_DIR
  fi

  if [[ -z "${EXECUTOR_PATH:-}" ]]; then
    EXECUTOR_PATH="$SCRIPT_DIR/t3rn/executor/executor/bin/executor"
    export EXECUTOR_PATH
  fi

  if [[ -z "${LOGS_DIR:-}" ]]; then
    LOGS_DIR="$SCRIPT_DIR/logs"
    export LOGS_DIR
  fi
  
  if [[ -f "$SCRIPT_DIR/modules/validation.sh" ]]; then
    source "$SCRIPT_DIR/modules/validation.sh" 2>/dev/null || true
  fi
  
  # Load balance checker for wallet address functionality
  if [[ -f "$SCRIPT_DIR/modules/balance_checker.sh" ]]; then
    source "$SCRIPT_DIR/modules/balance_checker.sh" 2>/dev/null || true
  fi
  
  validate_executor_environment
}

# === GET NETWORK EMOJI (Complete dengan Semua Network) ===
get_network_emoji() {
  local network="$1"
  case "$network" in
    "arbitrum-sepolia"|"arbt") echo "🔵" ;;
    "base-sepolia"|"bast") echo "🔷" ;;
    "blast-sepolia"|"blst") echo "💥" ;;
    "optimism-sepolia"|"opst") echo "🔴" ;;
    "unichain-sepolia"|"unit") echo "🦄" ;;
    "monad-testnet"|"mont") echo "🌙" ;;
    "sei-testnet"|"seit") echo "⚡" ;;
    "abstract-testnet"|"abst") echo "🎨" ;;
    "lisk-sepolia"|"lisk") echo "🔗" ;;
    "berachain-bepolia"|"bera") echo "🐻" ;;
    "bnb-testnet"|"bnb") echo "🟡" ;;
    "l2rn") echo "🌐" ;;
    *) echo "🔗" ;;
  esac
}

# === GET EXECUTION TYPE EMOJI ===
get_execution_emoji() {
  local type="$1"
  case "$type" in
    "bid") echo "🎯" ;;
    "execution") echo "⚡" ;;
    "claim") echo "💎" ;;
    "transfer") echo "💸" ;;
    "swap") echo "🔄" ;;
    "batch") echo "🚀" ;;
    *) echo "✨" ;;
  esac
}

# === PARSE LOG DATA FOR RICH NOTIFICATIONS ===
parse_log_data() {
  local line="$1"
  local data_type="$2"
  
  case "$data_type" in
    "order_id")
      echo "$line" | grep -oP '"orderId":"[^"]*"' | cut -d'"' -f4 || \
      echo "$line" | grep -oP '"id":"[^"]*"' | cut -d'"' -f4 || echo "N/A"
      ;;
    "tx_hash")
      echo "$line" | grep -oP '"txHash":"[^"]*"' | cut -d'"' -f4 || \
      echo "$line" | grep -oP '"hash":"[^"]*"' | cut -d'"' -f4 || echo "N/A"
      ;;
    "source_chain")
      echo "$line" | grep -oP '"source":\["[^"]*"' | cut -d'"' -f4 || \
      echo "$line" | grep -oP '"from":"[^"]*"' | cut -d'"' -f4 || echo "N/A"
      ;;
    "dest_chain")
      echo "$line" | grep -oP '"destination":\["[^"]*"' | cut -d'"' -f4 || \
      echo "$line" | grep -oP '"to":"[^"]*"' | cut -d'"' -f4 || echo "N/A"
      ;;
    "amount")
      echo "$line" | grep -oP '"amount":\["[^"]*"' | cut -d'"' -f4 || \
      echo "$line" | grep -oP '"value":"[^"]*"' | cut -d'"' -f4 || echo "0"
      ;;
    "gas_fee")
      echo "$line" | grep -oP '"gasUsed":"[^"]*"' | cut -d'"' -f4 || \
      echo "$line" | grep -oP '"gas":"[^"]*"' | cut -d'"' -f4 || echo "N/A"
      ;;
    "reward")
      echo "$line" | grep -oP '"reward":"[^"]*"' | cut -d'"' -f4 || \
      echo "$line" | grep -oP '"brn":"[^"]*"' | cut -d'"' -f4 || echo "N/A"
      ;;
    "network")
      echo "$line" | grep -oP '"network":"[^"]*"' | cut -d'"' -f4 || echo "N/A"
      ;;
    "count")
      echo "$line" | grep -oP '"count":[0-9]+' | cut -d':' -f2 || echo "1"
      ;;
  esac
}

# === GET RPC INFO (Complete dengan Alchemy Support) ===
get_rpc_info() {
  local network="$1"
  local rpc_name="Unknown"
  local rpc_latency="N/A"
  
  case "$network" in
    "arbitrum-sepolia"|"arbt") 
      rpc_name="Arbitrum Sepolia (Alchemy)"
      rpc_latency=$(ping -c 1 -W 2 arb-sepolia.g.alchemy.com 2>/dev/null | grep 'time=' | cut -d'=' -f4 | cut -d' ' -f1 || echo "N/A")
      ;;
    "base-sepolia"|"bast") 
      rpc_name="Base Sepolia (Alchemy)"
      rpc_latency=$(ping -c 1 -W 2 base-sepolia.g.alchemy.com 2>/dev/null | grep 'time=' | cut -d'=' -f4 | cut -d' ' -f1 || echo "N/A")
      ;;
    "blast-sepolia"|"blst") 
      rpc_name="Blast Sepolia (Alchemy)"
      rpc_latency=$(ping -c 1 -W 2 blast-sepolia.g.alchemy.com 2>/dev/null | grep 'time=' | cut -d'=' -f4 | cut -d' ' -f1 || echo "N/A")
      ;;
    "optimism-sepolia"|"opst") 
      rpc_name="Optimism Sepolia (Alchemy)"
      rpc_latency=$(ping -c 1 -W 2 opt-sepolia.g.alchemy.com 2>/dev/null | grep 'time=' | cut -d'=' -f4 | cut -d' ' -f1 || echo "N/A")
      ;;
    "unichain-sepolia"|"unit") 
      rpc_name="Unichain Sepolia (Alchemy)"
      rpc_latency=$(ping -c 1 -W 2 unichain-sepolia.g.alchemy.com 2>/dev/null | grep 'time=' | cut -d'=' -f4 | cut -d' ' -f1 || echo "N/A")
      ;;
    "sei-testnet"|"seit") 
      rpc_name="Sei Testnet (Alchemy)"
      rpc_latency=$(ping -c 1 -W 2 sei-testnet.g.alchemy.com 2>/dev/null | grep 'time=' | cut -d'=' -f4 | cut -d' ' -f1 || echo "N/A")
      ;;
    "abstract-testnet"|"abst") 
      rpc_name="Abstract Testnet (Alchemy)"
      rpc_latency=$(ping -c 1 -W 2 abstract-testnet.g.alchemy.com 2>/dev/null | grep 'time=' | cut -d'=' -f4 | cut -d' ' -f1 || echo "N/A")
      ;;
    "berachain-bepolia"|"bera") 
      rpc_name="Berachain Bepolia (Alchemy)"
      rpc_latency=$(ping -c 1 -W 2 berachain-bepolia.g.alchemy.com 2>/dev/null | grep 'time=' | cut -d'=' -f4 | cut -d' ' -f1 || echo "N/A")
      ;;
    "monad-testnet"|"mont") 
      rpc_name="Monad Testnet (Alchemy)"
      rpc_latency=$(ping -c 1 -W 2 monad-testnet.g.alchemy.com 2>/dev/null | grep 'time=' | cut -d'=' -f4 | cut -d' ' -f1 || echo "N/A")
      ;;
    "bnb-testnet"|"bnb") 
      rpc_name="BNB Testnet (Alchemy)"
      rpc_latency=$(ping -c 1 -W 2 bnb-testnet.g.alchemy.com 2>/dev/null | grep 'time=' | cut -d'=' -f4 | cut -d' ' -f1 || echo "N/A")
      ;;
    "lisk-sepolia"|"lisk") 
      rpc_name="Lisk Sepolia (Public)"
      rpc_latency=$(ping -c 1 -W 2 rpc.sepolia-api.lisk.com 2>/dev/null | grep 'time=' | cut -d'=' -f4 | cut -d' ' -f1 || echo "N/A")
      ;;
    "l2rn") 
      rpc_name="L2RN (WebSocket)"
      rpc_latency=$(ping -c 1 -W 2 rpc.t1rn.io 2>/dev/null | grep 'time=' | cut -d'=' -f4 | cut -d' ' -f1 || echo "N/A")
      ;;
    *) 
      rpc_name="$network"
      rpc_latency="N/A"
      ;;
  esac
  
  echo "$rpc_name|$rpc_latency"
}

# === GET WALLET ADDRESS (Safe Function) ===
get_executor_wallet_address() {
  local wallet_address="Unknown"
  
  # Try to get wallet address from balance checker module
  if command -v get_wallet_address >/dev/null 2>&1; then
    wallet_address=$(get_wallet_address 2>/dev/null || echo "Unknown")
  fi
  
  # Fallback: check cache
  if [[ "$wallet_address" == "Unknown" && -f "$SCRIPT_DIR/.wallet_address_cache" ]]; then
    wallet_address=$(cat "$SCRIPT_DIR/.wallet_address_cache" 2>/dev/null || echo "Unknown")
  fi
  
  echo "$wallet_address"
}

# === ENHANCED NOTIFICATION SYSTEM (Rich Reporting) ===
send_notification() {
  local level="$1"
  local message="$2"
  local value="${3:-0}"
  local extra_data="${4:-}"
  
  # Debug logging
  if [[ "${ENABLE_VERBOSE_LOGGING:-false}" == "true" ]]; then
    executor_log_info "🔔 DEBUG: Sending rich $level notification"
  fi
  
  # Check basic requirements
  [[ "${ENABLE_NOTIFICATIONS:-false}" == "true" ]] || return 0
  [[ "${TELEGRAM_ENABLE:-false}" == "true" ]] || return 0
  [[ -n "${TELEGRAM_BOT_TOKEN:-}" ]] || return 0
  [[ -n "${TELEGRAM_CHAT_ID:-}" ]] || return 0
  
  # Simple level filtering (no other filters as requested)
  local should_send=false
  case "${NOTIFICATION_LEVEL:-error}" in
    "bid_success")
      [[ "$level" == "bid_success" ]] && should_send=true
      ;;
    "order_success")
      [[ "$level" == "order_success" ]] && should_send=true
      ;;
    "claim_success")
      [[ "$level" == "claim_success" ]] && should_send=true
      ;;
    "all_success")
      [[ "$level" =~ ^(bid_success|order_success|claim_success|execution_success|batch_success|balance_report)$ ]] && should_send=true
      ;;
    "error")
      [[ "$level" =~ error ]] && should_send=true
      ;;
    "warning")
      [[ "$level" =~ (error|warning) ]] && should_send=true
      ;;
    "info")
      [[ "$level" =~ (error|warning|info) ]] && should_send=true
      ;;
    "debug"|"all")
      should_send=true
      ;;
    *)
      [[ "$level" =~ error ]] && should_send=true
      ;;
  esac
  
  [[ "$should_send" == "true" ]] || return 0
  
  # Send to Telegram
  local encoded_message=$(echo -e "$message" | sed 's/ /%20/g; s/\n/%0A/g; s/&/%26/g; s/</%3C/g; s/>/%3E/g')
  
  local response=$(curl -s -X POST "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
    -d "chat_id=${TELEGRAM_CHAT_ID}" \
    -d "text=$encoded_message" \
    -d "parse_mode=HTML" \
    --max-time 10 2>&1)
  
  if [[ "$response" =~ "\"ok\":true" ]]; then
    executor_log_info "📱 Rich notification sent successfully: $level"
  else
    executor_log_warn "📱 Rich notification failed: ${response:0:100}"
  fi
}

# === SEND RICH BID SUCCESS NOTIFICATION (Updated dengan Wallet Address) ===
send_rich_bid_notification() {
  local line="$1"
  
  local order_id=$(parse_log_data "$line" "order_id")
  local source_chain=$(parse_log_data "$line" "source_chain")
  local dest_chain=$(parse_log_data "$line" "dest_chain")
  local amount=$(parse_log_data "$line" "amount")
  local network=$(parse_log_data "$line" "network")
  
  local source_emoji=$(get_network_emoji "$source_chain")
  local dest_emoji=$(get_network_emoji "$dest_chain")
  local exec_emoji=$(get_execution_emoji "bid")
  
  # Get wallet address
  local wallet_address=$(get_executor_wallet_address)
  
  # Get RPC info
  local rpc_info=$(get_rpc_info "$network")
  local rpc_name=$(echo "$rpc_info" | cut -d'|' -f1)
  local rpc_latency=$(echo "$rpc_info" | cut -d'|' -f2)
  
  # Format amount
  if [[ "$amount" != "N/A" && "$amount" != "0" ]]; then
    amount=$(printf "%.6f" "$amount" 2>/dev/null || echo "$amount")
  fi
  
  local message="$exec_emoji <b>BID SUCCESS!</b> $exec_emoji%0A"
  message+="%0A📋 <b>Order Details:</b>"
  message+="%0A🆔 Order ID: <code>${order_id:0:16}...</code>"
  message+="%0A🌉 Route: $source_emoji $source_chain ➡️ $dest_emoji $dest_chain"
  message+="%0A💰 Amount: <b>$amount ETH</b>"
  message+="%0A🔑 Wallet: <code>${wallet_address:0:6}...${wallet_address: -4}</code>"
  message+="%0A%0A🌐 <b>Network Info:</b>"
  message+="%0A📡 RPC: $rpc_name"
  message+="%0A⚡ Latency: ${rpc_latency}ms"
  message+="%0A%0A⏰ Time: $(date '+%H:%M:%S')"
  message+="%0A📅 Date: $(date '+%Y-%m-%d')"
  
  send_notification "bid_success" "$message"
}

# === SEND RICH EXECUTION NOTIFICATION (Updated dengan Wallet Address) ===
send_rich_execution_notification() {
  local line="$1"
  
  local order_id=$(parse_log_data "$line" "order_id")
  local tx_hash=$(parse_log_data "$line" "tx_hash")
  local source_chain=$(parse_log_data "$line" "source_chain")
  local dest_chain=$(parse_log_data "$line" "dest_chain")
  local amount=$(parse_log_data "$line" "amount")
  local gas_fee=$(parse_log_data "$line" "gas_fee")
  local network=$(parse_log_data "$line" "network")
  
  local source_emoji=$(get_network_emoji "$source_chain")
  local dest_emoji=$(get_network_emoji "$dest_chain")
  local exec_emoji=$(get_execution_emoji "execution")
  
  # Get wallet address
  local wallet_address=$(get_executor_wallet_address)
  
  # Calculate estimated reward
  local estimated_reward="0.001"
  if [[ "$amount" != "0" && "$amount" != "N/A" ]]; then
    estimated_reward=$(echo "scale=6; $amount * 0.001" | bc -l 2>/dev/null || echo "0.001")
  fi
  
  # Format values
  if [[ "$amount" != "N/A" && "$amount" != "0" ]]; then
    amount=$(printf "%.6f" "$amount" 2>/dev/null || echo "$amount")
  fi
  
  local message="$exec_emoji <b>EXECUTION SUCCESS!</b> $exec_emoji%0A"
  message+="%0A📋 <b>Transaction Details:</b>"
  message+="%0A🆔 Order ID: <code>${order_id:0:16}...</code>"
  message+="%0A🔗 TX Hash: <code>${tx_hash:0:16}...</code>"
  message+="%0A🌉 Route: $source_emoji $source_chain ➡️ $dest_emoji $dest_chain"
  message+="%0A💰 Amount: <b>$amount ETH</b>"
  message+="%0A⛽ Gas Fee: <b>$gas_fee</b>"
  message+="%0A💎 Est. Reward: <b>~$estimated_reward BRN</b>"
  message+="%0A🔑 Wallet: <code>${wallet_address:0:6}...${wallet_address: -4}</code>"
  message+="%0A%0A⏰ Time: $(date '+%H:%M:%S')"
  message+="%0A📅 Date: $(date '+%Y-%m-%d')"
  
  send_notification "execution_success" "$message"
}

# === SEND RICH BATCH NOTIFICATION ===
send_rich_batch_notification() {
  local line="$1"
  
  local count=$(parse_log_data "$line" "count")
  local network=$(parse_log_data "$line" "network")
  local batch_emoji=$(get_execution_emoji "batch")
  local network_emoji=$(get_network_emoji "$network")
  
  # Get wallet address
  local wallet_address=$(get_executor_wallet_address)
  
  local message="$batch_emoji <b>BATCH EXECUTED!</b> $batch_emoji%0A"
  message+="%0A📊 <b>Batch Details:</b>"
  message+="%0A🔢 Transactions: <b>$count</b>"
  message+="%0A$network_emoji Network: $network"
  message+="%0A✅ Status: Submitted to network"
  message+="%0A🚀 Processing: In progress"
  message+="%0A🔑 Wallet: <code>${wallet_address:0:6}...${wallet_address: -4}</code>"
  message+="%0A%0A⏰ Time: $(date '+%H:%M:%S')"
  message+="%0A📅 Date: $(date '+%Y-%m-%d')"
  
  send_notification "batch_success" "$message"
}

# === SEND RICH CLAIM NOTIFICATION (Updated dengan Wallet Address) ===
send_rich_claim_notification() {
  local line="$1"
  
  local order_id=$(parse_log_data "$line" "order_id")
  local reward=$(parse_log_data "$line" "reward")
  local tx_hash=$(parse_log_data "$line" "tx_hash")
  local network=$(parse_log_data "$line" "network")
  
  local network_emoji=$(get_network_emoji "$network")
  local claim_emoji=$(get_execution_emoji "claim")
  
  # Get wallet address
  local wallet_address=$(get_executor_wallet_address)
  
  local message="$claim_emoji <b>CLAIM SUCCESS!</b> $claim_emoji%0A"
  message+="%0A💎 <b>Reward Claimed:</b>"
  message+="%0A🆔 Order ID: <code>${order_id:0:16}...</code>"
  message+="%0A🏆 Reward: <b>$reward BRN</b>"
  message+="%0A🔗 TX Hash: <code>${tx_hash:0:16}...</code>"
  message+="%0A$network_emoji Network: $network"
  message+="%0A🔑 Wallet: <code>${wallet_address:0:6}...${wallet_address: -4}</code>"
  message+="%0A%0A⏰ Time: $(date '+%H:%M:%S')"
  message+="%0A📅 Date: $(date '+%Y-%m-%d')"
  
  send_notification "claim_success" "$message"
}

# === SEND BALANCE REPORT (Updated dengan Wallet Address) ===
send_balance_report() {
  executor_log_info "📊 Generating rich balance report..."
  
  # Get wallet address
  local wallet_address=$(get_executor_wallet_address)
  
  local networks=(${ENABLED_NETWORKS//,/ })
  local total_balance=0
  local message="💰 <b>BALANCE REPORT</b> 💰%0A"
  message+="%0A🔑 <b>Wallet:</b> <code>${wallet_address:0:6}...${wallet_address: -4}</code>%0A"
  message+="%0A📊 <b>Network Balances:</b>%0A"
  
  for network in "${networks[@]}"; do
    local emoji=$(get_network_emoji "$network")
    local balance="0.000000"
    
    # Try to get balance from balance checker module
    if command -v check_network_balance >/dev/null 2>&1; then
      balance=$(check_network_balance "$network" "$wallet_address" 2>/dev/null || echo "0.000000")
    fi
    
    local network_name=""
    case "$network" in
      "arbitrum-sepolia") network_name="Arbitrum" ;;
      "base-sepolia") network_name="Base" ;;
      "blast-sepolia") network_name="Blast" ;;
      "optimism-sepolia") network_name="Optimism" ;;
      "unichain-sepolia") network_name="Unichain" ;;
      "monad-testnet") network_name="Monad" ;;
      "sei-testnet") network_name="Sei" ;;
      "abstract-testnet") network_name="Abstract" ;;
      "lisk-sepolia") network_name="Lisk" ;;
      "berachain-bepolia") network_name="Berachain" ;;
      "bnb-testnet") network_name="BNB" ;;
      "l2rn") network_name="L2RN" ;;
      *) network_name="$network" ;;
    esac
    
    # Format balance
    if [[ "$balance" =~ ^[0-9]+\.?[0-9]*$ ]]; then
      balance=$(printf "%.6f" "$balance" 2>/dev/null || echo "$balance")
      total_balance=$(echo "scale=6; $total_balance + $balance" | bc -l 2>/dev/null || echo "$total_balance")
    fi
    
    message+="%0A$emoji <b>$network_name:</b> $balance ETH"
  done
  
  # Format total balance
  total_balance=$(printf "%.6f" "$total_balance" 2>/dev/null || echo "$total_balance")
  
  message+="%0A%0A💎 <b>Total Balance:</b> $total_balance ETH"
  message+="%0A⚠️ <b>Min Threshold:</b> ${EXECUTOR_MIN_BALANCE_THRESHOLD_ETH:-0.5} ETH"
  
  # Status indicator
  local status_emoji="✅"
  local status_text="Healthy"
  if [[ $(echo "$total_balance < ${EXECUTOR_MIN_BALANCE_THRESHOLD_ETH:-0.5}" | bc -l 2>/dev/null || echo "0") -eq 1 ]]; then
    status_emoji="⚠️"
    status_text="Low Balance"
  fi
  
  message+="%0A$status_emoji <b>Status:</b> $status_text"
  message+="%0A%0A⏰ Time: $(date '+%H:%M:%S')"
  message+="%0A📅 Date: $(date '+%Y-%m-%d')"
  
  send_notification "balance_report" "$message"
}

# === TEST TELEGRAM CONFIGURATION ===
test_telegram_configuration() {
  executor_log_info "🧪 Testing Telegram configuration..."
  
  if [[ "${ENABLE_NOTIFICATIONS:-false}" != "true" ]]; then
    executor_log_warn "⚠️ Notifications disabled in configuration"
    return 1
  fi
  
  if [[ "${TELEGRAM_ENABLE:-false}" != "true" ]]; then
    executor_log_warn "⚠️ Telegram disabled in configuration"
    return 1
  fi
  
  if [[ -z "${TELEGRAM_BOT_TOKEN:-}" || "${TELEGRAM_BOT_TOKEN}" == "your_bot_token_here" ]]; then
    executor_log_warn "⚠️ Telegram bot token not configured"
    return 1
  fi
  
  if [[ -z "${TELEGRAM_CHAT_ID:-}" || "${TELEGRAM_CHAT_ID}" == "your_chat_id_here" ]]; then
    executor_log_warn "⚠️ Telegram chat ID not configured"
    return 1
  fi
  
  # Test bot token validity
  local bot_info=$(curl -s "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/getMe" --max-time 10)
  if [[ "$bot_info" =~ "\"ok\":true" ]]; then
    local bot_username=$(echo "$bot_info" | grep -oP '"username":"[^"]*"' | cut -d'"' -f4)
    executor_log_info "✅ Bot token valid: @$bot_username"
  else
    executor_log_warn "❌ Invalid bot token"
    return 1
  fi
  
  # Get wallet address for test
  local wallet_address=$(get_executor_wallet_address)
  
  # Send test message
  local test_emoji="🧪"
  local message="$test_emoji <b>T3RN EXECUTOR TEST</b> $test_emoji%0A"
  message+="%0A✅ <b>Rich notifications working!</b>"
  message+="%0A📱 Telegram integration: Active"
  message+="%0A🎯 Notification level: ${NOTIFICATION_LEVEL}"
  message+="%0A🌐 Enabled networks: ${ENABLED_NETWORKS}"
  message+="%0A🔑 Wallet: <code>${wallet_address:0:6}...${wallet_address: -4}</code>"
  message+="%0A%0A⏰ Time: $(date '+%H:%M:%S')"
  message+="%0A📅 Date: $(date '+%Y-%m-%d')"
  
  send_notification "info" "$message"
  
  executor_log_info "✅ Telegram configuration test completed"
  return 0
}

# === EXPORT ENVIRONMENT VARIABLES (Complete Network Support) ===
export_executor_environment() {
  executor_log_info "🔧 Exporting executor environment variables from .env..."
  
  source "$SCRIPT_DIR/.env" || executor_error_exit "Failed to load .env"
  
  # Validate private key
  if command -v validate_private_key >/dev/null 2>&1; then
    validate_private_key || executor_error_exit "Private key validation failed"
  else
    [[ -n "${PRIVATE_KEY_EXECUTOR:-}" ]] || executor_error_exit "PRIVATE_KEY_EXECUTOR not found in .env"
    [[ ${#PRIVATE_KEY_EXECUTOR} -eq 64 ]] || executor_error_exit "PRIVATE_KEY_EXECUTOR must be 64 characters"
    [[ ! "$PRIVATE_KEY_EXECUTOR" =~ ^0x ]] || executor_error_exit "PRIVATE_KEY_EXECUTOR should not start with 0x"
  fi
  
  # Core executor environment variables
  echo "export PRIVATE_KEY_LOCAL=\"$PRIVATE_KEY_EXECUTOR\""
  export PRIVATE_KEY_LOCAL="$PRIVATE_KEY_EXECUTOR"
  
  echo "export ENVIRONMENT=\"${ENVIRONMENT:-testnet}\""
  export ENVIRONMENT="${ENVIRONMENT:-testnet}"
  
  echo "export LOG_LEVEL=\"${LOG_LEVEL:-info}\""
  export LOG_LEVEL="${LOG_LEVEL:-info}"
  
  echo "export LOG_PRETTY=\"${LOG_PRETTY:-false}\""
  export LOG_PRETTY="${LOG_PRETTY:-false}"
  
  echo "export LOG_FORMAT=\"${LOG_FORMAT:-simple}\""
  export LOG_FORMAT="${LOG_FORMAT:-simple}"
  
  echo "export RUST_LOG=\"${RUST_LOG:-info}\""
  export RUST_LOG="${RUST_LOG:-info}"
  
  echo "export RUST_BACKTRACE=\"${RUST_BACKTRACE:-0}\""
  export RUST_BACKTRACE="${RUST_BACKTRACE:-0}"
  
  echo "export NODE_ENV=\"${NODE_ENV:-production}\""
  export NODE_ENV="${NODE_ENV:-production}"
  
  # Executor specific settings
  echo "export EXECUTOR_PROCESS_BIDS_ENABLED=\"${EXECUTOR_PROCESS_BIDS_ENABLED:-true}\""
  export EXECUTOR_PROCESS_BIDS_ENABLED="${EXECUTOR_PROCESS_BIDS_ENABLED:-true}"
  
  echo "export EXECUTOR_PROCESS_ORDERS_ENABLED=\"${EXECUTOR_PROCESS_ORDERS_ENABLED:-true}\""
  export EXECUTOR_PROCESS_ORDERS_ENABLED="${EXECUTOR_PROCESS_ORDERS_ENABLED:-true}"
  
  echo "export EXECUTOR_PROCESS_CLAIMS_ENABLED=\"${EXECUTOR_PROCESS_CLAIMS_ENABLED:-true}\""
  export EXECUTOR_PROCESS_CLAIMS_ENABLED="${EXECUTOR_PROCESS_CLAIMS_ENABLED:-true}"
  
  echo "export EXECUTOR_MAX_L3_GAS_PRICE=\"${EXECUTOR_MAX_L3_GAS_PRICE:-1000000000}\""
  export EXECUTOR_MAX_L3_GAS_PRICE="${EXECUTOR_MAX_L3_GAS_PRICE:-1000000000}"
  
  echo "export EXECUTOR_PROCESS_PENDING_ORDERS_FROM_API=\"${EXECUTOR_PROCESS_PENDING_ORDERS_FROM_API:-false}\""
  export EXECUTOR_PROCESS_PENDING_ORDERS_FROM_API="${EXECUTOR_PROCESS_PENDING_ORDERS_FROM_API:-false}"
  
  # Balance threshold fix
  echo "export EXECUTOR_MIN_BALANCE_THRESHOLD_ETH=\"${EXECUTOR_MIN_BALANCE_THRESHOLD_ETH:-0.5}\""
  export EXECUTOR_MIN_BALANCE_THRESHOLD_ETH="${EXECUTOR_MIN_BALANCE_THRESHOLD_ETH:-0.5}"
  
  echo "export BALANCE_MINIMUM_REQUIRED=\"${BALANCE_MINIMUM_REQUIRED:-0.5}\""
  export BALANCE_MINIMUM_REQUIRED="${BALANCE_MINIMUM_REQUIRED:-0.5}"
  
  # Network configuration
  echo "export ENABLED_NETWORKS=\"${ENABLED_NETWORKS:-arbitrum-sepolia,base-sepolia}\""
  export ENABLED_NETWORKS="${ENABLED_NETWORKS:-arbitrum-sepolia,base-sepolia}"
  
  echo "export EXECUTOR_ENABLED_NETWORKS=\"${EXECUTOR_ENABLED_NETWORKS:-$ENABLED_NETWORKS}\""
  export EXECUTOR_ENABLED_NETWORKS="${EXECUTOR_ENABLED_NETWORKS:-$ENABLED_NETWORKS}"
  
  echo "export EXECUTOR_ENABLED_ASSETS=\"${EXECUTOR_ENABLED_ASSETS:-*}\""
  export EXECUTOR_ENABLED_ASSETS="${EXECUTOR_ENABLED_ASSETS:-*}"
  
  echo "export NODE_TYPE=\"${NODE_TYPE:-alchemy-complete}\""
  export NODE_TYPE="${NODE_TYPE:-alchemy-complete}"
  
  # RPC endpoints (Complete Network List)
  local networks=("arbitrum-sepolia" "base-sepolia" "blast-sepolia" "optimism-sepolia" "unichain-sepolia" "monad-testnet" "sei-testnet" "abstract-testnet" "lisk-sepolia" "berachain-bepolia" "bnb-testnet" "l2rn")
  for network in "${networks[@]}"; do
    local network_code="$network"
    case "$network" in
      "l2rn") network_code="l2rn" ;;
      "arbitrum-sepolia") network_code="arbt" ;;
      "base-sepolia") network_code="bast" ;;
      "blast-sepolia") network_code="blst" ;;
      "optimism-sepolia") network_code="opst" ;;
      "unichain-sepolia") network_code="unit" ;;
      "monad-testnet") network_code="mont" ;;
      "sei-testnet") network_code="seit" ;;
      "abstract-testnet") network_code="abst" ;;
      "lisk-sepolia") network_code="lisk" ;;
      "berachain-bepolia") network_code="bera" ;;
      "bnb-testnet") network_code="bnb" ;;
    esac
    
    local rpc_var="RPC_${network_code^^}"
    if [[ -n "${!rpc_var:-}" ]]; then
      echo "export $rpc_var=\"${!rpc_var}\""
      export "$rpc_var"
    fi
  done
  
  # Enhanced Notification exports
  echo "export ENABLE_NOTIFICATIONS=\"${ENABLE_NOTIFICATIONS:-false}\""
  export ENABLE_NOTIFICATIONS="${ENABLE_NOTIFICATIONS:-false}"
  
  echo "export NOTIFICATION_LEVEL=\"${NOTIFICATION_LEVEL:-error}\""
  export NOTIFICATION_LEVEL="${NOTIFICATION_LEVEL:-error}"
  
  echo "export TELEGRAM_BOT_TOKEN=\"${TELEGRAM_BOT_TOKEN:-}\""
  export TELEGRAM_BOT_TOKEN="${TELEGRAM_BOT_TOKEN:-}"
  
  echo "export TELEGRAM_CHAT_ID=\"${TELEGRAM_CHAT_ID:-}\""
  export TELEGRAM_CHAT_ID="${TELEGRAM_CHAT_ID:-}"
  
  echo "export TELEGRAM_ENABLE=\"${TELEGRAM_ENABLE:-false}\""
  export TELEGRAM_ENABLE="${TELEGRAM_ENABLE:-false}"
  
  echo "export NOTIFY_BID_SUCCESS=\"${NOTIFY_BID_SUCCESS:-true}\""
  export NOTIFY_BID_SUCCESS="${NOTIFY_BID_SUCCESS:-true}"
  
  echo "export NOTIFY_ORDER_SUCCESS=\"${NOTIFY_ORDER_SUCCESS:-true}\""
  export NOTIFY_ORDER_SUCCESS="${NOTIFY_ORDER_SUCCESS:-true}"
  
  echo "export NOTIFY_CLAIM_SUCCESS=\"${NOTIFY_CLAIM_SUCCESS:-true}\""
  export NOTIFY_CLAIM_SUCCESS="${NOTIFY_CLAIM_SUCCESS:-true}"
  
  echo "export ENABLE_VERBOSE_LOGGING=\"${ENABLE_VERBOSE_LOGGING:-false}\""
  export ENABLE_VERBOSE_LOGGING="${ENABLE_VERBOSE_LOGGING:-false}"
  
  # Rich notification settings
  echo "export ENABLE_RICH_NOTIFICATIONS=\"${ENABLE_RICH_NOTIFICATIONS:-true}\""
  export ENABLE_RICH_NOTIFICATIONS="${ENABLE_RICH_NOTIFICATIONS:-true}"
  
  echo "export BALANCE_REPORT_INTERVAL=\"${BALANCE_REPORT_INTERVAL:-600}\""
  export BALANCE_REPORT_INTERVAL="${BALANCE_REPORT_INTERVAL:-600}"
  
  executor_log_info "✅ All environment variables exported from .env"
  
  # Test Telegram configuration
  if [[ "${ENABLE_NOTIFICATIONS:-false}" == "true" && "${TELEGRAM_ENABLE:-false}" == "true" ]]; then
    test_telegram_configuration || executor_log_warn "⚠️ Telegram configuration test failed"
  fi
  
  # Send startup notification
  if [[ "${NOTIFY_RESTART_EVENTS:-true}" == "true" ]]; then
    local wallet_address=$(get_executor_wallet_address)
    local startup_emoji="🚀"
    local message="$startup_emoji <b>T3RN EXECUTOR STARTED</b> $startup_emoji%0A"
    message+="%0A🌐 <b>Networks:</b> ${ENABLED_NETWORKS}%0A"
    message+="%0A💰 <b>Min Balance:</b> ${EXECUTOR_MIN_BALANCE_THRESHOLD_ETH:-0.5} ETH%0A"
    message+="%0A📱 <b>Notifications:</b> ${NOTIFICATION_LEVEL}%0A"
    message+="%0A🎯 <b>Rich Reporting:</b> ${ENABLE_RICH_NOTIFICATIONS:-true}%0A"
    message+="%0A🔑 <b>Wallet:</b> <code>${wallet_address:0:6}...${wallet_address: -4}</code>%0A"
    message+="%0A⏰ <b>Time:</b> $(date '+%H:%M:%S')%0A"
    message+="%0A📅 <b>Date:</b> $(date '+%Y-%m-%d')"
    
    send_notification "info" "$message"
  fi
}

# === ENHANCED MONITOR EXECUTOR OUTPUT ===
monitor_executor_output() {
  local executor_pid=$1
  
  executor_log_info "📊 Starting enhanced executor output monitoring with rich notifications..."
  
  # Start balance reporting scheduler
  if [[ "${ENABLE_RICH_NOTIFICATIONS:-true}" == "true" ]]; then
    (
      while true; do
        sleep "${BALANCE_REPORT_INTERVAL:-600}"  # 10 minutes default
        send_balance_report
      done
    ) &
    executor_log_info "📊 Balance reporting scheduler started (every ${BALANCE_REPORT_INTERVAL:-600}s)"
  fi
  
  # Monitor executor output dengan rich parsing
  tail -f "$LOGS_DIR/executor.log" | while read -r line; do
    if [[ "$line" =~ ^\{.*\}$ ]]; then
      # JSON format log
      local msg=$(echo "$line" | grep -oP '"msg":"[^"]*"' | cut -d'"' -f4 2>/dev/null || echo "")
      
      # Enhanced pattern matching dengan rich notifications
      if [[ "$msg" =~ "Bid successful" ]] && [[ "${NOTIFY_BID_SUCCESS:-true}" == "true" ]]; then
        if [[ "${ENABLE_RICH_NOTIFICATIONS:-true}" == "true" ]]; then
          send_rich_bid_notification "$line"
        else
          send_notification "bid_success" "🎯 <b>BID SUCCESS!</b>%0A⏰ $(date '+%H:%M:%S')"
        fi
        
      elif [[ "$msg" =~ "Execute transmission to queue" ]] && [[ "${NOTIFY_ORDER_SUCCESS:-true}" == "true" ]]; then
        if [[ "${ENABLE_RICH_NOTIFICATIONS:-true}" == "true" ]]; then
          send_rich_execution_notification "$line"
        else
          send_notification "execution_success" "⚡ <b>EXECUTION SUCCESS!</b>%0A⏰ $(date '+%H:%M:%S')"
        fi
        
      elif [[ "$msg" =~ "Send out batch of txs" ]] && [[ "${NOTIFY_ORDER_SUCCESS:-true}" == "true" ]]; then
        if [[ "${ENABLE_RICH_NOTIFICATIONS:-true}" == "true" ]]; then
          send_rich_batch_notification "$line"
        else
          local count=$(parse_log_data "$line" "count")
          send_notification "batch_success" "🚀 <b>BATCH EXECUTED!</b>%0A📊 Transactions: $count%0A⏰ $(date '+%H:%M:%S')"
        fi
        
      elif [[ "$msg" =~ "Order is claimable" ]] && [[ "${NOTIFY_CLAIM_SUCCESS:-true}" == "true" ]]; then
        if [[ "${ENABLE_RICH_NOTIFICATIONS:-true}" == "true" ]]; then
          send_rich_claim_notification "$line"
        else
          send_notification "claim_success" "💎 <b>CLAIM READY!</b>%0A⏰ $(date '+%H:%M:%S')"
        fi
        
      elif [[ "$msg" =~ "Native wallet balance.*below.*EXECUTOR_MIN_BALANCE_THRESHOLD_ETH" ]]; then
        local network=$(parse_log_data "$line" "source_chain")
        local amount=$(parse_log_data "$line" "amount")
        local emoji=$(get_network_emoji "$network")
        local wallet_address=$(get_executor_wallet_address)
        
        local message="⚠️ <b>LOW BALANCE ALERT!</b> ⚠️%0A"
        message+="%0A$emoji <b>Network:</b> $network"
        message+="%0A💰 <b>Current:</b> $amount ETH"
        message+="%0A🚨 <b>Threshold:</b> ${EXECUTOR_MIN_BALANCE_THRESHOLD_ETH:-0.5} ETH"
        message+="%0A🔑 <b>Wallet:</b> <code>${wallet_address:0:6}...${wallet_address: -4}</code>"
        message+="%0A💡 <b>Action:</b> Please top up wallet"
        message+="%0A⏰ <b>Time:</b> $(date '+%H:%M:%S')"
        
        send_notification "balance_low" "$message"
      fi
    fi
    
    # General metrics logging
    if [[ "$line" =~ "BidReceived" ]]; then
      echo "[$(date '+%Y-%m-%d %H:%M:%S')] 📈 METRIC: Bid received"
    elif [[ "$line" =~ "RemoteOrderCreated" ]]; then
      echo "[$(date '+%Y-%m-%d %H:%M:%S')] 📈 METRIC: Order created"
    fi
  done &
}

# === RUN EXECUTOR BINARY ===
run_executor_instance() {
  cd "$SCRIPT_DIR" || executor_error_exit "Cannot change to script directory"
  
  executor_log_info "🚀 Starting executor binary instance..."
  executor_log_info "📁 Working directory: $(pwd)"
  executor_log_info "🔧 Executing: $EXECUTOR_PATH"
  
  # Get wallet address for logging
  local wallet_address=$(get_executor_wallet_address)
  
  # Environment verification
  executor_log_info "🔍 Environment check:"
  executor_log_info "   PRIVATE_KEY_LOCAL: ${PRIVATE_KEY_LOCAL:0:8}...${PRIVATE_KEY_LOCAL: -8}"
  executor_log_info "   WALLET_ADDRESS: ${wallet_address:0:6}...${wallet_address: -4}"
  executor_log_info "   ENVIRONMENT: $ENVIRONMENT"
  executor_log_info "   LOG_LEVEL: $LOG_LEVEL"
  executor_log_info "   LOG_PRETTY: $LOG_PRETTY"
  executor_log_info "   NODE_TYPE: $NODE_TYPE"
  executor_log_info "   ENABLED_NETWORKS: $ENABLED_NETWORKS"
  executor_log_info "   MIN_BALANCE_THRESHOLD: ${EXECUTOR_MIN_BALANCE_THRESHOLD_ETH:-0.5} ETH"
  executor_log_info "   NOTIFICATIONS: ${ENABLE_NOTIFICATIONS:-false} (Level: ${NOTIFICATION_LEVEL:-error})"
  executor_log_info "   RICH_NOTIFICATIONS: ${ENABLE_RICH_NOTIFICATIONS:-true}"
  
  # Start executor
  "$EXECUTOR_PATH" 2>&1 | tee -a "$LOGS_DIR/executor.log" &
  local executor_pid=$!
  
  # Write PID immediately
  echo $executor_pid > "$SCRIPT_DIR/executor.pid"
  executor_log_info "📝 Executor PID written: $executor_pid"
  
  # Start enhanced output monitoring
  monitor_executor_output $executor_pid
  
  sleep 5
  
  if kill -0 $executor_pid 2>/dev/null; then
    executor_log_info "✅ Executor started successfully (PID: $executor_pid)"
    return 0
  else
    wait $executor_pid 2>/dev/null || true
    local exit_code=$?
    executor_log_warn "❌ Executor failed with exit code: $exit_code"
    
    send_notification "error" "🚨 <b>EXECUTOR STARTUP FAILED!</b>%0A❌ Exit code: $exit_code%0A⏰ $(date '+%H:%M:%S')"
    return 1
  fi
}

# === CHECK EXECUTOR RUNNING ===
is_executor_running() {
  if [[ -f "$SCRIPT_DIR/executor.pid" ]]; then
    local pid=$(cat "$SCRIPT_DIR/executor.pid")
    if kill -0 $pid 2>/dev/null; then
      return 0
    else
      rm -f "$SCRIPT_DIR/executor.pid"
      return 1
    fi
  fi
  
  pgrep -f "$EXECUTOR_PATH" >/dev/null 2>&1
}

# === STOP EXECUTOR ===
stop_executor() {
  executor_log_info "🛑 Stopping executor..."
  
  if [[ -f "$SCRIPT_DIR/executor.pid" ]]; then
    local pid=$(cat "$SCRIPT_DIR/executor.pid")
    if kill -0 $pid 2>/dev/null; then
      kill -TERM $pid 2>/dev/null || true
      sleep 5
      if kill -0 $pid 2>/dev/null; then
        kill -KILL $pid 2>/dev/null || true
      fi
    fi
    rm -f "$SCRIPT_DIR/executor.pid"
  fi
  
  pkill -f "$EXECUTOR_PATH" 2>/dev/null || true
  pkill -f "tail -f.*executor.log" 2>/dev/null || true
  executor_log_info "✅ Executor stopped"
}

# === AUTORESTART LOOP ===
start_executor_with_autorestart() {
  initialize_executor_binary
  export_executor_environment
  
  local restart_count=0
  local max_attempts="${AUTORESTART_MAX_ATTEMPTS:-10}"
  local sleep_interval="${AUTORESTART_SLEEP_INTERVAL:-15}"
  
  executor_log_info "🔁 Starting executor with autorestart (max: $max_attempts attempts)"
  
  if ! run_executor_instance; then
    executor_error_exit "Failed to start executor on initial attempt"
  fi
  
  # Autorestart loop
  while [[ $restart_count -lt $max_attempts ]]; do
    sleep $sleep_interval
    
    if ! is_executor_running; then
      ((restart_count++))
      executor_log_info "❌ Executor died! Restarting #$restart_count/$max_attempts"
      
      if [[ "${NOTIFY_RESTART_EVENTS:-true}" == "true" ]]; then
        send_notification "warning" "🔄 <b>EXECUTOR RESTART</b>%0A📊 Attempt: $restart_count/$max_attempts%0A⏰ $(date '+%H:%M:%S')"
      fi
      
      stop_executor 2>/dev/null || true
      sleep 3
      
      if run_executor_instance; then
        executor_log_info "✅ Executor restarted successfully (#$restart_count)"
        
        if [[ $restart_count -gt 3 ]]; then
          sleep 30
        else
          sleep 10
        fi
      else
        executor_log_warn "❌ Failed to restart executor (attempt #$restart_count)"
        send_notification "error" "🚨 <b>RESTART FAILED!</b>%0A❌ Attempt: $restart_count/$max_attempts%0A⏰ $(date '+%H:%M:%S')"
        sleep 20
      fi
    else
      if [[ $((restart_count % 4)) -eq 0 && $restart_count -gt 0 ]]; then
        executor_log_info "✅ Executor running normally (restarts: $restart_count)"
      fi
    fi
  done
  
  send_notification "error" "🚨 <b>MAX RESTARTS REACHED!</b>%0A❌ Failed after $max_attempts attempts%0A💡 Manual intervention required%0A⏰ $(date '+%H:%M:%S')"
  executor_error_exit "Maximum restart attempts reached ($max_attempts)"
}

# === CLEANUP ===
cleanup_executor() {
  executor_log_info "🧹 Cleaning up executor..."
  
  if [[ "${NOTIFY_RESTART_EVENTS:-true}" == "true" ]]; then
    send_notification "info" "🛑 <b>T3RN EXECUTOR SHUTDOWN</b>%0A⏰ $(date '+%Y-%m-%d %H:%M:%S')"
  fi
  
  stop_executor 2>/dev/null || true
  jobs -p | xargs -r kill 2>/dev/null || true
}

trap cleanup_executor EXIT

# Initialize on load
initialize_executor_binary

# Export main function
export -f start_executor_with_autorestart
export -f stop_executor
export -f is_executor_running
export -f send_notification
export -f test_telegram_configuration
export -f send_balance_report
export -f get_executor_wallet_address
export -f send_rich_bid_notification
export -f send_rich_execution_notification
export -f send_rich_claim_notification
export -f send_rich_batch_notification
