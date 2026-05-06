#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_BASE="$(cd "$SCRIPT_DIR/.." && pwd)"
CONF_DIR="$REPO_BASE/conf"

source "$CONF_DIR/env.sh"

echo "[deploy-cu] Deploying CU to $CU_HOST ($CU_IP)..."

# SSH and run build + optional UHD build on CU host
ssh -t "$CU_HOST" "
    set -e
    REPO_URL=\${1:-https://github.com/promaaa/cu-du.git}
    CU_DU_BASE=\${CU_DU_BASE:-\$HOME/cu-du}

    # Clone or update repo
    if [ -d \"\$CU_DU_BASE/.git\" ]; then
        echo \"[deploy-cu] Repo already exists, pulling latest...\"
        cd \"\$CU_DU_BASE\"
        git pull
    else
        echo \"[deploy-cu] Cloning repo...\"
        git clone \$REPO_URL \"\$CU_DU_BASE\"
        cd \"\$CU_DU_BASE\"
    fi

    # Source env
    source conf/env.sh

    # Run CU build
    echo \"[deploy-cu] Running CU build...\"
    roles/cu/build.sh

    echo \"[deploy-cu] Build complete on $CU_HOST.\"
" "$@"
