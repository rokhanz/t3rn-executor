#!/bin/bash
set -euo pipefail

# ╔══════════════════════════════════════════════════════════════╗
# ║                    T3RN PROGRESS MULTITASK                  ║
# ║                  (Multi-Task Progress Display)              ║
# ╚══════════════════════════════════════════════════════════════╝

# T3RN Executor Multi-Task Progress
# Advanced multi-task progress display with real-time status updates
#
# @author Rokhanz
# @license MIT
# @version 1.0.0


# === INTERNAL ERROR HANDLING ===
multitask_error_exit() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] MULTITASK ERROR: $*" >&2
  exit 1
}

multitask_log_info() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] MULTITASK INFO: $*"
}

multitask_log_warn() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] MULTITASK WARN: $*"
}

# === INITIALIZE MULTITASK PROGRESS ===
initialize_multitask_progress() {
  if [[ -z "${SCRIPT_DIR:-}" ]]; then
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")"/.. && pwd)"
    export SCRIPT_DIR
  fi
  
  # Load .env for multitask configuration
  if [[ -f "$SCRIPT_DIR/.env" ]]; then
    source "$SCRIPT_DIR/.env" 2>/dev/null || true
  fi
  
  # Load color progress if available
  if [[ -f "$SCRIPT_DIR/modules/progress_bar_color.sh" ]]; then
    source "$SCRIPT_DIR/modules/progress_bar_color.sh" 2>/dev/null || true
  fi
  
  # Multitask configuration
  ENABLE_PROGRESS_BAR="${ENABLE_PROGRESS_BAR:-true}"
  ENABLE_COLOR_OUTPUT="${ENABLE_COLOR_OUTPUT:-true}"
  ENABLE_EMOJI_LOGGING="${ENABLE_EMOJI_LOGGING:-true}"
  PROGRESS_BAR_WIDTH="${PROGRESS_BAR_WIDTH:-40}"
  MAX_CONCURRENT_TASKS="${MAX_CONCURRENT_TASKS:-5}"
  
  # Initialize multitask variables
  export MULTITASK_TEMP_DIR="/tmp/multitask_$$"
  export MULTITASK_ACTIVE=false
  export MULTITASK_TASKS=()
  export MULTITASK_PIDS=()
  export MULTITASK_STATUS=()
  
  mkdir -p "$MULTITASK_TEMP_DIR"
  
  multitask_log_info "🔄 Multitask progress initialized"
}

# === TASK STATUS DEFINITIONS ===
declare -A TASK_STATUS_COLORS=(
  ["pending"]="$COLOR_YELLOW"
  ["running"]="$COLOR_BLUE"
  ["success"]="$COLOR_GREEN"
  ["failed"]="$COLOR_RED"
  ["skipped"]="$COLOR_DIM"
)

declare -A TASK_STATUS_EMOJIS=(
  ["pending"]="⏳"
  ["running"]="🔄"
  ["success"]="✅"
  ["failed"]="❌"
  ["skipped"]="⏭️"
)

# === CREATE TASK ===
create_task() {
  local task_id="$1"
  local task_name="$2"
  local task_command="$3"
  local task_total="${4:-100}"
  
  local task_file="$MULTITASK_TEMP_DIR/task_${task_id}"
  
  cat > "$task_file" << EOF
{
  "id": "$task_id",
  "name": "$task_name",
  "command": "$task_command",
  "status": "pending",
  "progress": 0,
  "total": $task_total,
  "start_time": "",
  "end_time": "",
  "pid": "",
  "output": "",
  "error": ""
}
EOF
  
  multitask_log_info "📝 Created task: $task_id - $task_name"
}

# === UPDATE TASK STATUS ===
update_task_status() {
  local task_id="$1"
  local status="$2"
  local progress="${3:-}"
  local output="${4:-}"
  local error="${5:-}"
  
  local task_file="$MULTITASK_TEMP_DIR/task_${task_id}"
  
  if [[ ! -f "$task_file" ]]; then
    multitask_log_warn "⚠️ Task file not found: $task_id"
    return 1
  fi
  
  # Update task file
  local temp_file="${task_file}.tmp"
  
  # Read current task data
  local current_data=$(cat "$task_file")
  
  # Update fields
  echo "$current_data" | \
    sed "s/\"status\": \"[^\"]*\"/\"status\": \"$status\"/" | \
    sed "s/\"progress\": [0-9]*/\"progress\": ${progress:-0}/" | \
    sed "s/\"output\": \"[^\"]*\"/\"output\": \"$output\"/" | \
    sed "s/\"error\": \"[^\"]*\"/\"error\": \"$error\"/" > "$temp_file"
  
  mv "$temp_file" "$task_file"
}

# === GET TASK STATUS ===
get_task_status() {
  local task_id="$1"
  local field="${2:-status}"
  
  local task_file="$MULTITASK_TEMP_DIR/task_${task_id}"
  
  if [[ ! -f "$task_file" ]]; then
    echo "unknown"
    return 1
  fi
  
  grep -oP "\"$field\": \"[^\"]*\"" "$task_file" | cut -d'"' -f4
}

# === GET TASK PROGRESS ===
get_task_progress() {
  local task_id="$1"
  
  local task_file="$MULTITASK_TEMP_DIR/task_${task_id}"
  
  if [[ ! -f "$task_file" ]]; then
    echo "0"
    return 1
  fi
  
  grep -oP "\"progress\": [0-9]*" "$task_file" | cut -d' ' -f2
}

# === GET TASK TOTAL ===
get_task_total() {
  local task_id="$1"
  
  local task_file="$MULTITASK_TEMP_DIR/task_${task_id}"
  
  if [[ ! -f "$task_file" ]]; then
    echo "100"
    return 1
  fi
  
  grep -oP "\"total\": [0-9]*" "$task_file" | cut -d' ' -f2
}

# === DRAW MULTITASK DISPLAY ===
draw_multitask_display() {
  if [[ "${ENABLE_PROGRESS_BAR}" != "true" ]]; then
    return 0
  fi
  
  # Clear screen and move to top
  echo -ne "\033[2J\033[H"
  
  # Header
  if [[ "${ENABLE_EMOJI_LOGGING}" == "true" ]]; then
    echo -e "${COLOR_BOLD}${COLOR_CYAN}🔄 T3RN Executor - Multi-Task Progress${COLOR_RESET}"
  else
    echo -e "${COLOR_BOLD}${COLOR_CYAN}T3RN Executor - Multi-Task Progress${COLOR_RESET}"
  fi
  
  echo -e "${COLOR_DIM}$(date '+%Y-%m-%d %H:%M:%S')${COLOR_RESET}"
  echo ""
  
  # Task list
  local task_files=("$MULTITASK_TEMP_DIR"/task_*)
  local total_tasks=0
  local completed_tasks=0
  local failed_tasks=0
  
  for task_file in "${task_files[@]}"; do
    if [[ -f "$task_file" ]]; then
      ((total_tasks++))
      
      local task_id=$(basename "$task_file" | sed 's/task_//')
      local task_name=$(grep -oP '"name": "[^"]*"' "$task_file" | cut -d'"' -f4)
      local status=$(get_task_status "$task_id")
      local progress=$(get_task_progress "$task_id")
      local total=$(get_task_total "$task_id")
      
      # Count completed/failed tasks
      case "$status" in
        "success") ((completed_tasks++)) ;;
        "failed") ((failed_tasks++)) ;;
      esac
      
      # Draw task progress
      draw_single_task_progress "$task_id" "$task_name" "$status" "$progress" "$total"
    fi
  done
  
  # Summary
  echo ""
  echo -e "${COLOR_BOLD}Summary:${COLOR_RESET}"
  echo -e "  📊 Total Tasks: $total_tasks"
  echo -e "  ✅ Completed: ${COLOR_GREEN}$completed_tasks${COLOR_RESET}"
  echo -e "  ❌ Failed: ${COLOR_RED}$failed_tasks${COLOR_RESET}"
  echo -e "  🔄 Running: $((total_tasks - completed_tasks - failed_tasks))"
  
  # Overall progress
  if [[ $total_tasks -gt 0 ]]; then
    local overall_progress=$(( (completed_tasks * 100) / total_tasks ))
    echo ""
    echo -e "${COLOR_BOLD}Overall Progress:${COLOR_RESET}"
    draw_overall_progress "$overall_progress"
  fi
}

# === DRAW SINGLE TASK PROGRESS ===
draw_single_task_progress() {
  local task_id="$1"
  local task_name="$2"
  local status="$3"
  local progress="$4"
  local total="$5"
  
  local percentage=0
  if [[ $total -gt 0 ]]; then
    percentage=$(( (progress * 100) / total ))
  fi
  
  # Status color and emoji
  local status_color="${TASK_STATUS_COLORS[$status]:-$COLOR_WHITE}"
  local status_emoji="${TASK_STATUS_EMOJIS[$status]:-❓}"
  
  # Progress bar
  local bar_width=20
  local filled_width=$(( (percentage * bar_width) / 100 ))
  local empty_width=$((bar_width - filled_width))
  
  local progress_bar=""
  for ((i=0; i<filled_width; i++)); do
    progress_bar+="█"
  done
  for ((i=0; i<empty_width; i++)); do
    progress_bar+="░"
  done
  
  # Format task line
  printf "  %s %s%-20s%s [%s%s%s] %s%3d%%%s (%d/%d)\n" \
    "$status_emoji" \
    "$status_color" "$task_name" "$COLOR_RESET" \
    "$status_color" "$progress_bar" "$COLOR_RESET" \
    "$status_color" "$percentage" "$COLOR_RESET" \
    "$progress" "$total"
}

# === DRAW OVERALL PROGRESS ===
draw_overall_progress() {
  local percentage="$1"
  local width=50
  local filled_width=$(( (percentage * width) / 100 ))
  local empty_width=$((width - filled_width))
  
  # Choose color based on progress
  local color=""
  if [[ $percentage -eq 100 ]]; then
    color="$COLOR_BRIGHT_GREEN"
  elif [[ $percentage -ge 75 ]]; then
    color="$COLOR_GREEN"
  elif [[ $percentage -ge 50 ]]; then
    color="$COLOR_YELLOW"
  elif [[ $percentage -ge 25 ]]; then
    color="$COLOR_BLUE"
  else
    color="$COLOR_RED"
  fi
  
  # Build progress bar
  local progress_bar=""
  for ((i=0; i<filled_width; i++)); do
    progress_bar+="█"
  done
  for ((i=0; i<empty_width; i++)); do
    progress_bar+="░"
  done
  
  echo -e "  [${color}${progress_bar}${COLOR_RESET}] ${COLOR_BOLD}${percentage}%${COLOR_RESET}"
}

# === RUN TASK IN BACKGROUND ===
run_task_background() {
  local task_id="$1"
  local task_command="$2"
  
  update_task_status "$task_id" "running"
  
  # Run command in background and capture output
  {
    local start_time=$(date +%s)
    local output=""
    local error=""
    local exit_code=0
    
    # Execute command and capture output
    if output=$(eval "$task_command" 2>&1); then
      update_task_status "$task_id" "success" "100" "$output"
    else
      exit_code=$?
      update_task_status "$task_id" "failed" "0" "$output" "Exit code: $exit_code"
    fi
    
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    # Update task file with timing
    local task_file="$MULTITASK_TEMP_DIR/task_${task_id}"
    sed -i "s/\"start_time\": \"[^\"]*\"/\"start_time\": \"$start_time\"/" "$task_file"
    sed -i "s/\"end_time\": \"[^\"]*\"/\"end_time\": \"$end_time\"/" "$task_file"
    
  } &
  
  local task_pid=$!
  
  # Update task with PID
  local task_file="$MULTITASK_TEMP_DIR/task_${task_id}"
  sed -i "s/\"pid\": \"[^\"]*\"/\"pid\": \"$task_pid\"/" "$task_file"
  
  echo "$task_pid"
}

# === START MULTITASK EXECUTION ===
start_multitask_execution() {
  local task_ids=("$@")
  
  multitask_log_info "🚀 Starting multitask execution with ${#task_ids[@]} tasks"
  
  export MULTITASK_ACTIVE=true
  local running_tasks=()
  local task_queue=("${task_ids[@]}")
  
  # Start display update loop
  {
    while [[ "$MULTITASK_ACTIVE" == "true" ]]; do
      draw_multitask_display
      sleep 1
    done
  } &
  local display_pid=$!
  
  # Task execution loop
  while [[ ${#task_queue[@]} -gt 0 ]] || [[ ${#running_tasks[@]} -gt 0 ]]; do
    # Start new tasks if slots available
    while [[ ${#running_tasks[@]} -lt $MAX_CONCURRENT_TASKS ]] && [[ ${#task_queue[@]} -gt 0 ]]; do
      local task_id="${task_queue[0]}"
      task_queue=("${task_queue[@]:1}")  # Remove first element
      
      local task_file="$MULTITASK_TEMP_DIR/task_${task_id}"
      if [[ -f "$task_file" ]]; then
        local task_command=$(grep -oP '"command": "[^"]*"' "$task_file" | cut -d'"' -f4)
        local task_pid=$(run_task_background "$task_id" "$task_command")
        running_tasks+=("$task_id:$task_pid")
      fi
    done
    
    # Check running tasks
    local new_running_tasks=()
    for task_entry in "${running_tasks[@]}"; do
      local task_id="${task_entry%:*}"
      local task_pid="${task_entry#*:}"
      
      if kill -0 "$task_pid" 2>/dev/null; then
        # Task still running
        new_running_tasks+=("$task_entry")
      else
        # Task finished
        multitask_log_info "✅ Task completed: $task_id"
      fi
    done
    running_tasks=("${new_running_tasks[@]}")
    
    sleep 1
  done
  
  # Stop display
  export MULTITASK_ACTIVE=false
  kill $display_pid 2>/dev/null || true
  wait $display_pid 2>/dev/null || true
  
  # Final display
  draw_multitask_display
  
  multitask_log_info "🏁 Multitask execution completed"
}

# === NETWORK CONNECTIVITY MULTITASK ===
multitask_network_test() {
  local targets=("$@")
  
  multitask_log_info "🌐 Starting network connectivity test for ${#targets[@]} targets"
  
  local task_ids=()
  local task_counter=1
  
  # Create tasks for each target
  for target in "${targets[@]}"; do
    local task_id="net_$task_counter"
    create_task "$task_id" "Ping $target" "ping -c 3 -W 5 $target" 3
    task_ids+=("$task_id")
    ((task_counter++))
  done
  
  # Execute tasks
  start_multitask_execution "${task_ids[@]}"
  
  # Report results
  echo ""
  echo -e "${COLOR_BOLD}${COLOR_CYAN}🌐 Network Test Results:${COLOR_RESET}"
  
  for task_id in "${task_ids[@]}"; do
    local status=$(get_task_status "$task_id")
    local task_name=$(grep -oP '"name": "[^"]*"' "$MULTITASK_TEMP_DIR/task_${task_id}" | cut -d'"' -f4)
    
    if [[ "$status" == "success" ]]; then
      echo -e "  ✅ $task_name: ${COLOR_GREEN}ONLINE${COLOR_RESET}"
    else
      echo -e "  ❌ $task_name: ${COLOR_RED}OFFLINE${COLOR_RESET}"
    fi
  done
}

# === DEPENDENCY INSTALLATION MULTITASK ===
multitask_dependency_install() {
  local packages=("$@")
  
  multitask_log_info "📦 Starting dependency installation for ${#packages[@]} packages"
  
  local task_ids=()
  local task_counter=1
  
  # Create tasks for each package
  for package in "${packages[@]}"; do
    local task_id="pkg_$task_counter"
    create_task "$task_id" "Install $package" "sudo apt install -y $package" 1
    task_ids+=("$task_id")
    ((task_counter++))
  done
  
  # Execute tasks
  start_multitask_execution "${task_ids[@]}"
  
  # Report results
  echo ""
  echo -e "${COLOR_BOLD}${COLOR_CYAN}📦 Installation Results:${COLOR_RESET}"
  
  for task_id in "${task_ids[@]}"; do
    local status=$(get_task_status "$task_id")
    local task_name=$(grep -oP '"name": "[^"]*"' "$MULTITASK_TEMP_DIR/task_${task_id}" | cut -d'"' -f4)
    
    if [[ "$status" == "success" ]]; then
      echo -e "  ✅ $task_name: ${COLOR_GREEN}SUCCESS${COLOR_RESET}"
    else
      echo -e "  ❌ $task_name: ${COLOR_RED}FAILED${COLOR_RESET}"
    fi
  done
}

# === FILE OPERATIONS MULTITASK ===
multitask_file_operations() {
  local operations=("$@")
  
  multitask_log_info "📁 Starting file operations for ${#operations[@]} tasks"
  
  local task_ids=()
  local task_counter=1
  
  # Create tasks for each operation
  # Format: "operation:source:destination:name"
  for operation in "${operations[@]}"; do
    IFS=':' read -r op source dest name <<< "$operation"
    local task_id="file_$task_counter"
    
    case "$op" in
      "copy")
        create_task "$task_id" "Copy $name" "cp '$source' '$dest'" 1
        ;;
      "move")
        create_task "$task_id" "Move $name" "mv '$source' '$dest'" 1
        ;;
      "extract")
        create_task "$task_id" "Extract $name" "tar -xf '$source' -C '$dest'" 1
        ;;
      "download")
        create_task "$task_id" "Download $name" "curl -L -o '$dest' '$source'" 1
        ;;
    esac
    
    task_ids+=("$task_id")
    ((task_counter++))
  done
  
  # Execute tasks
  start_multitask_execution "${task_ids[@]}"
}

# === MULTITASK DEMO ===
multitask_demo() {
  echo -e "${COLOR_BOLD}${COLOR_CYAN}🔄 Multitask Progress Demo${COLOR_RESET}"
  echo ""
  
  # Create demo tasks
  local task_ids=("demo1" "demo2" "demo3" "demo4" "demo5")
  
  create_task "demo1" "Download File 1" "sleep 3 && echo 'Downloaded file 1'" 3
  create_task "demo2" "Process Data" "sleep 5 && echo 'Data processed'" 5
  create_task "demo3" "Upload Results" "sleep 2 && echo 'Results uploaded'" 2
  create_task "demo4" "Send Notification" "sleep 1 && echo 'Notification sent'" 1
  create_task "demo5" "Cleanup" "sleep 4 && echo 'Cleanup completed'" 4
  
  # Execute demo
  start_multitask_execution "${task_ids[@]}"
  
  echo ""
  echo -e "${COLOR_BRIGHT_GREEN}${COLOR_BOLD}✨ Demo completed!${COLOR_RESET}"
}

# === CLEANUP MULTITASK ===
cleanup_multitask() {
  multitask_log_info "🧹 Cleaning up multitask environment..."
  
  # Stop any running tasks
  export MULTITASK_ACTIVE=false
  
  # Kill any background processes
  local task_files=("$MULTITASK_TEMP_DIR"/task_*)
  for task_file in "${task_files[@]}"; do
    if [[ -f "$task_file" ]]; then
      local pid=$(grep -oP '"pid": "[^"]*"' "$task_file" | cut -d'"' -f4)
      if [[ -n "$pid" && "$pid" != "" ]]; then
        kill "$pid" 2>/dev/null || true
      fi
    fi
  done
  
  # Remove temporary directory
  rm -rf "$MULTITASK_TEMP_DIR" 2>/dev/null || true
  
  # Clear variables
  unset MULTITASK_TEMP_DIR MULTITASK_ACTIVE MULTITASK_TASKS MULTITASK_PIDS MULTITASK_STATUS
  
  multitask_log_info "✅ Multitask cleanup completed"
}

# === VALIDATE MULTITASK CONFIGURATION ===
validate_multitask_configuration() {
  multitask_log_info "🔍 Validating multitask configuration..."
  
  # Check max concurrent tasks
  if [[ ! "$MAX_CONCURRENT_TASKS" =~ ^[0-9]+$ ]] || [[ $MAX_CONCURRENT_TASKS -lt 1 ]] || [[ $MAX_CONCURRENT_TASKS -gt 20 ]]; then
    multitask_log_warn "⚠️ Invalid MAX_CONCURRENT_TASKS: $MAX_CONCURRENT_TASKS (should be 1-20)"
    return 1
  fi
  
  # Check temporary directory
  if [[ ! -d "$MULTITASK_TEMP_DIR" ]]; then
    multitask_log_warn "⚠️ Multitask temporary directory not found: $MULTITASK_TEMP_DIR"
    return 1
  fi
  
  multitask_log_info "✅ Multitask configuration validated"
  return 0
}

# Trap to cleanup on exit
trap cleanup_multitask EXIT

# Initialize on load
initialize_multitask_progress

# Export functions
export -f initialize_multitask_progress
export -f create_task
export -f update_task_status
export -f get_task_status
export -f get_task_progress
export -f get_task_total
export -f draw_multitask_display
export -f draw_single_task_progress
export -f draw_overall_progress
export -f run_task_background
export -f start_multitask_execution
export -f multitask_network_test
export -f multitask_dependency_install
export -f multitask_file_operations
export -f multitask_demo
export -f cleanup_multitask
export -f validate_multitask_configuration
