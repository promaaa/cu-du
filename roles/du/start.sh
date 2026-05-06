#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_BASE="/home/serber/cu-du"
CONF_DIR="$REPO_BASE/conf"
SOURCE_DIR="$REPO_BASE/source"
OAI_DIR="$SOURCE_DIR/openairinterface5g"
MONOLITHIC_OAI="/home/serber/monolithic/openairinterface5g"
LOG_DIR="${LOG_DIR:-/tmp}"
DU_LOG="$LOG_DIR/du.log"

source "$CONF_DIR/env.sh"

# Use monolithic OAI if available (has binary built)
if [ -d "$MONOLITHIC_OAI/cmake_targets/ran_build/build" ]; then
    echo "[DU start] Using existing monolithic OAI at $MONOLITHIC_OAI"
    OAI_BUILD_DIR="$MONOLITHIC_OAI/cmake_targets/ran_build/build"
    OAI_CONF_DIR="$MONOLITHIC_OAI/targets/PROJECTS/GENERIC-NR-5GC/CONF"
    SIB8_CONF="$MONOLITHIC_OAI/sib8.conf"
else
    OAI_BUILD_DIR="$OAI_DIR/cmake_targets/ran_build/build"
    OAI_CONF_DIR="$OAI_DIR/targets/PROJECTS/GENERIC-NR-5GC/CONF"
    SIB8_CONF="$OAI_DIR/sib8.conf"
fi

# Copy sib8.conf if it exists
if [ -f "$SIB8_CONF" ] && [ ! -f "$OAI_CONF_DIR/sib8.conf" ]; then
    cp "$SIB8_CONF" "$OAI_CONF_DIR/" 2>/dev/null || true
fi

echo "[DU start] Generating DU config..."
"$SCRIPT_DIR/../../scripts/generate-configs.sh" du

# Copy generated DU config to monolithic OAI path if using monolithic
if [ -d "$MONOLITHIC_OAI/cmake_targets/ran_build/build" ]; then
    mkdir -p "$MONOLITHIC_OAI/targets/PROJECTS/GENERIC-NR-5GC/CONF"
    cp "$OAI_DIR/targets/PROJECTS/GENERIC-NR-5GC/CONF/gnb-du.conf" "$MONOLITHIC_OAI/targets/PROJECTS/GENERIC-NR-5GC/CONF/" 2>/dev/null || true
fi

# Start DU binary
echo "[DU start] Starting DU binary..."
cd "$OAI_BUILD_DIR"
sudo ./nr-softmodem \
    -O "$OAI_CONF_DIR/gnb-du.conf" \
    --log_config.global_log_level info \
    | tee "$DU_LOG"
