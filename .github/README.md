# GitHub Project Files

This directory contains GitHub-specific configuration and documentation.

## Files

### Setup & Documentation

- **[QUICK_START.md](QUICK_START.md)** - Quick reference for setting up the GitHub project
- **[GITHUB_PROJECT_SETUP.md](GITHUB_PROJECT_SETUP.md)** - Detailed setup guide (automated & manual)
- **[../scripts/setup-github-project.sh](../scripts/setup-github-project.sh)** - Automated setup script

### Templates

- **[ISSUE_TEMPLATE/refactoring-phase.md](ISSUE_TEMPLATE/refactoring-phase.md)** - Template for phase issues

## Quick Start

### Automated Setup (Recommended)

```bash
# Install gh CLI
brew install gh

# Authenticate
gh auth login

# Run setup
just setup-github-project
# or
./scripts/setup-github-project.sh
```

### What Gets Created

- ✅ **GitHub Project**: "Shell Scripting Modernization"
- ✅ **Milestone**: v2.0 (9 weeks)
- ✅ **Labels**: 14 labels for organization
- ✅ **Issues**: 9 phase issues with full details

### Manual Setup

If automation fails, follow the detailed instructions in [GITHUB_PROJECT_SETUP.md](GITHUB_PROJECT_SETUP.md).

## Project Tracking

### View Progress

```bash
# List all refactoring issues
gh issue list --label refactoring

# View specific phase
gh issue view 1

# Check project status
gh project list --owner austyle-io
```

### Update Issues

```bash
# Mark phase as in progress
gh issue edit 1 --add-label "in-progress"

# Close completed phase
gh issue close 1 --comment "Phase complete! ✨"
```

## Phases Overview

| Phase | Title | Timeline | Risk |
|-------|-------|----------|------|
| 1 | Foundation Setup | Week 1 | Low |
| 2 | UI Module | Week 2 | Low |
| 3 | Modular Extraction | Week 3-4 | Medium |
| 4 | Argument Parsing | Week 5 | Medium |
| 5 | GNU Parallel | Week 6 | Medium |
| 6 | Main Script Refactor | Week 7 | High |
| 7 | Configuration | Week 8 | Low |
| 8 | Testing | Week 9 | Low |
| 9 | Documentation | Week 9 | Low |

## Related Documentation

- [Refactoring Plan](../docs/REFACTORING_PLAN.md) - Complete technical plan
- [Modern Shell Toolkit](../docs/MODERN_SHELL_SCRIPTING_TOOLKIT_FOR_PROFESSIONAL_CLI_APPLICATIONS.md) - Best practices guide

## Support

For questions or issues with the GitHub project setup:

1. Check [GITHUB_PROJECT_SETUP.md](GITHUB_PROJECT_SETUP.md) troubleshooting section
2. Verify `gh` CLI: `gh --version` (need v2.0+)
3. Check authentication: `gh auth status`
4. File an issue in the repository
