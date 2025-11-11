# macOS File Association Management
# Standalone justfile for file-assoc tools

# Show available commands
default:
    @just --list

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
