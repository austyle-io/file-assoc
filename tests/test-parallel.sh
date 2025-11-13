#!/usr/bin/env bash
# tests/test-parallel.sh - Unit tests for lib/parallel.sh

set -euo pipefail

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Source the module
# shellcheck source=../lib/parallel.sh
source "$PROJECT_ROOT/lib/parallel.sh"

# Test framework variables
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

#######################################
# Run a test and track results
# Arguments:
#   $1 - Test name
#   $2 - Test function name
#######################################
run_test() {
  local test_name="$1"
  local test_func="$2"

  ((TESTS_RUN++))

  if $test_func; then
    echo -e "${GREEN}✓${NC} $test_name"
    ((TESTS_PASSED++))
    return 0
  else
    echo -e "${RED}✗${NC} $test_name"
    ((TESTS_FAILED++))
    return 1
  fi
}

#######################################
# Test: parallel::init works
#######################################
test_parallel_init() {
  # Re-run init to test it
  if command -v parallel >/dev/null 2>&1; then
    parallel::init
    [[ "$PARALLEL_AVAILABLE" == "true" ]]
  else
    # If parallel not installed, init should return 1
    ! parallel::init
    [[ "$PARALLEL_AVAILABLE" == "false" ]]
  fi
}

#######################################
# Test: parallel::is_available returns correct status
#######################################
test_parallel_is_available() {
  if command -v parallel >/dev/null 2>&1; then
    parallel::is_available
  else
    ! parallel::is_available
  fi
}

#######################################
# Test: parallel::get_workers returns valid number
#######################################
test_parallel_get_workers() {
  local workers
  workers=$(parallel::get_workers)

  # Should be a number
  [[ "$workers" =~ ^[0-9]+$ ]] || return 1

  # Should be at least 1
  [[ $workers -ge 1 ]] || return 1

  # Should not exceed 128 (reasonable max)
  [[ $workers -le 128 ]]
}

#######################################
# Test: parallel::get_workers respects WORKERS variable
#######################################
test_parallel_workers_override() {
  local original_workers=${WORKERS:-}

  # Set custom worker count
  export WORKERS=8
  local workers
  workers=$(parallel::get_workers)

  # Restore original
  if [[ -n "$original_workers" ]]; then
    export WORKERS="$original_workers"
  else
    unset WORKERS
  fi

  # Should return 8
  [[ "$workers" == "8" ]]
}

#######################################
# Test: parallel::version returns version string
#######################################
test_parallel_version() {
  if command -v parallel >/dev/null 2>&1; then
    local version
    version=$(parallel::version)
    [[ -n "$version" ]] && [[ "$version" != "GNU Parallel not available" ]]
  else
    local version
    version=$(parallel::version)
    [[ "$version" == "GNU Parallel not available" ]]
  fi
}

#######################################
# Test: parallel::run with simple command
#######################################
test_parallel_run_simple() {
  if ! command -v parallel >/dev/null 2>&1; then
    echo "Skipping: parallel not installed" >&2
    return 0
  fi

  # Create temp file with test data
  local temp_file
  temp_file=$(mktemp)
  echo -e "1\n2\n3" > "$temp_file"

  # Run simple echo command
  local output
  output=$(cat "$temp_file" | parallel::run echo "Number: {}")

  rm -f "$temp_file"

  # Should have 3 lines
  local line_count
  line_count=$(echo "$output" | wc -l | tr -d ' ')
  [[ "$line_count" == "3" ]]
}

#######################################
# Test: parallel::process_files with function
#######################################
test_parallel_process_files() {
  if ! command -v parallel >/dev/null 2>&1; then
    echo "Skipping: parallel not installed" >&2
    return 0
  fi

  # Define test function
  test_process_file() {
    local file="$1"
    echo "Processed: $file"
  }
  export -f test_process_file

  # Create temp files
  local temp_dir
  temp_dir=$(mktemp -d)
  touch "$temp_dir/file1.txt"
  touch "$temp_dir/file2.txt"

  # Process files
  local output
  output=$(find "$temp_dir" -type f | parallel::process_files test_process_file false)

  # Cleanup
  rm -rf "$temp_dir"

  # Should have processed 2 files
  local line_count
  line_count=$(echo "$output" | wc -l | tr -d ' ')
  [[ "$line_count" == "2" ]]
}

#######################################
# Test: parallel::process_files fails with non-existent function
#######################################
test_parallel_process_files_invalid_function() {
  if ! command -v parallel >/dev/null 2>&1; then
    echo "Skipping: parallel not installed" >&2
    return 0
  fi

  # Should fail with non-existent function
  ! echo "test" | parallel::process_files nonexistent_function_xyz false 2>/dev/null
}

#######################################
# Test: parallel::status displays information
#######################################
test_parallel_status() {
  local output
  output=$(parallel::status)

  # Should contain status information
  echo "$output" | grep -q "GNU Parallel Module Status"
}

#######################################
# Test: parallel::run maintains input order
#######################################
test_parallel_run_order() {
  if ! command -v parallel >/dev/null 2>&1; then
    echo "Skipping: parallel not installed" >&2
    return 0
  fi

  # Test that output order matches input order
  local input="1
2
3
4
5"
  local output
  output=$(echo "$input" | parallel::run echo {})

  # Output should match input
  [[ "$output" == "$input" ]]
}

#######################################
# Main test runner
#######################################
main() {
  echo "Running parallel.sh tests..."
  echo ""

  # Run all tests
  run_test "parallel::init works" test_parallel_init
  run_test "parallel::is_available returns correct status" test_parallel_is_available
  run_test "parallel::get_workers returns valid number" test_parallel_get_workers
  run_test "parallel::get_workers respects WORKERS override" test_parallel_workers_override
  run_test "parallel::version returns version string" test_parallel_version
  run_test "parallel::run with simple command" test_parallel_run_simple
  run_test "parallel::process_files with function" test_parallel_process_files
  run_test "parallel::process_files fails with invalid function" test_parallel_process_files_invalid_function
  run_test "parallel::status displays information" test_parallel_status
  run_test "parallel::run maintains input order" test_parallel_run_order

  # Print summary
  echo ""
  echo "================================"
  echo "Test Summary:"
  echo "  Total:  $TESTS_RUN"
  echo -e "  ${GREEN}Passed: $TESTS_PASSED${NC}"

  if [[ $TESTS_FAILED -gt 0 ]]; then
    echo -e "  ${RED}Failed: $TESTS_FAILED${NC}"
    echo "================================"
    exit 1
  else
    echo "================================"
    echo -e "${GREEN}All tests passed!${NC}"
    exit 0
  fi
}

# Run tests
main
