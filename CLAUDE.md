# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

Container stacks for self-hosted services, one directory per service
(caddy, gitea, frigate, mediaserver, vaultwarden, ...), each holding a
`compose.yaml` plus optional `quadlet/`, `Dockerfile`, `config/`, and
`data/`. Services needing secrets/settings ship a `.env.example` to copy to
`.env` in the same directory.

Most stacks deploy as rootless podman quadlets from `quadlet/`, and alice
runs on plain podman from its `Makefile`. A stack with neither still runs
from its `compose.yaml`. Everywhere else `compose.yaml` is kept as an
example only and is no longer maintained, so don't edit it.

## Dev workflow

- Every stack tracks a `.gitkeep` in each directory it actually bind-mounts
  from whatever it runs from (quadlets, `Makefile` or `compose.yaml`), so a
  fresh clone already has them, podman never fails on a missing path, and
  docker never creates one as root. When you add a new bind
  mount, create a matching directory with a `.gitkeep` at that exact path,
  no deeper. Don't pre-create subdirectories an application creates for
  itself (e.g. deluge makes its own move-completed dirs) — only ones that
  error out if missing (e.g. Radarr/Sonarr root folders). `mediaserver/` is
  the reference example.
- The root `.gitignore` ignores all files under any `config/`/`data/` tree
  at any depth while keeping the directories themselves trackable, so
  `.gitkeep` placeholders show up but real runtime state (databases,
  secrets, media) never does, even under a stray `git add -A`. If a
  stack's data directory contains embedded git repos that would slip
  through this net (e.g. gitea-runner's act/cache checkouts), add a
  stack-local `.gitignore` rather than special-casing the root one.
- Each stack's `.env.example` documents `BASE_DIR` with a comment naming
  which of `config/`/`data/` it governs. Defaults to `.`; if set to
  anything else, the directory tree must already exist there, nothing
  creates it for you off-repo.
- `compose.override.yaml` is gitignored deliberately, it's where
  host-specific tweaks live (published ports, image pins, notification
  credentials) that shouldn't be in the tracked `compose.yaml`. Don't
  assume `compose.yaml` alone is the whole picture on a live host.
- Keep a stack's directory name and its container names in sync with what
  it actually runs, don't let them drift.
- Container names use hyphens. Sidecars are `<stack>-<service>`, named
  after the software (`gitea-postgres`, `gitea-redis`), with matching
  `config/`/`data/` dirs (`data/postgres`).
- Postgres services are unversioned (`postgres`, not `db-18`).
- Bring a compose stack up from its directory:
  `docker compose up -d --build --pull=always --remove-orphans`
- When verifying a deploy command for a locally built image, run it twice
  (no image, then after a source change) and confirm the new image ID is in
  use. A cold-start success doesn't prove the rebuild path.
- Lint: `uv run yamllint --strict .` or `uv run prek run --all-files`
  (yamllint plus end-of-file/trailing-whitespace/shebang checks, configured
  in `prek.toml`). uv is dev tooling only. There is no Python code here.

## Podman quadlets

- Quadlet paths are relative to the quadlet dir (`Volume=../data:/data`),
  so link the whole `quadlet/` directory into
  `~/.config/containers/systemd/`, not individual files.
- Host-specific settings live in gitignored `*.container.d/override.conf`
  drop-ins, the quadlet equivalent of `compose.override.yaml`.
