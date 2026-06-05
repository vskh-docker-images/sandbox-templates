#!/bin/bash
# /home/agent/bin/hermes (wrapper)
# Injects agent environment before launching the real Hermes binary.

REAL_HERMES="/home/agent/.local/bin/hermes"

if [ ! -x "$REAL_HERMES" ]; then
    echo "Error: real hermes binary not found at $REAL_HERMES" >&2
    exit 1
fi

. /etc/sandbox-persistent.sh

exec "$REAL_HERMES" "$@"
