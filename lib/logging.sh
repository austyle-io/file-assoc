#!/usr/bin/env bash
# lib/logging.sh - Simplified file logging
#
# Simple file-based logging without over-engineering. Handles log file creation,
# rotation, buffering, and log level filtering. Console output is handled by lib/ui.sh.
#
# Usage:
#   source lib/logging.sh
#   log::init "/var/log/myapp" "myapp.log" INFO 10
#   log::info "OPERATION" "message here"
#   log::flush

# Ensure script is sourced
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  echo "Error: This file should be sourced, not executed" >&2
  exit 1
fi

# Load dependencies
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/core.sh"

# Module version
readonly LOG_MODULE_VERSION="1.0.0"

# ============================================================================
# LOG CONFIGURATION
# ============================================================================

# Log state variables
LOG_DIR="${LOG_DIR:-}"
LOG_FILE="${LOG_FILE:-}"
LOG_LEVEL="${LOG_LEVEL:-INFO}"
LOG_KEEP_COUNT="${LOG_KEEP_COUNT:-10}"
LOG_BUFFER_SIZE="${LOG_BUFFER_SIZE:-100}"

# Log buffer for batching writes
declare -a LOG_BUFFER=()

# ============================================================================
# INITIALIZATION
# ============================================================================

# Initialize logging system
# Arguments:
#   $1 - Log directory path
#   $2 - Log file name (optional, auto-generated if not provided)
#   $3 - Log level (optional, default: INFO)
#   $4 - Keep count (optional, default: 10)
log::init() {
  local log_dir=${1:-}
  local log_file=${2:-}
  local log_level=${3:-INFO}
  local keep_count=${4:-10}

  # Validate log directory
  if [[ -z "$log_dir" ]]; then
    die "Log directory path required"
  fi

  # Create log directory
  mkdir -p "$log_dir" || die "Cannot create log directory: $log_dir"

  LOG_DIR="$log_dir"
  LOG_LEVEL="$log_level"
  LOG_KEEP_COUNT="$keep_count"

  # Generate log file name with timestamp if not provided
  if [[ -z "$log_file" ]]; then
    local timestamp
    timestamp=$(date +%Y%m%d-%H%M%S)
    LOG_FILE="${LOG_DIR}/file-assoc-${timestamp}.log"
  else
    LOG_FILE="${LOG_DIR}/${log_file}"
  fi

  # Rotate old logs before creating new one
  if [[ "$LOG_FILE" == "$LOG_DIR"/file-assoc-* ]]; then
    log::rotate
  fi

  # Create log file
  touch "$LOG_FILE" || die "Cannot create log file: $LOG_FILE"

  # Log initialization
  log::write "INFO" "STARTUP" "Logging initialized: file=$LOG_FILE level=$LOG_LEVEL"
}

# ============================================================================
# LOG ROTATION
# ============================================================================

# Rotate old log files, keeping only LOG_KEEP_COUNT most recent
log::rotate() {
  [[ -z "$LOG_DIR" ]] && return 0

  local log_files
  log_files=$(find "$LOG_DIR" -name "file-assoc-*.log" -type f 2>/dev/null | sort -r)

  # Exit early if no log files found
  [[ -z "$log_files" ]] && return 0

  local count=0
  while IFS= read -r log_file; do
    [[ -z "$log_file" ]] && continue
    count=$((count + 1))
    if [[ $count -gt $LOG_KEEP_COUNT ]]; then
      rm -f "$log_file"
    fi
  done <<< "$log_files"
}

# ============================================================================
# LOGGING FUNCTIONS
# ============================================================================

# Write log message to buffer (internal function)
# Arguments:
#   $1 - Log level (DEBUG, INFO, WARN, ERROR, FATAL)
#   $2 - Operation/component name
#   $3 - Message
log::write() {
  local level=$1
  local operation=$2
  local message=$3

  # Check if we should log this level
  case "$LOG_LEVEL" in
    DEBUG) ;;
    INFO) [[ "$level" == "DEBUG" ]] && return ;;
    WARN) [[ "$level" == "DEBUG" || "$level" == "INFO" ]] && return ;;
    ERROR) [[ "$level" != "ERROR" && "$level" != "FATAL" ]] && return ;;
  esac

  # Get ISO8601 timestamp
  local timestamp
  timestamp=$(get_iso_timestamp)

  # Format log line
  local log_line="[$timestamp] [$level] [$operation] $message"

  # Add to buffer
  LOG_BUFFER+=("$log_line")

  # Auto-flush if buffer is full
  if [[ ${#LOG_BUFFER[@]} -ge $LOG_BUFFER_SIZE ]]; then
    log::flush
  fi
}

# Flush log buffer to file
log::flush() {
  if [[ ${#LOG_BUFFER[@]} -gt 0 && -n "$LOG_FILE" ]]; then
    printf '%s\n' "${LOG_BUFFER[@]}" >> "$LOG_FILE" 2>/dev/null || true
    LOG_BUFFER=()
  fi
}

# ============================================================================
# CONVENIENCE FUNCTIONS
# ============================================================================

# Log debug message
# Arguments:
#   $1 - Operation/component name
#   $2 - Message
log::debug() {
  log::write "DEBUG" "$1" "$2"
}

# Log info message
# Arguments:
#   $1 - Operation/component name
#   $2 - Message
log::info() {
  log::write "INFO" "$1" "$2"
}

# Log warning message
# Arguments:
#   $1 - Operation/component name
#   $2 - Message
log::warn() {
  log::write "WARN" "$1" "$2"
}

# Log error message
# Arguments:
#   $1 - Operation/component name
#   $2 - Message
log::error() {
  log::write "ERROR" "$1" "$2"
}

# Log fatal error and flush immediately
# Arguments:
#   $1 - Operation/component name
#   $2 - Message
log::fatal() {
  log::write "FATAL" "$1" "$2"
  log::flush
}

# ============================================================================
# GETTERS
# ============================================================================

# Get current log file path
log::get_file() {
  echo "$LOG_FILE"
}

# Get current log level
log::get_level() {
  echo "$LOG_LEVEL"
}

# Set log level
# Arguments:
#   $1 - New log level (DEBUG, INFO, WARN, ERROR)
log::set_level() {
  local new_level=$1
  case "$new_level" in
    DEBUG|INFO|WARN|ERROR)
      LOG_LEVEL="$new_level"
      ;;
    *)
      log::warn "LOGGING" "Invalid log level: $new_level, keeping $LOG_LEVEL"
      ;;
  esac
}

# ============================================================================
# EXPORTS
# ============================================================================

# Export functions for use in subshells/parallel workers
export -f log::init
export -f log::rotate
export -f log::write
export -f log::flush
export -f log::debug
export -f log::info
export -f log::warn
export -f log::error
export -f log::fatal
export -f log::get_file
export -f log::get_level
export -f log::set_level

# Mark module as loaded
readonly LOG_MODULE_LOADED=true
