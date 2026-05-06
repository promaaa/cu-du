# Installation Guide

## Prerequisites

### Both Hosts (serber-firecell, serber-minipc)

```bash
sudo apt update
sudo apt install -y \
  autoconf automake build-essential ccache cmake cpufrequtils \
  doxygen ethtool g++ git inetutils-tools libboost-all-dev \
  libncurses-dev libusb-1.0-0 libusb-1.0-0-dev libusb-dev \
  python3-dev python3-mako python3-numpy python3-requests \
  python3-scipy python3-setuptools python3-ruamel.yaml \
  libsqlite3-dev libblas-dev libopenblas-dev \
  libhiredis-dev liblapacke-dev
```

### Docker (CN host — serber-firecell)

```bash
sudo apt install -y ca-certificates curl
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}") stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
sudo usermod -a -G docker $(whoami)
# Reboot required
```

---

## Build UHD from Source

> Only needed once per host. The UHD images downloader also fetches FPGA images for USRP B210.

```bash
git clone https://github.com/EttusResearch/uhd.git ~/uhd
cd ~/uhd
git checkout v4.8.0.0
cd host
mkdir build && cd build
cmake ../
make -j$(nproc)
make test || true
sudo make install
sudo ldconfig
sudo uhd_images_downloader
```

Verify:
```bash
sudo uhd_find_devices
```

---

## Build OAI nr-softmodem

```bash
git clone https://gitlab.eurecom.fr/oai/openairinterface5g.git ~/openairinterface5g
cd ~/openairinterface5g
git checkout 102965a669b9444857c27843ec8ce62780bf9d37

# Apply SIB8/PWS patch
git apply ~/cu-du/patches/oai-warning.patch

# Install dependencies
cd cmake_targets
sudo ./build_oai -I

# Build nr-softmodem
sudo ./build_oai -w USRP --ninja --gNB -C
```

> **Note:** DU build (serber-minipc) should use `-j4` cap due to limited cores/RAM.

---

## Patch Application

Patches are stored in `~/cu-du/patches/` and applied during the build step:

| Patch | Purpose | Used in CU/DU split |
|---|---|---|
| `oai-warning.patch` | SIB8/PWS transmission | **Yes** |
| `cross-cell.patch` | Cross-cell UE verification | **No** (UE-only) |

The patch is applied automatically by `roles/*/build.sh`.

---

## Repository Setup

On each host, clone the repo:

```bash
git clone https://github.com/promaaa/cu-du.git ~/cu-du
```

Or use the deployment scripts:

```bash
# On serber-firecell
~/cu-du/scripts/deploy-cu.sh

# On serber-minipc
~/cu-du/scripts/deploy-du.sh
```

---

## Core Network Setup

Download OAI CN5G configs:

```bash
wget -O ~/cu-du/source/oai-cn5g.zip \
  https://gitlab.eurecom.fr/oai/openairinterface5g/-/archive/develop/openairinterface5g-develop.zip?path=doc/tutorial_resources/oai-cn5g
unzip ~/cu-du/source/oai-cn5g.zip
mv ~/openairinterface5g-develop-doc-tutorial_resources-oai-cn5g/doc/tutorial_resources/oai-cn5g \
  ~/cu-du/source/oai-cn5g
rm -rf ~/openairinterface5g-develop*
```

Pull Docker images:
```bash
cd ~/cu-du/source/oai-cn5g
docker compose pull
```

Program SIM card:
```bash
sudo ./program_uicc --adm 12345678 \
  --imsi 001010000000001 --isdn 00000001 --acc 0001 \
  --key fec86ba6eb707ed08905757b1bb44b8f \
  --opc C42449363BBAD02B66D16BC975D77CC1 \
  -spn "OpenAirInterface" --authenticate
```
