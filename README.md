# Sandbox Templates

[![Build and Push Sandbox Templates](https://github.com/vskh-docker-images/sanbox-templates/actions/workflows/build-publish.yml/badge.svg)](https://github.com/vskh-docker-images/sanbox-templates/actions/workflows/build-publish.yml)

Custom Docker image templates for [Docker sandbox](https://docs.docker.com/desktop/features/sandbox/), providing environment variable injection for agentic development workflows.

## Overview

This repository contains custom Docker sandbox templates that extend official Docker sandbox base images. Each template adds an environment injection mechanism, enabling host-side configuration (API keys, agent settings, credentials) to be passed into sandboxes at runtime.

## Problem

Docker Desktop sandbox on Linux does not provide a reliable way to pass custom environment variables into running sandboxes. While the sandbox runtime includes a proxy-based credential injection mechanism for well-known API keys (e.g., `ANTHROPIC_API_KEY`), this approach:

- Is limited to a predefined set of environment variables and API providers
- May not function consistently on Docker Desktop for Linux
- Does not support arbitrary environment variables needed for custom agent configurations

For agentic development workflows, the ability to inject arbitrary environment variables — API keys, MCP server URLs, feature flags, authentication tokens — is essential for proper setup of the autonomous agent inside the sandbox.

## Solution

These templates implement a **file-based environment injection mechanism** using Docker's workspace directory mapping, which works reliably on Linux.

### How It Works

1. A shell script `/etc/agent-environment.sh` is installed in the image. It loads all `*.env` files from `/etc/agent-environment.d/` in sorted order.
2. A **`claude` wrapper** is installed to `~/bin/claude`, and `~/bin` is prepended to the agent's `PATH` so it shadows the real binary at `~/.local/bin/claude`. The real binary is left untouched, allowing Claude's self-update mechanism to work correctly. The wrapper sources the environment loader before delegating to the real binary — ensuring the main agent process receives injected variables even when the sandbox bypasses Docker `ENTRYPOINT`.
3. The environment loader is also appended to **`/etc/sandbox-persistent.sh`** (referenced by `CLAUDE_ENV_FILE`), so every Bash tool invocation within Claude Code inherits the same variables.
4. At runtime, mount a host directory containing your environment files to `/etc/agent-environment.d/` in read-only mode.

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
| `hermes` | `docker/sandbox-templates:shell-docker` | Hermes agent with env injection, browser tools, and first-run setup |

### Hermes Template

The `hermes/` directory ships both a Docker template and a published `sbx` kit image:

```bash
# Template path (Docker sandbox run)
docker sandbox run -t ghcr.io/vskh-docker-images/sandbox-templates:hermes \
  hermes ~/my-project /etc/agent-environment.d:ro

# Published kit path (sbx)
sbx run --kit ghcr.io/vskh-docker-images/sandbox-templates:hermes-kit \
  hermes ~/my-project /etc/agent-environment.d:ro
```

For provider keys and other injected values, add a mounted env file such as:

```bash
OPENROUTER_API_KEY=your-key
HERMES_YOLO_MODE=1
```

Useful Hermes variables to provide or override when you launch the template or kit:

| Variable | Why it matters | Typical value / notes |
| --- | --- | --- |
| `OPENROUTER_API_KEY` | Recommended provider key for the main model path. | Set this first if you want OpenRouter-backed inference. |
| `OPENAI_API_KEY` / `ANTHROPIC_API_KEY` / `GOOGLE_API_KEY` / `GEMINI_API_KEY` / `XAI_API_KEY` / `DEEPSEEK_API_KEY` | Alternate provider credentials for other LLM backends. | Use whichever provider you selected in `hermes setup`. |
| `HF_TOKEN` | Useful for Hugging Face inference/provider flows. | Optional, but required for some provider paths. |
| `HERMES_YOLO_MODE` | Bypasses dangerous-command approval prompts. | Set to `1` for the `--yolo` behavior used by this sandbox launch path. |
| `HERMES_HOME` | Overrides Hermes' runtime config directory. | Default is `~/.hermes`; set this when you want a sandbox-specific home. |
| `FIRECRAWL_API_KEY` / `TAVILY_API_KEY` / `EXA_API_KEY` / `PARALLEL_API_KEY` / `SEARXNG_URL` | Enables web search and browsing helpers. | Add the ones you actually plan to use. |
| `HERMES_DOCKER_BINARY` / `TERMINAL_*` | Optional terminal-backend tuning for containerized or remote runs. | Useful when the default Docker/terminal discovery is not enough. |

These values are usually placed in `~/.hermes/.env` or managed with `hermes config set VAR value`. For the full official Hermes environment-variable reference, see https://hermes-agent.nousresearch.com/docs/reference/environment-variables/.

The kit embeds a runtime allow-list, while the template-only path should use `sbx policy allow network -g "..."` as needed.

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

If a template also ships a kit image, CI publishes the companion tags:

- `<registry>/sandbox-templates:<template>-kit` — latest kit image from main
- `<registry>/sandbox-templates:<template>-kit-<sha>` — pinned kit image for the commit

Use the `-kit` image with `sbx run --kit <registry>/sandbox-templates:<template>-kit ...` when you want the published OCI kit rather than a local directory.

The companion `-kit` image is published from `kit/Dockerfile` with the normal OCI image build/push flow already used by CI.
