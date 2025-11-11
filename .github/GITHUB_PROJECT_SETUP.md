# GitHub Project Setup

This directory contains templates and scripts for setting up GitHub project tracking for the Shell Scripting Modernization refactoring.

## Quick Start (Automated)

**Prerequisites:**
- `gh` CLI installed: `brew install gh`
- Authenticated: `gh auth login`

**Run:**
```bash
cd /path/to/file-assoc
chmod +x scripts/setup-github-project.sh
./scripts/setup-github-project.sh
```

This will automatically create:
- ✅ GitHub Project "Shell Scripting Modernization"
- ✅ Milestone "v2.0"
- ✅ Labels (refactoring, modernization, phase-1 through phase-9)
- ✅ 9 phase issues with full details
- ✅ Link all issues to the project

## Manual Setup (Alternative)

If you prefer to create issues manually or the automated script doesn't work, follow these steps:

### 1. Create Project

1. Go to https://github.com/orgs/austyle-io/projects
2. Click "New project"
3. Name: "Shell Scripting Modernization"
4. Description: "Refactor file-assoc to use modern shell scripting best practices (Gum, GNU Parallel, Argbash)"
5. Template: "Board"

### 2. Create Milestone

1. Go to https://github.com/austyle-io/file-assoc/milestones
2. Click "New milestone"
3. Title: "v2.0 - Shell Scripting Modernization"
4. Due date: 9 weeks from today
5. Description: "Complete refactoring to modern shell scripting practices"

### 3. Create Labels

Go to https://github.com/austyle-io/file-assoc/labels and create:

| Name | Color | Description |
|------|-------|-------------|
| refactoring | #0969DA | Code refactoring and restructuring |
| modernization | #1D76DB | Modernizing with new tools and practices |
| phase-1 | #FBCA04 | Phase 1: Foundation Setup |
| phase-2 | #FBCA04 | Phase 2: UI Module |
| phase-3 | #FBCA04 | Phase 3: Modular Extraction |
| phase-4 | #FBCA04 | Phase 4: Argument Parsing |
| phase-5 | #FBCA04 | Phase 5: GNU Parallel |
| phase-6 | #FBCA04 | Phase 6: Main Script Refactor |
| phase-7 | #FBCA04 | Phase 7: Configuration |
| phase-8 | #FBCA04 | Phase 8: Testing |
| phase-9 | #FBCA04 | Phase 9: Validation |
| testing | #0E8A16 | Testing related tasks |
| documentation | #0075CA | Documentation improvements |
| performance | #D93F0B | Performance optimization |

### 4. Create Issues

Use the templates below to create 9 issues (one for each phase).

---

## Issue Templates

### Phase 1: Foundation Setup

**Title:** `Phase 1: Foundation Setup`

**Labels:** `refactoring`, `modernization`, `phase-1`

**Milestone:** `v2.0`

**Body:**
```markdown
## Phase Overview

**Timeline:** Week 1
**Goal:** Create infrastructure without breaking existing functionality
**Risk:** Low

## Tasks

- [ ] Create lib/ directory structure
- [ ] Install dependencies (Gum, GNU Parallel, Argbash)
- [ ] Update Brewfile with new dependencies
- [ ] Create lib/core.sh with utilities
- [ ] Create tests/ directory structure
- [ ] Update documentation (ARCHITECTURE.md)

## Deliverables

- [ ] lib/ directory created
- [ ] Dependencies installed and documented
- [ ] Core utilities implemented and tested
- [ ] Test framework setup

## Progress

- [ ] Phase started
- [ ] All tasks completed
- [ ] Tests passing
- [ ] Code reviewed
- [ ] Documentation updated
- [ ] Phase complete

## Success Criteria

- [ ] All tests passing
- [ ] Shellcheck passing
- [ ] Documentation complete

## Dependencies

None (first phase)

## Related

- 📋 [Refactoring Plan](../blob/main/docs/REFACTORING_PLAN.md#phase-1-foundation-setup-week-1)
- 📚 [Modern Shell Toolkit](../blob/main/docs/MODERN_SHELL_SCRIPTING_TOOLKIT_FOR_PROFESSIONAL_CLI_APPLICATIONS.md)
```

---

### Phase 2: UI Module

**Title:** `Phase 2: UI Module with Gum`

**Labels:** `refactoring`, `modernization`, `phase-2`

**Milestone:** `v2.0`

**Body:**
```markdown
## Phase Overview

**Timeline:** Week 2
**Goal:** Replace custom UI code with Gum
**Risk:** Low

## Tasks

- [ ] Create lib/ui.sh with Gum wrappers
- [ ] Identify all UI callsites in main script
- [ ] Create mapping of old → new calls
- [ ] Implement backward-compatible UI functions
- [ ] Test UI components
- [ ] Update documentation

## Deliverables

- [ ] lib/ui.sh implemented
- [ ] All UI functions tested
- [ ] Documentation updated

## Progress

- [ ] Phase started
- [ ] All tasks completed
- [ ] Tests passing
- [ ] Code reviewed
- [ ] Documentation updated
- [ ] Phase complete

## Success Criteria

- [ ] Gum integrated successfully
- [ ] UI functions backward compatible
- [ ] All visual output consistent

## Dependencies

Phase 1 must be completed first

## Related

- 📋 [Refactoring Plan](../blob/main/docs/REFACTORING_PLAN.md#phase-2-ui-module-week-2)
- 📚 [Gum Documentation](https://github.com/charmbracelet/gum)
```

---

### Phase 3: Modular Extraction

**Title:** `Phase 3: Modular Extraction (Part 1)`

**Labels:** `refactoring`, `modernization`, `phase-3`

**Milestone:** `v2.0`

**Body:**
```markdown
## Phase Overview

**Timeline:** Week 3-4
**Goal:** Extract core functionality into modules
**Risk:** Medium

## Tasks

- [ ] Extract lib/logging.sh (simplify existing)
- [ ] Extract lib/files.sh (file operations)
- [ ] Extract lib/xattr.sh (core functionality)
- [ ] Extract lib/sampling.sh (sampling logic)
- [ ] Extract lib/metrics.sh (performance tracking)
- [ ] Create unit tests for each module
- [ ] Verify integration tests pass
- [ ] Remove duplicated code

## Deliverables

- [ ] All lib modules implemented
- [ ] Unit tests for all modules (>80% coverage)
- [ ] Main script sourcing modules
- [ ] Duplicate code removed

## Progress

- [ ] Phase started
- [ ] All tasks completed
- [ ] Tests passing
- [ ] Code reviewed
- [ ] Documentation updated
- [ ] Phase complete

## Success Criteria

- [ ] All modules have unit tests
- [ ] Integration tests passing
- [ ] No regression in functionality

## Dependencies

Phase 2 must be completed first

## Related

- 📋 [Refactoring Plan](../blob/main/docs/REFACTORING_PLAN.md#phase-3-modular-extraction-week-3-4)
```

---

### Phase 4: Argument Parsing

**Title:** `Phase 4: Argument Parsing with Argbash`

**Labels:** `refactoring`, `modernization`, `phase-4`

**Milestone:** `v2.0`

**Body:**
```markdown
## Phase Overview

**Timeline:** Week 5
**Goal:** Replace manual parsing with Argbash
**Risk:** Medium

## Tasks

- [ ] Create Argbash template (templates/reset-args.m4)
- [ ] Define all arguments and options
- [ ] Generate parser script
- [ ] Integrate into main script
- [ ] Update help documentation
- [ ] Test all argument combinations
- [ ] Remove old parsing code

## Deliverables

- [ ] Argbash template created
- [ ] Generated parser integrated
- [ ] All arguments working
- [ ] Help text comprehensive
- [ ] Old parsing code removed

## Progress

- [ ] Phase started
- [ ] All tasks completed
- [ ] Tests passing
- [ ] Code reviewed
- [ ] Documentation updated
- [ ] Phase complete

## Success Criteria

- [ ] All CLI arguments working
- [ ] Help text auto-generated
- [ ] Backward compatible

## Dependencies

Phase 3 must be completed first

## Related

- 📋 [Refactoring Plan](../blob/main/docs/REFACTORING_PLAN.md#phase-4-argument-parsing-week-5)
- 📚 [Argbash Documentation](https://argbash.dev/)
```

---

### Phase 5: GNU Parallel Integration

**Title:** `Phase 5: GNU Parallel Integration`

**Labels:** `refactoring`, `modernization`, `phase-5`, `performance`

**Milestone:** `v2.0`

**Body:**
```markdown
## Phase Overview

**Timeline:** Week 6
**Goal:** Replace manual xargs parallelization with GNU Parallel
**Risk:** Medium

## Tasks

- [ ] Create lib/parallel.sh module
- [ ] Refactor worker functions
- [ ] Replace xargs calls with GNU Parallel
- [ ] Update progress tracking
- [ ] Benchmark performance (before/after)
- [ ] Test edge cases (large directories, errors)
- [ ] Remove manual worker code

## Deliverables

- [ ] lib/parallel.sh implemented
- [ ] All parallel processing migrated
- [ ] Performance benchmarks documented
- [ ] Manual worker code removed

## Progress

- [ ] Phase started
- [ ] All tasks completed
- [ ] Tests passing
- [ ] Code reviewed
- [ ] Documentation updated
- [ ] Phase complete

## Success Criteria

- [ ] Same or better performance
- [ ] Simpler code (50%+ reduction)
- [ ] Better error handling

## Dependencies

Phase 4 must be completed first

## Related

- 📋 [Refactoring Plan](../blob/main/docs/REFACTORING_PLAN.md#phase-5-gnu-parallel-integration-week-6)
- 📚 [GNU Parallel Documentation](https://www.gnu.org/software/parallel/)
```

---

### Phase 6: Main Script Refactor

**Title:** `Phase 6: Main Script Refactor`

**Labels:** `refactoring`, `modernization`, `phase-6`

**Milestone:** `v2.0`

**Body:**
```markdown
## Phase Overview

**Timeline:** Week 7
**Goal:** Simplify main script to orchestrator role
**Risk:** High

## Tasks

- [ ] Remove all extracted code
- [ ] Source all modules
- [ ] Simplify main() function
- [ ] Reduce to orchestration logic only
- [ ] Comprehensive integration testing
- [ ] Target: Reduce from 1,905 lines → ~300 lines

## Deliverables

- [ ] Main script simplified
- [ ] All modules integrated
- [ ] Integration tests passing
- [ ] Performance maintained or improved

## Progress

- [ ] Phase started
- [ ] All tasks completed
- [ ] Tests passing
- [ ] Code reviewed
- [ ] Documentation updated
- [ ] Phase complete

## Success Criteria

- [ ] Main script < 350 lines
- [ ] All modules properly sourced
- [ ] No functionality regression

## Dependencies

Phase 5 must be completed first

## Related

- 📋 [Refactoring Plan](../blob/main/docs/REFACTORING_PLAN.md#phase-6-main-script-refactor-week-7)
```

---

### Phase 7: Configuration & Cleanup

**Title:** `Phase 7: Configuration & Cleanup`

**Labels:** `refactoring`, `modernization`, `phase-7`, `documentation`

**Milestone:** `v2.0`

**Body:**
```markdown
## Phase Overview

**Timeline:** Week 8
**Goal:** Add YAML config, finalize documentation
**Risk:** Low

## Tasks

- [ ] Create lib/config.sh module
- [ ] Create config/extensions.yaml
- [ ] Create config/config.yaml for settings
- [ ] Update documentation (README, ARCHITECTURE)
- [ ] Final cleanup and polish
- [ ] Performance optimization

## Deliverables

- [ ] YAML configuration working
- [ ] All documentation updated
- [ ] Code cleanup complete
- [ ] Performance optimized

## Progress

- [ ] Phase started
- [ ] All tasks completed
- [ ] Tests passing
- [ ] Code reviewed
- [ ] Documentation updated
- [ ] Phase complete

## Success Criteria

- [ ] YAML config functional
- [ ] Documentation complete
- [ ] Code clean and polished

## Dependencies

Phase 6 must be completed first

## Related

- 📋 [Refactoring Plan](../blob/main/docs/REFACTORING_PLAN.md#phase-7-configuration--cleanup-week-8)
```

---

### Phase 8: Testing & Validation

**Title:** `Phase 8: Testing & Validation`

**Labels:** `refactoring`, `modernization`, `phase-8`, `testing`

**Milestone:** `v2.0`

**Body:**
```markdown
## Phase Overview

**Timeline:** Week 9
**Goal:** Comprehensive testing and validation
**Risk:** Low

## Tasks

- [ ] Integration test suite
- [ ] Performance benchmarking
- [ ] Cross-platform testing (macOS)
- [ ] Edge case testing
- [ ] User acceptance testing
- [ ] Bug fixes

## Test Scenarios

- [ ] Empty directories
- [ ] Very large directories (100k+ files)
- [ ] Permission errors
- [ ] Interrupted execution
- [ ] Invalid arguments
- [ ] Network drives

## Deliverables

- [ ] All tests passing
- [ ] Performance validated
- [ ] Edge cases handled
- [ ] Documentation complete

## Progress

- [ ] Phase started
- [ ] All tasks completed
- [ ] Tests passing
- [ ] Code reviewed
- [ ] Documentation updated
- [ ] Phase complete

## Success Criteria

- [ ] Test coverage > 80%
- [ ] All edge cases handled
- [ ] Performance meets targets

## Dependencies

Phase 7 must be completed first

## Related

- 📋 [Refactoring Plan](../blob/main/docs/REFACTORING_PLAN.md#phase-8-testing--validation-week-9)
```

---

### Phase 9: Documentation & Release

**Title:** `Phase 9: Documentation & Release`

**Labels:** `refactoring`, `modernization`, `phase-9`, `documentation`

**Milestone:** `v2.0`

**Body:**
```markdown
## Phase Overview

**Timeline:** Week 9
**Goal:** Finalize documentation and prepare release
**Risk:** Low

## Tasks

- [ ] Complete ARCHITECTURE.md
- [ ] Complete DEVELOPMENT.md
- [ ] Update README with new features
- [ ] Create CHANGELOG for v2.0
- [ ] Create release notes
- [ ] Tag release v2.0.0

## Deliverables

- [ ] All documentation complete
- [ ] CHANGELOG updated
- [ ] Release notes ready
- [ ] Release tagged

## Progress

- [ ] Phase started
- [ ] All tasks completed
- [ ] Tests passing
- [ ] Code reviewed
- [ ] Documentation updated
- [ ] Phase complete

## Success Criteria

- [ ] Documentation comprehensive
- [ ] Release notes clear
- [ ] Version tagged correctly

## Dependencies

Phase 8 must be completed first

## Related

- 📋 [Refactoring Plan](../blob/main/docs/REFACTORING_PLAN.md#phase-9-documentation--release)
```

---

## Project Board Views

### Recommended Columns

1. **📋 Backlog** - Phases not yet started
2. **🚧 In Progress** - Currently working on
3. **👀 Review** - Awaiting code review
4. **✅ Done** - Completed phases

### Custom Fields

Add these custom fields to your project:

- **Phase** (Single select): Phase 1, Phase 2, ..., Phase 9
- **Risk** (Single select): Low, Medium, High
- **Timeline** (Text): Week 1, Week 2, etc.
- **Dependencies** (Text): Which phases must complete first

---

## Automation Ideas

### GitHub Actions

Consider adding workflow automations:

```yaml
# .github/workflows/phase-checks.yml
name: Phase Checks

on:
  pull_request:
    branches: [ main ]

jobs:
  phase-validation:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Run tests
        run: just test-unit
      - name: Check formatting
        run: just format-check
      - name: Lint
        run: just lint
```

---

## Tips

### Track Progress

```bash
# View all refactoring issues
gh issue list --label refactoring --state all

# View current phase
gh issue list --label "phase-1" --state open

# Update issue
gh issue edit <number> --add-label "in-progress"

# Close phase
gh issue close <number> --comment "Phase complete! ✨"
```

### Link PRs to Issues

When creating PRs, reference the phase issue:

```bash
gh pr create \
  --title "feat(lib): add core utilities module" \
  --body "Implements Phase 1, Task 4\n\nCloses #1"
```

### Project Views

Create filtered views in your project:

- **By Phase**: Group by Phase field
- **By Risk**: Group by Risk field
- **Timeline**: Sort by Timeline field
- **Active**: Filter to In Progress status

---

## Questions?

If you encounter issues with setup:

1. Check `gh` CLI version: `gh --version` (need v2.0+)
2. Verify authentication: `gh auth status`
3. Check repository access: `gh repo view austyle-io/file-assoc`
4. File an issue in the repo for help

---

**Last Updated:** 2025-11-11
**Maintained By:** Project Team
