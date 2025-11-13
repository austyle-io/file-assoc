#!/bin/bash
# Welcome script for devcontainer
# Displays environment information after container creation

set -e

echo '✨ Development container ready!'
echo '📦 Python versions available:'
for py in /usr/bin/python3.*; do
  [[ -f "$py" && "$py" =~ python3\.[0-9]+$ ]] && basename "$py"
done

echo '⚡ uv version:'
uv --version

echo '🍺 Homebrew version:'
eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
brew --version
