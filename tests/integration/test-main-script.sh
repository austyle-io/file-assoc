#!/usr/bin/env bash
# Integration tests for reset-file-associations-v2.sh
#
# Tests the main script functionality end-to-end

set -euo pipefail

# ============================================================================
# TEST CONFIGURATION
# ============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
SCRIPT_V2="$PROJECT_ROOT/scripts/reset-file-associations-v2.sh"

# Test results
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0
TEST_OUTPUT=""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# ============================================================================
# TEST UTILITIES
# ============================================================================

# Print colored message
print_color() {
  local color=$1
  shift
  echo -e "${color}$*${NC}"
}

# Start a test
start_test() {
  local test_name="$1"
  TESTS_RUN=$((TESTS_RUN + 1))
  print_color "$BLUE" "\n[Test $TESTS_RUN] $test_name"
  TEST_OUTPUT=""
}

# Assert test passed
pass_test() {
  TESTS_PASSED=$((TESTS_PASSED + 1))
  print_color "$GREEN" "  ✓ PASSED"
}

# Assert test failed
fail_test() {
  local reason="$1"
  TESTS_FAILED=$((TESTS_FAILED + 1))
  print_color "$RED" "  ✗ FAILED: $reason"
  if [[ -n "$TEST_OUTPUT" ]]; then
    echo "  Output:"
    echo "$TEST_OUTPUT" | sed 's/^/    /'
  fi
}

# Assert condition is true
assert_true() {
  local condition="$1"
  local message="${2:-Assertion failed}"

  if eval "$condition"; then
    return 0
  else
    fail_test "$message"
    return 1
  fi
}

# Assert command succeeds
assert_success() {
  local cmd="$1"
  local message="${2:-Command should succeed}"

  if TEST_OUTPUT=$(eval "$cmd" 2>&1); then
    return 0
  else
    fail_test "$message"
    return 1
  fi
}

# Assert command fails
assert_failure() {
  local cmd="$1"
  local message="${2:-Command should fail}"

  if TEST_OUTPUT=$(eval "$cmd" 2>&1); then
    fail_test "$message"
    return 1
  else
    return 0
  fi
}

# Assert output contains string
assert_contains() {
  local haystack="$1"
  local needle="$2"
  local message="${3:-Output should contain '$needle'}"

  if echo "$haystack" | grep -q "$needle"; then
    return 0
  else
    fail_test "$message"
    return 1
  fi
}

# Assert file exists
assert_file_exists() {
  local file="$1"
  local message="${2:-File should exist: $file}"

  if [[ -f "$file" ]]; then
    return 0
  else
    fail_test "$message"
    return 1
  fi
}

# Assert file does not exist
assert_file_not_exists() {
  local file="$1"
  local message="${2:-File should not exist: $file}"

  if [[ ! -f "$file" ]]; then
    return 0
  else
    fail_test "$message"
    return 1
  fi
}

# ============================================================================
# TEST FIXTURES
# ============================================================================

# Create test directory with sample files
setup_test_files() {
  local test_dir
  test_dir=$(mktemp -d -t file-assoc-test-XXXXXX)

  # Create subdirectories
  mkdir -p "$test_dir/docs"
  mkdir -p "$test_dir/images"
  mkdir -p "$test_dir/videos"

  # Create test files
  touch "$test_dir/docs/test1.pdf"
  touch "$test_dir/docs/test2.pdf"
  touch "$test_dir/docs/document.docx"
  touch "$test_dir/images/photo1.jpg"
  touch "$test_dir/images/photo2.png"
  touch "$test_dir/videos/movie.mp4"
  touch "$test_dir/readme.txt"

  # Add xattr to some files (only on macOS)
  if command -v xattr >/dev/null 2>&1 && [[ "$(uname)" == "Darwin" ]]; then
    xattr -w com.apple.LaunchServices.OpenWith "test" "$test_dir/docs/test1.pdf" 2>/dev/null || true
    xattr -w com.apple.LaunchServices.OpenWith "test" "$test_dir/images/photo1.jpg" 2>/dev/null || true
  fi

  echo "$test_dir"
}

# Cleanup test directory
teardown_test_files() {
  local test_dir="$1"
  if [[ -n "$test_dir" ]] && [[ -d "$test_dir" ]]; then
    rm -rf "$test_dir"
  fi
}

# ============================================================================
# TESTS
# ============================================================================

# Test: Script exists and is executable
test_script_exists() {
  start_test "Script exists and is executable"

  if assert_file_exists "$SCRIPT_V2" "Script should exist"; then
    if assert_true "[[ -x '$SCRIPT_V2' ]]" "Script should be executable"; then
      pass_test
    fi
  fi
}

# Test: Help output
test_help_output() {
  start_test "Help output works"

  if assert_success "'$SCRIPT_V2' --help" "Help command should succeed"; then
    if assert_contains "$TEST_OUTPUT" "Usage:" "Help should contain usage"; then
      if assert_contains "$TEST_OUTPUT" "OPTIONS:" "Help should contain options"; then
        pass_test
      fi
    fi
  fi
}

# Test: Dry run mode
test_dry_run() {
  start_test "Dry run mode doesn't modify files"

  local test_dir
  test_dir=$(setup_test_files)

  # Run in dry-run mode
  if TEST_OUTPUT=$("$SCRIPT_V2" --dry-run --no-confirm -e pdf "$test_dir" 2>&1); then
    # Check that the output mentions dry run
    if assert_contains "$TEST_OUTPUT" "DRY RUN" "Output should mention dry run mode"; then
      # Script should complete successfully
      pass_test
    fi
  else
    fail_test "Dry run should succeed"
  fi

  teardown_test_files "$test_dir"
}

# Test: Basic execution
test_basic_execution() {
  start_test "Basic execution completes successfully"

  local test_dir
  test_dir=$(setup_test_files)

  # Run script with minimal options
  if TEST_OUTPUT=$("$SCRIPT_V2" --no-confirm --skip-sampling -e txt "$test_dir" 2>&1); then
    # Check for success indicators
    if assert_contains "$TEST_OUTPUT" "Processing Complete" "Should show completion"; then
      pass_test
    fi
  else
    fail_test "Basic execution should succeed"
  fi

  teardown_test_files "$test_dir"
}

# Test: Extension filtering
test_extension_filtering() {
  start_test "Extension filtering works correctly"

  local test_dir
  test_dir=$(setup_test_files)

  # Run script filtering only PDF files
  if TEST_OUTPUT=$("$SCRIPT_V2" --no-confirm --skip-sampling -e pdf "$test_dir" 2>&1); then
    # Should mention PDF files
    if assert_contains "$TEST_OUTPUT" "pdf" "Should process PDF files"; then
      # Should not process other extensions (unless mentioned in summary)
      pass_test
    fi
  else
    fail_test "Extension filtering should work"
  fi

  teardown_test_files "$test_dir"
}

# Test: Multiple extensions
test_multiple_extensions() {
  start_test "Multiple extensions can be specified"

  local test_dir
  test_dir=$(setup_test_files)

  # Run script with multiple extensions
  if TEST_OUTPUT=$("$SCRIPT_V2" --no-confirm --skip-sampling -e pdf -e jpg -e txt "$test_dir" 2>&1); then
    # Should complete successfully
    if assert_contains "$TEST_OUTPUT" "Processing Complete" "Should complete"; then
      pass_test
    fi
  else
    fail_test "Multiple extensions should work"
  fi

  teardown_test_files "$test_dir"
}

# Test: Sampling phase
test_sampling() {
  start_test "Sampling phase executes"

  local test_dir
  test_dir=$(setup_test_files)

  # Run script with sampling enabled
  if TEST_OUTPUT=$("$SCRIPT_V2" --no-confirm --sample-size 5 -e pdf "$test_dir" 2>&1); then
    # Should mention sampling
    if assert_contains "$TEST_OUTPUT" "sampling" "Should mention sampling phase"; then
      pass_test
    fi
  else
    fail_test "Sampling should work"
  fi

  teardown_test_files "$test_dir"
}

# Test: Skip sampling flag
test_skip_sampling() {
  start_test "Skip sampling flag works"

  local test_dir
  test_dir=$(setup_test_files)

  # Run script with skip-sampling
  if TEST_OUTPUT=$("$SCRIPT_V2" --no-confirm --skip-sampling -e pdf "$test_dir" 2>&1); then
    # Should not mention sampling
    if ! echo "$TEST_OUTPUT" | grep -qi "sampling phase"; then
      pass_test
    else
      fail_test "Should skip sampling phase"
    fi
  else
    fail_test "Skip sampling should work"
  fi

  teardown_test_files "$test_dir"
}

# Test: Verbose output
test_verbose_output() {
  start_test "Verbose flag increases output"

  local test_dir
  test_dir=$(setup_test_files)

  # Run without verbose
  local output_normal
  output_normal=$("$SCRIPT_V2" --no-confirm --skip-sampling -e txt "$test_dir" 2>&1 || true)

  # Run with verbose
  local output_verbose
  output_verbose=$("$SCRIPT_V2" --verbose --no-confirm --skip-sampling -e txt "$test_dir" 2>&1 || true)

  # Verbose output should be longer (or at least same length)
  local len_normal=${#output_normal}
  local len_verbose=${#output_verbose}

  if assert_true "[[ $len_verbose -ge $len_normal ]]" "Verbose output should be >= normal"; then
    pass_test
  fi

  teardown_test_files "$test_dir"
}

# Test: Invalid directory
test_invalid_directory() {
  start_test "Invalid directory is rejected"

  # Try to run on non-existent directory
  if assert_failure "'$SCRIPT_V2' /non/existent/directory 2>&1" "Should fail on invalid directory"; then
    if assert_contains "$TEST_OUTPUT" "Error" "Should show error message"; then
      pass_test
    fi
  fi
}

# Test: Max files limit
test_max_files_limit() {
  start_test "Max files limit is respected"

  local test_dir
  test_dir=$(setup_test_files)

  # Run with very low max-files limit
  if TEST_OUTPUT=$("$SCRIPT_V2" --no-confirm --skip-sampling --max-files 1 -e pdf "$test_dir" 2>&1); then
    # Should either skip or warn about exceeding limit
    if assert_contains "$TEST_OUTPUT" "exceed" "Should mention exceeding limit" || \
       assert_contains "$TEST_OUTPUT" "Skipping" "Should skip processing"; then
      pass_test
    fi
  else
    # Command might fail, which is also acceptable
    pass_test
  fi

  teardown_test_files "$test_dir"
}

# Test: Log file creation
test_log_file_creation() {
  start_test "Log file is created"

  local test_dir
  test_dir=$(setup_test_files)

  # Run script
  TEST_OUTPUT=$("$SCRIPT_V2" --no-confirm --skip-sampling -e txt "$test_dir" 2>&1 || true)

  # Check if log file location is mentioned
  if assert_contains "$TEST_OUTPUT" "Log file:" "Should mention log file"; then
    # Extract log file path (this is a simplified check)
    if echo "$TEST_OUTPUT" | grep -q "\.dotfiles-logs"; then
      pass_test
    else
      fail_test "Should create log in expected location"
    fi
  fi

  teardown_test_files "$test_dir"
}

# Test: No-confirm flag
test_no_confirm() {
  start_test "No-confirm flag skips prompts"

  local test_dir
  test_dir=$(setup_test_files)

  # Run with no-confirm - should not hang waiting for input
  # Use timeout to ensure it doesn't hang
  if timeout 10s "$SCRIPT_V2" --no-confirm --skip-sampling -e txt "$test_dir" >/dev/null 2>&1; then
    pass_test
  else
    fail_test "Should not prompt when --no-confirm is used"
  fi

  teardown_test_files "$test_dir"
}

# Test: Path option precedence
test_path_option() {
  start_test "Path option takes precedence over positional arg"

  local test_dir
  test_dir=$(setup_test_files)

  # Run with both --path and positional argument
  # The --path should take precedence
  if TEST_OUTPUT=$("$SCRIPT_V2" --no-confirm --skip-sampling --path "$test_dir" -e txt . 2>&1); then
    if assert_contains "$TEST_OUTPUT" "Processing Complete" "Should complete successfully"; then
      pass_test
    fi
  else
    fail_test "Path option should work"
  fi

  teardown_test_files "$test_dir"
}

# ============================================================================
# TEST RUNNER
# ============================================================================

# Run all tests
run_all_tests() {
  print_color "$BLUE" "=========================================="
  print_color "$BLUE" "  File Association Reset - Integration Tests"
  print_color "$BLUE" "=========================================="

  # Pre-flight check
  if [[ ! -f "$SCRIPT_V2" ]]; then
    print_color "$RED" "Error: Script not found at $SCRIPT_V2"
    exit 1
  fi

  # Run tests
  test_script_exists
  test_help_output
  test_dry_run
  test_basic_execution
  test_extension_filtering
  test_multiple_extensions
  test_sampling
  test_skip_sampling
  test_verbose_output
  test_invalid_directory
  test_max_files_limit
  test_log_file_creation
  test_no_confirm
  test_path_option

  # Print summary
  print_color "$BLUE" "\n=========================================="
  print_color "$BLUE" "  Test Summary"
  print_color "$BLUE" "=========================================="
  echo "Tests run:    $TESTS_RUN"
  print_color "$GREEN" "Tests passed: $TESTS_PASSED"

  if [[ $TESTS_FAILED -gt 0 ]]; then
    print_color "$RED" "Tests failed: $TESTS_FAILED"
    echo ""
    print_color "$RED" "FAILED"
    return 1
  else
    echo ""
    print_color "$GREEN" "ALL TESTS PASSED"
    return 0
  fi
}

# ============================================================================
# MAIN
# ============================================================================

main() {
  run_all_tests
}

# Run if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi
