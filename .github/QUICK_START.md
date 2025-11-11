# GitHub Project Quick Start

## 🚀 One-Command Setup

```bash
./scripts/setup-github-project.sh
```

This creates:
- ✅ GitHub Project with custom fields
- ✅ Milestone "v2.0" (9 weeks)
- ✅ 14 labels (refactoring, phases, etc.)
- ✅ 9 phase issues with full details

## 📦 Prerequisites

```bash
# Install gh CLI
brew install gh

# Authenticate
gh auth login

# Verify
gh auth status
```

## 📋 What Gets Created

### Project: "Shell Scripting Modernization"

**URL:** https://github.com/orgs/austyle-io/projects

**Fields:**
- Phase (1-9)
- Risk (Low/Medium/High)
- Timeline (Week X)
- Status (Backlog/In Progress/Review/Done)

### Issues (9 total)

| Issue | Title | Labels | Risk |
|-------|-------|--------|------|
| #1 | Phase 1: Foundation Setup | refactoring, phase-1 | Low |
| #2 | Phase 2: UI Module | refactoring, phase-2 | Low |
| #3 | Phase 3: Modular Extraction | refactoring, phase-3 | Medium |
| #4 | Phase 4: Argument Parsing | refactoring, phase-4 | Medium |
| #5 | Phase 5: GNU Parallel | refactoring, phase-5 | Medium |
| #6 | Phase 6: Main Script Refactor | refactoring, phase-6 | High |
| #7 | Phase 7: Configuration | refactoring, phase-7 | Low |
| #8 | Phase 8: Testing | refactoring, phase-8 | Low |
| #9 | Phase 9: Documentation | refactoring, phase-9 | Low |

### Labels (14 total)

- `refactoring` - Main refactoring work
- `modernization` - Modernizing practices
- `phase-1` through `phase-9` - Phase tracking
- `testing`, `documentation`, `performance` - Categories

## 🎯 Quick Commands

```bash
# View all issues
gh issue list --label refactoring

# View project
gh project list --owner austyle-io

# Start Phase 1
gh issue view 1
gh issue edit 1 --add-label "in-progress"

# Track progress
gh issue list --label "phase-1" --state open

# Close phase
gh issue close 1 --comment "Phase 1 complete! ✨"
```

## 🔄 Workflow

1. **Start Phase**
   ```bash
   gh issue edit <number> --add-label "in-progress"
   ```

2. **Create Feature Branch**
   ```bash
   git checkout -b phase-1/foundation-setup
   ```

3. **Make Changes**
   ```bash
   # Work on tasks...
   git commit -m "feat(lib): add core utilities"
   ```

4. **Create PR**
   ```bash
   gh pr create --title "Phase 1: Foundation Setup" \
     --body "Implements Phase 1\n\nCloses #1"
   ```

5. **Complete Phase**
   ```bash
   # PR merged
   gh issue close 1 --comment "Complete! Moving to Phase 2"
   ```

## 📊 Project Views

### Recommended Board Columns

1. **📋 Backlog** - Not started
2. **🚧 In Progress** - Active work
3. **👀 In Review** - PR submitted
4. **✅ Done** - Completed

### Filters

- **Current Sprint**: `is:open label:phase-1`
- **High Risk**: `is:open Risk:High`
- **Testing**: `is:open label:testing`
- **All Phases**: `label:refactoring`

## 🐛 Troubleshooting

### Script Fails

```bash
# Check gh CLI
gh --version  # Need v2.0+

# Check auth
gh auth status
gh auth login  # Re-authenticate

# Check permissions
gh repo view austyle-io/file-assoc
```

### Manual Setup

If automated setup fails, see:
- [.github/GITHUB_PROJECT_SETUP.md](.github/GITHUB_PROJECT_SETUP.md)

Contains full manual instructions for creating:
- Project
- Milestone
- Labels
- Issues

## 📚 Related Docs

- [Refactoring Plan](../docs/REFACTORING_PLAN.md) - Full technical plan
- [Modern Shell Toolkit](../docs/MODERN_SHELL_SCRIPTING_TOOLKIT_FOR_PROFESSIONAL_CLI_APPLICATIONS.md) - Best practices
- [Project Setup](GITHUB_PROJECT_SETUP.md) - Detailed setup guide

## ✨ Next Steps

After setup:

1. ✅ Review Phase 1 issue
2. ✅ Install dependencies (Gum, GNU Parallel, Argbash)
3. ✅ Create feature branch
4. ✅ Start coding!

---

**Questions?** Open an issue or check the main docs.
