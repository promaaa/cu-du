#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
LOG_DIR="${LOG_DIR:-/tmp}"
DU_LOG="$LOG_DIR/du.log"

echo "[DU stop] Stopping DU nr-softmodem..."
pkill -f "nr-softmodem.*gnb-du.conf" || true

echo "[DU stop] Done."
