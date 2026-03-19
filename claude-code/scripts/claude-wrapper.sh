#!/bin/bash
# /home/agent/.local/bin/claude (wrapper)
# Injects agent environment before launching the real Claude Code binary.
#
# The real claude symlink is renamed to .claude-real during image build.
# This wrapper sources /etc/agent-environment.sh (which loads *.env files
# from /etc/agent-environment.d/) and then exec's the real binary.

REAL_CLAUDE="/home/agent/.local/bin/.claude-real"

if [ ! -x "$REAL_CLAUDE" ]; then
    echo "Error: real claude binary not found at $REAL_CLAUDE" >&2
    exit 1
fi

. /etc/sandbox-persistent.sh

exec "$REAL_CLAUDE" "$@"
