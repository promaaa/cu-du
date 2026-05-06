#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
LOG_DIR="${LOG_DIR:-/tmp}"
CU_LOG="$LOG_DIR/cu.log"

echo "[CU stop] Stopping CU nr-softmodem..."
pkill -f "nr-softmodem.*gnb-cu.conf" || true

echo "[CU stop] Done."
