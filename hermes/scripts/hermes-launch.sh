#!/bin/bash

if [ -f /etc/agent-environment.sh ]; then
    . /etc/agent-environment.sh
fi

HERMES_HOME="${HERMES_HOME:-/home/agent/.hermes}"
SENTINEL="${HERMES_HOME}/.sandbox-setup-complete"

mkdir -p "$HERMES_HOME"

if [ ! -f "$SENTINEL" ]; then
    TTY_AVAILABLE=0
    if [ -t 0 ]; then
        TTY_AVAILABLE=1
    else
        : </dev/tty 2>/dev/null && TTY_AVAILABLE=1 || true
    fi

    if [ "$TTY_AVAILABLE" -eq 1 ]; then
        until hermes setup; do
            echo "Hermes setup did not complete; retrying in 1s..." >&2
            sleep 1
        done
        touch "$SENTINEL"
    fi
fi

exec hermes "$@"
