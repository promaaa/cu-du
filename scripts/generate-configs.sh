#!/bin/bash
# Wrapper for generate-configs.py

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_BASE="$(cd "$SCRIPT_DIR/.." && pwd)"

cd "$REPO_BASE"
python3 "$SCRIPT_DIR/generate-configs.py" "$@"
