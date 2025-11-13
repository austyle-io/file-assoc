#!/usr/bin/env bash
# lib/parallel.sh - GNU Parallel integration for parallel file processing
#
# This module provides wrappers around GNU Parallel for efficient parallel
# file processing with automatic load balancing, progress tracking, and
# error handling.
#
# Functions:
#   parallel::init()            - Check GNU Parallel availability
#   parallel::get_workers()     - Auto-detect optimal worker count
#   parallel::process_files()   - Process files in parallel with progress
#   parallel::run()            - Generic parallel runner
#   parallel::run_with_progress() - Run with built-in progress bar
#   parallel::is_available()   - Check if GNU Parallel is available

set -euo pipefail

# Module-level variables
declare -g PARALLEL_AVAILABLE=false
declare -g PARALLEL_VERSION=""
declare -g PARALLEL_WORKERS=0

#######################################
# Initialize parallel processing module
# Checks for GNU Parallel availability and sets up configuration
# Globals:
#   PARALLEL_AVAILABLE - Set to true if GNU Parallel is available
#   PARALLEL_VERSION - Version string of GNU Parallel
#   PARALLEL_WORKERS - Number of workers (0 = auto-detect)
# Arguments:
#   None
# Returns:
#   0 if GNU Parallel is available, 1 otherwise
#######################################
parallel::init() {
  if command -v parallel >/dev/null 2>&1; then
    PARALLEL_AVAILABLE=true
    PARALLEL_VERSION=$(parallel --version 2>/dev/null | head -n1 | awk '{print $3}')
    PARALLEL_WORKERS=$(parallel::get_workers)
    return 0
  else
    PARALLEL_AVAILABLE=false
    return 1
  fi
}

#######################################
# Check if GNU Parallel is available
# Globals:
#   PARALLEL_AVAILABLE
# Arguments:
#   None
# Returns:
#   0 if available, 1 otherwise
#######################################
parallel::is_available() {
  [[ "$PARALLEL_AVAILABLE" == true ]]
}

#######################################
# Get optimal number of parallel workers
# Auto-detects CPU cores and returns optimal worker count
# Can be overridden with WORKERS environment variable
# Globals:
#   WORKERS - Optional override for worker count
# Arguments:
#   None
# Outputs:
#   Number of workers to use
# Returns:
#   0 on success
#######################################
parallel::get_workers() {
  local workers=${WORKERS:-0}

  # If workers explicitly set, use that
  if [[ $workers -gt 0 ]]; then
    echo "$workers"
    return 0
  fi

  # Auto-detect based on platform
  local cpu_count
  if [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS
    cpu_count=$(sysctl -n hw.ncpu 2>/dev/null || echo 4)
  else
    # Linux
    cpu_count=$(nproc 2>/dev/null || grep -c ^processor /proc/cpuinfo 2>/dev/null || echo 4)
  fi

  # Use 75% of CPU cores for parallel processing (leave some headroom)
  local optimal_workers=$(( cpu_count * 3 / 4 ))

  # Minimum of 1, maximum of cpu_count
  if [[ $optimal_workers -lt 1 ]]; then
    optimal_workers=1
  elif [[ $optimal_workers -gt $cpu_count ]]; then
    optimal_workers=$cpu_count
  fi

  echo "$optimal_workers"
}

#######################################
# Run command in parallel using GNU Parallel
# Basic wrapper around GNU Parallel with sensible defaults
# Globals:
#   PARALLEL_WORKERS
# Arguments:
#   $@ - Command and arguments to run in parallel
# Stdin:
#   List of items to process (one per line)
# Returns:
#   Exit code from GNU Parallel
# Example:
#   find . -name "*.txt" | parallel::run process_file
#######################################
parallel::run() {
  if ! parallel::is_available; then
    echo "ERROR: GNU Parallel not available" >&2
    return 1
  fi

  local workers=${PARALLEL_WORKERS:-$(parallel::get_workers)}

  # Run GNU Parallel with:
  # --jobs: Number of parallel workers
  # --keep-order: Maintain input order in output
  # --line-buffer: Buffer output line by line (not character by character)
  # --halt: Stop on first error (soon,fail=1)
  parallel \
    --jobs "$workers" \
    --keep-order \
    --line-buffer \
    --halt soon,fail=1 \
    "$@"
}

#######################################
# Run command in parallel with progress bar
# Wrapper around GNU Parallel with built-in progress tracking
# Globals:
#   PARALLEL_WORKERS
# Arguments:
#   $@ - Command and arguments to run in parallel
# Stdin:
#   List of items to process (one per line)
# Returns:
#   Exit code from GNU Parallel
# Example:
#   find . -name "*.md" | parallel::run_with_progress process_file
#######################################
parallel::run_with_progress() {
  if ! parallel::is_available; then
    echo "ERROR: GNU Parallel not available" >&2
    return 1
  fi

  local workers=${PARALLEL_WORKERS:-$(parallel::get_workers)}

  # Run GNU Parallel with progress bar:
  # --progress: Show progress bar
  # --eta: Show estimated time of arrival
  parallel \
    --jobs "$workers" \
    --keep-order \
    --line-buffer \
    --halt soon,fail=1 \
    --progress \
    --eta \
    "$@"
}

#######################################
# Process files in parallel with custom function
# High-level wrapper for common file processing pattern
# Globals:
#   PARALLEL_WORKERS
# Arguments:
#   $1 - Function name to call for each file
#   $2 - Optional: Show progress (true/false, default: true)
# Stdin:
#   List of file paths (one per line)
# Returns:
#   Exit code from GNU Parallel
# Example:
#   files::find_by_ext "$DIR" "md" | parallel::process_files process_single_file
#######################################
parallel::process_files() {
  local func_name="$1"
  local show_progress="${2:-true}"

  if ! parallel::is_available; then
    echo "ERROR: GNU Parallel not available. Install with: brew install parallel" >&2
    return 1
  fi

  # Ensure function is exported for parallel to access
  if ! declare -F "$func_name" >/dev/null 2>&1; then
    echo "ERROR: Function '$func_name' not found or not exported" >&2
    echo "Hint: Use 'export -f $func_name' before calling parallel::process_files" >&2
    return 1
  fi

  if [[ "$show_progress" == "true" ]]; then
    parallel::run_with_progress "$func_name"
  else
    parallel::run "$func_name"
  fi
}

#######################################
# Run command in parallel with custom options
# Advanced wrapper allowing full control over GNU Parallel options
# Arguments:
#   $1 - Options string for GNU Parallel (e.g., "--jobs 4 --timeout 60")
#   $@ - Remaining args: command to run
# Stdin:
#   List of items to process
# Returns:
#   Exit code from GNU Parallel
# Example:
#   echo -e "file1\nfile2" | parallel::run_custom "--jobs 2 --timeout 30" process_file
#######################################
parallel::run_custom() {
  if ! parallel::is_available; then
    echo "ERROR: GNU Parallel not available" >&2
    return 1
  fi

  local parallel_opts="$1"
  shift

  # shellcheck disable=SC2086
  parallel $parallel_opts "$@"
}

#######################################
# Get version information
# Outputs:
#   GNU Parallel version string
# Returns:
#   0 if available, 1 otherwise
#######################################
parallel::version() {
  if parallel::is_available; then
    echo "$PARALLEL_VERSION"
    return 0
  else
    echo "GNU Parallel not available"
    return 1
  fi
}

#######################################
# Display module information and status
# Useful for debugging and verification
# Outputs:
#   Module status and configuration
#######################################
parallel::status() {
  echo "GNU Parallel Module Status:"
  echo "  Available: $PARALLEL_AVAILABLE"

  if parallel::is_available; then
    echo "  Version: $PARALLEL_VERSION"
    echo "  Workers: $PARALLEL_WORKERS (auto-detected: $(parallel::get_workers))"
    echo "  Command: $(command -v parallel)"
  else
    echo "  Status: Not installed"
    echo "  Install: brew install parallel"
  fi
}

# Auto-initialize on source
parallel::init || true
