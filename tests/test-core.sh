#!/usr/bin/env bash
# tests/test-core.sh - Unit tests for lib/core.sh
#
# Run with: ./tests/test-core.sh
# Or: just test-unit

set -uo pipefail

# Load the module to test
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# shellcheck source=../lib/core.sh
source "$PROJECT_ROOT/lib/core.sh"

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

  # Temporarily disable errexit for test execution
  set +e
  "$test_func"
  local result=$?
  set -e

  if [[ $result -eq 0 ]]; then
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

# ============================================================================
# TESTS: Platform Detection
# ============================================================================

test_get_platform() {
  local platform
  platform=$(get_platform)

  # Platform should be macos, linux, or unknown
  if [[ "$platform" == "macos" ]] || [[ "$platform" == "linux" ]] || [[ "$platform" == "unknown" ]]; then
    return 0
  fi

  echo "    FAIL: Invalid platform: $platform"
  return 1
}

test_is_macos() {
  # Should return 0 or 1 (true/false)
  is_macos && return 0
  return 0
}

test_is_linux() {
  # Should return 0 or 1 (true/false)
  is_linux && return 0
  return 0
}

# ============================================================================
# TESTS: Path Utilities
# ============================================================================

test_normalize_extension() {
  local result

  result=$(normalize_extension ".md")
  assert_equals "md" "$result" || return 1

  result=$(normalize_extension "md")
  assert_equals "md" "$result" || return 1

  result=$(normalize_extension ".json")
  assert_equals "json" "$result" || return 1

  return 0
}

test_is_absolute_path() {
  assert_success is_absolute_path "/absolute/path" || return 1
  assert_failure is_absolute_path "relative/path" || return 1
  assert_success is_absolute_path "/tmp" || return 1
  return 0
}

test_get_absolute_path() {
  local result

  # Test with current directory
  result=$(get_absolute_path ".")
  [[ -n "$result" ]] || return 1

  # Test with existing file
  result=$(get_absolute_path "$SCRIPT_DIR/test-core.sh")
  [[ -n "$result" ]] || return 1

  return 0
}

# ============================================================================
# TESTS: String Utilities
# ============================================================================

test_trim() {
  local result

  result=$(trim "  hello  ")
  assert_equals "hello" "$result" || return 1

  result=$(trim "hello")
  assert_equals "hello" "$result" || return 1

  result=$(trim "   ")
  assert_equals "" "$result" || return 1

  return 0
}

test_to_lower() {
  local result

  result=$(to_lower "HELLO")
  assert_equals "hello" "$result" || return 1

  result=$(to_lower "HeLLo")
  assert_equals "hello" "$result" || return 1

  return 0
}

test_to_upper() {
  local result

  result=$(to_upper "hello")
  assert_equals "HELLO" "$result" || return 1

  result=$(to_upper "HeLLo")
  assert_equals "HELLO" "$result" || return 1

  return 0
}

test_starts_with() {
  assert_success starts_with "hello world" "hello" || return 1
  assert_failure starts_with "hello world" "world" || return 1
  assert_success starts_with "hello" "hello" || return 1
  return 0
}

test_ends_with() {
  assert_success ends_with "hello.md" ".md" || return 1
  assert_failure ends_with "hello.md" ".txt" || return 1
  assert_success ends_with "hello" "hello" || return 1
  return 0
}

# ============================================================================
# TESTS: Array Utilities
# ============================================================================

test_array_contains() {
  local arr=("foo" "bar" "baz")

  assert_success array_contains "foo" "${arr[@]}" || return 1
  assert_success array_contains "bar" "${arr[@]}" || return 1
  assert_failure array_contains "qux" "${arr[@]}" || return 1

  return 0
}

test_array_join() {
  local arr=("foo" "bar" "baz")
  local result

  result=$(array_join "," "${arr[@]}")
  assert_equals "foo,bar,baz" "$result" || return 1

  result=$(array_join " - " "${arr[@]}")
  assert_equals "foo - bar - baz" "$result" || return 1

  return 0
}

# ============================================================================
# TESTS: Validation
# ============================================================================

test_is_integer() {
  assert_success is_integer "123" || return 1
  assert_success is_integer "0" || return 1
  assert_failure is_integer "abc" || return 1
  assert_failure is_integer "12.3" || return 1
  assert_failure is_integer "-5" || return 1
  return 0
}

test_is_readable_file() {
  # Test with this test file (should exist and be readable)
  assert_success is_readable_file "$SCRIPT_DIR/test-core.sh" || return 1

  # Test with non-existent file
  assert_failure is_readable_file "/nonexistent/file" || return 1

  return 0
}

test_is_readable_dir() {
  # Test with project root (should exist and be readable)
  assert_success is_readable_dir "$PROJECT_ROOT" || return 1

  # Test with non-existent directory
  assert_failure is_readable_dir "/nonexistent/directory" || return 1

  return 0
}

# ============================================================================
# TESTS: System Info
# ============================================================================

test_get_cpu_cores() {
  local cores
  cores=$(get_cpu_cores)

  # Should return a positive integer
  if ! is_integer "$cores"; then
    echo "    FAIL: CPU cores is not an integer: $cores"
    return 1
  fi

  if [[ $cores -lt 1 ]]; then
    echo "    FAIL: CPU cores should be >= 1: $cores"
    return 1
  fi

  return 0
}

test_get_available_memory() {
  local memory
  memory=$(get_available_memory)

  # Should return a non-negative integer
  if ! is_integer "$memory"; then
    echo "    FAIL: Memory is not an integer: $memory"
    return 1
  fi

  return 0
}

# ============================================================================
# TESTS: Date & Time
# ============================================================================

test_get_timestamp() {
  local timestamp
  timestamp=$(get_timestamp)

  # Should be a positive integer
  if ! is_integer "$timestamp"; then
    echo "    FAIL: Timestamp is not an integer: $timestamp"
    return 1
  fi

  return 0
}

test_get_iso_timestamp() {
  local iso
  iso=$(get_iso_timestamp)

  # Should match ISO 8601 format (basic check)
  if [[ ! "$iso" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$ ]]; then
    echo "    FAIL: Invalid ISO timestamp format: $iso"
    return 1
  fi

  return 0
}

test_get_duration() {
  local duration

  duration=$(get_duration 100 150)
  assert_equals "50" "$duration" || return 1

  duration=$(get_duration 0 60)
  assert_equals "60" "$duration" || return 1

  return 0
}

test_format_duration() {
  local result

  result=$(format_duration 30)
  assert_equals "30s" "$result" || return 1

  result=$(format_duration 90)
  assert_equals "1m 30s" "$result" || return 1

  result=$(format_duration 3665)
  assert_equals "1h 1m 5s" "$result" || return 1

  return 0
}

# ============================================================================
# TESTS: Temporary Files
# ============================================================================

test_create_temp_file() {
  local tmpfile
  tmpfile=$(create_temp_file)

  # Should exist
  if [[ ! -f "$tmpfile" ]]; then
    echo "    FAIL: Temp file not created: $tmpfile"
    return 1
  fi

  # Cleanup
  rm -f "$tmpfile"
  return 0
}

test_create_temp_dir() {
  local tmpdir
  tmpdir=$(create_temp_dir)

  # Should exist
  if [[ ! -d "$tmpdir" ]]; then
    echo "    FAIL: Temp directory not created: $tmpdir"
    return 1
  fi

  # Cleanup
  rm -rf "$tmpdir"
  return 0
}

# ============================================================================
# RUN TESTS
# ============================================================================

main() {
  echo "Running tests for lib/core.sh"
  echo ""

  # Platform Detection
  echo "Platform Detection:"
  test_run "get_platform" test_get_platform
  test_run "is_macos" test_is_macos
  test_run "is_linux" test_is_linux

  # Path Utilities
  echo ""
  echo "Path Utilities:"
  test_run "normalize_extension" test_normalize_extension
  test_run "is_absolute_path" test_is_absolute_path
  test_run "get_absolute_path" test_get_absolute_path

  # String Utilities
  echo ""
  echo "String Utilities:"
  test_run "trim" test_trim
  test_run "to_lower" test_to_lower
  test_run "to_upper" test_to_upper
  test_run "starts_with" test_starts_with
  test_run "ends_with" test_ends_with

  # Array Utilities
  echo ""
  echo "Array Utilities:"
  test_run "array_contains" test_array_contains
  test_run "array_join" test_array_join

  # Validation
  echo ""
  echo "Validation:"
  test_run "is_integer" test_is_integer
  test_run "is_readable_file" test_is_readable_file
  test_run "is_readable_dir" test_is_readable_dir

  # System Info
  echo ""
  echo "System Info:"
  test_run "get_cpu_cores" test_get_cpu_cores
  test_run "get_available_memory" test_get_available_memory

  # Date & Time
  echo ""
  echo "Date & Time:"
  test_run "get_timestamp" test_get_timestamp
  test_run "get_iso_timestamp" test_get_iso_timestamp
  test_run "get_duration" test_get_duration
  test_run "format_duration" test_format_duration

  # Temporary Files
  echo ""
  echo "Temporary Files:"
  test_run "create_temp_file" test_create_temp_file
  test_run "create_temp_dir" test_create_temp_dir

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
