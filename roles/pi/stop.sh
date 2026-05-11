#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
LOG_DIR="${LOG_DIR:-/tmp}"
PI_LOG="$LOG_DIR/pi.log"

echo "[PI stop] Stopping PI DU nr-softmodem..."
pkill -f "nr-softmodem.*gnb-pi.conf" || true

echo "[PI stop] Done."
