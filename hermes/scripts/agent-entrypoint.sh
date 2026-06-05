#!/bin/bash
# Entrypoint script for custom sandbox templates.
# Sources environment configuration, then hands off to CMD.

. /etc/agent-environment.sh

exec "$@"
