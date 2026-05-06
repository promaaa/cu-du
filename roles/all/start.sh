#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_BASE="$(cd "$SCRIPT_DIR/../../.." && pwd)"
CONF_DIR="$REPO_BASE/conf"
SOURCE_DIR="$REPO_BASE/source"
OAI_DIR="$SOURCE_DIR/openairinterface5g"
CN_DIR="$SOURCE_DIR/oai-cn5g"
LOG_DIR="${LOG_DIR:-/tmp}"
GNB_LOG="$LOG_DIR/gnb.log"

source "$CONF_DIR/env.sh"

echo "[ALL start] Generating CU and DU configs..."
"$SCRIPT_DIR/../../scripts/generate-configs.sh" all

# Start Core Network
echo "[ALL start] Starting Core Network..."
docker compose -f "$CN_DIR/docker-compose.yml" down 2>/dev/null || true
docker compose -f "$CN_DIR/docker-compose.yml" up -d

echo "[ALL start] Waiting for CN to be healthy (~20s)..."
sleep 20

docker compose -f "$CN_DIR/docker-compose.yml" ps

# Start monolithic gNB (CU+DU in one binary)
echo "[ALL start] Starting nr-softmodem (monolithic)..."
cd "$OAI_DIR/cmake_targets/ran_build/build"
sudo ./nr-softmodem \
    -O "$OAI_DIR/targets/PROJECTS/GENERIC-NR-5GC/CONF/gnb-cu.conf" \
    --log_config.global_log_level info \
    | tee "$GNB_LOG"
