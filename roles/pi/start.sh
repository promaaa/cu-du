#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_BASE="$HOME/cu-du"
CONF_DIR="$REPO_BASE/conf"
SOURCE_DIR="$REPO_BASE/source"
OAI_DIR="$SOURCE_DIR/openairinterface5g"
LOG_DIR="${LOG_DIR:-/tmp}"
PI_LOG="$LOG_DIR/pi.log"

source "$CONF_DIR/env.sh"

OAI_BUILD_DIR="$OAI_DIR/cmake_targets/ran_build/build"
OAI_CONF_DIR="$OAI_DIR/targets/PROJECTS/GENERIC-NR-5GC/CONF"
SIB8_CONF="$REPO_BASE/sib8.conf"

if [ ! -d "$OAI_BUILD_DIR" ]; then
    echo "[PI start] ERROR: OAI binary not found at $OAI_BUILD_DIR"
    echo "[PI start] Run roles/pi/build.sh first"
    exit 1
fi

if [ -f "$SIB8_CONF" ] && [ ! -f "$OAI_CONF_DIR/sib8.conf" ]; then
    cp "$SIB8_CONF" "$OAI_CONF_DIR/" 2>/dev/null || true
fi

echo "[PI start] Generating PI config..."
"$SCRIPT_DIR/../../scripts/generate-configs.py" pi

echo "[PI start] Starting PI DU binary..."
cd "$OAI_BUILD_DIR"
sudo ./nr-softmodem \
    -O "$OAI_CONF_DIR/gnb-pi.conf" \
    --log_config.global_log_level info \
    | tee "$PI_LOG"
