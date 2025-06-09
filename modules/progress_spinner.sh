#!/bin/bash
set -euo pipefail

# ╔══════════════════════════════════════════════════════════════╗
# ║                    T3RN PROGRESS SPINNER                    ║
# ║                  (Animated Spinner Display)                 ║
# ╚══════════════════════════════════════════════════════════════╝

# T3RN Executor Progress Spinner
# Animated spinner display with multiple styles and colorful effects
#
# @author Rokhanz
# @license MIT
# @version 1.0.0


# === INTERNAL ERROR HANDLING ===
spinner_error_exit() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] SPINNER ERROR: $*" >&2
  exit 1
}

spinner_log_info() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] SPINNER INFO: $*"
}

spinner_log_warn() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] SPINNER WARN: $*"
}

# === INITIALIZE SPINNER ===
initialize_spinner() {
  if [[ -z "${SCRIPT_DIR:-}" ]]; then
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")"/.. && pwd)"
    export SCRIPT_DIR
  fi
  
  # Load .env for spinner configuration
  if [[ -f "$SCRIPT_DIR/.env" ]]; then
    source "$SCRIPT_DIR/.env" 2>/dev/null || true
  fi
  
  # Load color progress if available
  if [[ -f "$SCRIPT_DIR/modules/progress_bar_color.sh" ]]; then
    source "$SCRIPT_DIR/modules/progress_bar_color.sh" 2>/dev/null || true
  fi
  
  # Spinner configuration
  ENABLE_PROGRESS_BAR="${ENABLE_PROGRESS_BAR:-true}"
  ENABLE_COLOR_OUTPUT="${ENABLE_COLOR_OUTPUT:-true}"
  ENABLE_EMOJI_LOGGING="${ENABLE_EMOJI_LOGGING:-true}"
  SPINNER_SPEED="${SPINNER_SPEED:-0.1}"
  
  # Spinner state variables
  export SPINNER_PID=""
  export SPINNER_ACTIVE=false
  export SPINNER_MESSAGE=""
}

# === SPINNER CHARACTER SETS ===
declare -A SPINNER_SETS=(
  ["classic"]="⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏"
  ["dots"]="⠋⠙⠚⠞⠖⠦⠴⠲⠳⠓"
  ["line"]="⠂⠄⠅⠇⠆⠖⠦⠴⠲⠱⠹⠸⠼⠴⠦⠖⠆⠇⠅⠄"
  ["pipe"]="┤┘┴└├┌┬┐"
  ["star"]="✶✸✹✺✹✷"
  ["arrow"]="←↖↑↗→↘↓↙"
  ["bounce"]="⠁⠂⠄⠂"
  ["toggle"]="⊶⊷"
  ["clock"]="🕐🕑🕒🕓🕔🕕🕖🕗🕘🕙🕚🕛"
  ["moon"]="🌑🌒🌓🌔🌕🌖🌗🌘"
  ["earth"]="🌍🌎🌏"
  ["weather"]="☀️⛅☁️🌧️⛈️🌩️"
  ["simple"]="/-\\|"
  ["blocks"]="▁▃▄▅▆▇█▇▆▅▄▃"
  ["squares"]="▖▘▝▗"
  ["triangles"]="◢◣◤◥"
  ["hearts"]="💛💙💜💚❤️"
  ["fire"]="🔥💥✨⭐🌟"
  ["water"]="💧💦🌊"
  ["progress"]="▏▎▍▌▋▊▉█"
)

# === GET SPINNER CHARACTERS ===
get_spinner_chars() {
  local style="${1:-classic}"
  echo "${SPINNER_SETS[$style]:-${SPINNER_SETS[classic]}}"
}

# === SHOW SPINNER ===
show_spinner() {
  local message="${1:-Loading}"
  local style="${2:-classic}"
  local duration="${3:-0}"  # 0 = infinite
  
  if [[ "${ENABLE_PROGRESS_BAR}" != "true" ]]; then
    return 0
  fi
  
  local chars=$(get_spinner_chars "$style")
  local char_count=${#chars}
  local position=0
  local start_time=$(date +%s)
  
  export SPINNER_ACTIVE=true
  export SPINNER_MESSAGE="$message"
  
  while [[ "$SPINNER_ACTIVE" == "true" ]]; do
    local char="${chars:$((position % char_count)):1}"
    local color=""
    
    # Apply colors if enabled
    if [[ "${ENABLE_COLOR_OUTPUT}" == "true" ]]; then
      case "$style" in
        "classic"|"dots"|"line"|"pipe")
          color="$COLOR_CYAN"
          ;;
        "star")
          color="$COLOR_YELLOW"
          ;;
        "arrow")
          color="$COLOR_BLUE"
          ;;
        "clock")
          color="$COLOR_MAGENTA"
          ;;
        "moon")
          color="$COLOR_DIM"
          ;;
        "fire")
          color="$COLOR_RED"
          ;;
        "water")
          color="$COLOR_BLUE"
          ;;
        *)
          color="$COLOR_GREEN"
          ;;
      esac
    fi
    
    # Display spinner with message
    if [[ "${ENABLE_EMOJI_LOGGING}" == "true" && ! "$style" =~ ^(clock|moon|earth|weather|hearts|fire|water)$ ]]; then
      echo -ne "\r🔄 ${COLOR_BOLD}${COLOR_CYAN}$message${COLOR_RESET} ${color}${char}${COLOR_RESET}"
    else
      echo -ne "\r${COLOR_BOLD}${COLOR_CYAN}$message${COLOR_RESET} ${color}${char}${COLOR_RESET}"
    fi
    
    sleep "${SPINNER_SPEED}"
    ((position++))
    
    # Check duration
    if [[ $duration -gt 0 ]]; then
      local current_time=$(date +%s)
      if [[ $((current_time - start_time)) -ge $duration ]]; then
        break
      fi
    fi
  done
  
  # Clear spinner line
  echo -ne "\r\033[K"
}

# === START SPINNER IN BACKGROUND ===
start_spinner() {
  local message="${1:-Processing}"
  local style="${2:-classic}"
  
  if [[ "${ENABLE_PROGRESS_BAR}" != "true" ]]; then
    return 0
  fi
  
  # Stop any existing spinner
  stop_spinner
  
  # Start new spinner in background
  show_spinner "$message" "$style" &
  export SPINNER_PID=$!
  
  spinner_log_info "🔄 Spinner started (PID: $SPINNER_PID)"
}

# === STOP SPINNER ===
stop_spinner() {
  if [[ -n "${SPINNER_PID}" && "${SPINNER_PID}" != "" ]]; then
    export SPINNER_ACTIVE=false
    kill "${SPINNER_PID}" 2>/dev/null || true
    wait "${SPINNER_PID}" 2>/dev/null || true
    export SPINNER_PID=""
    
    # Clear spinner line
    echo -ne "\r\033[K"
  fi
}

# === UPDATE SPINNER MESSAGE ===
update_spinner_message() {
  local new_message="$1"
  export SPINNER_MESSAGE="$new_message"
}

# === SPINNER WITH COMMAND ===
spinner_with_command() {
  local command="$1"
  local message="${2:-Executing command}"
  local style="${3:-classic}"
  local success_message="${4:-Command completed successfully}"
  local error_message="${5:-Command failed}"
  
  if [[ "${ENABLE_PROGRESS_BAR}" != "true" ]]; then
    eval "$command"
    return $?
  fi
  
  # Start spinner
  start_spinner "$message" "$style"
  
  # Execute command
  local output=""
  local exit_code=0
  
  if output=$(eval "$command" 2>&1); then
    stop_spinner
    echo -e "\r${COLOR_GREEN}✅ $success_message${COLOR_RESET}"
    return 0
  else
    exit_code=$?
    stop_spinner
    echo -e "\r${COLOR_RED}❌ $error_message${COLOR_RESET}"
    if [[ -n "$output" ]]; then
      echo -e "${COLOR_DIM}Output: $output${COLOR_RESET}"
    fi
    return $exit_code
  fi
}

# === MULTI-STAGE SPINNER ===
multi_stage_spinner() {
  local stages=("$@")
  
  if [[ "${ENABLE_PROGRESS_BAR}" != "true" ]]; then
    return 0
  fi
  
  local stage_count=${#stages[@]}
  local current_stage=1
  
  for stage in "${stages[@]}"; do
    IFS=':' read -r message duration style <<< "$stage"
    
    # Default values
    duration="${duration:-3}"
    style="${style:-classic}"
    
    # Update message with stage info
    local full_message="[$current_stage/$stage_count] $message"
    
    # Show spinner for this stage
    show_spinner "$full_message" "$style" "$duration"
    
    ((current_stage++))
  done
  
  echo -e "\r${COLOR_GREEN}✅ All stages completed${COLOR_RESET}"
}

# === PROGRESS SPINNER ===
progress_spinner() {
  local total="${1:-100}"
  local message="${2:-Progress}"
  local style="${3:-progress}"
  local interval="${4:-0.1}"
  
  if [[ "${ENABLE_PROGRESS_BAR}" != "true" ]]; then
    return 0
  fi
  
  local chars=$(get_spinner_chars "$style")
  local char_count=${#chars}
  
  for ((i=0; i<=total; i++)); do
    local percentage=$(( (i * 100) / total ))
    local char_index=$(( (i * char_count) / total ))
    local char="${chars:$char_index:1}"
    
    local color=""
    if [[ "${ENABLE_COLOR_OUTPUT}" == "true" ]]; then
      if [[ $percentage -ge 75 ]]; then
        color="$COLOR_GREEN"
      elif [[ $percentage -ge 50 ]]; then
        color="$COLOR_YELLOW"
      elif [[ $percentage -ge 25 ]]; then
        color="$COLOR_BLUE"
      else
        color="$COLOR_RED"
      fi
    fi
    
    if [[ "${ENABLE_EMOJI_LOGGING}" == "true" ]]; then
      echo -ne "\r📊 ${COLOR_BOLD}${COLOR_CYAN}$message${COLOR_RESET} ${color}${char}${COLOR_RESET} ${COLOR_BOLD}${percentage}%${COLOR_RESET}"
    else
      echo -ne "\r${COLOR_BOLD}${COLOR_CYAN}$message${COLOR_RESET} ${color}${char}${COLOR_RESET} ${COLOR_BOLD}${percentage}%${COLOR_RESET}"
    fi
    
    sleep "$interval"
  done
  
  echo ""
}

# === NETWORK SPINNER ===
network_spinner() {
  local target="${1:-google.com}"
  local message="${2:-Testing connectivity}"
  local timeout="${3:-10}"
  
  if [[ "${ENABLE_PROGRESS_BAR}" != "true" ]]; then
    ping -c 1 -W "$timeout" "$target" >/dev/null 2>&1
    return $?
  fi
  
  start_spinner "$message to $target" "earth"
  
  local result=0
  if ! ping -c 1 -W "$timeout" "$target" >/dev/null 2>&1; then
    result=1
  fi
  
  stop_spinner
  
  if [[ $result -eq 0 ]]; then
    echo -e "\r${COLOR_GREEN}✅ $target is reachable${COLOR_RESET}"
  else
    echo -e "\r${COLOR_RED}❌ $target is unreachable${COLOR_RESET}"
  fi
  
  return $result
}

# === DOWNLOAD SPINNER ===
download_spinner() {
  local url="$1"
  local output_file="$2"
  local message="${3:-Downloading}"
  
  if [[ "${ENABLE_PROGRESS_BAR}" != "true" ]]; then
    curl -L -o "$output_file" "$url"
    return $?
  fi
  
  start_spinner "$message $(basename "$output_file")" "arrow"
  
  local result=0
  if ! curl -L -o "$output_file" "$url" >/dev/null 2>&1; then
    result=1
  fi
  
  stop_spinner
  
  if [[ $result -eq 0 ]]; then
    local file_size=$(stat -c%s "$output_file" 2>/dev/null || echo "unknown")
    echo -e "\r${COLOR_GREEN}✅ Downloaded $(basename "$output_file") ($file_size bytes)${COLOR_RESET}"
  else
    echo -e "\r${COLOR_RED}❌ Download failed: $(basename "$output_file")${COLOR_RESET}"
  fi
  
  return $result
}

# === INSTALLATION SPINNER ===
installation_spinner() {
  local package="$1"
  local package_manager="${2:-apt}"
  local message="${3:-Installing}"
  
  if [[ "${ENABLE_PROGRESS_BAR}" != "true" ]]; then
    case "$package_manager" in
      "apt") sudo apt install -y "$package" ;;
      "yum") sudo yum install -y "$package" ;;
      "dnf") sudo dnf install -y "$package" ;;
      *) return 1 ;;
    esac
    return $?
  fi
  
  start_spinner "$message $package" "blocks"
  
  local result=0
  case "$package_manager" in
    "apt")
      if ! sudo apt install -y "$package" >/dev/null 2>&1; then
        result=1
      fi
      ;;
    "yum")
      if ! sudo yum install -y "$package" >/dev/null 2>&1; then
        result=1
      fi
      ;;
    "dnf")
      if ! sudo dnf install -y "$package" >/dev/null 2>&1; then
        result=1
      fi
      ;;
    *)
      result=1
      ;;
  esac
  
  stop_spinner
  
  if [[ $result -eq 0 ]]; then
    echo -e "\r${COLOR_GREEN}✅ $package installed successfully${COLOR_RESET}"
  else
    echo -e "\r${COLOR_RED}❌ Failed to install $package${COLOR_RESET}"
  fi
  
  return $result
}

# === SPINNER DEMO ===
spinner_demo() {
  echo -e "${COLOR_BOLD}${COLOR_CYAN}🎪 Spinner Demo${COLOR_RESET}"
  echo ""
  
  local spinner_styles=("classic" "dots" "line" "pipe" "star" "arrow" "clock" "moon" "fire" "water")
  
  for style in "${spinner_styles[@]}"; do
    echo -e "${COLOR_BOLD}$style spinner:${COLOR_RESET}"
    show_spinner "Demo $style" "$style" 2
    echo -e "\r${COLOR_GREEN}✅ $style demo completed${COLOR_RESET}"
    echo ""
  done
  
  echo -e "${COLOR_BOLD}Multi-stage spinner:${COLOR_RESET}"
  multi_stage_spinner \
    "Initializing:2:classic" \
    "Downloading:3:arrow" \
    "Processing:2:blocks" \
    "Finalizing:1:star"
  
  echo ""
  echo -e "${COLOR_BOLD}Progress spinner:${COLOR_RESET}"
  progress_spinner 20 "Processing data" "progress" 0.1
  
  echo ""
  echo -e "${COLOR_BRIGHT_GREEN}${COLOR_BOLD}🎉 Demo completed!${COLOR_RESET}"
}

# === SPINNER WITH TIMEOUT ===
spinner_with_timeout() {
  local command="$1"
  local timeout_seconds="$2"
  local message="${3:-Executing with timeout}"
  local style="${4:-classic}"
  
  if [[ "${ENABLE_PROGRESS_BAR}" != "true" ]]; then
    timeout "$timeout_seconds" bash -c "$command"
    return $?
  fi
  
  start_spinner "$message (timeout: ${timeout_seconds}s)" "$style"
  
  local result=0
  if ! timeout "$timeout_seconds" bash -c "$command" >/dev/null 2>&1; then
    result=$?
  fi
  
  stop_spinner
  
  case $result in
    0)
      echo -e "\r${COLOR_GREEN}✅ Command completed successfully${COLOR_RESET}"
      ;;
    124)
      echo -e "\r${COLOR_YELLOW}⏰ Command timed out after ${timeout_seconds}s${COLOR_RESET}"
      ;;
    *)
      echo -e "\r${COLOR_RED}❌ Command failed (exit code: $result)${COLOR_RESET}"
      ;;
  esac
  
  return $result
}

# === CLEANUP SPINNER ===
cleanup_spinner() {
  spinner_log_info "🧹 Cleaning up spinner..."
  
  # Stop any running spinner
  stop_spinner
  
  # Clear spinner variables
  export SPINNER_PID=""
  export SPINNER_ACTIVE=false
  export SPINNER_MESSAGE=""
  
  spinner_log_info "✅ Spinner cleanup completed"
}

# === VALIDATE SPINNER CONFIGURATION ===
validate_spinner_configuration() {
  spinner_log_info "🔍 Validating spinner configuration..."
  
  # Check spinner speed
  if [[ ! "$SPINNER_SPEED" =~ ^[0-9]*\.?[0-9]+$ ]]; then
    spinner_log_warn "⚠️ Invalid SPINNER_SPEED: $SPINNER_SPEED"
    return 1
  fi
  
  # Check if spinner speed is reasonable
  if [[ $(echo "$SPINNER_SPEED < 0.05" | bc -l 2>/dev/null || echo "0") -eq 1 ]] || \
     [[ $(echo "$SPINNER_SPEED > 2.0" | bc -l 2>/dev/null || echo "0") -eq 1 ]]; then
    spinner_log_warn "⚠️ SPINNER_SPEED out of reasonable range: $SPINNER_SPEED (0.05-2.0)"
  fi
  
  spinner_log_info "✅ Spinner configuration validated"
  return 0
}

# === GET SPINNER STATUS ===
get_spinner_status() {
  if [[ "$SPINNER_ACTIVE" == "true" && -n "$SPINNER_PID" ]]; then
    echo "ACTIVE: PID $SPINNER_PID, Message: $SPINNER_MESSAGE"
  else
    echo "INACTIVE"
  fi
}

# === LIST AVAILABLE SPINNER STYLES ===
list_spinner_styles() {
  echo "Available spinner styles:"
  for style in "${!SPINNER_SETS[@]}"; do
    local chars="${SPINNER_SETS[$style]}"
    echo "  $style: ${chars:0:5}..."
  done
}

# Trap to cleanup on exit
trap cleanup_spinner EXIT

# Initialize on load
initialize_spinner

# Export functions
export -f initialize_spinner
export -f show_spinner
export -f start_spinner
export -f stop_spinner
export -f update_spinner_message
export -f spinner_with_command
export -f multi_stage_spinner
export -f progress_spinner
export -f network_spinner
export -f download_spinner
export -f installation_spinner
export -f spinner_demo
export -f spinner_with_timeout
export -f cleanup_spinner
export -f validate_spinner_configuration
export -f get_spinner_status
export -f list_spinner_styles
export -f get_spinner_chars
