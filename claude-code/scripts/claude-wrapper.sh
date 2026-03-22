#!/bin/bash
# /home/agent/bin/claude (wrapper)
# Injects agent environment before launching the real Claude Code binary.
#
# Installed into ~/bin, which is prepended to PATH so it shadows the real
# claude binary at ~/.local/bin/claude. The real binary is left untouched,
# allowing Claude's self-update mechanism to work correctly.
# This wrapper sources /etc/agent-environment.sh (which loads *.env files
# from /etc/agent-environment.d/) and then exec's the real binary.

REAL_CLAUDE="/home/agent/.local/bin/claude"

if [ ! -x "$REAL_CLAUDE" ]; then
    echo "Error: real claude binary not found at $REAL_CLAUDE" >&2
    exit 1
fi

. /etc/sandbox-persistent.sh

exec "$REAL_CLAUDE" "$@"
