# macOS file association management

CYAN := '\033[0;36m'
GREEN := '\033[0;32m'
YELLOW := '\033[1;33m'
RED := '\033[0;31m'
NC := '\033[0m'

# Show available commands
default:
    @just --list

# Install required Homebrew dependencies
install-deps:
    #!/usr/bin/env bash
    set -euo pipefail
    printf '%b\n' "{{CYAN}}Installing file-assoc dependencies...{{NC}}"
    if ! command -v brew > /dev/null 2>&1; then
      printf '%b\n' "{{RED}}Homebrew is not installed. Install it from https://brew.sh first.{{NC}}" >&2
      exit 1
    fi
    brew bundle install --file=Brewfile
    printf '%b\n' "{{GREEN}}Dependencies installed.{{NC}}"

# Install the BATS test stack: the runner via Homebrew, helper libs via submodules
install-bats:
    #!/usr/bin/env bash
    set -euo pipefail
    if ! command -v brew > /dev/null 2>&1; then
      printf '%s\n' "Homebrew is required to install the bats runner. See https://brew.sh" >&2
      exit 1
    fi
    # Runner from the vetted homebrew/core tap (no third-party tap needed).
    brew install bats-core
    # Helper libraries are vendored as version-pinned git submodules.
    git submodule update --init test/helpers/lib

# Check required commands
check-deps:
    #!/usr/bin/env bash
    set -euo pipefail
    printf '%b\n' "{{CYAN}}Checking dependencies...{{NC}}"
    missing=0
    for tool in bash bats bc duti just perl shellcheck shfmt xattr; do
      if command -v "$tool" > /dev/null 2>&1; then
        printf '%b\n' "{{GREEN}}✓{{NC}} $tool"
      else
        printf '%b\n' "{{RED}}✗{{NC}} $tool"
        missing=1
      fi
    done
    if [[ $missing -ne 0 ]]; then
      printf '\n%b\n' "{{YELLOW}}Install missing dependencies with: just install-deps{{NC}}"
      exit 1
    fi
    printf '%b\n' "{{GREEN}}All required commands are available.{{NC}}"

# Format shell scripts (.bats files use bats syntax and are excluded)
format:
    #!/usr/bin/env bash
    set -euo pipefail
    shfmt -w -i 2 -bn -ci -sr bin/* scripts/*.sh

# Check shell script formatting
format-check:
    #!/usr/bin/env bash
    set -euo pipefail
    shfmt -d -i 2 -bn -ci -sr bin/* scripts/*.sh

# Run ShellCheck (.bats files use bats syntax and are excluded)
lint:
    #!/usr/bin/env bash
    set -euo pipefail
    shellcheck bin/* scripts/*.sh

# Supply-chain guard: the Brewfile must use only the vetted homebrew/core tap.
# Any `tap` directive pulls from a third-party repo and is rejected.
check-brewfile:
    #!/usr/bin/env bash
    set -euo pipefail
    if grep -qE '^[[:space:]]*tap([[:space:]]|\()' Brewfile; then
      printf '%s\n' "ERROR: Brewfile declares a third-party tap. Vendor the dependency as a pinned submodule instead." >&2
      grep -nE '^[[:space:]]*tap([[:space:]]|\()' Brewfile >&2
      exit 1
    fi
    printf '%s\n' "Brewfile uses only homebrew/core (no third-party taps)."

# Run static checks
quality: format-check lint check-brewfile

# Alias for quality
q: quality

# Apply system-wide file associations with duti
setup-file-associations:
    #!/usr/bin/env bash
    set -euo pipefail
    config="config/macos-file-associations.duti"
    if ! command -v duti > /dev/null 2>&1; then
      printf '%s\n' "duti is not installed. Run: just install-deps" >&2
      exit 1
    fi
    if [[ ! -f "$config" ]]; then
      printf '%s\n' "Missing $config" >&2
      exit 1
    fi

    # Apply each mapping individually so we can summarize the result. duti emits
    # 'error -50' for extensions that resolve only to a dynamic UTI, which macOS
    # refuses to set a default handler for. Those are expected and non-fatal, so
    # we count them as skipped and only surface genuinely unexpected errors.
    applied=0
    skipped=0
    unexpected=0
    skipped_list=()
    err_file="$(mktemp)"
    trap 'rm -f "$err_file"' EXIT

    while read -r bundle token role; do
      [[ -z "${bundle:-}" || "$bundle" == \#* ]] && continue
      [[ -z "${token:-}" || -z "${role:-}" ]] && continue

      if duti -s "$bundle" "$token" "$role" 2> "$err_file"; then
        applied=$((applied + 1))
      elif grep -q 'error -50' "$err_file"; then
        skipped=$((skipped + 1))
        skipped_list+=("$token")
      else
        unexpected=$((unexpected + 1))
        sed 's/^/  duti: /' "$err_file" >&2
      fi
    done < "$config"

    printf '\n%b\n' "{{GREEN}}Applied: ${applied}{{NC}}"
    printf '%b\n' "{{YELLOW}}Skipped (dynamic UTI, not settable via duti on macOS): ${skipped}{{NC}}"
    if [[ $skipped -gt 0 ]]; then
      printf '  %s\n' "${skipped_list[*]}"
      printf '  %s\n' "To set these, use Finder: right-click a file -> Open With -> Other -> Visual Studio Code -> Always Open With."
    fi
    if [[ $unexpected -gt 0 ]]; then
      printf '%b\n' "{{RED}}Unexpected errors: ${unexpected} (see duti output above){{NC}}" >&2
      exit 1
    fi

# Reset per-file overrides in DIR
reset-file-associations DIR="." *ARGS="":
    #!/usr/bin/env bash
    set -euo pipefail
    ./scripts/reset-file-associations.sh {{ARGS}} "{{DIR}}"

# Preview reset behavior without modifying files
reset-file-associations-preview DIR=".":
    #!/usr/bin/env bash
    set -euo pipefail
    ./scripts/reset-file-associations.sh --dry-run --verbose --no-confirm "{{DIR}}"

# Run the BATS integration suite for the shipped entrypoints
test-integration:
    #!/usr/bin/env bash
    set -euo pipefail
    if ! command -v bats > /dev/null 2>&1; then
      printf '%s\n' "bats is not installed. Run: just install-bats" >&2
      exit 1
    fi
    bats --recursive test/integration

# Run the default test suite
test: test-integration

# Run all checks and tests
test-all: quality test-integration
