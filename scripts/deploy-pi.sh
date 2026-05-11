#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_BASE="$HOME/cu-du"
CONF_DIR="$REPO_BASE/conf"

source "$CONF_DIR/env.sh"

echo "[deploy-pi] Deploying to serber-pi ($PI_IP)..."

echo "[deploy-pi] Cloning repo to serber-pi..."
sshpass -e ssh -o StrictHostKeyChecking=no serber@$PI_IP "rm -rf ~/cu-du; git clone https://github.com/promaaa/cu-du.git ~/cu-du"

echo "[deploy-pi] Running build on serber-pi..."
sshpass -e ssh -o StrictHostKeyChecking=no serber@$PI_IP "cd ~/cu-du && roles/pi/build.sh"

echo "[deploy-pi] Done."
