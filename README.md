# stacks

Container stacks for self-hosted services. One directory per service, each holding a `quadlet/` directory plus `config/`, and `data/` where applicable.

Most of these stacks run on rootless podman, from each stack's `quadlet/` directory (alice from its `Makefile`). The compose files are pre-podman. They are kept as examples only and are no longer maintained.

## Usage

Run these as the user that owns the stack, with linger enabled (`loginctl enable-linger <user>`).

```sh
cd ~/stacks/<stack>/
cp .env.example .env # Edit .env
podman unshare chown -R uid:gid data/ config/ # Use the uid and gid the container runs as
mkdir -p ~/.config/containers/systemd/
ln -s ~/stacks/<stack>/quadlet ~/.config/containers/systemd/<stack>
systemctl --user daemon-reload
# Start each .container file's unit by its basename
systemctl --user start <name>
```

Link the whole `quadlet/` directory, not individual files, because quadlet paths are relative to it. Host-specific settings go in a gitignored `quadlet/<name>.container.d/override.conf` drop-in.
