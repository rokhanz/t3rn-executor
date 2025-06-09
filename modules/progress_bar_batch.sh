#!/bin/bash
set -euo pipefail

# ╔══════════════════════════════════════════════════════════════╗
# ║                    T3RN PROGRESS BAR BATCH                  ║
# ║                  (Batch Progress Display)                   ║
# ╚══════════════════════════════════════════════════════════════╝

# T3RN Executor Batch Progress Bar
# Advanced batch progress display with multiple styles and animations
#
# @author Rokhanz
# @license MIT
# @version 1.0.0

# === INTERNAL ERROR HANDLING ===
progress_error_exit() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] PROGRESS ERROR: $*" >&2
  exit 1
}

progress_log_info() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] PROGRESS INFO: $*"
}

progress_log_warn() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] PROGRESS WARN: $*"
}

# === INITIALIZE PROGRESS BAR ===
initialize_progress_bar() {
  if [[ -z "${SCRIPT_DIR:-}" ]]; then
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")"/.. && pwd)"
    export SCRIPT_DIR
  fi
  
  # Load .env for progress bar configuration
  if [[ -f "$SCRIPT_DIR/.env" ]]; then
    source "$SCRIPT_DIR/.env" 2>/dev/null || true
  fi
  
  # Progress bar configuration
  PROGRESS_BAR_WIDTH="${PROGRESS_BAR_WIDTH:-50}"
  PROGRESS_BAR_STYLE="${PROGRESS_BAR_STYLE:-batch}"
  ENABLE_PROGRESS_BAR="${ENABLE_PROGRESS_BAR:-true}"
  ENABLE_COLOR_OUTPUT="${ENABLE_COLOR_OUTPUT:-true}"
  ENABLE_EMOJI_LOGGING="${ENABLE_EMOJI_LOGGING:-true}"
  
  # Colors for progress bar
  if [[ "${ENABLE_COLOR_OUTPUT}" == "true" ]]; then
    export PROGRESS_COLOR_GREEN="\033[32m"
    export PROGRESS_COLOR_BLUE="\033[34m"
    export PROGRESS_COLOR_YELLOW="\033[33m"
    export PROGRESS_COLOR_RED="\033[31m"
    export PROGRESS_COLOR_CYAN="\033[36m"
    export PROGRESS_COLOR_RESET="\033[0m"
  else
    export PROGRESS_COLOR_GREEN=""
    export PROGRESS_COLOR_BLUE=""
    export PROGRESS_COLOR_YELLOW=""
    export PROGRESS_COLOR_RED=""
    export PROGRESS_COLOR_CYAN=""
    export PROGRESS_COLOR_RESET=""
  fi
}

# === PROGRESS BAR CHARACTERS ===
declare -A PROGRESS_CHARS=(
  ["simple"]="█ "
  ["batch"]="▓▒░"
  ["detailed"]="█▉▊▋▌▍▎▏ "
  ["blocks"]="█▇▆▅▄▃▂▁ "
  ["dots"]="⣿⣾⣽⣻⢿⡿⣟⣯⣷"
  ["arrows"]="▶▷▸▹►▻"
)

# === GET PROGRESS CHARACTER ===
get_progress_char() {
  local style="${1:-batch}"
  local position="${2:-0}"
  
  local chars="${PROGRESS_CHARS[$style]:-${PROGRESS_CHARS[batch]}}"
  local char_count=${#chars}
  
  if [[ $char_count -gt 0 ]]; then
    local char_index=$((position % char_count))
    echo "${chars:$char_index:1}"
  else
    echo "█"
  fi
}

# === CALCULATE PROGRESS PERCENTAGE ===
calculate_percentage() {
  local current="$1"
  local total="$2"
  
  if [[ $total -eq 0 ]]; then
    echo "0"
  else
    echo $(( (current * 100) / total ))
  fi
}

# === DRAW PROGRESS BAR ===
draw_progress_bar() {
  local current="$1"
  local total="$2"
  local label="${3:-Progress}"
  local width="${4:-$PROGRESS_BAR_WIDTH}"
  local style="${5:-$PROGRESS_BAR_STYLE}"
  
  local percentage=$(calculate_percentage "$current" "$total")
  local filled_width=$(( (current * width) / total ))
  local empty_width=$((width - filled_width))
  
  # Build progress bar
  local progress_bar=""
  local filled_char=$(get_progress_char "$style" 0)
  local empty_char=" "
  
  # Add filled portion
  for ((i=0; i<filled_width; i++)); do
    progress_bar+="$filled_char"
  done
  
  # Add empty portion
  for ((i=0; i<empty_width; i++)); do
    progress_bar+="$empty_char"
  done
  
  # Format output based on style
  case "$style" in
    "simple")
      echo -ne "\r${PROGRESS_COLOR_CYAN}$label:${PROGRESS_COLOR_RESET} [${PROGRESS_COLOR_GREEN}$progress_bar${PROGRESS_COLOR_RESET}] ${percentage}%"
      ;;
    "batch")
      local emoji=""
      if [[ "${ENABLE_EMOJI_LOGGING}" == "true" ]]; then
        if [[ $percentage -eq 100 ]]; then
          emoji="✅ "
        elif [[ $percentage -ge 75 ]]; then
          emoji="🔄 "
        elif [[ $percentage -ge 50 ]]; then
          emoji="⏳ "
        elif [[ $percentage -ge 25 ]]; then
          emoji="🔍 "
        else
          emoji="🚀 "
        fi
      fi
      echo -ne "\r${emoji}${PROGRESS_COLOR_BLUE}$label:${PROGRESS_COLOR_RESET} [${PROGRESS_COLOR_GREEN}$progress_bar${PROGRESS_COLOR_RESET}] ${PROGRESS_COLOR_YELLOW}${percentage}%${PROGRESS_COLOR_RESET} (${current}/${total})"
      ;;
    "detailed")
      local time_info=""
      if [[ -n "${PROGRESS_START_TIME:-}" ]]; then
        local elapsed=$(($(date +%s) - PROGRESS_START_TIME))
        local eta=""
        if [[ $current -gt 0 && $current -lt $total ]]; then
          local remaining=$((total - current))
          local rate=$((current / (elapsed + 1)))
          if [[ $rate -gt 0 ]]; then
            eta=" ETA: $((remaining / rate))s"
          fi
        fi
        time_info=" Elapsed: ${elapsed}s$eta"
      fi
      echo -ne "\r${PROGRESS_COLOR_CYAN}$label:${PROGRESS_COLOR_RESET} [${PROGRESS_COLOR_GREEN}$progress_bar${PROGRESS_COLOR_RESET}] ${PROGRESS_COLOR_YELLOW}${percentage}%${PROGRESS_COLOR_RESET} (${current}/${total})$time_info"
      ;;
    *)
      echo -ne "\r$label: [$progress_bar] ${percentage}% (${current}/${total})"
      ;;
  esac
}

# === SHOW PROGRESS BAR ===
show_progress_bar() {
  local label="${1:-Processing}"
  local total="${2:-100}"
  local style="${3:-$PROGRESS_BAR_STYLE}"
  local interval="${4:-0.1}"
  
  if [[ "${ENABLE_PROGRESS_BAR}" != "true" ]]; then
    return 0
  fi
  
  export PROGRESS_START_TIME=$(date +%s)
  local current=0
  
  while [[ $current -le $total ]]; do
    draw_progress_bar "$current" "$total" "$label" "$PROGRESS_BAR_WIDTH" "$style"
    
    if [[ $current -eq $total ]]; then
      break
    fi
    
    sleep "$interval"
    ((current++))
  done
  
  echo ""  # New line after completion
}

# === SHOW INDETERMINATE PROGRESS ===
show_indeterminate_progress() {
  local label="${1:-Loading}"
  local style="${2:-dots}"
  local interval="${3:-0.2}"
  
  if [[ "${ENABLE_PROGRESS_BAR}" != "true" ]]; then
    return 0
  fi
  
  local chars="${PROGRESS_CHARS[$style]:-${PROGRESS_CHARS[dots]}}"
  local char_count=${#chars}
  local position=0
  
  while true; do
    local char="${chars:$((position % char_count)):1}"
    
    if [[ "${ENABLE_EMOJI_LOGGING}" == "true" ]]; then
      echo -ne "\r🔄 ${PROGRESS_COLOR_CYAN}$label${PROGRESS_COLOR_RESET} $char"
    else
      echo -ne "\r${PROGRESS_COLOR_CYAN}$label${PROGRESS_COLOR_RESET} $char"
    fi
    
    sleep "$interval"
    ((position++))
  done
}

# === BATCH PROGRESS TRACKER ===
batch_progress_tracker() {
  local total_items="$1"
  local label="${2:-Processing items}"
  local style="${3:-batch}"
  
  if [[ "${ENABLE_PROGRESS_BAR}" != "true" ]]; then
    return 0
  fi
  
  export BATCH_TOTAL="$total_items"
  export BATCH_CURRENT=0
  export BATCH_LABEL="$label"
  export BATCH_STYLE="$style"
  export PROGRESS_START_TIME=$(date +%s)
  
  # Create named pipe for progress updates
  local progress_pipe="/tmp/batch_progress_$$"
  mkfifo "$progress_pipe" 2>/dev/null || true
  export BATCH_PROGRESS_PIPE="$progress_pipe"
  
  # Start progress display in background
  {
    while true; do
      if read -r update < "$progress_pipe"; then
        case "$update" in
          "increment")
            ((BATCH_CURRENT++))
            draw_progress_bar "$BATCH_CURRENT" "$BATCH_TOTAL" "$BATCH_LABEL" "$PROGRESS_BAR_WIDTH" "$BATCH_STYLE"
            ;;
          "complete")
            draw_progress_bar "$BATCH_TOTAL" "$BATCH_TOTAL" "$BATCH_LABEL" "$PROGRESS_BAR_WIDTH" "$BATCH_STYLE"
            echo ""
            break
            ;;
          "abort")
            echo -ne "\r${PROGRESS_COLOR_RED}$BATCH_LABEL: ABORTED${PROGRESS_COLOR_RESET}"
            echo ""
            break
            ;;
        esac
      fi
    done
    
    # Cleanup
    rm -f "$progress_pipe"
  } &
  
  export BATCH_PROGRESS_PID=$!
}

# === UPDATE BATCH PROGRESS ===
update_batch_progress() {
  local action="${1:-increment}"
  
  if [[ -n "${BATCH_PROGRESS_PIPE:-}" && -p "${BATCH_PROGRESS_PIPE}" ]]; then
    echo "$action" > "${BATCH_PROGRESS_PIPE}"
  fi
}

# === COMPLETE BATCH PROGRESS ===
complete_batch_progress() {
  update_batch_progress "complete"
  
  # Wait for progress display to finish
  if [[ -n "${BATCH_PROGRESS_PID:-}" ]]; then
    wait "${BATCH_PROGRESS_PID}" 2>/dev/null || true
  fi
  
  # Cleanup
  unset BATCH_TOTAL BATCH_CURRENT BATCH_LABEL BATCH_STYLE BATCH_PROGRESS_PIPE BATCH_PROGRESS_PID
}

# === ABORT BATCH PROGRESS ===
abort_batch_progress() {
  update_batch_progress "abort"
  
  # Wait for progress display to finish
  if [[ -n "${BATCH_PROGRESS_PID:-}" ]]; then
    wait "${BATCH_PROGRESS_PID}" 2>/dev/null || true
  fi
  
  # Cleanup
  unset BATCH_TOTAL BATCH_CURRENT BATCH_LABEL BATCH_STYLE BATCH_PROGRESS_PIPE BATCH_PROGRESS_PID
}

# === DOWNLOAD PROGRESS BAR ===
download_progress_bar() {
  local url="$1"
  local output_file="$2"
  local label="${3:-Downloading}"
  
  if [[ "${ENABLE_PROGRESS_BAR}" != "true" ]]; then
    curl -L -o "$output_file" "$url"
    return $?
  fi
  
  # Download with progress
  curl -L --progress-bar -o "$output_file" "$url" 2>&1 | {
    local last_percent=0
    while IFS= read -r line; do
      if [[ "$line" =~ ([0-9]+)% ]]; then
        local percent="${BASH_REMATCH[1]}"
        if [[ $percent -ne $last_percent ]]; then
          draw_progress_bar "$percent" "100" "$label" "$PROGRESS_BAR_WIDTH" "batch"
          last_percent=$percent
        fi
      fi
    done
    echo ""
  }
}

# === FILE OPERATION PROGRESS ===
file_operation_progress() {
  local operation="$1"
  local source="$2"
  local destination="$3"
  local label="${4:-File operation}"
  
  if [[ "${ENABLE_PROGRESS_BAR}" != "true" ]]; then
    case "$operation" in
      "copy") cp "$source" "$destination" ;;
      "move") mv "$source" "$destination" ;;
      "extract") tar -xf "$source" -C "$destination" ;;
    esac
    return $?
  fi
  
  # Get source size for progress calculation
  local source_size=0
  if [[ -f "$source" ]]; then
    source_size=$(stat -c%s "$source" 2>/dev/null || echo "0")
  fi
  
  case "$operation" in
    "copy")
      # Use rsync with progress if available
      if command -v rsync >/dev/null 2>&1; then
        rsync --progress "$source" "$destination" 2>&1 | {
          while IFS= read -r line; do
            if [[ "$line" =~ ([0-9]+)% ]]; then
              local percent="${BASH_REMATCH[1]}"
              draw_progress_bar "$percent" "100" "$label" "$PROGRESS_BAR_WIDTH" "batch"
            fi
          done
          echo ""
        }
      else
        # Fallback to cp with simulated progress
        show_indeterminate_progress "$label" "dots" 0.1 &
        local progress_pid=$!
        cp "$source" "$destination"
        local result=$?
        kill $progress_pid 2>/dev/null || true
        echo ""
        return $result
      fi
      ;;
    "move")
      show_indeterminate_progress "$label" "arrows" 0.1 &
      local progress_pid=$!
      mv "$source" "$destination"
      local result=$?
      kill $progress_pid 2>/dev/null || true
      echo ""
      return $result
      ;;
    "extract")
      # Extract with progress
      if command -v pv >/dev/null 2>&1 && [[ $source_size -gt 0 ]]; then
        pv "$source" | tar -xf - -C "$destination"
      else
        show_indeterminate_progress "$label" "blocks" 0.2 &
        local progress_pid=$!
        tar -xf "$source" -C "$destination"
        local result=$?
        kill $progress_pid 2>/dev/null || true
        echo ""
        return $result
      fi
      ;;
  esac
}

# === NETWORK OPERATION PROGRESS ===
network_operation_progress() {
  local operation="$1"
  local target="$2"
  local label="${3:-Network operation}"
  local timeout="${4:-30}"
  
  if [[ "${ENABLE_PROGRESS_BAR}" != "true" ]]; then
    case "$operation" in
      "ping") ping -c 1 -W "$timeout" "$target" >/dev/null 2>&1 ;;
      "wget") wget -q --timeout="$timeout" "$target" ;;
      "curl") curl -s --max-time "$timeout" "$target" >/dev/null ;;
    esac
    return $?
  fi
  
  # Show progress during network operation
  show_indeterminate_progress "$label" "dots" 0.3 &
  local progress_pid=$!
  
  local result=0
  case "$operation" in
    "ping")
      ping -c 1 -W "$timeout" "$target" >/dev/null 2>&1 || result=$?
      ;;
    "wget")
      wget -q --timeout="$timeout" "$target" || result=$?
      ;;
    "curl")
      curl -s --max-time "$timeout" "$target" >/dev/null || result=$?
      ;;
  esac
  
  kill $progress_pid 2>/dev/null || true
  wait $progress_pid 2>/dev/null || true
  
  if [[ $result -eq 0 ]]; then
    echo -e "\r${PROGRESS_COLOR_GREEN}✅ $label: SUCCESS${PROGRESS_COLOR_RESET}"
  else
    echo -e "\r${PROGRESS_COLOR_RED}❌ $label: FAILED${PROGRESS_COLOR_RESET}"
  fi
  
  return $result
}

# === MULTI-STEP PROGRESS ===
multi_step_progress() {
  local steps=("$@")
  local total_steps=${#steps[@]}
  local current_step=0
  
  if [[ "${ENABLE_PROGRESS_BAR}" != "true" ]]; then
    return 0
  fi
  
  export PROGRESS_START_TIME=$(date +%s)
  
  for step in "${steps[@]}"; do
    ((current_step++))
    draw_progress_bar "$current_step" "$total_steps" "Step $current_step: $step" "$PROGRESS_BAR_WIDTH" "detailed"
    sleep 0.5  # Simulate step processing
  done
  
  echo ""
}

# === CLEANUP PROGRESS ===
cleanup_progress() {
  # Kill any running progress displays
  if [[ -n "${BATCH_PROGRESS_PID:-}" ]]; then
    kill "${BATCH_PROGRESS_PID}" 2>/dev/null || true
  fi
  
  # Remove any temporary files
  rm -f /tmp/batch_progress_$$ 2>/dev/null || true
  
  # Clear progress variables
  unset BATCH_TOTAL BATCH_CURRENT BATCH_LABEL BATCH_STYLE BATCH_PROGRESS_PIPE BATCH_PROGRESS_PID PROGRESS_START_TIME
}

# === PROGRESS BAR DEMO ===
progress_bar_demo() {
  echo "🎨 Progress Bar Demo"
  echo "===================="
  
  echo ""
  echo "1. Simple Progress Bar:"
  show_progress_bar "Simple Demo" 20 "simple" 0.1
  
  echo ""
  echo "2. Batch Progress Bar:"
  show_progress_bar "Batch Demo" 15 "batch" 0.15
  
  echo ""
  echo "3. Detailed Progress Bar:"
  show_progress_bar "Detailed Demo" 10 "detailed" 0.2
  
  echo ""
  echo "4. Indeterminate Progress (3 seconds):"
  show_indeterminate_progress "Loading Demo" "dots" 0.1 &
  local demo_pid=$!
  sleep 3
  kill $demo_pid 2>/dev/null || true
  echo -e "\r✅ Loading Demo: COMPLETE"
  
  echo ""
  echo "5. Batch Tracker Demo:"
  batch_progress_tracker 5 "Processing items"
  for i in {1..5}; do
    sleep 0.5
    update_batch_progress "increment"
  done
  complete_batch_progress
  
  echo ""
  echo "✅ Demo completed!"
}

# === VALIDATE PROGRESS CONFIGURATION ===
validate_progress_configuration() {
  # Check if progress bar width is valid
  if [[ ! "$PROGRESS_BAR_WIDTH" =~ ^[0-9]+$ ]] || [[ $PROGRESS_BAR_WIDTH -lt 10 ]] || [[ $PROGRESS_BAR_WIDTH -gt 100 ]]; then
    progress_log_warn "⚠️ Invalid progress bar width: $PROGRESS_BAR_WIDTH (should be 10-100)"
    return 1
  fi
  
  # Check if style is valid
  if [[ -z "${PROGRESS_CHARS[$PROGRESS_BAR_STYLE]:-}" ]]; then
    progress_log_warn "⚠️ Invalid progress bar style: $PROGRESS_BAR_STYLE"
    return 1
  fi
  
  return 0
}

# Trap to cleanup on exit
trap cleanup_progress EXIT

# Initialize on load
initialize_progress_bar

# Export functions
export -f initialize_progress_bar
export -f show_progress_bar
export -f show_indeterminate_progress
export -f batch_progress_tracker
export -f update_batch_progress
export -f complete_batch_progress
export -f abort_batch_progress
export -f download_progress_bar
export -f file_operation_progress
export -f network_operation_progress
export -f multi_step_progress
export -f cleanup_progress
export -f progress_bar_demo
export -f validate_progress_configuration
export -f draw_progress_bar
export -f calculate_percentage
export -f get_progress_char
