#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_BASE="$HOME/cu-du"
MONOLITHIC_BASE="$HOME/monolithic"
CN_DIR="$MONOLITHIC_BASE/configuration"

echo "[CN start] Starting Core Network..."
docker compose -f "$CN_DIR/docker-compose.yml" down 2>/dev/null || true
docker compose -f "$CN_DIR/docker-compose.yml" up -d

echo "[CN start] Waiting for CN to be healthy (~20s)..."
sleep 20

echo "[CN start] Applying data plane fixes (MTU & Checksum)..."
sudo ethtool -K enp6s0 tx off rx off || true
sudo docker exec oai-upf ethtool -K eth0 tx off rx off || true
sudo docker exec oai-upf iptables -t mangle -A FORWARD -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --clamp-mss-to-pmtu || true


echo "[CN start] CN status:"
docker compose -f "$CN_DIR/docker-compose.yml" ps
