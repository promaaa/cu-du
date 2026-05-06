#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_BASE="$(cd "$SCRIPT_DIR/.." && pwd)"
CONF_DIR="$REPO_BASE/conf"

source "$CONF_DIR/env.sh"

echo "[deploy-all] Deploying ALL (CU+DU) to $CU_HOST ($CU_IP)..."

ssh -t "$CU_HOST" "
    set -e
    REPO_URL=\${1:-https://github.com/promaaa/cu-du.git}
    CU_DU_BASE=\${CU_DU_BASE:-\$HOME/cu-du}

    if [ -d \"\$CU_DU_BASE/.git\" ]; then
        echo \"[deploy-all] Repo already exists, pulling latest...\"
        cd \"\$CU_DU_BASE\"
        git pull
    else
        echo \"[deploy-all] Cloning repo...\"
        git clone \$REPO_URL \"\$CU_DU_BASE\"
        cd \"\$CU_DU_BASE\"
    fi

    source conf/env.sh

    echo \"[deploy-all] Running ALL build...\"
    roles/all/build.sh

    echo \"[deploy-all] Build complete on $CU_HOST.\"
" "$@"
