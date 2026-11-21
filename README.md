# stacks

Docker Compose stacks for self-hosted services. One directory per service, each holding a `compose.yaml` plus `config/`, and `data/` where applicable.

The compose files are kept as examples only and are no longer maintained. Most of these stacks run on rootless podman, from each stack's `quadlet/` directory (alice from its `Makefile`).

## Usage

```sh
cd <stack>/
cp .env.example .env # Edit .env
chown -R uid:gid data/ config/ # Use the same values as PUID and PGID from .env
docker compose up -d --pull=always --remove-orphans
```
