#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_BASE="$HOME/cu-du"
CONF_DIR="$REPO_BASE/conf"
SOURCE_DIR="$REPO_BASE/source"
OAI_DIR="$SOURCE_DIR/openairinterface5g"
PATCHES_DIR="$REPO_BASE/patches"
LOG_DIR="${LOG_DIR:-/tmp}"

source "$CONF_DIR/env.sh"

echo "[PI build] Starting on serber-pi..."

if [ ! -d "$OAI_DIR/.git" ]; then
    echo "[PI build] Fetching OAI source into repo overlay..."
    TMP_DIR="$(mktemp -d)"
    git clone https://gitlab.eurecom.fr/oai/openairinterface5g.git "$TMP_DIR/openairinterface5g"
    mkdir -p "$OAI_DIR"
    rsync -a "$TMP_DIR/openairinterface5g/" "$OAI_DIR/"
    rm -rf "$TMP_DIR"
fi

cd "$OAI_DIR"

echo "[PI build] Checking out $OAI_COMMIT..."
git checkout "$OAI_COMMIT"

if grep -q "build_sib8_segments" "$OAI_DIR/openair2/RRC/NR/MESSAGES/asn1_msg.c" 2>/dev/null; then
    echo "[PI build] SIB8/PWS already present, skipping patch"
elif [ -f "$PATCHES_DIR/oai-warning.patch" ]; then
    echo "[PI build] Applying oai-warning.patch..."
    git apply "$PATCHES_DIR/oai-warning.patch" || echo "[PI build] Patch failed, continuing..."
fi

if ! command -v uhd_config_info &>/dev/null; then
    echo "[PI build] Building UHD from source..."
    UHD_DIR="$REPO_BASE/uhd"
    if [ ! -d "$UHD_DIR/.git" ]; then
        git clone https://github.com/EttusResearch/uhd.git "$UHD_DIR"
    fi
    cd "$UHD_DIR"
    git checkout "$UHD_VERSION"
    cd host
    mkdir -p build
    cd build
    cmake ../
    make -j4
    make test || true
    sudo make install
    sudo ldconfig
    sudo uhd_images_downloader
    cd "$OAI_DIR"
else
    echo "[PI build] UHD already installed"
fi

if ! uhd_find_devices 2>&1 | grep -q "35F8ABA"; then
    echo "[PI build] WARNING: B210 serial 35F8ABA not detected right now. Build can continue, but DU start will require it."
fi

if [ ! -d /tmp/asn1c ] || [ ! -f /tmp/asn1c/skeleton/asn1_constants.h ]; then
    echo "[PI build] Installing OAI dependencies..."
    cd "$OAI_DIR/cmake_targets"
    sudo ./build_oai -I || echo "[PI build] Dependency installer failed; continuing because dependencies may already be present"
else
    echo "[PI build] Dependencies already installed, skipping -I"
fi

if [ -f "$OAI_DIR/cmake_targets/ran_build/build/nr-softmodem" ]; then
    echo "[PI build] Binary already exists, skipping build"
else
    echo "[PI build] Building nr-softmodem (-j4 for limited RAM on Pi 5)..."
    cd "$OAI_DIR/cmake_targets"
    sudo ./build_oai -w USRP --ninja --gNB -C --build-tool-opt "-j4"
fi

echo "[PI build] Done."
