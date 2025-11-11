# macOS File Association Management Tools

Comprehensive toolkit for managing macOS file associations at both system-wide and per-file levels.

## 📋 Overview

macOS uses a two-tier file association system:

1. **System-wide defaults** - Stored in Launch Services database, applied via `duti`
2. **Per-file overrides** - Stored as extended attributes on individual files

This toolkit provides tools to manage both levels:
- `file-assoc-setup` - Apply system-wide defaults
- `file-assoc-reset` - Remove per-file overrides

## 🚀 Quick Start

### Prerequisites

```bash
# Install duti (if not already installed)
brew install duti
```

### Installation

1. Add `bin/` to your PATH:
   ```bash
   export PATH="/Users/austyle/austyle-io/file-assoc/bin:$PATH"
   ```

2. Or use the justfile recipes:
   ```bash
   cd /Users/austyle/austyle-io/file-assoc
   just setup-file-associations
   ```

### Basic Usage

```bash
# Apply system-wide file associations
file-assoc-setup

# Reset per-file overrides in a directory
file-assoc-reset ~/Downloads

# Preview what would be reset (dry run)
file-assoc-reset --dry-run --verbose ~/Documents

# Get help
file-assoc-setup --help
file-assoc-reset --help
```

## 📁 Directory Structure

```
file-assoc/
├── README.md                        # This file
├── justfile                         # Task runner recipes
├── bin/                             # User-facing commands (add to PATH)
│   ├── file-assoc-setup            # Apply system-wide associations
│   └── file-assoc-reset            # Remove per-file overrides
├── scripts/                         # Core implementation
│   └── reset-file-associations.sh  # Main reset script (53KB, 1200+ lines)
├── config/                          # Configuration
│   └── macos-file-associations.duti # Association mappings (38 extensions)
└── docs/                            # Documentation
    └── LAUNCH_SERVICES_ANALYSIS.md # Deep-dive technical documentation
```

## 🔧 Tools

### 1. file-assoc-setup

**Purpose:** Apply system-wide file associations from configuration.

**Usage:**
```bash
file-assoc-setup              # Apply associations
file-assoc-setup --configure  # Edit config file
file-assoc-setup --help       # Show help
```

**What it does:**
- Validates `duti` is installed
- Applies all mappings from `config/macos-file-associations.duti`
- Sets default applications for 38+ file extensions
- Effects are immediate for new files

### 2. file-assoc-reset

**Purpose:** Remove per-file custom associations to let system defaults apply.

**Usage:**
```bash
file-assoc-reset [OPTIONS] [DIRECTORY]

# Common options:
--dry-run              # Preview without making changes
--verbose              # Show detailed output
--ext md --ext sh      # Only process specific extensions
--skip-sampling        # Disable smart sampling optimization
--workers 8            # Set parallel workers (default: auto)
--sample-size 100      # Custom sample size (default: 50)
-p, --path DIR         # Target directory
```

**Examples:**
```bash
# Reset all supported files in Downloads
file-assoc-reset ~/Downloads

# Dry run with verbose output
file-assoc-reset --dry-run --verbose ~/Documents

# Only reset markdown and shell files
file-assoc-reset --ext md --ext sh ~/Projects

# High-performance reset with 16 workers
file-assoc-reset --workers 16 ~/Code
```

## 📊 Performance Features

### Smart Sampling
The reset script includes intelligent sampling to skip directories that don't have custom associations:
- Samples 50 random files per extension
- If sample shows 0% with custom associations, skips entire directory
- Can save minutes on large directories

### Parallel Processing
- Auto-detects CPU cores
- Configurable worker count
- Chunk-based processing for optimal throughput
- Typical throughput: 100-500 files/s (varies by extension)

### Progress Tracking
- Real-time progress bars with smooth animations
- Realistic ETA calculations based on actual throughput
- Per-extension performance metrics
- Comprehensive summary report

### Example Performance Report
```
Extension           Files  w/Attrs   Duration     Rate
------------------------------------------------------------
.js                  6067        0     11.44s   530.2/s
.json                4740        0      9.69s   489.0/s
.ts                  4272        0      9.86s   433.0/s
.md                  3852        0      9.10s   423.2/s
.tsx                 1768        0      6.88s   256.9/s
------------------------------------------------------------
TOTAL               27305        0    211.93s   128.8/s
```

## 🎯 Supported File Types

### Configuration
json, jsonc, json5, yaml, yml, toml, env, envrc, gitignore, gitattributes

### Documentation
md, markdown, txt, log

### Shell Scripts
sh, bash, zsh, fish

### Programming Languages
ts, tsx, js, jsx, mjs, cjs, py, rs, go, java, c, cpp, h, hpp, rb

### Data Formats
csv, tsv, xml, svg, sql

## 📚 Documentation

### Launch Services Architecture
See `docs/LAUNCH_SERVICES_ANALYSIS.md` for detailed documentation on:
- How Launch Services works
- System-wide vs per-file associations
- Extended attributes structure
- Database queries and optimization
- Performance analysis

### Command Help
All commands include comprehensive help:
```bash
file-assoc-setup --help
file-assoc-reset --help
```

## 🔄 Common Workflows

### Initial Setup
```bash
# 1. Apply system-wide defaults
file-assoc-setup

# 2. Reset existing files to use new defaults
file-assoc-reset ~/Downloads
file-assoc-reset ~/Documents
file-assoc-reset ~/Code
```

### After Changing Associations
```bash
# 1. Edit configuration
file-assoc-setup --configure

# 2. Re-apply system-wide defaults
file-assoc-setup

# 3. Reset affected files
file-assoc-reset ~/Downloads
```

### Testing/Verification
```bash
# Preview what would change
file-assoc-reset --dry-run --verbose ~/Downloads

# Check specific file
xattr -l ~/Downloads/file.md | grep LaunchServices

# Apply if satisfied
file-assoc-reset ~/Downloads
```

## 🛠️ Justfile Recipes

```bash
# Show available commands
just

# Apply system-wide associations
just setup-file-associations

# Reset with custom directory
just reset-file-associations ~/Downloads

# Dry run preview
just reset-file-associations-preview ~/Documents

# Quick test
just test
```

## 📈 Performance Tips

1. **Use parallel processing** (default, auto-detected)
2. **Let sampling optimize** (default, skips clean directories)
3. **For large directories**: Use `--workers 16` on high-core machines
4. **For targeted resets**: Use `--ext` to process specific extensions only
5. **Monitor progress**: The script shows real-time throughput and ETAs

## 🐛 Troubleshooting

### Script not found
```bash
# Make sure scripts are executable
chmod +x bin/file-assoc-*
chmod +x scripts/reset-file-associations.sh
```

### duti not installed
```bash
brew install duti
```

### Permission errors
```bash
# The script needs read access to scan files
# And write access to remove extended attributes
# Try with sudo if needed (not recommended for home directories)
```

### Verify associations
```bash
# Check current association for a file
duti -x md

# Check per-file override
xattr -l ~/file.md | grep LaunchServices
```

## 🔗 Related Tools

- **duti** - Command-line tool to set default applications
- **lsregister** - Launch Services database management
- **xattr** - Extended attribute manipulation

## 📝 Notes

- System-wide changes take effect immediately
- Per-file resets require file to be "closed" to take effect
- Finder may cache associations briefly
- Some system-protected files cannot be modified
- The script respects `.gitignore` patterns when present

## 🎉 Features

### Recent Enhancements
- ✅ Realistic ETA calculations based on batch timing
- ✅ Smooth progress bar animations with adaptive catch-up
- ✅ Performance metrics report (per-extension + top 5 fastest/slowest)
- ✅ Fixed spinner animation during file scanning
- ✅ Improved table formatting for long extension names
- ✅ macOS-compatible millisecond timestamps
- ✅ Batch-specific timing for accurate rate calculations

### Core Features
- ✅ Smart sampling to skip clean directories
- ✅ Parallel processing with auto-detection
- ✅ Comprehensive logging with timestamps
- ✅ Dry-run mode for safe testing
- ✅ Color-coded output
- ✅ Resource monitoring (memory, disk space)
- ✅ Graceful error handling
- ✅ Progress persistence across interruptions

---

**Version:** 1.0.0
**Author:** Tyler Austin
**Last Updated:** 2025-11-11
