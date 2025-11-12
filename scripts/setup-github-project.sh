#!/usr/bin/env bash
# Setup GitHub Project and Issues for Refactoring Plan
#
# This script creates a GitHub project and all phase issues for tracking
# the shell scripting modernization refactoring.
#
# Prerequisites:
#   - gh CLI installed and authenticated
#   - Run from repository root
#
# Usage:
#   ./scripts/setup-github-project.sh

set -euo pipefail

# Colors
CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Configuration
REPO="austyle-io/file-assoc"
PROJECT_NAME="Shell Scripting Modernization"
PROJECT_DESC="Refactor file-assoc to use modern shell scripting best practices (Gum, GNU Parallel, Argbash)"

# Check prerequisites
check_prerequisites() {
  echo -e "${CYAN}Checking prerequisites...${NC}"

  if ! command -v gh &> /dev/null; then
    echo -e "${RED}Error: gh CLI not found. Install with: brew install gh${NC}"
    exit 1
  fi

  if ! gh auth status &> /dev/null; then
    echo -e "${RED}Error: gh CLI not authenticated. Run: gh auth login${NC}"
    exit 1
  fi

  echo -e "${GREEN}✓ Prerequisites met${NC}"
}

# Create GitHub Project
create_project() {
  echo -e "\n${CYAN}Creating GitHub Project: ${PROJECT_NAME}${NC}"

  # Create project (v2 - new projects)
  local project_id
  project_id=$(gh project create \
    --owner austyle-io \
    --title "$PROJECT_NAME" \
    --body "$PROJECT_DESC" \
    --format json | jq -r '.id')

  if [[ -z "$project_id" ]]; then
    echo -e "${RED}Failed to create project${NC}"
    exit 1
  fi

  echo -e "${GREEN}✓ Project created: $project_id${NC}"
  echo "$project_id" > .github/PROJECT_ID

  # Add custom fields
  echo -e "${CYAN}Adding custom fields...${NC}"

  # Phase field (single select)
  gh project field-create "$project_id" \
    --owner austyle-io \
    --data-type SINGLE_SELECT \
    --name "Phase" \
    --single-select-options "Phase 1,Phase 2,Phase 3,Phase 4,Phase 5,Phase 6,Phase 7,Phase 8,Phase 9"

  # Risk field (single select)
  gh project field-create "$project_id" \
    --owner austyle-io \
    --data-type SINGLE_SELECT \
    --name "Risk" \
    --single-select-options "Low,Medium,High"

  # Timeline field (text)
  gh project field-create "$project_id" \
    --owner austyle-io \
    --data-type TEXT \
    --name "Timeline"

  echo -e "${GREEN}✓ Custom fields added${NC}"
}

# Create labels
create_labels() {
  echo -e "\n${CYAN}Creating labels...${NC}"

  local labels=(
    "refactoring:0969DA:Code refactoring and restructuring"
    "modernization:1D76DB:Modernizing with new tools and practices"
    "phase-1:FBCA04:Phase 1: Foundation Setup"
    "phase-2:FBCA04:Phase 2: UI Module"
    "phase-3:FBCA04:Phase 3: Modular Extraction"
    "phase-4:FBCA04:Phase 4: Argument Parsing"
    "phase-5:FBCA04:Phase 5: GNU Parallel"
    "phase-6:FBCA04:Phase 6: Main Script Refactor"
    "phase-7:FBCA04:Phase 7: Configuration"
    "phase-8:FBCA04:Phase 8: Testing"
    "phase-9:FBCA04:Phase 9: Validation"
    "testing:0E8A16:Testing related tasks"
    "documentation:0075CA:Documentation improvements"
    "performance:D93F0B:Performance optimization"
  )

  for label_spec in "${labels[@]}"; do
    IFS=':' read -r name color desc <<< "$label_spec"

    # Check if label exists
    if gh label list --repo "$REPO" | grep -q "^$name"; then
      echo -e "  ${YELLOW}Label '$name' already exists, skipping${NC}"
    else
      gh label create "$name" \
        --repo "$REPO" \
        --color "$color" \
        --description "$desc"
      echo -e "  ${GREEN}✓ Created label: $name${NC}"
    fi
  done
}

# Create issue for a phase
create_phase_issue() {
  local phase=$1
  local title=$2
  local timeline=$3
  local goal=$4
  local risk=$5
  shift 5
  local tasks=("$@")

  echo -e "\n${CYAN}Creating issue: Phase $phase: $title${NC}"

  # Build task list
  local task_list=""
  for task in "${tasks[@]}"; do
    task_list+="- [ ] $task"$'\n'
  done

  # Create issue body
  local body
  body=$(cat <<EOF
## Phase Overview

**Timeline:** $timeline
**Goal:** $goal
**Risk:** $risk

## Tasks

$task_list

## Deliverables

See [docs/REFACTORING_PLAN.md](../blob/main/docs/REFACTORING_PLAN.md#phase-$phase) for detailed deliverables.

## Progress

- [ ] Phase started
- [ ] All tasks completed
- [ ] Tests passing
- [ ] Code reviewed
- [ ] Documentation updated
- [ ] Phase complete

## Related

- 📋 [Refactoring Plan](../blob/main/docs/REFACTORING_PLAN.md)
- 📚 [Modern Shell Toolkit](../blob/main/docs/MODERN_SHELL_SCRIPTING_TOOLKIT_FOR_PROFESSIONAL_CLI_APPLICATIONS.md)

---

**Part of:** Shell Scripting Modernization Project
**Dependencies:** $([ "$phase" -gt 1 ] && echo "Phase $((phase - 1)) must be completed first" || echo "None (first phase)")
EOF
)

  # Create issue
  local issue_number
  issue_number=$(gh issue create \
    --repo "$REPO" \
    --title "Phase $phase: $title" \
    --body "$body" \
    --label "refactoring,modernization,phase-$phase" \
    --assignee "@me" \
    --milestone "v2.0" \
    | grep -oE '[0-9]+$')

  echo -e "${GREEN}✓ Created issue #$issue_number${NC}"

  # Add to project (if PROJECT_ID exists)
  if [[ -f .github/PROJECT_ID ]]; then
    local project_id
    project_id=$(cat .github/PROJECT_ID)
    gh project item-add "$project_id" --owner austyle-io --url "https://github.com/$REPO/issues/$issue_number"
    echo -e "${GREEN}✓ Added to project${NC}"
  fi
}

# Create all phase issues
create_all_issues() {
  echo -e "\n${CYAN}Creating phase issues...${NC}"

  # Phase 1: Foundation Setup
  create_phase_issue 1 \
    "Foundation Setup" \
    "Week 1" \
    "Create infrastructure without breaking existing functionality" \
    "Low" \
    "Create lib/ directory structure" \
    "Install dependencies (Gum, GNU Parallel, Argbash)" \
    "Update Brewfile with new dependencies" \
    "Create lib/core.sh with utilities" \
    "Create tests/ directory structure" \
    "Update documentation (ARCHITECTURE.md)"

  # Phase 2: UI Module
  create_phase_issue 2 \
    "UI Module with Gum" \
    "Week 2" \
    "Replace custom UI code with Gum" \
    "Low" \
    "Create lib/ui.sh with Gum wrappers" \
    "Identify all UI callsites in main script" \
    "Create mapping of old → new calls" \
    "Implement backward-compatible UI functions" \
    "Test UI components" \
    "Update documentation"

  # Phase 3: Modular Extraction
  create_phase_issue 3 \
    "Modular Extraction (Part 1)" \
    "Week 3-4" \
    "Extract core functionality into modules" \
    "Medium" \
    "Extract lib/logging.sh (simplify existing)" \
    "Extract lib/files.sh (file operations)" \
    "Extract lib/xattr.sh (core functionality)" \
    "Extract lib/sampling.sh (sampling logic)" \
    "Extract lib/metrics.sh (performance tracking)" \
    "Create unit tests for each module" \
    "Verify integration tests pass" \
    "Remove duplicated code"

  # Phase 4: Argument Parsing
  create_phase_issue 4 \
    "Argument Parsing with Argbash" \
    "Week 5" \
    "Replace manual parsing with Argbash" \
    "Medium" \
    "Create Argbash template (templates/reset-args.m4)" \
    "Define all arguments and options" \
    "Generate parser script" \
    "Integrate into main script" \
    "Update help documentation" \
    "Test all argument combinations" \
    "Remove old parsing code"

  # Phase 5: GNU Parallel Integration
  create_phase_issue 5 \
    "GNU Parallel Integration" \
    "Week 6" \
    "Replace manual xargs parallelization with GNU Parallel" \
    "Medium" \
    "Create lib/parallel.sh module" \
    "Refactor worker functions" \
    "Replace xargs calls with GNU Parallel" \
    "Update progress tracking" \
    "Benchmark performance (before/after)" \
    "Test edge cases (large directories, errors)" \
    "Remove manual worker code"

  # Phase 6: Main Script Refactor
  create_phase_issue 6 \
    "Main Script Refactor" \
    "Week 7" \
    "Simplify main script to orchestrator role" \
    "High" \
    "Remove all extracted code" \
    "Source all modules" \
    "Simplify main() function" \
    "Reduce to orchestration logic only" \
    "Comprehensive integration testing" \
    "Target: Reduce from 1,905 lines → ~300 lines"

  # Phase 7: Configuration & Cleanup
  create_phase_issue 7 \
    "Configuration & Cleanup" \
    "Week 8" \
    "Add YAML config, finalize documentation" \
    "Low" \
    "Create lib/config.sh module" \
    "Create config/extensions.yaml" \
    "Create config/config.yaml for settings" \
    "Update documentation (README, ARCHITECTURE)" \
    "Final cleanup and polish" \
    "Performance optimization"

  # Phase 8: Testing & Validation
  create_phase_issue 8 \
    "Testing & Validation" \
    "Week 9" \
    "Comprehensive testing and validation" \
    "Low" \
    "Integration test suite" \
    "Performance benchmarking" \
    "Cross-platform testing (macOS)" \
    "Edge case testing" \
    "User acceptance testing" \
    "Bug fixes"

  # Phase 9: Documentation & Release
  create_phase_issue 9 \
    "Documentation & Release" \
    "Week 9" \
    "Finalize documentation and prepare release" \
    "Low" \
    "Complete ARCHITECTURE.md" \
    "Complete DEVELOPMENT.md" \
    "Update README with new features" \
    "Create CHANGELOG for v2.0" \
    "Create release notes" \
    "Tag release v2.0.0"
}

# Create milestone
create_milestone() {
  echo -e "\n${CYAN}Creating milestone: v2.0${NC}"

  # Check if milestone exists
  if gh milestone list --repo "$REPO" | grep -q "v2.0"; then
    echo -e "${YELLOW}Milestone 'v2.0' already exists, skipping${NC}"
  else
    gh milestone create "v2.0" \
      --repo "$REPO" \
      --title "v2.0 - Shell Scripting Modernization" \
      --description "Complete refactoring to modern shell scripting practices" \
      --due-date "$(date -v+9w +%Y-%m-%d 2>/dev/null || date -d '+9 weeks' +%Y-%m-%d)"

    echo -e "${GREEN}✓ Milestone created${NC}"
  fi
}

# Main execution
main() {
  echo -e "${CYAN}╔════════════════════════════════════════════════════╗${NC}"
  echo -e "${CYAN}║  GitHub Project Setup: Shell Scripting Modernization  ║${NC}"
  echo -e "${CYAN}╚════════════════════════════════════════════════════╝${NC}"

  check_prerequisites
  create_milestone
  create_labels
  create_project
  create_all_issues

  echo -e "\n${GREEN}╔════════════════════════════════════════════════════╗${NC}"
  echo -e "${GREEN}║              ✓ Setup Complete!                     ║${NC}"
  echo -e "${GREEN}╚════════════════════════════════════════════════════╝${NC}"
  echo -e "\n${CYAN}Next steps:${NC}"
  echo -e "  1. View project: ${YELLOW}gh project view --owner austyle-io${NC}"
  echo -e "  2. View issues: ${YELLOW}gh issue list --label refactoring${NC}"
  echo -e "  3. Start Phase 1: ${YELLOW}gh issue view 1${NC}"
  echo -e "\n${CYAN}Project URL:${NC} https://github.com/orgs/austyle-io/projects"
  echo -e "${CYAN}Issues URL:${NC} https://github.com/$REPO/issues?q=is:issue+label:refactoring"
}

main "$@"
