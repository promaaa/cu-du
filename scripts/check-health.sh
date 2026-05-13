#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_BASE="$(cd "$SCRIPT_DIR/.." && pwd)"
CONF_DIR="$REPO_BASE/conf"
LOG_DIR="${LOG_DIR:-\$HOME/cu-du/logs}"

source "$CONF_DIR/env.sh"

echo "=========================================="
echo "CU/DU Health Check"
echo "=========================================="

echo ""
echo "[1] CU process on $CU_HOST"
ssh "$CU_HOST" "ps aux | grep nr-softmodem | grep -v grep" || echo "  FAIL: CU not running"

echo ""
echo "[2] PI DU process on $PI_HOST"
ssh "$PI_HOST" "ps aux | grep nr-softmodem | grep -v grep" || echo "  FAIL: PI DU not running"

echo ""
echo "[3] CN containers on $CU_HOST"
ssh "$CU_HOST" "cd \$HOME/cu-du/source/oai-cn5g && docker compose -f docker-compose.yaml ps"

echo ""
echo "[3b] UPF shaping"
ssh "$CU_HOST" "docker exec oai-upf tc qdisc show dev tun0 2>/dev/null" || echo "  FAIL: UPF shaper missing"

echo ""
echo "[4] F1 link — CU log"
ssh "$CU_HOST" "grep -i 'F1\|f1_setup' $LOG_DIR/cu.log 2>/dev/null | tail -10" || echo "  No CU F1 log"

echo ""
echo "[5] F1 link — DU log"
ssh "$PI_HOST" "grep -i 'F1\|f1_setup' $LOG_DIR/pi.log 2>/dev/null | tail -10" || echo "  No PI F1 log"

echo ""
echo "[6] AMF registration (CU log)"
ssh "$CU_HOST" "grep 'NGAP_REGISTER_GNB_CNF\|Registered' $LOG_DIR/cu.log 2>/dev/null | tail -5" || echo "  Not registered yet"

echo ""
echo "[7] SIB8 / PWS in CU log"
ssh "$CU_HOST" "grep -i 'SIB8\|write_replace_warning' $LOG_DIR/cu.log 2>/dev/null | tail -5"

echo ""
echo "[8] SIB8 / PWS in DU log"
ssh "$PI_HOST" "grep -i 'SIB8\|write_replace_warning' $LOG_DIR/pi.log 2>/dev/null | tail -5"

echo ""
echo "[9] UE attached"
ssh "$PI_HOST" "grep 'RRC_CONNECTED\|in-sync\|UE.*RNTI' $LOG_DIR/pi.log 2>/dev/null | tail -5" || echo "  No UE attached yet"

echo ""
echo "[10] PI host health"
ssh "$PI_HOST" "vcgencmd get_throttled 2>/dev/null || true; for f in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do printf '%s=' \"\$f\"; cat \"\$f\"; done 2>/dev/null | head -4" || true

echo ""
echo "=========================================="
echo "Health check complete"
echo "=========================================="
