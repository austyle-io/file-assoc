# Shell Script Portability Guide

This guide documents defensive patterns and portability best practices adopted from the dotfiles repository.

## Table of Contents

1. [echo vs printf](#echo-vs-printf)
2. [Defensive Patterns](#defensive-patterns)
3. [Command Detection](#command-detection)
4. [Error Handling](#error-handling)
5. [Variable Safety](#variable-safety)

---

## echo vs printf

### Rule: Always use printf for portability

**Why?**
- `echo` behavior is **unspecified** by POSIX when arguments contain backslashes or start with `-n`
- Behavior varies across shells (bash, dash, zsh) and systems (macOS, Linux)
- Even same bash version can differ based on compilation flags

### Examples

```bash
# ❌ NON-PORTABLE - echo with escape sequences
echo -e "${RED}Error${NC}"
echo -n "Loading..."

# ✅ PORTABLE - printf with explicit formatting
printf '%b' "${RED}Error${NC}\n"
printf '%s' "Loading..."

# ❌ DANGEROUS - variable in echo (could start with -n or contain \)
echo "$variable"

# ✅ SAFE - variable properly formatted
printf '%s\n' "$variable"
```

### Quick Reference

| Task | echo (non-portable) | printf (portable) |
|------|---------------------|-------------------|
| Print with newline | `echo "text"` | `printf '%s\n' "text"` |
| Print without newline | `echo -n "text"` | `printf '%s' "text"` |
| Escape sequences | `echo -e "\033[31m"` | `printf '\033[31m'` |
| With variables | `echo "$var"` | `printf '%s\n' "$var"` |
| Formatted output | N/A | `printf '%-20s %5d\n' "name" 42` |

---

## Defensive Patterns

### 1. File Existence Checks

Always verify files exist and are readable before sourcing or processing:

```bash
# Check file exists
[ -f "$file" ] && . "$file"

# Check readable
[ -r "$file" ] && source "$file"

# Check directory exists
[ -d "$directory" ] && cd "$directory"

# Combined checks for safety
[ -f "$file" ] && [ -r "$file" ] && . "$file"
```

### 2. Guard Against Double-Loading

Prevent duplicate initialization:

```bash
# Set guard variable on first load
if [ -z "$MODULE_LOADED" ]; then
    # ... initialization code ...
    export MODULE_LOADED=1
fi
```

### 3. Safe Early Return/Exit

Handle both sourced files and executed scripts:

```bash
# Works whether sourced or executed
return 0 2>/dev/null || exit 0

# For error cases
return 1 2>/dev/null || exit 1
```

---

## Command Detection

### Portable Command Availability Check

```bash
# ✅ PORTABLE - Works across all POSIX shells
if command -v foo >/dev/null 2>&1; then
    eval "$(foo init)"
fi

# ⚠️ LESS PORTABLE - Works but verbose
if type foo >/dev/null 2>&1; then
    eval "$(foo init)"
fi

# ❌ NOT PORTABLE - bash/zsh specific
if which foo &>/dev/null; then
    eval "$(foo init)"
fi
```

---

## Error Handling

### 1. Error Suppression with Fallback

```bash
# Suppress errors, continue on failure
command 2>/dev/null || true

# Provide default value on failure
result=$(command 2>/dev/null || echo "default")

# Conditional execution
command 2>/dev/null && echo "Success" || echo "Failed"
```

### 2. Safe Output Redirection

```bash
# Suppress both stdout and stderr (bash/zsh)
command &>/dev/null

# POSIX-portable equivalent
command >/dev/null 2>&1

# Stderr only
command 2>/dev/null
```

### 3. Set Options for Safety

```bash
#!/usr/bin/env bash
set -euo pipefail  # Exit on error, undefined var, pipe failures

# Alternatively, per-function:
set -e              # Exit on error
set -u              # Error on undefined variable
set -o pipefail     # Pipe failure detection
```

---

## Variable Safety

### 1. Default Values

```bash
# Use default if unset or empty
VAR="${VAR:-default_value}"

# Use default only if unset (preserve empty string)
VAR="${VAR-default_value}"

# Set and export in one line
VAR="${VAR:-default}"
export VAR
```

### 2. Existence Checks

```bash
# Check if variable is set and non-empty
[ -n "$VAR" ] && echo "VAR is set"

# Check if variable is unset or empty
[ -z "$VAR" ] && echo "VAR is not set"

# Check if variable is set (even if empty)
[ "${VAR+set}" = "set" ] && echo "VAR is defined"
```

### 3. Path Safety

Always quote variables containing paths:

```bash
# ✅ SAFE - Prevents word splitting and globbing
for file in "$DIRECTORY"/*.sh; do
    [ -r "$file" ] && . "$file"
done

# ❌ UNSAFE - Breaks with spaces or special characters
for file in $DIRECTORY/*.sh; do
    [ -r $file ] && . $file
done
```

---

## Shell Detection

### Interactive Shell Detection (POSIX)

```bash
case $- in
    *i*) INTERACTIVE=1 ;;
    *) INTERACTIVE= ;;
esac

if [ -n "$INTERACTIVE" ]; then
    # Interactive-only initialization
    load_aliases
    load_completions
fi
```

### Specific Shell Detection

```bash
# Detect bash
if [ -n "$BASH_VERSION" ]; then
    # Bash-specific code
fi

# Detect zsh
if [ -n "$ZSH_VERSION" ]; then
    # ZSH-specific code
fi

# Detect sh (POSIX)
if [ -z "$BASH_VERSION" ] && [ -z "$ZSH_VERSION" ]; then
    # Likely sh or dash
fi
```

---

## Real-World Examples

### Example 1: Safe File Sourcing

```bash
# From dotfiles/shell/profile
DOTFILES_DIR="${DOTFILES_DIR:-$HOME/Danti/dotfiles}"

for f in "$DOTFILES_DIR"/shell/exports.d/*.sh; do
    [ -r "$f" ] && . "$f"
done
```

**Defensive features:**
- Uses default value fallback
- Quotes path variable
- Checks readability
- Uses POSIX `.` instead of bash `source`

### Example 2: Conditional Initialization

```bash
# From dotfiles/shell/bashrc
if command -v direnv &>/dev/null; then
    eval "$(direnv hook bash)"
fi
```

**Defensive features:**
- Checks command exists before use
- Suppresses errors with `&>/dev/null`
- Won't break if direnv missing

### Example 3: Safe Variable Output

```bash
# ❌ UNSAFE - variable could contain anything
echo "Processing $filename..."

# ✅ SAFE - printf protects against special characters
printf 'Processing %s...\n' "$filename"
```

---

## Checklist

When writing portable shell scripts:

- [ ] Use `printf` instead of `echo -e` or `echo -n`
- [ ] Use `printf '%s\n'` for variables
- [ ] Check files exist before sourcing: `[ -f "$file" ] && . "$file"`
- [ ] Use `command -v` for command detection
- [ ] Quote all path variables: `"$VAR"`
- [ ] Use fallback defaults: `"${VAR:-default}"`
- [ ] Suppress expected errors: `command 2>/dev/null || true`
- [ ] Use POSIX `.` instead of `source` when targeting sh
- [ ] Set shebang appropriately: `#!/bin/sh` (POSIX) or `#!/usr/bin/env bash` (bash)

---

## References

- [POSIX Shell Specification](https://pubs.opengroup.org/onlinepubs/9699919799/utilities/V3_chap02.html)
- [ShellCheck - Shell Script Linter](https://www.shellcheck.net/)
- [Bash Guide for Beginners](https://tldp.org/LDP/Bash-Beginners-Guide/html/)
- [Google Shell Style Guide](https://google.github.io/styleguide/shellguide.html)
- [Chromium OS Shell Style Extensions](https://chromium.googlesource.com/chromiumos/docs/+/master/styleguide/shell.md)
