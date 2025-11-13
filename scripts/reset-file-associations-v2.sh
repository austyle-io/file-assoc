#!/usr/bin/env bash
# Reset file associations for existing files by clearing extended attributes
# This forces files to use the system-wide defaults set by duti
#
# Version 2.0 - Fully modular implementation using lib/* modules
# Enhanced with comprehensive logging, resource limits, throttling, and parallel processing

set -euo pipefail

# ============================================================================
# MODULE IMPORTS
# ============================================================================

# Determine script directory for relative imports
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$(cd "$SCRIPT_DIR/../lib" && pwd)"

# Source all required modules
source "$LIB_DIR/core.sh"
source "$LIB_DIR/logging.sh"
source "$LIB_DIR/ui.sh"
source "$LIB_DIR/files.sh"
source "$LIB_DIR/xattr.sh"
source "$LIB_DIR/sampling.sh"
source "$LIB_DIR/parallel.sh"
source "$LIB_DIR/metrics.sh"

# ============================================================================
# CONFIGURATION & DEFAULTS
# ============================================================================

# Default file extensions to process (if none specified)
DEFAULT_EXTENSIONS=(
  "pdf" "doc" "docx" "xls" "xlsx" "ppt" "pptx"
  "jpg" "jpeg" "png" "gif" "bmp" "tiff"
  "mp4" "mov" "avi" "mkv" "mp3" "wav"
  "zip" "tar" "gz" "7z" "rar"
  "txt" "md" "rtf" "html" "css" "js"
)

# Runtime state
START_TIME=""
INTERRUPTED=false
LOG_DIR="${HOME}/.dotfiles-logs"

# Performance tracking
declare -A EXTENSION_METRICS_FILES
declare -A EXTENSION_METRICS_WITH_ATTRS
declare -A EXTENSION_METRICS_CLEARED
declare -a EXTENSION_ORDER

# ============================================================================
# SIGNAL HANDLING
# ============================================================================

# Handle interruption gracefully
handle_interrupt() {
  INTERRUPTED=true
  ui::newline
  ui::warn "Operation interrupted by user"

  # Display partial metrics if any
  if [[ ${#EXTENSION_ORDER[@]} -gt 0 ]]; then
    ui::info "Partial results:"
    metrics::report
  fi

  log::info "Script interrupted by user"
  ui::info "Log file: $(log::get_file)"

  exit 130
}

trap handle_interrupt SIGINT SIGTERM

# ============================================================================
# WORKER FUNCTION FOR PARALLEL PROCESSING
# ============================================================================

# Worker function that processes a single file
# This function is exported and called by GNU Parallel for each file
#
# Arguments:
#   $1 - File path to process
#
# Output:
#   Status line in format: "status:filepath"
#   Where status is one of: cleared, skipped, error
process_file_worker() {
  local file="$1"

  # Check if file has LaunchServices attribute
  if xattr::has_launch_services "$file"; then
    # File has the attribute
    if [[ "$DRY_RUN" = "on" ]]; then
      # Dry run - just report what would be done
      echo "would-clear:$file"
    else
      # Actually clear the attribute
      if xattr::clear_launch_services "$file" 2>/dev/null; then
        echo "cleared:$file"
      else
        echo "error:$file"
      fi
    fi
  else
    # File doesn't have the attribute
    echo "skipped:$file"
  fi
}

# Export the worker function so parallel can use it
export -f process_file_worker

# ============================================================================
# INITIALIZATION
# ============================================================================

# Initialize all modules and subsystems
initialize() {
  START_TIME=$(date +%s)

  # Initialize UI module
  ui::init

  # Initialize logging
  log::init "$LOG_DIR" "" "$LOG_LEVEL"
  log::info "=== File Association Reset v2.0 Started ==="
  log::info "Target directory: $TARGET_DIR"
  log::info "Log level: $LOG_LEVEL"

  # Initialize parallel processing
  parallel::init
  if parallel::is_available; then
    log::info "GNU Parallel available: version $(parallel::version)"
  else
    log::warn "GNU Parallel not available - will use sequential processing"
  fi

  # Initialize metrics tracking
  metrics::init

  # Check if xattr is available
  if ! xattr::is_available; then
    die "xattr command not found - required for this script"
  fi

  log::info "All modules initialized successfully"
}

# ============================================================================
# VALIDATION
# ============================================================================

# Validate arguments and configuration
validate_configuration() {
  log::info "Validating configuration..."

  # Validate target directory exists
  if ! files::validate_directory "$TARGET_DIR"; then
    die "Invalid target directory: $TARGET_DIR"
  fi

  # Convert to absolute path
  TARGET_DIR=$(files::get_absolute_dir "$TARGET_DIR")
  log::info "Using absolute path: $TARGET_DIR"

  # Use default extensions if none specified
  if [[ ${#EXTENSIONS[@]} -eq 0 ]]; then
    EXTENSIONS=("${DEFAULT_EXTENSIONS[@]}")
    log::info "Using default extensions (${#EXTENSIONS[@]} types)"
  else
    log::info "Using custom extensions: ${EXTENSIONS[*]}"
  fi

  # Validate numeric parameters
  if [[ "$MAX_FILES" -lt 1 ]]; then
    die "MAX_FILES must be at least 1"
  fi

  if [[ "$MAX_RATE" -lt 1 ]]; then
    die "MAX_RATE must be at least 1"
  fi

  log::info "Configuration validated successfully"
}

# ============================================================================
# USER INTERFACE
# ============================================================================

# Display header and configuration summary
display_header() {
  ui::header "File Association Reset v2.0"
  ui::newline

  ui::info "Target Directory: $TARGET_DIR"
  ui::info "Extensions: ${EXTENSIONS[*]}"
  ui::info "Max Files: $MAX_FILES"
  ui::info "Max Rate: $MAX_RATE files/sec"

  if [[ "$DRY_RUN" = "on" ]]; then
    ui::warn "DRY RUN MODE - No changes will be made"
  fi

  if [[ "$USE_PARALLEL" = "true" ]] && parallel::is_available; then
    local workers
    workers=$(parallel::get_workers)
    ui::info "Parallel Processing: $workers workers"
  else
    ui::info "Processing Mode: Sequential"
  fi

  ui::newline
}

# Confirm with user before proceeding
confirm_operation() {
  if [[ "$NO_CONFIRM" = "on" ]]; then
    log::info "Skipping confirmation (--no-confirm flag set)"
    return 0
  fi

  if ! ui::confirm "Proceed with file processing?"; then
    ui::info "Operation cancelled by user"
    log::info "Operation cancelled by user"
    exit 0
  fi

  log::info "User confirmed operation"
}

# ============================================================================
# SAMPLING PHASE
# ============================================================================

# Run sampling analysis to estimate scope
run_sampling_phase() {
  if [[ "$SKIP_SAMPLING" = "on" ]]; then
    log::info "Skipping sampling phase (--skip-sampling flag set)"
    return 0
  fi

  ui::info "Running sampling phase ($SAMPLE_SIZE files)..."
  log::info "Starting sampling phase with sample size: $SAMPLE_SIZE"

  # Run sampling analysis
  local result
  result=$(sampling::analyze "$TARGET_DIR" "$SAMPLE_SIZE" "${EXTENSIONS[@]}")

  # Parse results
  local sample_count hit_count hit_rate estimated_total estimated_hits
  sample_count=$(echo "$result" | grep "^sample_count=" | cut -d= -f2)
  hit_count=$(echo "$result" | grep "^hit_count=" | cut -d= -f2)
  hit_rate=$(echo "$result" | grep "^hit_rate=" | cut -d= -f2)
  estimated_total=$(echo "$result" | grep "^estimated_total=" | cut -d= -f2)
  estimated_hits=$(echo "$result" | grep "^estimated_hits=" | cut -d= -f2)

  log::info "Sampling results: $hit_count/$sample_count files have attributes ($hit_rate% hit rate)"
  log::info "Estimated totals: $estimated_hits/$estimated_total files"

  # Display results
  ui::success "Sampling complete"
  ui::info "  Sampled: $sample_count files"
  ui::info "  With attributes: $hit_count files ($hit_rate%)"
  ui::info "  Estimated total: ~$estimated_hits affected files"
  ui::newline

  # Warn if estimated total exceeds max files
  if [[ "$estimated_total" -gt "$MAX_FILES" ]]; then
    ui::warn "Estimated total ($estimated_total) exceeds MAX_FILES limit ($MAX_FILES)"
    ui::warn "Consider using --max-files to increase limit or specify fewer extensions"

    if [[ "$NO_CONFIRM" != "on" ]]; then
      if ! ui::confirm "Continue anyway?"; then
        ui::info "Operation cancelled"
        exit 0
      fi
    fi
  fi
}

# ============================================================================
# PROCESSING PHASE
# ============================================================================

# Process files for a single extension
process_extension() {
  local ext="$1"

  log::info "Processing extension: $ext"
  ui::info "Processing .$ext files..."

  # Track this extension
  EXTENSION_ORDER+=("$ext")
  metrics::start "$ext"

  # Find files with this extension
  local file_list
  file_list=$(files::find_by_ext "$TARGET_DIR" "$ext")

  # Count files
  local file_count
  file_count=$(echo "$file_list" | grep -c . || echo "0")

  if [[ "$file_count" -eq 0 ]]; then
    ui::info "  No .$ext files found"
    log::info "No files found for extension: $ext"
    metrics::end "$ext" 0 0 0
    return
  fi

  ui::info "  Found $file_count files"
  log::info "Found $file_count files with extension: $ext"

  # Check max files limit
  if [[ "$file_count" -gt "$MAX_FILES" ]]; then
    ui::warn "  File count ($file_count) exceeds MAX_FILES limit ($MAX_FILES)"
    log::warn "File count for $ext exceeds limit: $file_count > $MAX_FILES"
    ui::warn "  Skipping this extension"
    metrics::end "$ext" 0 0 0
    return
  fi

  # Process files
  local results
  local show_progress="false"
  if [[ "$VERBOSE" = "on" ]]; then
    show_progress="true"
  fi

  if [[ "$USE_PARALLEL" = "true" ]] && parallel::is_available; then
    # Use parallel processing
    log::info "Processing with parallel workers"
    results=$(echo "$file_list" | parallel::process_files "process_file_worker" "$show_progress")
  else
    # Use sequential processing
    log::info "Processing sequentially"
    results=""
    while IFS= read -r file; do
      [[ -z "$file" ]] && continue
      result=$(process_file_worker "$file")
      results+="$result"$'\n'

      if [[ "$show_progress" = "true" ]]; then
        echo "  $result" | sed 's/:/ /'
      fi
    done <<< "$file_list"
  fi

  # Parse results
  local cleared_count skipped_count error_count
  cleared_count=$(echo "$results" | grep -c "^cleared:" || echo "0")
  skipped_count=$(echo "$results" | grep -c "^skipped:" || echo "0")
  error_count=$(echo "$results" | grep -c "^error:" || echo "0")

  # Store metrics
  EXTENSION_METRICS_FILES["$ext"]=$file_count
  EXTENSION_METRICS_WITH_ATTRS["$ext"]=$cleared_count
  EXTENSION_METRICS_CLEARED["$ext"]=$cleared_count

  # Update metrics
  metrics::end "$ext" "$file_count" "$cleared_count" "$cleared_count"

  # Display summary for this extension
  ui::success "  Processed: $file_count files"
  if [[ "$cleared_count" -gt 0 ]]; then
    if [[ "$DRY_RUN" = "on" ]]; then
      ui::info "  Would clear: $cleared_count files"
    else
      ui::info "  Cleared: $cleared_count files"
    fi
  fi
  if [[ "$error_count" -gt 0 ]]; then
    ui::warn "  Errors: $error_count files"
  fi

  log::info "Extension $ext complete: processed=$file_count cleared=$cleared_count errors=$error_count"
  ui::newline
}

# Process all extensions
process_all_extensions() {
  ui::info "Starting file processing..."
  ui::newline
  log::info "Processing ${#EXTENSIONS[@]} extensions"

  for ext in "${EXTENSIONS[@]}"; do
    # Check for interruption
    if [[ "$INTERRUPTED" = "true" ]]; then
      break
    fi

    process_extension "$ext"
  done
}

# ============================================================================
# REPORTING PHASE
# ============================================================================

# Display final report
display_final_report() {
  ui::newline
  ui::header "Processing Complete"
  ui::newline

  # Display metrics
  metrics::report

  # Calculate totals
  local total_processed=0
  local total_cleared=0

  for ext in "${EXTENSION_ORDER[@]}"; do
    total_processed=$((total_processed + EXTENSION_METRICS_FILES["$ext"]))
    total_cleared=$((total_cleared + EXTENSION_METRICS_CLEARED["$ext"]))
  done

  # Display summary
  ui::newline
  ui::success "Summary:"
  ui::info "  Total files processed: $total_processed"
  if [[ "$DRY_RUN" = "on" ]]; then
    ui::info "  Would clear attributes: $total_cleared"
  else
    ui::info "  Attributes cleared: $total_cleared"
  fi

  # Calculate elapsed time
  local end_time elapsed_time
  end_time=$(date +%s)
  elapsed_time=$((end_time - START_TIME))
  ui::info "  Time elapsed: ${elapsed_time}s"

  # Display log file location
  ui::newline
  ui::info "Log file: $(log::get_file)"

  log::info "=== File Association Reset v2.0 Complete ==="
  log::info "Total processed: $total_processed, Total cleared: $total_cleared, Time: ${elapsed_time}s"
}

# ============================================================================
# MAIN ORCHESTRATION
# ============================================================================

main() {
  # Parse command-line arguments (this sets all the _arg_* variables and exports them)
  source "$LIB_DIR/args-parser.sh" "$@"

  # Initialize all modules
  initialize

  # Validate configuration
  validate_configuration

  # Display header and configuration
  display_header

  # Get user confirmation
  confirm_operation

  # Run sampling phase
  run_sampling_phase

  # Process all files
  process_all_extensions

  # Display final report
  display_final_report

  # Exit successfully
  exit 0
}

# ============================================================================
# SCRIPT ENTRY POINT
# ============================================================================

# Only run main if script is executed (not sourced)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi
