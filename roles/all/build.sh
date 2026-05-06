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

echo "[ALL build] Starting (CU+DU on same host)..."

# Use existing OAI source if available, otherwise clone
MONOLITHIC_OAI="$HOME/monolithic/openairinterface5g"
if [ -d "$MONOLITHIC_OAI/.git" ]; then
    echo "[ALL build] Using existing OAI source at $MONOLITHIC_OAI"
    OAI_DIR="$MONOLITHIC_OAI"
    cd "$OAI_DIR"
elif [ ! -d "$OAI_DIR/.git" ]; then
    echo "[ALL build] Cloning OAI source..."
    git clone https://gitlab.eurecom.fr/oai/openairinterface5g.git "$OAI_DIR"
    cd "$OAI_DIR"
else
    cd "$OAI_DIR"
fi

# Checkout specific commit
echo "[ALL build] Checking out $OAI_COMMIT..."
git checkout "$OAI_COMMIT"

# Apply SIB8/PWS patch
if [ -f "$PATCHES_DIR/oai-warning.patch" ]; then
    echo "[ALL build] Applying oai-warning.patch..."
    git apply "$PATCHES_DIR/oai-warning.patch"
fi

# Build UHD from source if not installed
if ! command -v uhd_find_devices &>/dev/null || ! uhd_find_devices 2>&1 | grep -q "B210"; then
    echo "[ALL build] Building UHD from source..."
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
    echo "[ALL build] UHD already installed"
fi

# Install OAI dependencies
echo "[ALL build] Installing OAI dependencies..."
cd "$OAI_DIR/cmake_targets"
sudo ./build_oai -I

# Build nr-softmodem in monolithic mode (CU+DU combined)
echo "[ALL build] Building nr-softmodem (monolithic, full parallelism)..."
cd "$OAI_DIR/cmake_targets"
sudo ./build_oai -w USRP --ninja --gNB -C

echo "[ALL build] Done."
