#!/usr/bin/env bats
# Integration tests for the shipped file-assoc entrypoints:
#   bin/file-assoc-setup, bin/file-assoc-reset, scripts/reset-file-associations.sh

load '../helpers/test_helper'

setup() {
  _common_setup
}

teardown() {
  _common_teardown
}

# ---------------------------------------------------------------------------
# Wrapper help / config
# ---------------------------------------------------------------------------

@test "file-assoc-setup --help prints usage" {
  run "$SETUP_BIN" --help
  assert_success
  assert_output --partial "file-assoc-setup"
  assert_output --partial "USAGE:"
}

@test "file-assoc-setup --configure points at the repo-local duti config" {
  # EDITOR=true makes the wrapper exec a no-op editor after printing the path,
  # so the test never blocks on an interactive editor.
  EDITOR=true run "$SETUP_BIN" --configure
  assert_success
  assert_output --partial "${PROJECT_ROOT}/config/macos-file-associations.duti"
}

@test "file-assoc-reset --help is forwarded to the reset script" {
  run "$RESET_BIN" --help
  assert_success
  assert_output --partial "Usage:"
  assert_output --partial "Reset file associations"
}

@test "reset script --help documents key flags" {
  run "$RESET_SCRIPT" --help
  assert_success
  assert_output --partial "--dry-run"
  assert_output --partial "--skip-sampling"
  assert_output --partial "--no-parallel"
}

# ---------------------------------------------------------------------------
# Dry-run behavior
# ---------------------------------------------------------------------------

@test "dry run reports DRY RUN and completes without modifying files" {
  local fixture
  fixture="$(make_fixture_dir)"

  run "$RESET_SCRIPT" --dry-run --no-confirm --skip-sampling --no-parallel \
    --log-file "${TEST_SANDBOX}/dry-run.log" -e md "$fixture"
  assert_success
  assert_output --partial "DRY RUN"
  assert_output --partial "Total files scanned:"
  assert_output --partial "(Dry run - no changes made)"

  # The fixture file must still be present and unchanged.
  assert_file_exists "${fixture}/readme.md"
}

@test "dry run writes a log file into the configured log dir" {
  local fixture log
  fixture="$(make_fixture_dir)"
  log="${TEST_SANDBOX}/explicit.log"

  run "$RESET_SCRIPT" --dry-run --no-confirm --skip-sampling --no-parallel \
    --log-file "$log" -e md "$fixture"
  assert_success
  assert_file_exists "$log"
}

# ---------------------------------------------------------------------------
# Argument handling
# ---------------------------------------------------------------------------

@test "--path takes precedence over the positional directory" {
  local fixture
  fixture="$(make_fixture_dir)"

  run "$RESET_SCRIPT" --dry-run --no-confirm --skip-sampling --no-parallel \
    --path "$fixture" --log-file "${TEST_SANDBOX}/path.log" \
    -e txt /definitely/not/a/real/path
  assert_success
  assert_output --partial "$fixture"
  assert_output --partial "Total files scanned:"
}

@test "--ext limits processing to the requested extension" {
  # Fixture has exactly one .md file plus one .txt, .js, and .json. Filtering to
  # md must scan only that single file, so the scanned count proves the filter
  # applied (the section header is ANSI-colored, so match the plain count line).
  local fixture
  fixture="$(make_fixture_dir)"

  run "$RESET_SCRIPT" --dry-run --no-confirm --skip-sampling --no-parallel \
    --log-file "${TEST_SANDBOX}/ext.log" -e md "$fixture"
  assert_success
  assert_output --partial "Total files scanned: 1"
}

@test "nonexistent target directory fails with a clear error" {
  run "$RESET_SCRIPT" --dry-run --no-confirm /definitely/not/a/real/path
  assert_failure
  assert_output --partial "Directory not found"
}

@test "unknown option is rejected" {
  run "$RESET_SCRIPT" --not-a-real-flag
  assert_failure
  assert_output --partial "Unknown option"
}

# ---------------------------------------------------------------------------
# Live reset (macOS only)
# ---------------------------------------------------------------------------

@test "live reset clears the LaunchServices xattr from a fixture file" {
  require_macos_xattr

  local fixture file
  fixture="${TEST_SANDBOX}/xattr-fixture"
  mkdir -p "$fixture"
  file="${fixture}/sample.md"
  printf '%s\n' "# sample" > "$file"

  if ! xattr -w com.apple.LaunchServices.OpenWith test "$file" 2> /dev/null; then
    skip "could not write LaunchServices test xattr"
  fi

  run "$RESET_SCRIPT" --no-confirm --skip-sampling --no-parallel \
    --log-file "${TEST_SANDBOX}/live.log" -e md "$fixture"
  assert_success
  assert_output --partial "Files reset to system default:"

  # The attribute must be gone after a live reset.
  run xattr "$file"
  assert_success
  refute_output --partial "com.apple.LaunchServices.OpenWith"
}
