#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_BASE="$(cd "$SCRIPT_DIR/.." && pwd)"
CONF_DIR="$REPO_BASE/conf"

source "$CONF_DIR/env.sh"

REMOTE_LOG_DIR='${HOME}/cu-du/logs'
SSH_OPTS=(-o StrictHostKeyChecking=no -o PreferredAuthentications=password -o PubkeyAuthentication=no)
if [ -n "${SSHPASS:-}" ] && command -v sshpass >/dev/null 2>&1; then
    SSH_CMD=(sshpass -e ssh "${SSH_OPTS[@]}")
else
    SSH_CMD=(ssh "${SSH_OPTS[@]}")
fi
CU_TARGET="serber@$CU_IP"
PI_TARGET="serber@$PI_IP"

echo "=========================================="
echo "CU/DU Health Check"
echo "=========================================="

echo ""
echo "[1] CU process on $CU_HOST"
"${SSH_CMD[@]}" "$CU_TARGET" "ps aux | grep nr-softmodem | grep -v grep" || echo "  FAIL: CU not running"

echo ""
echo "[2] PI DU process on $PI_HOST"
"${SSH_CMD[@]}" "$PI_TARGET" "ps aux | grep nr-softmodem | grep -v grep" || echo "  FAIL: PI DU not running"

echo ""
echo "[3] CN containers on $CU_HOST"
"${SSH_CMD[@]}" "$CU_TARGET" "cd \$HOME/cu-du/source/oai-cn5g && docker compose -f docker-compose.yaml ps"

echo ""
echo "[3b] UPF shaping"
"${SSH_CMD[@]}" "$CU_TARGET" "docker exec oai-upf tc qdisc show dev tun0 2>/dev/null" || echo "  FAIL: UPF shaper missing"

echo ""
echo "[4] F1 link — CU log"
"${SSH_CMD[@]}" "$CU_TARGET" "grep -i 'F1\|f1_setup' $REMOTE_LOG_DIR/cu.log 2>/dev/null | tail -10" || echo "  No CU F1 log"

echo ""
echo "[5] F1 link — DU log"
"${SSH_CMD[@]}" "$PI_TARGET" "grep -i 'F1\|f1_setup' $REMOTE_LOG_DIR/pi.log 2>/dev/null | tail -10" || echo "  No PI F1 log"

echo ""
echo "[6] AMF registration (CU log)"
"${SSH_CMD[@]}" "$CU_TARGET" "grep 'NGAP_REGISTER_GNB_CNF\|Registered' $REMOTE_LOG_DIR/cu.log 2>/dev/null | tail -5" || echo "  Not registered yet"

echo ""
echo "[7] SIB8 / PWS in CU log"
"${SSH_CMD[@]}" "$CU_TARGET" "grep -i 'SIB8\|write_replace_warning' $REMOTE_LOG_DIR/cu.log 2>/dev/null | tail -5"

echo ""
echo "[8] SIB8 / PWS in DU log"
"${SSH_CMD[@]}" "$PI_TARGET" "grep -i 'SIB8\|write_replace_warning' $REMOTE_LOG_DIR/pi.log 2>/dev/null | tail -5"

echo ""
echo "[9] UE attached"
"${SSH_CMD[@]}" "$PI_TARGET" "grep 'RRC_CONNECTED\|in-sync\|UE.*RNTI' $REMOTE_LOG_DIR/pi.log 2>/dev/null | tail -5" || echo "  No UE attached yet"

echo ""
echo "[10] PI host health"
"${SSH_CMD[@]}" "$PI_TARGET" "vcgencmd get_throttled 2>/dev/null || true; for f in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do printf '%s=' \"\$f\"; cat \"\$f\"; done 2>/dev/null | head -4" || true

echo ""
echo "=========================================="
echo "Health check complete"
echo "=========================================="
