#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_BASE="$HOME/cu-du"
SOURCE_DIR="$REPO_BASE/source"
CN_DIR="$SOURCE_DIR/oai-cn5g"
COMPOSE_FILE="$CN_DIR/docker-compose.yaml"

if [ ! -f "$COMPOSE_FILE" ]; then
    COMPOSE_FILE="$CN_DIR/docker-compose.yml"
fi

echo "[CN stop] Stopping Core Network..."
docker compose -f "$COMPOSE_FILE" down

echo "[CN stop] Done."
