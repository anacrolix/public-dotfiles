# syntax=docker/dockerfile:1
# ^^^ must be the very first line — enables BuildKit and its cache mount features

# --- Rust toolchain stage ---
# Isolated so the toolchain download is only re-run when this stage's inputs
# change, not every time the main image's apt or npm layers are modified.
FROM ubuntu:24.04 AS rust-toolchain
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    rm -f /etc/apt/apt.conf.d/docker-clean && \
    apt-get update && apt-get install -y --no-install-recommends curl ca-certificates
ARG SANDBOX_UID=1000
RUN useradd -m -u ${SANDBOX_UID} -s /bin/bash user
USER user
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --default-toolchain stable

# --- main stage ---
FROM ubuntu:24.04
# Ubuntu 24.04 over Debian because Claude Code and the Node ecosystem
# have better compatibility with Ubuntu in practice.

ENV DEBIAN_FRONTEND=noninteractive
# Prevents apt from showing interactive prompts (e.g. timezone selection)
# during build, which would hang the build indefinitely.

# --- system packages ---
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    # Cache apt's download and index directories on the host between builds.
    # Without this, every rebuild fetches package indexes and re-downloads
    # packages from the internet. sharing=locked prevents concurrent builds
    # from writing to the cache simultaneously and corrupting it.
    # curl             - fetching files and APIs from the shell
    # ca-certificates  - validates SSL certs for curl, npm, and the Anthropic API
    # git              - Claude Code uses git heavily for reading history, diffing, and committing
    # unzip            - unpacking downloaded archives
    # jq               - parsing JSON in shell scripts without dropping into Python
    # procps           - ps, kill etc — lets Claude inspect and manage running processes
    # iputils-ping     - ping used in entrypoint to verify network isolation
    # python3/pip/venv - running Python and isolating packages per project
    # nodejs/npm       - required to install and run Claude Code
    # build-essential  - gcc/g++/make — needed for Rust, cgo, and native node modules
    # ripgrep          - Claude Code uses rg internally for fast code search
    # fd-find          - fd, a faster find; Claude uses it to locate files
    # less             - pager for file/output inspection
    # file             - identify file types by content
    # golang-go        - Go bootstrap compiler; projects use the toolchain directive to auto-download newer versions
    # rustup           - Rust toolchain installer; toolchain installed per-user below
    # sudo             - allows the unprivileged user to run commands as root when needed
    rm -f /etc/apt/apt.conf.d/docker-clean && \
    apt-get update && apt-get install -y --no-install-recommends \
    curl \
    ca-certificates \
    git \
    unzip \
    jq \
    procps \
    iputils-ping \
    python3 \
    python3-pip \
    python3-venv \
    nodejs \
    npm \
    build-essential \
    ripgrep \
    fd-find \
    less \
    file \
    golang-go \
    rustup \
    sudo

# --- install claude code as root ---
# Installing as root means claude lands in /usr/local/bin, which is
# root-owned. The unprivileged user can run claude but cannot modify
# or replace it, which is what we want in a sandbox.
RUN --mount=type=cache,target=/root/.npm,sharing=locked \
    npm install -g @anthropic-ai/claude-code

# --- GitHub CLI ---
# gh is useful for Claude to open PRs, read issues, and manage repos.
# Installed separately because it requires the official GitHub apt repo.
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    rm -f /etc/apt/apt.conf.d/docker-clean && \
    curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
        | dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg && \
    chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg && \
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
        > /etc/apt/sources.list.d/github-cli.list && \
    apt-get update && apt-get install -y --no-install-recommends gh

COPY --chmod=755 entrypoint.sh /entrypoint.sh

# --- create user ---
# UID must match the host user so that files mounted from the host (Claude
# credentials, gh auth, workspace) are owned by this user inside the container.
# On macOS, Docker Desktop maps the host user to UID 0 in the VM, so without
# this the mounted files appear as root and Claude can't read/write them.
ARG SANDBOX_UID=1000
RUN useradd -m -u ${SANDBOX_UID} -s /bin/bash user && \
    echo 'user ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/user

USER user
# Switch to the unprivileged user for all subsequent RUN, CMD, ENTRYPOINT.
# Everything from here on is owned by and runs as "user", not root.

WORKDIR /home/user
# Set working directory to the user's home. Must come after USER —
# if set before, the directory would be created owned by root.

# --- Rust ---
# Toolchain copied from the isolated rust-toolchain stage above.
# rustup remains available at runtime for adding targets, updating, etc.
COPY --from=rust-toolchain --chown=user:user /home/user/.cargo /home/user/.cargo
COPY --from=rust-toolchain --chown=user:user /home/user/.rustup /home/user/.rustup
ENV PATH="/home/user/.cargo/bin:${PATH}"

# --- workspace ---
RUN mkdir /home/user/workspace
# Separate working directory for claude to operate in, keeping it distinct
# from the home directory where config and tooling live.

WORKDIR /home/user/workspace
# Drop into the workspace by default so claude starts in a clean directory
# rather than the home directory.

ENTRYPOINT ["/entrypoint.sh"]
