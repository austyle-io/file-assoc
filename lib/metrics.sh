#!/usr/bin/env bash
# lib/metrics.sh - Performance tracking
#
# Track and report performance metrics for file processing operations.
# Records timing, throughput, and generates detailed performance reports.
#
# Usage:
#   source lib/metrics.sh
#   metrics::init
#   metrics::start "operation"
#   metrics::end "operation" 100 50
#   metrics::report

# Ensure script is sourced
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  echo "Error: This file should be sourced, not executed" >&2
  exit 1
fi

# Load dependencies
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/core.sh"

# Module version
# Guard against multiple sourcing
if [[ -n "${METRICS_MODULE_VERSION:-}" ]]; then
  return 0
fi

readonly METRICS_MODULE_VERSION="1.0.0"

# ============================================================================
# METRICS STATE
# ============================================================================

# Associative arrays for metrics storage
declare -gA METRICS_START=()
declare -gA METRICS_END=()
declare -gA METRICS_FILES=()
declare -gA METRICS_WITH_ATTRS=()
declare -gA METRICS_CLEARED=()

# Order of operations (for reporting)
declare -ga METRICS_ORDER=()

# ============================================================================
# INITIALIZATION
# ============================================================================

# Initialize metrics system
metrics::init() {
  METRICS_START=()
  METRICS_END=()
  METRICS_FILES=()
  METRICS_WITH_ATTRS=()
  METRICS_CLEARED=()
  METRICS_ORDER=()
}

# ============================================================================
# TIMING FUNCTIONS
# ============================================================================

# Get current timestamp in milliseconds
# Output:
#   Timestamp in milliseconds
metrics::get_timestamp_ms() {
  # Try Python3 first (most accurate)
  if command -v python3 >/dev/null 2>&1; then
    python3 -c 'import time; print(int(time.time() * 1000))'
    return
  fi

  # Fallback to date (less accurate on macOS)
  if command -v gdate >/dev/null 2>&1; then
    # GNU date (brew install coreutils)
    gdate +%s%3N
  elif date +%s%N 2>/dev/null | grep -qv '%N'; then
    # Linux date with nanoseconds
    local ns
    ns=$(date +%s%N)
    echo "$((ns / 1000000))"
  else
    # macOS native date - second precision only
    local s
    s=$(date +%s)
    echo "$((s * 1000))"
  fi
}

# ============================================================================
# RECORDING FUNCTIONS
# ============================================================================

# Record start of operation
# Arguments:
#   $1 - Operation name/ID
metrics::start() {
  local operation=$1

  [[ -z "$operation" ]] && return 1

  METRICS_ORDER+=("$operation")
  METRICS_START["$operation"]=$(metrics::get_timestamp_ms)
  METRICS_FILES["$operation"]=0
  METRICS_WITH_ATTRS["$operation"]=0
  METRICS_CLEARED["$operation"]=0
}

# Record end of operation
# Arguments:
#   $1 - Operation name/ID
#   $2 - Total files processed (optional)
#   $3 - Files with attributes (optional)
#   $4 - Files cleared (optional)
metrics::end() {
  local operation=$1
  local files=${2:-0}
  local with_attrs=${3:-0}
  local cleared=${4:-0}

  [[ -z "$operation" ]] && return 1

  METRICS_END["$operation"]=$(metrics::get_timestamp_ms)
  METRICS_FILES["$operation"]=$files
  METRICS_WITH_ATTRS["$operation"]=$with_attrs
  METRICS_CLEARED["$operation"]=$cleared
}

# Update operation metrics without ending timing
# Arguments:
#   $1 - Operation name/ID
#   $2 - Total files processed
#   $3 - Files with attributes (optional)
#   $4 - Files cleared (optional)
metrics::update() {
  local operation=$1
  local files=$2
  local with_attrs=${3:-0}
  local cleared=${4:-0}

  [[ -z "$operation" ]] && return 1

  METRICS_FILES["$operation"]=$files
  METRICS_WITH_ATTRS["$operation"]=$with_attrs
  METRICS_CLEARED["$operation"]=$cleared
}

# ============================================================================
# CALCULATION FUNCTIONS
# ============================================================================

# Get duration for operation in milliseconds
# Arguments:
#   $1 - Operation name/ID
# Output:
#   Duration in milliseconds
metrics::get_duration_ms() {
  local operation=$1

  [[ -z "$operation" ]] && { echo "0"; return 1; }

  local start_ms=${METRICS_START["$operation"]:-0}
  local end_ms=${METRICS_END["$operation"]:-0}

  [[ $start_ms -eq 0 ]] && { echo "0"; return 1; }
  [[ $end_ms -eq 0 ]] && { echo "0"; return 1; }

  echo "$((end_ms - start_ms))"
}

# Get duration for operation in seconds
# Arguments:
#   $1 - Operation name/ID
# Output:
#   Duration in seconds (with 2 decimal places)
metrics::get_duration_sec() {
  local operation=$1
  local duration_ms
  duration_ms=$(metrics::get_duration_ms "$operation")

  [[ $duration_ms -eq 0 ]] && { echo "0.00"; return 1; }

  awk "BEGIN {printf \"%.2f\", $duration_ms / 1000}"
}

# Calculate processing rate (files per second)
# Arguments:
#   $1 - Operation name/ID
# Output:
#   Rate in files/second (with 1 decimal place)
metrics::get_rate() {
  local operation=$1

  [[ -z "$operation" ]] && { echo "0.0"; return 1; }

  local files=${METRICS_FILES["$operation"]:-0}
  local duration_ms
  duration_ms=$(metrics::get_duration_ms "$operation")

  [[ $files -eq 0 ]] && { echo "0.0"; return 0; }
  [[ $duration_ms -eq 0 ]] && { echo "0.0"; return 1; }

  awk "BEGIN {printf \"%.1f\", $files * 1000 / $duration_ms}"
}

# ============================================================================
# REPORTING FUNCTIONS
# ============================================================================

# Generate performance report
# Arguments:
#   $1 - Color enabled (default: true)
# Output:
#   Formatted performance report
metrics::report() {
  local use_color=${1:-true}

  # Color codes
  local BLUE=""
  local CYAN=""
  local GREEN=""
  local YELLOW=""
  local RED=""
  local NC=""

  if [[ "$use_color" == "true" ]]; then
    BLUE='\033[0;34m'
    CYAN='\033[0;36m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    RED='\033[0;31m'
    NC='\033[0m'
  fi

  printf '\n'
  printf '%b\n' "${BLUE}═══════════════════════════════════════════════════════${NC}"
  printf '%b\n' "${CYAN}Performance Report${NC}"
  printf '%b\n' "${BLUE}═══════════════════════════════════════════════════════${NC}"
  printf '\n'

  # Table header
  printf "${CYAN}%-16s %8s %8s %10s %8s${NC}\n" "Operation" "Files" "w/Attrs" "Duration" "Rate"
  printf '%s\n' "------------------------------------------------------------"

  local total_duration_ms=0
  local total_files=0
  local total_with_attrs=0

  # Per-operation metrics
  for operation in "${METRICS_ORDER[@]}"; do
    local files=${METRICS_FILES["$operation"]:-0}
    local with_attrs=${METRICS_WITH_ATTRS["$operation"]:-0}
    local duration_sec
    duration_sec=$(metrics::get_duration_sec "$operation")
    local rate
    rate=$(metrics::get_rate "$operation")
    local duration_ms
    duration_ms=$(metrics::get_duration_ms "$operation")

    # Accumulate totals
    total_duration_ms=$((total_duration_ms + duration_ms))
    total_files=$((total_files + files))
    total_with_attrs=$((total_with_attrs + with_attrs))

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

    printf "${color}%-16s %8d %8d %9.2fs %7s/s${NC}\n" "$operation" "$files" "$with_attrs" "$duration_sec" "$rate"
  done

  printf '%s\n' "------------------------------------------------------------"

  # Summary statistics
  local total_duration_sec
  if [[ $total_duration_ms -gt 0 ]]; then
    total_duration_sec=$(awk "BEGIN {printf \"%.2f\", $total_duration_ms / 1000}")
  else
    total_duration_sec="0.00"
  fi

  local avg_rate="0.0"
  if [[ $total_duration_ms -gt 0 ]] && [[ $total_files -gt 0 ]]; then
    avg_rate=$(awk "BEGIN {printf \"%.1f\", $total_files * 1000 / $total_duration_ms}")
  fi

  printf '\n'
  printf "${CYAN}%-16s %8d %8d %9.2fs %7s/s${NC}\n" "TOTAL" "$total_files" "$total_with_attrs" "$total_duration_sec" "$avg_rate"
  printf '\n'

  # Top performers (if more than 1 operation)
  if [[ ${#METRICS_ORDER[@]} -gt 1 ]]; then
    metrics::report_top_performers "$use_color"
  fi

  printf '%b\n' "${BLUE}═══════════════════════════════════════════════════════${NC}"
}

# Report top 5 fastest and slowest operations
# Arguments:
#   $1 - Color enabled (default: true)
metrics::report_top_performers() {
  local use_color=${1:-true}

  local GREEN=""
  local RED=""
  local CYAN=""
  local NC=""

  if [[ "$use_color" == "true" ]]; then
    GREEN='\033[0;32m'
    RED='\033[0;31m'
    CYAN='\033[0;36m'
    NC='\033[0m'
  fi

  # Top 5 fastest
  printf '%b\n' "${CYAN}Top 5 Fastest:${NC}"
  for operation in "${METRICS_ORDER[@]}"; do
    local files=${METRICS_FILES["$operation"]:-0}
    [[ $files -eq 0 ]] && continue

    local rate
    rate=$(metrics::get_rate "$operation")
    printf '%s %s\n' "$rate" "$operation"
  done | sort -rn | head -5 | while read -r rate op; do
    printf "  ${GREEN}%-16s %7s files/s${NC}\n" "$op" "$rate"
  done

  printf '\n'

  # Top 5 slowest
  printf '%b\n' "${CYAN}Top 5 Slowest:${NC}"
  for operation in "${METRICS_ORDER[@]}"; do
    local files=${METRICS_FILES["$operation"]:-0}
    [[ $files -eq 0 ]] && continue

    local rate
    rate=$(metrics::get_rate "$operation")
    printf '%s %s\n' "$rate" "$operation"
  done | sort -n | head -5 | while read -r rate op; do
    printf "  ${RED}%-16s %7s files/s${NC}\n" "$op" "$rate"
  done

  printf '\n'
}

# Generate simple summary (one-line)
# Output:
#   Simple summary string
metrics::summary() {
  local total_files=0
  local total_duration_ms=0

  for operation in "${METRICS_ORDER[@]}"; do
    local files=${METRICS_FILES["$operation"]:-0}
    local duration_ms
    duration_ms=$(metrics::get_duration_ms "$operation")

    total_files=$((total_files + files))
    total_duration_ms=$((total_duration_ms + duration_ms))
  done

  local duration_sec
  duration_sec=$(awk "BEGIN {printf \"%.2f\", $total_duration_ms / 1000}")

  local rate="0.0"
  if [[ $total_duration_ms -gt 0 ]] && [[ $total_files -gt 0 ]]; then
    rate=$(awk "BEGIN {printf \"%.1f\", $total_files * 1000 / $total_duration_ms}")
  fi

  echo "Processed $total_files files in ${duration_sec}s (${rate} files/s)"
}

# ============================================================================
# EXPORTS
# ============================================================================

# Export functions for use in subshells/parallel workers
export -f metrics::init
export -f metrics::get_timestamp_ms
export -f metrics::start
export -f metrics::end
export -f metrics::update
export -f metrics::get_duration_ms
export -f metrics::get_duration_sec
export -f metrics::get_rate
export -f metrics::report
export -f metrics::report_top_performers
export -f metrics::summary

# Mark module as loaded
readonly METRICS_MODULE_LOADED=true
