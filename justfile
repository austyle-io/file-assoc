# macOS File Association Management
# Standalone justfile for file-assoc tools

# Color codes for output
CYAN := '\033[0;36m'
GREEN := '\033[0;32m'
YELLOW := '\033[1;33m'
RED := '\033[0;31m'
NC := '\033[0m'  # No Color

# Show available commands
default:
    @just --list

# ============================================================================
# DEPENDENCY MANAGEMENT
# ============================================================================

# Install all dependencies via Homebrew
install-deps:
    #!/usr/bin/env bash
    set -euo pipefail
    echo -e "{{CYAN}}📦 Installing dependencies...{{NC}}"
    if ! command -v brew &>/dev/null; then
        echo -e "{{RED}}❌ Homebrew not installed. Install from https://brew.sh{{NC}}"
        exit 1
    fi
    brew bundle install
    echo -e "{{GREEN}}✅ Dependencies installed{{NC}}"

# Check if all required tools are installed
check-deps:
    #!/usr/bin/env bash
    set -euo pipefail
    echo -e "{{CYAN}}🔍 Checking dependencies...{{NC}}"
    MISSING=0
    for tool in duti just shellcheck shfmt; do
        if command -v "$tool" &>/dev/null; then
            echo -e "{{GREEN}}✓{{NC}} $tool"
        else
            echo -e "{{RED}}✗{{NC}} $tool (missing)"
            MISSING=1
        fi
    done
    if [ $MISSING -eq 1 ]; then
        echo ""
        echo -e "{{YELLOW}}Install missing dependencies with: just install-deps{{NC}}"
        exit 1
    fi
    echo -e "{{GREEN}}✅ All dependencies installed{{NC}}"

# Update Brewfile from currently installed tools
brewfile-update:
    @echo -e "{{CYAN}}📦 Updating Brewfile...{{NC}}"
    @brew bundle dump --force
    @echo -e "{{GREEN}}✅ Brewfile updated{{NC}}"

# ============================================================================
# LINTING & FORMATTING
# ============================================================================

# Run shellcheck on all shell scripts
lint:
    #!/usr/bin/env bash
    set -euo pipefail
    echo -e "{{CYAN}}🔍 Running shellcheck...{{NC}}"
    if ! command -v shellcheck &>/dev/null; then
        echo -e "{{RED}}❌ shellcheck not installed. Run: just install-deps{{NC}}"
        exit 1
    fi

    ERRORS=0
    for script in scripts/*.sh bin/*; do
        if [ -f "$script" ] && head -1 "$script" | grep -q "^#!.*sh"; then
            echo -e "{{CYAN}}Checking: $script{{NC}}"
            if shellcheck "$script"; then
                echo -e "{{GREEN}}✓ $script{{NC}}"
            else
                ERRORS=1
            fi
        fi
    done

    if [ $ERRORS -eq 1 ]; then
        echo -e "{{RED}}❌ Shellcheck found issues{{NC}}"
        exit 1
    fi
    echo -e "{{GREEN}}✅ All scripts passed shellcheck{{NC}}"

# Format all shell scripts with shfmt
format:
    #!/usr/bin/env bash
    set -euo pipefail
    echo -e "{{CYAN}}🎨 Formatting shell scripts...{{NC}}"
    if ! command -v shfmt &>/dev/null; then
        echo -e "{{RED}}❌ shfmt not installed. Run: just install-deps{{NC}}"
        exit 1
    fi

    # Format with: 2-space indent, binary ops on next line, case indent, space redirects
    shfmt -w -i 2 -bn -ci -sr scripts/*.sh bin/*
    echo -e "{{GREEN}}✅ Scripts formatted{{NC}}"

# Check formatting without modifying files
format-check:
    #!/usr/bin/env bash
    set -euo pipefail
    echo -e "{{CYAN}}🔍 Checking shell script formatting...{{NC}}"
    if ! command -v shfmt &>/dev/null; then
        echo -e "{{RED}}❌ shfmt not installed. Run: just install-deps{{NC}}"
        exit 1
    fi

    if shfmt -d -i 2 -bn -ci -sr scripts/*.sh bin/*; then
        echo -e "{{GREEN}}✅ All scripts properly formatted{{NC}}"
    else
        echo -e "{{RED}}❌ Some scripts need formatting. Run: just format{{NC}}"
        exit 1
    fi

# Run all quality checks (lint + format-check)
quality:
    @echo -e "{{CYAN}}🎯 Running quality checks...{{NC}}"
    @just lint
    @just format-check
    @echo -e "{{GREEN}}✅ All quality checks passed{{NC}}"

# Alias: short form for quality
q: quality

# ============================================================================
# FILE ASSOCIATION MANAGEMENT
# ============================================================================

# Apply system-wide file associations
setup-file-associations:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "🔗 Setting up macOS file associations..."

    # Check if duti is installed
    if ! command -v duti &>/dev/null; then
        echo "❌ duti is not installed. Please install it first:"
        echo "   brew install duti"
        exit 1
    fi

    # Check if config file exists
    if [ ! -f "config/macos-file-associations.duti" ]; then
        echo "❌ Configuration file not found: config/macos-file-associations.duti"
        exit 1
    fi

    # Apply file associations
    echo "📝 Applying file associations from config/macos-file-associations.duti..."
    duti config/macos-file-associations.duti

    echo "✅ File associations applied successfully!"
    echo ""
    echo "Note: Changes take effect immediately for new files."
    echo "To reset existing files: just reset-file-associations"

# Reset file associations for existing files
reset-file-associations DIR="." *ARGS="":
    #!/usr/bin/env bash
    set -euo pipefail
    ./scripts/reset-file-associations.sh {{ARGS}} "{{DIR}}"

# Reset file associations (dry run preview)
reset-file-associations-preview DIR=".":
    #!/usr/bin/env bash
    set -euo pipefail
    ./scripts/reset-file-associations.sh --dry-run --verbose "{{DIR}}"

# Quick test with current directory
test:
    @echo "🧪 Testing file association reset (dry run)..."
    @just reset-file-associations-preview .

# Run unit tests for library modules
test-unit:
    #!/usr/bin/env bash
    set -euo pipefail
    echo -e "{{CYAN}}🧪 Running unit tests...{{NC}}"
    echo ""

    TEST_FAILURES=0

    # Run core library tests
    if [ -f tests/test-core.sh ]; then
        echo -e "{{CYAN}}Testing lib/core.sh...{{NC}}"
        if bash -c 'source lib/core.sh && source tests/test-core.sh && main' 2>&1 | grep -v "readonly variable"; then
            echo ""
        else
            TEST_FAILURES=$((TEST_FAILURES + 1))
        fi
    fi

    # Run UI library tests
    if [ -f tests/test-ui.sh ]; then
        echo -e "{{CYAN}}Testing lib/ui.sh...{{NC}}"
        if bash tests/test-ui.sh 2>&1 | grep -v "readonly variable"; then
            echo ""
        else
            TEST_FAILURES=$((TEST_FAILURES + 1))
        fi
    fi

    # Run logging library tests
    if [ -f tests/test-logging.sh ]; then
        echo -e "{{CYAN}}Testing lib/logging.sh...{{NC}}"
        if bash tests/test-logging.sh 2>&1 | grep -v "readonly variable"; then
            echo ""
        else
            TEST_FAILURES=$((TEST_FAILURES + 1))
        fi
    fi

    # Run files library tests
    if [ -f tests/test-files.sh ]; then
        echo -e "{{CYAN}}Testing lib/files.sh...{{NC}}"
        if bash tests/test-files.sh 2>&1 | grep -v "readonly variable"; then
            echo ""
        else
            TEST_FAILURES=$((TEST_FAILURES + 1))
        fi
    fi

    # Run xattr library tests
    if [ -f tests/test-xattr.sh ]; then
        echo -e "{{CYAN}}Testing lib/xattr.sh...{{NC}}"
        if bash tests/test-xattr.sh 2>&1 | grep -v "readonly variable"; then
            echo ""
        else
            TEST_FAILURES=$((TEST_FAILURES + 1))
        fi
    fi

    # Run metrics library tests
    if [ -f tests/test-metrics.sh ]; then
        echo -e "{{CYAN}}Testing lib/metrics.sh...{{NC}}"
        if bash tests/test-metrics.sh 2>&1 | grep -v "readonly variable"; then
            echo ""
        else
            TEST_FAILURES=$((TEST_FAILURES + 1))
        fi
    fi

    # Summary
    if [ $TEST_FAILURES -eq 0 ]; then
        echo -e "{{GREEN}}✅ All unit tests completed successfully{{NC}}"
    else
        echo -e "{{RED}}❌ $TEST_FAILURES test suite(s) failed{{NC}}"
        exit 1
    fi

# ============================================================================
# PROJECT MANAGEMENT
# ============================================================================

# Setup GitHub project and issues for refactoring
setup-github-project:
    #!/usr/bin/env bash
    set -euo pipefail
    echo -e "{{CYAN}}🚀 Setting up GitHub project for refactoring...{{NC}}"

    if ! command -v gh &>/dev/null; then
        echo -e "{{RED}}❌ gh CLI not installed. Install with: brew install gh{{NC}}"
        exit 1
    fi

    if ! gh auth status &>/dev/null; then
        echo -e "{{RED}}❌ Not authenticated. Run: gh auth login{{NC}}"
        exit 1
    fi

    ./scripts/setup-github-project.sh
    echo -e "{{GREEN}}✅ GitHub project setup complete!{{NC}}"
    echo -e "{{CYAN}}View project: gh project list --owner austyle-io{{NC}}"
    echo -e "{{CYAN}}View issues: gh issue list --label refactoring{{NC}}"
