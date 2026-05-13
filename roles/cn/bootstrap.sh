#!/bin/bash
set -euo pipefail

REPO_BASE="$HOME/cu-du"
SOURCE_DIR="$REPO_BASE/source"
CN_DIR="$SOURCE_DIR/oai-cn5g"

mkdir -p "$SOURCE_DIR"

if [ -f "$CN_DIR/docker-compose.yaml" ] || [ -f "$CN_DIR/docker-compose.yml" ]; then
    echo "[CN bootstrap] Core Network already present at $CN_DIR"
    exit 0
fi

echo "[CN bootstrap] ERROR: no Core Network compose tree found at $CN_DIR."
echo "[CN bootstrap] Place the known-good OAI CN5G docker-compose.yml tree at $CN_DIR, then rerun."
exit 1
