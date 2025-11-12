# file-assoc Dependencies (macOS)
# Install with: brew bundle install
# Update with: brew bundle dump --force
#
# Platform Note:
#   - This Brewfile is optimized for macOS development
#   - For Linux development containers, use: Brewfile.linux
#   - Some packages (like duti) are macOS-specific
#
# See also: Brewfile.linux for Linux-specific packages

# ============================================================================
# macOS-SPECIFIC TOOLS
# ============================================================================

# Core Requirement: duti for managing file associations (macOS only)
brew "duti"

# Task Runner
brew "just"

# ============================================================================
# Modern Shell Scripting Tools (Phase 1: Foundation)
# ============================================================================

# Terminal UI Components
brew "gum"          # Modern terminal UI toolkit by Charm

# Parallel Processing
brew "parallel"     # GNU Parallel for robust parallelization

# Argument Parsing
brew "argbash"      # Bash argument parser generator

# Data Processing
brew "jq"           # JSON processor and query language
brew "yq"           # YAML/JSON/XML/TOML processor (mikefarah/yq)

# Optional: Progress & Visual Enhancements
brew "pv"           # Pipe Viewer for monitoring data through pipelines
brew "figlet"       # ASCII art text generator
brew "lolcat"       # Rainbow colorizer for output

# Shell Linting & Formatting
brew "shellcheck"  # Shell script linter
brew "shfmt"       # Shell script formatter

# Development Tools
brew "git"
brew "gh"  # GitHub CLI (for repo management)

# Optional: Testing Framework (for future test suite)
tap "bats-core/bats-core"
brew "bats-core"
brew "bats-support"
brew "bats-assert"
brew "bats-file"

# Optional: Pre-commit Framework (for git hooks)
brew "pre-commit"

# Optional: Coverage Tool (for future test coverage)
brew "kcov"
