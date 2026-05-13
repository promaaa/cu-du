#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_BASE="$HOME/cu-du"
SOURCE_DIR="$REPO_BASE/source"
CN_DIR="$SOURCE_DIR/oai-cn5g"
COMPOSE_FILE="$CN_DIR/docker-compose.yaml"

if [ ! -f "$COMPOSE_FILE" ]; then
    COMPOSE_FILE="$CN_DIR/docker-compose.yml"
fi

echo "[CN health] Checking Core Network containers..."
docker compose -f "$COMPOSE_FILE" ps

echo "[CN health] Checking UPF shaper..."
docker exec oai-upf tc qdisc show dev tun0 2>/dev/null || true

echo "[CN health] Verifying SIM registration..."
docker exec mysql mysql -u root -plinux -D oai_db -e \
    "SELECT * FROM AuthenticationSubscription WHERE supi='001010000059449';" 2>/dev/null

echo "[CN health] Done."
