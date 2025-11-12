#!/usr/bin/env bash
# .devcontainer/validate.sh - Validate devcontainer configuration without building
# This script can run in environments without Docker

set -euo pipefail

# Colors
CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

ERRORS=0
WARNINGS=0

echo -e "${CYAN}🔍 Validating devcontainer configuration...${NC}"
echo ""

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Test 1: Check required files exist
echo -e "${CYAN}Test 1: Required files${NC}"
REQUIRED_FILES=(
    ".devcontainer/Dockerfile"
    ".devcontainer/devcontainer.json"
    ".devcontainer/README.md"
    ".devcontainer/build-and-test.sh"
    "Brewfile.linux"
    ".dockerignore"
)

for file in "${REQUIRED_FILES[@]}"; do
    if [[ -f "$PROJECT_ROOT/$file" ]]; then
        echo -e "  ${GREEN}✓${NC} $file"
    else
        echo -e "  ${RED}✗${NC} $file (missing)"
        ERRORS=$((ERRORS + 1))
    fi
done
echo ""

# Test 2: Validate devcontainer.json syntax (JSONC format)
echo -e "${CYAN}Test 2: devcontainer.json syntax${NC}"
# devcontainer.json uses JSONC (JSON with Comments), so we need to strip comments
if command -v python3 >/dev/null 2>&1; then
    # Use Python to strip JSONC comments and validate JSON
    # We use /tmp/test_validate.py which we know works reliably
    cat > /tmp/validate_devcontainer.py <<'PYEOF'
import re, json, sys
try:
    with open(sys.argv[1], 'r') as f:
        content = f.read()
    # Remove single-line comments
    content = re.sub(r'//.*', '', content)
    # Remove multi-line comments
    content = re.sub(r'/\*.*?\*/', '', content, flags=re.DOTALL)
    # Remove trailing commas (JSONC allows them)
    content = re.sub(r',(\s*[}\]])', r'\1', content)
    json.loads(content)
    sys.exit(0)
except Exception:
    sys.exit(1)
PYEOF

    if python3 /tmp/validate_devcontainer.py "$SCRIPT_DIR/devcontainer.json" 2>/dev/null; then
        echo -e "  ${GREEN}✓${NC} Valid JSONC syntax"
    else
        echo -e "  ${RED}✗${NC} Invalid JSONC syntax"
        ERRORS=$((ERRORS + 1))
    fi
    rm -f /tmp/validate_devcontainer.py
else
    echo -e "  ${YELLOW}⚠${NC} python3 not available, skipping JSON validation"
    WARNINGS=$((WARNINGS + 1))
fi
echo ""

# Test 3: Check Dockerfile syntax
echo -e "${CYAN}Test 3: Dockerfile syntax${NC}"
if grep -q "^FROM " "$SCRIPT_DIR/Dockerfile"; then
    echo -e "  ${GREEN}✓${NC} Has FROM instruction"
else
    echo -e "  ${RED}✗${NC} Missing FROM instruction"
    ERRORS=$((ERRORS + 1))
fi

if grep -q "WORKDIR" "$SCRIPT_DIR/Dockerfile"; then
    echo -e "  ${GREEN}✓${NC} Has WORKDIR instruction"
else
    echo -e "  ${YELLOW}⚠${NC} No WORKDIR instruction"
    WARNINGS=$((WARNINGS + 1))
fi

# Check for common Dockerfile issues
if grep -q "apt-get update.*&&.*apt-get install" "$SCRIPT_DIR/Dockerfile"; then
    echo -e "  ${GREEN}✓${NC} apt-get commands properly chained"
else
    echo -e "  ${YELLOW}⚠${NC} apt-get commands might not be optimized"
    WARNINGS=$((WARNINGS + 1))
fi
echo ""  # Blank line

# Debug: Check if we reach here

# Test 4: Validate Brewfile.linux
echo -e "${CYAN}Test 4: Brewfile.linux${NC}"
if [[ -f "$PROJECT_ROOT/Brewfile.linux" ]]; then
    # Check for key packages
    KEY_PACKAGES=("argbash" "just" "shellcheck" "gum")
    for pkg in "${KEY_PACKAGES[@]}"; do
        if grep -q "brew \"$pkg\"" "$PROJECT_ROOT/Brewfile.linux"; then
            echo -e "  ${GREEN}✓${NC} $pkg defined"
        else
            echo -e "  ${RED}✗${NC} $pkg missing"
            ERRORS=$((ERRORS + 1))
        fi
    done
else
    echo -e "  ${RED}✗${NC} Brewfile.linux not found"
    ERRORS=$((ERRORS + 1))
fi
echo ""

# Test 5: Check devcontainer features
echo -e "${CYAN}Test 5: devcontainer.json configuration${NC}"
# Use grep for basic checks since JSONC isn't easily parsed with jq
if grep -q '"dockerfile"' "$SCRIPT_DIR/devcontainer.json"; then
    echo -e "  ${GREEN}✓${NC} Dockerfile reference configured"
else
    echo -e "  ${RED}✗${NC} No Dockerfile reference"
    ERRORS=$((ERRORS + 1))
fi

if grep -q '"remoteUser"' "$SCRIPT_DIR/devcontainer.json"; then
    USER=$(grep '"remoteUser"' "$SCRIPT_DIR/devcontainer.json" | sed 's/.*"remoteUser".*:.*"\([^"]*\)".*/\1/')
    echo -e "  ${GREEN}✓${NC} Remote user: $USER"
else
    echo -e "  ${YELLOW}⚠${NC} No remote user specified"
    WARNINGS=$((WARNINGS + 1))
fi

if grep -q '"extensions"' "$SCRIPT_DIR/devcontainer.json"; then
    echo -e "  ${GREEN}✓${NC} VS Code extensions configured"
else
    echo -e "  ${YELLOW}⚠${NC} No VS Code extensions configured"
    WARNINGS=$((WARNINGS + 1))
fi
echo ""

# Test 6: Check Python versions in Dockerfile
echo -e "${CYAN}Test 6: Python configuration${NC}"
for version in "3.11" "3.12" "3.13"; do
    if grep -q "python$version" "$SCRIPT_DIR/Dockerfile"; then
        echo -e "  ${GREEN}✓${NC} Python $version configured"
    else
        echo -e "  ${YELLOW}⚠${NC} Python $version not found"
        WARNINGS=$((WARNINGS + 1))
    fi
done
echo ""

# Test 7: Check for uv installation
echo -e "${CYAN}Test 7: uv installation${NC}"
if grep -q "ghcr.io/astral-sh/uv" "$SCRIPT_DIR/Dockerfile"; then
    echo -e "  ${GREEN}✓${NC} uv installed from official image"
elif grep -q "curl.*astral.sh/uv/install.sh" "$SCRIPT_DIR/Dockerfile"; then
    echo -e "  ${GREEN}✓${NC} uv installed via install script"
else
    echo -e "  ${RED}✗${NC} uv installation not found"
    ERRORS=$((ERRORS + 1))
fi
echo ""

# Test 8: Check for Homebrew installation
echo -e "${CYAN}Test 8: Homebrew installation${NC}"
if grep -qE "(brew\.sh/install|Homebrew/install)" "$SCRIPT_DIR/Dockerfile"; then
    echo -e "  ${GREEN}✓${NC} Homebrew installation script found"
else
    echo -e "  ${RED}✗${NC} Homebrew installation not found"
    ERRORS=$((ERRORS + 1))
fi

if grep -q "linuxbrew" "$SCRIPT_DIR/Dockerfile"; then
    echo -e "  ${GREEN}✓${NC} linuxbrew user configured"
else
    echo -e "  ${YELLOW}⚠${NC} No linuxbrew user (may cause permission issues)"
    WARNINGS=$((WARNINGS + 1))
fi
echo ""

# Test 9: Check lifecycle hooks
echo -e "${CYAN}Test 9: Lifecycle hooks${NC}"
for hook in "onCreateCommand" "postCreateCommand" "postStartCommand"; do
    if grep -q "\"$hook\"" "$SCRIPT_DIR/devcontainer.json"; then
        echo -e "  ${GREEN}✓${NC} $hook configured"
    else
        echo -e "  ${YELLOW}⚠${NC} $hook not configured"
        WARNINGS=$((WARNINGS + 1))
    fi
done
echo ""

# Test 10: Documentation completeness
echo -e "${CYAN}Test 10: Documentation${NC}"
README="$SCRIPT_DIR/README.md"
REQUIRED_SECTIONS=(
    "Features"
    "Usage"
    "Quick Start"
    "Troubleshooting"
)

for section in "${REQUIRED_SECTIONS[@]}"; do
    if grep -qi "$section" "$README" 2>/dev/null; then
        echo -e "  ${GREEN}✓${NC} $section section present"
    else
        echo -e "  ${YELLOW}⚠${NC} $section section missing"
        WARNINGS=$((WARNINGS + 1))
    fi
done
echo ""

# Summary
echo -e "${CYAN}═══════════════════════════════════════════${NC}"
echo -e "${CYAN}Validation Summary${NC}"
echo -e "${CYAN}═══════════════════════════════════════════${NC}"

if [[ $ERRORS -eq 0 ]] && [[ $WARNINGS -eq 0 ]]; then
    echo -e "${GREEN}✅ All checks passed!${NC}"
    echo ""
    echo "Next steps:"
    echo "  1. Build locally: .devcontainer/build-and-test.sh"
    echo "  2. Test in VS Code: Reopen in Container"
    echo "  3. Push to GHCR: Use GitHub Actions workflow"
    exit 0
elif [[ $ERRORS -eq 0 ]]; then
    echo -e "${YELLOW}⚠️  Validation passed with $WARNINGS warning(s)${NC}"
    echo ""
    echo "The configuration should work, but review warnings above."
    echo ""
    echo "Next steps:"
    echo "  1. Build locally: .devcontainer/build-and-test.sh"
    echo "  2. Test in VS Code: Reopen in Container"
    exit 0
else
    echo -e "${RED}❌ Validation failed with $ERRORS error(s) and $WARNINGS warning(s)${NC}"
    echo ""
    echo "Fix the errors above before building the container."
    exit 1
fi
