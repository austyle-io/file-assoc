#!/usr/bin/env bash
# lib/core.sh - Core utilities for file-assoc
#
# Fundamental utilities used across all modules:
# - Error handling and validation
# - Path manipulation
# - Platform detection
# - Common helper functions
#
# Usage:
#   source lib/core.sh
#   require_command "jq" "Install with: brew install jq"
#   die "Something went wrong"

# Ensure script is sourced, not executed
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  echo "Error: This file should be sourced, not executed directly" >&2
  echo "Usage: source ${BASH_SOURCE[0]}" >&2
  exit 1
fi

# ============================================================================
# CONSTANTS
# ============================================================================

# Version information
readonly CORE_VERSION="1.0.0"

# Platform detection results (cached)
declare -g PLATFORM=""
declare -g IS_MACOS=""
declare -g IS_LINUX=""

# ============================================================================
# ERROR HANDLING
# ============================================================================

# Exit with error message
# Usage: die "error message" [exit_code]
die() {
  local message=$1
  local exit_code=${2:-1}

  echo "Error: $message" >&2
  exit "$exit_code"
}

# Check if command exists, exit with message if not found
# Usage: require_command "jq" "Install with: brew install jq"
require_command() {
  local cmd=$1
  local install_msg=${2:-"Command '$cmd' is required but not found"}

  if ! command -v "$cmd" > /dev/null 2>&1; then
    die "$install_msg"
  fi
}

# Check bash version (require 4.0+)
# Usage: check_bash_version
check_bash_version() {
  local required_major=4
  local current_major="${BASH_VERSINFO[0]}"

  if [[ $current_major -lt $required_major ]]; then
    die "Bash $required_major.0+ required (found: $BASH_VERSION). Install with: brew install bash"
  fi
}

# Validate that a value is not empty
# Usage: require_value "$VAR" "variable name"
require_value() {
  local value=$1
  local name=$2

  if [[ -z "$value" ]]; then
    die "$name is required but not provided"
  fi
}

# ============================================================================
# PATH UTILITIES
# ============================================================================

# Get absolute path for a file or directory
# Usage: abs_path=$(get_absolute_path "relative/path")
get_absolute_path() {
  local path=$1

  # Check if path exists
  if [[ ! -e "$path" ]]; then
    echo "Error: Path does not exist: $path" >&2
    return 1
  fi

  # Get absolute path
  if [[ -d "$path" ]]; then
    (cd "$path" && pwd)
  else
    local dir_path base_name
    dir_path=$(cd "$(dirname "$path")" && pwd)
    base_name=$(basename "$path")
    echo "$dir_path/$base_name"
  fi
}

# Normalize extension (remove leading dot)
# Usage: ext=$(normalize_extension ".md")  # Returns "md"
normalize_extension() {
  local ext=$1
  echo "${ext#.}"
}

# Get script directory (directory containing the script)
# Usage: SCRIPT_DIR=$(get_script_dir)
get_script_dir() {
  local source="${BASH_SOURCE[1]}"
  local dir

  # Resolve symlinks
  while [[ -L "$source" ]]; do
    dir=$(cd -P "$(dirname "$source")" && pwd)
    source=$(readlink "$source")
    [[ $source != /* ]] && source="$dir/$source"
  done

  dir=$(cd -P "$(dirname "$source")" && pwd)
  echo "$dir"
}

# Check if path is absolute
# Usage: if is_absolute_path "/foo/bar"; then ...
is_absolute_path() {
  local path=$1
  [[ "$path" == /* ]]
}

# ============================================================================
# PLATFORM DETECTION
# ============================================================================

# Detect and cache platform information
# Called automatically on first use of platform functions
_detect_platform() {
  if [[ -n "$PLATFORM" ]]; then
    return 0
  fi

  case "$OSTYPE" in
    darwin*)
      PLATFORM="macos"
      IS_MACOS=true
      IS_LINUX=false
      ;;
    linux*)
      PLATFORM="linux"
      IS_MACOS=false
      IS_LINUX=true
      ;;
    *)
      PLATFORM="unknown"
      IS_MACOS=false
      IS_LINUX=false
      ;;
  esac
}

# Check if running on macOS
# Usage: if is_macos; then ...
is_macos() {
  _detect_platform
  [[ "$IS_MACOS" == true ]]
}

# Check if running on Linux
# Usage: if is_linux; then ...
is_linux() {
  _detect_platform
  [[ "$IS_LINUX" == true ]]
}

# Get platform name
# Usage: platform=$(get_platform)
get_platform() {
  _detect_platform
  echo "$PLATFORM"
}

# ============================================================================
# CPU & SYSTEM INFO
# ============================================================================

# Detect number of CPU cores
# Usage: cores=$(get_cpu_cores)
get_cpu_cores() {
  local cores=1

  if command -v nproc > /dev/null 2>&1; then
    cores=$(nproc)
  elif command -v sysctl > /dev/null 2>&1; then
    cores=$(sysctl -n hw.ncpu 2> /dev/null || echo "1")
  elif [[ -f /proc/cpuinfo ]]; then
    cores=$(grep -c ^processor /proc/cpuinfo 2> /dev/null || echo "1")
  fi

  echo "$cores"
}

# Get available memory in MB
# Usage: memory_mb=$(get_available_memory)
get_available_memory() {
  local memory_mb=0

  if is_macos; then
    # macOS: get physical memory
    local memory_bytes
    memory_bytes=$(sysctl -n hw.memsize 2> /dev/null || echo "0")
    memory_mb=$((memory_bytes / 1024 / 1024))
  elif is_linux; then
    # Linux: read from /proc/meminfo
    local memory_kb
    memory_kb=$(grep MemAvailable /proc/meminfo 2> /dev/null | awk '{print $2}')
    memory_mb=$((memory_kb / 1024))
  fi

  echo "$memory_mb"
}

# ============================================================================
# STRING UTILITIES
# ============================================================================

# Trim whitespace from string
# Usage: trimmed=$(trim "  hello  ")
trim() {
  local str=$1
  # Remove leading whitespace
  str="${str#"${str%%[![:space:]]*}"}"
  # Remove trailing whitespace
  str="${str%"${str##*[![:space:]]}"}"
  echo "$str"
}

# Convert string to lowercase
# Usage: lower=$(to_lower "HELLO")
to_lower() {
  echo "$1" | tr '[:upper:]' '[:lower:]'
}

# Convert string to uppercase
# Usage: upper=$(to_upper "hello")
to_upper() {
  echo "$1" | tr '[:lower:]' '[:upper:]'
}

# Check if string starts with prefix
# Usage: if starts_with "hello world" "hello"; then ...
starts_with() {
  local str=$1
  local prefix=$2
  [[ "$str" == "$prefix"* ]]
}

# Check if string ends with suffix
# Usage: if ends_with "hello.md" ".md"; then ...
ends_with() {
  local str=$1
  local suffix=$2
  [[ "$str" == *"$suffix" ]]
}

# ============================================================================
# ARRAY UTILITIES
# ============================================================================

# Check if array contains element
# Usage: if array_contains "foo" "${my_array[@]}"; then ...
array_contains() {
  local element=$1
  shift
  local arr=("$@")

  for item in "${arr[@]}"; do
    if [[ "$item" == "$element" ]]; then
      return 0
    fi
  done
  return 1
}

# Join array elements with delimiter
# Usage: result=$(array_join "," "${my_array[@]}")
array_join() {
  local delimiter=$1
  shift
  local arr=("$@")

  local result=""
  local first=true

  for item in "${arr[@]}"; do
    if [[ "$first" == true ]]; then
      result="$item"
      first=false
    else
      result="$result$delimiter$item"
    fi
  done

  echo "$result"
}

# ============================================================================
# VALIDATION
# ============================================================================

# Check if variable is a valid integer
# Usage: if is_integer "$value"; then ...
is_integer() {
  local value=$1
  [[ "$value" =~ ^[0-9]+$ ]]
}

# Check if file exists and is readable
# Usage: if is_readable_file "/path/to/file"; then ...
is_readable_file() {
  local file=$1
  [[ -f "$file" && -r "$file" ]]
}

# Check if directory exists and is readable
# Usage: if is_readable_dir "/path/to/dir"; then ...
is_readable_dir() {
  local dir=$1
  [[ -d "$dir" && -r "$dir" ]]
}

# Check if file exists and is writable
# Usage: if is_writable_file "/path/to/file"; then ...
is_writable_file() {
  local file=$1
  [[ -f "$file" && -w "$file" ]]
}

# Check if directory exists and is writable
# Usage: if is_writable_dir "/path/to/dir"; then ...
is_writable_dir() {
  local dir=$1
  [[ -d "$dir" && -w "$dir" ]]
}

# ============================================================================
# DATE & TIME
# ============================================================================

# Get current timestamp in seconds since epoch
# Usage: timestamp=$(get_timestamp)
get_timestamp() {
  date +%s
}

# Get ISO 8601 timestamp
# Usage: iso_time=$(get_iso_timestamp)
get_iso_timestamp() {
  date -u +"%Y-%m-%dT%H:%M:%SZ"
}

# Calculate duration between two timestamps
# Usage: duration=$(get_duration "$start_time" "$end_time")
get_duration() {
  local start=$1
  local end=$2
  echo $((end - start))
}

# Format duration in human-readable format
# Usage: formatted=$(format_duration 125)  # Returns "2m 5s"
format_duration() {
  local total_seconds=$1
  local hours=$((total_seconds / 3600))
  local minutes=$(((total_seconds % 3600) / 60))
  local seconds=$((total_seconds % 60))

  if [[ $hours -gt 0 ]]; then
    echo "${hours}h ${minutes}m ${seconds}s"
  elif [[ $minutes -gt 0 ]]; then
    echo "${minutes}m ${seconds}s"
  else
    echo "${seconds}s"
  fi
}

# ============================================================================
# TEMPORARY FILES
# ============================================================================

# Create temporary file
# Usage: tmpfile=$(create_temp_file)
create_temp_file() {
  mktemp "${TMPDIR:-/tmp}/file-assoc.XXXXX"
}

# Create temporary directory
# Usage: tmpdir=$(create_temp_dir)
create_temp_dir() {
  mktemp -d "${TMPDIR:-/tmp}/file-assoc.XXXXX"
}

# ============================================================================
# INITIALIZATION
# ============================================================================

# Auto-detect platform on load
_detect_platform

# Verify bash version
check_bash_version

# Export commonly used functions
export -f die
export -f require_command
export -f get_absolute_path
export -f normalize_extension
export -f is_macos
export -f is_linux
export -f get_platform
export -f get_cpu_cores
export -f trim
export -f is_integer

# Mark as loaded
readonly CORE_LOADED=true
