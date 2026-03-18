# Sandbox Templates

Custom Docker image templates for [Docker sandbox](https://docs.docker.com/desktop/features/sandbox/), providing environment variable injection for agentic development workflows.

## Overview

This repository contains custom Docker sandbox templates that extend official Docker sandbox base images. Each template adds an environment injection mechanism, enabling host-side configuration (API keys, agent settings, credentials) to be passed into sandboxes at runtime.

## Problem

Docker Desktop sandbox on Linux does not provide a reliable way to pass custom environment variables into running sandboxes. While the sandbox runtime includes a proxy-based credential injection mechanism for well-known API keys (e.g., `ANTHROPIC_API_KEY`), this approach:

- Is limited to a predefined set of environment variables and API providers
- May not function consistently on Docker Desktop for Linux
- Does not support arbitrary environment variables needed for custom agent configurations
- Provides no way to inject project-specific settings, internal API endpoints, or organization-specific credentials

For agentic development workflows, the ability to inject arbitrary environment variables — API keys, MCP server URLs, feature flags, authentication tokens — is essential for proper setup of the autonomous agent inside the sandbox.

## Solution

These templates implement a **file-based environment injection mechanism** using Docker's workspace directory mapping, which works reliably on Linux.

### How It Works

1. A shell script `/etc/agent-environment.sh` is installed in the image. It loads all `*.env` files from `/etc/agent-environment.d/` in sorted order.
2. A custom entrypoint script sources the environment, then hands off to the original command (`claude --dangerously-skip-permissions`).
3. At runtime, mount a host directory containing your environment files to `/etc/agent-environment.d/` in read-only mode.

```
Host                                    Sandbox
/etc/agent-environment.d/               /etc/agent-environment.d/ (ro)
  ├── 00-api-keys.env       ──────►      ├── 00-api-keys.env
  ├── 10-mcp-config.env     ──────►      ├── 10-mcp-config.env
  └── 20-project.env        ──────►      └── 20-project.env
```

If no directory is mounted, the mechanism is a no-op — the agent starts normally.

### Usage

**1. Create environment files on the host:**

```bash
sudo mkdir -p /etc/agent-environment.d

sudo tee /etc/agent-environment.d/00-api-keys.env << 'EOF'
ANTHROPIC_API_KEY=sk-ant-...
GITHUB_TOKEN=ghp_...
EOF

sudo tee /etc/agent-environment.d/10-custom.env << 'EOF'
MY_INTERNAL_API_URL=https://api.internal.example.com
AGENT_LOG_LEVEL=debug
EOF
```

**2. Run the sandbox with the custom template, mounting your env directory:**

Docker sandboxes support [multiple workspace mounts](https://docs.docker.com/ai/sandboxes/workflows/#multiple-workspaces) (requires Docker Desktop 4.61+). Additional workspace paths are appended after the primary workspace, with `:ro` to mount read-only.

> **Important:** Docker sandbox mounts workspaces at their **absolute host path** inside the sandbox — no path remapping occurs. To have files available at `/etc/agent-environment.d` inside the sandbox, the directory must exist at `/etc/agent-environment.d` on the host as well.

```bash
# Create the env directory on the host (requires sudo on Linux)
sudo mkdir -p /etc/agent-environment.d

# Run sandbox — mounts ~/my-project as primary workspace (rw)
# and /etc/agent-environment.d as a read-only additional workspace
docker sandbox run claude ~/my-project /etc/agent-environment.d:ro

# Using a custom template from GHCR
docker sandbox run \
    -t ghcr.io/vskh-docker-images/sandbox-templates:claude-code \
    claude ~/my-project /etc/agent-environment.d:ro

# Using a custom template from DockerHub
docker sandbox run \
    -t vskhimages/sandbox-templates:claude-code \
    claude ~/my-project /etc/agent-environment.d:ro
```

### Environment File Conventions

- Files **must** have the `.env` extension to be loaded
- Files are sourced in lexicographic order — use numeric prefixes (`00-`, `10-`, `20-`) for ordering
- Files must contain plain `KEY=VALUE` entries; shell syntax such as `export`, command substitution, or inline scripts is rejected
- Quoted values are supported, but no shell expansion is performed
- Mount the directory in **read-only mode** (`ro`) for security

## Available Templates

| Template | Base Image | Description |
|---|---|---|
| `claude-code` | `docker/sandbox-templates:claude-code-docker` | Claude Code agent with environment injection |

## Adding New Templates

1. Create a new directory at the repository root (e.g., `my-template/`)
2. Add a `Dockerfile` that extends the appropriate base sandbox template
3. Include the environment injection scripts (copy from `claude-code/scripts/`)
4. The CI pipeline automatically detects new template directories containing a `Dockerfile`

## CI/CD

GitHub Actions automatically builds images on pull requests (validation only) and pushes to both GHCR and DockerHub on merge to `main`.

### Image Tags

Each template produces:

- `<registry>/sandbox-templates:<template>` — latest from main
- `<registry>/sandbox-templates:<template>-<sha>` — pinned to specific commit
