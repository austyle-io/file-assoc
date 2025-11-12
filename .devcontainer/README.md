# Development Container Configuration

This directory contains the development container (devcontainer) configuration for the file-assoc project. The devcontainer provides a consistent, reproducible development environment with all necessary tools pre-installed.

## Features

### 🐍 Python Environment
- **Python 3.11, 3.12, 3.13** pre-installed
- **Python 3.12** set as default (most stable for modern development)
- **uv/uvx** - Ultra-fast Python package manager (10-100x faster than pip)
  - Replaces pip, poetry, pyenv, virtualenv, and more
  - Installed from official Astral image

### 🍺 Homebrew (Linuxbrew)
- **Homebrew** installed and configured for Linux
- Package management via Brewfile.linux
- Pre-installed packages:
  - `argbash` - Bash argument parser generator ⭐
  - `shellcheck` - Shell script linter
  - `shfmt` - Shell script formatter
  - `just` - Task runner
  - `gum` - Modern terminal UI
  - `parallel` - GNU Parallel
  - `jq`/`yq` - JSON/YAML processors
  - And more (see Brewfile.linux)

### 🛠️ Development Tools
- Git with GitHub CLI (`gh`)
- VS Code extensions pre-installed:
  - Shell scripting (shellcheck, bash-ide)
  - Python (Pylance, Ruff)
  - Markdown, Git, and more
- Oh My Zsh with themes (optional)

### 📦 Project-Specific
- All dependencies from Brewfile.linux automatically installed
- Argument parser auto-generated on container creation (if template exists)
- Shell environment configured with Homebrew and uv in PATH

## Pre-Built Image

A pre-built version of this devcontainer is available from GitHub Container Registry:

```
ghcr.io/austyle-io/file-assoc-devcontainer:latest
```

This image is automatically built and pushed when changes are made to the devcontainer configuration on the main branch.

### Using the Pre-Built Image

To use the pre-built image instead of building locally, you can modify `.devcontainer/devcontainer.json` to reference the image:

```json
{
  "image": "ghcr.io/austyle-io/file-assoc-devcontainer:latest",
  // ... rest of configuration
}
```

However, the current configuration uses a local Dockerfile build, which allows for faster iteration during development.

## Usage

### Quick Start

**Option 1: VS Code (Recommended)**
1. Install [VS Code](https://code.visualstudio.com/) and [Dev Containers extension](https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.remote-containers)
2. Open this project in VS Code
3. Click the prompt to "Reopen in Container" (or press `F1` → "Dev Containers: Reopen in Container")
4. Wait for container to build (first time takes 5-10 minutes)
5. You're ready to develop! 🎉

**Option 2: GitHub Codespaces**
1. Go to the repository on GitHub
2. Click "Code" → "Codespaces" → "Create codespace"
3. Wait for environment to initialize
4. Start coding in the browser or open in VS Code

**Option 3: Claude Code**
1. The container will be automatically used when working with Claude Code
2. All tools and dependencies are available immediately

### Verifying Installation

After the container starts, verify installations:

```bash
# Python versions
python --version        # Should show Python 3.12.x
python3.11 --version
python3.12 --version
python3.13 --version

# uv (Python package manager)
uv --version
uvx --version

# Homebrew
brew --version
brew list

# Key tools
argbash --version      # ⭐ Needed for Phase 4
just --version
shellcheck --version
gum --version

# Project commands
just --list            # Show all available tasks
```

### Using uv (Python Package Manager)

```bash
# Install packages
uv pip install requests

# Create virtual environment
uv venv

# Activate virtual environment
source .venv/bin/activate

# Install from requirements
uv pip install -r requirements.txt

# Run tool without installing
uvx ruff check .
uvx black .
```

### Using Homebrew

```bash
# Install additional packages
brew install htop

# Update packages
brew update
brew upgrade

# Search for packages
brew search python

# Check status
brew doctor
```

### Generating Argument Parser

The argument parser is automatically generated on container creation if the template exists:

```bash
# Manual generation
just generate-parser

# Check if regeneration needed
just check-parser

# Direct argbash usage
argbash templates/reset-args.m4 -o lib/args-parser.sh
```

## Container Architecture

### User Setup
- Primary user: `vscode` (UID: 1000, GID: 1000)
- Homebrew user: `linuxbrew` (for Homebrew installation)
- `vscode` user has sudo access and is in `linuxbrew` group

### Directory Structure
```
/workspace/              # Project root (mounted from host)
/home/vscode/            # vscode user home
/home/linuxbrew/         # Homebrew user home
  .linuxbrew/            # Homebrew installation
    bin/                 # Homebrew binaries
    Cellar/              # Installed packages
```

### Environment Variables
- `PYTHONUNBUFFERED=1` - Python output buffering disabled
- `UV_LINK_MODE=copy` - uv link mode for better compatibility
- `UV_PYTHON=3.12` - Default Python version for uv
- `HOMEBREW_NO_AUTO_UPDATE=1` - Disable auto-updates
- `HOMEBREW_PREFIX=/home/linuxbrew/.linuxbrew` - Homebrew location
- `PATH` includes: uv, Homebrew, Python binaries

### Lifecycle Hooks

**onCreateCommand** (runs once when container is created):
- Installs Homebrew packages from Brewfile.linux
- Verifies uv installation

**postCreateCommand** (runs after container creation):
- Shows welcome message with installed versions
- Auto-generates argument parser (if template exists)

**postStartCommand** (runs each time container starts):
- Shows available just commands

**postAttachCommand** (runs when you attach to the container):
- Verifies environment is ready

## Customization

### Adding Python Versions

Edit `.devcontainer/Dockerfile`:
```dockerfile
RUN apt-get update \
    && apt-get -y install --no-install-recommends \
        python3.14 \          # When available
        python3.14-dev \
        python3.14-venv \
```

### Adding Homebrew Packages

Edit `Brewfile.linux`:
```ruby
brew "package-name"
```

Then rebuild container or run:
```bash
brew bundle --file=Brewfile.linux
```

### Adding VS Code Extensions

Edit `.devcontainer/devcontainer.json`:
```json
"extensions": [
  "publisher.extension-name"
]
```

### Modifying Shell Configuration

Edit your `~/.bashrc` or `~/.zshrc` inside the container:
```bash
# Add to ~/.bashrc
export MY_CUSTOM_VAR=value
alias myalias='command'
```

## Troubleshooting

### Container Build Fails

**Issue**: Docker build fails or times out

**Solution**:
```bash
# Rebuild without cache
# VS Code: Ctrl+Shift+P → "Dev Containers: Rebuild Container Without Cache"

# Or via docker directly
docker build --no-cache -f .devcontainer/Dockerfile .
```

### Homebrew Commands Not Found

**Issue**: `brew: command not found`

**Solution**:
```bash
# Add Homebrew to PATH manually
eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"

# Or restart your shell
exec bash -l
```

### uv Not Working

**Issue**: `uv: command not found`

**Solution**:
```bash
# Verify uv is installed
ls -l /usr/local/bin/uv

# Check PATH
echo $PATH | grep usr/local/bin

# Reinstall if necessary (rebuild container)
```

### Slow First Build

**Issue**: Initial container build takes 10+ minutes

**Explanation**: This is normal for first build. The container:
- Installs Python 3.11, 3.12, 3.13
- Compiles Homebrew packages from source (on first install)
- Downloads and configures all tools

**Future builds**: Much faster due to Docker layer caching

### Permission Issues

**Issue**: Can't write to certain directories

**Solution**:
```bash
# Check current user
whoami  # Should be 'vscode'

# Fix ownership if needed
sudo chown -R vscode:vscode /workspace
```

### argbash Not Found

**Issue**: `argbash: command not found` even though Homebrew installed it

**Solution**:
```bash
# Verify argbash is installed
brew list argbash

# Check symlink
ls -l /usr/local/bin/argbash

# Manual symlink if needed
sudo ln -sf /home/linuxbrew/.linuxbrew/bin/argbash /usr/local/bin/argbash

# Or use Homebrew path directly
/home/linuxbrew/.linuxbrew/bin/argbash --version
```

## Performance Optimization

### Faster Rebuilds

The Dockerfile uses multi-stage builds and layer caching:
- Base packages layer (rarely changes)
- Python installation layer
- Homebrew installation layer (cached)
- User setup layer

Make changes to later layers when possible to avoid rebuilding earlier layers.

### Reducing Container Size

If container is too large:
```bash
# Clean Homebrew cache
brew cleanup

# Remove unnecessary apt packages
sudo apt-get autoremove -y
sudo apt-get clean -y
```

## Integration with Project

### Running Tests

```bash
# Unit tests
just test-unit

# Specific module
./tests/test-core.sh

# All quality checks
just quality
```

### Using Just (Task Runner)

```bash
# See all commands
just --list

# Common commands
just lint           # Run shellcheck
just format         # Format shell scripts
just generate-parser  # Generate argument parser
just test-unit      # Run all unit tests
```

### Development Workflow

1. **Start container**: Opens in VS Code or Codespace
2. **Make changes**: Edit code with full IDE support
3. **Test changes**: Run `just test-unit` or specific tests
4. **Generate parser**: Run `just generate-parser` after template changes
5. **Commit**: Git configured with your credentials
6. **Push**: Changes are pushed from container

## Technical Details

### Base Image
- `mcr.microsoft.com/devcontainers/base:ubuntu-24.04`
- Official Microsoft dev container base
- Ubuntu 24.04 LTS (Noble Numbat)

### Architecture
- Multi-user setup (linuxbrew, vscode)
- Layer caching for fast rebuilds
- Docker-in-docker support (socket mounted)

### Security
- Non-root user (vscode) by default
- Sudo access for admin tasks
- Isolated Homebrew installation

## CI/CD Integration

### GitHub Actions

The repository includes a GitHub Actions workflow (`.github/workflows/build-devcontainer.yml`) that automatically:

1. **Validates** the devcontainer configuration on every push and PR
2. **Builds** the Docker image using Docker Buildx with caching
3. **Pushes** to GitHub Container Registry (GHCR) on main branch
4. **Tags** with latest, git sha, branch name, and date

The workflow runs when changes are detected in:
- `.devcontainer/**`
- `Brewfile.linux`
- `.dockerignore`
- The workflow file itself

### Manual Build and Push

To manually build and push to GHCR:

```bash
# Login to GHCR
echo $GITHUB_TOKEN | docker login ghcr.io -u USERNAME --password-stdin

# Build the image
docker buildx build -t ghcr.io/austyle-io/file-assoc-devcontainer:latest \
  -f .devcontainer/Dockerfile .

# Push to registry
docker push ghcr.io/austyle-io/file-assoc-devcontainer:latest
```

Note: You need `packages: write` permission in the repository.

## Resources

- [Dev Containers Documentation](https://containers.dev/)
- [VS Code Remote Containers](https://code.visualstudio.com/docs/remote/containers)
- [uv Documentation](https://docs.astral.sh/uv/)
- [Homebrew on Linux](https://docs.brew.sh/Homebrew-on-Linux)
- [argbash Documentation](https://argbash.readthedocs.io/)
- [GitHub Container Registry](https://docs.github.com/en/packages/working-with-a-github-packages-registry/working-with-the-container-registry)

## Contributing

When adding new dependencies:
1. Add to `Brewfile.linux` (for Homebrew packages)
2. Or add to `requirements.txt` (for Python packages via uv)
3. Update this README if needed
4. Test in a fresh container build

## License

Same as main project (see top-level LICENSE file).
