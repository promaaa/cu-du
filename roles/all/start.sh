#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_BASE="$HOME/cu-du"
CONF_DIR="$REPO_BASE/conf"
SOURCE_DIR="$REPO_BASE/source"
OAI_DIR="$SOURCE_DIR/openairinterface5g"
CN_DIR="$SOURCE_DIR/oai-cn5g"
LOG_DIR="${LOG_DIR:-/tmp}"
GNB_LOG="$LOG_DIR/gnb.log"

source "$CONF_DIR/env.sh"

OAI_BUILD_DIR="$OAI_DIR/cmake_targets/ran_build/build"
OAI_CONF_DIR="$OAI_DIR/targets/PROJECTS/GENERIC-NR-5GC/CONF"
SIB8_CONF="$REPO_BASE/sib8.conf"

if [ ! -d "$OAI_BUILD_DIR" ]; then
    echo "[ALL start] ERROR: OAI binary not found at $OAI_BUILD_DIR"
    echo "[ALL start] Run roles/cu/build.sh first"
    exit 1
fi

if [ -f "$SIB8_CONF" ] && [ ! -f "$OAI_CONF_DIR/sib8.conf" ]; then
    cp "$SIB8_CONF" "$OAI_CONF_DIR/" 2>/dev/null || true
fi

echo "[ALL start] Generating CU and DU configs..."
"$SCRIPT_DIR/../../scripts/generate-configs.py" all

echo "[ALL start] Starting Core Network..."
docker compose -f "$CN_DIR/docker-compose.yml" down 2>/dev/null || true
docker compose -f "$CN_DIR/docker-compose.yml" up -d

echo "[ALL start] Waiting for CN to be healthy (~20s)..."
sleep 20

docker compose -f "$CN_DIR/docker-compose.yml" ps

echo "[ALL start] Starting nr-softmodem (monolithic)..."
cd "$OAI_BUILD_DIR"
sudo ./nr-softmodem \
    -O "$OAI_CONF_DIR/gnb-cu.conf" \
    --log_config.global_log_level info \
    | tee "$GNB_LOG"