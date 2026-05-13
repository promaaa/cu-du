#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_BASE="$HOME/cu-du"
CONF_DIR="$REPO_BASE/conf"
SOURCE_DIR="$REPO_BASE/source"
OAI_DIR="$SOURCE_DIR/openairinterface5g"
CN_DIR="$SOURCE_DIR/oai-cn5g"
COMPOSE_FILE="$CN_DIR/docker-compose.yaml"
LOG_DIR="${LOG_DIR:-$REPO_BASE/logs}"
CU_LOG="$LOG_DIR/cu.log"

source "$CONF_DIR/env.sh"

OAI_BUILD_DIR="$OAI_DIR/cmake_targets/ran_build/build"
OAI_CONF_DIR="$OAI_DIR/targets/PROJECTS/GENERIC-NR-5GC/CONF"
SIB8_CONF="$REPO_BASE/sib8.conf"

if [ ! -f "$COMPOSE_FILE" ]; then
    COMPOSE_FILE="$CN_DIR/docker-compose.yml"
fi

mkdir -p "$LOG_DIR"

if [ ! -x "$OAI_BUILD_DIR/nr-softmodem" ]; then
    echo "[CU start] ERROR: OAI binary not found at $OAI_BUILD_DIR"
    echo "[CU start] Run roles/cu/build.sh first"
    exit 1
fi

if [ -f "$SIB8_CONF" ] && [ ! -f "$OAI_CONF_DIR/sib8.conf" ]; then
    cp "$SIB8_CONF" "$OAI_CONF_DIR/" 2>/dev/null || true
fi

echo "[CU start] Generating CU config..."
python3 "$SCRIPT_DIR/../../scripts/generate-configs.py" cu

echo "[CU start] Starting Core Network..."
docker compose -f "$COMPOSE_FILE" down 2>/dev/null || true
docker compose -f "$COMPOSE_FILE" up -d

echo "[CU start] Waiting for CN to be healthy (~20s)..."
sleep 20

docker compose -f "$COMPOSE_FILE" ps

echo "[CU start] Applying UPF downlink shaper..."
docker exec oai-upf tc qdisc replace dev tun0 root tbf rate 1500kbit burst 8kbit latency 400ms || true
docker exec oai-upf tc qdisc show dev tun0 || true

echo "[CU start] Starting CU binary..."
cd "$OAI_BUILD_DIR"
sudo ./nr-softmodem \
    -O "$OAI_CONF_DIR/gnb-cu.conf" \
    --log_config.global_log_level info \
    | tee "$CU_LOG"
