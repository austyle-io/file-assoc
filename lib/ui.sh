#!/usr/bin/env bash
# lib/ui.sh - Terminal UI components using Gum
#
# Modern terminal UI using Gum (https://github.com/charmbracelet/gum)
# with graceful fallback to basic ANSI codes if Gum is not available.
#
# Usage:
#   source lib/ui.sh
#   ui::init
#   ui::info "Processing files..."
#   ui::success "Complete!"

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
# CONSTANTS
# ============================================================================

readonly UI_VERSION="1.0.0"

# Gum availability flag
declare -g GUM_AVAILABLE=false

# ANSI color codes (fallback)
declare -g -r UI_RED='\033[0;31m'
declare -g -r UI_GREEN='\033[0;32m'
declare -g -r UI_YELLOW='\033[1;33m'
declare -g -r UI_BLUE='\033[0;34m'
declare -g -r UI_CYAN='\033[0;36m'
declare -g -r UI_MAGENTA='\033[0;35m'
declare -g -r UI_NC='\033[0m'

# Spinner characters for fallback
declare -g -r UI_SPINNER_CHARS="⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏"

# Spinner PID (for fallback spinner)
declare -g UI_SPINNER_PID=""

# ============================================================================
# INITIALIZATION
# ============================================================================

# Initialize UI system
# Usage: ui::init
ui::init() {
  # Check if Gum is available
  if command -v gum > /dev/null 2>&1; then
    GUM_AVAILABLE=true
    # Log if logging is available
    if declare -f log_debug > /dev/null 2>&1; then
      log_debug "UI" "Gum is available, using modern UI"
    fi
  else
    GUM_AVAILABLE=false
    # Log if logging is available
    if declare -f log_debug > /dev/null 2>&1; then
      log_debug "UI" "Gum not available, using fallback ANSI UI"
    fi
  fi
}

# Check if Gum is available
# Usage: if ui::has_gum; then ...
ui::has_gum() {
  [[ "$GUM_AVAILABLE" = true ]]
}

# ============================================================================
# BASIC OUTPUT
# ============================================================================

# Display a header/section title
# Usage: ui::header "Section Title"
ui::header() {
  local text=$1

  if ui::has_gum; then
    gum style \
      --foreground 212 \
      --border double \
      --align center \
      --width 60 \
      --margin "1 0" \
      --padding "1 4" \
      "$text"
  else
    # Fallback: Simple banner
    local border="━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    printf '%b\n' "${UI_CYAN}${border}${UI_NC}"
    printf '%b\n' "${UI_CYAN}${text}${UI_NC}"
    printf '%b\n' "${UI_CYAN}${border}${UI_NC}"
  fi
}

# Display info message
# Usage: ui::info "Processing files..."
ui::info() {
  local message=$1

  if ui::has_gum; then
    gum style --foreground 14 "ℹ $message"
  else
    printf '%b\n' "${UI_CYAN}ℹ${UI_NC} $message"
  fi
}

# Display success message
# Usage: ui::success "Operation complete!"
ui::success() {
  local message=$1

  if ui::has_gum; then
    gum style --foreground 10 "✓ $message"
  else
    printf '%b\n' "${UI_GREEN}✓${UI_NC} $message"
  fi
}

# Display warning message
# Usage: ui::warn "This might take a while"
ui::warn() {
  local message=$1

  if ui::has_gum; then
    gum style --foreground 11 "⚠ $message"
  else
    printf '%b\n' "${UI_YELLOW}⚠${UI_NC} $message"
  fi
}

# Display error message
# Usage: ui::error "Something went wrong"
ui::error() {
  local message=$1

  if ui::has_gum; then
    gum style --foreground 9 --bold "✗ $message" >&2
  else
    printf '%b\n' "${UI_RED}✗${UI_NC} $message" >&2
  fi
}

# Display debug message (only if verbose)
# Usage: ui::debug "Debug information"
ui::debug() {
  local message=$1

  # Only show if VERBOSE is set
  if [[ "${VERBOSE:-false}" == true ]]; then
    if ui::has_gum; then
      gum style --foreground 13 --faint "🐛 $message"
    else
      printf '%b\n' "${UI_MAGENTA}🐛${UI_NC} $message"
    fi
  fi
}

# ============================================================================
# CONSOLE LOGGING (Backward Compatible)
# ============================================================================

# Console log with timestamp and level (backward compatible)
# Usage: ui::console_log INFO "message"
ui::console_log() {
  local level=$1
  shift
  local message="$*"

  local timestamp
  timestamp=$(ui::get_timestamp)

  case "$level" in
    INFO)
      if ui::has_gum; then
        printf '%b ' "${UI_CYAN}[${timestamp}]${UI_NC}"
        gum style --foreground 14 "[INFO ]"
        printf ' %s\n' "$message"
      else
        printf '%b\n' "${UI_CYAN}[${timestamp}]${UI_NC} ${UI_CYAN}[INFO ]${UI_NC} ${message}"
      fi
      ;;
    WARN)
      if ui::has_gum; then
        printf '%b ' "${UI_CYAN}[${timestamp}]${UI_NC}"
        gum style --foreground 11 "[WARN ]"
        printf ' %s\n' "$message"
      else
        printf '%b\n' "${UI_CYAN}[${timestamp}]${UI_NC} ${UI_YELLOW}[WARN ]${UI_NC} ${message}"
      fi
      ;;
    ERROR)
      if ui::has_gum; then
        printf '%b ' "${UI_CYAN}[${timestamp}]${UI_NC}"
        gum style --foreground 9 "[ERROR]"
        printf ' %s\n' "$message"
      else
        printf '%b\n' "${UI_CYAN}[${timestamp}]${UI_NC} ${UI_RED}[ERROR]${UI_NC} ${message}"
      fi
      ;;
    SUCCESS)
      if ui::has_gum; then
        printf '%b ' "${UI_CYAN}[${timestamp}]${UI_NC}"
        gum style --foreground 10 "[OK   ]"
        printf ' %s\n' "$message"
      else
        printf '%b\n' "${UI_CYAN}[${timestamp}]${UI_NC} ${UI_GREEN}[OK   ]${UI_NC} ${message}"
      fi
      ;;
    DEBUG)
      if [[ "${VERBOSE:-false}" == true ]]; then
        if ui::has_gum; then
          printf '%b ' "${UI_CYAN}[${timestamp}]${UI_NC}"
          gum style --foreground 13 "[DEBUG]"
          printf ' %s\n' "$message"
        else
          printf '%b\n' "${UI_CYAN}[${timestamp}]${UI_NC} ${UI_MAGENTA}[DEBUG]${UI_NC} ${message}"
        fi
      fi
      ;;
    *)
      printf '%b\n' "${UI_CYAN}[${timestamp}]${UI_NC}        ${message}"
      ;;
  esac
}

# Get console timestamp (24-hour with milliseconds)
ui::get_timestamp() {
  if command -v gdate > /dev/null 2>&1; then
    gdate +%H:%M:%S.%3N
  elif date +%H:%M:%S.%N 2> /dev/null | grep -qv '%N'; then
    date +%H:%M:%S.%3N
  else
    date +%H:%M:%S.000
  fi
}

# ============================================================================
# INTERACTIVE COMPONENTS
# ============================================================================

# Confirmation prompt
# Usage: if ui::confirm "Continue?"; then ...
ui::confirm() {
  local prompt=${1:-"Continue?"}

  if ui::has_gum; then
    gum confirm "$prompt"
  else
    # Fallback: read -p
    read -rp "$prompt (y/N) " response
    [[ "$response" =~ ^[Yy]$ ]]
  fi
}

# Text input
# Usage: name=$(ui::input "Enter your name")
ui::input() {
  local prompt=${1:-"Enter value"}
  local placeholder=${2:-""}

  if ui::has_gum; then
    if [[ -n "$placeholder" ]]; then
      gum input --placeholder "$placeholder" --prompt "$prompt: "
    else
      gum input --prompt "$prompt: "
    fi
  else
    # Fallback: read -p
    read -rp "$prompt: " value
    echo "$value"
  fi
}

# Selection menu
# Usage: choice=$(ui::choose "Option 1" "Option 2" "Option 3")
ui::choose() {
  local options=("$@")

  if ui::has_gum; then
    gum choose "${options[@]}"
  else
    # Fallback: select
    select choice in "${options[@]}"; do
      if [[ -n "$choice" ]]; then
        echo "$choice"
        break
      fi
    done
  fi
}

# ============================================================================
# SPINNERS
# ============================================================================

# Show spinner during command execution
# Usage: ui::spinner "Loading..." -- long_running_command
ui::spinner() {
  local title=$1
  shift

  if [[ "$1" == "--" ]]; then
    shift
  fi

  if ui::has_gum; then
    gum spin --spinner dot --title "$title" -- "$@"
  else
    # Fallback: run command without spinner (or basic spinner)
    ui::start_spinner "$title"
    "$@"
    local result=$?
    ui::stop_spinner
    return $result
  fi
}

# Start spinner (fallback for manual control)
# Usage: ui::start_spinner "Processing..."
ui::start_spinner() {
  local message=${1:-"Processing..."}

  # If Gum is available, don't use fallback spinner
  if ui::has_gum; then
    ui::info "$message"
    return
  fi

  # Hide cursor
  tput civis 2> /dev/null || true

  # Start background spinner
  (
    local i=0
    while true; do
      local char="${UI_SPINNER_CHARS:$i:1}"
      printf "\r${UI_CYAN}%s${UI_NC} %s" "$char" "$message"
      i=$(((i + 1) % ${#UI_SPINNER_CHARS}))
      sleep 0.1
    done
  ) &

  UI_SPINNER_PID=$!
}

# Stop spinner (fallback)
# Usage: ui::stop_spinner
ui::stop_spinner() {
  if [[ -n "$UI_SPINNER_PID" ]]; then
    kill "$UI_SPINNER_PID" 2> /dev/null || true
    wait "$UI_SPINNER_PID" 2> /dev/null || true
    UI_SPINNER_PID=""
    printf "\r%80s\r" "" # Clear the line
    # Show cursor
    tput cnorm 2> /dev/null || true
  fi
}

# ============================================================================
# PROGRESS
# ============================================================================

# Show progress bar (basic implementation, Gum doesn't have built-in progress)
# Usage: ui::progress 50 100 "Processing files"
ui::progress() {
  local current=$1
  local total=$2
  local label=${3:-"Progress"}

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

  # Calculate rate and ETA (if available)
  local rate_info=""
  if [[ -n "${BATCH_START_TIME:-}" ]]; then
    local elapsed=$(($(date +%s) - BATCH_START_TIME))
    if [[ $elapsed -gt 0 ]] && [[ $current -gt 0 ]]; then
      local rate=$((current / elapsed))
      [[ $rate -eq 0 ]] && rate=1
      local remaining=$((total - current))
      local eta=$((remaining / rate))

      if [[ $eta -gt 60 ]]; then
        rate_info=" ${UI_YELLOW}@${rate}/s${UI_NC} ETA: ${UI_MAGENTA}$((eta / 60))m $((eta % 60))s${UI_NC}"
      else
        rate_info=" ${UI_YELLOW}@${rate}/s${UI_NC} ETA: ${UI_MAGENTA}${eta}s${UI_NC}"
      fi
    fi
  fi

  # Display progress
  local timestamp
  timestamp=$(ui::get_timestamp)

  printf "\r${UI_CYAN}[%s]${UI_NC} ${UI_CYAN}[INFO ]${UI_NC} ${UI_CYAN}%s:${UI_NC} [%s] ${UI_GREEN}%3d%%${UI_NC} (%d/%d)%b  " \
    "$timestamp" "$label" "$bar" "$percent" "$current" "$total" "$rate_info"
}

# ============================================================================
# FORMATTING
# ============================================================================

# Format markdown text (if Gum available)
# Usage: ui::format < file.md
ui::format() {
  if ui::has_gum; then
    gum format
  else
    # Fallback: just cat
    cat
  fi
}

# Style text with color/formatting
# Usage: ui::style --foreground 212 --bold "Important text"
ui::style() {
  if ui::has_gum; then
    gum style "$@"
  else
    # Fallback: just echo the last argument (the text)
    echo "${*: -1}"
  fi
}

# Display table (if Gum available)
# Usage: ui::table --header "Col1,Col2" --data "val1,val2"
ui::table() {
  if ui::has_gum; then
    gum table "$@"
  else
    # Fallback: simple column output
    column -t -s,
  fi
}

# ============================================================================
# UTILITY FUNCTIONS
# ============================================================================

# Print a blank line
# Usage: ui::newline
ui::newline() {
  echo ""
}

# Print a divider/separator
# Usage: ui::divider
ui::divider() {
  local char=${1:-━}
  local width=${2:-60}

  local line=""
  for ((i = 0; i < width; i++)); do
    line+="$char"
  done

  if ui::has_gum; then
    gum style --foreground 14 "$line"
  else
    printf '%b\n' "${UI_CYAN}${line}${UI_NC}"
  fi
}

# Clear the current line
# Usage: ui::clear_line
ui::clear_line() {
  printf "\r%80s\r" ""
}

# ============================================================================
# LEGACY COMPATIBILITY ALIASES
# ============================================================================

# Provide aliases for backward compatibility with existing scripts

# Alias console_log -> ui::console_log
alias console_log='ui::console_log'

# Color constants for legacy code
RED="$UI_RED"
GREEN="$UI_GREEN"
YELLOW="$UI_YELLOW"
BLUE="$UI_BLUE"
CYAN="$UI_CYAN"
MAGENTA="$UI_MAGENTA"
NC="$UI_NC"

export RED GREEN YELLOW BLUE CYAN MAGENTA NC

# ============================================================================
# EXPORTS
# ============================================================================

# Export main functions
export -f ui::init
export -f ui::has_gum
export -f ui::header
export -f ui::info
export -f ui::success
export -f ui::warn
export -f ui::error
export -f ui::debug
export -f ui::console_log
export -f ui::get_timestamp
export -f ui::confirm
export -f ui::input
export -f ui::choose
export -f ui::spinner
export -f ui::start_spinner
export -f ui::stop_spinner
export -f ui::progress
export -f ui::newline
export -f ui::divider
export -f ui::clear_line

# Mark as loaded
readonly UI_LOADED=true
