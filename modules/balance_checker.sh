#!/bin/bash
set -euo pipefail

# ╔══════════════════════════════════════════════════════════════╗
# ║                    T3RN BALANCE CHECKER                     ║
# ║                  (Multi-Network Balance)                    ║
# ╚══════════════════════════════════════════════════════════════╝

# T3RN Executor Balance Checker
# Multi-network balance monitoring with automatic wallet address derivation
#
# @author Rokhanz
# @license MIT
# @version 1.0.0

# === INTERNAL ERROR HANDLING ===
balance_error_exit() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] BALANCE ERROR: $*" >&2
  exit 1
}

balance_log_info() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] BALANCE INFO: $*"
}

balance_log_warn() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] BALANCE WARN: $*"
}

# === INITIALIZE BALANCE CHECKER ===
initialize_balance_checker() {
  if [[ -z "${SCRIPT_DIR:-}" ]]; then
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")"/.. && pwd)"
    export SCRIPT_DIR
  fi
  
  if [[ -z "${LOGS_DIR:-}" ]]; then
    LOGS_DIR="$SCRIPT_DIR/logs"
    export LOGS_DIR
  fi
  
  mkdir -p "$LOGS_DIR" || balance_error_exit "Cannot create logs directory"
  
  # Load .env for balance checking configuration
  if [[ -f "$SCRIPT_DIR/.env" ]]; then
    source "$SCRIPT_DIR/.env" || balance_error_exit "Failed to load .env"
  else
    balance_log_warn "⚠️ .env file not found, using default values"
  fi
  
  # Validate private key is available
  if [[ -z "${PRIVATE_KEY_EXECUTOR:-}" ]]; then
    balance_error_exit "PRIVATE_KEY_EXECUTOR not set in .env"
  fi
  
  balance_log_info "💰 Balance checker initialized"
}

# === VALIDATE WALLET ADDRESS ===
validate_wallet_address() {
  local address="$1"
  
  # Check format: 0x followed by 40 hex characters
  if [[ ! "$address" =~ ^0x[a-fA-F0-9]{40}$ ]]; then
    balance_log_warn "⚠️ Invalid wallet address format: $address"
    return 1
  fi
  
  # Check not zero address
  if [[ "$address" == "0x0000000000000000000000000000000000000000" ]]; then
    balance_log_warn "⚠️ Zero address detected"
    return 1
  fi
  
  balance_log_info "✅ Wallet address format validated"
  return 0
}

# === CACHE WALLET ADDRESS ===
cache_wallet_address() {
  local wallet_address="$1"
  local cache_file="$SCRIPT_DIR/.wallet_address_cache"
  
  if [[ -n "$wallet_address" && "$wallet_address" =~ ^0x[a-fA-F0-9]{40}$ ]]; then
    echo "$wallet_address" > "$cache_file"
    balance_log_info "💾 Wallet address cached for future use"
  fi
}

# === GET WALLET ADDRESS FROM PRIVATE KEY ===
get_wallet_address() {
  local private_key="${PRIVATE_KEY_EXECUTOR:-}"
  
  if [[ -z "$private_key" ]]; then
    balance_error_exit "Private key not available"
  fi
  
  # Method 1: Using cast (from foundry) - most reliable
  if command -v cast >/dev/null 2>&1; then
    local wallet_address=$(cast wallet address "$private_key" 2>/dev/null || echo "")
    if [[ -n "$wallet_address" && "$wallet_address" =~ ^0x[a-fA-F0-9]{40}$ ]]; then
      balance_log_info "🔑 Wallet address derived using cast: ${wallet_address:0:6}...${wallet_address: -4}"
      cache_wallet_address "$wallet_address"
      echo "$wallet_address"
      return 0
    fi
  fi
  
  # Method 2: Using node.js with ethers (if available)
  if command -v node >/dev/null 2>&1; then
    local wallet_address=$(node -e "
      try {
        const { ethers } = require('ethers');
        const wallet = new ethers.Wallet('$private_key');
        console.log(wallet.address);
      } catch (e) {
        process.exit(1);
      }
    " 2>/dev/null || echo "")
    
    if [[ -n "$wallet_address" && "$wallet_address" =~ ^0x[a-fA-F0-9]{40}$ ]]; then
      balance_log_info "🔑 Wallet address derived using ethers.js: ${wallet_address:0:6}...${wallet_address: -4}"
      cache_wallet_address "$wallet_address"
      echo "$wallet_address"
      return 0
    fi
  fi
  
  # Method 3: Using python3 with web3 (if available)
  if command -v python3 >/dev/null 2>&1; then
    local wallet_address=$(python3 -c "
import sys
try:
    from eth_account import Account
    account = Account.from_key('$private_key')
    print(account.address)
except ImportError:
    sys.exit(1)
except Exception:
    sys.exit(1)
" 2>/dev/null || echo "")
    
    if [[ -n "$wallet_address" && "$wallet_address" =~ ^0x[a-fA-F0-9]{40}$ ]]; then
      balance_log_info "🔑 Wallet address derived using web3.py: ${wallet_address:0:6}...${wallet_address: -4}"
      cache_wallet_address "$wallet_address"
      echo "$wallet_address"
      return 0
    fi
  fi
  
  # Method 4: Using openssl for manual derivation (advanced)
  if command -v openssl >/dev/null 2>&1 && command -v xxd >/dev/null 2>&1; then
    balance_log_info "🔑 Attempting manual address derivation with openssl..."
    
    # Create temporary files
    local temp_key="/tmp/temp_private_key.$$"
    local temp_pub="/tmp/temp_public_key.$$"
    
    # Convert hex private key to binary and create key file
    echo "$private_key" | xxd -r -p > "$temp_key"
    
    # Generate public key from private key
    if openssl ec -inform raw -in "$temp_key" -pubout -outform DER -out "$temp_pub" 2>/dev/null; then
      # Extract public key bytes (remove DER header)
      local pub_key_hex=$(xxd -p "$temp_pub" | tr -d '\n' | tail -c 130)
      
      # For Ethereum, we need keccak256 of the public key (minus 0x04 prefix)
      local pub_key_clean="${pub_key_hex:2}"  # Remove 0x04 prefix
      
      # Note: This would require keccak256 implementation
      # For now, we'll use a simplified approach
      balance_log_warn "⚠️ Manual derivation requires keccak256 implementation"
    fi
    
    # Cleanup
    rm -f "$temp_key" "$temp_pub"
  fi
  
  # Method 5: Check if address is cached
  local cache_file="$SCRIPT_DIR/.wallet_address_cache"
  if [[ -f "$cache_file" ]]; then
    local cached_address=$(cat "$cache_file" 2>/dev/null || echo "")
    if [[ -n "$cached_address" && "$cached_address" =~ ^0x[a-fA-F0-9]{40}$ ]]; then
      balance_log_info "🔑 Using cached wallet address: ${cached_address:0:6}...${cached_address: -4}"
      echo "$cached_address"
      return 0
    fi
  fi
  
  # Fallback: Installation instructions
  balance_log_warn "⚠️ Cannot derive wallet address automatically"
  balance_log_info "💡 Install one of these tools for automatic derivation:"
  balance_log_info "   - foundry (cast): curl -L https://foundry.paradigm.xyz | bash"
  balance_log_info "   - node.js + ethers: npm install -g ethers"
  balance_log_info "   - python3 + web3: pip3 install web3 eth-account"
  
  # For GitHub version, return error instead of prompting
  balance_error_exit "Wallet address derivation failed. Please install cast, node.js+ethers, or python3+web3"
}

# === GET NETWORK RPC URL ===
get_network_rpc() {
  local network="$1"
  local rpc_var=""
  
  case "$network" in
    "arbitrum-sepolia") rpc_var="RPC_ARBT" ;;
    "base-sepolia") rpc_var="RPC_BAST" ;;
    "blast-sepolia") rpc_var="RPC_BLST" ;;
    "optimism-sepolia") rpc_var="RPC_OPST" ;;
    "unichain-sepolia") rpc_var="RPC_UNIT" ;;
    "monad-testnet") rpc_var="RPC_MONT" ;;
    "sei-testnet") rpc_var="RPC_SEIT" ;;
    "abstract-testnet") rpc_var="RPC_ABST" ;;
    "lisk-sepolia") rpc_var="RPC_LISK" ;;
    "berachain-bepolia") rpc_var="RPC_BERA" ;;
    "bnb-testnet") rpc_var="RPC_BNB" ;;
    "l2rn") rpc_var="RPC_L2RN" ;;
    *)
      balance_log_warn "⚠️ Unknown network: $network"
      return 1
      ;;
  esac
  
  local rpc_url="${!rpc_var:-}"
  if [[ -z "$rpc_url" ]]; then
    balance_log_warn "⚠️ RPC URL not configured for $network"
    return 1
  fi
  
  echo "$rpc_url"
}

# === GET NETWORK EMOJI ===
get_network_emoji() {
  local network="$1"
  case "$network" in
    "arbitrum-sepolia") echo "🔵" ;;
    "base-sepolia") echo "🔷" ;;
    "blast-sepolia") echo "💥" ;;
    "optimism-sepolia") echo "🔴" ;;
    "unichain-sepolia") echo "🦄" ;;
    "monad-testnet") echo "🌙" ;;
    "sei-testnet") echo "⚡" ;;
    "abstract-testnet") echo "🎨" ;;
    "lisk-sepolia") echo "🔗" ;;
    "berachain-bepolia") echo "🐻" ;;
    "bnb-testnet") echo "🟡" ;;
    "l2rn") echo "🌐" ;;
    *) echo "🔗" ;;
  esac
}

# === CHECK BALANCE FOR SINGLE NETWORK ===
check_network_balance() {
  local network="$1"
  local wallet_address="${2:-$(get_wallet_address)}"
  
  balance_log_info "💰 Checking balance for $network..."
  
  local rpc_url=$(get_network_rpc "$network")
  if [[ $? -ne 0 ]]; then
    balance_log_warn "⚠️ Cannot get RPC URL for $network"
    echo "0.000000"
    return 1
  fi
  
  # Skip WebSocket URLs for balance checking
  if [[ "$rpc_url" =~ ^wss?: ]]; then
    balance_log_warn "⚠️ WebSocket RPC not supported for balance checking: $network"
    echo "0.000000"
    return 1
  fi
  
  # Make RPC call to get balance
  local response=$(curl -s --max-time 15 -X POST "$rpc_url" \
    -H "Content-Type: application/json" \
    -d "{\"jsonrpc\":\"2.0\",\"method\":\"eth_getBalance\",\"params\":[\"$wallet_address\",\"latest\"],\"id\":1}" 2>/dev/null || echo "")
  
  if [[ -z "$response" ]]; then
    balance_log_warn "❌ No response from $network RPC"
    echo "0.000000"
    return 1
  fi
  
  # Parse balance from response
  local balance_hex=$(echo "$response" | grep -oP '"result":"[^"]*"' | cut -d'"' -f4 2>/dev/null || echo "")
  
  if [[ -z "$balance_hex" || "$balance_hex" == "null" ]]; then
    # Check for error in response
    local error_msg=$(echo "$response" | grep -oP '"error":\{[^}]*"message":"[^"]*"' | cut -d'"' -f8 2>/dev/null || echo "Unknown error")
    balance_log_warn "❌ Error getting balance for $network: $error_msg"
    echo "0.000000"
    return 1
  fi
  
  # Convert hex to decimal (wei)
  local balance_wei=$(printf "%d" "$balance_hex" 2>/dev/null || echo "0")
  
  # Convert wei to ETH (divide by 10^18)
  local balance_eth=$(echo "scale=6; $balance_wei / 1000000000000000000" | bc -l 2>/dev/null || echo "0.000000")
  
  balance_log_info "✅ $network balance: $balance_eth ETH"
  echo "$balance_eth"
  return 0
}

# === CHECK ALL NETWORK BALANCES ===
check_all_network_balances() {
  balance_log_info "💰 Checking balances for all enabled networks..."
  
  local wallet_address=$(get_wallet_address)
  local enabled_networks="${ENABLED_NETWORKS:-arbitrum-sepolia,base-sepolia}"
  
  # Parse networks
  IFS=',' read -ra networks <<< "$enabled_networks"
  
  local total_balance=0
  local successful_checks=0
  local failed_checks=0
  
  balance_log_info "📊 Checking ${#networks[@]} networks for wallet: ${wallet_address:0:6}...${wallet_address: -4}"
  
  for network in "${networks[@]}"; do
    network=$(echo "$network" | xargs)  # Trim whitespace
    
    local emoji=$(get_network_emoji "$network")
    local balance=$(check_network_balance "$network" "$wallet_address")
    local check_status=$?
    
    if [[ $check_status -eq 0 ]]; then
      ((successful_checks++))
      
      # Add to total balance
      if [[ "$balance" =~ ^[0-9]+\.?[0-9]*$ ]]; then
        total_balance=$(echo "scale=6; $total_balance + $balance" | bc -l 2>/dev/null || echo "$total_balance")
      fi
      
      # Check if balance is below threshold
      local threshold_var="BALANCE_THRESHOLD_$(echo "$network" | sed 's/-/_/g' | tr '[:lower:]' '[:upper:]')"
      local threshold="${!threshold_var:-${EXECUTOR_MIN_BALANCE_THRESHOLD_ETH:-0.5}}"
      
      if [[ $(echo "$balance < $threshold" | bc -l 2>/dev/null || echo "0") -eq 1 ]]; then
        balance_log_warn "⚠️ $emoji $network: $balance ETH (below threshold: $threshold ETH)"
      else
        balance_log_info "✅ $emoji $network: $balance ETH"
      fi
    else
      ((failed_checks++))
      balance_log_warn "❌ $emoji $network: Failed to check balance"
    fi
  done
  
  # Summary
  balance_log_info "📊 Balance check summary:"
  balance_log_info "   🔑 Wallet: ${wallet_address:0:6}...${wallet_address: -4}"
  balance_log_info "   ✅ Successful: $successful_checks"
  balance_log_info "   ❌ Failed: $failed_checks"
  balance_log_info "   💎 Total Balance: $total_balance ETH"
  
  # Check total balance against minimum
  local min_total="${BALANCE_MINIMUM_REQUIRED:-0.5}"
  if [[ $(echo "$total_balance < $min_total" | bc -l 2>/dev/null || echo "0") -eq 1 ]]; then
    balance_log_warn "⚠️ Total balance ($total_balance ETH) below minimum required ($min_total ETH)"
  fi
  
  return 0
}

# === BALANCE MONITORING LOOP ===
start_balance_monitoring() {
  local interval="${BALANCE_CHECK_INTERVAL:-600}"  # 10 minutes default
  
  balance_log_info "🔄 Starting balance monitoring (interval: ${interval}s)"
  
  while true; do
    check_all_network_balances
    
    balance_log_info "⏰ Next balance check in ${interval}s..."
    sleep "$interval"
  done
}

# === GET BALANCE SUMMARY ===
get_balance_summary() {
  local wallet_address=$(get_wallet_address)
  local enabled_networks="${ENABLED_NETWORKS:-arbitrum-sepolia,base-sepolia}"
  
  # Parse networks
  IFS=',' read -ra networks <<< "$enabled_networks"
  
  local summary=""
  local total_balance=0
  
  for network in "${networks[@]}"; do
    network=$(echo "$network" | xargs)
    
    local emoji=$(get_network_emoji "$network")
    local balance=$(check_network_balance "$network" "$wallet_address" 2>/dev/null || echo "0.000000")
    
    if [[ "$balance" =~ ^[0-9]+\.?[0-9]*$ ]]; then
      total_balance=$(echo "scale=6; $total_balance + $balance" | bc -l 2>/dev/null || echo "$total_balance")
    fi
    
    summary+="$emoji $network: $balance ETH\n"
  done
  
  summary+="💎 Total: $total_balance ETH\n"
  summary+="🔑 Wallet: ${wallet_address:0:6}...${wallet_address: -4}"
  
  echo -e "$summary"
}

# === GET BALANCE SUMMARY FOR TELEGRAM ===
get_balance_summary_telegram() {
  local wallet_address=$(get_wallet_address)
  local enabled_networks="${ENABLED_NETWORKS:-arbitrum-sepolia,base-sepolia}"
  
  # Parse networks
  IFS=',' read -ra networks <<< "$enabled_networks"
  
  local summary=""
  local total_balance=0
  
  for network in "${networks[@]}"; do
    network=$(echo "$network" | xargs)
    
    local emoji=$(get_network_emoji "$network")
    local balance=$(check_network_balance "$network" "$wallet_address" 2>/dev/null || echo "0.000000")
    
    if [[ "$balance" =~ ^[0-9]+\.?[0-9]*$ ]]; then
      total_balance=$(echo "scale=6; $total_balance + $balance" | bc -l 2>/dev/null || echo "$total_balance")
    fi
    
    # Format for Telegram
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
    
    summary+="%0A$emoji <b>$network_name:</b> $balance ETH"
  done
  
  summary+="%0A%0A💎 <b>Total Balance:</b> $total_balance ETH"
  summary+="%0A🔑 <b>Wallet:</b> <code>${wallet_address:0:6}...${wallet_address: -4}</code>"
  
  echo "$summary"
}

# === VALIDATE BALANCE CONFIGURATION ===
validate_balance_configuration() {
  balance_log_info "🔍 Validating balance configuration..."
  
  # Check if private key is set
  if [[ -z "${PRIVATE_KEY_EXECUTOR:-}" ]]; then
    balance_log_warn "⚠️ PRIVATE_KEY_EXECUTOR not set"
    return 1
  fi
  
  # Test wallet address derivation
  local wallet_address=$(get_wallet_address 2>/dev/null || echo "")
  if [[ -z "$wallet_address" ]]; then
    balance_log_warn "⚠️ Cannot derive wallet address from private key"
    return 1
  fi
  
  # Check if networks are configured
  if [[ -z "${ENABLED_NETWORKS:-}" ]]; then
    balance_log_warn "⚠️ ENABLED_NETWORKS not set"
    return 1
  fi
  
  # Check balance thresholds
  local min_balance="${EXECUTOR_MIN_BALANCE_THRESHOLD_ETH:-0.5}"
  if [[ ! "$min_balance" =~ ^[0-9]+\.?[0-9]*$ ]]; then
    balance_log_warn "⚠️ Invalid EXECUTOR_MIN_BALANCE_THRESHOLD_ETH: $min_balance"
    return 1
  fi
  
  balance_log_info "✅ Balance configuration validated"
  return 0
}

# === GENERATE BALANCE REPORT ===
generate_balance_report() {
  local report_file="${LOGS_DIR}/balance_report.txt"
  
  balance_log_info "📋 Generating balance report..."
  
  local wallet_address=$(get_wallet_address)
  
  {
    echo "T3RN EXECUTOR BALANCE REPORT"
    echo "Generated: $(date)"
    echo "========================================"
    echo ""
    
    echo "Wallet Configuration:"
    echo "  🔑 Private Key: ${PRIVATE_KEY_EXECUTOR:+CONFIGURED}"
    echo "  📍 Wallet Address: $wallet_address"
    echo "  🌐 Enabled Networks: ${ENABLED_NETWORKS:-not set}"
    echo ""
    
    echo "Balance Thresholds:"
    echo "  💰 Global Minimum: ${EXECUTOR_MIN_BALANCE_THRESHOLD_ETH:-0.5} ETH"
    echo "  🔵 Arbitrum: ${BALANCE_THRESHOLD_ARBT:-0.3} ETH"
    echo "  🔷 Base: ${BALANCE_THRESHOLD_BAST:-0.3} ETH"
    echo "  💥 Blast: ${BALANCE_THRESHOLD_BLST:-0.5} ETH"
    echo "  🔴 Optimism: ${BALANCE_THRESHOLD_OPST:-0.3} ETH"
    echo "  🦄 Unichain: ${BALANCE_THRESHOLD_UNIT:-0.5} ETH"
    echo ""
    
    echo "Current Balances:"
    get_balance_summary
    echo ""
    
    echo "Monitoring Configuration:"
    echo "  ⏰ Check Interval: ${BALANCE_CHECK_INTERVAL:-600}s"
    echo "  📊 Monitoring: ${ENABLE_BALANCE_MONITORING:-true}"
    echo "  🔔 Notifications: ${ENABLE_NOTIFICATIONS:-false}"
    echo ""
    
  } > "$report_file"
  
  balance_log_info "✅ Balance report saved: $report_file"
}

# === GET LOW BALANCE NETWORKS ===
get_low_balance_networks() {
  local enabled_networks="${ENABLED_NETWORKS:-arbitrum-sepolia,base-sepolia}"
  local wallet_address=$(get_wallet_address)
  
  # Parse networks
  IFS=',' read -ra networks <<< "$enabled_networks"
  
  local low_balance_networks=()
  
  for network in "${networks[@]}"; do
    network=$(echo "$network" | xargs)
    
    local balance=$(check_network_balance "$network" "$wallet_address" 2>/dev/null || echo "0.000000")
    local threshold_var="BALANCE_THRESHOLD_$(echo "$network" | sed 's/-/_/g' | tr '[:lower:]' '[:upper:]')"
    local threshold="${!threshold_var:-${EXECUTOR_MIN_BALANCE_THRESHOLD_ETH:-0.5}}"
    
    if [[ $(echo "$balance < $threshold" | bc -l 2>/dev/null || echo "0") -eq 1 ]]; then
      low_balance_networks+=("$network:$balance:$threshold")
    fi
  done
  
  if [[ ${#low_balance_networks[@]} -gt 0 ]]; then
    for entry in "${low_balance_networks[@]}"; do
      IFS=':' read -r network balance threshold <<< "$entry"
      local emoji=$(get_network_emoji "$network")
      echo "$emoji $network: $balance ETH (threshold: $threshold ETH)"
    done
  else
    echo "All networks have sufficient balance"
  fi
}

# Initialize on load
initialize_balance_checker

# Export functions
export -f initialize_balance_checker
export -f check_network_balance
export -f check_all_network_balances
export -f start_balance_monitoring
export -f get_balance_summary
export -f get_balance_summary_telegram
export -f validate_balance_configuration
export -f generate_balance_report
export -f get_low_balance_networks
export -f get_wallet_address
export -f get_network_rpc
export -f get_network_emoji
export -f validate_wallet_address
export -f cache_wallet_address
