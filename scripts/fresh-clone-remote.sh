#!/bin/bash
set -euo pipefail

if [ "$#" -ne 2 ]; then
    echo "Usage: $0 <host> <repo-url>"
    exit 1
fi

HOST="$1"
REPO_URL="$2"
SSH_OPTS=(-o StrictHostKeyChecking=no -o PreferredAuthentications=password -o PubkeyAuthentication=no)

sshpass -e ssh "${SSH_OPTS[@]}" "$HOST" "
    set -e
    if [ -d \"\$HOME/cu-du\" ]; then
        ts=\$(date +%Y%m%d-%H%M%S)
        mkdir -p \"\$HOME/cu-du-archives\"
        mv \"\$HOME/cu-du\" \"\$HOME/cu-du-archives/cu-du-before-fresh-clone-\$ts\"
        echo \"Archived existing ~/cu-du to ~/cu-du-archives/cu-du-before-fresh-clone-\$ts\"
    fi
    git clone '$REPO_URL' \"\$HOME/cu-du\"
    cd \"\$HOME/cu-du\"
    scripts/validate-working-config.sh
"
