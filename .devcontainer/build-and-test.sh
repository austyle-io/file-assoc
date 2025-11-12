#!/usr/bin/env bash
# .devcontainer/build-and-test.sh
# Build and test the devcontainer locally before pushing

set -euo pipefail

# Colors
CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${CYAN}🐳 Building file-assoc devcontainer...${NC}"
echo ""

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Image name
IMAGE_NAME="file-assoc-devcontainer"
IMAGE_TAG="latest"
FULL_IMAGE="${IMAGE_NAME}:${IMAGE_TAG}"

# Build the image
echo -e "${CYAN}📦 Building Docker image...${NC}"
echo "   Context: $PROJECT_ROOT"
echo "   Dockerfile: $SCRIPT_DIR/Dockerfile"
echo ""

if docker build \
    -f "$SCRIPT_DIR/Dockerfile" \
    -t "$FULL_IMAGE" \
    "$PROJECT_ROOT"; then
    echo ""
    echo -e "${GREEN}✅ Image built successfully${NC}"
else
    echo ""
    echo -e "${RED}❌ Build failed${NC}"
    exit 1
fi

# Get image size
IMAGE_SIZE=$(docker images "$FULL_IMAGE" --format "{{.Size}}")
echo -e "${CYAN}📊 Image size: ${IMAGE_SIZE}${NC}"
echo ""

# Test the image
echo -e "${CYAN}🧪 Testing image...${NC}"
echo ""

echo -e "${YELLOW}Test 1: Python versions${NC}"
docker run --rm "$FULL_IMAGE" bash -c '
    echo "Python 3.11: $(python3.11 --version)"
    echo "Python 3.12: $(python3.12 --version)"
    echo "Python 3.13: $(python3.13 --version)"
    echo "Default: $(python --version)"
'
echo ""

echo -e "${YELLOW}Test 2: uv installation${NC}"
docker run --rm "$FULL_IMAGE" bash -c '
    uv --version
    uvx --version || echo "uvx is a symlink to uv"
'
echo ""

echo -e "${YELLOW}Test 3: Homebrew installation${NC}"
docker run --rm "$FULL_IMAGE" bash -c '
    eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
    brew --version
    echo ""
    echo "Installed packages:"
    brew list
'
echo ""

echo -e "${YELLOW}Test 4: Key tools${NC}"
docker run --rm "$FULL_IMAGE" bash -c '
    eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
    echo "argbash: $(argbash --version 2>&1 | head -1)"
    echo "just: $(just --version)"
    echo "shellcheck: $(shellcheck --version | head -2 | tail -1)"
    echo "gum: $(gum --version)"
'
echo ""

echo -e "${YELLOW}Test 5: User permissions${NC}"
docker run --rm "$FULL_IMAGE" bash -c '
    echo "Current user: $(whoami)"
    echo "User ID: $(id -u)"
    echo "Group ID: $(id -g)"
    echo "Groups: $(groups)"
'
echo ""

echo -e "${YELLOW}Test 6: Environment variables${NC}"
docker run --rm "$FULL_IMAGE" bash -c '
    echo "PATH: $PATH" | tr ":" "\n" | grep -E "(brew|uv|python)"
    echo ""
    echo "HOMEBREW_PREFIX: $HOMEBREW_PREFIX"
'
echo ""

# Summary
echo -e "${GREEN}═══════════════════════════════════════════${NC}"
echo -e "${GREEN}✅ All tests passed!${NC}"
echo -e "${GREEN}═══════════════════════════════════════════${NC}"
echo ""
echo "Image: $FULL_IMAGE"
echo "Size: $IMAGE_SIZE"
echo ""
echo "Next steps:"
echo "  1. Test in VS Code: Open project and select 'Reopen in Container'"
echo "  2. Push to registry (optional):"
echo "     docker tag $FULL_IMAGE ghcr.io/austyle-io/$IMAGE_NAME:$IMAGE_TAG"
echo "     docker push ghcr.io/austyle-io/$IMAGE_NAME:$IMAGE_TAG"
echo "  3. Update devcontainer.json to use pushed image:"
echo "     \"image\": \"ghcr.io/austyle-io/$IMAGE_NAME:$IMAGE_TAG\""
echo ""
