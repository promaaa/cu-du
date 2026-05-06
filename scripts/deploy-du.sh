#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_BASE="$(cd "$SCRIPT_DIR/.." && pwd)"
CONF_DIR="$REPO_BASE/conf"

source "$CONF_DIR/env.sh"

echo "[deploy-du] Deploying DU to $DU_HOST ($DU_IP)..."

ssh -t "$DU_HOST" "
    set -e
    REPO_URL=\${1:-https://github.com/promaaa/cu-du.git}
    CU_DU_BASE=\${CU_DU_BASE:-\$HOME/cu-du}

    if [ -d \"\$CU_DU_BASE/.git\" ]; then
        echo \"[deploy-du] Repo already exists, pulling latest...\"
        cd \"\$CU_DU_BASE\"
        git pull
    else
        echo \"[deploy-du] Cloning repo...\"
        git clone \$REPO_URL \"\$CU_DU_BASE\"
        cd \"\$CU_DU_BASE\"
    fi

    source conf/env.sh

    echo \"[deploy-du] Running DU build...\"
    roles/du/build.sh

    echo \"[deploy-du] Build complete on $DU_HOST.\"
" "$@"
