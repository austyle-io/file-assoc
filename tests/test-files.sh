#!/usr/bin/env bash
# tests/test-files.sh - Unit tests for lib/files.sh

set -uo pipefail

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Source modules
source "$PROJECT_ROOT/lib/core.sh"
source "$PROJECT_ROOT/lib/files.sh"

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

test_files_count() {
  local test_dir
  test_dir=$(create_temp_dir)

  # Create some test files
  touch "$test_dir/file1.txt"
  touch "$test_dir/file2.txt"
  touch "$test_dir/file3.md"

  local count
  count=$(files::count "$test_dir" "txt")

  rm -rf "$test_dir"
  [[ $count -eq 2 ]]
}

test_files_count_all() {
  local test_dir
  test_dir=$(create_temp_dir)

  touch "$test_dir/file1.txt"
  touch "$test_dir/file2.md"
  touch "$test_dir/file3.doc"

  local count
  count=$(files::count_all "$test_dir")

  rm -rf "$test_dir"
  [[ $count -eq 3 ]]
}

test_files_count_multiple() {
  local test_dir
  test_dir=$(create_temp_dir)

  touch "$test_dir/file1.txt"
  touch "$test_dir/file2.txt"
  touch "$test_dir/file3.md"
  touch "$test_dir/file4.doc"

  local count
  count=$(files::count_multiple "$test_dir" "txt" "md")

  rm -rf "$test_dir"
  [[ $count -eq 3 ]]
}

test_files_find_by_ext() {
  local test_dir
  test_dir=$(create_temp_dir)

  touch "$test_dir/file1.txt"
  touch "$test_dir/file2.txt"
  touch "$test_dir/file3.md"

  local found
  found=$(files::find_by_ext "$test_dir" "txt" | wc -l | tr -d ' ')

  rm -rf "$test_dir"
  [[ $found -eq 2 ]]
}

test_files_validate_directory() {
  local test_dir
  test_dir=$(create_temp_dir)

  files::validate_directory "$test_dir"
  local result=$?

  rm -rf "$test_dir"
  [[ $result -eq 0 ]]
}

test_files_validate_directory_invalid() {
  files::validate_directory "/nonexistent/path/$(date +%s)"
  local result=$?

  [[ $result -eq 1 ]]
}

test_files_get_absolute_dir() {
  local test_dir
  test_dir=$(create_temp_dir)

  local abs_path
  abs_path=$(files::get_absolute_dir "$test_dir")

  rm -rf "$test_dir"
  [[ "$abs_path" == "$test_dir" ]]
}

test_files_get_size() {
  local test_file
  test_file=$(create_temp_file)

  echo "hello world" > "$test_file"

  local size
  size=$(files::get_size "$test_file")

  rm -f "$test_file"
  [[ $size -gt 0 ]]
}

test_files_format_size() {
  local formatted
  formatted=$(files::format_size 500)
  [[ "$formatted" == "500 B" ]] || return 1

  formatted=$(files::format_size 2048)
  [[ "$formatted" == "2.0 KB" ]] || return 1

  formatted=$(files::format_size $((5 * 1024 * 1024)))
  [[ "$formatted" == "5.0 MB" ]]
}

test_files_get_extension() {
  local ext
  ext=$(files::get_extension "test.txt")
  [[ "$ext" == "txt" ]] || return 1

  ext=$(files::get_extension "/path/to/file.md")
  [[ "$ext" == "md" ]] || return 1

  ext=$(files::get_extension "file.tar.gz")
  [[ "$ext" == "gz" ]]
}

test_files_has_extension() {
  files::has_extension "test.txt" "txt" || return 1
  files::has_extension "file.md" "md" || return 1
  ! files::has_extension "file.txt" "md"
}

test_files_estimate_time() {
  local estimate
  estimate=$(files::estimate_time 1000 500)
  [[ $estimate -eq 2 ]] || return 1

  estimate=$(files::estimate_time 100 500)
  [[ $estimate -eq 1 ]]
}

# ============================================================================
# MAIN
# ============================================================================

main() {
  echo "Running tests for lib/files.sh"
  echo ""

  echo "Counting:"
  test_run "files_count" test_files_count
  test_run "files_count_all" test_files_count_all
  test_run "files_count_multiple" test_files_count_multiple

  echo ""
  echo "Finding:"
  test_run "files_find_by_ext" test_files_find_by_ext

  echo ""
  echo "Validation:"
  test_run "files_validate_directory" test_files_validate_directory
  test_run "files_validate_directory_invalid" test_files_validate_directory_invalid
  test_run "files_get_absolute_dir" test_files_get_absolute_dir

  echo ""
  echo "Size Operations:"
  test_run "files_get_size" test_files_get_size
  test_run "files_format_size" test_files_format_size

  echo ""
  echo "Extension Operations:"
  test_run "files_get_extension" test_files_get_extension
  test_run "files_has_extension" test_files_has_extension

  echo ""
  echo "Estimation:"
  test_run "files_estimate_time" test_files_estimate_time

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
