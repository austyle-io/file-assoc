# Migration Guide: V1 to V2
## reset-file-associations.sh → reset-file-associations-v2.sh

**Version:** 2.0
**Date:** 2025-11-13
**Status:** Complete

---

## Overview

This guide helps you migrate from the monolithic v1 script (`reset-file-associations.sh`) to the new modular v2 implementation (`reset-file-associations-v2.sh`).

### What Changed

**V1 (Monolithic):**
- Single 1,905-line script
- Inline implementations
- Manual argument parsing
- Basic ANSI color codes
- Manual xargs-based parallelization

**V2 (Modular):**
- 484-line orchestration script
- 8 reusable library modules
- Automatic argument parser
- Gum-powered UI (with fallback)
- GNU Parallel integration (with fallback)

### Key Benefits

1. **74.6% Code Reduction** - Main script reduced from 1,905 to 484 lines
2. **Better Maintainability** - Modular architecture with clear separation of concerns
3. **Enhanced UI** - Professional terminal interface using Gum
4. **Improved Performance** - GNU Parallel for efficient parallel processing
5. **Better Testing** - Comprehensive integration test suite
6. **Easier Extension** - Modular libraries make adding features simple

---

## Command-Line Interface

### No Breaking Changes!

The v2 script maintains **100% backward compatibility** with v1 command-line arguments. All existing scripts and workflows will continue to work.

### Side-by-Side Comparison

| Feature | V1 Command | V2 Command | Notes |
|---------|------------|------------|-------|
| Help | `./reset-file-associations.sh --help` | `./reset-file-associations-v2.sh --help` | Same output |
| Dry run | `./reset-file-associations.sh --dry-run` | `./reset-file-associations-v2.sh --dry-run` | Same behavior |
| Verbose | `./reset-file-associations.sh --verbose` | `./reset-file-associations-v2.sh --verbose` | Enhanced output |
| Extensions | `./reset-file-associations.sh -e pdf -e doc` | `./reset-file-associations-v2.sh -e pdf -e doc` | Same syntax |
| Directory | `./reset-file-associations.sh ~/Documents` | `./reset-file-associations-v2.sh ~/Documents` | Same syntax |
| Path option | `./reset-file-associations.sh --path ~/Docs` | `./reset-file-associations-v2.sh --path ~/Docs` | Same behavior |
| Max files | `./reset-file-associations.sh --max-files 5000` | `./reset-file-associations-v2.sh --max-files 5000` | Same behavior |
| Workers | `./reset-file-associations.sh --workers 4` | `./reset-file-associations-v2.sh --workers 4` | Same behavior |
| No parallel | `./reset-file-associations.sh --no-parallel` | `./reset-file-associations-v2.sh --no-parallel` | Same behavior |
| Sampling | `./reset-file-associations.sh --sample-size 50` | `./reset-file-associations-v2.sh --sample-size 50` | Same behavior |
| Skip sampling | `./reset-file-associations.sh --skip-sampling` | `./reset-file-associations-v2.sh --skip-sampling` | Same behavior |
| Log level | `./reset-file-associations.sh --log-level DEBUG` | `./reset-file-associations-v2.sh --log-level DEBUG` | Same behavior |

### Complete Argument List

```bash
# Boolean flags
--help, -h              Show help message
--dry-run, -d           Preview changes without modifying files
--verbose               Show detailed output
--no-confirm            Skip confirmation prompts
--no-throttle           Disable all throttling
--no-parallel           Disable parallel processing
--skip-sampling         Skip the sampling phase

# Single-value options
--path, -p PATH         Target directory (overrides positional arg)
--max-files NUM         Maximum files to process (default: 10000)
--max-rate NUM          Maximum files per second (default: 100)
--max-memory NUM        Maximum memory in MB (default: 500)
--batch-size NUM        Files per batch (default: 1000)
--workers NUM           Number of parallel workers, 0=auto (default: 0)
--chunk-size NUM        Files per worker chunk (default: 100)
--sample-size NUM       Number of files to sample (default: 100)
--log-level LEVEL       Log level: DEBUG|INFO|WARN|ERROR (default: INFO)
--log-file PATH         Custom log file location

# Repeated options
--ext, -e EXT           File extension to process (repeatable)

# Positional
DIRECTORY               Directory to process (default: current directory)
```

---

## Using Justfile Recipes

The justfile provides convenient shortcuts for running both versions.

### V1 Commands (Original Script)

```bash
# Run v1 script
just reset-file-associations ~/Documents

# Run v1 script with options
just reset-file-associations ~/Documents --dry-run --verbose

# Preview with v1 (dry run)
just reset-file-associations-preview ~/Documents
```

### V2 Commands (New Modular Script)

```bash
# Run v2 script
just reset-v2 ~/Documents

# Run v2 script with options
just reset-v2 ~/Documents --dry-run --verbose

# Preview with v2 (dry run)
just reset-v2-preview ~/Documents
```

---

## Behavioral Differences

While the command-line interface is identical, some internal behaviors have improved:

### 1. Enhanced UI (When Gum Available)

**V1:**
- Basic ANSI color codes
- Simple text output
- Manual progress indication

**V2:**
- Gum-powered UI with styled output
- Progress bars (when verbose enabled)
- Better visual hierarchy
- Graceful fallback to ANSI codes if Gum not installed

**Example:**
```bash
# V1 output
Processing .pdf files...
Found 150 files
Cleared: 45 files

# V2 output (with Gum)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  File Association Reset v2.0
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

ℹ Processing .pdf files...
ℹ   Found 150 files
✓   Processed: 150 files
ℹ   Cleared: 45 files
```

### 2. Parallel Processing

**V1:**
- Uses `xargs -P` for parallelization
- Manual worker management
- Basic error handling

**V2:**
- Uses GNU Parallel (if available)
- Automatic worker detection
- Better error handling and reporting
- Fallback to sequential processing

**Performance:**
Both versions achieve similar throughput (~500-600 files/sec), but v2 has more efficient resource management.

### 3. Sampling Phase

**V1:**
- Basic random sampling
- Simple hit rate calculation

**V2:**
- Enhanced sampling with `sampling.sh` module
- More accurate hit rate estimation
- Better confidence reporting
- Same results, cleaner implementation

### 4. Logging

**V1:**
- Inline logging implementation
- Manual log rotation

**V2:**
- Dedicated `logging.sh` module
- Structured log levels (DEBUG, INFO, WARN, ERROR)
- Better log formatting
- Same log file location: `~/.dotfiles-logs/`

### 5. Error Handling

**V1:**
- Basic error messages
- Exit codes

**V2:**
- Enhanced error messages with context
- Same exit codes (backward compatible)
- Better signal handling (SIGINT, SIGTERM)

---

## Environment Variables

All environment variables from v1 are still supported in v2:

```bash
# Resource limits
export FILE_ASSOC_MAX_FILES=20000
export FILE_ASSOC_MAX_RATE=200
export FILE_ASSOC_MAX_MEMORY=1000
export FILE_ASSOC_BATCH_SIZE=2000

# Parallel processing
export FILE_ASSOC_WORKERS=8
export FILE_ASSOC_CHUNK_SIZE=200
export FILE_ASSOC_USE_PARALLEL=true

# Sampling
export FILE_ASSOC_SAMPLE_SIZE=200

# Logging
export FILE_ASSOC_LOG_LEVEL=DEBUG
```

---

## Migration Steps

### Option 1: Simple Rename (Recommended)

The easiest migration is to simply use v2 instead of v1:

```bash
# Old
./scripts/reset-file-associations.sh --dry-run ~/Documents

# New
./scripts/reset-file-associations-v2.sh --dry-run ~/Documents
```

### Option 2: Gradual Migration

Keep both versions during transition:

1. **Test v2 with dry-run:**
   ```bash
   just reset-v2-preview ~/test-directory
   ```

2. **Compare outputs:**
   ```bash
   # Run v1 dry-run
   just reset-file-associations-preview ~/test-directory > v1-output.txt

   # Run v2 dry-run
   just reset-v2-preview ~/test-directory > v2-output.txt

   # Compare
   diff v1-output.txt v2-output.txt
   ```

3. **Switch to v2 when confident:**
   ```bash
   just reset-v2 ~/Documents
   ```

### Option 3: Scripted Migration

Update your existing automation scripts:

**Before:**
```bash
#!/bin/bash
./scripts/reset-file-associations.sh \
  --no-confirm \
  --max-files 5000 \
  -e pdf -e doc -e docx \
  ~/Documents
```

**After:**
```bash
#!/bin/bash
./scripts/reset-file-associations-v2.sh \
  --no-confirm \
  --max-files 5000 \
  -e pdf -e doc -e docx \
  ~/Documents
```

---

## Verifying Migration

### 1. Run Integration Tests

```bash
# Test v2 implementation
just test-integration
```

Expected output:
```text
==========================================
  File Association Reset - Integration Tests
==========================================

[Test 1] Script exists and is executable
  ✓ PASSED

[Test 2] Help output works
  ✓ PASSED

...

==========================================
  Test Summary
==========================================
Tests run:    14
Tests passed: 14

ALL TESTS PASSED
```

### 2. Test Common Scenarios

```bash
# Test 1: Dry run with verbose
just reset-v2-preview ~/test-directory

# Test 2: Specific extensions
just reset-v2 ~/test-directory -e pdf -e doc

# Test 3: With sampling
./scripts/reset-file-associations-v2.sh \
  --sample-size 50 \
  --no-confirm \
  ~/test-directory

# Test 4: No parallel mode
./scripts/reset-file-associations-v2.sh \
  --no-parallel \
  --no-confirm \
  ~/test-directory
```

### 3. Compare Results

Run the same command on a test directory with both versions:

```bash
# Create test directory
mkdir -p ~/test-migration
cp -r ~/Documents/sample-files ~/test-migration/v1-test
cp -r ~/Documents/sample-files ~/test-migration/v2-test

# Run v1
./scripts/reset-file-associations.sh \
  --no-confirm \
  -e pdf \
  ~/test-migration/v1-test

# Run v2
./scripts/reset-file-associations-v2.sh \
  --no-confirm \
  -e pdf \
  ~/test-migration/v2-test

# Compare results (should be identical)
diff -r ~/test-migration/v1-test ~/test-migration/v2-test
```

---

## Troubleshooting

### Issue: "Module not found" error

**Symptom:**
```bash
./scripts/reset-file-associations-v2.sh: line 17: lib/core.sh: No such file or directory
```

**Solution:**
Ensure you're running the script from the project root or use an absolute path:
```bash
cd /path/to/file-assoc
./scripts/reset-file-associations-v2.sh
```

### Issue: Gum not available warning

**Symptom:**
```text
⚠ Gum not available - using fallback UI
```

**Solution:**
This is not an error! V2 works fine without Gum, but install it for enhanced UI:
```bash
brew install gum
```

### Issue: GNU Parallel not available

**Symptom:**
```text
⚠ GNU Parallel not available - will use sequential processing
```

**Solution:**
This is not an error! V2 works fine without Parallel, but install it for better performance:
```bash
brew install parallel
```

### Issue: Performance seems slower

**Investigation:**
1. Check if parallel processing is enabled:
   ```bash
   ./scripts/reset-file-associations-v2.sh --verbose ~/Documents
   # Look for "Parallel Processing: N workers" in output
   ```

2. Try increasing workers:
   ```bash
   ./scripts/reset-file-associations-v2.sh --workers 8 ~/Documents
   ```

3. Check system resources:
   ```bash
   # Monitor during execution
   top -pid $(pgrep -f reset-file-associations-v2)
   ```

---

## Rollback Plan

If you encounter issues with v2, you can always rollback to v1:

### Temporary Rollback

```bash
# Simply use v1 script
./scripts/reset-file-associations.sh [options] [directory]
```

### Permanent Rollback (if needed)

```bash
# Update your automation to use v1
# V1 script will remain in the repository for compatibility
```

**Note:** Both scripts will be maintained during the transition period.

---

## Future Deprecation Timeline

- **Current (2025-Q4):** Both v1 and v2 available
- **2026-Q1:** V2 recommended for all new usage
- **2026-Q2:** V1 marked as deprecated (still available)
- **2026-Q3:** V1 removed from default justfile recipes
- **2026-Q4:** V1 script archived to `scripts/legacy/`

---

## Getting Help

### Documentation

- [ARCHITECTURE.md](ARCHITECTURE.md) - Technical architecture
- [REFACTORING_PLAN.md](REFACTORING_PLAN.md) - Complete refactoring plan
- [Module README files](../lib/) - Individual module documentation

### Testing

```bash
# Run all tests
just test-all

# Run only integration tests
just test-integration

# Run only unit tests
just test-unit
```

### Community

- **Issues:** [GitHub Issues](https://github.com/austyle-io/file-assoc/issues)
- **Discussions:** [GitHub Discussions](https://github.com/austyle-io/file-assoc/discussions)

---

## Summary

**Key Takeaways:**

1. ✅ **No breaking changes** - All v1 commands work in v2
2. ✅ **Better architecture** - 74.6% code reduction through modularity
3. ✅ **Enhanced features** - Better UI, logging, and error handling
4. ✅ **Same performance** - Equivalent or better throughput
5. ✅ **Easy migration** - Just replace script name in your commands
6. ✅ **Comprehensive tests** - 14 integration tests ensure compatibility

**Migration in one line:**
```bash
# Change this:
./scripts/reset-file-associations.sh --dry-run ~/Documents

# To this:
./scripts/reset-file-associations-v2.sh --dry-run ~/Documents
```

That's it! 🎉

---

**Questions or Issues?** Please open an issue on GitHub or refer to the documentation in `docs/`.
