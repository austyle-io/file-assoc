# syntax=docker/dockerfile:1

FROM mcr.microsoft.com/devcontainers/base:ubuntu-24.04

# Avoid warnings by switching to noninteractive
ENV DEBIAN_FRONTEND=noninteractive

# Configure apt and install base packages
RUN apt-get update \
    && apt-get -y install --no-install-recommends \
        apt-utils \
        dialog \
        ca-certificates \
        curl \
        git \
        build-essential \
        procps \
        file \
        libssl-dev \
        pkg-config \
        # Python build dependencies
        libffi-dev \
        libsqlite3-dev \
        libbz2-dev \
        libreadline-dev \
        libncurses5-dev \
        libncursesw5-dev \
        liblzma-dev \
        tk-dev \
        zlib1g-dev \
    && apt-get autoremove -y \
    && apt-get clean -y \
    && rm -rf /var/lib/apt/lists/*

# Add deadsnakes PPA for multiple Python versions
RUN apt-get update \
    && apt-get -y install --no-install-recommends software-properties-common \
    && add-apt-repository ppa:deadsnakes/ppa -y \
    && apt-get autoremove -y \
    && apt-get clean -y \
    && rm -rf /var/lib/apt/lists/*

# Install Python 3.11, 3.12, 3.13 (3.14 not released yet as of Nov 2024)
RUN apt-get update \
    && apt-get -y install --no-install-recommends \
        python3.11 \
        python3.11-dev \
        python3.11-venv \
        python3.12 \
        python3.12-dev \
        python3.12-venv \
        python3.13 \
        python3.13-dev \
        python3.13-venv \
        python3-pip \
    && apt-get autoremove -y \
    && apt-get clean -y \
    && rm -rf /var/lib/apt/lists/*

# Set Python 3.12 as default (most stable for modern development)
RUN update-alternatives --install /usr/bin/python python /usr/bin/python3.12 1 \
    && update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.12 1

# Install uv (fast Python package manager) from official image
COPY --from=ghcr.io/astral-sh/uv:latest /uv /usr/local/bin/uv

# Verify uv installation and set up uvx
RUN uv --version \
    && ln -s /usr/local/bin/uv /usr/local/bin/uvx

# Install Homebrew (Linuxbrew) as linuxbrew user
# Create linuxbrew user and group
RUN groupadd -r linuxbrew \
    && useradd -r -g linuxbrew -d /home/linuxbrew -m -s /bin/bash linuxbrew \
    && echo 'linuxbrew ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers

# Install Homebrew as linuxbrew user
USER linuxbrew
WORKDIR /home/linuxbrew
RUN /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" </dev/null

# Add Homebrew to PATH
ENV PATH="/home/linuxbrew/.linuxbrew/bin:/home/linuxbrew/.linuxbrew/sbin:${PATH}"
ENV HOMEBREW_PREFIX="/home/linuxbrew/.linuxbrew"
ENV HOMEBREW_CELLAR="/home/linuxbrew/.linuxbrew/Cellar"
ENV HOMEBREW_REPOSITORY="/home/linuxbrew/.linuxbrew/Homebrew"

# Verify Homebrew installation
RUN brew --version

# Install essential Homebrew packages
RUN brew install \
    gcc \
    just \
    shellcheck \
    shfmt

# Switch back to root for finalization
USER root

# Add Homebrew environment to system-wide profile
RUN echo 'eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"' >> /etc/profile.d/brew.sh \
    && chmod +x /etc/profile.d/brew.sh

# Create a script to source Homebrew for all users
RUN echo '#!/bin/bash\neval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"' > /usr/local/bin/brew-env \
    && chmod +x /usr/local/bin/brew-env

# Install argbash from source (not available in Homebrew or apt)
# Argbash is used to generate bash argument parsers for our scripts
RUN apt-get update \
    && apt-get -y install --no-install-recommends \
        autoconf \
        make \
        wget \
    && wget -q https://github.com/matejak/argbash/archive/refs/tags/2.10.0.tar.gz -O /tmp/argbash.tar.gz \
    && tar -xzf /tmp/argbash.tar.gz -C /tmp \
    && cd /tmp/argbash-2.10.0/resources \
    && make install PREFIX=/usr \
    && cd / \
    && rm -rf /tmp/argbash* \
    && apt-get autoremove -y \
    && apt-get clean -y \
    && rm -rf /var/lib/apt/lists/*

# Switch to vscode user (standard devcontainer user)
ARG USERNAME=vscode
ARG USER_UID=1000
ARG USER_GID=$USER_UID

# Create vscode user if it doesn't exist
RUN if ! id -u $USERNAME > /dev/null 2>&1; then \
        groupadd --gid $USER_GID $USERNAME \
        && useradd --uid $USER_UID --gid $USER_GID -m $USERNAME \
        && echo $USERNAME ALL=\(root\) NOPASSWD:ALL > /etc/sudoers.d/$USERNAME \
        && chmod 0440 /etc/sudoers.d/$USERNAME; \
    fi

# Add vscode user to linuxbrew group for Homebrew access
RUN usermod -a -G linuxbrew $USERNAME

# Set up shell environment for vscode user
USER $USERNAME
WORKDIR /home/$USERNAME

# Add Homebrew and uv to vscode user's shell
RUN echo 'eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"' >> ~/.bashrc \
    && echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc

# Verify installations for vscode user
RUN python --version \
    && python3 --version \
    && uv --version \
    && eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)" && brew --version

# Switch back to noninteractive
ENV DEBIAN_FRONTEND=dialog

# Set working directory
WORKDIR /workspace

# Labels
LABEL org.opencontainers.image.title="file-assoc-devcontainer"
LABEL org.opencontainers.image.description="Dev container for file-assoc project with uv, Python 3.11/12/13, and Homebrew"
LABEL org.opencontainers.image.source="https://github.com/austyle-io/file-assoc"
LABEL maintainer="file-assoc-project"
