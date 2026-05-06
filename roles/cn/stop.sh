#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_BASE="$HOME/cu-du"
CN_DIR="$REPO_BASE/source/oai-cn5g"

echo "[CN stop] Stopping Core Network..."
docker compose -f "$CN_DIR/docker-compose.yml" down

echo "[CN stop] Done."
