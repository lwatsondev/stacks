#!/bin/sh

# Written by Claude, tested extensively by a human.

set -eu

usage() {
    echo "Usage: $0 [user@]host:/path/to/frigate" >&2
    echo "The remote path must contain Frigate's config/ and data/{clips,exports}." >&2
}

[ $# -eq 1 ] || { usage; exit 1; }
remote="$1"

command -v sshfs > /dev/null || { echo "sshfs is not installed" >&2; exit 1; }

cd "$(dirname "$0")/.."
mnt="data/frigate"

if mountpoint -q "$mnt"; then
    # A dropped connection leaves a mountpoint that errors on access.
    if ls "$mnt" > /dev/null 2>&1; then
        echo "$mnt is already mounted"
        exit 0
    fi
    echo "$mnt is stale, unmounting"
    fusermount3 -u "$mnt"
fi

mkdir -p "$mnt"

# The Docker daemon needs allow_other, which needs user_allow_other in /etc/fuse.conf.
sshfs -o ro,allow_other,reconnect,ServerAliveInterval=15,ServerAliveCountMax=3 "$remote" "$mnt"
echo "Mounted $remote on $mnt"
