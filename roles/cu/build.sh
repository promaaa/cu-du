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

echo "[CU build] Starting..."

if [ ! -d "$OAI_DIR/.git" ]; then
    echo "[CU build] Fetching OAI source into repo overlay..."
    TMP_DIR="$(mktemp -d)"
    git clone https://gitlab.eurecom.fr/oai/openairinterface5g.git "$TMP_DIR/openairinterface5g"
    mkdir -p "$OAI_DIR"
    rsync -a "$TMP_DIR/openairinterface5g/" "$OAI_DIR/"
    rm -rf "$TMP_DIR"
fi

cd "$OAI_DIR"

echo "[CU build] Checking out $OAI_COMMIT..."
git checkout "$OAI_COMMIT"

if grep -q "build_sib8_segments" "$OAI_DIR/openair2/RRC/NR/MESSAGES/asn1_msg.c" 2>/dev/null; then
    echo "[CU build] SIB8/PWS already present, skipping patch"
elif [ -f "$PATCHES_DIR/oai-warning.patch" ]; then
    echo "[CU build] Applying oai-warning.patch..."
    git apply "$PATCHES_DIR/oai-warning.patch" || echo "[CU build] Patch failed, continuing..."
fi

if ! command -v uhd_find_devices &>/dev/null || ! uhd_find_devices 2>&1 | grep -q "B210"; then
    echo "[CU build] Building UHD from source..."
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
    make -j"$(nproc)"
    make test || true
    sudo make install
    sudo ldconfig
    sudo uhd_images_downloader
    cd "$OAI_DIR"
else
    echo "[CU build] UHD already installed"
fi

if [ ! -d /tmp/asn1c ] || [ ! -f /tmp/asn1c/skeleton/asn1_constants.h ]; then
    echo "[CU build] Installing OAI dependencies..."
    cd "$OAI_DIR/cmake_targets"
    sudo ./build_oai -I
else
    echo "[CU build] Dependencies already installed, skipping -I"
fi

if [ -f "$OAI_DIR/cmake_targets/ran_build/build/nr-softmodem" ]; then
    echo "[CU build] Binary already exists, skipping build"
else
    echo "[CU build] Building nr-softmodem..."
    cd "$OAI_DIR/cmake_targets"
    sudo ./build_oai -w USRP --ninja --gNB -C
fi

echo "[CU build] Done."
