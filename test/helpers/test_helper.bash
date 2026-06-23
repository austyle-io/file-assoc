#!/usr/bin/env bash
# Shared BATS setup/teardown and helpers for file-assoc tests.
#
# Loads the bats-support / bats-assert / bats-file helper libraries from the
# usual Homebrew/Linux/CI locations, derives PROJECT_ROOT from this file, and
# provides an isolated sandbox via _common_setup / _common_teardown.

# ---------------------------------------------------------------------------
# Load bats helper libraries
# ---------------------------------------------------------------------------

# Prefer the vendored, version-pinned helper libraries (git submodules under
# test/helpers/lib/). This removes the third-party Homebrew tap from the trust
# chain; the system locations below remain as a fallback when the submodules
# have not been initialized.
_HELPER_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib"
if [[ -f "${_HELPER_LIB_DIR}/bats-support/load.bash" ]]; then
  BATS_LIB_PREFIX="${_HELPER_LIB_DIR}"
elif [[ -n "${BATS_LIB_PATH:-}" ]] && [[ -d "${BATS_LIB_PATH}" ]]; then
  BATS_LIB_PREFIX="${BATS_LIB_PATH}"
elif [[ -d "/opt/homebrew/lib" ]]; then
  BATS_LIB_PREFIX="/opt/homebrew/lib"
elif [[ -d "/usr/local/lib" ]]; then
  BATS_LIB_PREFIX="/usr/local/lib"
elif [[ -d "${HOME}/.local/share/bats/lib" ]]; then
  BATS_LIB_PREFIX="${HOME}/.local/share/bats/lib"
elif [[ -d "${HOME}/.local/lib" ]]; then
  BATS_LIB_PREFIX="${HOME}/.local/lib"
else
  for dir in "/usr/lib" "${HOME}/.bats/lib" "${TMPDIR:-/tmp}/bats"; do
    if [[ -d "$dir/bats-support" ]]; then
      BATS_LIB_PREFIX="$dir"
      break
    fi
  done
fi

if [[ -n "${BATS_LIB_PREFIX:-}" ]]; then
  missing_libs=()
  for lib in bats-support bats-assert bats-file; do
    loaded=false
    if [[ -f "${BATS_LIB_PREFIX}/${lib}/load.bash" ]]; then
      # shellcheck source=/dev/null
      load "${BATS_LIB_PREFIX}/${lib}/load.bash"
      loaded=true
    elif [[ -f "${BATS_LIB_PREFIX}/${lib}/src/load.bash" ]]; then
      # shellcheck source=/dev/null
      load "${BATS_LIB_PREFIX}/${lib}/src/load.bash"
      loaded=true
    elif [[ -f "${BATS_LIB_PREFIX}/${lib}.bash" ]]; then
      # shellcheck source=/dev/null
      load "${BATS_LIB_PREFIX}/${lib}.bash"
      loaded=true
    fi
    [[ "$loaded" != "true" ]] && missing_libs+=("$lib")
  done

  if [[ ${#missing_libs[@]} -gt 0 ]]; then
    echo "ERROR: Missing BATS helper libraries: ${missing_libs[*]}" >&2
    echo "Initialize the vendored helpers with: git submodule update --init (or: just install-bats)" >&2
    exit 1
  fi
else
  echo "ERROR: BATS helper libraries not found." >&2
  echo "Install with: just install-bats" >&2
  exit 1
fi

# ---------------------------------------------------------------------------
# Project paths
# ---------------------------------------------------------------------------

# Derived from BASH_SOURCE so tests always exercise the checkout that contains
# this helper (test/helpers/test_helper.bash -> repo root is ../../).
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
export PROJECT_ROOT

export SETUP_BIN="${PROJECT_ROOT}/bin/file-assoc-setup"
export RESET_BIN="${PROJECT_ROOT}/bin/file-assoc-reset"
export RESET_SCRIPT="${PROJECT_ROOT}/scripts/reset-file-associations.sh"
export DUTI_CONFIG="${PROJECT_ROOT}/config/macos-file-associations.duti"

# ---------------------------------------------------------------------------
# Setup / teardown
# ---------------------------------------------------------------------------

# _common_setup creates an isolated sandbox directory and redirects script logs
# into it so tests never touch the user's real ~/.file-assoc/logs.
_common_setup() {
  TEST_SANDBOX="$(mktemp -d "${TMPDIR:-/tmp}/file-assoc-test.XXXXXXXX")" || {
    echo "ERROR: failed to create test sandbox" >&2
    return 1
  }
  # Normalize (collapse any double slashes from TMPDIR) so comparisons match the
  # reset script's own `cd "$dir" && pwd` normalization of the target directory.
  TEST_SANDBOX="$(cd "$TEST_SANDBOX" && pwd)"
  export TEST_SANDBOX

  # Keep reset-script logs inside the sandbox.
  export FILE_ASSOC_LOG_DIR="${TEST_SANDBOX}/logs"
}

# _common_teardown removes the sandbox created in _common_setup.
_common_teardown() {
  if [[ -n "${TEST_SANDBOX:-}" ]] && [[ -d "${TEST_SANDBOX}" ]]; then
    rm -rf "${TEST_SANDBOX}"
  fi
  unset TEST_SANDBOX FILE_ASSOC_LOG_DIR
}

# ---------------------------------------------------------------------------
# Test helpers
# ---------------------------------------------------------------------------

# make_fixture_dir creates a directory of sample source files under the sandbox
# and prints its absolute path.
make_fixture_dir() {
  local dir="${TEST_SANDBOX}/fixture"
  mkdir -p "$dir/subdir"
  printf '%s\n' "# test" > "$dir/readme.md"
  printf '%s\n' "hello" > "$dir/subdir/notes.txt"
  printf '%s\n' "console.log('ok')" > "$dir/app.js"
  printf '%s\n' "{}" > "$dir/config.json"
  printf '%s\n' "$dir"
}

# require_macos_xattr skips the current test unless running on macOS with a
# working `xattr` that can write the LaunchServices attribute.
require_macos_xattr() {
  [[ "$(uname -s)" == "Darwin" ]] || skip "requires macOS"
  command -v xattr > /dev/null 2>&1 || skip "requires xattr"
}

export -f _common_setup _common_teardown make_fixture_dir require_macos_xattr
