# syntax=docker/dockerfile:1
# ^^^ must be the very first line — enables BuildKit and its cache mount features

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
    # python3/pip/venv - running Python and isolating packages per project
    # nodejs/npm       - required to install and run Claude Code
    apt-get update && apt-get install -y --no-install-recommends \
    curl \
    ca-certificates \
    git \
    unzip \
    jq \
    procps \
    python3 \
    python3-pip \
    python3-venv \
    nodejs \
    npm \
    && rm -rf /var/lib/apt/lists/*
    # Remove apt list cache from the image layer itself — the host-side
    # BuildKit cache (above) handles caching, so we don't need this in
    # the image. Keeping it would bloat every image built from this layer.

# --- install claude code as root ---
# Installing as root means claude lands in /usr/local/bin, which is
# root-owned. The unprivileged user can run claude but cannot modify
# or replace it, which is what we want in a sandbox.
RUN --mount=type=cache,target=/root/.npm,sharing=locked \
    npm install -g @anthropic-ai/claude-code

# --- create user ---
RUN useradd -m -s /bin/bash user
# Create an unprivileged user. Running as root inside the container is
# unnecessary and means any mistake or exploit has broader blast radius.
# -m creates the home directory, -s sets the shell.

USER user
# Switch to the unprivileged user for all subsequent RUN, CMD, ENTRYPOINT.
# Everything from here on is owned by and runs as "user", not root.

WORKDIR /home/user
# Set working directory to the user's home. Must come after USER —
# if set before, the directory would be created owned by root.

# --- workspace ---
RUN mkdir /home/user/workspace
# Separate working directory for claude to operate in, keeping it distinct
# from the home directory where config and tooling live.

WORKDIR /home/user/workspace
# Drop into the workspace by default so claude starts in a clean directory
# rather than the home directory.

CMD ["/bin/bash"]
# Default to an interactive shell. Override this in docker compose or
# docker run to execute a specific command instead.
