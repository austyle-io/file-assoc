#!/usr/bin/env bash
# lib/files.sh - File discovery and operations
#
# File system operations for finding and counting files by extension.
# Provides efficient file discovery with progress tracking.
#
# Usage:
#   source lib/files.sh
#   count=$(files::count "/path/to/dir" "txt")
#   files::find_by_ext "/path/to/dir" "md" | while read file; do ...; done

# Ensure script is sourced
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  echo "Error: This file should be sourced, not executed" >&2
  exit 1
fi

# Load dependencies
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/core.sh"

# Module version
readonly FILES_MODULE_VERSION="1.0.0"

# ============================================================================
# FILE COUNTING
# ============================================================================

# Count files by extension in directory
# Arguments:
#   $1 - Directory path
#   $2 - File extension (without dot, e.g., "txt")
# Output:
#   Number of files found
files::count() {
  local dir_path=$1
  local extension=$2

  # Validate inputs
  if [[ -z "$dir_path" ]]; then
    echo "0"
    return 1
  fi

  if [[ ! -d "$dir_path" ]]; then
    echo "0"
    return 1
  fi

  # Normalize extension (remove leading dot)
  extension=$(normalize_extension "$extension")

  # Fast count without progress
  find "$dir_path" -type f -name "*.${extension}" 2>/dev/null | wc -l | tr -d ' '
}

# Count all files in directory (no extension filter)
# Arguments:
#   $1 - Directory path
# Output:
#   Number of files found
files::count_all() {
  local dir_path=$1

  # Validate inputs
  if [[ -z "$dir_path" ]]; then
    echo "0"
    return 1
  fi

  if [[ ! -d "$dir_path" ]]; then
    echo "0"
    return 1
  fi

  # Count all regular files
  find "$dir_path" -type f 2>/dev/null | wc -l | tr -d ' '
}

# Count files for multiple extensions
# Arguments:
#   $1 - Directory path
#   $@ - Extensions (e.g., "txt" "md" "doc")
# Output:
#   Total number of files found across all extensions
files::count_multiple() {
  local dir_path=$1
  shift
  local extensions=("$@")

  [[ -z "$dir_path" ]] && { echo "0"; return 1; }
  [[ ! -d "$dir_path" ]] && { echo "0"; return 1; }
  [[ ${#extensions[@]} -eq 0 ]] && { echo "0"; return 1; }

  local total=0
  local ext
  for ext in "${extensions[@]}"; do
    local count
    count=$(files::count "$dir_path" "$ext")
    total=$((total + count))
  done

  echo "$total"
}

# ============================================================================
# FILE DISCOVERY
# ============================================================================

# Find files by extension
# Arguments:
#   $1 - Directory path
#   $2 - File extension (without dot, e.g., "txt")
# Output:
#   List of file paths, one per line
files::find_by_ext() {
  local dir_path=$1
  local extension=$2

  [[ -z "$dir_path" ]] && return 1
  [[ ! -d "$dir_path" ]] && return 1

  # Normalize extension (remove leading dot)
  extension=$(normalize_extension "$extension")

  # Find files matching extension
  find "$dir_path" -type f -name "*.${extension}" 2>/dev/null
}

# Find all files (no extension filter)
# Arguments:
#   $1 - Directory path
# Output:
#   List of file paths, one per line
files::find_all() {
  local dir_path=$1

  [[ -z "$dir_path" ]] && return 1
  [[ ! -d "$dir_path" ]] && return 1

  # Find all regular files
  find "$dir_path" -type f 2>/dev/null
}

# Find files by multiple extensions
# Arguments:
#   $1 - Directory path
#   $@ - Extensions (e.g., "txt" "md" "doc")
# Output:
#   List of file paths, one per line
files::find_by_extensions() {
  local dir_path=$1
  shift
  local extensions=("$@")

  [[ -z "$dir_path" ]] && return 1
  [[ ! -d "$dir_path" ]] && return 1
  [[ ${#extensions[@]} -eq 0 ]] && return 1

  # Build find predicates for multiple extensions
  local find_args=()
  local first=true

  for ext in "${extensions[@]}"; do
    ext=$(normalize_extension "$ext")

    if [[ "$first" == true ]]; then
      find_args+=(-name "*.${ext}")
      first=false
    else
      find_args+=(-o -name "*.${ext}")
    fi
  done

  # Execute find with combined predicates
  find "$dir_path" -type f \( "${find_args[@]}" \) 2>/dev/null
}

# ============================================================================
# DIRECTORY VALIDATION
# ============================================================================

# Validate directory exists and is readable
# Arguments:
#   $1 - Directory path
# Returns:
#   0 if valid, 1 otherwise
files::validate_directory() {
  local dir_path=$1

  [[ -z "$dir_path" ]] && return 1
  [[ ! -e "$dir_path" ]] && return 1
  [[ ! -d "$dir_path" ]] && return 1
  [[ ! -r "$dir_path" ]] && return 1

  return 0
}

# Get absolute path of directory
# Arguments:
#   $1 - Directory path (relative or absolute)
# Output:
#   Absolute path
files::get_absolute_dir() {
  local dir_path=$1

  [[ -z "$dir_path" ]] && return 1
  [[ ! -d "$dir_path" ]] && return 1

  (cd "$dir_path" && pwd)
}

# ============================================================================
# FILE OPERATIONS
# ============================================================================

# Get file size in bytes
# Arguments:
#   $1 - File path
# Output:
#   File size in bytes
files::get_size() {
  local file_path=$1

  [[ -z "$file_path" ]] && return 1
  [[ ! -f "$file_path" ]] && return 1

  if is_macos; then
    stat -f %z "$file_path" 2>/dev/null
  else
    stat -c %s "$file_path" 2>/dev/null
  fi
}

# Get total size of files by extension
# Arguments:
#   $1 - Directory path
#   $2 - File extension (without dot, e.g., "txt")
# Output:
#   Total size in bytes
files::get_total_size() {
  local dir_path=$1
  local extension=$2

  [[ -z "$dir_path" ]] && return 1
  [[ ! -d "$dir_path" ]] && return 1

  extension=$(normalize_extension "$extension")

  local total=0
  while IFS= read -r file; do
    local size
    size=$(files::get_size "$file")
    total=$((total + size))
  done < <(files::find_by_ext "$dir_path" "$extension")

  echo "$total"
}

# Format bytes to human-readable size
# Arguments:
#   $1 - Size in bytes
# Output:
#   Human-readable size (e.g., "1.5 MB")
files::format_size() {
  local bytes=$1

  if [[ $bytes -lt 1024 ]]; then
    echo "${bytes} B"
  elif [[ $bytes -lt $((1024 * 1024)) ]]; then
    echo "$(awk "BEGIN {printf \"%.1f\", $bytes / 1024}") KB"
  elif [[ $bytes -lt $((1024 * 1024 * 1024)) ]]; then
    echo "$(awk "BEGIN {printf \"%.1f\", $bytes / 1024 / 1024}") MB"
  else
    echo "$(awk "BEGIN {printf \"%.1f\", $bytes / 1024 / 1024 / 1024}") GB"
  fi
}

# ============================================================================
# ESTIMATION
# ============================================================================

# Estimate processing time based on file count
# Arguments:
#   $1 - Number of files
#   $2 - Files per second (default: 500)
# Output:
#   Estimated duration in seconds
files::estimate_time() {
  local file_count=$1
  local files_per_sec=${2:-500}

  [[ $files_per_sec -eq 0 ]] && files_per_sec=500

  local duration=$((file_count / files_per_sec))
  [[ $duration -lt 1 ]] && duration=1

  echo "$duration"
}

# ============================================================================
# EXTENSION UTILITIES
# ============================================================================

# Get file extension from filename
# Arguments:
#   $1 - File path or name
# Output:
#   Extension without dot (e.g., "txt")
files::get_extension() {
  local file_path=$1

  [[ -z "$file_path" ]] && return 1

  local basename
  basename=$(basename "$file_path")

  # Extract extension
  local ext="${basename##*.}"

  # If no extension found, return empty
  [[ "$ext" == "$basename" ]] && return 1

  # Normalize and return
  normalize_extension "$ext"
}

# Check if file has specific extension
# Arguments:
#   $1 - File path
#   $2 - Extension to check (without dot)
# Returns:
#   0 if matches, 1 otherwise
files::has_extension() {
  local file_path=$1
  local target_ext=$2

  [[ -z "$file_path" ]] && return 1
  [[ -z "$target_ext" ]] && return 1

  local actual_ext
  actual_ext=$(files::get_extension "$file_path") || return 1

  target_ext=$(normalize_extension "$target_ext")

  [[ "$actual_ext" == "$target_ext" ]]
}

# ============================================================================
# EXPORTS
# ============================================================================

# Export functions for use in subshells/parallel workers
export -f files::count
export -f files::count_all
export -f files::count_multiple
export -f files::find_by_ext
export -f files::find_all
export -f files::find_by_extensions
export -f files::validate_directory
export -f files::get_absolute_dir
export -f files::get_size
export -f files::get_total_size
export -f files::format_size
export -f files::estimate_time
export -f files::get_extension
export -f files::has_extension

# Mark module as loaded
readonly FILES_MODULE_LOADED=true
