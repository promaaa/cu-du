#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_BASE="$(cd "$SCRIPT_DIR/../../.." && pwd)"
CN_DIR="$REPO_BASE/source/oai-cn5g"

echo "[CN health] Checking Core Network containers..."
docker compose -f "$CN_DIR/docker-compose.yml" ps

echo "[CN health] Verifying SIM registration..."
docker exec mysql mysql -u root -plinux -D oai_db -e \
    "SELECT * FROM AuthenticationSubscription WHERE supi='001010000059449';" 2>/dev/null

echo "[CN health] Done."
