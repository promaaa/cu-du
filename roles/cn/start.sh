#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_BASE="$(cd "$SCRIPT_DIR/../../.." && pwd)"
CN_DIR="$REPO_BASE/source/oai-cn5g"

echo "[CN start] Starting Core Network..."
docker compose -f "$CN_DIR/docker-compose.yml" down 2>/dev/null || true
docker compose -f "$CN_DIR/docker-compose.yml" up -d

echo "[CN start] Waiting for CN to be healthy (~20s)..."
sleep 20

echo "[CN start] CN status:"
docker compose -f "$CN_DIR/docker-compose.yml" ps
