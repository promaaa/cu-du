#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
LOG_DIR="${LOG_DIR:-/tmp}"
GNB_LOG="$LOG_DIR/gnb.log"

echo "[ALL stop] Stopping nr-softmodem (monolithic)..."
pkill -f "nr-softmodem.*gnb-cu.conf" || true

echo "[ALL stop] Done."
