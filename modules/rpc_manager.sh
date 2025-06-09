#!/bin/bash
set -euo pipefail

# ╔══════════════════════════════════════════════════════════════╗
# ║                    T3RN RPC MANAGER                         ║
# ║                  (RPC Endpoint Management)                  ║
# ╚══════════════════════════════════════════════════════════════╝

# T3RN Executor RPC Manager
# Comprehensive RPC endpoint management with Alchemy integration and failover
#
# @author Rokhanz
# @license MIT
# @version 1.0.0

# === INTERNAL ERROR HANDLING ===
rpc_error_exit() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] RPC ERROR: $*" >&2
  exit 1
}

rpc_log_info() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] RPC INFO: $*"
}

rpc_log_warn() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] RPC WARN: $*"
}

# === INTERNAL VALIDATION ===
validate_rpc_environment() {
  [[ -n "${SCRIPT_DIR:-}" ]] || rpc_error_exit "SCRIPT_DIR not set"
  [[ -f "$SCRIPT_DIR/.env" ]] || rpc_error_exit ".env file not found"
  
  # Load validation module if available
  if [[ -f "$SCRIPT_DIR/modules/validation.sh" ]]; then
    source "$SCRIPT_DIR/modules/validation.sh" 2>/dev/null || true
    
    # Run RPC-specific validations if available
    if command -v validate_rpc_endpoints >/dev/null 2>&1; then
      validate_rpc_endpoints || rpc_error_exit "RPC endpoints validation failed"
    fi
  fi
  
  return 0
}

# === INITIALIZE RPC MANAGER ===
initialize_rpc_manager() {
  if [[ -z "${SCRIPT_DIR:-}" ]]; then
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")"/.. && pwd)"
    export SCRIPT_DIR
  fi
  
  validate_rpc_environment
}

# === LOAD ALCHEMY KEYS (Extended untuk 8 Keys) ===
load_alchemy_keys() {
  rpc_log_info "🔑 Loading Alchemy API keys..."
  
  local alchemy_keys=()
  local valid_keys=0
  
  # Load up to 8 Alchemy keys
  for i in {1..8}; do
    local key_var="ALCHEMY_KEY_$i"
    local key_value="${!key_var:-}"
    
    if [[ -n "$key_value" && "$key_value" != "your_alchemy_api_key" && "$key_value" != "" ]]; then
      # Validate key format
      if [[ ${#key_value} -ge 20 && "$key_value" =~ ^[a-zA-Z0-9_-]+$ ]]; then
        alchemy_keys+=("$key_value")
        ((valid_keys++))
        rpc_log_info "✅ Valid Alchemy key #$i loaded"
      else
        rpc_log_warn "⚠️ Invalid Alchemy key #$i format, skipping"
      fi
    else
      rpc_log_info "📝 Alchemy key #$i not configured or using placeholder"
    fi
  done
  
  export ALCHEMY_KEYS=("${alchemy_keys[@]}")
  rpc_log_info "✅ Total Alchemy keys loaded: $valid_keys"
  
  if [[ $valid_keys -eq 0 ]]; then
    rpc_log_warn "⚠️ No valid Alchemy keys found. Will use fallback RPCs only."
  fi
  
  return 0
}

# === GET ALCHEMY URL FOR NETWORK (Complete dengan Network Baru) ===
get_alchemy_url_for_network() {
  local network="$1"
  local api_key="$2"
  
  case "$network" in
    "arbitrum-sepolia")
      echo "https://arb-sepolia.g.alchemy.com/v2/$api_key"
      ;;
    "base-sepolia")
      echo "https://base-sepolia.g.alchemy.com/v2/$api_key"
      ;;
    "blast-sepolia")
      echo "https://blast-sepolia.g.alchemy.com/v2/$api_key"
      ;;
    "optimism-sepolia")
      echo "https://opt-sepolia.g.alchemy.com/v2/$api_key"
      ;;
    "unichain-sepolia")
      echo "https://unichain-sepolia.g.alchemy.com/v2/$api_key"
      ;;
    "sei-testnet")
      echo "https://sei-testnet.g.alchemy.com/v2/$api_key"
      ;;
    "abstract-testnet")
      echo "https://abstract-testnet.g.alchemy.com/v2/$api_key"
      ;;
    "berachain-bepolia")
      echo "https://berachain-bepolia.g.alchemy.com/v2/$api_key"
      ;;
    "monad-testnet")
      echo "https://monad-testnet.g.alchemy.com/v2/$api_key"
      ;;
    "bnb-testnet")
      echo "https://bnb-testnet.g.alchemy.com/v2/$api_key"
      ;;
    # Network yang tidak support Alchemy (berdasarkan informasi)
    "lisk-sepolia"|"l2rn")
      rpc_log_warn "⚠️ $network not supported by Alchemy, using fallback"
      return 1
      ;;
    *)
      rpc_log_warn "⚠️ Network $network not supported by Alchemy"
      return 1
      ;;
  esac
  
  return 0
}

# === SETUP FALLBACK RPC (Complete Network List) ===
setup_fallback_rpc() {
  local network="$1"
  local network_code="$2"
  local rpc_var="RPC_${network_code^^}"
  
  rpc_log_info "🔄 Setting up fallback RPC for $network..."
  
  # Fallback URLs (Complete)
  case "$network" in
    "arbitrum-sepolia")
      export "$rpc_var"="https://sepolia-rollup.arbitrum.io/rpc"
      ;;
    "base-sepolia")
      export "$rpc_var"="https://base-sepolia-rpc.publicnode.com"
      ;;
    "blast-sepolia")
      export "$rpc_var"="https://sepolia.blast.io"
      ;;
    "optimism-sepolia")
      export "$rpc_var"="https://sepolia.optimism.io"
      ;;
    "unichain-sepolia")
      export "$rpc_var"="https://sepolia.unichain.org"
      ;;
    "monad-testnet")
      export "$rpc_var"="https://testnet-rpc.monad.xyz"
      ;;
    "sei-testnet")
      export "$rpc_var"="https://evm-rpc-testnet.sei-apis.com"
      ;;
    "abstract-testnet")
      export "$rpc_var"="https://api.testnet.abs.xyz"
      ;;
    "lisk-sepolia")
      export "$rpc_var"="https://rpc.sepolia-api.lisk.com"
      ;;
    "berachain-bepolia")
      export "$rpc_var"="https://bepolia.rpc.berachain.com"
      ;;
    "bnb-testnet")
      export "$rpc_var"="https://data-seed-prebsc-1-s1.binance.org:8545"
      ;;
    "l2rn")
      export "$rpc_var"="wss://rpc.t1rn.io"
      ;;
    *)
      rpc_error_exit "No fallback RPC available for: $network"
      ;;
  esac
  
  rpc_log_info "✅ $network RPC set to fallback: ${!rpc_var}"
}

# === TEST RPC ENDPOINT ===
test_rpc_endpoint() {
  local url="$1"
  local network="$2"
  
  # Test dengan eth_blockNumber untuk HTTP/HTTPS
  if [[ "$url" =~ ^https?:// ]]; then
    local response=$(curl -s --max-time 10 -X POST "$url" \
      -H "Content-Type: application/json" \
      -d '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' 2>/dev/null || echo "")
    
    if [[ "$response" =~ "result" && ! "$response" =~ "error" ]]; then
      return 0
    else
      rpc_log_warn "❌ RPC test failed for $network: ${response:0:100}"
      return 1
    fi
  
  # Test WebSocket connection untuk WSS
  elif [[ "$url" =~ ^wss?:// ]]; then
    # Simple connection test untuk WebSocket
    if command -v nc >/dev/null 2>&1; then
      local host=$(echo "$url" | sed 's|wss\?://||' | cut -d'/' -f1)
      local port="443"
      
      if echo | timeout 5 nc -z "$host" "$port" 2>/dev/null; then
        return 0
      else
        rpc_log_warn "❌ WebSocket connection test failed for $network"
        return 1
      fi
    else
      rpc_log_warn "⚠️ Cannot test WebSocket (nc not available), assuming working"
      return 0
    fi
  
  else
    rpc_log_warn "⚠️ Unknown URL scheme for $network: $url"
    return 1
  fi
}

# === SETUP ALCHEMY RPC WITH FALLBACK (Enhanced untuk Semua Network) ===
setup_alchemy_rpc_with_fallback() {
  local network="$1"
  local network_code="$2"
  
  rpc_log_info "🔑 Setting up Alchemy RPC for $network with fallback priority..."
  
  # Check if network supports Alchemy (berdasarkan informasi yang diberikan)
  local alchemy_supported=true
  case "$network" in
    "lisk-sepolia"|"l2rn")
      alchemy_supported=false
      rpc_log_info "📍 $network tidak support Alchemy, langsung ke fallback"
      ;;
    "arbitrum-sepolia"|"base-sepolia"|"blast-sepolia"|"optimism-sepolia"|"unichain-sepolia"|"sei-testnet"|"abstract-testnet"|"berachain-bepolia"|"monad-testnet"|"bnb-testnet")
      alchemy_supported=true
      ;;
    *)
      alchemy_supported=false
      rpc_log_warn "⚠️ $network tidak dikenal, menggunakan fallback"
      ;;
  esac
  
  # Jika tidak support Alchemy, langsung fallback
  if [[ "$alchemy_supported" == "false" ]]; then
    setup_fallback_rpc "$network" "$network_code"
    return 0
  fi
  
  # Check if Alchemy keys available
  if [[ -z "${ALCHEMY_KEYS:-}" ]] || [[ ${#ALCHEMY_KEYS[@]} -eq 0 ]]; then
    rpc_log_warn "⚠️ No Alchemy keys available for $network, using fallback"
    setup_fallback_rpc "$network" "$network_code"
    return 0
  fi
  
  # Test semua Alchemy keys untuk network ini
  local working_key=""
  for key in "${ALCHEMY_KEYS[@]}"; do
    local test_url=$(get_alchemy_url_for_network "$network" "$key")
    local url_exit_code=$?
    
    # Skip jika get_alchemy_url_for_network return error
    if [[ $url_exit_code -ne 0 ]]; then
      continue
    fi
    
    rpc_log_info "🧪 Testing Alchemy key for $network: ${key:0:8}...${key: -4}"
    
    # Test RPC endpoint
    if test_rpc_endpoint "$test_url" "$network"; then
      working_key="$key"
      rpc_log_info "✅ Alchemy key working for $network: ${key:0:8}...${key: -4}"
      break
    else
      rpc_log_warn "❌ Alchemy key failed for $network: ${key:0:8}...${key: -4}"
    fi
  done
  
  # Set RPC URL berdasarkan hasil test
  local rpc_var="RPC_${network_code^^}"
  
  if [[ -n "$working_key" ]]; then
    local alchemy_url=$(get_alchemy_url_for_network "$network" "$working_key")
    export "$rpc_var"="$alchemy_url"
    rpc_log_info "✅ $network RPC set to Alchemy: ${working_key:0:8}...${working_key: -4}"
  else
    rpc_log_warn "⚠️ All Alchemy keys failed for $network, using fallback"
    setup_fallback_rpc "$network" "$network_code"
  fi
}

# === GET RPC URL FOR NETWORK (Complete Network List) ===
get_rpc_url_for_network() {
  local network="$1"
  [[ -n "$network" ]] || rpc_error_exit "Network parameter empty"
  
  rpc_log_info "🔍 Getting RPC URL for network: $network"
  
  # Map network names to RPC variable names (Complete)
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
      rpc_error_exit "Unsupported network: $network"
      ;;
  esac
  
  # Use default value syntax
  local rpc_url="${!rpc_var:-}"
  
  if [[ -z "$rpc_url" ]]; then
    rpc_error_exit "RPC URL not configured for network: $network (variable: $rpc_var)"
  fi
  
  echo "$rpc_url"
}

# === SETUP RPC ENDPOINTS FROM ENV (Main Function - Complete) ===
setup_rpc_endpoints_from_env() {
  rpc_log_info "🌐 Menyiapkan RPC endpoints dengan Alchemy priority + fallback..."
  
  # Load Alchemy keys first
  load_alchemy_keys
  
  # Define network mappings (Complete List)
  local networks=("arbitrum-sepolia" "base-sepolia" "blast-sepolia" "optimism-sepolia" "unichain-sepolia" "monad-testnet" "sei-testnet" "abstract-testnet" "lisk-sepolia" "berachain-bepolia" "bnb-testnet" "l2rn")
  local network_codes=("arbt" "bast" "blst" "opst" "unit" "mont" "seit" "abst" "lisk" "bera" "bnb" "l2rn")
  
  # Setup RPC untuk setiap network dengan priority Alchemy
  for i in "${!networks[@]}"; do
    local network="${networks[$i]}"
    local network_code="${network_codes[$i]}"
    
    # Check if network is enabled
    if [[ -v ENABLED_NETWORKS_ARRAY ]]; then
      if [[ " ${ENABLED_NETWORKS_ARRAY[*]} " =~ " ${network} " ]]; then
        rpc_log_info "🔧 Setting up RPC for enabled network: $network"
        setup_alchemy_rpc_with_fallback "$network" "$network_code"
      else
        rpc_log_info "⏭️ Skipping disabled network: $network"
      fi
    else
      # Fallback if ENABLED_NETWORKS_ARRAY not set
      rpc_log_warn "⚠️ ENABLED_NETWORKS_ARRAY not set, setting up all networks"
      setup_alchemy_rpc_with_fallback "$network" "$network_code"
    fi
  done
  
  # Handle RPC overrides from .env
  handle_rpc_overrides
  
  rpc_log_info "✅ RPC endpoints configured with Alchemy priority"
}

# === HANDLE RPC OVERRIDES (Complete) ===
handle_rpc_overrides() {
  rpc_log_info "🔧 Checking for RPC overrides..."
  
  local override_vars=("RPC_ARBT_OVERRIDE" "RPC_BAST_OVERRIDE" "RPC_BLST_OVERRIDE" "RPC_OPST_OVERRIDE" "RPC_UNIT_OVERRIDE" "RPC_MONT_OVERRIDE" "RPC_SEIT_OVERRIDE" "RPC_ABST_OVERRIDE" "RPC_LISK_OVERRIDE" "RPC_BERA_OVERRIDE" "RPC_BNB_OVERRIDE" "RPC_L2RN_OVERRIDE")
  local target_vars=("RPC_ARBT" "RPC_BAST" "RPC_BLST" "RPC_OPST" "RPC_UNIT" "RPC_MONT" "RPC_SEIT" "RPC_ABST" "RPC_LISK" "RPC_BERA" "RPC_BNB" "RPC_L2RN")
  
  for i in "${!override_vars[@]}"; do
    local override_var="${override_vars[$i]}"
    local target_var="${target_vars[$i]}"
    local override_value="${!override_var:-}"
    
    if [[ -n "$override_value" ]]; then
      export "$target_var"="$override_value"
      rpc_log_info "✅ RPC override applied: $target_var = $override_value"
    fi
  done
}

# === RPC HEALTH CHECK (Complete) ===
check_rpc_health() {
  local network="$1"
  local rpc_url=$(get_rpc_url_for_network "$network" 2>/dev/null || echo "")
  
  if [[ -z "$rpc_url" ]]; then
    rpc_log_warn "❌ No RPC URL configured for $network"
    return 1
  fi
  
  rpc_log_info "🏥 Checking RPC health for $network..."
  
  if test_rpc_endpoint "$rpc_url" "$network"; then
    rpc_log_info "✅ RPC health check passed for $network"
    return 0
  else
    rpc_log_warn "❌ RPC health check failed for $network"
    return 1
  fi
}

# === SCHEDULE RPC HEALTH CHECK ===
schedule_rpc_health_check() {
  local interval="${RPC_HEALTH_CHECK_INTERVAL:-300}"
  
  rpc_log_info "⏰ Starting RPC health check scheduler (interval: ${interval}s)"
  
  while true; do
    if [[ -v ENABLED_NETWORKS_ARRAY ]]; then
      for network in "${ENABLED_NETWORKS_ARRAY[@]}"; do
        check_rpc_health "$network" || true  # Don't exit on health check failure
      done
    fi
    
    sleep "$interval"
  done
}

# === DISPLAY RPC CONFIGURATION (Complete) ===
display_rpc_configuration() {
  rpc_log_info "📋 RPC Configuration Summary:"
  
  local networks=("arbitrum-sepolia" "base-sepolia" "blast-sepolia" "optimism-sepolia" "unichain-sepolia" "monad-testnet" "sei-testnet" "abstract-testnet" "lisk-sepolia" "berachain-bepolia" "bnb-testnet" "l2rn")
  local network_codes=("arbt" "bast" "blst" "opst" "unit" "mont" "seit" "abst" "lisk" "bera" "bnb" "l2rn")
  
  for i in "${!networks[@]}"; do
    local network="${networks[$i]}"
    local network_code="${network_codes[$i]}"
    local rpc_var="RPC_${network_code^^}"
    local rpc_url="${!rpc_var:-not configured}"
    
    if [[ -v ENABLED_NETWORKS_ARRAY ]] && [[ " ${ENABLED_NETWORKS_ARRAY[*]} " =~ " ${network} " ]]; then
      rpc_log_info "   ✅ $network: $rpc_url"
    else
      rpc_log_info "   ⏭️ $network: disabled"
    fi
  done
}

# === VALIDATE ALL RPC ENDPOINTS ===
validate_all_rpc_endpoints() {
  rpc_log_info "🔍 Validating all configured RPC endpoints..."
  
  local failed_networks=()
  
  if [[ -v ENABLED_NETWORKS_ARRAY ]]; then
    for network in "${ENABLED_NETWORKS_ARRAY[@]}"; do
      if ! check_rpc_health "$network"; then
        failed_networks+=("$network")
      fi
    done
  fi
  
  if [[ ${#failed_networks[@]} -gt 0 ]]; then
    rpc_log_warn "⚠️ RPC validation failed for networks: ${failed_networks[*]}"
    return 1
  else
    rpc_log_info "✅ All RPC endpoints validated successfully"
    return 0
  fi
}

# Initialize on load
initialize_rpc_manager

# Export functions
export -f setup_rpc_endpoints_from_env
export -f get_rpc_url_for_network
export -f check_rpc_health
export -f schedule_rpc_health_check
export -f display_rpc_configuration
export -f validate_all_rpc_endpoints
export -f load_alchemy_keys
export -f setup_alchemy_rpc_with_fallback
export -f setup_fallback_rpc
export -f test_rpc_endpoint
