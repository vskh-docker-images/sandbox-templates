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
- The [hermes/](hermes/) template also ships a kit at [hermes/kit/spec.yaml](hermes/kit/spec.yaml)
  with the first-run launch flow and browser-enabled runtime policy.
- If a template ships a kit, publish its companion OCI image as `<template>-kit` and
  `<template>-kit-<sha>` to both GHCR and DockerHub so it can be loaded via `sbx run --kit ...`.

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
- Kit publishing convention: when a template has a `kit/` directory, also add a
  `kit/Dockerfile` so CI can publish a companion OCI image using the same base tag
  pattern as the template, with a `-kit` suffix (`<template>-kit`, `<template>-kit-<sha>`).
  The published `-kit` image is just an OCI image built by the existing Docker
  build/push path; no separate `sbx kit push` step is required for this repo.
- Prefer `sbx run --kit ghcr.io/...:<template>-kit ...` or `sbx run --kit vskhimages/...:<template>-kit ...`
  over local path references in repo docs and examples.

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

### hermes template

The Hermes template follows the same pattern, but uses the `shell-docker` base and
adds the first-run launch flow for Hermes:

- Base image: `docker/sandbox-templates:shell-docker`.
- Launcher [hermes/scripts/hermes-launch.sh](hermes/scripts/hermes-launch.sh)
  → `/usr/local/bin/hermes-launch`; it runs `hermes setup` until completion on first
  launch, then starts Hermes with the baked `--yolo` path.
- Wrapper [hermes/scripts/hermes-wrapper.sh](hermes/scripts/hermes-wrapper.sh)
  → `~/bin/hermes`; the real `~/.local/bin/hermes` shim stays untouched so `hermes update`
  continues to work.
- Persistent shell init is `/etc/sandbox-persistent.sh`; the loader and `PATH`
  override are appended there so shell sessions inherit the injected env.
- The Hermes kit lives in [hermes/kit/spec.yaml](hermes/kit/spec.yaml) and is packaged by
  [hermes/kit/Dockerfile](hermes/kit/Dockerfile) as an OCI image.
- Published Hermes kit tags are `ghcr.io/vskh-docker-images/sandbox-templates:hermes-kit`
  and `vskhimages/sandbox-templates:hermes-kit`, with `-<sha>` variants for pinned builds.

Validate:

```sh
docker build -t sandbox-templates:hermes hermes
```
