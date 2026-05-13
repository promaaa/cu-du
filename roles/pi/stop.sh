#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_BASE="$HOME/cu-du"
LOG_DIR="${LOG_DIR:-$REPO_BASE/logs}"
PI_LOG="$LOG_DIR/pi.log"

echo "[PI stop] Stopping PI DU nr-softmodem..."
pkill -f "nr-softmodem.*gnb-pi.conf" || true

echo "[PI stop] Done."
