#!/bin/sh
set -eu

curl -sf "http://127.0.0.1:${ALICE_PORT:-8080}/api/info" > /dev/null
