# Installation Guide

## Quick Install

### 1. Add to PATH

Add the `bin/` directory to your PATH for easy access from anywhere:

```bash
# Add to your ~/.zshrc or ~/.bashrc
export PATH="/Users/austyle/austyle-io/file-assoc/bin:$PATH"
```

Then reload your shell:
```bash
source ~/.zshrc  # or ~/.bashrc
```

### 2. Verify Installation

```bash
which file-assoc-setup
which file-assoc-reset
```

Should both return paths in `/Users/austyle/austyle-io/file-assoc/bin/`

### 3. Test Commands

```bash
file-assoc-setup --help
file-assoc-reset --help
```

## Alternative: Use Just Recipes

If you prefer not to modify PATH:

```bash
cd /Users/austyle/austyle-io/file-assoc

# Show available commands
just

# Apply system-wide associations
just setup-file-associations

# Reset per-file overrides
just reset-file-associations ~/Downloads

# Dry run preview
just reset-file-associations-preview ~/Documents
```

## Standalone Operation

This directory is completely self-contained and portable:
- All wrapper scripts use relative paths
- No dependencies on dotfiles directory
- Works from any location when added to PATH
- Works with symlinks

## What Was Copied

From `/Users/austyle/Danti/dotfiles/`:

```
✓ scripts/reset-file-associations.sh   → scripts/
✓ bin/file-assoc-setup                 → bin/
✓ bin/file-assoc-reset                 → bin/
✓ config/macos-file-associations.duti  → config/
✓ docs/LAUNCH_SERVICES_ANALYSIS.md     → docs/
+ justfile                              → (extracted recipes)
+ README.md                             → (comprehensive guide)
```

All scripts maintain their executable permissions and work independently.

## Prerequisites

- **macOS** (uses Launch Services)
- **duti** - Install with: `brew install duti`
- **just** (optional) - Install with: `brew install just`

## Next Steps

1. **Review configuration:**
   ```bash
   file-assoc-setup --configure
   ```

2. **Apply system-wide defaults:**
   ```bash
   file-assoc-setup
   ```

3. **Reset existing files:**
   ```bash
   file-assoc-reset ~/Downloads
   ```

See `README.md` for complete documentation.
