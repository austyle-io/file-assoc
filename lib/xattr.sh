#!/usr/bin/env bash
# lib/xattr.sh - Extended attribute operations
#
# macOS extended attribute management, specifically for LaunchServices file associations.
# Provides functions to check, clear, and query extended attributes.
#
# Usage:
#   source lib/xattr.sh
#   if xattr::has_launch_services "/path/to/file"; then
#     xattr::clear_launch_services "/path/to/file"
#   fi

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
if [[ -n "${XATTR_MODULE_VERSION:-}" ]]; then
  return 0
fi

readonly XATTR_MODULE_VERSION="1.0.0"

# LaunchServices attribute name
readonly LAUNCH_SERVICES_ATTR="com.apple.LaunchServices.OpenWith"

# ============================================================================
# ATTRIBUTE CHECKING
# ============================================================================

# Check if file has LaunchServices OpenWith attribute
# Arguments:
#   $1 - File path
# Returns:
#   0 if attribute exists, 1 otherwise
xattr::has_launch_services() {
  local file_path=$1

  [[ -z "$file_path" ]] && return 1
  [[ ! -f "$file_path" ]] && return 1

  # Check if xattr command is available
  if ! command -v xattr >/dev/null 2>&1; then
    return 1
  fi

  # Check for the attribute
  if xattr "$file_path" 2>/dev/null | grep -q "$LAUNCH_SERVICES_ATTR"; then
    return 0
  else
    return 1
  fi
}

# Check if file has any extended attributes
# Arguments:
#   $1 - File path
# Returns:
#   0 if any attributes exist, 1 otherwise
xattr::has_any() {
  local file_path=$1

  [[ -z "$file_path" ]] && return 1
  [[ ! -f "$file_path" ]] && return 1

  if ! command -v xattr >/dev/null 2>&1; then
    return 1
  fi

  local attrs
  attrs=$(xattr "$file_path" 2>/dev/null)

  [[ -n "$attrs" ]]
}

# ============================================================================
# ATTRIBUTE REMOVAL
# ============================================================================

# Clear LaunchServices OpenWith attribute from file
# Arguments:
#   $1 - File path
# Returns:
#   0 on success, 1 on failure
xattr::clear_launch_services() {
  local file_path=$1

  [[ -z "$file_path" ]] && return 1
  [[ ! -f "$file_path" ]] && return 1

  if ! command -v xattr >/dev/null 2>&1; then
    return 1
  fi

  # Remove the attribute
  if xattr -d "$LAUNCH_SERVICES_ATTR" "$file_path" 2>/dev/null; then
    return 0
  else
    return 1
  fi
}

# Clear all extended attributes from file
# Arguments:
#   $1 - File path
# Returns:
#   0 on success, 1 on failure
xattr::clear_all() {
  local file_path=$1

  [[ -z "$file_path" ]] && return 1
  [[ ! -f "$file_path" ]] && return 1

  if ! command -v xattr >/dev/null 2>&1; then
    return 1
  fi

  # Remove all attributes
  if xattr -c "$file_path" 2>/dev/null; then
    return 0
  else
    return 1
  fi
}

# ============================================================================
# ATTRIBUTE QUERIES
# ============================================================================

# List all extended attributes for a file
# Arguments:
#   $1 - File path
# Output:
#   List of attribute names, one per line
xattr::list() {
  local file_path=$1

  [[ -z "$file_path" ]] && return 1
  [[ ! -f "$file_path" ]] && return 1

  if ! command -v xattr >/dev/null 2>&1; then
    return 1
  fi

  xattr "$file_path" 2>/dev/null || true
}

# Get value of specific extended attribute
# Arguments:
#   $1 - File path
#   $2 - Attribute name
# Output:
#   Attribute value (hex or text depending on content)
xattr::get() {
  local file_path=$1
  local attr_name=$2

  [[ -z "$file_path" ]] && return 1
  [[ -z "$attr_name" ]] && return 1
  [[ ! -f "$file_path" ]] && return 1

  if ! command -v xattr >/dev/null 2>&1; then
    return 1
  fi

  xattr -p "$attr_name" "$file_path" 2>/dev/null || return 1
}

# ============================================================================
# BATCH OPERATIONS
# ============================================================================

# Count files with LaunchServices attribute in directory
# Arguments:
#   $1 - Directory path
#   $2 - Extension (optional, e.g., "txt")
# Output:
#   Number of files with the attribute
xattr::count_with_launch_services() {
  local dir_path=$1
  local extension=${2:-}

  [[ -z "$dir_path" ]] && return 1
  [[ ! -d "$dir_path" ]] && return 1

  if ! command -v xattr >/dev/null 2>&1; then
    echo "0"
    return 1
  fi

  local find_args=("$dir_path" -type f)

  if [[ -n "$extension" ]]; then
    # Normalize extension (remove leading dot)
    extension=$(normalize_extension "$extension")
    find_args+=(-name "*.${extension}")
  fi

  local count=0
  while IFS= read -r file; do
    if xattr::has_launch_services "$file"; then
      ((count++))
    fi
  done < <(find "${find_args[@]}" 2>/dev/null)

  echo "$count"
}

# Get list of files with LaunchServices attribute
# Arguments:
#   $1 - Directory path
#   $2 - Extension (optional, e.g., "txt")
# Output:
#   List of file paths, one per line
xattr::find_with_launch_services() {
  local dir_path=$1
  local extension=${2:-}

  [[ -z "$dir_path" ]] && return 1
  [[ ! -d "$dir_path" ]] && return 1

  if ! command -v xattr >/dev/null 2>&1; then
    return 1
  fi

  local find_args=("$dir_path" -type f)

  if [[ -n "$extension" ]]; then
    # Normalize extension (remove leading dot)
    extension=$(normalize_extension "$extension")
    find_args+=(-name "*.${extension}")
  fi

  while IFS= read -r file; do
    if xattr::has_launch_services "$file"; then
      echo "$file"
    fi
  done < <(find "${find_args[@]}" 2>/dev/null)
}

# ============================================================================
# UTILITY FUNCTIONS
# ============================================================================

# Check if xattr command is available
# Returns:
#   0 if available, 1 otherwise
xattr::is_available() {
  command -v xattr >/dev/null 2>&1
}

# Get xattr version/info
# Output:
#   xattr command version or info
xattr::version() {
  if ! xattr::is_available; then
    echo "xattr not available"
    return 1
  fi

  # macOS xattr doesn't have a --version flag, so just confirm it exists
  echo "xattr available (macOS extended attributes)"
}

# ============================================================================
# EXPORTS
# ============================================================================

# Export functions for use in subshells/parallel workers
export -f xattr::has_launch_services
export -f xattr::has_any
export -f xattr::clear_launch_services
export -f xattr::clear_all
export -f xattr::list
export -f xattr::get
export -f xattr::count_with_launch_services
export -f xattr::find_with_launch_services
export -f xattr::is_available
export -f xattr::version

# Mark module as loaded
readonly XATTR_MODULE_LOADED=true
