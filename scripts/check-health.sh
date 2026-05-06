#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_BASE="$(cd "$SCRIPT_DIR/.." && pwd)"
CONF_DIR="$REPO_BASE/conf"
LOG_DIR="${LOG_DIR:-/tmp}"

source "$CONF_DIR/env.sh"

echo "=========================================="
echo "CU/DU Health Check"
echo "=========================================="

echo ""
echo "[1] CU process on $CU_HOST"
ssh "$CU_HOST" "ps aux | grep nr-softmodem | grep -v grep" || echo "  FAIL: CU not running"

echo ""
echo "[2] DU process on $DU_HOST"
ssh "$DU_HOST" "ps aux | grep nr-softmodem | grep -v grep" || echo "  FAIL: DU not running"

echo ""
echo "[3] CN containers on $CU_HOST"
ssh "$CU_HOST" "docker compose -f \$HOME/cu-du/source/oai-cn5g/docker-compose.yml ps"

echo ""
echo "[4] F1 link — CU log"
ssh "$CU_HOST" "grep -i 'F1\|f1_setup' $LOG_DIR/cu.log 2>/dev/null | tail -10" || echo "  No CU F1 log"

echo ""
echo "[5] F1 link — DU log"
ssh "$DU_HOST" "grep -i 'F1\|f1_setup' $LOG_DIR/du.log 2>/dev/null | tail -10" || echo "  No DU F1 log"

echo ""
echo "[6] AMF registration (CU log)"
ssh "$CU_HOST" "grep 'NGAP_REGISTER_GNB_CNF\|Registered' $LOG_DIR/cu.log 2>/dev/null | tail -5" || echo "  Not registered yet"

echo ""
echo "[7] SIB8 / PWS in CU log"
ssh "$CU_HOST" "grep -i 'SIB8\|write_replace_warning' $LOG_DIR/cu.log 2>/dev/null | tail -5"

echo ""
echo "[8] SIB8 / PWS in DU log"
ssh "$DU_HOST" "grep -i 'SIB8\|write_replace_warning' $LOG_DIR/du.log 2>/dev/null | tail -5"

echo ""
echo "[9] UE attached"
ssh "$DU_HOST" "grep 'RRC_CONNECTED\|in-sync\|UE.*RNTI' $LOG_DIR/du.log 2>/dev/null | tail -5" || echo "  No UE attached yet"

echo ""
echo "=========================================="
echo "Health check complete"
echo "=========================================="
