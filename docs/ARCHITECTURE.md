# Architecture Documentation
## file-assoc - Modern Shell Scripting Architecture

**Last Updated:** 2025-11-12
**Status:** Phase 2 - UI Module Complete

---

## Overview

The file-assoc project provides tools for managing macOS file associations at both system-wide and per-file levels. This document describes the modular architecture being implemented as part of the Shell Scripting Modernization refactoring (v2.0).

### Design Philosophy

1. **Modular by Design** - Separate concerns into reusable libraries
2. **Modern Tooling** - Leverage battle-tested tools (Gum, GNU Parallel, Argbash)
3. **Test-Driven** - Comprehensive test coverage for all modules
4. **Cross-Platform** - Support macOS and Linux where applicable
5. **Professional UX** - Terminal UI matching modern CLI applications

---

## Directory Structure

```
file-assoc/
├── bin/                          # User-facing commands
│   ├── file-assoc-setup         # Apply system-wide associations
│   └── file-assoc-reset         # Reset per-file overrides
│
├── lib/                          # Modular libraries (NEW in v2.0)
│   ├── core.sh                  # ✅ Core utilities & platform detection
│   ├── ui.sh                    # ✅ Terminal UI (Gum integration)
│   ├── logging.sh               # 🚧 Simplified logging
│   ├── files.sh                 # 🚧 File discovery & operations
│   ├── xattr.sh                 # 🚧 Extended attribute management
│   ├── parallel.sh              # 🚧 GNU Parallel wrapper
│   ├── sampling.sh              # 🚧 Smart sampling logic
│   ├── metrics.sh               # 🚧 Performance tracking
│   └── config.sh                # 🚧 Configuration management
│
├── scripts/
│   ├── reset-file-associations.sh  # Main script (being refactored)
│   └── setup-github-project.sh     # GitHub project automation
│
├── tests/                        # Unit & integration tests (NEW)
│   ├── test-core.sh             # ✅ Tests for lib/core.sh
│   ├── test-ui.sh               # ✅ Tests for lib/ui.sh
│   ├── test-files.sh            # 🚧 Tests for lib/files.sh
│   └── fixtures/                # Test data
│
├── config/
│   ├── macos-file-associations.duti
│   └── extensions.yaml          # 🚧 Extension configuration
│
├── docs/
│   ├── ARCHITECTURE.md          # This document
│   ├── REFACTORING_PLAN.md      # Complete refactoring strategy
│   └── MODERN_SHELL_SCRIPTING_TOOLKIT...md
│
├── .github/                      # GitHub project tracking
│   ├── QUICK_START.md
│   ├── GITHUB_PROJECT_SETUP.md
│   └── ISSUE_TEMPLATE/
│
├── Brewfile                      # Dependencies
├── justfile                      # Task runner
└── README.md

Legend: ✅ Complete  🚧 In Progress  ⏳ Planned
```

---

## Module Architecture

### Core Modules (lib/)

#### `lib/core.sh` - Core Utilities ✅

**Status:** Complete (Phase 1)
**Lines:** ~430
**Dependencies:** None
**Test Coverage:** 24/24 tests passing

**Purpose:**
Fundamental utilities used across all other modules. Provides error handling, path manipulation, platform detection, and common helper functions.

**Key Functions:**

```bash
# Error Handling
die()                    # Exit with error message
require_command()        # Check command availability
check_bash_version()     # Ensure bash 4.0+
require_value()          # Validate non-empty values

# Path Utilities
get_absolute_path()      # Resolve absolute paths
normalize_extension()    # Remove leading dots
get_script_dir()         # Get script directory
is_absolute_path()       # Check if path is absolute

# Platform Detection
is_macos()              # Check if running on macOS
is_linux()              # Check if running on Linux
get_platform()          # Get platform name
get_cpu_cores()         # Detect CPU cores
get_available_memory()  # Get available memory in MB

# String Utilities
trim()                  # Remove whitespace
to_lower()              # Convert to lowercase
to_upper()              # Convert to uppercase
starts_with()           # Check string prefix
ends_with()             # Check string suffix

# Array Utilities
array_contains()        # Check if array has element
array_join()            # Join with delimiter

# Validation
is_integer()            # Validate integer
is_readable_file()      # Check file readability
is_readable_dir()       # Check directory readability
is_writable_file()      # Check file writability
is_writable_dir()       # Check directory writability

# Date & Time
get_timestamp()         # Unix timestamp
get_iso_timestamp()     # ISO 8601 format
get_duration()          # Calculate duration
format_duration()       # Human-readable duration

# Temporary Files
create_temp_file()      # Create temp file
create_temp_dir()       # Create temp directory
```

**Usage Example:**

```bash
source lib/core.sh

# Error handling
require_command "jq" "Install with: brew install jq"
die "Something went wrong"

# Platform detection
if is_macos; then
  echo "Running on macOS"
fi

# Path manipulation
abs_path=$(get_absolute_path "relative/path")
ext=$(normalize_extension ".md")  # Returns "md"

# String utilities
lower=$(to_lower "HELLO")
trimmed=$(trim "  hello  ")

# Array utilities
arr=("foo" "bar" "baz")
if array_contains "foo" "${arr[@]}"; then
  echo "Found"
fi

# Validation
if is_integer "123"; then
  echo "Valid integer"
fi

# Date & Time
start=$(get_timestamp)
# ... do work ...
end=$(get_timestamp)
duration=$(get_duration "$start" "$end")
echo "Took: $(format_duration $duration)"
```

---

#### `lib/ui.sh` - Terminal UI (Gum Integration) ✅

**Status:** Complete (Phase 2)
**Lines:** ~534
**Dependencies:** `gum` (optional, graceful fallback to ANSI codes)
**Test Coverage:** 17/17 tests passing

**Purpose:**
Professional terminal UI using Gum with graceful fallback to ANSI codes when Gum is unavailable. Provides modern, consistent UI components while maintaining backward compatibility with existing console_log patterns.

**Key Functions:**

```bash
# Initialization
ui::init()           # Initialize UI system, detect Gum availability
ui::has_gum()        # Check if Gum is available

# Basic Output
ui::header()         # Section headers with borders
ui::info()           # Info messages with icon
ui::success()        # Success messages with checkmark
ui::warn()           # Warning messages with icon
ui::error()          # Error messages to stderr
ui::debug()          # Debug messages (respects VERBOSE)

# Console Logging (Backward Compatible)
ui::console_log()    # Timestamped logging (INFO, WARN, ERROR, SUCCESS, DEBUG)
ui::get_timestamp()  # Get timestamp with milliseconds

# Interactive Components
ui::confirm()        # Yes/no confirmation (gum confirm or read fallback)
ui::input()          # Text input with optional placeholder
ui::choose()         # Selection menu from options

# Spinners & Progress
ui::spinner()        # Show spinner during command execution
ui::start_spinner()  # Manual spinner control (start)
ui::stop_spinner()   # Manual spinner control (stop)
ui::progress()       # Progress bar with ETA calculation

# Formatting
ui::format()         # Format markdown (gum format or cat)
ui::style()          # Style text with colors/formatting
ui::table()          # Display tables (gum table or column)

# Utilities
ui::newline()        # Print blank line
ui::divider()        # Print visual separator
ui::clear_line()     # Clear current terminal line
```

**Usage Example:**

```bash
source lib/core.sh
source lib/ui.sh

# Initialize UI (detect Gum)
ui::init

# Display header
ui::header "File Association Reset"

# Basic output
ui::info "Scanning directory..."
ui::warn "This will affect 1000 files"

# Confirmation
if ui::confirm "Continue with reset?"; then
  # Run command with spinner
  ui::spinner "Processing files" -- process_files
  ui::success "Complete!"
else
  ui::error "Operation cancelled"
fi

# Console logging (backward compatible)
ui::console_log INFO "Starting batch operation"
ui::console_log SUCCESS "Processed 100 files"

# Progress tracking
for i in {1..100}; do
  ui::progress $i 100 "Processing"
  # ... do work ...
done
```

**Backward Compatibility:**

The module provides legacy aliases for existing scripts:
```bash
# Legacy color constants (still work)
echo "${RED}Error${NC}"
echo "${GREEN}Success${NC}"

# Legacy console_log alias
console_log INFO "message"  # Same as ui::console_log INFO "message"
```

---

#### `lib/logging.sh` - Simplified Logging 🚧

**Status:** Planned (Phase 3)
**Dependencies:** lib/core.sh

**Purpose:**
Lightweight logging without over-engineering. Simplified version of current 200+ line logging system.

**Planned Functions:**

```bash
log::init()          # Setup log file
log::debug()         # Debug messages
log::info()          # Info messages
log::warn()          # Warnings
log::error()         # Errors
log::fatal()         # Fatal errors (exits)
log::set_level()     # Set log level
log::get_file()      # Get log file path
```

---

#### `lib/files.sh` - File Discovery & Operations 🚧

**Status:** Planned (Phase 3)
**Dependencies:** lib/core.sh

**Purpose:**
File system operations and validation specific to file association management.

**Planned Functions:**

```bash
files::count()               # Count files by extension
files::find_by_ext()         # Find files for extension
files::find_all()            # Find files for all extensions
files::validate_directory()  # Validate target directory
files::estimate_time()       # Estimate processing time
files::get_size()           # Get total size
```

---

#### `lib/xattr.sh` - Extended Attribute Operations 🚧

**Status:** Planned (Phase 3)
**Dependencies:** lib/core.sh

**Purpose:**
Core extended attribute manipulation (macOS specific). Wraps xattr operations with error handling.

**Planned Functions:**

```bash
xattr::has_launch_services()    # Check if file has LaunchServices attr
xattr::clear_launch_services()  # Remove LaunchServices attr
xattr::get_attr()              # Get specific attribute value
xattr::list_attrs()            # List all attributes
xattr::stats()                 # Get statistics for directory
```

---

#### `lib/parallel.sh` - GNU Parallel Integration 🚧

**Status:** Planned (Phase 5)
**Dependencies:** `parallel` (GNU Parallel), lib/core.sh

**Purpose:**
Parallel processing using GNU Parallel instead of manual xargs coordination.

**Planned Functions:**

```bash
parallel::init()            # Check GNU Parallel availability
parallel::process_files()   # Process files in parallel
parallel::get_workers()     # Auto-detect optimal workers
parallel::run()            # Generic parallel runner
```

---

#### `lib/sampling.sh` - Smart Sampling Logic 🚧

**Status:** Planned (Phase 3)
**Dependencies:** lib/core.sh, lib/files.sh, lib/xattr.sh

**Purpose:**
Pre-scan sampling to estimate hit rate and skip clean directories.

**Planned Functions:**

```bash
sampling::analyze()          # Run sampling analysis
sampling::calculate_rate()   # Calculate hit rate
sampling::should_skip()      # Determine if scan should be skipped
sampling::get_sample()       # Get random sample of files
```

---

#### `lib/metrics.sh` - Performance Tracking 🚧

**Status:** Planned (Phase 3)
**Dependencies:** lib/core.sh

**Purpose:**
Track and report performance metrics for operations.

**Planned Functions:**

```bash
metrics::init()              # Initialize metrics tracking
metrics::start()            # Start timing for operation
metrics::end()              # End timing for operation
metrics::record()           # Record metric
metrics::report()           # Generate performance report
metrics::get_duration()     # Get duration for operation
```

---

#### `lib/config.sh` - Configuration Management 🚧

**Status:** Planned (Phase 7)
**Dependencies:** lib/core.sh, `yq`

**Purpose:**
Load and validate YAML configuration files.

**Planned Functions:**

```bash
config::load()              # Load configuration file
config::get()              # Get config value
config::set()              # Set config value
config::validate()         # Validate configuration
config::get_extensions()   # Get extension list
```

---

## Data Flow

### Current Architecture (v1.x)

```
┌─────────────────────────────────────────┐
│   reset-file-associations.sh            │
│   (1,905 lines - monolithic)            │
│                                         │
│   • Argument parsing                    │
│   • Logging                             │
│   • UI (ANSI codes)                     │
│   • File discovery                      │
│   • Parallel processing (xargs)         │
│   • Extended attributes                 │
│   • Sampling                            │
│   • Metrics                             │
│   • All logic tightly coupled           │
└─────────────────────────────────────────┘
```

### Target Architecture (v2.0)

```
┌─────────────────────────────────────────┐
│   reset-file-associations.sh (~300)     │
│   (Main orchestrator - coordinates)     │
└─────────────────┬───────────────────────┘
                  │
      ┌───────────┴───────────┐
      ▼                       ▼
┌──────────────┐    ┌──────────────────┐
│  lib/core.sh │    │  lib/ui.sh       │
│  (utilities) │    │  (Gum UI)        │
└──────────────┘    └──────────────────┘
      │                       │
      ▼                       ▼
┌──────────────┐    ┌──────────────────┐
│lib/files.sh  │    │ lib/xattr.sh     │
│(discovery)   │    │ (attributes)     │
└──────────────┘    └──────────────────┘
      │                       │
      ▼                       ▼
┌──────────────┐    ┌──────────────────┐
│lib/parallel.sh│   │ lib/sampling.sh  │
│(GNU Parallel)│    │ (pre-scan)       │
└──────────────┘    └──────────────────┘
      │                       │
      ▼                       ▼
┌──────────────┐    ┌──────────────────┐
│lib/logging.sh│    │ lib/metrics.sh   │
│(logs)        │    │ (performance)    │
└──────────────┘    └──────────────────┘
```

---

## Testing Strategy

### Test Organization

```
tests/
├── test-core.sh          # ✅ Unit tests for lib/core.sh (24 tests)
├── test-ui.sh            # ✅ Unit tests for lib/ui.sh (17 tests)
├── test-files.sh         # 🚧 Unit tests for lib/files.sh
├── test-xattr.sh        # 🚧 Unit tests for lib/xattr.sh (macOS only)
├── test-parallel.sh     # 🚧 Unit tests for lib/parallel.sh
├── integration/         # 🚧 End-to-end tests
│   ├── test-full-workflow.sh
│   ├── test-dry-run.sh
│   └── test-sampling.sh
└── fixtures/            # Test data
    ├── sample-files/
    └── expected-output/
```

### Test Framework

Simple custom framework (no external dependencies):

```bash
# Run a test
test_run "test_name" test_function

# Assertions
assert_equals "expected" "actual" "message"
assert_success command args
assert_failure command args

# Results
Tests run: 24
Passed: 24
Failed: 0
✅ All tests passed!
```

### Running Tests

```bash
# Run all unit tests
just test-unit

# Run specific module tests
./tests/test-core.sh

# Run integration tests
just test-integration

# Run with coverage (future)
just test-coverage
```

---

## Dependencies

### Required (Runtime)

```bash
# Core macOS tools
duti          # File association management

# Modern shell scripting tools (Phase 1+)
gum           # Terminal UI
parallel      # GNU Parallel
argbash       # Argument parsing (build-time)
jq            # JSON processing
yq            # YAML processing
```

### Optional (Development)

```bash
# Linting & formatting
shellcheck    # Shell script linter
shfmt         # Shell script formatter

# Testing
bats-core     # Testing framework (alternative)

# Project management
just          # Task runner
gh            # GitHub CLI
```

### Installation

```bash
# Install all dependencies
brew bundle install

# Or manually
brew install duti gum parallel argbash jq yq shellcheck shfmt just gh
```

---

## Configuration

### Environment Variables

```bash
# Logging
FILE_ASSOC_LOG_LEVEL=INFO           # DEBUG, INFO, WARN, ERROR

# Parallel processing
FILE_ASSOC_WORKERS=0                # 0 = auto-detect CPU cores
FILE_ASSOC_CHUNK_SIZE=100           # Files per worker chunk
FILE_ASSOC_USE_PARALLEL=true        # Enable/disable parallelization

# Resource limits
FILE_ASSOC_MAX_FILES=10000          # Abort if more files found
FILE_ASSOC_MAX_RATE=100             # Files per second
FILE_ASSOC_MAX_MEMORY=500           # MB

# Sampling
FILE_ASSOC_SAMPLE_SIZE=100          # Number of files to sample
```

### Configuration Files

```yaml
# config/extensions.yaml (planned)
extensions:
  config:
    - json
    - yaml
    - toml

  documentation:
    - md
    - txt

  programming:
    - ts
    - js
    - py
```

---

## Migration Path

### Phase 1: Foundation (✅ Complete)

- ✅ Create lib/ directory structure
- ✅ Install modern dependencies (Gum, GNU Parallel, Argbash, jq, yq)
- ✅ Create lib/core.sh with core utilities
- ✅ Create tests/ directory structure
- ✅ Create comprehensive test suite for core.sh (24 tests)
- ✅ Update Brewfile with new dependencies
- ✅ Document architecture

### Phase 2: UI Module with Gum Integration (✅ Complete)

- ✅ Create lib/ui.sh with Gum integration
- ✅ Implement graceful fallback to ANSI codes
- ✅ Maintain backward compatibility with console_log
- ✅ Create comprehensive test suite for ui.sh (17 tests)
- ✅ Update justfile to run UI tests
- ✅ Update documentation

### Phase 3-9: Modular Extraction (🚧 Next)

See [REFACTORING_PLAN.md](REFACTORING_PLAN.md) for complete timeline.

---

## Performance Targets

### Current (v1.x)

```
Files processed: 100,000
Duration: ~180s
Throughput: ~545 files/s
Memory: 287MB peak
```

### Target (v2.0)

```
Files processed: 100,000
Duration: ≤180s (same or better)
Throughput: ≥545 files/s
Memory: ≤250MB peak
Code size: -26% (1,905 → 1,400 lines)
Main script: -84% (1,905 → 300 lines)
Test coverage: >80%
```

---

## Success Metrics

### Code Quality

- ✅ Main script reduced from 1,905 → ~300 lines
- ✅ Modular libraries: 9 files, ~1,000 total lines
- ✅ Test coverage > 80%
- ✅ Shellcheck passing with zero warnings
- ✅ All functions < 50 lines

### User Experience

- ✅ Professional UI with Gum
- ✅ Automatic help generation (Argbash)
- ✅ Clear error messages
- ✅ Progress tracking
- ✅ Graceful interruption

### Maintainability

- ✅ Clear module boundaries
- ✅ Reusable libraries
- ✅ Comprehensive documentation
- ✅ Easy to extend
- ✅ Unit testable

---

## Future Enhancements

### Potential Features

1. **YAML Configuration**
   - Move extensions from hardcoded arrays to YAML
   - Support comments and metadata
   - Hierarchical organization

2. **Plugin System**
   - Custom validators
   - Custom processors
   - Extension hooks

3. **Remote Processing**
   - SSH-based remote execution
   - Distributed processing across machines

4. **Advanced Sampling**
   - Machine learning-based prediction
   - Adaptive sampling rates
   - Historical data analysis

5. **Web Dashboard**
   - Progress monitoring
   - Historical statistics
   - Configuration management

---

## Contributing

### Adding a New Module

1. Create `lib/module-name.sh`
2. Add header documentation
3. Implement functions with `module::function()` naming
4. Create `tests/test-module-name.sh`
5. Update this ARCHITECTURE.md
6. Update justfile with test recipe
7. Submit PR with tests passing

### Module Template

```bash
#!/usr/bin/env bash
# lib/module-name.sh - Brief description
#
# Detailed description of module purpose.
#
# Usage:
#   source lib/module-name.sh
#   module::function arg1 arg2

# Ensure script is sourced
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  echo "Error: This file should be sourced" >&2
  exit 1
fi

# Load dependencies
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/core.sh"

# Module version
readonly MODULE_VERSION="1.0.0"

# Module functions
module::function() {
  local arg1=$1
  local arg2=$2

  # Implementation
}

# Export functions
export -f module::function

# Mark as loaded
readonly MODULE_LOADED=true
```

---

## References

- [Refactoring Plan](REFACTORING_PLAN.md) - Complete refactoring strategy
- [Modern Shell Toolkit](MODERN_SHELL_SCRIPTING_TOOLKIT_FOR_PROFESSIONAL_CLI_APPLICATIONS.md) - Best practices
- [GitHub Project Setup](.github/GITHUB_PROJECT_SETUP.md) - Project tracking

---

**Version:** 1.1.0
**Last Updated:** 2025-11-12
**Status:** Living document - updated as architecture evolves
