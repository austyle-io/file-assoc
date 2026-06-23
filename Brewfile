# file-assoc dependencies for macOS
# Install with: brew bundle install --file=Brewfile
#
# All formulae come from the vetted homebrew/core tap (no third-party taps).
# The BATS helper libraries (bats-support/assert/file) are NOT installed here:
# they are vendored as version-pinned git submodules under test/helpers/lib/,
# so initialize them with `git submodule update --init` (or `just install-bats`).

brew "bash"       # Modern Bash for scripts that use arrays and strict mode
brew "bc"         # Performance report arithmetic
brew "coreutils"  # Optional gdate/gshuf support on macOS
brew "duti"       # Apply Launch Services file associations
brew "just"       # Task runner
brew "shellcheck" # Shell script linting
brew "shfmt"      # Shell script formatting

# Testing: BATS runner only (homebrew/core). The helper libraries are vendored
# as pinned submodules — see test/helpers/lib/.
brew "bats-core"  # Bash Automated Testing System
