#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_BASE="$HOME/cu-du"
SOURCE_DIR="$REPO_BASE/source"
CN_DIR="$SOURCE_DIR/oai-cn5g"
COMPOSE_FILE="$CN_DIR/docker-compose.yaml"

if [ ! -f "$COMPOSE_FILE" ]; then
    COMPOSE_FILE="$CN_DIR/docker-compose.yml"
fi

if [ ! -f "$COMPOSE_FILE" ]; then
    echo "[CN start] ERROR: Core Network compose file not found in $CN_DIR"
    echo "[CN start] Run roles/cn/bootstrap.sh first, or copy the known-good oai-cn5g directory into source/oai-cn5g."
    exit 1
fi

echo "[CN start] Starting Core Network..."
docker compose -f "$COMPOSE_FILE" down 2>/dev/null || true
docker compose -f "$COMPOSE_FILE" up -d

echo "[CN start] Waiting for CN to be healthy (~20s)..."
sleep 20

echo "[CN start] Applying UPF downlink shaper..."
docker exec oai-upf tc qdisc replace dev tun0 root tbf rate 1500kbit burst 64kbit latency 400ms || true
docker exec oai-upf tc qdisc show dev tun0 || true

echo "[CN start] CN status:"
docker compose -f "$COMPOSE_FILE" ps
