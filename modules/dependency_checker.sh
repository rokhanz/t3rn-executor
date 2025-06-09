#!/bin/bash
set -euo pipefail

# ╔══════════════════════════════════════════════════════════════╗
# ║                    T3RN DEPENDENCY CHECKER                  ║
# ║                  (System Dependencies)                      ║
# ╚══════════════════════════════════════════════════════════════╝

# T3RN Executor Dependency Checker
# Comprehensive system dependency validation and automatic installation
#
# @author Rokhanz
# @license MIT
# @version 1.0.0


# === INTERNAL ERROR HANDLING ===
dependency_error_exit() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] DEPENDENCY ERROR: $*" >&2
  exit 1
}

dependency_log_info() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] DEPENDENCY INFO: $*"
}

dependency_log_warn() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] DEPENDENCY WARN: $*"
}

# === INITIALIZE DEPENDENCY CHECKER ===
initialize_dependency_checker() {
  if [[ -z "${SCRIPT_DIR:-}" ]]; then
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")"/.. && pwd)"
    export SCRIPT_DIR
  fi
  
  if [[ -z "${LOGS_DIR:-}" ]]; then
    LOGS_DIR="$SCRIPT_DIR/logs"
    export LOGS_DIR
  fi
  
  mkdir -p "$LOGS_DIR" || dependency_error_exit "Cannot create logs directory"
  
  dependency_log_info "🔍 Dependency checker initialized"
}

# === SYSTEM INFORMATION ===
get_system_info() {
  dependency_log_info "🖥️ Gathering system information..."
  
  local os_name=$(uname -s)
  local os_arch=$(uname -m)
  local os_kernel=$(uname -r)
  local os_release=""
  
  # Get OS release information
  if [[ -f "/etc/os-release" ]]; then
    os_release=$(grep "PRETTY_NAME" /etc/os-release | cut -d'"' -f2)
  elif [[ -f "/etc/redhat-release" ]]; then
    os_release=$(cat /etc/redhat-release)
  else
    os_release="Unknown"
  fi
  
  echo "OS: $os_name"
  echo "Architecture: $os_arch"
  echo "Kernel: $os_kernel"
  echo "Release: $os_release"
  echo "User: $(whoami)"
  echo "Home: $HOME"
  echo "Shell: $SHELL"
  echo "CPU Cores: $(nproc 2>/dev/null || echo "unknown")"
  echo "Total Memory: $(free -h 2>/dev/null | grep '^Mem:' | awk '{print $2}' || echo "unknown")"
  echo "Available Memory: $(free -h 2>/dev/null | grep '^Mem:' | awk '{print $7}' || echo "unknown")"
  echo "Disk Space: $(df -h "$SCRIPT_DIR" 2>/dev/null | tail -1 | awk '{print $4}' || echo "unknown") available"
}

# === REQUIRED DEPENDENCIES ===
declare -A REQUIRED_DEPENDENCIES=(
  ["curl"]="HTTP client for API calls and downloads"
  ["tar"]="Archive extraction utility"
  ["screen"]="Terminal multiplexer for background execution"
  ["find"]="File search utility"
  ["stat"]="File status utility"
  ["grep"]="Text search utility"
  ["awk"]="Text processing utility"
  ["sed"]="Stream editor"
  ["cut"]="Text column extraction"
  ["bc"]="Basic calculator for arithmetic"
  ["ps"]="Process status utility"
  ["kill"]="Process termination utility"
  ["pkill"]="Process killing by name"
  ["nc"]="Network connection utility"
  ["free"]="Memory usage utility"
  ["top"]="Process monitoring utility"
  ["df"]="Disk space utility"
  ["date"]="Date and time utility"
  ["sleep"]="Delay utility"
  ["head"]="Text head utility"
  ["tail"]="Text tail utility"
  ["sort"]="Text sorting utility"
  ["uniq"]="Text uniqueness utility"
  ["wc"]="Word/line counting utility"
  ["xargs"]="Command execution utility"
  ["chmod"]="File permission utility"
  ["chown"]="File ownership utility"
  ["mkdir"]="Directory creation utility"
  ["rm"]="File removal utility"
  ["cp"]="File copy utility"
  ["mv"]="File move utility"
  ["ln"]="Link creation utility"
  ["which"]="Command location utility"
  ["whoami"]="User identification utility"
  ["id"]="User ID utility"
  ["uname"]="System information utility"
  ["hostname"]="Hostname utility"
  ["ping"]="Network connectivity test"
  ["wget"]="Alternative HTTP client"
  ["xxd"]="Hex dump utility"
  ["base64"]="Base64 encoding utility"
  ["openssl"]="Cryptographic utility"
)

# === OPTIONAL DEPENDENCIES ===
declare -A OPTIONAL_DEPENDENCIES=(
  ["jq"]="JSON processor for API responses"
  ["htop"]="Enhanced process monitor"
  ["tmux"]="Alternative terminal multiplexer"
  ["git"]="Version control system"
  ["vim"]="Text editor"
  ["nano"]="Simple text editor"
  ["less"]="Text pager"
  ["more"]="Text pager"
  ["tree"]="Directory tree display"
  ["rsync"]="File synchronization"
  ["zip"]="Archive creation"
  ["unzip"]="Archive extraction"
  ["gzip"]="Compression utility"
  ["gunzip"]="Decompression utility"
  ["lsof"]="List open files"
  ["netstat"]="Network statistics"
  ["ss"]="Socket statistics"
  ["iptables"]="Firewall utility"
  ["systemctl"]="Service control"
  ["journalctl"]="System log viewer"
  ["crontab"]="Task scheduler"
  ["at"]="Job scheduler"
  ["nohup"]="Background process utility"
  ["disown"]="Process detachment"
  ["jobs"]="Job control"
  ["bg"]="Background job control"
  ["fg"]="Foreground job control"
)

# === WALLET TOOLS DEPENDENCIES ===
declare -A WALLET_DEPENDENCIES=(
  ["cast"]="Foundry's cast tool for Ethereum operations"
  ["node"]="Node.js runtime for ethers.js"
  ["npm"]="Node.js package manager"
  ["python3"]="Python 3 runtime for web3.py"
  ["pip3"]="Python 3 package manager"
)

# === CHECK SINGLE DEPENDENCY ===
check_dependency() {
  local cmd="$1"
  local description="$2"
  local required="${3:-false}"
  
  if command -v "$cmd" >/dev/null 2>&1; then
    local version=""
    case "$cmd" in
      "curl")
        version=$(curl --version 2>/dev/null | head -1 | awk '{print $2}' || echo "unknown")
        ;;
      "screen")
        version=$(screen -v 2>&1 | head -1 | awk '{print $3}' || echo "unknown")
        ;;
      "node")
        version=$(node --version 2>/dev/null || echo "unknown")
        ;;
      "python3")
        version=$(python3 --version 2>/dev/null | awk '{print $2}' || echo "unknown")
        ;;
      "git")
        version=$(git --version 2>/dev/null | awk '{print $3}' || echo "unknown")
        ;;
      "jq")
        version=$(jq --version 2>/dev/null || echo "unknown")
        ;;
      *)
        version=$(command -v "$cmd" 2>/dev/null || echo "installed")
        ;;
    esac
    
    dependency_log_info "✅ $cmd: $version ($description)"
    return 0
  else
    if [[ "$required" == "true" ]]; then
      dependency_log_warn "❌ $cmd: MISSING (REQUIRED) - $description"
      return 1
    else
      dependency_log_warn "⚠️ $cmd: MISSING (optional) - $description"
      return 0
    fi
  fi
}

# === CHECK ALL DEPENDENCIES ===
check_all_dependencies() {
  dependency_log_info "🔍 Checking all system dependencies..."
  
  local missing_required=()
  local missing_optional=()
  local missing_wallet=()
  
  # Check required dependencies
  dependency_log_info "📋 Checking required dependencies..."
  for cmd in "${!REQUIRED_DEPENDENCIES[@]}"; do
    if ! check_dependency "$cmd" "${REQUIRED_DEPENDENCIES[$cmd]}" "true"; then
      missing_required+=("$cmd")
    fi
  done
  
  # Check optional dependencies
  dependency_log_info "📋 Checking optional dependencies..."
  for cmd in "${!OPTIONAL_DEPENDENCIES[@]}"; do
    if ! check_dependency "$cmd" "${OPTIONAL_DEPENDENCIES[$cmd]}" "false"; then
      missing_optional+=("$cmd")
    fi
  done
  
  # Check wallet tools
  dependency_log_info "📋 Checking wallet tools..."
  for cmd in "${!WALLET_DEPENDENCIES[@]}"; do
    if ! check_dependency "$cmd" "${WALLET_DEPENDENCIES[$cmd]}" "false"; then
      missing_wallet+=("$cmd")
    fi
  done
  
  # Summary
  dependency_log_info "📊 Dependency check summary:"
  dependency_log_info "   ✅ Required available: $((${#REQUIRED_DEPENDENCIES[@]} - ${#missing_required[@]}))/${#REQUIRED_DEPENDENCIES[@]}"
  dependency_log_info "   ✅ Optional available: $((${#OPTIONAL_DEPENDENCIES[@]} - ${#missing_optional[@]}))/${#OPTIONAL_DEPENDENCIES[@]}"
  dependency_log_info "   ✅ Wallet tools available: $((${#WALLET_DEPENDENCIES[@]} - ${#missing_wallet[@]}))/${#WALLET_DEPENDENCIES[@]}"
  
  if [[ ${#missing_required[@]} -gt 0 ]]; then
    dependency_log_warn "❌ Missing required dependencies: ${missing_required[*]}"
    return 1
  fi
  
  if [[ ${#missing_optional[@]} -gt 0 ]]; then
    dependency_log_info "⚠️ Missing optional dependencies: ${missing_optional[*]}"
  fi
  
  if [[ ${#missing_wallet[@]} -gt 0 ]]; then
    dependency_log_info "⚠️ Missing wallet tools: ${missing_wallet[*]}"
  fi
  
  dependency_log_info "✅ All required dependencies satisfied"
  return 0
}

# === INSTALL MISSING DEPENDENCIES ===
install_missing_dependencies() {
  dependency_log_info "📦 Installing missing dependencies..."
  
  # Detect package manager
  local package_manager=""
  local install_cmd=""
  local update_cmd=""
  
  if command -v apt >/dev/null 2>&1; then
    package_manager="apt"
    install_cmd="sudo apt install -y"
    update_cmd="sudo apt update"
  elif command -v yum >/dev/null 2>&1; then
    package_manager="yum"
    install_cmd="sudo yum install -y"
    update_cmd="sudo yum update"
  elif command -v dnf >/dev/null 2>&1; then
    package_manager="dnf"
    install_cmd="sudo dnf install -y"
    update_cmd="sudo dnf update"
  elif command -v pacman >/dev/null 2>&1; then
    package_manager="pacman"
    install_cmd="sudo pacman -S --noconfirm"
    update_cmd="sudo pacman -Sy"
  elif command -v zypper >/dev/null 2>&1; then
    package_manager="zypper"
    install_cmd="sudo zypper install -y"
    update_cmd="sudo zypper refresh"
  else
    dependency_log_warn "⚠️ No supported package manager found (apt, yum, dnf, pacman, zypper)"
    return 1
  fi
  
  dependency_log_info "📦 Detected package manager: $package_manager"
  
  # Update package lists
  dependency_log_info "🔄 Updating package lists..."
  if ! eval "$update_cmd"; then
    dependency_log_warn "⚠️ Failed to update package lists"
  fi
  
  # Install missing required dependencies
  local missing_required=()
  for cmd in "${!REQUIRED_DEPENDENCIES[@]}"; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
      missing_required+=("$cmd")
    fi
  done
  
  if [[ ${#missing_required[@]} -gt 0 ]]; then
    dependency_log_info "📦 Installing required packages: ${missing_required[*]}"
    
    # Package name mapping for different distributions
    local packages_to_install=()
    for cmd in "${missing_required[@]}"; do
      case "$cmd" in
        "bc") packages_to_install+=("bc") ;;
        "nc") packages_to_install+=("netcat-openbsd" "netcat" "nmap-ncat") ;;
        "xxd") packages_to_install+=("xxd" "vim-common") ;;
        *) packages_to_install+=("$cmd") ;;
      esac
    done
    
    # Install packages
    for package in "${packages_to_install[@]}"; do
      dependency_log_info "📦 Installing $package..."
      if eval "$install_cmd $package"; then
        dependency_log_info "✅ Successfully installed $package"
      else
        dependency_log_warn "❌ Failed to install $package"
      fi
    done
  fi
  
  # Install useful optional packages
  dependency_log_info "📦 Installing recommended optional packages..."
  local recommended_optional=("jq" "htop" "git" "vim" "tree")
  
  for package in "${recommended_optional[@]}"; do
    if ! command -v "$package" >/dev/null 2>&1; then
      dependency_log_info "📦 Installing optional package: $package..."
      if eval "$install_cmd $package"; then
        dependency_log_info "✅ Successfully installed $package"
      else
        dependency_log_warn "⚠️ Failed to install optional package: $package"
      fi
    fi
  done
}

# === INSTALL WALLET TOOLS ===
install_wallet_tools() {
  dependency_log_info "🔑 Installing wallet tools for address derivation..."
  
  # Install Foundry (cast)
  if ! command -v cast >/dev/null 2>&1; then
    dependency_log_info "🔧 Installing Foundry (cast)..."
    if curl -L https://foundry.paradigm.xyz | bash; then
      # Source foundry environment
      if [[ -f "$HOME/.foundry/bin/foundryup" ]]; then
        "$HOME/.foundry/bin/foundryup"
        export PATH="$HOME/.foundry/bin:$PATH"
        dependency_log_info "✅ Foundry installed successfully"
      fi
    else
      dependency_log_warn "❌ Failed to install Foundry"
    fi
  fi
  
  # Install Node.js and ethers
  if ! command -v node >/dev/null 2>&1; then
    dependency_log_info "🔧 Installing Node.js..."
    
    # Install Node.js using NodeSource repository
    if command -v curl >/dev/null 2>&1; then
      if curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -; then
        if sudo apt-get install -y nodejs; then
          dependency_log_info "✅ Node.js installed successfully"
        fi
      fi
    fi
  fi
  
  # Install ethers.js globally
  if command -v npm >/dev/null 2>&1 && ! npm list -g ethers >/dev/null 2>&1; then
    dependency_log_info "🔧 Installing ethers.js..."
    if npm install -g ethers; then
      dependency_log_info "✅ ethers.js installed successfully"
    else
      dependency_log_warn "❌ Failed to install ethers.js"
    fi
  fi
  
  # Install Python3 and web3
  if ! command -v python3 >/dev/null 2>&1; then
    dependency_log_info "🔧 Installing Python3..."
    if command -v apt >/dev/null 2>&1; then
      if sudo apt update && sudo apt install -y python3 python3-pip; then
        dependency_log_info "✅ Python3 installed successfully"
      fi
    fi
  fi
  
  # Install web3.py and eth-account
  if command -v pip3 >/dev/null 2>&1; then
    dependency_log_info "🔧 Installing web3.py and eth-account..."
    if pip3 install web3 eth-account; then
      dependency_log_info "✅ web3.py and eth-account installed successfully"
    else
      dependency_log_warn "❌ Failed to install web3.py packages"
    fi
  fi
}

# === CHECK SYSTEM REQUIREMENTS ===
check_system_requirements() {
  dependency_log_info "🖥️ Checking system requirements..."
  
  local requirements_met=true
  
  # Check architecture
  local arch=$(uname -m)
  if [[ "$arch" != "x86_64" ]]; then
    dependency_log_warn "⚠️ Architecture $arch may not be supported (recommended: x86_64)"
    requirements_met=false
  else
    dependency_log_info "✅ Architecture: $arch (supported)"
  fi
  
  # Check memory
  local total_memory_kb=$(grep MemTotal /proc/meminfo 2>/dev/null | awk '{print $2}' || echo "0")
  local total_memory_mb=$((total_memory_kb / 1024))
  
  if [[ $total_memory_mb -lt 1024 ]]; then
    dependency_log_warn "⚠️ Low memory: ${total_memory_mb}MB (recommended: 2GB+)"
    requirements_met=false
  else
    dependency_log_info "✅ Memory: ${total_memory_mb}MB (sufficient)"
  fi
  
  # Check disk space
  local available_space_kb=$(df "$SCRIPT_DIR" 2>/dev/null | tail -1 | awk '{print $4}' || echo "0")
  local available_space_mb=$((available_space_kb / 1024))
  
  if [[ $available_space_mb -lt 500 ]]; then
    dependency_log_warn "⚠️ Low disk space: ${available_space_mb}MB (recommended: 1GB+)"
    requirements_met=false
  else
    dependency_log_info "✅ Disk space: ${available_space_mb}MB (sufficient)"
  fi
  
  # Check internet connectivity
  if ping -c 1 -W 5 8.8.8.8 >/dev/null 2>&1; then
    dependency_log_info "✅ Internet connectivity: OK"
  else
    dependency_log_warn "⚠️ Internet connectivity: Failed"
    requirements_met=false
  fi
  
  # Check permissions
  if [[ -w "$SCRIPT_DIR" ]]; then
    dependency_log_info "✅ Write permissions: OK"
  else
    dependency_log_warn "⚠️ Write permissions: Failed"
    requirements_met=false
  fi
  
  if [[ "$requirements_met" == "true" ]]; then
    dependency_log_info "✅ All system requirements met"
    return 0
  else
    dependency_log_warn "⚠️ Some system requirements not met"
    return 1
  fi
}

# === GENERATE DEPENDENCY REPORT ===
generate_dependency_report() {
  local report_file="${LOGS_DIR}/dependency_report.txt"
  
  dependency_log_info "📋 Generating dependency report..."
  
  {
    echo "T3RN EXECUTOR DEPENDENCY REPORT"
    echo "Generated: $(date)"
    echo "========================================"
    echo ""
    
    echo "System Information:"
    get_system_info
    echo ""
    
    echo "Required Dependencies:"
    for cmd in "${!REQUIRED_DEPENDENCIES[@]}"; do
      if command -v "$cmd" >/dev/null 2>&1; then
        local version=$(command -v "$cmd")
        echo "  ✅ $cmd: $version"
      else
        echo "  ❌ $cmd: MISSING"
      fi
    done
    echo ""
    
    echo "Optional Dependencies:"
    for cmd in "${!OPTIONAL_DEPENDENCIES[@]}"; do
      if command -v "$cmd" >/dev/null 2>&1; then
        local version=$(command -v "$cmd")
        echo "  ✅ $cmd: $version"
      else
        echo "  ⚠️ $cmd: MISSING"
      fi
    done
    echo ""
    
    echo "Wallet Tools:"
    for cmd in "${!WALLET_DEPENDENCIES[@]}"; do
      if command -v "$cmd" >/dev/null 2>&1; then
        local version=""
        case "$cmd" in
          "cast") version=$(cast --version 2>/dev/null | head -1 || echo "installed") ;;
          "node") version=$(node --version 2>/dev/null || echo "installed") ;;
          "python3") version=$(python3 --version 2>/dev/null || echo "installed") ;;
          *) version="installed" ;;
        esac
        echo "  ✅ $cmd: $version"
      else
        echo "  ⚠️ $cmd: MISSING"
      fi
    done
    echo ""
    
    echo "Installation Commands:"
    echo "  Required packages: sudo apt update && sudo apt install -y curl tar screen bc netcat-openbsd xxd"
    echo "  Optional packages: sudo apt install -y jq htop git vim tree"
    echo "  Foundry (cast): curl -L https://foundry.paradigm.xyz | bash"
    echo "  Node.js + ethers: curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash - && sudo apt install -y nodejs && npm install -g ethers"
    echo "  Python3 + web3: sudo apt install -y python3 python3-pip && pip3 install web3 eth-account"
    echo ""
    
  } > "$report_file"
  
  dependency_log_info "✅ Dependency report saved: $report_file"
}

# === GET MISSING DEPENDENCIES ===
get_missing_dependencies() {
  local missing=()
  
  for cmd in "${!REQUIRED_DEPENDENCIES[@]}"; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
      missing+=("$cmd")
    fi
  done
  
  if [[ ${#missing[@]} -gt 0 ]]; then
    echo "Missing required: ${missing[*]}"
  else
    echo "All required dependencies satisfied"
  fi
}

# === VALIDATE DEPENDENCY CONFIGURATION ===
validate_dependency_configuration() {
  dependency_log_info "🔍 Validating dependency configuration..."
  
  # Check if all required dependencies are available
  if ! check_all_dependencies >/dev/null 2>&1; then
    dependency_log_warn "⚠️ Some required dependencies are missing"
    return 1
  fi
  
  # Check system requirements
  if ! check_system_requirements >/dev/null 2>&1; then
    dependency_log_warn "⚠️ System requirements not fully met"
    return 1
  fi
  
  dependency_log_info "✅ Dependency configuration validated"
  return 0
}

# === AUTO INSTALL DEPENDENCIES ===
auto_install_dependencies() {
  dependency_log_info "🚀 Starting automatic dependency installation..."
  
  # Install missing system dependencies
  install_missing_dependencies
  
  # Install wallet tools
  install_wallet_tools
  
  # Verify installation
  if check_all_dependencies; then
    dependency_log_info "✅ All dependencies installed successfully"
    return 0
  else
    dependency_log_warn "⚠️ Some dependencies may still be missing"
    return 1
  fi
}

# Initialize on load
initialize_dependency_checker

# Export functions
export -f initialize_dependency_checker
export -f check_dependency
export -f check_all_dependencies
export -f install_missing_dependencies
export -f install_wallet_tools
export -f check_system_requirements
export -f generate_dependency_report
export -f get_missing_dependencies
export -f validate_dependency_configuration
export -f auto_install_dependencies
export -f get_system_info
