#!/bin/bash
# /etc/agent-environment.sh
# Loads KEY=VALUE pairs from *.env files in /etc/agent-environment.d/.
# This avoids executing arbitrary shell code from mounted configuration.
#
# NOTE: This file is sourced (not executed), so we must not set shell options
# like set -euo pipefail — they propagate to the calling shell and can cause
# the entrypoint to abort before exec.

AGENT_ENV_DIR="/etc/agent-environment.d"

trim_whitespace() {
    local value="$1"

    value="${value#"${value%%[![:space:]]*}"}"
    value="${value%"${value##*[![:space:]]}"}"

    printf '%s' "$value"
}

strip_matching_quotes() {
    local value="$1"

    if [[ ${#value} -ge 2 ]]; then
        if [[ ${value:0:1} == '"' && ${value: -1} == '"' ]]; then
            value=${value:1:-1}
        elif [[ ${value:0:1} == "'" && ${value: -1} == "'" ]]; then
            value=${value:1:-1}
        fi
    fi

    printf '%s' "$value"
}

APPLIED_VARS=()

load_env_file() {
    local env_file="$1"
    local line key value
    local file_vars=()

    while IFS= read -r line || [ -n "$line" ]; do
        line=$(trim_whitespace "$line")

        [[ -z "$line" ]] && continue
        [[ ${line:0:1} == "#" ]] && continue
        [[ "$line" == export* ]] && {
            echo "Invalid line in $env_file: export syntax is not allowed" >&2
            return 1
        }
        [[ "$line" == *=* ]] || {
            echo "Invalid line in $env_file: expected KEY=VALUE" >&2
            return 1
        }

        key=${line%%=*}
        value=${line#*=}

        key=$(trim_whitespace "$key")
        value=$(trim_whitespace "$value")

        [[ "$key" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]] || {
            echo "Invalid environment key in $env_file: $key" >&2
            return 1
        }

        if [[ "$value" == *'$('* || "$value" == *'`'* ]]; then
            echo "Invalid value in $env_file for $key: command substitution is not allowed" >&2
            return 1
        fi

        value=$(strip_matching_quotes "$value")
        export "$key=$value"
        file_vars+=("$key=$value")
    done < "$env_file"

    # if [ ${#file_vars[@]} -gt 0 ]; then
    #     # echo "[agent-environment] $(basename "$env_file"):"
    #     # for entry in "${file_vars[@]}"; do
    #     #     echo "  $entry"
    #     # done
    #     APPLIED_VARS+=("${file_vars[@]}")
    # fi
}

if [ -d "$AGENT_ENV_DIR" ]; then
    for env_file in "$AGENT_ENV_DIR"/*.env; do
        [ -f "$env_file" ] || continue
        load_env_file "$env_file"
    done
fi

# if [ "${#APPLIED_VARS[@]}" -gt 0 ]; then
#     echo "[agent-environment] ${#APPLIED_VARS[@]} variable(s) applied."
# else
#     echo "[agent-environment] No environment variables applied."
# fi
