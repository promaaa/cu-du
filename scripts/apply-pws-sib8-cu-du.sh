#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PATCH_FILE="$REPO_ROOT/patches/oai-pws-sib8-cu-du.patch"

usage() {
  cat <<'USAGE'
Apply the PWS/SIB8 CU/DU OAI patch.

Usage:
  scripts/apply-pws-sib8-cu-du.sh /path/to/openairinterface5g
  scripts/apply-pws-sib8-cu-du.sh user@host:/path/to/openairinterface5g

Examples:
  scripts/apply-pws-sib8-cu-du.sh /home/serber/cu-du/source/openairinterface5g
  scripts/apply-pws-sib8-cu-du.sh serber-firecell:/home/serber/cu-du/source/openairinterface5g
  scripts/apply-pws-sib8-cu-du.sh serber-minipc:/home/serber/monolithic/openairinterface5g

The target OAI tree should be based on commit:
  102965a669b9444857c27843ec8ce62780bf9d37
USAGE
}

if [[ $# -ne 1 || "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

if [[ ! -f "$PATCH_FILE" ]]; then
  echo "Patch file not found: $PATCH_FILE" >&2
  exit 1
fi

TARGET="$1"

if [[ "$TARGET" == *:* ]]; then
  HOST="${TARGET%%:*}"
  OAI_DIR="${TARGET#*:}"
  REMOTE_PATCH="/tmp/oai-pws-sib8-cu-du.patch"

  echo "[pws] Copying patch to $HOST:$REMOTE_PATCH"
  scp "$PATCH_FILE" "$HOST:$REMOTE_PATCH"

  echo "[pws] Checking patch on $HOST:$OAI_DIR"
  ssh "$HOST" "cd '$OAI_DIR' && git apply --check '$REMOTE_PATCH'"

  echo "[pws] Applying patch on $HOST:$OAI_DIR"
  ssh "$HOST" "cd '$OAI_DIR' && git apply '$REMOTE_PATCH'"
else
  OAI_DIR="$TARGET"
  echo "[pws] Checking patch in $OAI_DIR"
  (cd "$OAI_DIR" && git apply --check "$PATCH_FILE")

  echo "[pws] Applying patch in $OAI_DIR"
  (cd "$OAI_DIR" && git apply "$PATCH_FILE")
fi

echo "[pws] Patch applied successfully."
