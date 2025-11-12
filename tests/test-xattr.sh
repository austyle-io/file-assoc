#!/usr/bin/env bash
# tests/test-xattr.sh - Unit tests for lib/xattr.sh

set -uo pipefail

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Source modules
source "$PROJECT_ROOT/lib/core.sh"
source "$PROJECT_ROOT/lib/xattr.sh"

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

# ============================================================================
# TESTS
# ============================================================================

test_xattr_is_available() {
  # This test checks if xattr command exists
  # On Linux, xattr might not be available, which is okay
  if is_macos; then
    xattr::is_available
  else
    # On Linux, just pass the test
    return 0
  fi
}

test_xattr_version() {
  if is_macos; then
    local version
    version=$(xattr::version)
    [[ -n "$version" ]]
  else
    # On Linux, just pass the test
    return 0
  fi
}

test_xattr_has_launch_services_false() {
  local test_file
  test_file=$(create_temp_file)

  # New file should not have LaunchServices attribute
  xattr::has_launch_services "$test_file"
  local result=$?

  rm -f "$test_file"
  [[ $result -eq 1 ]]
}

test_xattr_has_any_false() {
  local test_file
  test_file=$(create_temp_file)

  # New file should not have any attributes
  xattr::has_any "$test_file"
  local result=$?

  rm -f "$test_file"
  [[ $result -eq 1 ]]
}

test_xattr_list_empty() {
  local test_file
  test_file=$(create_temp_file)

  local attrs
  attrs=$(xattr::list "$test_file")

  rm -f "$test_file"
  [[ -z "$attrs" ]]
}

test_xattr_clear_launch_services_no_attr() {
  local test_file
  test_file=$(create_temp_file)

  # Trying to clear non-existent attribute should return 1
  xattr::clear_launch_services "$test_file"
  local result=$?

  rm -f "$test_file"
  [[ $result -eq 1 ]]
}

test_xattr_invalid_file() {
  # All functions should handle invalid files gracefully
  xattr::has_launch_services "/nonexistent/file" || return 0
  return 1
}

# ============================================================================
# MAIN
# ============================================================================

main() {
  echo "Running tests for lib/xattr.sh"
  echo ""

  if ! is_macos; then
    echo "⚠️  Extended attributes are macOS-specific"
    echo "   Running basic compatibility tests only"
    echo ""
  fi

  echo "Availability:"
  test_run "xattr_is_available" test_xattr_is_available
  test_run "xattr_version" test_xattr_version

  echo ""
  echo "Checking:"
  test_run "xattr_has_launch_services_false" test_xattr_has_launch_services_false
  test_run "xattr_has_any_false" test_xattr_has_any_false

  echo ""
  echo "Listing:"
  test_run "xattr_list_empty" test_xattr_list_empty

  echo ""
  echo "Clearing:"
  test_run "xattr_clear_launch_services_no_attr" test_xattr_clear_launch_services_no_attr

  echo ""
  echo "Error Handling:"
  test_run "xattr_invalid_file" test_xattr_invalid_file

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
