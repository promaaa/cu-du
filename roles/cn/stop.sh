#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_BASE="$HOME/cu-du"
MONOLITHIC_BASE="$HOME/monolithic"
CN_DIR="$MONOLITHIC_BASE/configuration"

echo "[CN stop] Stopping Core Network..."
docker compose -f "$CN_DIR/docker-compose.yml" down

echo "[CN stop] Done."
