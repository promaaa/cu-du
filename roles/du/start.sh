#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_BASE="$(cd "$SCRIPT_DIR/.." && pwd)"
CONF_DIR="$REPO_BASE/conf"
SOURCE_DIR="$REPO_BASE/source"
OAI_DIR="$SOURCE_DIR/openairinterface5g"
LOG_DIR="${LOG_DIR:-/tmp}"
DU_LOG="$LOG_DIR/du.log"

source "$CONF_DIR/env.sh"

echo "[DU start] Generating DU config..."
"$SCRIPT_DIR/../../scripts/generate-configs.sh" du

# Start DU binary
echo "[DU start] Starting DU binary..."
cd "$OAI_DIR/cmake_targets/ran_build/build"
sudo ./nr-softmodem \
    -O "$OAI_DIR/targets/PROJECTS/GENERIC-NR-5GC/CONF/gnb-du.conf" \
    --log_config.global_log_level info \
    | tee "$DU_LOG"
