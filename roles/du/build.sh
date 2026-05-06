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

echo "[DU build] Starting..."

# Use existing OAI source if available, otherwise clone
MONOLITHIC_OAI="$HOME/monolithic/openairinterface5g"
if [ -d "$MONOLITHIC_OAI/.git" ]; then
    echo "[DU build] Using existing OAI source at $MONOLITHIC_OAI"
    OAI_DIR="$MONOLITHIC_OAI"
    cd "$OAI_DIR"
elif [ ! -d "$OAI_DIR/.git" ]; then
    echo "[DU build] Cloning OAI source..."
    git clone https://gitlab.eurecom.fr/oai/openairinterface5g.git "$OAI_DIR"
    cd "$OAI_DIR"
else
    cd "$OAI_DIR"
fi

# Checkout specific commit
echo "[DU build] Checking out $OAI_COMMIT..."
git checkout "$OAI_COMMIT"

# Apply SIB8/PWS patch only if function not already present
if grep -q "build_sib8_segments" "$OAI_DIR/openair2/RRC/NR/MESSAGES/asn1_msg.c" 2>/dev/null; then
    echo "[DU build] SIB8/PWS already present in $OAI_COMMIT, skipping patch"
elif [ -f "$PATCHES_DIR/oai-warning.patch" ]; then
    echo "[DU build] Applying oai-warning.patch..."
    git apply "$PATCHES_DIR/oai-warning.patch" || echo "[DU build] Patch failed, continuing..."
fi

# Build UHD from source if not installed
if ! command -v uhd_find_devices &>/dev/null || ! uhd_find_devices 2>&1 | grep -q "B210"; then
    echo "[DU build] Building UHD from source..."
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
    echo "[DU build] UHD already installed"
fi

# Install OAI dependencies only if asn1c not present
if [ ! -d /tmp/asn1c ] || [ ! -f /tmp/asn1c/skeleton/asn1_constants.h ]; then
    echo "[DU build] Installing OAI dependencies (asn1c missing)..."
    cd "$OAI_DIR/cmake_targets"
    sudo ./build_oai -I
else
    echo "[DU build] Dependencies already installed (asn1c present), skipping -I"
fi

# Build nr-softmodem for DU mode (only if binary not already built)
if [ -f "$OAI_DIR/cmake_targets/ran_build/build/nr-softmodem" ]; then
    echo "[DU build] Binary already exists, skipping build"
else
    echo "[DU build] Building nr-softmodem (DU, -j4 cap for weak host)..."
    cd "$OAI_DIR/cmake_targets"
    sudo ./build_oai -w USRP --ninja --gNB -C -j4
fi

echo "[DU build] Done."
