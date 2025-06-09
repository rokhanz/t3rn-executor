#!/bin/bash
set -euo pipefail

# ╔══════════════════════════════════════════════════════════════╗
# ║                    T3RN WALLET MANAGER                      ║
# ║                  (Wallet Management & Security)             ║
# ╚══════════════════════════════════════════════════════════════╝

# === INTERNAL ERROR HANDLING ===
wallet_error_exit() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] WALLET ERROR: $*" >&2
  exit 1
}

wallet_log_info() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] WALLET INFO: $*"
}

wallet_log_warn() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] WALLET WARN: $*"
}

# === INITIALIZE WALLET MANAGER ===
initialize_wallet_manager() {
  if [[ -z "${SCRIPT_DIR:-}" ]]; then
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")"/.. && pwd)"
    export SCRIPT_DIR
  fi
  
  if [[ -z "${LOGS_DIR:-}" ]]; then
    LOGS_DIR="$SCRIPT_DIR/logs"
    export LOGS_DIR
  fi
  
  mkdir -p "$LOGS_DIR" || wallet_error_exit "Cannot create logs directory"
  
  # Load .env for wallet configuration
  if [[ -f "$SCRIPT_DIR/.env" ]]; then
    source "$SCRIPT_DIR/.env" 2>/dev/null || true
  fi
  
  # Wallet configuration
  WALLET_SECURITY_MODE="${WALLET_SECURITY_MODE:-high}"
  ENABLE_TRANSACTION_SIMULATION="${ENABLE_TRANSACTION_SIMULATION:-true}"
  WALLET_BACKUP_DIR="${WALLET_BACKUP_DIR:-$SCRIPT_DIR/.wallet_backups}"
  WALLET_CACHE_DIR="${WALLET_CACHE_DIR:-$SCRIPT_DIR/.wallet_cache}"
  
  # Create secure directories
  mkdir -p "$WALLET_BACKUP_DIR" && chmod 700 "$WALLET_BACKUP_DIR"
  mkdir -p "$WALLET_CACHE_DIR" && chmod 700 "$WALLET_CACHE_DIR"
  
  wallet_log_info "🔐 Wallet manager initialized"
}

# === VALIDATE PRIVATE KEY FORMAT ===
validate_private_key_format() {
  local private_key="$1"
  
  # Check if private key is provided
  if [[ -z "$private_key" ]]; then
    wallet_log_warn "⚠️ Private key is empty"
    return 1
  fi
  
  # Check length (64 characters for private key without 0x)
  if [[ ${#private_key} -ne 64 ]]; then
    wallet_log_warn "⚠️ Private key must be exactly 64 characters (got ${#private_key})"
    return 1
  fi
  
  # Check format (hex characters only)
  if [[ ! "$private_key" =~ ^[a-fA-F0-9]+$ ]]; then
    wallet_log_warn "⚠️ Private key must contain only hexadecimal characters"
    return 1
  fi
  
  # Check no 0x prefix
  if [[ "$private_key" =~ ^0x ]]; then
    wallet_log_warn "⚠️ Private key should not start with 0x prefix"
    return 1
  fi
  
  # Check not default/example values
  local invalid_keys=(
    "1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef"
    "your_private_key_without_0x_prefix_64_characters_here"
    "0000000000000000000000000000000000000000000000000000000000000000"
    "ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff"
  )
  
  for invalid_key in "${invalid_keys[@]}"; do
    if [[ "$private_key" == "$invalid_key" ]]; then
      wallet_log_warn "⚠️ Private key appears to be a placeholder/example value"
      return 1
    fi
  done
  
  wallet_log_info "✅ Private key format validation passed"
  return 0
}

# === DERIVE WALLET ADDRESS FROM PRIVATE KEY ===
derive_wallet_address() {
  local private_key="${1:-${PRIVATE_KEY_EXECUTOR:-}}"
  
  if [[ -z "$private_key" ]]; then
    wallet_error_exit "Private key not provided"
  fi
  
  # Validate private key format first
  if ! validate_private_key_format "$private_key"; then
    wallet_error_exit "Invalid private key format"
  fi
  
  wallet_log_info "🔑 Deriving wallet address from private key..."
  
  # Method 1: Using cast (from foundry) - most reliable
  if command -v cast >/dev/null 2>&1; then
    local wallet_address=$(cast wallet address "$private_key" 2>/dev/null || echo "")
    if [[ -n "$wallet_address" && "$wallet_address" =~ ^0x[a-fA-F0-9]{40}$ ]]; then
      wallet_log_info "✅ Address derived using cast: ${wallet_address:0:6}...${wallet_address: -4}"
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
      wallet_log_info "✅ Address derived using ethers.js: ${wallet_address:0:6}...${wallet_address: -4}"
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
      wallet_log_info "✅ Address derived using web3.py: ${wallet_address:0:6}...${wallet_address: -4}"
      cache_wallet_address "$wallet_address"
      echo "$wallet_address"
      return 0
    fi
  fi
  
  # Method 4: Check if address is cached
  local cached_address=$(get_cached_wallet_address "$private_key")
  if [[ -n "$cached_address" ]]; then
    wallet_log_info "✅ Using cached wallet address: ${cached_address:0:6}...${cached_address: -4}"
    echo "$cached_address"
    return 0
  fi
  
  # Fallback: Installation instructions
  wallet_log_warn "⚠️ Cannot derive wallet address automatically"
  wallet_log_info "💡 Install one of these tools for automatic derivation:"
  wallet_log_info "   - foundry (cast): curl -L https://foundry.paradigm.xyz | bash"
  wallet_log_info "   - node.js + ethers: npm install -g ethers"
  wallet_log_info "   - python3 + web3: pip3 install web3 eth-account"
  
  wallet_error_exit "Wallet address derivation failed"
}

# === CACHE WALLET ADDRESS ===
cache_wallet_address() {
  local wallet_address="$1"
  local private_key="${PRIVATE_KEY_EXECUTOR:-}"
  
  if [[ -z "$private_key" || -z "$wallet_address" ]]; then
    return 1
  fi
  
  # Create hash of private key for cache filename (security)
  local key_hash=$(echo -n "$private_key" | sha256sum | cut -d' ' -f1)
  local cache_file="$WALLET_CACHE_DIR/address_${key_hash:0:16}.cache"
  
  if [[ "$wallet_address" =~ ^0x[a-fA-F0-9]{40}$ ]]; then
    echo "$wallet_address" > "$cache_file"
    chmod 600 "$cache_file"  # Secure permissions
    wallet_log_info "💾 Wallet address cached securely"
  fi
}

# === GET CACHED WALLET ADDRESS ===
get_cached_wallet_address() {
  local private_key="$1"
  
  if [[ -z "$private_key" ]]; then
    return 1
  fi
  
  # Create hash of private key for cache filename
  local key_hash=$(echo -n "$private_key" | sha256sum | cut -d' ' -f1)
  local cache_file="$WALLET_CACHE_DIR/address_${key_hash:0:16}.cache"
  
  if [[ -f "$cache_file" ]]; then
    local cached_address=$(cat "$cache_file" 2>/dev/null || echo "")
    if [[ "$cached_address" =~ ^0x[a-fA-F0-9]{40}$ ]]; then
      echo "$cached_address"
      return 0
    fi
  fi
  
  return 1
}

# === VALIDATE WALLET ADDRESS ===
validate_wallet_address() {
  local address="$1"
  
  # Check format: 0x followed by 40 hex characters
  if [[ ! "$address" =~ ^0x[a-fA-F0-9]{40}$ ]]; then
    wallet_log_warn "⚠️ Invalid wallet address format: $address"
    return 1
  fi
  
  # Check not zero address
  if [[ "$address" == "0x0000000000000000000000000000000000000000" ]]; then
    wallet_log_warn "⚠️ Zero address detected"
    return 1
  fi
  
  # Check not burn addresses
  local burn_addresses=(
    "0x000000000000000000000000000000000000dEaD"
    "0xdEaD000000000000000042069420694206942069"
  )
  
  for burn_address in "${burn_addresses[@]}"; do
    if [[ "${address,,}" == "${burn_address,,}" ]]; then
      wallet_log_warn "⚠️ Burn address detected: $address"
      return 1
    fi
  done
  
  wallet_log_info "✅ Wallet address format validated"
  return 0
}

# === GET WALLET BALANCE ===
get_wallet_balance() {
  local network="$1"
  local wallet_address="${2:-$(derive_wallet_address)}"
  
  wallet_log_info "💰 Getting wallet balance for $network..."
  
  # Get RPC URL for network
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
      wallet_log_warn "⚠️ Unknown network: $network"
      echo "0.000000"
      return 1
      ;;
  esac
  
  local rpc_url="${!rpc_var:-}"
  if [[ -z "$rpc_url" ]]; then
    wallet_log_warn "⚠️ RPC URL not configured for $network"
    echo "0.000000"
    return 1
  fi
  
  # Skip WebSocket URLs for balance checking
  if [[ "$rpc_url" =~ ^wss?: ]]; then
    wallet_log_warn "⚠️ WebSocket RPC not supported for balance checking: $network"
    echo "0.000000"
    return 1
  fi
  
  # Make RPC call to get balance
  local response=$(curl -s --max-time 15 -X POST "$rpc_url" \
    -H "Content-Type: application/json" \
    -d "{\"jsonrpc\":\"2.0\",\"method\":\"eth_getBalance\",\"params\":[\"$wallet_address\",\"latest\"],\"id\":1}" 2>/dev/null || echo "")
  
  if [[ -z "$response" ]]; then
    wallet_log_warn "❌ No response from $network RPC"
    echo "0.000000"
    return 1
  fi
  
  # Parse balance from response
  local balance_hex=$(echo "$response" | grep -oP '"result":"[^"]*"' | cut -d'"' -f4 2>/dev/null || echo "")
  
  if [[ -z "$balance_hex" || "$balance_hex" == "null" ]]; then
    local error_msg=$(echo "$response" | grep -oP '"error":\{[^}]*"message":"[^"]*"' | cut -d'"' -f8 2>/dev/null || echo "Unknown error")
    wallet_log_warn "❌ Error getting balance for $network: $error_msg"
    echo "0.000000"
    return 1
  fi
  
  # Convert hex to decimal (wei)
  local balance_wei=$(printf "%d" "$balance_hex" 2>/dev/null || echo "0")
  
  # Convert wei to ETH (divide by 10^18)
  local balance_eth=$(echo "scale=6; $balance_wei / 1000000000000000000" | bc -l 2>/dev/null || echo "0.000000")
  
  wallet_log_info "✅ $network balance: $balance_eth ETH"
  echo "$balance_eth"
  return 0
}

# === BACKUP WALLET CONFIGURATION ===
backup_wallet_configuration() {
  wallet_log_info "💾 Creating wallet configuration backup..."
  
  local backup_file="$WALLET_BACKUP_DIR/wallet_backup_$(date +%Y%m%d_%H%M%S).enc"
  local temp_file="/tmp/wallet_backup_$$"
  
  # Create backup data (without exposing private key)
  {
    echo "T3RN WALLET BACKUP"
    echo "Generated: $(date)"
    echo "========================================"
    echo ""
    echo "Wallet Configuration:"
    echo "  Security Mode: ${WALLET_SECURITY_MODE}"
    echo "  Transaction Simulation: ${ENABLE_TRANSACTION_SIMULATION}"
    echo "  Enabled Networks: ${ENABLED_NETWORKS}"
    echo ""
    
    if [[ -n "${PRIVATE_KEY_EXECUTOR:-}" ]]; then
      local wallet_address=$(derive_wallet_address 2>/dev/null || echo "Unknown")
      echo "Wallet Info:"
      echo "  Address: $wallet_address"
      echo "  Private Key Hash: $(echo -n "${PRIVATE_KEY_EXECUTOR}" | sha256sum | cut -d' ' -f1)"
      echo ""
    fi
    
    echo "Network Balances:"
    if [[ -n "${ENABLED_NETWORKS:-}" ]]; then
      IFS=',' read -ra networks <<< "${ENABLED_NETWORKS}"
      for network in "${networks[@]}"; do
        network=$(echo "$network" | xargs)
        local balance=$(get_wallet_balance "$network" 2>/dev/null || echo "0.000000")
        echo "  $network: $balance ETH"
      done
    fi
    
  } > "$temp_file"
  
  # Encrypt backup file (if gpg is available)
  if command -v gpg >/dev/null 2>&1; then
    gpg --symmetric --cipher-algo AES256 --output "$backup_file" "$temp_file" 2>/dev/null || {
      # Fallback: just copy without encryption
      cp "$temp_file" "${backup_file%.enc}.txt"
      wallet_log_warn "⚠️ GPG not available, backup saved unencrypted"
    }
  else
    cp "$temp_file" "${backup_file%.enc}.txt"
    wallet_log_warn "⚠️ GPG not available, backup saved unencrypted"
  fi
  
  # Secure cleanup
  shred -u "$temp_file" 2>/dev/null || rm -f "$temp_file"
  
  wallet_log_info "✅ Wallet backup created"
}

# === CHECK WALLET SECURITY ===
check_wallet_security() {
  wallet_log_info "🔒 Performing wallet security check..."
  
  local security_issues=()
  
  # Check private key security
  if [[ -n "${PRIVATE_KEY_EXECUTOR:-}" ]]; then
    if ! validate_private_key_format "${PRIVATE_KEY_EXECUTOR}"; then
      security_issues+=("Invalid private key format")
    fi
  else
    security_issues+=("Private key not configured")
  fi
  
  # Check file permissions
  if [[ -f "$SCRIPT_DIR/.env" ]]; then
    local env_perms=$(stat -c "%a" "$SCRIPT_DIR/.env" 2>/dev/null || echo "000")
    if [[ "$env_perms" != "600" && "$env_perms" != "400" ]]; then
      security_issues+=(".env file permissions too open ($env_perms)")
    fi
  fi
  
  # Check if private key is in command history
  if history | grep -q "PRIVATE_KEY" 2>/dev/null; then
    security_issues+=("Private key may be in command history")
  fi
  
  # Check backup directory permissions
  if [[ -d "$WALLET_BACKUP_DIR" ]]; then
    local backup_perms=$(stat -c "%a" "$WALLET_BACKUP_DIR" 2>/dev/null || echo "000")
    if [[ "$backup_perms" != "700" ]]; then
      security_issues+=("Backup directory permissions too open ($backup_perms)")
    fi
  fi
  
  # Report security status
  if [[ ${#security_issues[@]} -eq 0 ]]; then
    wallet_log_info "✅ Wallet security check passed"
    return 0
  else
    wallet_log_warn "⚠️ Security issues found:"
    for issue in "${security_issues[@]}"; do
      wallet_log_warn "   - $issue"
    done
    return 1
  fi
}

# === SIMULATE TRANSACTION ===
simulate_transaction() {
  local to_address="$1"
  local value="$2"
  local network="$3"
  local data="${4:-0x}"
  
  if [[ "${ENABLE_TRANSACTION_SIMULATION}" != "true" ]]; then
    wallet_log_info "📋 Transaction simulation disabled"
    return 0
  fi
  
  wallet_log_info "🧪 Simulating transaction on $network..."
  
  local wallet_address=$(derive_wallet_address)
  
  # Get RPC URL
  local rpc_var=""
  case "$network" in
    "arbitrum-sepolia") rpc_var="RPC_ARBT" ;;
    "base-sepolia") rpc_var="RPC_BAST" ;;
    "blast-sepolia") rpc_var="RPC_BLST" ;;
    "optimism-sepolia") rpc_var="RPC_OPST" ;;
    "unichain-sepolia") rpc_var="RPC_UNIT" ;;
    *) 
      wallet_log_warn "⚠️ Simulation not supported for $network"
      return 1
      ;;
  esac
  
  local rpc_url="${!rpc_var:-}"
  if [[ -z "$rpc_url" ]]; then
    wallet_log_warn "⚠️ RPC URL not configured for $network"
    return 1
  fi
  
  # Convert value to hex
  local value_hex=$(printf "0x%x" "$value" 2>/dev/null || echo "0x0")
  
  # Simulate transaction using eth_call
  local response=$(curl -s --max-time 15 -X POST "$rpc_url" \
    -H "Content-Type: application/json" \
    -d "{\"jsonrpc\":\"2.0\",\"method\":\"eth_call\",\"params\":[{\"from\":\"$wallet_address\",\"to\":\"$to_address\",\"value\":\"$value_hex\",\"data\":\"$data\"},\"latest\"],\"id\":1}" 2>/dev/null || echo "")
  
  if [[ -n "$response" && ! "$response" =~ "error" ]]; then
    wallet_log_info "✅ Transaction simulation successful"
    return 0
  else
    local error_msg=$(echo "$response" | grep -oP '"message":"[^"]*"' | cut -d'"' -f4 2>/dev/null || echo "Unknown error")
    wallet_log_warn "❌ Transaction simulation failed: $error_msg"
    return 1
  fi
}

# === GENERATE WALLET REPORT ===
generate_wallet_report() {
  local report_file="${LOGS_DIR}/wallet_report.txt"
  
  wallet_log_info "📋 Generating wallet report..."
  
  local wallet_address=$(derive_wallet_address 2>/dev/null || echo "Unknown")
  
  {
    echo "T3RN EXECUTOR WALLET REPORT"
    echo "Generated: $(date)"
    echo "========================================"
    echo ""
    
    echo "Wallet Configuration:"
    echo "  🔐 Security Mode: ${WALLET_SECURITY_MODE}"
    echo "  🧪 Transaction Simulation: ${ENABLE_TRANSACTION_SIMULATION}"
    echo "  📁 Backup Directory: $WALLET_BACKUP_DIR"
    echo "  💾 Cache Directory: $WALLET_CACHE_DIR"
    echo ""
    
    echo "Wallet Information:"
    echo "  📍 Address: $wallet_address"
    echo "  🔑 Private Key: ${PRIVATE_KEY_EXECUTOR:+CONFIGURED}"
    echo "  🌐 Enabled Networks: ${ENABLED_NETWORKS:-not set}"
    echo ""
    
    echo "Security Status:"
    if check_wallet_security >/dev/null 2>&1; then
      echo "  ✅ Security Check: PASSED"
    else
      echo "  ⚠️ Security Check: ISSUES FOUND"
    fi
    echo ""
    
    echo "Network Balances:"
    if [[ -n "${ENABLED_NETWORKS:-}" ]]; then
      IFS=',' read -ra networks <<< "${ENABLED_NETWORKS}"
      local total_balance=0
      
      for network in "${networks[@]}"; do
        network=$(echo "$network" | xargs)
        local balance=$(get_wallet_balance "$network" 2>/dev/null || echo "0.000000")
        echo "  $network: $balance ETH"
        
        if [[ "$balance" =~ ^[0-9]+\.?[0-9]*$ ]]; then
          total_balance=$(echo "scale=6; $total_balance + $balance" | bc -l 2>/dev/null || echo "$total_balance")
        fi
      done
      
      echo ""
      echo "  💎 Total Balance: $total_balance ETH"
    else
      echo "  ❌ No networks configured"
    fi
    echo ""
    
    echo "Backup Status:"
    if [[ -d "$WALLET_BACKUP_DIR" ]]; then
      local backup_count=$(ls -1 "$WALLET_BACKUP_DIR"/*.{enc,txt} 2>/dev/null | wc -l)
      echo "  📁 Backup Directory: EXISTS"
      echo "  📊 Backup Count: $backup_count"
      if [[ $backup_count -gt 0 ]]; then
        local latest_backup=$(ls -1t "$WALLET_BACKUP_DIR"/*.{enc,txt} 2>/dev/null | head -1)
        echo "  📅 Latest Backup: $(basename "$latest_backup")"
      fi
    else
      echo "  📁 Backup Directory: NOT FOUND"
    fi
    echo ""
    
  } > "$report_file"
  
  wallet_log_info "✅ Wallet report saved: $report_file"
}

# === GET WALLET STATUS ===
get_wallet_status() {
  local wallet_address=$(derive_wallet_address 2>/dev/null || echo "")
  
  if [[ -n "$wallet_address" ]]; then
    echo "CONFIGURED: $wallet_address"
  else
    echo "NOT_CONFIGURED"
  fi
}

# === VALIDATE WALLET CONFIGURATION ===
validate_wallet_configuration() {
  wallet_log_info "🔍 Validating wallet configuration..."
  
  # Check private key
  if [[ -z "${PRIVATE_KEY_EXECUTOR:-}" ]]; then
    wallet_log_warn "❌ PRIVATE_KEY_EXECUTOR not set"
    return 1
  fi
  
  # Validate private key format
  if ! validate_private_key_format "${PRIVATE_KEY_EXECUTOR}"; then
    return 1
  fi
  
  # Test wallet address derivation
  local wallet_address=$(derive_wallet_address 2>/dev/null || echo "")
  if [[ -z "$wallet_address" ]]; then
    wallet_log_warn "❌ Cannot derive wallet address"
    return 1
  fi
  
  # Validate derived address
  if ! validate_wallet_address "$wallet_address"; then
    return 1
  fi
  
  # Check security
  if [[ "${WALLET_SECURITY_MODE}" == "high" ]]; then
    if ! check_wallet_security >/dev/null 2>&1; then
      wallet_log_warn "⚠️ Security issues found in high security mode"
    fi
  fi
  
  wallet_log_info "✅ Wallet configuration validated"
  return 0
}

# === CLEANUP WALLET CACHE ===
cleanup_wallet_cache() {
  wallet_log_info "🧹 Cleaning up wallet cache..."
  
  if [[ -d "$WALLET_CACHE_DIR" ]]; then
    # Remove cache files older than 24 hours
    find "$WALLET_CACHE_DIR" -name "*.cache" -mtime +1 -delete 2>/dev/null || true
    wallet_log_info "✅ Wallet cache cleaned"
  fi
}

# === SECURE WALLET SETUP ===
secure_wallet_setup() {
  wallet_log_info "🔒 Performing secure wallet setup..."
  
  # Set secure permissions on .env file
  if [[ -f "$SCRIPT_DIR/.env" ]]; then
    chmod 600 "$SCRIPT_DIR/.env"
    wallet_log_info "✅ .env file permissions secured"
  fi
  
  # Set secure permissions on backup directory
  if [[ -d "$WALLET_BACKUP_DIR" ]]; then
    chmod 700 "$WALLET_BACKUP_DIR"
    wallet_log_info "✅ Backup directory permissions secured"
  fi
  
  # Set secure permissions on cache directory
  if [[ -d "$WALLET_CACHE_DIR" ]]; then
    chmod 700 "$WALLET_CACHE_DIR"
    wallet_log_info "✅ Cache directory permissions secured"
  fi
  
  # Clear command history of sensitive data
  if command -v history >/dev/null 2>&1; then
    history -c 2>/dev/null || true
    wallet_log_info "✅ Command history cleared"
  fi
  
  wallet_log_info "✅ Secure wallet setup completed"
}

# Initialize on load
initialize_wallet_manager

# Export functions
export -f initialize_wallet_manager
export -f validate_private_key_format
export -f derive_wallet_address
export -f cache_wallet_address
export -f get_cached_wallet_address
export -f validate_wallet_address
export -f get_wallet_balance
export -f backup_wallet_configuration
export -f check_wallet_security
export -f simulate_transaction
export -f generate_wallet_report
export -f get_wallet_status
export -f validate_wallet_configuration
export -f cleanup_wallet_cache
export -f secure_wallet_setup
