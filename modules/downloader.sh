#!/bin/bash
set -euo pipefail

# ╔══════════════════════════════════════════════════════════════╗
# ║                    T3RN EXECUTOR DOWNLOADER                 ║
# ║                  (Binary Download & Setup)                  ║
# ╚══════════════════════════════════════════════════════════════╝

# T3RN Executor Binary Downloader
# Automated download, extraction, and setup of T3RN executor binary
#
# @author Rokhanz
# @license MIT
# @version 1.0.0


# === INTERNAL ERROR HANDLING ===
downloader_error_exit() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] DOWNLOADER ERROR: $*" >&2
  exit 1
}

downloader_log_info() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] DOWNLOADER INFO: $*"
}

downloader_log_warn() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] DOWNLOADER WARN: $*"
}

# === INITIALIZE DOWNLOADER ===
initialize_downloader() {
  if [[ -z "${SCRIPT_DIR:-}" ]]; then
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")"/.. && pwd)"
    export SCRIPT_DIR
  fi
  
  if [[ -z "${T3RN_DIR:-}" ]]; then
    T3RN_DIR="$SCRIPT_DIR/t3rn"
    export T3RN_DIR
  fi
  
  if [[ -z "${LOGS_DIR:-}" ]]; then
    LOGS_DIR="$SCRIPT_DIR/logs"
    export LOGS_DIR
  fi
  
  mkdir -p "$LOGS_DIR" || downloader_error_exit "Cannot create logs directory"
  
  # Load .env for downloader configuration
  if [[ -f "$SCRIPT_DIR/.env" ]]; then
    source "$SCRIPT_DIR/.env" 2>/dev/null || true
  fi
  
  # Load progress bar if available
  if [[ -f "$SCRIPT_DIR/modules/progress_bar_batch.sh" ]]; then
    source "$SCRIPT_DIR/modules/progress_bar_batch.sh" 2>/dev/null || true
  fi
  
  downloader_log_info "📦 Downloader initialized"
}

# === GITHUB API CONFIGURATION ===
GITHUB_API_BASE="https://api.github.com"
GITHUB_REPO_OWNER="t3rn"
GITHUB_REPO_NAME="executor"
DOWNLOAD_TIMEOUT=300  # 5 minutes
MAX_RETRY_ATTEMPTS=3
RETRY_DELAY=5

# === GET LATEST RELEASE INFO ===
get_latest_release_info() {
  downloader_log_info "🔍 Fetching latest release information from GitHub..."
  
  local api_url="$GITHUB_API_BASE/repos/$GITHUB_REPO_OWNER/$GITHUB_REPO_NAME/releases/latest"
  local response=""
  local attempt=1
  
  while [[ $attempt -le $MAX_RETRY_ATTEMPTS ]]; do
    downloader_log_info "📡 Attempt $attempt/$MAX_RETRY_ATTEMPTS: Fetching release info..."
    
    response=$(curl -s --max-time 30 \
      -H "Accept: application/vnd.github.v3+json" \
      -H "User-Agent: t3rn-executor-downloader" \
      "$api_url" 2>/dev/null || echo "")
    
    if [[ -n "$response" && "$response" =~ "tag_name" ]]; then
      echo "$response"
      return 0
    fi
    
    downloader_log_warn "⚠️ Attempt $attempt failed, retrying in ${RETRY_DELAY}s..."
    sleep $RETRY_DELAY
    ((attempt++))
  done
  
  downloader_error_exit "Failed to fetch release information after $MAX_RETRY_ATTEMPTS attempts"
}

# === GET SPECIFIC RELEASE INFO ===
get_specific_release_info() {
  local version="$1"
  
  downloader_log_info "🔍 Fetching release information for version: $version"
  
  # Remove 'v' prefix if present
  version="${version#v}"
  
  local api_url="$GITHUB_API_BASE/repos/$GITHUB_REPO_OWNER/$GITHUB_REPO_NAME/releases/tags/v$version"
  local response=""
  local attempt=1
  
  while [[ $attempt -le $MAX_RETRY_ATTEMPTS ]]; do
    downloader_log_info "📡 Attempt $attempt/$MAX_RETRY_ATTEMPTS: Fetching release info for v$version..."
    
    response=$(curl -s --max-time 30 \
      -H "Accept: application/vnd.github.v3+json" \
      -H "User-Agent: t3rn-executor-downloader" \
      "$api_url" 2>/dev/null || echo "")
    
    if [[ -n "$response" && "$response" =~ "tag_name" ]]; then
      echo "$response"
      return 0
    fi
    
    downloader_log_warn "⚠️ Attempt $attempt failed, retrying in ${RETRY_DELAY}s..."
    sleep $RETRY_DELAY
    ((attempt++))
  done
  
  downloader_error_exit "Failed to fetch release information for version v$version after $MAX_RETRY_ATTEMPTS attempts"
}

# === PARSE RELEASE INFO ===
parse_release_info() {
  local release_json="$1"
  local info_type="$2"
  
  case "$info_type" in
    "tag_name")
      echo "$release_json" | grep -oP '"tag_name":\s*"[^"]*"' | cut -d'"' -f4
      ;;
    "name")
      echo "$release_json" | grep -oP '"name":\s*"[^"]*"' | cut -d'"' -f4
      ;;
    "published_at")
      echo "$release_json" | grep -oP '"published_at":\s*"[^"]*"' | cut -d'"' -f4
      ;;
    "body")
      echo "$release_json" | grep -oP '"body":\s*"[^"]*"' | cut -d'"' -f4 | head -c 200
      ;;
    "download_url")
      # Look for Linux x86_64 binary
      echo "$release_json" | grep -oP '"browser_download_url":\s*"[^"]*linux[^"]*x86_64[^"]*"' | cut -d'"' -f4 | head -1
      ;;
    "tarball_url")
      echo "$release_json" | grep -oP '"tarball_url":\s*"[^"]*"' | cut -d'"' -f4
      ;;
    "zipball_url")
      echo "$release_json" | grep -oP '"zipball_url":\s*"[^"]*"' | cut -d'"' -f4
      ;;
    *)
      downloader_log_warn "⚠️ Unknown info type: $info_type"
      return 1
      ;;
  esac
}

# === DETECT SYSTEM ARCHITECTURE ===
detect_system_architecture() {
  local arch=$(uname -m)
  local os=$(uname -s | tr '[:upper:]' '[:lower:]')
  
  case "$arch" in
    "x86_64"|"amd64")
      echo "x86_64"
      ;;
    "aarch64"|"arm64")
      echo "aarch64"
      ;;
    "armv7l")
      echo "armv7"
      ;;
    *)
      downloader_log_warn "⚠️ Unsupported architecture: $arch"
      echo "x86_64"  # Default fallback
      ;;
  esac
}

# === FIND DOWNLOAD URL FOR ARCHITECTURE ===
find_download_url_for_arch() {
  local release_json="$1"
  local target_arch="${2:-$(detect_system_architecture)}"
  local target_os="${3:-linux}"
  
  downloader_log_info "🔍 Looking for download URL for $target_os-$target_arch..."
  
  # Extract all download URLs
  local urls=$(echo "$release_json" | grep -oP '"browser_download_url":\s*"[^"]*"' | cut -d'"' -f4)
  
  # Filter by architecture and OS
  local filtered_url=""
  while IFS= read -r url; do
    if [[ "$url" =~ $target_os ]] && [[ "$url" =~ $target_arch ]]; then
      filtered_url="$url"
      break
    fi
  done <<< "$urls"
  
  # Fallback patterns
  if [[ -z "$filtered_url" ]]; then
    # Try common patterns
    local patterns=("linux.*x86_64" "linux.*amd64" "linux" "x86_64" "amd64")
    
    for pattern in "${patterns[@]}"; do
      filtered_url=$(echo "$urls" | grep -E "$pattern" | head -1)
      if [[ -n "$filtered_url" ]]; then
        downloader_log_info "📋 Found URL using pattern: $pattern"
        break
      fi
    done
  fi
  
  if [[ -n "$filtered_url" ]]; then
    echo "$filtered_url"
    return 0
  else
    downloader_log_warn "⚠️ No suitable download URL found for $target_os-$target_arch"
    return 1
  fi
}

# === DOWNLOAD FILE WITH PROGRESS ===
download_file_with_progress() {
  local url="$1"
  local output_file="$2"
  local description="${3:-Downloading file}"
  
  downloader_log_info "📥 $description..."
  downloader_log_info "🔗 URL: $url"
  downloader_log_info "📁 Output: $output_file"
  
  # Create output directory if it doesn't exist
  local output_dir=$(dirname "$output_file")
  mkdir -p "$output_dir" || downloader_error_exit "Cannot create output directory: $output_dir"
  
  # Check if progress bar is available
  if command -v show_progress_bar >/dev/null 2>&1 && [[ "${ENABLE_PROGRESS_BAR:-true}" == "true" ]]; then
    # Download with progress bar
    local temp_file="${output_file}.tmp"
    
    # Start progress bar in background
    show_progress_bar "Downloading" &
    local progress_pid=$!
    
    # Download file
    local download_success=false
    if curl -L --max-time $DOWNLOAD_TIMEOUT \
         --retry $MAX_RETRY_ATTEMPTS \
         --retry-delay $RETRY_DELAY \
         --retry-max-time $((DOWNLOAD_TIMEOUT * 2)) \
         -o "$temp_file" \
         "$url" 2>/dev/null; then
      download_success=true
    fi
    
    # Stop progress bar
    kill $progress_pid 2>/dev/null || true
    wait $progress_pid 2>/dev/null || true
    
    if [[ "$download_success" == "true" ]]; then
      mv "$temp_file" "$output_file"
      downloader_log_info "✅ Download completed successfully"
      return 0
    else
      rm -f "$temp_file"
      downloader_error_exit "Download failed"
    fi
  else
    # Download without progress bar
    if curl -L --max-time $DOWNLOAD_TIMEOUT \
         --retry $MAX_RETRY_ATTEMPTS \
         --retry-delay $RETRY_DELAY \
         --retry-max-time $((DOWNLOAD_TIMEOUT * 2)) \
         -o "$output_file" \
         "$url"; then
      downloader_log_info "✅ Download completed successfully"
      return 0
    else
      downloader_error_exit "Download failed"
    fi
  fi
}

# === VERIFY DOWNLOAD ===
verify_download() {
  local file_path="$1"
  local expected_type="${2:-binary}"
  
  downloader_log_info "🔍 Verifying downloaded file: $file_path"
  
  # Check if file exists
  if [[ ! -f "$file_path" ]]; then
    downloader_error_exit "Downloaded file not found: $file_path"
  fi
  
  # Check file size
  local file_size=$(stat -c%s "$file_path" 2>/dev/null || echo "0")
  if [[ $file_size -lt 1000000 ]]; then  # Less than 1MB
    downloader_log_warn "⚠️ Downloaded file seems small: $file_size bytes"
  else
    downloader_log_info "✅ File size: $file_size bytes"
  fi
  
  # Check file type
  local file_type=$(file "$file_path" 2>/dev/null || echo "unknown")
  downloader_log_info "📋 File type: $file_type"
  
  case "$expected_type" in
    "binary")
      if [[ "$file_type" =~ "ELF" ]] || [[ "$file_type" =~ "executable" ]]; then
        downloader_log_info "✅ Binary file verification passed"
      else
        downloader_log_warn "⚠️ File may not be a valid binary: $file_type"
      fi
      ;;
    "archive")
      if [[ "$file_type" =~ "gzip" ]] || [[ "$file_type" =~ "tar" ]] || [[ "$file_type" =~ "archive" ]]; then
        downloader_log_info "✅ Archive file verification passed"
      else
        downloader_log_warn "⚠️ File may not be a valid archive: $file_type"
      fi
      ;;
  esac
  
  return 0
}

# === CLEANUP PREVIOUS INSTALLATION ===
cleanup_previous_installation() {
  downloader_log_info "🧹 Cleaning up previous installation..."
  
  # Remove old t3rn directory if it exists
  if [[ -d "$T3RN_DIR" ]]; then
    downloader_log_info "🗑️ Removing existing t3rn directory: $T3RN_DIR"
    rm -rf "$T3RN_DIR" || downloader_error_exit "Failed to remove existing t3rn directory"
  fi
  
  # Remove old download files
  local download_files=("$SCRIPT_DIR"/*.tar.gz "$SCRIPT_DIR"/*.zip "$SCRIPT_DIR"/executor-*)
  for pattern in "${download_files[@]}"; do
    if ls $pattern 1> /dev/null 2>&1; then
      downloader_log_info "🗑️ Removing old download files: $pattern"
      rm -f $pattern
    fi
  done
  
  downloader_log_info "✅ Cleanup completed"
}

# === CREATE T3RN DIRECTORY ===
create_t3rn_directory() {
  downloader_log_info "📁 Creating t3rn directory structure..."
  
  mkdir -p "$T3RN_DIR" || downloader_error_exit "Cannot create t3rn directory: $T3RN_DIR"
  mkdir -p "$T3RN_DIR/executor" || downloader_error_exit "Cannot create executor directory"
  
  downloader_log_info "✅ Directory structure created"
}

# === DOWNLOAD EXECUTOR BINARY ===
download_executor_binary() {
  local version="${1:-latest}"
  
  downloader_log_info "🚀 Starting executor binary download (version: $version)..."
  
  # Get release information
  local release_info=""
  if [[ "$version" == "latest" ]]; then
    release_info=$(get_latest_release_info)
  else
    release_info=$(get_specific_release_info "$version")
  fi
  
  # Parse release information
  local tag_name=$(parse_release_info "$release_info" "tag_name")
  local release_name=$(parse_release_info "$release_info" "name")
  local published_at=$(parse_release_info "$release_info" "published_at")
  
  downloader_log_info "📋 Release Information:"
  downloader_log_info "   Version: $tag_name"
  downloader_log_info "   Name: $release_name"
  downloader_log_info "   Published: $published_at"
  
  # Find download URL
  local download_url=$(find_download_url_for_arch "$release_info")
  if [[ -z "$download_url" ]]; then
    downloader_error_exit "No suitable download URL found for this system"
  fi
  
  downloader_log_info "🔗 Download URL: $download_url"
  
  # Determine file name and type
  local filename=$(basename "$download_url")
  local output_file="$SCRIPT_DIR/$filename"
  
  # Download the file
  download_file_with_progress "$download_url" "$output_file" "Downloading T3RN Executor $tag_name"
  
  # Verify download
  if [[ "$filename" =~ \.tar\.gz$ ]] || [[ "$filename" =~ \.tgz$ ]]; then
    verify_download "$output_file" "archive"
  else
    verify_download "$output_file" "binary"
  fi
  
  # Store download info for extraction
  export DOWNLOADED_FILE="$output_file"
  export DOWNLOADED_VERSION="$tag_name"
  
  downloader_log_info "✅ Executor binary downloaded successfully"
}

# === EXTRACT EXECUTOR BINARY ===
extract_executor_binary() {
  local downloaded_file="${DOWNLOADED_FILE:-}"
  
  if [[ -z "$downloaded_file" || ! -f "$downloaded_file" ]]; then
    downloader_error_exit "No downloaded file to extract"
  fi
  
  downloader_log_info "📦 Extracting executor binary from: $downloaded_file"
  
  local filename=$(basename "$downloaded_file")
  
  # Determine extraction method based on file type
  if [[ "$filename" =~ \.tar\.gz$ ]] || [[ "$filename" =~ \.tgz$ ]]; then
    # Extract tar.gz archive
    downloader_log_info "🔧 Extracting tar.gz archive..."
    
    if tar -xzf "$downloaded_file" -C "$T3RN_DIR" --strip-components=0; then
      downloader_log_info "✅ Archive extracted successfully"
    else
      downloader_error_exit "Failed to extract archive"
    fi
    
  elif [[ "$filename" =~ \.zip$ ]]; then
    # Extract zip archive
    downloader_log_info "🔧 Extracting zip archive..."
    
    if command -v unzip >/dev/null 2>&1; then
      if unzip -q "$downloaded_file" -d "$T3RN_DIR"; then
        downloader_log_info "✅ Archive extracted successfully"
      else
        downloader_error_exit "Failed to extract zip archive"
      fi
    else
      downloader_error_exit "unzip command not available"
    fi
    
  else
    # Assume it's a direct binary
    downloader_log_info "🔧 Copying binary file..."
    
    local binary_dir="$T3RN_DIR/executor/executor/bin"
    mkdir -p "$binary_dir"
    
    if cp "$downloaded_file" "$binary_dir/executor"; then
      downloader_log_info "✅ Binary copied successfully"
    else
      downloader_error_exit "Failed to copy binary"
    fi
  fi
  
  # Find the executor binary
  local executor_binary=""
  local search_paths=(
    "$T3RN_DIR/executor/executor/bin/executor"
    "$T3RN_DIR/executor/bin/executor"
    "$T3RN_DIR/bin/executor"
    "$T3RN_DIR/executor"
  )
  
  for path in "${search_paths[@]}"; do
    if [[ -f "$path" ]]; then
      executor_binary="$path"
      break
    fi
  done
  
  # If not found, search recursively
  if [[ -z "$executor_binary" ]]; then
    executor_binary=$(find "$T3RN_DIR" -name "executor" -type f -executable 2>/dev/null | head -1)
  fi
  
  if [[ -z "$executor_binary" ]]; then
    downloader_error_exit "Executor binary not found after extraction"
  fi
  
  # Ensure the binary is in the expected location
  local expected_path="$T3RN_DIR/executor/executor/bin/executor"
  if [[ "$executor_binary" != "$expected_path" ]]; then
    downloader_log_info "📁 Moving executor binary to expected location..."
    
    mkdir -p "$(dirname "$expected_path")"
    mv "$executor_binary" "$expected_path" || downloader_error_exit "Failed to move executor binary"
    executor_binary="$expected_path"
  fi
  
  export EXECUTOR_PATH="$executor_binary"
  downloader_log_info "✅ Executor binary ready: $executor_binary"
}

# === SET PERMISSIONS AND VALIDATE ===
set_permissions_and_validate() {
  local executor_path="${EXECUTOR_PATH:-$T3RN_DIR/executor/executor/bin/executor}"
  
  downloader_log_info "🔧 Setting permissions and validating executor binary..."
  
  # Check if binary exists
  if [[ ! -f "$executor_path" ]]; then
    downloader_error_exit "Executor binary not found: $executor_path"
  fi
  
  # Set executable permissions
  if chmod +x "$executor_path"; then
    downloader_log_info "✅ Executable permissions set"
  else
    downloader_error_exit "Failed to set executable permissions"
  fi
  
  # Validate binary
  local file_info=$(file "$executor_path" 2>/dev/null || echo "unknown")
  downloader_log_info "📋 Binary info: $file_info"
  
  # Check if it's a valid ELF binary
  if [[ "$file_info" =~ "ELF 64-bit" ]]; then
    downloader_log_info "✅ Valid 64-bit ELF binary"
  elif [[ "$file_info" =~ "ELF" ]]; then
    downloader_log_warn "⚠️ ELF binary but may not be 64-bit"
  else
    downloader_log_warn "⚠️ Binary type unknown: $file_info"
  fi
  
  # Test binary execution (with timeout)
  downloader_log_info "🧪 Testing binary execution..."
  if timeout 10 "$executor_path" --help >/dev/null 2>&1; then
    downloader_log_info "✅ Binary execution test passed"
  else
    downloader_log_warn "⚠️ Binary execution test failed (may need dependencies)"
  fi
  
  # Clean up downloaded archive
  if [[ -n "${DOWNLOADED_FILE:-}" && -f "${DOWNLOADED_FILE}" ]]; then
    downloader_log_info "🧹 Cleaning up downloaded archive..."
    rm -f "${DOWNLOADED_FILE}"
  fi
  
  downloader_log_info "✅ Executor binary setup completed"
}

# === GET DOWNLOAD STATUS ===
get_download_status() {
  local executor_path="$T3RN_DIR/executor/executor/bin/executor"
  
  if [[ -f "$executor_path" && -x "$executor_path" ]]; then
    echo "READY: $(stat -c%s "$executor_path" 2>/dev/null || echo "unknown") bytes"
  else
    echo "NOT_FOUND"
  fi
}

# === VALIDATE DOWNLOAD CONFIGURATION ===
validate_download_configuration() {
  downloader_log_info "🔍 Validating download configuration..."
  
  # Check internet connectivity
  if ! ping -c 1 -W 5 github.com >/dev/null 2>&1; then
    downloader_log_warn "⚠️ Cannot reach GitHub"
    return 1
  fi
  
  # Check required tools
  local required_tools=("curl" "tar" "file" "stat")
  for tool in "${required_tools[@]}"; do
    if ! command -v "$tool" >/dev/null 2>&1; then
      downloader_log_warn "⚠️ Required tool missing: $tool"
      return 1
    fi
  done
  
  # Check write permissions
  if [[ ! -w "$SCRIPT_DIR" ]]; then
    downloader_log_warn "⚠️ No write permission in script directory"
    return 1
  fi
  
  downloader_log_info "✅ Download configuration validated"
  return 0
}

# === GENERATE DOWNLOAD REPORT ===
generate_download_report() {
  local report_file="${LOGS_DIR}/download_report.txt"
  
  downloader_log_info "📋 Generating download report..."
  
  {
    echo "T3RN EXECUTOR DOWNLOAD REPORT"
    echo "Generated: $(date)"
    echo "========================================"
    echo ""
    
    echo "Download Configuration:"
    echo "  🔗 Repository: $GITHUB_REPO_OWNER/$GITHUB_REPO_NAME"
    echo "  ⏱️ Timeout: $DOWNLOAD_TIMEOUT seconds"
    echo "  🔄 Max Retries: $MAX_RETRY_ATTEMPTS"
    echo "  ⏳ Retry Delay: $RETRY_DELAY seconds"
    echo ""
    
    echo "System Information:"
    echo "  🖥️ Architecture: $(detect_system_architecture)"
    echo "  🐧 OS: $(uname -s)"
    echo "  📁 Script Directory: $SCRIPT_DIR"
    echo "  📁 T3RN Directory: $T3RN_DIR"
    echo ""
    
    echo "Binary Status:"
    local executor_path="$T3RN_DIR/executor/executor/bin/executor"
    if [[ -f "$executor_path" ]]; then
      echo "  ✅ Binary: EXISTS"
      echo "  📁 Path: $executor_path"
      echo "  📊 Size: $(stat -c%s "$executor_path" 2>/dev/null || echo "unknown") bytes"
      echo "  🔧 Executable: $(test -x "$executor_path" && echo "YES" || echo "NO")"
      echo "  📋 Type: $(file "$executor_path" 2>/dev/null | cut -d: -f2 || echo "unknown")"
      echo "  📅 Modified: $(stat -c%y "$executor_path" 2>/dev/null || echo "unknown")"
    else
      echo "  ❌ Binary: NOT FOUND"
    fi
    echo ""
    
    echo "Download Commands:"
    echo "  Latest: ./modules/downloader.sh latest"
    echo "  Specific: ./modules/downloader.sh v1.0.0"
    echo "  Manual: curl -L https://github.com/t3rn/executor/releases/latest"
    echo ""
    
  } > "$report_file"
  
  downloader_log_info "✅ Download report saved: $report_file"
}

# Initialize on load
initialize_downloader

# Export functions
export -f initialize_downloader
export -f get_latest_release_info
export -f get_specific_release_info
export -f parse_release_info
export -f detect_system_architecture
export -f find_download_url_for_arch
export -f download_file_with_progress
export -f verify_download
export -f cleanup_previous_installation
export -f create_t3rn_directory
export -f download_executor_binary
export -f extract_executor_binary
export -f set_permissions_and_validate
export -f get_download_status
export -f validate_download_configuration
export -f generate_download_report
