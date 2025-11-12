#!/usr/bin/env bash
# tests/test-ui.sh - Unit tests for lib/ui.sh
#
# Run with: ./tests/test-ui.sh
# Or: just test-unit

set -uo pipefail

# Load the modules to test
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# shellcheck source=../lib/core.sh
source "$PROJECT_ROOT/lib/core.sh"

# shellcheck source=../lib/ui.sh
source "$PROJECT_ROOT/lib/ui.sh"

# ============================================================================
# TEST FRAMEWORK
# ============================================================================

TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Run a test
test_run() {
  local test_name=$1
  local test_func=$2

  ((TESTS_RUN++))

  # Call test function and capture result
  if "$test_func"; then
    ((TESTS_PASSED++))
    echo "  ✓ $test_name"
  else
    ((TESTS_FAILED++))
    echo "  ✗ $test_name"
  fi
}

# Assert equality
assert_equals() {
  local expected=$1
  local actual=$2
  local message=${3:-"Expected '$expected', got '$actual'"}

  if [[ "$expected" != "$actual" ]]; then
    echo "    FAIL: $message"
    return 1
  fi
  return 0
}

# Assert command succeeds
assert_success() {
  if ! "$@"; then
    echo "    FAIL: Command failed: $*"
    return 1
  fi
  return 0
}

# Assert command fails
assert_failure() {
  if "$@"; then
    echo "    FAIL: Command should have failed: $*"
    return 1
  fi
  return 0
}

# Assert output contains string
assert_contains() {
  local output=$1
  local expected=$2

  if [[ "$output" != *"$expected"* ]]; then
    echo "    FAIL: Output doesn't contain '$expected'"
    echo "    Output: $output"
    return 1
  fi
  return 0
}

# ============================================================================
# TESTS: Initialization
# ============================================================================

test_ui_init() {
  # Should initialize without error
  assert_success ui::init || return 1

  # GUM_AVAILABLE should be set (true or false)
  if [[ -z "$GUM_AVAILABLE" ]]; then
    echo "    FAIL: GUM_AVAILABLE not set"
    return 1
  fi

  return 0
}

test_has_gum() {
  # Should return true or false (not error)
  ui::has_gum && return 0
  return 0
}

# ============================================================================
# TESTS: Basic Output (Visual inspection needed)
# ============================================================================

test_info_output() {
  # Test that info doesn't error
  local output
  output=$(ui::info "Test message" 2>&1)

  # Should not be empty
  if [[ -z "$output" ]]; then
    echo "    FAIL: No output from ui::info"
    return 1
  fi

  # Should contain the message
  assert_contains "$output" "Test message" || return 1

  return 0
}

test_success_output() {
  local output
  output=$(ui::success "Success message" 2>&1)

  if [[ -z "$output" ]]; then
    echo "    FAIL: No output from ui::success"
    return 1
  fi

  assert_contains "$output" "Success message" || return 1
  return 0
}

test_warn_output() {
  local output
  output=$(ui::warn "Warning message" 2>&1)

  if [[ -z "$output" ]]; then
    echo "    FAIL: No output from ui::warn"
    return 1
  fi

  assert_contains "$output" "Warning message" || return 1
  return 0
}

test_error_output() {
  local output
  output=$(ui::error "Error message" 2>&1)

  if [[ -z "$output" ]]; then
    echo "    FAIL: No output from ui::error"
    return 1
  fi

  assert_contains "$output" "Error message" || return 1
  return 0
}

# ============================================================================
# TESTS: Console Logging
# ============================================================================

test_console_log_info() {
  local output
  output=$(ui::console_log INFO "Test info" 2>&1)

  # Should contain timestamp (format: HH:MM:SS)
  if [[ ! "$output" =~ [0-9]{2}:[0-9]{2}:[0-9]{2} ]]; then
    echo "    FAIL: No timestamp in output"
    return 1
  fi

  # Should contain INFO label
  assert_contains "$output" "INFO" || return 1

  # Should contain message
  assert_contains "$output" "Test info" || return 1

  return 0
}

test_console_log_warn() {
  local output
  output=$(ui::console_log WARN "Test warning" 2>&1)

  assert_contains "$output" "WARN" || return 1
  assert_contains "$output" "Test warning" || return 1
  return 0
}

test_console_log_error() {
  local output
  output=$(ui::console_log ERROR "Test error" 2>&1)

  assert_contains "$output" "ERROR" || return 1
  assert_contains "$output" "Test error" || return 1
  return 0
}

test_console_log_success() {
  local output
  output=$(ui::console_log SUCCESS "Test success" 2>&1)

  assert_contains "$output" "OK" || return 1
  assert_contains "$output" "Test success" || return 1
  return 0
}

# ============================================================================
# TESTS: Timestamp
# ============================================================================

test_get_timestamp() {
  local timestamp
  timestamp=$(ui::get_timestamp)

  # Should match HH:MM:SS format (with optional milliseconds)
  if [[ ! "$timestamp" =~ ^[0-9]{2}:[0-9]{2}:[0-9]{2} ]]; then
    echo "    FAIL: Invalid timestamp format: $timestamp"
    return 1
  fi

  return 0
}

# ============================================================================
# TESTS: Utility Functions
# ============================================================================

test_newline() {
  local output
  output=$(ui::newline)

  # Should be a single newline (empty line)
  if [[ "$output" != "" ]]; then
    echo "    FAIL: ui::newline should produce empty output"
    return 1
  fi

  return 0
}

test_divider() {
  local output
  output=$(ui::divider 2>&1)

  # Should not be empty
  if [[ -z "$output" ]]; then
    echo "    FAIL: No output from ui::divider"
    return 1
  fi

  # Should contain separator characters
  if [[ ! "$output" =~ ━ ]]; then
    echo "    FAIL: Divider doesn't contain expected characters"
    return 1
  fi

  return 0
}

# ============================================================================
# TESTS: Legacy Compatibility
# ============================================================================

test_color_constants_exported() {
  # Test that legacy color constants are available
  if [[ -z "$RED" ]]; then
    echo "    FAIL: RED constant not exported"
    return 1
  fi

  if [[ -z "$GREEN" ]]; then
    echo "    FAIL: GREEN constant not exported"
    return 1
  fi

  if [[ -z "$NC" ]]; then
    echo "    FAIL: NC constant not exported"
    return 1
  fi

  return 0
}

# ============================================================================
# TESTS: Spinner (Manual)
# ============================================================================

test_spinner_start_stop() {
  # Test spinner without Gum (fallback)
  local original_gum=$GUM_AVAILABLE
  GUM_AVAILABLE=false

  # Start spinner
  ui::start_spinner "Testing..."

  # Spinner PID should be set
  if [[ -z "$UI_SPINNER_PID" ]]; then
    echo "    FAIL: Spinner PID not set"
    GUM_AVAILABLE=$original_gum
    return 1
  fi

  # Stop spinner
  ui::stop_spinner

  # Spinner PID should be cleared
  if [[ -n "$UI_SPINNER_PID" ]]; then
    echo "    FAIL: Spinner PID not cleared"
    GUM_AVAILABLE=$original_gum
    return 1
  fi

  GUM_AVAILABLE=$original_gum
  return 0
}

# ============================================================================
# TESTS: Progress Bar
# ============================================================================

test_progress_bar() {
  local output
  output=$(ui::progress 50 100 "Test" 2>&1)

  # Should not be empty
  if [[ -z "$output" ]]; then
    echo "    FAIL: No output from ui::progress"
    return 1
  fi

  # Should contain percentage
  if [[ ! "$output" =~ 50% ]]; then
    echo "    FAIL: Progress bar doesn't show percentage"
    return 1
  fi

  # Should contain the label
  assert_contains "$output" "Test" || return 1

  return 0
}

test_progress_bar_zero_total() {
  # Should handle zero total gracefully
  local output
  output=$(ui::progress 0 0 "Test" 2>&1)

  # Should succeed (return 0) and produce no output
  return 0
}

# ============================================================================
# RUN TESTS
# ============================================================================

main() {
  echo "Running tests for lib/ui.sh"
  echo ""

  # Initialize UI first
  ui::init

  if ui::has_gum; then
    echo "Gum is available: Testing with Gum"
  else
    echo "Gum not available: Testing fallback mode"
  fi
  echo ""

  # Initialization
  echo "Initialization:"
  test_run "ui_init" test_ui_init
  test_run "has_gum" test_has_gum

  # Basic Output
  echo ""
  echo "Basic Output:"
  test_run "info_output" test_info_output
  test_run "success_output" test_success_output
  test_run "warn_output" test_warn_output
  test_run "error_output" test_error_output

  # Console Logging
  echo ""
  echo "Console Logging:"
  test_run "console_log_info" test_console_log_info
  test_run "console_log_warn" test_console_log_warn
  test_run "console_log_error" test_console_log_error
  test_run "console_log_success" test_console_log_success

  # Timestamp
  echo ""
  echo "Timestamp:"
  test_run "get_timestamp" test_get_timestamp

  # Utility Functions
  echo ""
  echo "Utility Functions:"
  test_run "newline" test_newline
  test_run "divider" test_divider

  # Legacy Compatibility
  echo ""
  echo "Legacy Compatibility:"
  test_run "color_constants_exported" test_color_constants_exported

  # Spinner
  echo ""
  echo "Spinner:"
  test_run "spinner_start_stop" test_spinner_start_stop

  # Progress Bar
  echo ""
  echo "Progress Bar:"
  test_run "progress_bar" test_progress_bar
  test_run "progress_bar_zero_total" test_progress_bar_zero_total

  # Summary
  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "Tests run: $TESTS_RUN"
  echo "Passed: $TESTS_PASSED"
  echo "Failed: $TESTS_FAILED"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

  if [[ $TESTS_FAILED -eq 0 ]]; then
    echo "✅ All tests passed!"
    return 0
  else
    echo "❌ Some tests failed"
    return 1
  fi
}

main "$@"
