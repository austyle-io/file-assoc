#!/usr/bin/env bash
# lib/parallel.sh - GNU Parallel Integration
#
# Provides a clean, modular API for parallel file processing using GNU Parallel.
# Replaces manual xargs-based parallelization with battle-tested parallel processing.
#
# Usage:
#   source lib/parallel.sh
#   parallel::init
#   parallel::process_files "my_function" true

# Ensure script is sourced, not executed
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  echo "Error: This file should be sourced, not executed directly" >&2
  echo "Usage: source ${BASH_SOURCE[0]}" >&2
  exit 1
fi

# Load dependencies
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/core.sh"

# ============================================================================
# MODULE VARIABLES
# ============================================================================

# Module version
# Guard against multiple sourcing
if [[ -n "${PARALLEL_MODULE_VERSION:-}" ]]; then
  return 0
fi

readonly PARALLEL_MODULE_VERSION="1.0.0"

# GNU Parallel availability flag
declare -g PARALLEL_AVAILABLE=false

# GNU Parallel version string
declare -g PARALLEL_VERSION=""

# Number of parallel workers (auto-detected or set by user)
declare -g PARALLEL_WORKERS=0

# ============================================================================
# INITIALIZATION
# ============================================================================

# Initialize the parallel module
#
# Checks if GNU Parallel is installed, detects version, and sets module variables.
# Returns 0 if parallel is available, 1 if not.
#
# Usage:
#   parallel::init
#   if [ $? -eq 0 ]; then
#     echo "Parallel is available"
#   fi
parallel::init() {
  # Check if GNU Parallel is installed
  if command -v parallel > /dev/null 2>&1; then
    PARALLEL_AVAILABLE=true

    # Get version string
    PARALLEL_VERSION=$(parallel --version 2>/dev/null | head -n 1 | sed 's/GNU parallel //' || echo "unknown")

    # Auto-detect worker count
    PARALLEL_WORKERS=$(parallel::get_workers)

    return 0
  else
    PARALLEL_AVAILABLE=false
    PARALLEL_VERSION=""
    PARALLEL_WORKERS=0

    return 1
  fi
}

# ============================================================================
# AVAILABILITY CHECKS
# ============================================================================

# Check if GNU Parallel is available
#
# Returns 0 if parallel is available, 1 if not.
#
# Usage:
#   if parallel::is_available; then
#     echo "Can use parallel processing"
#   fi
parallel::is_available() {
  [[ "$PARALLEL_AVAILABLE" = true ]]
}

# ============================================================================
# WORKER MANAGEMENT
# ============================================================================

# Get optimal worker count
#
# Auto-detects optimal worker count (75% of CPU cores) using platform-aware
# detection. Respects WORKERS environment variable if set.
#
# Returns worker count (1-128).
#
# Usage:
#   workers=$(parallel::get_workers)
#   echo "Using $workers workers"
parallel::get_workers() {
  local workers=0

  # Check if WORKERS env var is set
  if [[ -n "${WORKERS:-}" ]] && is_integer "$WORKERS" && [[ $WORKERS -gt 0 ]]; then
    workers=$WORKERS
  else
    # Auto-detect CPU cores (platform-aware)
    local cpu_cores
    if is_macos; then
      cpu_cores=$(sysctl -n hw.ncpu 2>/dev/null || echo "4")
    else
      cpu_cores=$(nproc 2>/dev/null || echo "4")
    fi

    # Use 75% of CPU cores (minimum 1, maximum 128)
    workers=$(( (cpu_cores * 3) / 4 ))
    [[ $workers -lt 1 ]] && workers=1
    [[ $workers -gt 128 ]] && workers=128
  fi

  echo "$workers"
}

# ============================================================================
# CORE EXECUTION
# ============================================================================

# Execute GNU Parallel with sensible defaults
#
# Runs parallel with standard options:
#   --jobs: Use PARALLEL_WORKERS
#   --keep-order: Maintain input order
#   --line-buffer: Line-buffered output
#   --halt soon,fail=1: Stop on first failure
#
# Usage:
#   parallel::run command args < input_file
#   echo "file1\nfile2" | parallel::run process_file
parallel::run() {
  if ! parallel::is_available; then
    echo "Error: GNU Parallel is not available" >&2
    echo "Install with: brew install parallel" >&2
    return 1
  fi

  local workers=$PARALLEL_WORKERS
  [[ $workers -eq 0 ]] && workers=$(parallel::get_workers)

  # Run parallel with sensible defaults
  parallel \
    --jobs "$workers" \
    --keep-order \
    --line-buffer \
    --halt soon,fail=1 \
    "$@"
}

# Execute GNU Parallel with progress indicators
#
# Same as parallel::run but adds:
#   --progress: Show progress bar
#   --eta: Show estimated time remaining
#
# Usage:
#   parallel::run_with_progress command args < input_file
parallel::run_with_progress() {
  if ! parallel::is_available; then
    echo "Error: GNU Parallel is not available" >&2
    echo "Install with: brew install parallel" >&2
    return 1
  fi

  local workers=$PARALLEL_WORKERS
  [[ $workers -eq 0 ]] && workers=$(parallel::get_workers)

  # Run parallel with progress
  parallel \
    --jobs "$workers" \
    --keep-order \
    --line-buffer \
    --halt soon,fail=1 \
    --progress \
    --eta \
    "$@"
}

# Execute GNU Parallel with custom options
#
# Advanced wrapper allowing custom parallel options. Provides base defaults
# but allows override via arguments.
#
# Usage:
#   parallel::run_custom --jobs 4 --no-keep-order command args < input_file
parallel::run_custom() {
  if ! parallel::is_available; then
    echo "Error: GNU Parallel is not available" >&2
    echo "Install with: brew install parallel" >&2
    return 1
  fi

  # Run parallel with custom options
  parallel "$@"
}

# ============================================================================
# HIGH-LEVEL FILE PROCESSING
# ============================================================================

# Process files in parallel using a custom function
#
# High-level wrapper that validates the function exists and calls the
# appropriate run method with progress indicators if requested.
#
# Arguments:
#   $1 - Function name to execute for each file
#   $2 - Show progress (true/false, default: false)
#
# The function must be exported with 'export -f function_name' before calling.
# Input is read from stdin (list of file paths, one per line).
#
# Usage:
#   process_single_file() {
#     local file=$1
#     echo "Processing: $file"
#   }
#   export -f process_single_file
#
#   find . -name "*.txt" | parallel::process_files "process_single_file" false
parallel::process_files() {
  local function_name=$1
  local show_progress=${2:-false}

  # Validate parallel is available
  if ! parallel::is_available; then
    echo "Error: GNU Parallel is not available" >&2
    echo "Install with: brew install parallel" >&2
    return 1
  fi

  # Validate function name is provided
  if [[ -z "$function_name" ]]; then
    echo "Error: Function name is required" >&2
    echo "Usage: parallel::process_files FUNCTION_NAME [SHOW_PROGRESS]" >&2
    return 1
  fi

  # Validate function exists
  if ! declare -f "$function_name" > /dev/null 2>&1; then
    echo "Error: Function '$function_name' does not exist" >&2
    echo "Make sure the function is defined and exported with: export -f $function_name" >&2
    return 1
  fi

  # Call appropriate run method
  if [[ "$show_progress" == "true" ]]; then
    parallel::run_with_progress "$function_name" "{}"
  else
    parallel::run "$function_name" "{}"
  fi
}

# ============================================================================
# VERSION & STATUS
# ============================================================================

# Get GNU Parallel version string
#
# Returns version string or "unknown" if not available.
#
# Usage:
#   version=$(parallel::version)
#   echo "Parallel version: $version"
parallel::version() {
  if parallel::is_available; then
    echo "$PARALLEL_VERSION"
  else
    echo "unknown"
  fi
}

# Display module status
#
# Shows availability, version, and worker count information.
#
# Usage:
#   parallel::status
parallel::status() {
  echo "GNU Parallel Module Status:"
  echo "  Version: $PARALLEL_MODULE_VERSION"
  echo ""

  if parallel::is_available; then
    echo "  GNU Parallel: ✓ Available"
    echo "  Version: $PARALLEL_VERSION"
    echo "  Workers: $PARALLEL_WORKERS (75% of CPU cores)"

    # Show actual CPU cores
    local cpu_cores
    if is_macos; then
      cpu_cores=$(sysctl -n hw.ncpu 2>/dev/null || echo "unknown")
    else
      cpu_cores=$(nproc 2>/dev/null || echo "unknown")
    fi
    echo "  CPU Cores: $cpu_cores"

    # Check if WORKERS env var is set
    if [[ -n "${WORKERS:-}" ]]; then
      echo "  Note: WORKERS environment variable is set to $WORKERS"
    fi
  else
    echo "  GNU Parallel: ✗ Not available"
    echo "  Install with: brew install parallel"
  fi
}

# ============================================================================
# EXPORTS
# ============================================================================

# Export functions for use in subshells/parallel workers
export -f parallel::init
export -f parallel::is_available
export -f parallel::get_workers
export -f parallel::run
export -f parallel::run_with_progress
export -f parallel::run_custom
export -f parallel::process_files
export -f parallel::version
export -f parallel::status

# ============================================================================
# AUTO-INITIALIZATION
# ============================================================================

# Auto-initialize on source (don't fail if parallel not available)
parallel::init || true

# Mark module as loaded
readonly PARALLEL_MODULE_LOADED=true
