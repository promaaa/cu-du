#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_BASE="$HOME/cu-du"
MONOLITHIC_BASE="$HOME/monolithic"
CN_DIR="$MONOLITHIC_BASE/configuration"

echo "[CN health] Checking Core Network containers..."
docker compose -f "$CN_DIR/docker-compose.yml" ps

echo "[CN health] Verifying SIM registration..."
docker exec mysql mysql -u root -plinux -D oai_db -e \
    "SELECT * FROM AuthenticationSubscription WHERE supi='001010000059449';" 2>/dev/null

echo "[CN health] Done."
