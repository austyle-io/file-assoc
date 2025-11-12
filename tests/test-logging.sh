#!/usr/bin/env bash
# tests/test-logging.sh - Unit tests for lib/logging.sh

set -uo pipefail

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Source modules
source "$PROJECT_ROOT/lib/core.sh"
source "$PROJECT_ROOT/lib/logging.sh"

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# ============================================================================
# TEST FRAMEWORK
# ============================================================================

test_run() {
  local test_name=$1
  local test_func=$2

  ((TESTS_RUN++))

  if $test_func; then
    ((TESTS_PASSED++))
    echo "  ✓ $test_name"
    return 0
  else
    ((TESTS_FAILED++))
    echo "  ✗ $test_name"
    return 1
  fi
}

assert_equals() {
  local expected=$1
  local actual=$2
  local message=${3:-""}

  if [[ "$expected" == "$actual" ]]; then
    return 0
  else
    [[ -n "$message" ]] && echo "    $message"
    echo "    Expected: '$expected'"
    echo "    Got: '$actual'"
    return 1
  fi
}

assert_success() {
  "$@" >/dev/null 2>&1
}

assert_file_exists() {
  [[ -f "$1" ]]
}

# ============================================================================
# TESTS
# ============================================================================

test_log_init() {
  local test_dir
  test_dir=$(create_temp_dir)

  log::init "$test_dir" "test.log" "INFO" 5
  local result=$?

  [[ $result -eq 0 ]] && [[ -f "$test_dir/test.log" ]]
  local success=$?

  rm -rf "$test_dir"
  return $success
}

test_log_init_auto_name() {
  local test_dir
  test_dir=$(create_temp_dir)

  log::init "$test_dir" "" "INFO" 5
  local result=$?

  # Check that a log file was created with auto-generated name
  local log_count
  log_count=$(find "$test_dir" -name "file-assoc-*.log" | wc -l | tr -d ' ')

  rm -rf "$test_dir"
  [[ $result -eq 0 ]] && [[ $log_count -eq 1 ]]
}

test_log_write_info() {
  local test_dir
  test_dir=$(create_temp_dir)

  log::init "$test_dir" "test.log" "INFO" 5
  log::info "TEST" "test message"
  log::flush

  grep -q "INFO" "$test_dir/test.log" && grep -q "test message" "$test_dir/test.log"
  local success=$?

  rm -rf "$test_dir"
  return $success
}

test_log_write_debug() {
  local test_dir
  test_dir=$(create_temp_dir)

  log::init "$test_dir" "test.log" "DEBUG" 5
  log::debug "TEST" "debug message"
  log::flush

  grep -q "DEBUG" "$test_dir/test.log" && grep -q "debug message" "$test_dir/test.log"
  local success=$?

  rm -rf "$test_dir"
  return $success
}

test_log_level_filtering() {
  local test_dir
  test_dir=$(create_temp_dir)

  # Set level to WARN, DEBUG should not be logged
  log::init "$test_dir" "test.log" "WARN" 5
  log::debug "TEST" "debug message"
  log::warn "TEST" "warn message"
  log::flush

  # Debug should not be in log, warn should be
  ! grep -q "DEBUG" "$test_dir/test.log" && grep -q "WARN" "$test_dir/test.log"
  local success=$?

  rm -rf "$test_dir"
  return $success
}

test_log_flush() {
  local test_dir
  test_dir=$(create_temp_dir)

  log::init "$test_dir" "test.log" "INFO" 1000
  log::info "TEST" "message 1"

  # Should not be written yet (buffer size is 1000)
  [[ ! -s "$test_dir/test.log" ]] || return 1

  log::flush

  # Now should be written
  [[ -s "$test_dir/test.log" ]]
  local success=$?

  rm -rf "$test_dir"
  return $success
}

test_log_get_file() {
  local test_dir
  test_dir=$(create_temp_dir)

  log::init "$test_dir" "test.log" "INFO" 5

  local log_file
  log_file=$(log::get_file)

  [[ "$log_file" == "$test_dir/test.log" ]]
  local success=$?

  rm -rf "$test_dir"
  return $success
}

test_log_get_level() {
  local test_dir
  test_dir=$(create_temp_dir)

  log::init "$test_dir" "test.log" "DEBUG" 5

  local level
  level=$(log::get_level)

  rm -rf "$test_dir"
  [[ "$level" == "DEBUG" ]]
}

test_log_set_level() {
  local test_dir
  test_dir=$(create_temp_dir)

  log::init "$test_dir" "test.log" "INFO" 5
  log::set_level "WARN"

  local level
  level=$(log::get_level)

  rm -rf "$test_dir"
  [[ "$level" == "WARN" ]]
}

test_log_rotation() {
  local test_dir
  test_dir=$(create_temp_dir)

  # Create 12 old log files
  for i in {1..12}; do
    touch "$test_dir/file-assoc-2025010$i-120000.log"
  done

  # Init with keep count of 10
  log::init "$test_dir" "" "INFO" 10

  # Count remaining logs (should be <= 11: 10 kept + 1 newly created)
  local count
  count=$(find "$test_dir" -name "file-assoc-*.log" | wc -l | tr -d ' ')

  rm -rf "$test_dir"
  [[ $count -le 11 ]]
}

test_log_fatal_auto_flush() {
  local test_dir
  test_dir=$(create_temp_dir)

  log::init "$test_dir" "test.log" "INFO" 1000
  log::fatal "TEST" "fatal error"

  # Fatal should auto-flush
  grep -q "FATAL" "$test_dir/test.log"
  local success=$?

  rm -rf "$test_dir"
  return $success
}

# ============================================================================
# MAIN
# ============================================================================

main() {
  echo "Running tests for lib/logging.sh"
  echo ""

  echo "Initialization:"
  test_run "log_init" test_log_init
  test_run "log_init_auto_name" test_log_init_auto_name

  echo ""
  echo "Writing:"
  test_run "log_write_info" test_log_write_info
  test_run "log_write_debug" test_log_write_debug

  echo ""
  echo "Level Filtering:"
  test_run "log_level_filtering" test_log_level_filtering

  echo ""
  echo "Buffering:"
  test_run "log_flush" test_log_flush
  test_run "log_fatal_auto_flush" test_log_fatal_auto_flush

  echo ""
  echo "Getters:"
  test_run "log_get_file" test_log_get_file
  test_run "log_get_level" test_log_get_level
  test_run "log_set_level" test_log_set_level

  echo ""
  echo "Rotation:"
  test_run "log_rotation" test_log_rotation

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
    echo "❌ Some tests failed!"
    return 1
  fi
}

# Run tests if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main
fi
