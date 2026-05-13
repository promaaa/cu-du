#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_BASE="$(cd "$SCRIPT_DIR/.." && pwd)"
CONF_DIR="$REPO_BASE/conf"

source "$CONF_DIR/env.sh"

echo "[deploy-pi] Deploying to serber-pi ($PI_IP)..."

SSH_TARGET="serber@$PI_IP"
SSH_OPTS=(-o StrictHostKeyChecking=no -o PreferredAuthentications=password -o PubkeyAuthentication=no)
REPO_URL="${1:-https://github.com/promaaa/cu-du.git}"

echo "[deploy-pi] Cloning repo to serber-pi..."
sshpass -e ssh "${SSH_OPTS[@]}" "$SSH_TARGET" "
    set -e
    if [ -d \"\$HOME/cu-du/.git\" ]; then
        cd \"\$HOME/cu-du\"
        git pull
    else
        rm -rf \"\$HOME/cu-du\"
        git clone '$REPO_URL' \"\$HOME/cu-du\"
    fi
"

echo "[deploy-pi] Running build on serber-pi..."
sshpass -e ssh "${SSH_OPTS[@]}" "$SSH_TARGET" "cd ~/cu-du && roles/pi/build.sh"

echo "[deploy-pi] Done."
