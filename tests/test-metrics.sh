#!/usr/bin/env bash
# tests/test-metrics.sh - Unit tests for lib/metrics.sh

set -uo pipefail

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Source modules
source "$PROJECT_ROOT/lib/core.sh"
source "$PROJECT_ROOT/lib/metrics.sh"

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

test_metrics_init() {
  metrics::init
  [[ ${#METRICS_ORDER[@]} -eq 0 ]]
}

test_metrics_get_timestamp_ms() {
  local ts
  ts=$(metrics::get_timestamp_ms)

  # Timestamp should be a positive integer
  [[ $ts -gt 0 ]] && [[ $ts =~ ^[0-9]+$ ]]
}

test_metrics_start() {
  metrics::init
  metrics::start "test_op"

  # Check that operation was recorded
  [[ ${METRICS_START["test_op"]} -gt 0 ]]
}

test_metrics_end() {
  metrics::init
  metrics::start "test_op"
  sleep 0.1
  metrics::end "test_op" 100 50 25

  # Check that end timestamp and values were recorded
  [[ ${METRICS_END["test_op"]} -gt 0 ]] && \
  [[ ${METRICS_FILES["test_op"]} -eq 100 ]] && \
  [[ ${METRICS_WITH_ATTRS["test_op"]} -eq 50 ]]
}

test_metrics_get_duration_ms() {
  metrics::init
  metrics::start "test_op"
  sleep 0.1
  metrics::end "test_op" 10 5

  local duration
  duration=$(metrics::get_duration_ms "test_op")

  # Duration should be at least 100ms
  [[ $duration -ge 90 ]]
}

test_metrics_get_duration_sec() {
  metrics::init
  metrics::start "test_op"
  sleep 0.1
  metrics::end "test_op" 10 5

  local duration
  duration=$(metrics::get_duration_sec "test_op")

  # Should contain decimal point
  [[ "$duration" =~ \. ]]
}

test_metrics_get_rate() {
  metrics::init
  metrics::start "test_op"
  sleep 0.1
  metrics::end "test_op" 100 50

  local rate
  rate=$(metrics::get_rate "test_op")

  # Rate should be positive
  [[ "$rate" =~ ^[0-9]+\.[0-9]+$ ]]
}

test_metrics_update() {
  metrics::init
  metrics::start "test_op"
  metrics::update "test_op" 50 25 10

  [[ ${METRICS_FILES["test_op"]} -eq 50 ]]
}

test_metrics_summary() {
  metrics::init
  metrics::start "op1"
  sleep 0.05
  metrics::end "op1" 100 50

  local summary
  summary=$(metrics::summary)

  # Summary should contain "Processed" and file count
  [[ "$summary" =~ Processed ]] && [[ "$summary" =~ 100 ]]
}

test_metrics_multiple_operations() {
  metrics::init

  metrics::start "op1"
  sleep 0.05
  metrics::end "op1" 50 25

  metrics::start "op2"
  sleep 0.05
  metrics::end "op2" 30 15

  # Check order is maintained
  [[ ${#METRICS_ORDER[@]} -eq 2 ]] && \
  [[ ${METRICS_ORDER[0]} == "op1" ]] && \
  [[ ${METRICS_ORDER[1]} == "op2" ]]
}

# ============================================================================
# MAIN
# ============================================================================

main() {
  echo "Running tests for lib/metrics.sh"
  echo ""

  echo "Initialization:"
  test_run "metrics_init" test_metrics_init
  test_run "metrics_get_timestamp_ms" test_metrics_get_timestamp_ms

  echo ""
  echo "Recording:"
  test_run "metrics_start" test_metrics_start
  test_run "metrics_end" test_metrics_end
  test_run "metrics_update" test_metrics_update

  echo ""
  echo "Calculations:"
  test_run "metrics_get_duration_ms" test_metrics_get_duration_ms
  test_run "metrics_get_duration_sec" test_metrics_get_duration_sec
  test_run "metrics_get_rate" test_metrics_get_rate

  echo ""
  echo "Reporting:"
  test_run "metrics_summary" test_metrics_summary
  test_run "metrics_multiple_operations" test_metrics_multiple_operations

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
