#!/bin/bash
set -euo pipefail

# ╔══════════════════════════════════════════════════════════════╗
# ║                    T3RN PROGRESS BAR COLOR                  ║
# ║                  (Colorful Progress Display)                ║
# ╚══════════════════════════════════════════════════════════════╝

# T3RN Executor Colorful Progress Bar
# Advanced colorful progress display with gradient effects and terminal detection
#
# @author Rokhanz
# @license MIT
# @version 1.0.0


# === INTERNAL ERROR HANDLING ===
color_progress_error_exit() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] COLOR_PROGRESS ERROR: $*" >&2
  exit 1
}

color_progress_log_info() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] COLOR_PROGRESS INFO: $*"
}

color_progress_log_warn() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] COLOR_PROGRESS WARN: $*"
}

# === INITIALIZE COLOR PROGRESS BAR ===
initialize_color_progress_bar() {
  if [[ -z "${SCRIPT_DIR:-}" ]]; then
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")"/.. && pwd)"
    export SCRIPT_DIR
  fi
  
  # Load .env for color configuration
  if [[ -f "$SCRIPT_DIR/.env" ]]; then
    source "$SCRIPT_DIR/.env" 2>/dev/null || true
  fi
  
  # Color configuration
  ENABLE_COLOR_OUTPUT="${ENABLE_COLOR_OUTPUT:-true}"
  ENABLE_EMOJI_LOGGING="${ENABLE_EMOJI_LOGGING:-true}"
  PROGRESS_BAR_WIDTH="${PROGRESS_BAR_WIDTH:-50}"
  
  # Detect terminal capabilities
  detect_terminal_capabilities
  
  # Initialize color codes
  initialize_color_codes
}

# === DETECT TERMINAL CAPABILITIES ===
detect_terminal_capabilities() {
  export TERMINAL_SUPPORTS_COLOR=false
  export TERMINAL_SUPPORTS_256_COLOR=false
  export TERMINAL_SUPPORTS_TRUE_COLOR=false
  export TERMINAL_WIDTH=$(tput cols 2>/dev/null || echo "80")
  
  # Check if stdout is a terminal
  if [[ -t 1 ]]; then
    # Check basic color support
    if command -v tput >/dev/null 2>&1; then
      local colors=$(tput colors 2>/dev/null || echo "0")
      if [[ $colors -ge 8 ]]; then
        TERMINAL_SUPPORTS_COLOR=true
      fi
      if [[ $colors -ge 256 ]]; then
        TERMINAL_SUPPORTS_256_COLOR=true
      fi
    fi
    
    # Check true color support
    if [[ -n "${COLORTERM:-}" ]] && [[ "$COLORTERM" =~ (truecolor|24bit) ]]; then
      TERMINAL_SUPPORTS_TRUE_COLOR=true
    fi
  fi
  
  # Override if color is disabled
  if [[ "${ENABLE_COLOR_OUTPUT}" != "true" ]]; then
    TERMINAL_SUPPORTS_COLOR=false
    TERMINAL_SUPPORTS_256_COLOR=false
    TERMINAL_SUPPORTS_TRUE_COLOR=false
  fi
}

# === INITIALIZE COLOR CODES ===
initialize_color_codes() {
  if [[ "$TERMINAL_SUPPORTS_COLOR" == "true" ]]; then
    # Basic 16 colors
    export COLOR_BLACK="\033[30m"
    export COLOR_RED="\033[31m"
    export COLOR_GREEN="\033[32m"
    export COLOR_YELLOW="\033[33m"
    export COLOR_BLUE="\033[34m"
    export COLOR_MAGENTA="\033[35m"
    export COLOR_CYAN="\033[36m"
    export COLOR_WHITE="\033[37m"
    
    # Bright colors
    export COLOR_BRIGHT_BLACK="\033[90m"
    export COLOR_BRIGHT_RED="\033[91m"
    export COLOR_BRIGHT_GREEN="\033[92m"
    export COLOR_BRIGHT_YELLOW="\033[93m"
    export COLOR_BRIGHT_BLUE="\033[94m"
    export COLOR_BRIGHT_MAGENTA="\033[95m"
    export COLOR_BRIGHT_CYAN="\033[96m"
    export COLOR_BRIGHT_WHITE="\033[97m"
    
    # Background colors
    export COLOR_BG_BLACK="\033[40m"
    export COLOR_BG_RED="\033[41m"
    export COLOR_BG_GREEN="\033[42m"
    export COLOR_BG_YELLOW="\033[43m"
    export COLOR_BG_BLUE="\033[44m"
    export COLOR_BG_MAGENTA="\033[45m"
    export COLOR_BG_CYAN="\033[46m"
    export COLOR_BG_WHITE="\033[47m"
    
    # Text formatting
    export COLOR_BOLD="\033[1m"
    export COLOR_DIM="\033[2m"
    export COLOR_ITALIC="\033[3m"
    export COLOR_UNDERLINE="\033[4m"
    export COLOR_BLINK="\033[5m"
    export COLOR_REVERSE="\033[7m"
    export COLOR_STRIKETHROUGH="\033[9m"
    
    # Reset
    export COLOR_RESET="\033[0m"
  else
    # No color support - empty variables
    export COLOR_BLACK=""
    export COLOR_RED=""
    export COLOR_GREEN=""
    export COLOR_YELLOW=""
    export COLOR_BLUE=""
    export COLOR_MAGENTA=""
    export COLOR_CYAN=""
    export COLOR_WHITE=""
    export COLOR_BRIGHT_BLACK=""
    export COLOR_BRIGHT_RED=""
    export COLOR_BRIGHT_GREEN=""
    export COLOR_BRIGHT_YELLOW=""
    export COLOR_BRIGHT_BLUE=""
    export COLOR_BRIGHT_MAGENTA=""
    export COLOR_BRIGHT_CYAN=""
    export COLOR_BRIGHT_WHITE=""
    export COLOR_BG_BLACK=""
    export COLOR_BG_RED=""
    export COLOR_BG_GREEN=""
    export COLOR_BG_YELLOW=""
    export COLOR_BG_BLUE=""
    export COLOR_BG_MAGENTA=""
    export COLOR_BG_CYAN=""
    export COLOR_BG_WHITE=""
    export COLOR_BOLD=""
    export COLOR_DIM=""
    export COLOR_ITALIC=""
    export COLOR_UNDERLINE=""
    export COLOR_BLINK=""
    export COLOR_REVERSE=""
    export COLOR_STRIKETHROUGH=""
    export COLOR_RESET=""
  fi
}

# === 256 COLOR FUNCTION ===
color_256() {
  local color_code="$1"
  if [[ "$TERMINAL_SUPPORTS_256_COLOR" == "true" ]]; then
    echo "\033[38;5;${color_code}m"
  else
    echo ""
  fi
}

# === RGB COLOR FUNCTION ===
color_rgb() {
  local r="$1"
  local g="$2"
  local b="$3"
  if [[ "$TERMINAL_SUPPORTS_TRUE_COLOR" == "true" ]]; then
    echo "\033[38;2;${r};${g};${b}m"
  else
    echo ""
  fi
}

# === GRADIENT COLOR GENERATOR ===
generate_gradient_color() {
  local percentage="$1"
  local start_color="${2:-red}"
  local end_color="${3:-green}"
  
  if [[ "$TERMINAL_SUPPORTS_TRUE_COLOR" != "true" ]]; then
    # Fallback to basic colors
    if [[ $percentage -lt 25 ]]; then
      echo "$COLOR_RED"
    elif [[ $percentage -lt 50 ]]; then
      echo "$COLOR_YELLOW"
    elif [[ $percentage -lt 75 ]]; then
      echo "$COLOR_CYAN"
    else
      echo "$COLOR_GREEN"
    fi
    return
  fi
  
  # RGB values for common colors
  local -A rgb_colors=(
    ["red"]="255,0,0"
    ["green"]="0,255,0"
    ["blue"]="0,0,255"
    ["yellow"]="255,255,0"
    ["cyan"]="0,255,255"
    ["magenta"]="255,0,255"
    ["orange"]="255,165,0"
    ["purple"]="128,0,128"
  )
  
  local start_rgb="${rgb_colors[$start_color]:-255,0,0}"
  local end_rgb="${rgb_colors[$end_color]:-0,255,0}"
  
  IFS=',' read -r start_r start_g start_b <<< "$start_rgb"
  IFS=',' read -r end_r end_g end_b <<< "$end_rgb"
  
  # Calculate interpolated color
  local factor=$(echo "scale=2; $percentage / 100" | bc -l 2>/dev/null || echo "0.5")
  local r=$(echo "scale=0; $start_r + ($end_r - $start_r) * $factor" | bc -l 2>/dev/null || echo "$start_r")
  local g=$(echo "scale=0; $start_g + ($end_g - $start_g) * $factor" | bc -l 2>/dev/null || echo "$start_g")
  local b=$(echo "scale=0; $start_b + ($end_b - $start_b) * $factor" | bc -l 2>/dev/null || echo "$start_b")
  
  color_rgb "$r" "$g" "$b"
}

# === COLORFUL PROGRESS BAR ===
draw_colorful_progress_bar() {
  local current="$1"
  local total="$2"
  local label="${3:-Progress}"
  local width="${4:-$PROGRESS_BAR_WIDTH}"
  local style="${5:-gradient}"
  
  local percentage=$(( (current * 100) / total ))
  local filled_width=$(( (current * width) / total ))
  local empty_width=$((width - filled_width))
  
  # Choose colors based on style
  case "$style" in
    "gradient")
      local bar_color=$(generate_gradient_color "$percentage" "red" "green")
      ;;
    "rainbow")
      local bar_color=$(color_256 $((196 + (percentage * 60 / 100))))
      ;;
    "ocean")
      local bar_color=$(generate_gradient_color "$percentage" "blue" "cyan")
      ;;
    "fire")
      local bar_color=$(generate_gradient_color "$percentage" "red" "yellow")
      ;;
    "forest")
      local bar_color=$(generate_gradient_color "$percentage" "green" "cyan")
      ;;
    "sunset")
      local bar_color=$(generate_gradient_color "$percentage" "orange" "magenta")
      ;;
    *)
      local bar_color="$COLOR_GREEN"
      ;;
  esac
  
  # Build progress bar
  local progress_bar=""
  local filled_char="█"
  local empty_char="░"
  
  # Add filled portion with color
  for ((i=0; i<filled_width; i++)); do
    progress_bar+="${bar_color}${filled_char}${COLOR_RESET}"
  done
  
  # Add empty portion
  for ((i=0; i<empty_width; i++)); do
    progress_bar+="${COLOR_DIM}${empty_char}${COLOR_RESET}"
  done
  
  # Format output with emojis and colors
  local emoji=""
  local status_color=""
  
  if [[ "${ENABLE_EMOJI_LOGGING}" == "true" ]]; then
    if [[ $percentage -eq 100 ]]; then
      emoji="✅ "
      status_color="$COLOR_BRIGHT_GREEN"
    elif [[ $percentage -ge 75 ]]; then
      emoji="🔥 "
      status_color="$COLOR_BRIGHT_CYAN"
    elif [[ $percentage -ge 50 ]]; then
      emoji="⚡ "
      status_color="$COLOR_BRIGHT_YELLOW"
    elif [[ $percentage -ge 25 ]]; then
      emoji="🔄 "
      status_color="$COLOR_BRIGHT_BLUE"
    else
      emoji="🚀 "
      status_color="$COLOR_BRIGHT_MAGENTA"
    fi
  fi
  
  echo -ne "\r${emoji}${COLOR_BOLD}${COLOR_CYAN}$label:${COLOR_RESET} [${progress_bar}] ${status_color}${COLOR_BOLD}${percentage}%${COLOR_RESET} ${COLOR_DIM}(${current}/${total})${COLOR_RESET}"
}

# === ANIMATED PROGRESS BAR ===
animated_progress_bar() {
  local total="${1:-100}"
  local label="${2:-Processing}"
  local style="${3:-gradient}"
  local speed="${4:-0.1}"
  
  for ((i=0; i<=total; i++)); do
    draw_colorful_progress_bar "$i" "$total" "$label" "$PROGRESS_BAR_WIDTH" "$style"
    sleep "$speed"
  done
  echo ""
}

# === PULSING PROGRESS BAR ===
pulsing_progress_bar() {
  local label="${1:-Loading}"
  local duration="${2:-5}"
  local style="${3:-rainbow}"
  
  local start_time=$(date +%s)
  local pulse_chars=("▁" "▂" "▃" "▄" "▅" "▆" "▇" "█" "▇" "▆" "▅" "▄" "▃" "▂")
  local char_index=0
  
  while [[ $(($(date +%s) - start_time)) -lt $duration ]]; do
    local char="${pulse_chars[$((char_index % ${#pulse_chars[@]}))]}"
    local color=""
    
    case "$style" in
      "rainbow")
        color=$(color_256 $((196 + (char_index * 10) % 60)))
        ;;
      "ocean")
        color=$(color_256 $((21 + (char_index * 5) % 20)))
        ;;
      "fire")
        color=$(color_256 $((196 + (char_index * 3) % 15)))
        ;;
      *)
        color="$COLOR_CYAN"
        ;;
    esac
    
    if [[ "${ENABLE_EMOJI_LOGGING}" == "true" ]]; then
      echo -ne "\r🌊 ${COLOR_BOLD}${COLOR_CYAN}$label${COLOR_RESET} ${color}${char}${char}${char}${COLOR_RESET}"
    else
      echo -ne "\r${COLOR_BOLD}${COLOR_CYAN}$label${COLOR_RESET} ${color}${char}${char}${char}${COLOR_RESET}"
    fi
    
    sleep 0.1
    ((char_index++))
  done
  echo ""
}

# === SPINNING WHEEL PROGRESS ===
spinning_wheel_progress() {
  local label="${1:-Working}"
  local duration="${2:-5}"
  local style="${3:-colorful}"
  
  local start_time=$(date +%s)
  local spin_chars=("⠋" "⠙" "⠹" "⠸" "⠼" "⠴" "⠦" "⠧" "⠇" "⠏")
  local char_index=0
  
  while [[ $(($(date +%s) - start_time)) -lt $duration ]]; do
    local char="${spin_chars[$((char_index % ${#spin_chars[@]}))]}"
    local color=""
    
    case "$style" in
      "colorful")
        local colors=("$COLOR_RED" "$COLOR_GREEN" "$COLOR_YELLOW" "$COLOR_BLUE" "$COLOR_MAGENTA" "$COLOR_CYAN")
        color="${colors[$((char_index % ${#colors[@]}))]}"
        ;;
      "gradient")
        color=$(generate_gradient_color $((char_index * 10 % 100)) "blue" "magenta")
        ;;
      *)
        color="$COLOR_CYAN"
        ;;
    esac
    
    if [[ "${ENABLE_EMOJI_LOGGING}" == "true" ]]; then
      echo -ne "\r⚙️ ${COLOR_BOLD}${COLOR_CYAN}$label${COLOR_RESET} ${color}${char}${COLOR_RESET}"
    else
      echo -ne "\r${COLOR_BOLD}${COLOR_CYAN}$label${COLOR_RESET} ${color}${char}${COLOR_RESET}"
    fi
    
    sleep 0.1
    ((char_index++))
  done
  echo ""
}

# === MULTI-COLOR STEP PROGRESS ===
multi_color_step_progress() {
  local steps=("$@")
  local total_steps=${#steps[@]}
  local current_step=0
  
  local step_colors=("$COLOR_RED" "$COLOR_YELLOW" "$COLOR_BLUE" "$COLOR_MAGENTA" "$COLOR_CYAN" "$COLOR_GREEN")
  
  for step in "${steps[@]}"; do
    ((current_step++))
    local color="${step_colors[$((current_step % ${#step_colors[@]}))]}"
    local percentage=$(( (current_step * 100) / total_steps ))
    
    echo -e "${color}${COLOR_BOLD}Step $current_step/$total_steps:${COLOR_RESET} $step"
    draw_colorful_progress_bar "$current_step" "$total_steps" "Overall Progress" "$PROGRESS_BAR_WIDTH" "gradient"
    echo ""
    sleep 0.5
  done
  
  echo -e "${COLOR_BRIGHT_GREEN}${COLOR_BOLD}✅ All steps completed!${COLOR_RESET}"
}

# === DOWNLOAD PROGRESS WITH COLORS ===
colorful_download_progress() {
  local url="$1"
  local output_file="$2"
  local label="${3:-Downloading}"
  
  # Create a temporary file for curl progress
  local progress_file="/tmp/curl_progress_$$"
  
  # Start download with progress
  curl -L -o "$output_file" "$url" \
    --progress-bar 2>&1 | {
    while IFS= read -r line; do
      if [[ "$line" =~ ([0-9]+)% ]]; then
        local percent="${BASH_REMATCH[1]}"
        draw_colorful_progress_bar "$percent" "100" "$label" "$PROGRESS_BAR_WIDTH" "ocean"
      fi
    done
    echo ""
  }
  
  rm -f "$progress_file"
}

# === NETWORK TEST WITH COLORS ===
colorful_network_test() {
  local targets=("$@")
  local total_targets=${#targets[@]}
  local current_target=0
  
  echo -e "${COLOR_BOLD}${COLOR_CYAN}🌐 Network Connectivity Test${COLOR_RESET}"
  echo ""
  
  for target in "${targets[@]}"; do
    ((current_target++))
    
    echo -ne "${COLOR_BOLD}Testing $target...${COLOR_RESET} "
    
    if ping -c 1 -W 3 "$target" >/dev/null 2>&1; then
      echo -e "${COLOR_BRIGHT_GREEN}✅ ONLINE${COLOR_RESET}"
    else
      echo -e "${COLOR_BRIGHT_RED}❌ OFFLINE${COLOR_RESET}"
    fi
    
    draw_colorful_progress_bar "$current_target" "$total_targets" "Network Test Progress" "$PROGRESS_BAR_WIDTH" "forest"
    echo ""
  done
  
  echo -e "${COLOR_BRIGHT_GREEN}${COLOR_BOLD}🌐 Network test completed!${COLOR_RESET}"
}

# === COLOR DEMO ===
color_progress_demo() {
  echo -e "${COLOR_BOLD}${COLOR_CYAN}🎨 Colorful Progress Bar Demo${COLOR_RESET}"
  echo -e "${COLOR_DIM}Terminal capabilities: Color: $TERMINAL_SUPPORTS_COLOR, 256: $TERMINAL_SUPPORTS_256_COLOR, True: $TERMINAL_SUPPORTS_TRUE_COLOR${COLOR_RESET}"
  echo ""
  
  echo -e "${COLOR_BOLD}1. Gradient Progress (Red to Green):${COLOR_RESET}"
  animated_progress_bar 20 "Gradient Demo" "gradient" 0.1
  
  echo ""
  echo -e "${COLOR_BOLD}2. Rainbow Progress:${COLOR_RESET}"
  animated_progress_bar 15 "Rainbow Demo" "rainbow" 0.1
  
  echo ""
  echo -e "${COLOR_BOLD}3. Ocean Theme:${COLOR_RESET}"
  animated_progress_bar 12 "Ocean Demo" "ocean" 0.15
  
  echo ""
  echo -e "${COLOR_BOLD}4. Fire Theme:${COLOR_RESET}"
  animated_progress_bar 10 "Fire Demo" "fire" 0.2
  
  echo ""
  echo -e "${COLOR_BOLD}5. Pulsing Animation (3 seconds):${COLOR_RESET}"
  pulsing_progress_bar "Pulsing Demo" 3 "rainbow"
  
  echo ""
  echo -e "${COLOR_BOLD}6. Spinning Wheel (3 seconds):${COLOR_RESET}"
  spinning_wheel_progress "Spinning Demo" 3 "colorful"
  
  echo ""
  echo -e "${COLOR_BOLD}7. Multi-Step Progress:${COLOR_RESET}"
  multi_color_step_progress "Initialize" "Download" "Extract" "Configure" "Complete"
  
  echo ""
  echo -e "${COLOR_BRIGHT_GREEN}${COLOR_BOLD}✨ Demo completed!${COLOR_RESET}"
}

# === VALIDATE COLOR CONFIGURATION ===
validate_color_configuration() {
  color_progress_log_info "🔍 Validating color configuration..."
  
  # Check terminal capabilities
  if [[ "$TERMINAL_SUPPORTS_COLOR" != "true" ]] && [[ "${ENABLE_COLOR_OUTPUT}" == "true" ]]; then
    color_progress_log_warn "⚠️ Color output enabled but terminal doesn't support colors"
  fi
  
  # Check progress bar width
  if [[ ! "$PROGRESS_BAR_WIDTH" =~ ^[0-9]+$ ]] || [[ $PROGRESS_BAR_WIDTH -lt 10 ]] || [[ $PROGRESS_BAR_WIDTH -gt 100 ]]; then
    color_progress_log_warn "⚠️ Invalid progress bar width: $PROGRESS_BAR_WIDTH"
    return 1
  fi
  
  color_progress_log_info "✅ Color configuration validated"
  return 0
}

# === GET COLOR CAPABILITIES ===
get_color_capabilities() {
  echo "Terminal Color Capabilities:"
  echo "  Basic Color: $TERMINAL_SUPPORTS_COLOR"
  echo "  256 Color: $TERMINAL_SUPPORTS_256_COLOR"
  echo "  True Color: $TERMINAL_SUPPORTS_TRUE_COLOR"
  echo "  Terminal Width: $TERMINAL_WIDTH"
  echo "  Color Output Enabled: ${ENABLE_COLOR_OUTPUT}"
}

# Initialize on load
initialize_color_progress_bar

# Export functions
export -f initialize_color_progress_bar
export -f detect_terminal_capabilities
export -f initialize_color_codes
export -f color_256
export -f color_rgb
export -f generate_gradient_color
export -f draw_colorful_progress_bar
export -f animated_progress_bar
export -f pulsing_progress_bar
export -f spinning_wheel_progress
export -f multi_color_step_progress
export -f colorful_download_progress
export -f colorful_network_test
export -f color_progress_demo
export -f validate_color_configuration
export -f get_color_capabilities
