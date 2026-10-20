#!/bin/sh

# Written by Claude, tested extensively by a human.

set -eu

cd "$(dirname "$0")/.."

docker compose down

# The container must be gone first, it holds the mount open.
if mountpoint -q data/frigate; then
    fusermount3 -u data/frigate
    echo "Unmounted data/frigate"
else
    echo "data/frigate is not mounted"
fi
