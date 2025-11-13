#!/bin/bash
# Welcome script for devcontainer
# Displays environment information after container creation

set -e

echo '✨ Development container ready!'
echo '📦 Python versions available:'
ls -1 /usr/bin/python3.* | grep -E 'python3\.[0-9]+$'

echo '⚡ uv version:'
uv --version

echo '🍺 Homebrew version:'
eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
brew --version
