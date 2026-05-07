#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_BASE="$HOME/cu-du"
CONF_DIR="$REPO_BASE/conf"
SOURCE_DIR="$REPO_BASE/source"
OAI_DIR="$SOURCE_DIR/openairinterface5g"
LOG_DIR="${LOG_DIR:-/tmp}"
DU_LOG="$LOG_DIR/du.log"

source "$CONF_DIR/env.sh"

OAI_BUILD_DIR="$OAI_DIR/cmake_targets/ran_build/build"
OAI_CONF_DIR="$OAI_DIR/targets/PROJECTS/GENERIC-NR-5GC/CONF"
SIB8_CONF="$REPO_BASE/sib8.conf"

if [ ! -d "$OAI_BUILD_DIR" ]; then
    echo "[DU start] ERROR: OAI binary not found at $OAI_BUILD_DIR"
    echo "[DU start] Run roles/du/build.sh first"
    exit 1
fi

if [ -f "$SIB8_CONF" ] && [ ! -f "$OAI_CONF_DIR/sib8.conf" ]; then
    cp "$SIB8_CONF" "$OAI_CONF_DIR/" 2>/dev/null || true
fi

echo "[DU start] Generating DU config..."
"$SCRIPT_DIR/../../scripts/generate-configs.py" du

echo "[DU start] Starting DU binary..."
cd "$OAI_BUILD_DIR"
sudo ./nr-softmodem \
    -O "$OAI_CONF_DIR/gnb-du.conf" \
    --log_config.global_log_level info \
    | tee "$DU_LOG"