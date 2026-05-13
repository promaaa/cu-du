#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_BASE="$HOME/cu-du"
LOG_DIR="${LOG_DIR:-$REPO_BASE/logs}"
CU_LOG="$LOG_DIR/cu.log"

echo "[CU stop] Stopping CU nr-softmodem..."
pkill -f "nr-softmodem.*gnb-cu.conf" || true

echo "[CU stop] Done."
