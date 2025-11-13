#!/usr/bin/env bash
# tests/test-parallel.sh - Unit tests for lib/parallel.sh
#
# Run with: ./tests/test-parallel.sh
# Or: just test-unit

set -uo pipefail

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Source modules
source "$PROJECT_ROOT/lib/core.sh"
source "$PROJECT_ROOT/lib/parallel.sh"

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

# Assert value is in range
assert_in_range() {
  local value=$1
  local min=$2
  local max=$3

  if [[ ! "$value" =~ ^[0-9]+$ ]]; then
    echo "    FAIL: Value '$value' is not an integer"
    return 1
  fi

  if [[ $value -lt $min ]] || [[ $value -gt $max ]]; then
    echo "    FAIL: Value $value not in range [$min, $max]"
    return 1
  fi

  return 0
}

# ============================================================================
# TESTS: Initialization
# ============================================================================

test_parallel_init() {
  # Should initialize without error (returns 0 if available, 1 if not)
  parallel::init || true

  # PARALLEL_AVAILABLE should be set (true or false)
  if [[ -z "$PARALLEL_AVAILABLE" ]]; then
    echo "    FAIL: PARALLEL_AVAILABLE not set"
    return 1
  fi

  # Should be either true or false
  if [[ "$PARALLEL_AVAILABLE" != "true" ]] && [[ "$PARALLEL_AVAILABLE" != "false" ]]; then
    echo "    FAIL: PARALLEL_AVAILABLE has invalid value: $PARALLEL_AVAILABLE"
    return 1
  fi

  return 0
}

test_parallel_is_available() {
  # Should return 0 or 1 (not error)
  parallel::is_available || true

  # If available, verify version is set
  if parallel::is_available; then
    if [[ -z "$PARALLEL_VERSION" ]]; then
      echo "    FAIL: PARALLEL_VERSION not set when parallel is available"
      return 1
    fi
  else
    echo "    INFO: Parallel not available, test passed with graceful handling"
  fi

  return 0
}

# ============================================================================
# TESTS: Worker Management
# ============================================================================

test_parallel_get_workers() {
  local workers
  workers=$(parallel::get_workers)

  # Should return a valid integer
  if ! is_integer "$workers"; then
    echo "    FAIL: Worker count is not an integer: $workers"
    return 1
  fi

  # Should be in reasonable range (1-128)
  assert_in_range "$workers" 1 128 || return 1

  return 0
}

test_parallel_workers_override() {
  # Test WORKERS environment variable override
  local original_workers=${WORKERS:-}

  # Set WORKERS env var
  export WORKERS=8

  # Get workers (should return 8)
  local workers
  workers=$(parallel::get_workers)

  # Restore original
  if [[ -n "$original_workers" ]]; then
    export WORKERS=$original_workers
  else
    unset WORKERS
  fi

  # Verify override worked
  assert_equals "8" "$workers" || return 1

  return 0
}

# ============================================================================
# TESTS: Version & Status
# ============================================================================

test_parallel_version() {
  local version
  version=$(parallel::version)

  # Should not be empty
  if [[ -z "$version" ]]; then
    echo "    FAIL: Version string is empty"
    return 1
  fi

  # If parallel is available, should not be "unknown"
  if parallel::is_available; then
    if [[ "$version" == "unknown" ]]; then
      echo "    FAIL: Version is 'unknown' when parallel is available"
      return 1
    fi
  else
    # If not available, should be "unknown"
    if [[ "$version" != "unknown" ]]; then
      echo "    FAIL: Version should be 'unknown' when parallel is not available"
      return 1
    fi
  fi

  return 0
}

# ============================================================================
# TESTS: Execution (requires parallel to be installed)
# ============================================================================

test_parallel_run() {
  if ! parallel::is_available; then
    echo "    SKIP: Parallel not installed"
    return 0
  fi

  # Test basic parallel execution
  local output
  output=$(echo -e "1\n2\n3" | parallel::run "echo test_{}")

  # Should contain expected output
  assert_contains "$output" "test_1" || return 1
  assert_contains "$output" "test_2" || return 1
  assert_contains "$output" "test_3" || return 1

  return 0
}

test_parallel_process_files() {
  if ! parallel::is_available; then
    echo "    SKIP: Parallel not installed"
    return 0
  fi

  # Create a test function
  test_file_processor() {
    local file=$1
    echo "processed:$file"
  }
  export -f test_file_processor

  # Test processing files
  local output
  output=$(echo -e "file1.txt\nfile2.txt" | parallel::process_files "test_file_processor" false)

  # Should contain expected output
  assert_contains "$output" "processed:file1.txt" || return 1
  assert_contains "$output" "processed:file2.txt" || return 1

  return 0
}

test_parallel_process_files_invalid() {
  if ! parallel::is_available; then
    echo "    SKIP: Parallel not installed"
    return 0
  fi

  # Test with non-existent function (should fail)
  local output
  output=$(echo "test.txt" | parallel::process_files "nonexistent_function" false 2>&1) || true

  # Should contain error message
  assert_contains "$output" "does not exist" || return 1

  return 0
}

# ============================================================================
# TESTS: Status & Display
# ============================================================================

test_parallel_status() {
  local output
  output=$(parallel::status 2>&1)

  # Should contain status information
  assert_contains "$output" "GNU Parallel Module Status" || return 1
  assert_contains "$output" "Version" || return 1

  if parallel::is_available; then
    assert_contains "$output" "Available" || return 1
    assert_contains "$output" "Workers" || return 1
  else
    assert_contains "$output" "Not available" || return 1
  fi

  return 0
}

# ============================================================================
# TESTS: Order Preservation
# ============================================================================

test_parallel_run_order() {
  if ! parallel::is_available; then
    echo "    SKIP: Parallel not installed"
    return 0
  fi

  # Test that --keep-order maintains input order
  local output
  output=$(echo -e "3\n1\n2" | parallel::run "echo {}")

  # Convert to array
  local -a lines
  mapfile -t lines <<< "$output"

  # Should maintain input order (3, 1, 2)
  assert_equals "3" "${lines[0]}" || return 1
  assert_equals "1" "${lines[1]}" || return 1
  assert_equals "2" "${lines[2]}" || return 1

  return 0
}

# ============================================================================
# RUN TESTS
# ============================================================================

main() {
  echo "Running tests for lib/parallel.sh"
  echo ""

  # Check if parallel is available
  if parallel::is_available; then
    echo "GNU Parallel is available: $(parallel::version)"
    echo "All tests will run"
  else
    echo "GNU Parallel not available"
    echo "Some tests will be skipped gracefully"
  fi
  echo ""

  # Initialization
  echo "Initialization:"
  test_run "parallel_init" test_parallel_init
  test_run "parallel_is_available" test_parallel_is_available

  # Worker Management
  echo ""
  echo "Worker Management:"
  test_run "parallel_get_workers" test_parallel_get_workers
  test_run "parallel_workers_override" test_parallel_workers_override

  # Version & Status
  echo ""
  echo "Version & Status:"
  test_run "parallel_version" test_parallel_version
  test_run "parallel_status" test_parallel_status

  # Execution (requires parallel)
  echo ""
  echo "Execution:"
  test_run "parallel_run" test_parallel_run
  test_run "parallel_process_files" test_parallel_process_files
  test_run "parallel_process_files_invalid" test_parallel_process_files_invalid

  # Order Preservation
  echo ""
  echo "Order Preservation:"
  test_run "parallel_run_order" test_parallel_run_order

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

# Run tests if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main
fi
