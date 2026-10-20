#!/bin/sh
set -eu

exec python /app/alice.py --port "${ALICE_PORT:-8080}" --conf /app/config/alice.conf
