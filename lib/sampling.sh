#!/usr/bin/env bash
# lib/sampling.sh - Smart sampling logic
#
# Pre-scan sampling to estimate hit rates and skip clean directories.
# Randomly samples files to determine if full scan is needed.
#
# Usage:
#   source lib/sampling.sh
#   result=$(sampling::analyze "/path/to/dir" 100 "txt" "md" "doc")
#   hit_rate=$(sampling::calculate_rate 10 100)

# Ensure script is sourced
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  echo "Error: This file should be sourced, not executed" >&2
  exit 1
fi

# Load dependencies
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/core.sh"
source "$SCRIPT_DIR/files.sh"
source "$SCRIPT_DIR/xattr.sh"

# Module version
# Guard against multiple sourcing
if [[ -n "${SAMPLING_MODULE_VERSION:-}" ]]; then
  return 0
fi

readonly SAMPLING_MODULE_VERSION="1.0.0"

# ============================================================================
# SAMPLING OPERATIONS
# ============================================================================

# Get random sample of files for extension
# Arguments:
#   $1 - Directory path
#   $2 - Extension (without dot)
#   $3 - Sample size
#   $4 - Total files (optional, will count if not provided)
# Output:
#   List of file paths, one per line
sampling::get_sample() {
  local dir_path=$1
  local extension=$2
  local sample_size=$3
  local total_files=${4:-0}

  [[ -z "$dir_path" ]] && return 1
  [[ ! -d "$dir_path" ]] && return 1

  extension=$(normalize_extension "$extension")

  # Get total if not provided
  if [[ $total_files -eq 0 ]]; then
    total_files=$(files::count "$dir_path" "$extension")
  fi

  # If sample size >= total files, return all files
  if [[ $sample_size -ge $total_files ]]; then
    files::find_by_ext "$dir_path" "$extension"
    return
  fi

  # Use shuf to randomly sample files
  if command -v shuf >/dev/null 2>&1; then
    files::find_by_ext "$dir_path" "$extension" | shuf -n "$sample_size"
  else
    # Fallback: use sort -R if shuf not available
    files::find_by_ext "$dir_path" "$extension" | sort -R | head -n "$sample_size"
  fi
}

# Calculate hit rate from sample
# Arguments:
#   $1 - Number of files with attribute
#   $2 - Total sample size
# Output:
#   Hit rate as percentage (e.g., "15.50")
sampling::calculate_rate() {
  local with_attr=$1
  local sample_size=$2

  [[ $sample_size -eq 0 ]] && { echo "0.00"; return 1; }

  awk "BEGIN {printf \"%.2f\", ($with_attr / $sample_size) * 100}"
}

# Analyze sample for attribute presence
# Arguments:
#   $1 - Directory path
#   $2 - Sample size
#   $@ - Extensions to sample (e.g., "txt" "md" "doc")
# Output:
#   Two numbers: files_with_attr sample_size_actual
sampling::analyze() {
  local dir_path=$1
  local sample_size=$2
  shift 2
  local extensions=("$@")

  [[ -z "$dir_path" ]] && { echo "0 0"; return 1; }
  [[ ! -d "$dir_path" ]] && { echo "0 0"; return 1; }
  [[ ${#extensions[@]} -eq 0 ]] && { echo "0 0"; return 1; }

  # Get total file count across all extensions
  local total_file_count
  total_file_count=$(files::count_multiple "$dir_path" "${extensions[@]}")

  [[ $total_file_count -eq 0 ]] && { echo "0 0"; return 0; }

  # Create temp file for sample
  local temp_sample_file
  temp_sample_file=$(create_temp_file)

  # Collect proportional samples from each extension
  local ext
  for ext in "${extensions[@]}"; do
    ext=$(normalize_extension "$ext")

    # Count files for this extension
    local ext_count
    ext_count=$(files::count "$dir_path" "$ext")

    [[ $ext_count -eq 0 ]] && continue

    # Calculate proportional sample size for this extension
    local ext_sample_size=$((sample_size * ext_count / total_file_count))
    [[ $ext_sample_size -lt 1 ]] && ext_sample_size=1

    # Get sample files
    sampling::get_sample "$dir_path" "$ext" "$ext_sample_size" "$ext_count" >> "$temp_sample_file"
  done

  # Check each sampled file for the attribute
  local sample_size_actual=0
  local sample_with_attr=0

  while IFS= read -r file; do
    ((sample_size_actual++))

    if xattr::has_launch_services "$file"; then
      ((sample_with_attr++))
    fi
  done < "$temp_sample_file"

  # Cleanup
  rm -f "$temp_sample_file"

  # Return results
  echo "$sample_with_attr $sample_size_actual"
}

# Analyze single extension sample
# Arguments:
#   $1 - Directory path
#   $2 - Extension (without dot)
#   $3 - Sample size
# Output:
#   Two numbers: files_with_attr sample_size_actual
sampling::analyze_extension() {
  local dir_path=$1
  local extension=$2
  local sample_size=$3

  [[ -z "$dir_path" ]] && { echo "0 0"; return 1; }
  [[ ! -d "$dir_path" ]] && { echo "0 0"; return 1; }
  [[ -z "$extension" ]] && { echo "0 0"; return 1; }

  extension=$(normalize_extension "$extension")

  # Get total count
  local total_count
  total_count=$(files::count "$dir_path" "$extension")

  [[ $total_count -eq 0 ]] && { echo "0 0"; return 0; }

  # Get sample
  local sample_size_actual=0
  local sample_with_attr=0

  while IFS= read -r file; do
    ((sample_size_actual++))

    if xattr::has_launch_services "$file"; then
      ((sample_with_attr++))
    fi
  done < <(sampling::get_sample "$dir_path" "$extension" "$sample_size" "$total_count")

  # Return results
  echo "$sample_with_attr $sample_size_actual"
}

# ============================================================================
# DECISION FUNCTIONS
# ============================================================================

# Check if directory should be skipped based on sample
# Arguments:
#   $1 - Files with attribute
#   $2 - Sample size
#   $3 - Minimum sample size for decision (default: 50)
# Returns:
#   0 if should skip, 1 if should continue
sampling::should_skip() {
  local with_attr=$1
  local sample_size=$2
  local min_sample=${3:-50}

  # If sample is too small, don't skip
  [[ $sample_size -lt $min_sample ]] && return 1

  # If no files have the attribute, suggest skipping
  [[ $with_attr -eq 0 ]] && return 0

  # Otherwise, continue
  return 1
}

# Estimate total files needing processing based on sample
# Arguments:
#   $1 - Files with attribute in sample
#   $2 - Sample size
#   $3 - Total file count
# Output:
#   Estimated number of files needing processing
sampling::estimate_total() {
  local with_attr=$1
  local sample_size=$2
  local total_count=$3

  [[ $sample_size -eq 0 ]] && { echo "0"; return 1; }
  [[ $with_attr -eq 0 ]] && { echo "0"; return 0; }

  # Calculate estimate
  local estimated=$((total_count * with_attr / sample_size))
  echo "$estimated"
}

# Get confidence level for sample size
# Arguments:
#   $1 - Sample size
#   $2 - Total population
# Output:
#   Confidence description (e.g., "High", "Medium", "Low")
sampling::get_confidence() {
  local sample_size=$1
  local total=$2

  [[ $total -eq 0 ]] && { echo "N/A"; return 1; }

  local percentage=$((sample_size * 100 / total))

  if [[ $percentage -ge 10 ]]; then
    echo "High"
  elif [[ $percentage -ge 5 ]]; then
    echo "Medium"
  elif [[ $percentage -ge 1 ]]; then
    echo "Low"
  else
    echo "Very Low"
  fi
}

# ============================================================================
# REPORTING
# ============================================================================

# Format sampling results for display
# Arguments:
#   $1 - Files with attribute
#   $2 - Sample size
#   $3 - Total file count
# Output:
#   Multi-line formatted report
sampling::format_results() {
  local with_attr=$1
  local sample_size=$2
  local total_count=$3

  local hit_rate
  hit_rate=$(sampling::calculate_rate "$with_attr" "$sample_size")

  local estimated
  estimated=$(sampling::estimate_total "$with_attr" "$sample_size" "$total_count")

  local confidence
  confidence=$(sampling::get_confidence "$sample_size" "$total_count")

  cat <<EOF
Sample Analysis Results:
  Sample size: $sample_size files
  Files with custom associations: $with_attr
  Hit rate: ${hit_rate}%
  Estimated files needing reset: ~$estimated
  Confidence level: $confidence
EOF
}

# ============================================================================
# EXPORTS
# ============================================================================

# Export functions for use in subshells/parallel workers
export -f sampling::get_sample
export -f sampling::calculate_rate
export -f sampling::analyze
export -f sampling::analyze_extension
export -f sampling::should_skip
export -f sampling::estimate_total
export -f sampling::get_confidence
export -f sampling::format_results

# Mark module as loaded
readonly SAMPLING_MODULE_LOADED=true
