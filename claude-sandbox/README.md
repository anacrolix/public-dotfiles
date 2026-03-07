# claude-sandbox

A Docker-based sandbox for running Claude Code in a network-isolated environment.
The sandbox can access the internet but is blocked from reaching your local LAN.

## Usage

Run from any directory — that directory becomes the workspace Claude operates in:

```sh
just -f /path/to/claude-sandbox/justfile cli          # interactive Claude session
just -f /path/to/claude-sandbox/justfile cli "task"   # Claude with a task
just -f /path/to/claude-sandbox/justfile shell        # drop into a bash shell
just -f /path/to/claude-sandbox/justfile build        # rebuild containers
```

Add the justfile to your PATH or alias it for convenience.

## Authentication

Claude Code needs an API key or OAuth credentials. Two options:

### Option A: Local proxy (default)

The justfile defaults to routing through [cliproxyapi](https://github.com/cli-proxy-api/cli-proxy-api)
running on the macOS host at `http://host.docker.internal:8317`. The proxy holds
your Claude OAuth session and handles auth with Anthropic's servers.

1. Install and start cliproxyapi
2. Run `cliproxyapi --claude-login` to authenticate
3. No further configuration needed — the defaults in the justfile handle the rest

### Option B: Direct API key

Override the defaults before running:

```sh
export ANTHROPIC_API_KEY=sk-ant-...
export ANTHROPIC_BASE_URL=https://api.anthropic.com
just -f /path/to/claude-sandbox/justfile cli
```

Note: API usage is billed separately from a Claude.ai subscription.

## GitHub access

The sandbox mounts `~/.config/gh` read-only so the `gh` CLI works out of the box.
In future this may be replaced with a scoped PAT via `GITHUB_TOKEN` for tighter
permission control.

## Network isolation

The `nolan` container applies iptables rules that block access to RFC1918 private
addresses (your LAN), while allowing internet access and the Docker Desktop host
interface (`192.168.65.0/24`) needed to reach the local proxy.
