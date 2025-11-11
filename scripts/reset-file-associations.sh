#!/usr/bin/env bash
# Reset file associations for existing files by clearing extended attributes
# This forces files to use the system-wide default set by duti
#
# Enhanced with comprehensive logging, resource limits, and throttling

set -euo pipefail

# ============================================================================
# CONFIGURATION & CONSTANTS
# ============================================================================

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m' # No Color

# Command-line flags
DRY_RUN=false
VERBOSE=false
NO_CONFIRM=false
NO_THROTTLE=false
TARGET_DIR=""
EXTENSIONS=()

# Resource limits (can be overridden by env vars or flags)
MAX_FILES="${FILE_ASSOC_MAX_FILES:-10000}"    # Abort if more files found
MAX_RATE="${FILE_ASSOC_MAX_RATE:-100}"        # Files per second
MAX_MEMORY="${FILE_ASSOC_MAX_MEMORY:-500}"    # MB
BATCH_SIZE="${FILE_ASSOC_BATCH_SIZE:-1000}"   # Files per batch
BATCH_PAUSE="${FILE_ASSOC_BATCH_PAUSE:-1000}" # ms between batches
NICE_LEVEL="${FILE_ASSOC_NICE:-10}"           # Process priority (0-19)

# Parallel processing (can be overridden by env vars or flags)
WORKERS="${FILE_ASSOC_WORKERS:-0}"              # 0 = auto-detect CPU cores
CHUNK_SIZE="${FILE_ASSOC_CHUNK_SIZE:-100}"      # Files per xargs chunk
USE_PARALLEL="${FILE_ASSOC_USE_PARALLEL:-true}" # Enable parallel processing

# Sampling configuration (can be overridden by env vars or flags)
SAMPLE_SIZE="${FILE_ASSOC_SAMPLE_SIZE:-100}" # Number of files to sample
SKIP_SAMPLING=false                          # Skip sampling phase
# shellcheck disable=SC2034  # Reserved for future auto-skip logic based on hit rate
SAMPLE_THRESHOLD=0.05 # Minimum hit rate to proceed (5%)

# Logging configuration
LOG_LEVEL="${FILE_ASSOC_LOG_LEVEL:-INFO}" # DEBUG, INFO, WARN, ERROR
LOG_DIR="${HOME}/.dotfiles-logs"
LOG_FILE=""
LOG_BUFFER=()
LOG_BUFFER_SIZE=100
# shellcheck disable=SC2034  # Reserved for future log rotation feature
LOG_MAX_SIZE=$((10 * 1024 * 1024)) # 10MB
LOG_KEEP_COUNT=5

# Runtime state
SCRIPT_PID=$$
START_TIME=""
INTERRUPTED=false
TEMP_RESULTS_DIR=""
total_files=0
files_with_attrs=0
files_cleared=0
errors=0

# Performance metrics tracking
declare -A EXTENSION_METRICS_START
declare -A EXTENSION_METRICS_END
declare -A EXTENSION_METRICS_FILES
declare -A EXTENSION_METRICS_WITH_ATTRS
declare -A EXTENSION_METRICS_CLEARED
declare -a EXTENSION_ORDER

# ============================================================================
# LOGGING INFRASTRUCTURE
# ============================================================================

# Initialize logging
init_logging() {

  # Create log directory
  mkdir -p "$LOG_DIR"

  # Generate log file name with timestamp (unless custom log file specified)
  if [[ -z "$LOG_FILE" ]]; then
    local timestamp
    timestamp=$(date +%Y%m%d-%H%M%S)
    LOG_FILE="${LOG_DIR}/reset-file-associations-${timestamp}.log"
  fi

  # Rotate old logs (only if using auto-generated log files)
  if [[ "$LOG_FILE" == "$LOG_DIR"/reset-file-associations-* ]]; then
    rotate_logs
  fi

  # Create log file
  touch "$LOG_FILE" || {
    printf '%s\n' "Error: Cannot create log file: $LOG_FILE" >&2
    exit 1
  }

  # Log startup information
  log_info "STARTUP" "PID=$SCRIPT_PID USER=$USER DIR=$TARGET_DIR"
  log_info "CONFIG" "MAX_FILES=$MAX_FILES MAX_RATE=$MAX_RATE MAX_MEMORY=${MAX_MEMORY}MB BATCH_SIZE=$BATCH_SIZE"
  log_info "CONFIG" "LOG_LEVEL=$LOG_LEVEL NICE=$NICE_LEVEL DRY_RUN=$DRY_RUN"
}

# Rotate old log files
rotate_logs() {
  local log_files
  log_files=$(find "$LOG_DIR" -name "reset-file-associations-*.log" -type f 2> /dev/null | sort -r)

  # Exit early if no log files found
  if [[ -z "$log_files" ]]; then
    return 0
  fi

  local count=0
  while IFS= read -r log_file; do
    # Skip empty lines
    [[ -z "$log_file" ]] && continue

    count=$((count + 1))
    if [[ $count -gt $LOG_KEEP_COUNT ]]; then
      rm -f "$log_file"
    fi
  done <<< "$log_files"
}

# Get current timestamp in ISO8601 format (for log files)
get_timestamp() {
  date -u +"%Y-%m-%dT%H:%M:%S.%3NZ" 2> /dev/null || date -u +"%Y-%m-%dT%H:%M:%SZ"
}

# Get console timestamp (24-hour with milliseconds)
get_console_timestamp() {
  # Try to get milliseconds if available, otherwise just use seconds
  if command -v gdate > /dev/null 2>&1; then
    # GNU date (if installed via brew)
    gdate +%H:%M:%S.%3N
  elif date +%H:%M:%S.%N 2> /dev/null | grep -qv '%N'; then
    # If %N is supported, use it (Linux)
    date +%H:%M:%S.%3N
  else
    # macOS native date - no millisecond support, show .000
    date +%H:%M:%S.000
  fi
}

# Console logging with timestamp and log level
console_log() {
  local level=$1
  shift
  local message="$*"

  local timestamp
  timestamp=$(get_console_timestamp)

  local level_color=""
  local level_label=""

  case "$level" in
    INFO)
      level_color="${CYAN}"
      level_label="INFO "
      ;;
    WARN)
      level_color="${YELLOW}"
      level_label="WARN "
      ;;
    ERROR)
      level_color="${RED}"
      level_label="ERROR"
      ;;
    DEBUG)
      level_color="${MAGENTA}"
      level_label="DEBUG"
      ;;
    SUCCESS)
      level_color="${GREEN}"
      level_label="OK   "
      ;;
    *)
      level_color="${NC}"
      level_label="     "
      ;;
  esac

  printf '%b\n' "${CYAN}[${timestamp}]${NC} ${level_color}[${level_label}]${NC} ${message}"
}

# Log message with level
log_message() {
  local level=$1
  local operation=$2
  local message=$3

  # Check log level
  case "$LOG_LEVEL" in
    DEBUG) ;;
    INFO) [[ "$level" == "DEBUG" ]] && return ;;
    WARN) [[ "$level" == "DEBUG" || "$level" == "INFO" ]] && return ;;
    ERROR) [[ "$level" != "ERROR" && "$level" != "FATAL" ]] && return ;;
  esac

  local timestamp
  timestamp=$(get_timestamp)
  local log_line="[$timestamp] [$level] [$operation] $message"

  # Add to buffer
  LOG_BUFFER+=("$log_line")

  # Flush if buffer is full
  if [[ ${#LOG_BUFFER[@]} -ge $LOG_BUFFER_SIZE ]]; then
    flush_log_buffer
  fi
}

# Flush log buffer to file
flush_log_buffer() {
  if [[ ${#LOG_BUFFER[@]} -gt 0 && -n "$LOG_FILE" ]]; then
    printf '%s\n' "${LOG_BUFFER[@]}" >> "$LOG_FILE"
    LOG_BUFFER=()
  fi
}

# Convenience logging functions
log_debug() { log_message "DEBUG" "$1" "$2"; }
log_info() { log_message "INFO" "$1" "$2"; }
log_warn() { log_message "WARN" "$1" "$2"; }
log_error() { log_message "ERROR" "$1" "$2"; }
log_fatal() {
  log_message "FATAL" "$1" "$2"
  flush_log_buffer
}

# ============================================================================
# RESOURCE MONITORING
# ============================================================================

# Get current memory usage in MB (macOS)
get_memory_usage() {
  # Get RSS (Resident Set Size) in KB and convert to MB
  local rss_kb
  rss_kb=$(ps -o rss= -p $SCRIPT_PID 2> /dev/null || printf '%s\n' "0")
  printf '%s\n' "$((rss_kb / 1024))"
}

# Check if memory limit is exceeded
check_memory_limit() {
  local current_mb
  current_mb=$(get_memory_usage)

  if [[ $current_mb -gt $MAX_MEMORY ]]; then
    log_fatal "MEMORY" "LIMIT_EXCEEDED current=${current_mb}MB max=${MAX_MEMORY}MB"
    printf '%b\n' "${RED}Error: Memory limit exceeded (${current_mb}MB > ${MAX_MEMORY}MB)${NC}" >&2
    printf '%s\n' "See log: $LOG_FILE"
    cleanup_and_exit 1
  fi

  if [[ "$VERBOSE" = true ]]; then
    printf '%b' "\r${CYAN}Memory: ${current_mb}MB / ${MAX_MEMORY}MB${NC}  "
  fi
}

# Set process priority
set_process_priority() {
  if command -v renice > /dev/null 2>&1; then
    renice -n "$NICE_LEVEL" -p $SCRIPT_PID > /dev/null 2>&1 || true
    log_info "PRIORITY" "Set nice level to $NICE_LEVEL"
  fi
}

# Detect number of CPU cores
detect_cpu_cores() {
  local cores=1

  # Try various methods to detect CPU cores
  if command -v nproc > /dev/null 2>&1; then
    cores=$(nproc)
  elif command -v sysctl > /dev/null 2>&1; then
    cores=$(sysctl -n hw.ncpu 2> /dev/null || printf '%s\n' "1")
  elif [[ -f /proc/cpuinfo ]]; then
    cores=$(grep -c ^processor /proc/cpuinfo 2> /dev/null || printf '%s\n' "1")
  fi

  printf '%s\n' "$cores"
}

# ============================================================================
# SIGNAL HANDLING & CLEANUP
# ============================================================================

# Cleanup function with verbose status
cleanup_and_exit() {
  local exit_code=${1:-0}
  local show_verbose=${2:-false}

  if [[ "$show_verbose" = true ]]; then
    printf '\n'
    console_log INFO "${YELLOW}━━━ Cleanup Process ━━━${NC}"
  fi

  # Stop spinner if running
  if [[ -n "$SPINNER_PID" ]]; then
    [[ "$show_verbose" = true ]] && console_log INFO "Stopping spinner..."
    stop_spinner
    [[ "$show_verbose" = true ]] && console_log SUCCESS "Spinner stopped"
  fi

  # Stop quit monitor if running
  if [[ -n "$QUIT_MONITOR_PID" ]]; then
    [[ "$show_verbose" = true ]] && console_log INFO "Stopping quit monitor (PID: $QUIT_MONITOR_PID)..."
    stop_quit_monitor
    # Restore terminal to normal mode
    stty sane 2> /dev/null || true
    [[ "$show_verbose" = true ]] && console_log SUCCESS "Quit monitor stopped"
  fi

  # Stop progress monitor if running
  if [[ -n "$PROGRESS_MONITOR_PID" ]]; then
    [[ "$show_verbose" = true ]] && console_log INFO "Terminating progress monitor (PID: $PROGRESS_MONITOR_PID)..."
    kill "$PROGRESS_MONITOR_PID" 2> /dev/null || true
    wait "$PROGRESS_MONITOR_PID" 2> /dev/null || true
    [[ "$show_verbose" = true ]] && console_log SUCCESS "Progress monitor terminated"
    PROGRESS_MONITOR_PID=""
  fi

  # Kill any background worker processes
  if [[ -n "$TEMP_RESULTS_DIR" ]] && [[ -d "$TEMP_RESULTS_DIR" ]]; then
    [[ "$show_verbose" = true ]] && console_log INFO "Cleaning up temporary results..."
    # shellcheck disable=SC2155  # Worker count calculation is non-critical for cleanup
    local worker_count=$(find "$TEMP_RESULTS_DIR" -name "worker-*.log" -type f 2> /dev/null | wc -l | tr -d ' ')
    if [[ $worker_count -gt 0 ]]; then
      [[ "$show_verbose" = true ]] && console_log INFO "  Found ${worker_count} worker log files"
    fi
    rm -rf "$TEMP_RESULTS_DIR"
    [[ "$show_verbose" = true ]] && console_log SUCCESS "  Temporary directory removed"
  fi

  # Flush any remaining logs
  [[ "$show_verbose" = true ]] && console_log INFO "Flushing log buffer..."
  flush_log_buffer
  [[ "$show_verbose" = true ]] && console_log SUCCESS "  Logs flushed to disk"

  # Calculate duration
  local duration=0
  if [[ -n "$START_TIME" ]]; then
    local end_time
    end_time=$(date +%s)
    duration=$((end_time - START_TIME))
  fi

  # Log shutdown
  local reason="completed"
  [[ $INTERRUPTED = true ]] && reason="interrupted"
  [[ $exit_code -ne 0 ]] && reason="error"

  log_info "SHUTDOWN" "REASON=$reason FILES_SCANNED=$total_files FILES_CLEARED=$files_cleared ERRORS=$errors DURATION=${duration}s"
  flush_log_buffer

  # Final summary
  if [[ $INTERRUPTED = true ]] || [[ "$show_verbose" = true ]]; then
    printf '\n'
    if [[ $INTERRUPTED = true ]]; then
      printf '%b\n' "${YELLOW}╔═══════════════════════════════════════════════════════╗${NC}"
      printf '%b\n' "${YELLOW}║${NC}             Operation Cancelled by User             ${YELLOW}║${NC}"
      printf '%b\n' "${YELLOW}╚═══════════════════════════════════════════════════════╝${NC}"
    fi
    console_log INFO "${CYAN}Progress at shutdown:${NC}"
    console_log INFO "  Files scanned: ${total_files}"
    console_log INFO "  Files with associations: ${files_with_attrs}"
    console_log INFO "  Files cleared: ${files_cleared}"
    console_log INFO "  Errors: ${errors}"
    console_log INFO "  Duration: ${duration}s"
    console_log INFO "  Log: ${LOG_FILE}"
    printf '\n'
  fi

  [[ "$show_verbose" = true ]] && console_log SUCCESS "Cleanup complete, exiting..."

  exit "$exit_code"
}

# Signal handler with verbose feedback
# shellcheck disable=SC2329  # Called indirectly via trap in cleanup()
handle_signal() {
  local sig=$1

  # Clear the current line
  printf "\r%80s\r" ""

  printf '\n'
  printf '%b\n' "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  console_log WARN "${RED}⚠  Signal Received: ${YELLOW}${sig}${NC}"
  printf '%b\n' "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  printf '\n'
  console_log WARN "${YELLOW}Initiating graceful shutdown...${NC}"

  log_warn "SIGNAL" "Received $sig, shutting down gracefully..."
  INTERRUPTED=true

  # Show what we're about to clean up
  local cleanup_items=0
  [[ -n "$SPINNER_PID" ]] && ((cleanup_items++))
  [[ -n "$QUIT_MONITOR_PID" ]] && ((cleanup_items++))
  [[ -n "$PROGRESS_MONITOR_PID" ]] && ((cleanup_items++))
  [[ -n "$TEMP_RESULTS_DIR" && -d "$TEMP_RESULTS_DIR" ]] && ((cleanup_items++))

  if [[ $cleanup_items -gt 0 ]]; then
    console_log INFO "Found ${cleanup_items} background processes to clean up"
  fi

  cleanup_and_exit 130 true
}

# Monitor for user quit command
QUIT_MONITOR_PID=""

start_quit_monitor() {
  # Start a background process that monitors for 'q' key
  (
    # Save terminal settings
    local old_tty_settings
    old_tty_settings=$(stty -g 2> /dev/null)

    # Set terminal to raw mode for single character input
    stty -echo -icanon time 0 min 0 2> /dev/null

    while true; do
      # Read a single character with timeout
      local char
      char=$(dd bs=1 count=1 2> /dev/null)

      if [[ "$char" = "q" ]] || [[ "$char" = "Q" ]]; then
        # Restore terminal settings
        stty "$old_tty_settings" 2> /dev/null

        # Send SIGTERM to main process
        kill -TERM $$ 2> /dev/null
        exit 0
      fi

      sleep 0.1
    done
  ) &

  QUIT_MONITOR_PID=$!
}

stop_quit_monitor() {
  if [[ -n "$QUIT_MONITOR_PID" ]]; then
    kill "$QUIT_MONITOR_PID" 2> /dev/null || true
    wait "$QUIT_MONITOR_PID" 2> /dev/null || true
    QUIT_MONITOR_PID=""
  fi
}

# Set up signal handlers
trap 'handle_signal SIGINT' SIGINT
trap 'handle_signal SIGTERM' SIGTERM
trap 'handle_signal SIGQUIT' SIGQUIT

# ============================================================================
# THROTTLING & RATE LIMITING
# ============================================================================

# Sleep for throttling (in milliseconds)
throttle_sleep() {
  local sleep_ms=$1
  # shellcheck disable=SC2155  # Simple calculation, error unlikely
  local sleep_sec=$(awk "BEGIN {print $sleep_ms/1000}")
  sleep "$sleep_sec" 2> /dev/null || sleep 1
}

# Calculate and apply rate limiting
apply_rate_limit() {
  if [[ "$NO_THROTTLE" = true ]]; then
    return
  fi

  # Calculate time per file (in milliseconds)
  local ms_per_file=$((1000 / MAX_RATE))

  # Sleep if needed
  if [[ $ms_per_file -gt 0 ]]; then
    throttle_sleep $ms_per_file
  fi
}

# Batch pause
apply_batch_pause() {
  if [[ "$NO_THROTTLE" = true ]]; then
    return
  fi

  # shellcheck disable=SC2034  # batch_num reserved for future batch-specific logging
  local batch_num=$1
  if [[ $((total_files % BATCH_SIZE)) -eq 0 ]] && [[ $total_files -gt 0 ]]; then
    log_info "THROTTLE" "Batch pause after $total_files files"
    if [[ "$VERBOSE" = true ]]; then
      printf '%b\n' "\n${CYAN}Pausing between batches...${NC}"
    fi
    throttle_sleep "$BATCH_PAUSE"
  fi
}

# ============================================================================
# PROGRESS DISPLAY
# ============================================================================

# Spinner for indeterminate operations
SPINNER_PID=""
SPINNER_CHARS="⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏"

start_spinner() {
  local message=${1:-"Processing..."}

  # Hide cursor
  tput civis 2> /dev/null || true

  (
    local i=0
    while true; do
      local char="${SPINNER_CHARS:$i:1}"
      printf "\r${CYAN}%s${NC} %s" "$char" "$message"
      i=$(((i + 1) % ${#SPINNER_CHARS}))
      sleep 0.1
    done
  ) &

  SPINNER_PID=$!
}

stop_spinner() {
  if [[ -n "$SPINNER_PID" ]]; then
    kill "$SPINNER_PID" 2> /dev/null || true
    wait "$SPINNER_PID" 2> /dev/null || true
    SPINNER_PID=""
    printf "\r%80s\r" "" # Clear the line
    # Show cursor
    tput cnorm 2> /dev/null || true
  fi
}

# Show progress bar
show_progress() {
  local current=$1
  local total=$2
  local section_name=${3:-"Processing"}

  if [[ $total -eq 0 ]]; then
    return
  fi

  local percent=$((current * 100 / total))
  local bar_width=40
  local filled=$((bar_width * current / total))
  local empty=$((bar_width - filled))

  # Build progress bar
  local bar=""
  for ((i = 0; i < filled; i++)); do bar+="█"; done
  if [[ $filled -lt $bar_width ]]; then
    bar+="▓"
    for ((i = 0; i < empty - 1; i++)); do bar+="░"; done
  fi

  # Calculate rate based on batch start time (not global start time)
  local batch_start=${BATCH_START_TIME:-$START_TIME}
  local elapsed=$(($(date +%s) - batch_start))
  local rate=0
  if [[ $elapsed -gt 0 ]] && [[ $current -gt 0 ]]; then
    rate=$((current / elapsed))
  fi

  # Use minimum rate of 1/s to avoid infinite ETAs
  [[ $rate -eq 0 ]] && rate=1

  # Calculate ETA
  local remaining=$((total - current))
  local eta=$((remaining / rate))

  local eta_str="${eta}s"
  if [[ $eta -gt 60 ]]; then
    eta_str="$((eta / 60))m $((eta % 60))s"
  fi

  # Get timestamp for progress updates
  local timestamp
  timestamp=$(get_console_timestamp)

  printf "\r${CYAN}[%s]${NC} ${CYAN}[INFO ]${NC} ${CYAN}%s:${NC} [%s] ${GREEN}%3d%%${NC} (%d/%d) ${YELLOW}@%d/s${NC} ETA: ${MAGENTA}%s${NC}  " \
    "$timestamp" "$section_name" "$bar" "$percent" "$current" "$total" "$rate" "$eta_str"
}

# ============================================================================
# FILE PROCESSING
# ============================================================================

# Setup parallel processing infrastructure
setup_parallel_processing() {
  # Auto-detect workers if set to 0
  if [[ $WORKERS -eq 0 ]]; then
    WORKERS=$(detect_cpu_cores)
    log_info "PARALLEL" "Auto-detected $WORKERS CPU cores"
  fi

  # Create temporary directory for result files
  TEMP_RESULTS_DIR=$(mktemp -d "/tmp/file-assoc-results-$$.XXXXX")
  export TEMP_RESULTS_DIR

  log_info "PARALLEL" "Created results directory at $TEMP_RESULTS_DIR"
  return 0
}

# Collect results from parallel workers
collect_parallel_results() {
  if [[ -z "$TEMP_RESULTS_DIR" ]] || [[ ! -d "$TEMP_RESULTS_DIR" ]]; then
    return
  fi

  local processed=0
  local has_attr=0
  local cleared=0
  local errs=0

  # Count results from all worker log files using grep
  for worker_log in "$TEMP_RESULTS_DIR"/worker-*.log; do
    [[ -f "$worker_log" ]] || continue

    # Count occurrences using grep (much faster and won't block)
    local p
    local h
    local c
    local e
    p=$(grep -c "^PROCESSED$" "$worker_log" 2> /dev/null || printf '%s\n' "0")
    h=$(grep -c "^HAS_ATTR$" "$worker_log" 2> /dev/null || printf '%s\n' "0")
    c=$(grep -c "^CLEARED$" "$worker_log" 2> /dev/null || printf '%s\n' "0")
    e=$(grep -c "^ERROR$" "$worker_log" 2> /dev/null || printf '%s\n' "0")

    # Trim whitespace and add to counters
    processed=$((processed + ${p//[[:space:]]/}))
    has_attr=$((has_attr + ${h//[[:space:]]/}))
    cleared=$((cleared + ${c//[[:space:]]/}))
    errs=$((errs + ${e//[[:space:]]/}))
  done

  # Update global counters
  total_files=$((total_files + processed))
  files_with_attrs=$((files_with_attrs + has_attr))
  files_cleared=$((files_cleared + cleared))
  errors=$((errors + errs))

  log_info "PARALLEL" "Collected results: processed=$processed has_attr=$has_attr cleared=$cleared errors=$errs"
}

# Worker function (processes a single file and writes results to temp files)
# This will be called by xargs in parallel
# shellcheck disable=SC2329  # Called indirectly via bash -c in process_files_parallel()
process_file_worker() {
  local file=$1
  local results_dir=${TEMP_RESULTS_DIR:-/tmp}
  local worker_id=$$

  # Check if file has LaunchServices extended attribute
  if xattr "$file" 2> /dev/null | grep -q "com.apple.LaunchServices.OpenWith"; then
    printf '%s\n' "HAS_ATTR" >> "$results_dir/worker-$worker_id.log"

    # Clear the attribute (unless dry run)
    if [[ "${DRY_RUN:-false}" != "true" ]]; then
      if xattr -d com.apple.LaunchServices.OpenWith "$file" 2> /dev/null; then
        printf '%s\n' "CLEARED" >> "$results_dir/worker-$worker_id.log"
      else
        printf '%s\n' "ERROR" >> "$results_dir/worker-$worker_id.log"
      fi
    fi
  fi

  printf '%s\n' "PROCESSED" >> "$results_dir/worker-$worker_id.log"
}

# Legacy sequential processing function (kept for fallback)
process_file() {
  local file=$1
  local ext=$2

  ((total_files++))

  # Check memory every 100 files
  if [[ $((total_files % 100)) -eq 0 ]]; then
    check_memory_limit
  fi

  # Apply batch pause
  apply_batch_pause $total_files

  # Check if file has LaunchServices extended attribute
  if xattr "$file" 2> /dev/null | grep -q "com.apple.LaunchServices.OpenWith"; then
    ((files_with_attrs++))

    log_debug "CHECK" "FILE=$file HAS_ATTR=true"

    if [[ "$VERBOSE" = true ]] || [[ "$DRY_RUN" = true ]]; then
      printf '%b\n' "  ${YELLOW}•${NC} $(basename "$file")"
    fi

    # Clear the attribute (unless dry run)
    if [[ "$DRY_RUN" = false ]]; then
      if xattr -d com.apple.LaunchServices.OpenWith "$file" 2> /dev/null; then
        ((files_cleared++))
        log_info "CLEAR" "FILE=$file RESULT=success"

        if [[ "$VERBOSE" = true ]]; then
          printf '%b\n' "    ${GREEN}✓${NC} Cleared association"
        fi
      else
        ((errors++))
        log_error "CLEAR" "FILE=$file RESULT=failed ERROR=xattr_failed"
        printf '%b\n' "    ${RED}✗${NC} Failed to clear association" >&2
      fi
    fi

    # Apply rate limiting
    apply_rate_limit
  fi
}

# Monitor progress during parallel processing
PROGRESS_MONITOR_PID=""

monitor_parallel_progress() {
  local ext=$1
  local expected_total=$2
  local ui_progress=0
  local work_complete=false

  while true; do
    if [[ -z "$TEMP_RESULTS_DIR" ]] || [[ ! -d "$TEMP_RESULTS_DIR" ]]; then
      sleep 0.1
      continue
    fi

    # Count processed files so far (actual progress)
    local actual_progress=0
    shopt -s nullglob
    for worker_log in "$TEMP_RESULTS_DIR"/worker-*.log; do
      [[ -f "$worker_log" ]] || continue
      # shellcheck disable=SC2155  # Progress counting is non-critical, fallback to 0 on error
      local count=$(grep -c "^PROCESSED$" "$worker_log" 2> /dev/null || printf '%s\n' "0")
      actual_progress=$((actual_progress + count))
    done
    shopt -u nullglob

    # Check if work is complete
    if [[ -f "$TEMP_RESULTS_DIR/work_complete" ]]; then
      work_complete=true
      actual_progress=$expected_total
    fi

    # Smooth UI progress catch-up
    if [[ $actual_progress -gt $ui_progress ]]; then
      # Calculate catch-up rate: faster when further behind
      local diff=$((actual_progress - ui_progress))
      local catchup_rate=$((diff / 10))
      [[ $catchup_rate -lt 1 ]] && catchup_rate=1
      [[ $catchup_rate -gt 20 ]] && catchup_rate=20

      ui_progress=$((ui_progress + catchup_rate))
      [[ $ui_progress -gt $actual_progress ]] && ui_progress=$actual_progress
    fi

    # Show UI progress (not actual progress)
    if [[ $ui_progress -gt 0 ]] || [[ $expected_total -gt 0 ]]; then
      show_progress "$ui_progress" "$expected_total" "Processing .$ext files"
    fi

    # Exit when work complete AND UI caught up
    if [[ "$work_complete" == "true" ]] && [[ $ui_progress -ge $expected_total ]]; then
      # Signal that UI animation is complete
      touch "$TEMP_RESULTS_DIR/ui_complete"
      break
    fi

    sleep 0.1 # Faster updates for smoother animation
  done
}

# Process files in parallel using xargs
# Build find predicates for all extensions at once (single-pass optimization)
build_find_predicates() {
  local result=""
  local first=true

  for ext in "${EXTENSIONS[@]}"; do
    ext="${ext#.}"

    if [[ "$first" == true ]]; then
      result="-name \\*.${ext}"
      first=false
    else
      result="$result -o -name \\*.${ext}"
    fi
  done

  printf '%s' "$result"
}

# Enhanced worker that tags output with extension
# shellcheck disable=SC2329  # Called indirectly via bash -c in process_files_single_pass()
process_file_worker_with_ext() {
  local file=$1
  local results_dir=${TEMP_RESULTS_DIR:-/tmp}
  local worker_id=$$

  # Check if file has LaunchServices extended attribute
  if xattr "$file" 2> /dev/null | grep -q "com.apple.LaunchServices.OpenWith"; then
    printf '%s\n' "HAS_ATTR:$file" >> "$results_dir/worker-$worker_id.log"

    # Clear the attribute if not in dry-run mode
    if [[ "$DRY_RUN" != true ]]; then
      if xattr -d com.apple.LaunchServices.OpenWith "$file" 2> /dev/null; then
        printf '%s\n' "CLEARED:$file" >> "$results_dir/worker-$worker_id.log"
      else
        printf '%s\n' "ERROR:$file" >> "$results_dir/worker-$worker_id.log"
      fi
    else
      # In dry run, count as "would clear"
      printf '%s\n' "CLEARED:$file" >> "$results_dir/worker-$worker_id.log"
    fi
  fi

  # Always mark as processed (with filename for extension tracking)
  printf '%s\n' "PROCESSED:$file" >> "$results_dir/worker-$worker_id.log"
}

# Process ALL files in a single pass (optimized for large directories)
process_files_single_pass() {
  console_log INFO "${MAGENTA}Single-pass mode:${NC} processing all ${#EXTENSIONS[@]} extensions simultaneously"

  # Initialize metrics for all extensions
  for ext in "${EXTENSIONS[@]}"; do
    ext="${ext#.}"
    record_extension_start "$ext"
  done

  # Create temp directory for results
  TEMP_RESULTS_DIR=$(mktemp -d)
  export TEMP_RESULTS_DIR

  # Set batch start time
  BATCH_START_TIME=$(date +%s)
  export BATCH_START_TIME

  # Build find command with all extension patterns
  console_log INFO "Discovering and processing files in parallel..."
  log_info "SINGLE_PASS" "Processing all extensions with $WORKERS workers"

  # Build find predicate as array for proper argument handling
  local find_args=()
  local first=true
  for ext in "${EXTENSIONS[@]}"; do
    ext="${ext#.}"
    if [[ "$first" == true ]]; then
      find_args+=(-name "*.${ext}")
      first=false
    else
      find_args+=(-o -name "*.${ext}")
    fi
  done

  # Single find command for ALL files, process immediately
  # Inline worker logic to avoid function export issues
  find "$TARGET_DIR" -type f \( "${find_args[@]}" \) -print0 2> /dev/null \
    | xargs -0 -P "$WORKERS" -n "$CHUNK_SIZE" sh -c '
      results_dir="$1"
      dry_run="$2"
      shift 2
      for file in "$@"; do
        worker_id=$$

        # Check if file has LaunchServices extended attribute
        if xattr "$file" 2>/dev/null | grep -q "com.apple.LaunchServices.OpenWith"; then
          printf "%s\n" "HAS_ATTR:$file" >> "$results_dir/worker-$worker_id.log"

          # Clear the attribute if not in dry-run mode
          if [ "$dry_run" != "true" ]; then
            if xattr -d com.apple.LaunchServices.OpenWith "$file" 2>/dev/null; then
              printf "%s\n" "CLEARED:$file" >> "$results_dir/worker-$worker_id.log"
            else
              printf "%s\n" "ERROR:$file" >> "$results_dir/worker-$worker_id.log"
            fi
          else
            printf "%s\n" "CLEARED:$file" >> "$results_dir/worker-$worker_id.log"
          fi
        fi

        # Always mark as processed (with filename for extension tracking)
        printf "%s\n" "PROCESSED:$file" >> "$results_dir/worker-$worker_id.log"
      done
    ' _ "$TEMP_RESULTS_DIR" "$DRY_RUN" || true

  # Collect results per extension
  console_log INFO "Aggregating per-extension statistics..."

  local total_processed=0
  local total_with_attrs=0
  local total_cleared=0

  for ext in "${EXTENSIONS[@]}"; do
    ext="${ext#.}"

    # Count files processed for this extension from worker logs
    local ext_processed=0
    local ext_with_attrs=0
    local ext_cleared=0

    shopt -s nullglob
    for worker_log in "$TEMP_RESULTS_DIR"/worker-*.log; do
      [[ -f "$worker_log" ]] || continue

      # Count entries for this specific extension
      while IFS= read -r line; do
        case "$line" in
          PROCESSED:*".$ext")
            ((ext_processed++))
            ;;
          HAS_ATTR:*".$ext")
            ((ext_with_attrs++))
            ;;
          CLEARED:*".$ext")
            ((ext_cleared++))
            ;;
        esac
      done < "$worker_log"
    done
    shopt -u nullglob

    # Update global counters
    total_processed=$((total_processed + ext_processed))
    total_with_attrs=$((total_with_attrs + ext_with_attrs))
    total_cleared=$((total_cleared + ext_cleared))

    # Update metrics
    EXTENSION_METRICS_FILES["$ext"]=$ext_processed
    EXTENSION_METRICS_WITH_ATTRS["$ext"]=$ext_with_attrs
    EXTENSION_METRICS_CLEARED["$ext"]=$ext_cleared
    record_extension_end "$ext" "$ext_processed" "$ext_with_attrs" "$ext_cleared"

    # Show per-extension results if files were found
    if [[ $ext_processed -gt 0 ]]; then
      console_log INFO "  ${CYAN}.$ext${NC}: $ext_processed files ($ext_with_attrs with attrs, $ext_cleared cleared)"
    fi
  done

  # Update global stats
  total_files=$total_processed
  files_with_attrs=$total_with_attrs
  files_cleared=$total_cleared

  # Clean up
  rm -rf "$TEMP_RESULTS_DIR"

  console_log SUCCESS "Single-pass complete: processed $total_processed files across ${#EXTENSIONS[@]} extensions"
}

# Process files for extension in parallel (legacy per-extension mode)
process_files_parallel() {
  local ext=$1

  log_info "PARALLEL" "Processing .$ext files with $WORKERS workers, chunk size $CHUNK_SIZE"

  # Count files for progress tracking
  local file_count
  file_count=$(count_files_for_extension "$ext")

  # Clean up progress signal files from previous run
  rm -f "$TEMP_RESULTS_DIR/work_complete" "$TEMP_RESULTS_DIR/ui_complete"

  # Set batch start time for accurate ETA calculation
  BATCH_START_TIME=$(date +%s)
  export BATCH_START_TIME

  # Start progress monitor in background
  if [[ $file_count -gt 0 ]]; then
    monitor_parallel_progress "$ext" "$file_count" &
    PROGRESS_MONITOR_PID=$!
  fi

  # Export worker function and variables for xargs subshells
  export -f process_file_worker
  export DRY_RUN
  export TEMP_RESULTS_DIR

  # Process files in parallel
  # Use || true to prevent exit on xargs error
  # shellcheck disable=SC2016  # Single quotes intentional, variables expanded by inner bash
  find "$TARGET_DIR" -type f -name "*.${ext}" -print0 2> /dev/null \
    | xargs -0 -P "$WORKERS" -n "$CHUNK_SIZE" bash -c '
      for file in "$@"; do
        process_file_worker "$file"
      done
    ' _ || true

  # Signal that actual work is complete
  touch "$TEMP_RESULTS_DIR/work_complete"

  # Wait for UI animation to complete (smooth catch-up)
  local wait_timeout=0
  while [[ ! -f "$TEMP_RESULTS_DIR/ui_complete" ]] && [[ $wait_timeout -lt 30 ]]; do
    sleep 0.1
    wait_timeout=$((wait_timeout + 1))
  done

  # Stop progress monitor (should already be done)
  if [[ -n "$PROGRESS_MONITOR_PID" ]]; then
    kill "$PROGRESS_MONITOR_PID" 2> /dev/null || true
    wait "$PROGRESS_MONITOR_PID" 2> /dev/null || true
    PROGRESS_MONITOR_PID=""
  fi

  # Clear progress line and show final count
  printf "\r%150s\r" ""

  # Ensure all worker log files are flushed to disk
  sync
  sleep 0.1

  # Collect results from workers
  collect_parallel_results

  # Clear worker logs for next extension
  if [[ -n "$TEMP_RESULTS_DIR" ]] && [[ -d "$TEMP_RESULTS_DIR" ]]; then
    rm -f "$TEMP_RESULTS_DIR"/worker-*.log
  fi

  log_info "PARALLEL" "Completed processing .$ext files"
}

# Animate spinner in background while counting files
animate_spinner_for_scan() {
  local ext=$1
  local count_file=$2
  local running_file=$3
  local spinner_chars="⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏"
  local spinner_i=0

  while [[ -f "$running_file" ]]; do
    local count=0
    if [[ -f "$count_file" ]]; then
      count=$(cat "$count_file" 2> /dev/null || printf '%s\n' "0")
      count=${count:-0} # Ensure count is never empty
    fi

    local timestamp
    timestamp=$(get_console_timestamp)
    local char="${spinner_chars:$spinner_i:1}"
    printf "\r${CYAN}[%s]${NC} ${CYAN}[INFO ]${NC} ${CYAN}%s${NC} Scanning ${YELLOW}.%s${NC} files... ${GREEN}%d${NC} found" "$timestamp" "$char" "$ext" "$count" >&2

    spinner_i=$(((spinner_i + 1) % ${#spinner_chars}))
    sleep 0.15
  done
}

# Count files for an extension with progress updates
count_files_for_extension() {
  local ext=$1
  local show_progress=${2:-false}

  if [[ "$show_progress" = true ]]; then
    # Create temp files for inter-process communication
    # shellcheck disable=SC2155  # mktemp failure would be caught by subsequent file operations
    local count_file=$(mktemp "/tmp/scan_count_${ext}.XXXXX")
    local running_file="${count_file}.running"
    printf '%s\n' "0" > "$count_file"
    touch "$running_file"

    # Start background spinner animation
    animate_spinner_for_scan "$ext" "$count_file" "$running_file" &
    local spinner_pid=$!

    # Count files and update count file
    local count=0
    while IFS= read -r file; do
      ((count++))
      printf '%s\n' "$count" > "$count_file"
    done < <(find "$TARGET_DIR" -type f -name "*.${ext}" 2> /dev/null)

    # Stop spinner animation
    rm -f "$running_file"
    wait "$spinner_pid" 2> /dev/null || true

    # Final update with filled spinner (to stderr)
    local timestamp
    timestamp=$(get_console_timestamp)
    printf "\r${CYAN}[%s]${NC} ${CYAN}[INFO ]${NC} ${CYAN}⠿${NC} Scanning ${YELLOW}.%s${NC} files... ${GREEN}%d${NC} found\n" "$timestamp" "$ext" "$count" >&2

    # Cleanup
    rm -f "$count_file" "$running_file"

    # Return just the count (to stdout)
    printf '%s\n' "$count"
  else
    # Fast count without progress
    find "$TARGET_DIR" -type f -name "*.${ext}" 2> /dev/null | wc -l | tr -d ' '
  fi
}

# ============================================================================
# SAMPLING PHASE
# ============================================================================

# Sample files randomly for pre-scan analysis
sample_files_for_extension() {
  local ext=$1
  local sample_size=$2
  local total_files=$3

  # If sample size >= total files, just return all files
  if [[ $sample_size -ge $total_files ]]; then
    find "$TARGET_DIR" -type f -name "*.${ext}" 2> /dev/null
    return
  fi

  # Use shuf to randomly sample files
  find "$TARGET_DIR" -type f -name "*.${ext}" 2> /dev/null | shuf -n "$sample_size"
}

# Analyze sample to calculate hit rate
analyze_sample() {
  local sample_size_actual=0
  local sample_with_attr=0

  console_log INFO "${YELLOW}━━━ Sampling Phase ━━━${NC}" >&2
  console_log INFO "Analyzing sample of up to ${SAMPLE_SIZE} files to estimate hit rate..." >&2
  log_info "SAMPLE" "Starting sampling phase with sample_size=$SAMPLE_SIZE"

  # Collect sample files from all extensions
  local temp_sample_file
  temp_sample_file=$(mktemp)

  for ext in "${EXTENSIONS[@]}"; do
    ext="${ext#.}"

    # Count files for this extension
    local ext_count
    ext_count=$(count_files_for_extension "$ext" false)

    if [[ $ext_count -eq 0 ]]; then
      continue
    fi

    # Calculate proportional sample size for this extension
    local ext_sample_size=$((SAMPLE_SIZE * ext_count / total_file_count))
    [[ $ext_sample_size -lt 1 ]] && ext_sample_size=1

    console_log INFO "  Sampling ${ext_sample_size} .${ext} files (of ${ext_count} total)..." >&2

    # Get sample files
    sample_files_for_extension "$ext" "$ext_sample_size" "$ext_count" >> "$temp_sample_file"
  done

  # Check each sampled file for the attribute
  local spinner_chars="⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏"
  local spinner_i=0

  while IFS= read -r file; do
    ((sample_size_actual++))

    # Update spinner
    if [[ $((sample_size_actual % 5)) -eq 0 ]]; then
      local char="${spinner_chars:$spinner_i:1}"
      spinner_i=$(((spinner_i + 1) % ${#spinner_chars}))
      printf "\r${CYAN}%s${NC} Checking sample... %d/%d files" "$char" "$sample_size_actual" "$SAMPLE_SIZE" >&2
    fi

    # Check for attribute
    if xattr "$file" 2> /dev/null | grep -q "com.apple.LaunchServices.OpenWith"; then
      ((sample_with_attr++))
    fi
  done < "$temp_sample_file"

  # Clear spinner line
  printf "\r%80s\r" "" >&2

  rm -f "$temp_sample_file"

  # Calculate hit rate
  local hit_rate=0
  if [[ $sample_size_actual -gt 0 ]]; then
    hit_rate=$(awk "BEGIN {printf \"%.2f\", ($sample_with_attr / $sample_size_actual) * 100}")
  fi

  # Log results
  log_info "SAMPLE" "sample_size=$sample_size_actual with_attr=$sample_with_attr hit_rate=${hit_rate}%"

  # Display results
  printf '\n' >&2
  console_log SUCCESS "Sample analysis complete" >&2
  console_log INFO "  Sample size: ${sample_size_actual} files" >&2
  console_log INFO "  Files with custom associations: ${sample_with_attr}" >&2

  if [[ $sample_with_attr -eq 0 ]]; then
    console_log WARN "  Hit rate: ${RED}0.00%${NC}" >&2
  else
    console_log INFO "  Hit rate: ${GREEN}${hit_rate}%${NC}" >&2
  fi

  # Estimate total files that would need processing
  if [[ $sample_with_attr -gt 0 ]]; then
    local estimated_total=$((total_file_count * sample_with_attr / sample_size_actual))
    console_log INFO "  Estimated files needing reset: ~${estimated_total}" >&2
  fi

  printf '\n' >&2

  # Return hit rate for decision making
  printf '%s\n' "$sample_with_attr $sample_size_actual"
}

# Check if sampling indicates zero hit rate and prompt user
check_sampling_results() {
  local sample_with_attr=$1
  local sample_size_actual=$2

  if [[ $sample_with_attr -eq 0 ]] && [[ $sample_size_actual -ge 50 ]]; then
    console_log WARN "${YELLOW}━━━ Zero Hit Rate Detected ━━━${NC}"
    console_log WARN "No files with custom associations found in sample of ${sample_size_actual} files."
    console_log INFO ""
    console_log INFO "This suggests:"
    console_log INFO "  • System-wide defaults (duti) are being used correctly"
    console_log INFO "  • No per-file overrides exist in this directory"
    console_log INFO "  • Full scan would likely find ${RED}0 files${NC} to modify"
    console_log INFO ""
    console_log INFO "Recommendation: ${GREEN}Skip full scan${NC} to save time (~10 seconds)"
    printf '\n'
    if [[ "$NO_CONFIRM" != true ]]; then
      read -rp "Continue with full scan anyway? (y/N) " response
      if [[ ! "$response" =~ ^[Yy]$ ]]; then
        console_log INFO "Scan cancelled by user based on sampling results"
        log_info "SAMPLE" "User skipped full scan due to 0% hit rate"

        # Show what would have happened
        printf '\n'
        console_log INFO "If you had continued, the script would have:"
        console_log INFO "  • Scanned ${total_file_count} files"
        console_log INFO "  • Likely found 0 files with custom associations"
        console_log INFO "  • Taken approximately 10-15 seconds"
        printf '\n'
        console_log SUCCESS "Time saved: ~10-15 seconds ⚡"

        cleanup_and_exit 0
      fi
      console_log INFO "Proceeding with full scan as requested..."
      log_info "SAMPLE" "User chose to continue despite 0% hit rate"
    fi
  elif [[ $sample_with_attr -eq 0 ]]; then
    console_log WARN "Sample size (${sample_size_actual}) is small but shows 0% hit rate"
    console_log INFO "Proceeding with full scan for thorough analysis..."
  fi
}

# ============================================================================
# PERFORMANCE METRICS
# ============================================================================

# Get current timestamp in milliseconds (macOS compatible)
get_timestamp_ms() {
  python3 -c 'import time; print(int(time.time() * 1000))'
}

# Record start of extension processing
record_extension_start() {
  local ext=$1
  EXTENSION_ORDER+=("$ext")
  EXTENSION_METRICS_START["$ext"]=$(get_timestamp_ms)
  EXTENSION_METRICS_FILES["$ext"]=0
  EXTENSION_METRICS_WITH_ATTRS["$ext"]=0
  EXTENSION_METRICS_CLEARED["$ext"]=0
}

# Record end of extension processing
record_extension_end() {
  local ext=$1
  local files=$2
  local with_attrs=$3
  local cleared=$4

  EXTENSION_METRICS_END["$ext"]=$(get_timestamp_ms)
  EXTENSION_METRICS_FILES["$ext"]=$files
  EXTENSION_METRICS_WITH_ATTRS["$ext"]=$with_attrs
  # shellcheck disable=SC2034  # EXTENSION_METRICS_CLEARED reserved for detailed reporting
  EXTENSION_METRICS_CLEARED["$ext"]=$cleared
}

# Generate performance report
generate_performance_report() {
  printf '\n'
  printf '%b\n' "${BLUE}═══════════════════════════════════════════════════════${NC}"
  printf '%b\n' "${CYAN}Performance Report${NC}"
  printf '%b\n' "${BLUE}═══════════════════════════════════════════════════════${NC}"
  printf '\n'
  # Table header
  printf "${CYAN}%-16s %8s %8s %10s %8s${NC}\n" "Extension" "Files" "w/Attrs" "Duration" "Rate"
  printf '%s\n' "------------------------------------------------------------"

  local total_duration_ms=0
  local total_files_processed=0

  # Per-extension metrics
  for ext in "${EXTENSION_ORDER[@]}"; do
    local files=${EXTENSION_METRICS_FILES["$ext"]:-0}
    local with_attrs=${EXTENSION_METRICS_WITH_ATTRS["$ext"]:-0}
    local start_ms=${EXTENSION_METRICS_START["$ext"]:-0}
    local end_ms=${EXTENSION_METRICS_END["$ext"]:-0}

    if [[ $start_ms -gt 0 ]] && [[ $end_ms -gt 0 ]]; then
      local duration_ms=$((end_ms - start_ms))
      total_duration_ms=$((total_duration_ms + duration_ms))
      total_files_processed=$((total_files_processed + files))

      # shellcheck disable=SC2155  # Performance calculation, non-critical
      local duration_s=$(echo "scale=2; $duration_ms / 1000" | bc)

      local rate="0"
      if [[ $duration_ms -gt 0 ]] && [[ $files -gt 0 ]]; then
        # shellcheck disable=SC2155  # Performance calculation, non-critical
        rate=$(echo "scale=1; $files * 1000 / $duration_ms" | bc)
      fi

      # Color code by performance
      local color="${NC}"
      if [[ $files -gt 0 ]]; then
        local rate_int=${rate%.*}
        if [[ $rate_int -gt 50 ]]; then
          color="${GREEN}"
        elif [[ $rate_int -gt 10 ]]; then
          color="${YELLOW}"
        else
          color="${RED}"
        fi
      fi

      printf "${color}%-16s %8d %8d %9.2fs %7s/s${NC}\n" ".$ext" "$files" "$with_attrs" "$duration_s" "$rate"
    fi
  done

  printf '%s\n' "------------------------------------------------------------"

  # Summary statistics
  # shellcheck disable=SC2155  # Performance calculation, non-critical
  local total_duration_s=$(echo "scale=2; $total_duration_ms / 1000" | bc)
  local avg_rate="0"
  if [[ $total_duration_ms -gt 0 ]] && [[ $total_files_processed -gt 0 ]]; then
    # shellcheck disable=SC2155  # Performance calculation, non-critical
    avg_rate=$(echo "scale=1; $total_files_processed * 1000 / $total_duration_ms" | bc)
  fi

  printf '\n'
  printf "${CYAN}%-16s %8d %8d %9.2fs %7s/s${NC}\n" "TOTAL" "$total_files_processed" "$files_with_attrs" "$total_duration_s" "$avg_rate"
  printf '\n'
  # Top 5 fastest/slowest
  printf '%b\n' "${CYAN}Top 5 Fastest:${NC}"
  for ext in "${EXTENSION_ORDER[@]}"; do
    local files=${EXTENSION_METRICS_FILES["$ext"]:-0}
    local start_ms=${EXTENSION_METRICS_START["$ext"]:-0}
    local end_ms=${EXTENSION_METRICS_END["$ext"]:-0}

    if [[ $files -gt 0 ]] && [[ $start_ms -gt 0 ]] && [[ $end_ms -gt 0 ]]; then
      local duration_ms=$((end_ms - start_ms))
      # shellcheck disable=SC2155  # Top 5 calculation, non-critical
      local rate=$(echo "scale=1; $files * 1000 / $duration_ms" | bc)
      printf '%s\n' "$rate $ext"
    fi
  done | sort -rn | head -5 | while read -r rate ext; do
    printf "  ${GREEN}%-16s %7s files/s${NC}\n" ".$ext" "$rate"
  done

  printf '\n'
  printf '%b\n' "${CYAN}Top 5 Slowest:${NC}"
  for ext in "${EXTENSION_ORDER[@]}"; do
    local files=${EXTENSION_METRICS_FILES["$ext"]:-0}
    local start_ms=${EXTENSION_METRICS_START["$ext"]:-0}
    local end_ms=${EXTENSION_METRICS_END["$ext"]:-0}

    if [[ $files -gt 0 ]] && [[ $start_ms -gt 0 ]] && [[ $end_ms -gt 0 ]]; then
      local duration_ms=$((end_ms - start_ms))
      # shellcheck disable=SC2155  # Top 5 calculation, non-critical
      local rate=$(echo "scale=1; $files * 1000 / $duration_ms" | bc)
      printf '%s\n' "$rate $ext"
    fi
  done | sort -n | head -5 | while read -r rate ext; do
    printf "  ${RED}%-16s %7s files/s${NC}\n" ".$ext" "$rate"
  done

  printf '\n'
  printf '%b\n' "${BLUE}═══════════════════════════════════════════════════════${NC}"
}

# ============================================================================
# USAGE & ARGUMENT PARSING
# ============================================================================

usage() {
  cat << EOF
Usage: $(basename "$0") [OPTIONS] [DIRECTORY]

Reset file associations for existing files by clearing LaunchServices extended attributes.
This forces files to use the system-wide defaults set by duti.

Enhanced with comprehensive logging, resource limits, and throttling.

OPTIONS:
  -d, --dry-run          Show what would be changed without making changes
  -v, --verbose          Show detailed output with progress
  -p, --path PATH        Target directory path (takes precedence over positional arg)
  -e, --ext EXTENSION    Add file extension to process (can be used multiple times)
                         Default: processes common dev file extensions
  -h, --help             Show this help message

RESOURCE LIMITS:
  --max-files N          Maximum files to process (default: $MAX_FILES)
  --max-rate N           Maximum files per second (default: $MAX_RATE)
  --max-memory N         Maximum memory in MB (default: $MAX_MEMORY)
  --batch-size N         Files per batch (default: $BATCH_SIZE)
  --no-throttle          Disable all throttling (not recommended)
  --no-confirm           Skip confirmation prompts

PARALLEL PROCESSING:
  --workers N            Number of parallel workers (default: CPU cores, 0=auto)
  --chunk-size N         Files per worker chunk (default: $CHUNK_SIZE)
  --no-parallel          Disable parallel processing (sequential mode)

SAMPLING & OPTIMIZATION:
  --sample-size N        Number of files to sample before full scan (default: $SAMPLE_SIZE)
  --skip-sampling        Skip sampling phase and proceed directly to full scan

LOGGING:
  --log-level LEVEL      Set log level: DEBUG, INFO, WARN, ERROR (default: $LOG_LEVEL)
  --log-file PATH        Custom log file location (default: auto-generated)

ARGUMENTS:
  DIRECTORY             Directory to process (default: current directory)
                        Will process files recursively

ENVIRONMENT VARIABLES:
  FILE_ASSOC_MAX_FILES        Override default max files
  FILE_ASSOC_MAX_RATE         Override default rate limit
  FILE_ASSOC_MAX_MEMORY       Override default memory limit
  FILE_ASSOC_LOG_LEVEL        Override default log level
  FILE_ASSOC_WORKERS          Override default worker count
  FILE_ASSOC_CHUNK_SIZE       Override default chunk size
  FILE_ASSOC_USE_PARALLEL     Override parallel processing (true/false)
  FILE_ASSOC_SAMPLE_SIZE      Override default sample size

EXAMPLES:
  # Dry run with verbose output
  $(basename "$0") --dry-run --verbose

  # Reset only .md files in ~/Documents
  $(basename "$0") --ext md ~/Documents

  # Reset with custom limits
  $(basename "$0") --max-files 50000 --max-rate 200 ~/Projects

  # Use 8 parallel workers with larger chunks
  $(basename "$0") --workers 8 --chunk-size 200 ~/Danti

  # Sample 200 files before full scan (larger sample for big directories)
  $(basename "$0") --sample-size 200 ~/Projects

  # Skip sampling and scan all files immediately
  $(basename "$0") --skip-sampling ~/Danti

  # Sequential mode (no parallelization)
  $(basename "$0") --no-parallel ~/Projects

  # Disable throttling for maximum speed (use with caution)
  $(basename "$0") --no-throttle --no-confirm ~/Danti

LOGS:
  Logs are written to: $LOG_DIR/reset-file-associations-TIMESTAMP.log
  Last $LOG_KEEP_COUNT log files are kept, older logs are auto-deleted.

EOF
}

# Default extensions (matches duti config)
DEFAULT_EXTENSIONS=(
  "json" "jsonc" "json5" "yaml" "yml" "toml"
  "md" "markdown" "txt" "log"
  "sh" "bash" "zsh" "fish"
  "ts" "tsx" "js" "jsx" "mjs" "cjs"
  "py" "rs" "go" "java" "c" "cpp" "h" "hpp" "rb"
  "env" "envrc" "gitignore" "gitattributes"
  "csv" "tsv" "xml" "svg" "sql"
)

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    -d | --dry-run)
      DRY_RUN=true
      shift
      ;;
    -v | --verbose)
      VERBOSE=true
      shift
      ;;
    -e | --ext)
      if [[ -z "${2:-}" ]]; then
        printf '%b\n' "${RED}Error: --ext requires an argument${NC}" >&2
        exit 1
      fi
      EXTENSIONS+=("$2")
      shift 2
      ;;
    --max-files)
      if [[ -z "${2:-}" ]]; then
        printf '%b\n' "${RED}Error: --max-files requires an argument${NC}" >&2
        exit 1
      fi
      MAX_FILES=$2
      shift 2
      ;;
    --max-rate)
      if [[ -z "${2:-}" ]]; then
        printf '%b\n' "${RED}Error: --max-rate requires an argument${NC}" >&2
        exit 1
      fi
      MAX_RATE=$2
      shift 2
      ;;
    --max-memory)
      if [[ -z "${2:-}" ]]; then
        printf '%b\n' "${RED}Error: --max-memory requires an argument${NC}" >&2
        exit 1
      fi
      MAX_MEMORY=$2
      shift 2
      ;;
    --batch-size)
      if [[ -z "${2:-}" ]]; then
        printf '%b\n' "${RED}Error: --batch-size requires an argument${NC}" >&2
        exit 1
      fi
      BATCH_SIZE=$2
      shift 2
      ;;
    --workers)
      if [[ -z "${2:-}" ]]; then
        printf '%b\n' "${RED}Error: --workers requires an argument${NC}" >&2
        exit 1
      fi
      WORKERS=$2
      shift 2
      ;;
    --chunk-size)
      if [[ -z "${2:-}" ]]; then
        printf '%b\n' "${RED}Error: --chunk-size requires an argument${NC}" >&2
        exit 1
      fi
      CHUNK_SIZE=$2
      shift 2
      ;;
    --no-parallel)
      USE_PARALLEL=false
      shift
      ;;
    --sample-size)
      if [[ -z "${2:-}" ]]; then
        printf '%b\n' "${RED}Error: --sample-size requires an argument${NC}" >&2
        exit 1
      fi
      SAMPLE_SIZE=$2
      shift 2
      ;;
    --skip-sampling)
      SKIP_SAMPLING=true
      shift
      ;;
    --no-throttle)
      NO_THROTTLE=true
      shift
      ;;
    --no-confirm)
      NO_CONFIRM=true
      shift
      ;;
    --log-level)
      if [[ -z "${2:-}" ]]; then
        printf '%b\n' "${RED}Error: --log-level requires an argument${NC}" >&2
        exit 1
      fi
      LOG_LEVEL=$2
      shift 2
      ;;
    --log-file)
      if [[ -z "${2:-}" ]]; then
        printf '%b\n' "${RED}Error: --log-file requires an argument${NC}" >&2
        exit 1
      fi
      LOG_FILE=$2
      shift 2
      ;;
    -p | --path)
      if [[ -z "${2:-}" ]]; then
        printf '%b\n' "${RED}Error: --path requires an argument${NC}" >&2
        exit 1
      fi
      PATH_EXPLICIT="$2"
      shift 2
      ;;
    -h | --help)
      usage
      exit 0
      ;;
    -*)
      printf '%b\n' "${RED}Error: Unknown option: $1${NC}" >&2
      usage
      exit 1
      ;;
    *)
      if [[ -z "$TARGET_DIR" ]]; then
        TARGET_DIR="$1"
      else
        printf '%b\n' "${RED}Error: Multiple directories specified${NC}" >&2
        usage
        exit 1
      fi
      shift
      ;;
  esac
done

# ============================================================================
# MAIN LOGIC
# ============================================================================

# Set defaults
# --path/-p takes precedence over positional argument
if [[ -n "${PATH_EXPLICIT:-}" ]]; then
  TARGET_DIR="$PATH_EXPLICIT"
else
  TARGET_DIR="${TARGET_DIR:-.}"
fi

if [[ ${#EXTENSIONS[@]} -eq 0 ]]; then
  EXTENSIONS=("${DEFAULT_EXTENSIONS[@]}")
fi

# Validate directory
if [[ ! -d "$TARGET_DIR" ]]; then
  printf '%b\n' "${RED}Error: Directory not found: $TARGET_DIR${NC}" >&2
  exit 1
fi

# Convert to absolute path
TARGET_DIR=$(cd "$TARGET_DIR" && pwd)

# Initialize logging
init_logging

# Set process priority
set_process_priority

# Record start time
START_TIME=$(date +%s)

# Banner (55 chars wide content area)
printf '%b\n' "${BLUE}+-------------------------------------------------------+${NC}"
printf "${BLUE}|${NC}%-55s${BLUE}|${NC}\n" "  Reset File Associations via Extended Attributes"
printf "${BLUE}|${NC}%-55s${BLUE}|${NC}\n" "  Enhanced with Logging & Resource Management"
printf '%b\n' "${BLUE}+-------------------------------------------------------+${NC}"
printf '\n'
printf '%b\n' "${YELLOW}Target:${NC} $TARGET_DIR"
printf '%b\n' "${YELLOW}Mode:${NC} $([ "$DRY_RUN" = true ] && printf '%s\n' "DRY RUN (no changes)" || printf '%s\n' "LIVE (will modify files)")"
printf '%b\n' "${YELLOW}Extensions:${NC}"
# Format extensions into multiple lines (10 per line)
ext_line=""
ext_count=0
for ext in "${EXTENSIONS[@]}"; do
  ext_line+="$ext "
  ext_count=$((ext_count + 1))
  if [[ $ext_count -eq 10 ]]; then
    printf '%b\n' "  $ext_line"
    ext_line=""
    ext_count=0
  fi
done
# Print remaining extensions
[[ -n "$ext_line" ]] && printf '%b\n' "  $ext_line"
printf '%b\n' "${YELLOW}Log File:${NC} $LOG_FILE"
printf '\n'
printf '%b\n' "${CYAN}Resource Limits:${NC}"
printf '%b\n' "  Max files: $MAX_FILES"
printf '%b\n' "  Max rate: $MAX_RATE files/sec"
printf '%b\n' "  Max memory: ${MAX_MEMORY}MB"
printf '%b\n' "  Batch size: $BATCH_SIZE files"
[[ "$NO_THROTTLE" = true ]] && printf '%b\n' "  ${RED}Throttling: DISABLED${NC}"
printf '\n'
printf '%b\n' "${CYAN}Parallel Processing:${NC}"
if [[ "$USE_PARALLEL" = true ]]; then
  printf '%b\n' "  ${GREEN}Enabled${NC}"
  printf '%b\n' "  Workers: $WORKERS $([ "$WORKERS" -eq 0 ] && printf '%s\n' "(auto-detect)" || printf '')"
  printf '%b\n' "  Chunk size: $CHUNK_SIZE files"
else
  printf '%b\n' "  ${YELLOW}Disabled (sequential mode)${NC}"
fi
printf '\n'
# Count total files with progressive feedback
console_log INFO "Scanning directory for ${#EXTENSIONS[@]} file extensions..."
log_info "SCAN" "Starting file count"

total_file_count=0
for ext in "${EXTENSIONS[@]}"; do
  ext="${ext#.}"
  count=$(count_files_for_extension "$ext" true)
  total_file_count=$((total_file_count + count))
  log_info "SCAN" "EXTENSION=$ext COUNT=$count"
done

printf '\n'
console_log SUCCESS "Scan complete: ${GREEN}$total_file_count${NC} total files found"
log_info "SCAN" "TOTAL_FILES=$total_file_count"

# Check if exceeds max files limit
if [[ $total_file_count -gt $MAX_FILES ]]; then
  log_warn "SCAN" "File count exceeds limit: $total_file_count > $MAX_FILES"
  console_log WARN "${RED}Found $total_file_count files, exceeds limit of $MAX_FILES${NC}"

  if [[ "$NO_CONFIRM" != true ]]; then
    console_log WARN "This could take a long time and consume significant resources."
    read -rp "Continue anyway? (y/N) " response
    if [[ ! "$response" =~ ^[Yy]$ ]]; then
      log_info "SCAN" "User aborted due to file count"
      console_log INFO "Aborted by user"
      cleanup_and_exit 0
    fi
    log_info "SCAN" "User confirmed large file count"
  fi
fi

# Confirmation prompt for live mode
if [[ "$DRY_RUN" = false ]] && [[ "$NO_CONFIRM" != true ]] && [[ $total_file_count -gt 100 ]]; then
  console_log WARN "About to modify file associations for $total_file_count files."
  read -rp "Continue? (y/N) " response
  if [[ ! "$response" =~ ^[Yy]$ ]]; then
    log_info "CONFIRM" "User aborted before processing"
    console_log INFO "Aborted by user"
    cleanup_and_exit 0
  fi
  log_info "CONFIRM" "User confirmed operation"
fi

# Sampling phase (unless skipped)
if [[ "$SKIP_SAMPLING" = false ]] && [[ $total_file_count -ge 50 ]]; then
  printf '\n'
  # Run sampling analysis
  sampling_result=$(analyze_sample)

  # Parse results
  sample_with_attr=0
  sample_size_actual=0
  read -r sample_with_attr sample_size_actual <<< "$sampling_result"

  # Check if we should proceed based on sampling
  check_sampling_results "$sample_with_attr" "$sample_size_actual"
elif [[ "$SKIP_SAMPLING" = true ]]; then
  console_log INFO "Sampling skipped (--skip-sampling flag)"
  log_info "SAMPLE" "Sampling phase skipped by user"
elif [[ $total_file_count -lt 50 ]]; then
  console_log INFO "Sampling skipped (file count < 50)"
  log_info "SAMPLE" "Sampling phase skipped due to small file count: $total_file_count"
fi

printf '\n'
console_log INFO "Processing files..."
console_log INFO "${MAGENTA}Tip:${NC} Press ${YELLOW}Ctrl+C${NC} or ${YELLOW}q${NC} at any time to cancel with graceful cleanup"
printf '\n'
log_info "PROCESS" "Starting file processing"

# Start quit monitor for interactive cancellation
start_quit_monitor

# Setup parallel processing if enabled
if [[ "$USE_PARALLEL" = true ]]; then
  setup_parallel_processing || {
    log_warn "PARALLEL" "Failed to setup parallel processing, falling back to sequential"
    USE_PARALLEL=false
  }
fi

# Choose processing mode: single-pass (optimized) or per-extension (legacy)
# NOTE: Single-pass mode is experimental and currently disabled by default due to worker log bug
# To enable: export ENABLE_SINGLE_PASS=true
if [[ "$USE_PARALLEL" = true ]] && [[ ${#EXTENSIONS[@]} -gt 1 ]] && [[ "${ENABLE_SINGLE_PASS:-false}" = true ]]; then
  # SINGLE-PASS MODE: Process all extensions at once (massive speedup for large directories)
  # WARNING: Currently has bug where worker logs aren't created, causing 0 files processed
  printf '\n'
  console_log INFO "${MAGENTA}╔═══════════════════════════════════════════════════════╗${NC}"
  console_log INFO "${MAGENTA}║${NC}          Single-Pass Optimization Enabled           ${MAGENTA}║${NC}"
  console_log INFO "${MAGENTA}╚═══════════════════════════════════════════════════════╝${NC}"
  printf '\n'

  process_files_single_pass

else
  # PER-EXTENSION MODE: Process each extension separately (legacy behavior)
  console_log INFO "Using per-extension mode (${#EXTENSIONS[@]} extension(s))"

  for ext in "${EXTENSIONS[@]}"; do
    # Remove leading dot if present
    ext="${ext#.}"

    # Record metrics start
    record_extension_start "$ext"

    # Capture pre-extension counters
    pre_with_attrs=$files_with_attrs
    pre_cleared=$files_cleared

    # Show section header
    printf '\n'
    console_log INFO "${BLUE}━━━ Processing ${CYAN}.$ext${BLUE} files ━━━${NC}"

    log_info "EXTENSION" "Processing ext=$ext"

    # Count files for this extension
    ext_file_count=$(count_files_for_extension "$ext" false)

    # Use parallel processing if enabled, otherwise fall back to sequential
    if [[ "$USE_PARALLEL" = true ]]; then
      process_files_parallel "$ext"
      printf "\r%150s\r" "" # Clear any remaining progress output
      console_log SUCCESS "Completed .$ext files"
    else
      # Sequential processing (legacy) with spinner
      if [[ $ext_file_count -gt 0 ]]; then
        start_spinner "Processing $ext_file_count .$ext files (sequential mode)..."
      fi

      while IFS= read -r -d '' file; do
        process_file "$file" "$ext"
      done < <(find "$TARGET_DIR" -type f -name "*.${ext}" -print0 2> /dev/null)

      stop_spinner
      printf "\r%150s\r" "" # Clear any remaining progress output
      console_log SUCCESS "Completed .$ext files"
    fi

    # Calculate per-extension metrics
    ext_with_attrs=$((files_with_attrs - pre_with_attrs))
    ext_cleared=$((files_cleared - pre_cleared))

    # Record metrics end
    record_extension_end "$ext" "$ext_file_count" "$ext_with_attrs" "$ext_cleared"
  done
fi

# Clear progress line
[[ "$VERBOSE" = true ]] && echo ""

# Generate performance report
generate_performance_report

# Final summary
printf '\n'
printf '%b\n' "${BLUE}═══════════════════════════════════════════════════════${NC}"
console_log SUCCESS "${GREEN}Summary:${NC}"
console_log INFO "  Total files scanned: ${total_files}"
console_log INFO "  Files with custom associations: ${files_with_attrs}"

if [[ "$DRY_RUN" = false ]]; then
  console_log INFO "  Files reset to system default: ${GREEN}${files_cleared}${NC}"
  if [[ $errors -gt 0 ]]; then
    console_log ERROR "  Errors: ${RED}${errors}${NC}"
  fi
else
  console_log WARN "  ${YELLOW}(Dry run - no changes made)${NC}"
fi

# Resource usage
end_memory=$(get_memory_usage)
console_log INFO "  Peak memory usage: ${end_memory}MB"

# Duration
duration=$(($(date +%s) - START_TIME))
console_log INFO "  Duration: ${duration}s"

printf '\n'
console_log INFO "Log file: $LOG_FILE"
printf '%b\n' "${BLUE}═══════════════════════════════════════════════════════${NC}"

# Cleanup and exit
if [[ $errors -gt 0 ]]; then
  log_error "COMPLETE" "Finished with errors: $errors"
  cleanup_and_exit 1
else
  log_info "COMPLETE" "Finished successfully"
  cleanup_and_exit 0
fi
