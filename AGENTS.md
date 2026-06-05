# AGENTS.md

Docker sandbox templates that extend upstream sandbox images with file-based
environment injection for agentic workflows. See [README.md](README.md) for the
full mechanism and usage; this file covers what an agent needs to work safely here.

## Layout

- One template per top-level directory; each contains its own `Dockerfile`. The CI
  in [.github/workflows/build-publish.yml](.github/workflows/build-publish.yml)
  discovers templates by that layout.
- The reference template is [claude-code/](claude-code/). Its shared injection
  scripts live in [claude-code/scripts/](claude-code/scripts/).

## Environment injection (do not break)

Every template uses the same three-script flow to inject `KEY=VALUE` pairs from
mounted `*.env` files. Keep it intact when editing any template's `Dockerfile` or
its scripts:

- `scripts/agent-environment.sh` → `/etc/agent-environment.sh`: the loader. Reads
  `*.env` files from `/etc/agent-environment.d/` in lexical order and exports them.
- `scripts/agent-entrypoint.sh` → `ENTRYPOINT`: sources the loader, then `exec "$@"`
  so the agent process starts with the injected vars.
- `scripts/<agent>-wrapper.sh` → `~/bin/<agent>`: shadows the real agent binary via
  `PATH` (`~/bin` first) so the launched agent gets the injected vars. The real
  binary must stay untouched so the agent's self-update keeps working.
- The loader and `PATH` override are also appended to the image's persistent shell
  init so shells the agent spawns (e.g. its built-in Bash tool) inherit the same
  environment.

## Conventions

- Env files: `.env` extension, plain `KEY=VALUE`, numeric prefixes (`00-`, `10-`)
  for load order.
- The loader deliberately rejects `export`, command substitution, and backticks in
  mounted files — preserve that validation when touching
  [claude-code/scripts/agent-environment.sh](claude-code/scripts/agent-environment.sh).

## Adding a template

Create `<name>/Dockerfile` extending the appropriate base image and copy the
injection scripts from `claude-code/scripts/`. CI builds any directory containing a
`Dockerfile` and publishes to GHCR and DockerHub.

### claude-code template

The reference template binds the generic flow to Claude Code specifics:

- Base image: `docker/sandbox-templates:claude-code-docker`.
- Wrapper [claude-code/scripts/claude-wrapper.sh](claude-code/scripts/claude-wrapper.sh)
  → `~/bin/claude`; the real binary at `~/.local/bin/claude` must stay untouched so
  Claude's self-update keeps working.
- Persistent shell init is `/etc/sandbox-persistent.sh` (provided by the upstream
  image); the loader and `~/bin` `PATH` override are appended there so Claude's Bash
  tool inherits the environment.

Validate:

```sh
docker build -t sandbox-templates:claude-code claude-code
```
