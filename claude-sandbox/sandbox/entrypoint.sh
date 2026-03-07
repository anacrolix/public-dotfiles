#!/bin/bash
set -euo pipefail

# Verify RFC1918 isolation is active: any blocked private address should be unreachable.
if ping -c 1 -W 1 192.168.1.1 >/dev/null 2>&1; then
    echo "ERROR: local gateway 192.168.1.1 is reachable — isolation rules may not be active" >&2
    exit 1
fi
echo "Network isolation OK"

if [[ -n "${CLAUDE_TASK:-}" ]]; then
    exec claude --dangerously-skip-permissions -p "$CLAUDE_TASK"
else
    exec claude --dangerously-skip-permissions
fi
