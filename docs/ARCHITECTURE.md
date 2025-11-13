# Architecture Documentation
## file-assoc - Modern Shell Scripting Architecture

**Last Updated:** 2025-11-13
**Status:** Phase 5 - GNU Parallel Integration (Complete)

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
│   ├── logging.sh               # ✅ Simplified logging
│   ├── files.sh                 # ✅ File discovery & operations
│   ├── xattr.sh                 # ✅ Extended attribute management
│   ├── sampling.sh              # ✅ Smart sampling logic
│   ├── metrics.sh               # ✅ Performance tracking
│   ├── parallel.sh              # ✅ GNU Parallel wrapper
│   └── config.sh                # 🚧 Configuration management
│
├── scripts/
│   ├── reset-file-associations.sh  # Main script (being refactored)
│   └── setup-github-project.sh     # GitHub project automation
│
├── templates/                    # Code generation templates (NEW Phase 4)
│   ├── reset-args.m4             # ✅ Argbash template for argument parsing
│   ├── generate-parser.sh        # ✅ Parser generation script
│   └── README.md                 # ✅ Template documentation
│
├── tests/                        # Unit & integration tests (NEW)
│   ├── test-core.sh             # ✅ Tests for lib/core.sh
│   ├── test-ui.sh               # ✅ Tests for lib/ui.sh
│   ├── test-logging.sh          # ✅ Tests for lib/logging.sh
│   ├── test-files.sh            # ✅ Tests for lib/files.sh
│   ├── test-xattr.sh            # ✅ Tests for lib/xattr.sh
│   ├── test-metrics.sh          # ✅ Tests for lib/metrics.sh
│   ├── test-parallel.sh         # ✅ Tests for lib/parallel.sh
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

#### `lib/logging.sh` - Simplified Logging ✅

**Status:** Complete (Phase 3)
**Lines:** ~260
**Dependencies:** lib/core.sh
**Test Coverage:** 11/11 tests passing

**Purpose:**
Lightweight file-based logging without over-engineering. Handles log file creation, rotation, buffering, and level filtering. Console output is handled by lib/ui.sh.

**Key Functions:**

```bash
# Initialization
log::init()          # Initialize logging system with directory, file, level
log::rotate()        # Rotate old log files, keep N most recent

# Writing
log::write()         # Internal write to buffer with level filtering
log::flush()         # Flush buffer to file

# Convenience functions
log::debug()         # Log debug message
log::info()          # Log info message
log::warn()          # Log warning message
log::error()         # Log error message
log::fatal()         # Log fatal error and flush immediately

# Configuration
log::get_file()      # Get current log file path
log::get_level()     # Get current log level
log::set_level()     # Set log level (DEBUG, INFO, WARN, ERROR)
```

**Usage Example:**

```bash
source lib/core.sh
source lib/logging.sh

# Initialize logging
log::init "/var/log/myapp" "" "INFO" 10

# Log messages
log::info "STARTUP" "Application started"
log::warn "CONFIG" "Missing optional config file"
log::error "DATABASE" "Connection failed"

# Fatal error (auto-flushes)
log::fatal "CRITICAL" "Unrecoverable error"
```

---

#### `lib/files.sh` - File Discovery & Operations ✅

**Status:** Complete (Phase 3)
**Lines:** ~340
**Dependencies:** lib/core.sh
**Test Coverage:** 12/12 tests passing

**Purpose:**
File system operations for finding and counting files by extension. Provides efficient file discovery with validation and size calculations.

**Key Functions:**

```bash
# Counting
files::count()               # Count files by extension
files::count_all()           # Count all files in directory
files::count_multiple()      # Count files for multiple extensions

# Discovery
files::find_by_ext()         # Find files by extension
files::find_all()            # Find all files in directory
files::find_by_extensions()  # Find files matching multiple extensions

# Validation
files::validate_directory()  # Validate directory exists and is readable
files::get_absolute_dir()    # Get absolute path of directory

# Size Operations
files::get_size()            # Get file size in bytes
files::get_total_size()      # Get total size of files by extension
files::format_size()         # Format bytes to human-readable (KB, MB, GB)

# Extension Utilities
files::get_extension()       # Extract extension from filename
files::has_extension()       # Check if file has specific extension

# Estimation
files::estimate_time()       # Estimate processing time based on file count
```

**Usage Example:**

```bash
source lib/core.sh
source lib/files.sh

# Count files
count=$(files::count "/path/to/dir" "txt")
echo "Found $count .txt files"

# Find and process files
files::find_by_ext "/path/to/dir" "md" | while read -r file; do
  echo "Processing: $file"
done

# Validate directory
if files::validate_directory "/target/dir"; then
  echo "Directory is valid"
fi

# Get size information
size=$(files::get_total_size "/path/to/dir" "log")
echo "Total size: $(files::format_size $size)"
```

---

#### `lib/xattr.sh` - Extended Attribute Operations ✅

**Status:** Complete (Phase 3)
**Lines:** ~280
**Dependencies:** lib/core.sh
**Test Coverage:** 7/7 tests passing (macOS-specific)

**Purpose:**
macOS extended attribute management for LaunchServices file associations. Wraps xattr operations with error handling and provides batch operations.

**Key Functions:**

```bash
# Checking
xattr::has_launch_services()    # Check if file has LaunchServices attr
xattr::has_any()                # Check if file has any extended attributes
xattr::is_available()           # Check if xattr command is available

# Removal
xattr::clear_launch_services()  # Remove LaunchServices attr from file
xattr::clear_all()              # Remove all extended attributes

# Queries
xattr::list()                   # List all attributes for file
xattr::get()                    # Get specific attribute value
xattr::version()                # Get xattr version/info

# Batch Operations
xattr::count_with_launch_services()  # Count files with LaunchServices attr
xattr::find_with_launch_services()   # Find files with LaunchServices attr
```

**Usage Example:**

```bash
source lib/core.sh
source lib/xattr.sh

# Check and clear attribute
if xattr::has_launch_services "/path/to/file.txt"; then
  echo "File has custom association"
  xattr::clear_launch_services "/path/to/file.txt"
  echo "Association cleared"
fi

# Batch operations
count=$(xattr::count_with_launch_services "/Documents" "pdf")
echo "Found $count PDF files with custom associations"

# List all attributes
xattr::list "/path/to/file.txt"
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

#### `lib/sampling.sh` - Smart Sampling Logic ✅

**Status:** Complete (Phase 3)
**Lines:** ~300
**Dependencies:** lib/core.sh, lib/files.sh, lib/xattr.sh
**Test Coverage:** Integrated with files/xattr tests

**Purpose:**
Pre-scan sampling to estimate hit rates and determine if full scans are needed. Randomly samples files to check for extended attributes.

**Key Functions:**

```bash
# Sampling
sampling::get_sample()           # Get random sample of files for extension
sampling::analyze()              # Analyze sample across all extensions
sampling::analyze_extension()    # Analyze single extension sample
sampling::calculate_rate()       # Calculate hit rate percentage

# Decision Making
sampling::should_skip()          # Check if directory should be skipped
sampling::estimate_total()       # Estimate total files needing processing
sampling::get_confidence()       # Get confidence level for sample size

# Reporting
sampling::format_results()       # Format sampling results for display
```

**Usage Example:**

```bash
source lib/core.sh
source lib/files.sh
source lib/xattr.sh
source lib/sampling.sh

# Analyze directory with 100-file sample
result=$(sampling::analyze "/Documents" 100 "pdf" "doc" "txt")
read with_attr sample_size <<< "$result"

# Calculate hit rate
hit_rate=$(sampling::calculate_rate $with_attr $sample_size)
echo "Hit rate: ${hit_rate}%"

# Decide whether to skip
if sampling::should_skip $with_attr $sample_size 50; then
  echo "No files need processing, skipping..."
else
  echo "Proceeding with full scan..."
fi
```

---

#### `lib/metrics.sh` - Performance Tracking ✅

**Status:** Complete (Phase 3)
**Lines:** ~380
**Dependencies:** lib/core.sh
**Test Coverage:** 10/10 tests passing

**Purpose:**
Track and report performance metrics for file processing operations. Records timing, throughput, and generates detailed performance reports with top performers.

**Key Functions:**

```bash
# Initialization
metrics::init()                  # Initialize/reset metrics system
metrics::get_timestamp_ms()      # Get current timestamp in milliseconds

# Recording
metrics::start()                 # Record start of operation
metrics::end()                   # Record end of operation with counts
metrics::update()                # Update operation metrics without ending

# Calculations
metrics::get_duration_ms()       # Get operation duration in milliseconds
metrics::get_duration_sec()      # Get operation duration in seconds
metrics::get_rate()              # Calculate files per second rate

# Reporting
metrics::report()                # Generate full performance report
metrics::report_top_performers() # Show top 5 fastest/slowest operations
metrics::summary()               # Generate one-line summary
```

**Usage Example:**

```bash
source lib/core.sh
source lib/metrics.sh

# Initialize
metrics::init

# Track operations
for ext in txt md doc; do
  metrics::start "$ext"
  # ... process files ...
  metrics::end "$ext" $files_processed $files_with_attrs $files_cleared
done

# Generate report
metrics::report

# Or get simple summary
echo $(metrics::summary)
# Output: Processed 1000 files in 5.23s (191.2 files/s)
```

---

#### `lib/parallel.sh` - GNU Parallel Integration ✅

**Status:** Complete (Phase 5)
**Lines:** ~290
**Dependencies:** None (requires GNU Parallel installed)
**Test Coverage:** 10/10 tests passing

**Purpose:**
Provides wrappers around GNU Parallel for efficient parallel file processing with automatic load balancing, progress tracking, and error handling. Replaces manual xargs-based parallelization with a robust, feature-rich solution.

**Key Functions:**

```bash
# Initialization
parallel::init()                     # Check GNU Parallel availability
parallel::is_available()             # Check if parallel is installed
parallel::get_workers()              # Auto-detect optimal worker count

# Basic Execution
parallel::run()                      # Basic parallel runner with defaults
parallel::run_with_progress()        # Run with built-in progress bar
parallel::run_custom()               # Run with custom options

# High-Level Wrappers
parallel::process_files()            # Process files with custom function
parallel::version()                  # Get GNU Parallel version
parallel::status()                   # Display module status
```

**Usage Example:**

```bash
source lib/parallel.sh
source lib/xattr.sh

# Initialize
parallel::init || {
  echo "GNU Parallel not available"
  exit 1
}

# Define processing function
process_file() {
  local file="$1"
  if xattr::has_launch_services "$file"; then
    xattr::clear_launch_services "$file"
    echo "Cleared: $file"
  fi
}
export -f process_file

# Process files in parallel with progress
find /path/to/files -name "*.md" \
  | parallel::run_with_progress process_file

# Or use high-level wrapper
files::find_by_ext "$DIR" "md" \
  | parallel::process_files process_file
```

**Benefits over Manual xargs:**

- **Automatic output ordering** (`--keep-order`) - Results appear in input order
- **Built-in progress tracking** (`--progress`) - No custom progress bars needed
- **Better load balancing** - Distributes work optimally across workers
- **Simpler error handling** - `--halt soon,fail=1` stops on first error
- **ETA estimation** - Shows estimated completion time
- **~170 lines eliminated** - Removes complex worker coordination code

**Worker Count Auto-Detection:**

The module automatically detects optimal worker count based on CPU cores:
- Uses 75% of available cores (leaves headroom for system)
- Minimum of 1 worker
- Can be overridden with `WORKERS` environment variable
- Platform-aware (macOS: `sysctl`, Linux: `nproc`)

**Example with Custom Options:**

```bash
# Process with timeout and retry
echo -e "file1\nfile2\nfile3" \
  | parallel::run_custom "--jobs 4 --timeout 30 --retries 2" process_file

# Process with specific worker count
WORKERS=8 parallel::run process_file <<< "$files"
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
├── test-logging.sh       # ✅ Unit tests for lib/logging.sh (11 tests)
├── test-files.sh         # ✅ Unit tests for lib/files.sh (12 tests)
├── test-xattr.sh         # ✅ Unit tests for lib/xattr.sh (7 tests, macOS only)
├── test-metrics.sh       # ✅ Unit tests for lib/metrics.sh (10 tests)
├── test-sampling.sh      # 🚧 Unit tests for lib/sampling.sh
├── test-parallel.sh      # 🚧 Unit tests for lib/parallel.sh
├── integration/          # 🚧 End-to-end tests
│   ├── test-full-workflow.sh
│   ├── test-dry-run.sh
│   └── test-sampling.sh
└── fixtures/             # Test data
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

# Results (Phase 3 complete)
Tests run: 81
Passed: 81
Failed: 0
✅ All tests passed!

# Breakdown by module:
# - core.sh:    24/24 tests passing
# - ui.sh:      17/17 tests passing
# - logging.sh: 11/11 tests passing
# - files.sh:   12/12 tests passing
# - xattr.sh:    7/7  tests passing
# - metrics.sh: 10/10 tests passing
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

## Argument Parsing

### Argbash Template Approach (Phase 4)

The project uses [Argbash](https://argbash.io/) to generate professional argument parsing code from declarative templates. This approach provides:

- **Automatic Help Generation**: Self-documenting CLI with --help
- **Type Validation**: Integer validation, enum checking
- **Consistent Error Messages**: Professional error handling
- **Reduced Boilerplate**: ~134 lines of manual parsing → generated code
- **Maintainability**: Changes made in template, regenerate parser

### Template Structure

The Argbash template (`templates/reset-args.m4`) defines:

**Boolean Flags**:
- `--dry-run` / `-d`: Preview changes without making them
- `--verbose` / `-v`: Detailed output with progress
- `--no-throttle`: Disable rate limiting
- `--no-confirm`: Skip confirmation prompts
- `--no-parallel`: Use sequential processing
- `--skip-sampling`: Skip pre-scan sampling

**Single-Value Options**:
- `--path` / `-p PATH`: Target directory
- `--max-files N`: Maximum files limit (default: 10000)
- `--max-rate N`: Rate limit (default: 100 files/s)
- `--max-memory N`: Memory limit (default: 500MB)
- `--batch-size N`: Batch size (default: 1000)
- `--workers N`: Worker count (default: auto)
- `--chunk-size N`: Chunk size (default: 100)
- `--sample-size N`: Sample size (default: 100)
- `--log-level LEVEL`: Log level (DEBUG, INFO, WARN, ERROR)
- `--log-file PATH`: Custom log file path

**Repeated Options**:
- `--ext` / `-e EXT`: File extensions (repeatable)

**Positional Arguments**:
- `DIRECTORY`: Target directory (default: current directory)

### Validation

The template includes comprehensive validation:
- Integer validation for all numeric options
- Enum validation for log levels (DEBUG, INFO, WARN, ERROR)
- Directory existence checks
- Extension normalization (removes leading dots)
- Conflict detection (--path vs positional directory)

### Generating the Parser

**Prerequisites**:
```bash
# Install argbash
brew install argbash

# Or install all dependencies
brew bundle install
```

**Generate parser**:
```bash
# Using justfile
just generate-parser

# Or manually
./templates/generate-parser.sh

# Or with argbash directly
argbash templates/reset-args.m4 -o lib/args-parser.sh
```

**Check if regeneration needed**:
```bash
just check-parser
```

### Integration

Once generated, the parser is sourced by the main script:

```bash
#!/usr/bin/env bash
# Source the generated argument parser
source lib/args-parser.sh

# Use parsed arguments
echo "Target directory: $TARGET_DIR"
echo "Dry run: $DRY_RUN"
echo "Extensions: ${EXTENSIONS[@]}"
```

The parser exports all arguments as environment variables matching the main script's expectations.

### Benefits Over Manual Parsing

| Aspect | Manual Parsing | Argbash |
|--------|---------------|---------|
| Lines of code | ~134 lines | Template: ~200 lines (reusable) |
| Help generation | Manual | Automatic |
| Validation | Manual | Built-in |
| Error messages | Custom | Consistent |
| Type checking | Manual | Automatic |
| Maintainability | Low | High |
| Documentation | Separate | Self-documenting |

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

### Phase 3: Modular Extraction (✅ Complete)

- ✅ Extract lib/logging.sh (simplified file logging)
- ✅ Extract lib/files.sh (file operations & discovery)
- ✅ Extract lib/xattr.sh (extended attribute operations)
- ✅ Extract lib/sampling.sh (smart sampling logic)
- ✅ Extract lib/metrics.sh (performance tracking)
- ✅ Create unit tests for all modules (81 tests total)
- ✅ Update justfile to run all tests
- ✅ Update documentation

### Phase 4: Argument Parsing with Argbash (✅ Template Ready)

- ✅ Create Argbash template (templates/reset-args.m4)
- ✅ Define all 18+ arguments and options with validation
- ✅ Create parser generation script (templates/generate-parser.sh)
- ✅ Add justfile recipes (generate-parser, check-parser)
- ✅ Document template structure and usage
- ⏳ Install argbash (requires: brew install argbash)
- ⏳ Generate parser script (run after argbash install)
- ⏳ Integrate into main script
- ⏳ Test all argument combinations
- ⏳ Remove manual argument parsing code

**Note**: Argbash must be installed before parser can be generated.
See `templates/README.md` for complete documentation.

### Phase 5-9: Integration & Enhancement (🚧 Next)

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

**Version:** 1.3.0
**Last Updated:** 2025-11-12
**Status:** Living document - updated as architecture evolves
