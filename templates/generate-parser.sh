#!/usr/bin/env bash
# templates/generate-parser.sh - Generate argument parser from Argbash template
#
# This script generates lib/args-parser.sh from templates/reset-args.m4
# using Argbash (https://argbash.io/)

set -euo pipefail

# Colors for output
CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Paths
TEMPLATE_FILE="$SCRIPT_DIR/reset-args.m4"
OUTPUT_FILE="$PROJECT_ROOT/lib/args-parser.sh"

echo -e "${CYAN}🔧 Argument Parser Generator${NC}"
echo ""

# Check if argbash is installed
if ! command -v argbash >/dev/null 2>&1; then
  echo -e "${RED}❌ Error: argbash is not installed${NC}"
  echo ""
  echo "Install argbash using one of the following methods:"
  echo ""
  echo "  1. Via Homebrew:"
  echo -e "     ${CYAN}brew install argbash${NC}"
  echo ""
  echo "  2. Install all project dependencies:"
  echo -e "     ${CYAN}brew bundle install${NC}"
  echo ""
  echo "  3. Via pip:"
  echo -e "     ${CYAN}pip install argbash${NC}"
  echo ""
  exit 1
fi

# Check if template exists
if [[ ! -f "$TEMPLATE_FILE" ]]; then
  echo -e "${RED}❌ Error: Template not found: $TEMPLATE_FILE${NC}"
  exit 1
fi

# Get argbash version
ARGBASH_VERSION=$(argbash --version 2>&1 | head -n 1 || echo "unknown")
echo -e "${CYAN}Using: $ARGBASH_VERSION${NC}"
echo ""

# Generate parser
echo -e "${CYAN}📝 Generating parser from template...${NC}"
echo "   Template: $TEMPLATE_FILE"
echo "   Output:   $OUTPUT_FILE"
echo ""

if argbash "$TEMPLATE_FILE" -o "$OUTPUT_FILE"; then
  echo -e "${GREEN}✅ Parser generated successfully${NC}"
  echo ""

  # Make executable
  chmod +x "$OUTPUT_FILE"
  echo -e "${GREEN}✅ Made parser executable${NC}"
  echo ""

  # Show file info
  LINES=$(wc -l < "$OUTPUT_FILE" | tr -d ' ')
  echo -e "${CYAN}Generated parser:${NC}"
  echo "   Lines: $LINES"
  echo "   Path:  $OUTPUT_FILE"
  echo ""

  # Validate syntax
  echo -e "${CYAN}🔍 Validating generated parser...${NC}"
  if bash -n "$OUTPUT_FILE"; then
    echo -e "${GREEN}✅ Syntax validation passed${NC}"
  else
    echo -e "${RED}❌ Syntax validation failed${NC}"
    exit 1
  fi
  echo ""

  # Test help output
  echo -e "${CYAN}📖 Testing help output...${NC}"
  if bash "$OUTPUT_FILE" --help >/dev/null 2>&1; then
    echo -e "${GREEN}✅ Help output works${NC}"
  else
    echo -e "${YELLOW}⚠️  Help output test failed (may need integration)${NC}"
  fi
  echo ""

  echo -e "${GREEN}🎉 Parser generation complete!${NC}"
  echo ""
  echo "Next steps:"
  echo "  1. Review the generated parser: less $OUTPUT_FILE"
  echo "  2. Integrate into main script: source lib/args-parser.sh"
  echo "  3. Test with various arguments"
  echo ""

else
  echo -e "${RED}❌ Failed to generate parser${NC}"
  echo ""
  echo "Troubleshooting:"
  echo "  1. Check template syntax in $TEMPLATE_FILE"
  echo "  2. Ensure all ARG_ directives are valid"
  echo "  3. Verify m4 macros are properly closed"
  echo "  4. See: https://argbash.readthedocs.io/"
  echo ""
  exit 1
fi
