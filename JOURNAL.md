# CU/DU Debug Journal

## Date: 2026-05-07

## Summary: Making Repo Self-Contained and Reproducible

### Goal
Make the `cu-du` repo fully reproducible — any outside person can clone and deploy with minimal effort.

### Changes Made

#### 1. Fixed Hardcoded Paths in Scripts
- `roles/du/start.sh`: Removed hardcoded `/home/serber/cu-du` and `MONOLITHIC_OAI` references. Now uses `$HOME/cu-du`.
- `roles/cu/start.sh`: Removed `MONOLITHIC_OAI` fallback, now uses `source/openairinterface5g/` directly.
- `roles/all/start.sh`: Same cleanup as CU/DU.
- `roles/cu/build.sh`, `roles/du/build.sh`, `roles/all/build.sh`: Removed `MONOLITHIC_OAI` fallback, now clones OAI if not present.

#### 2. Fixed `generate-configs.py`
- Removed hardcoded `/home/serber/monolithic/openairinterface5g` paths
- Now uses `REPO_BASE` derived from `$HOME/cu-du`
- All paths relative to repo root

#### 3. Added Reference Configs to Repo
- `source/openairinterface5g/targets/PROJECTS/GENERIC-NR-5GC/CONF/cu_gnb.conf` (from OAI commit 102965a6)
- `source/openairinterface5g/targets/PROJECTS/GENERIC-NR-5GC/CONF/du_gnb.conf` (same)
- `source/oai-cn5g/` (docker-compose for core network)

#### 4. Added `sib8.conf` Template
- Created `sib8.conf` with default PWS warning message parameters

#### 5. Updated `du-cfg.yml`
- Added `clock_src: internal` to usrp section
- `generate-configs.py` now replaces `clock_src` in DU config

#### 6. Added `clock_src` and PRB Replacement to DU Config
- `generate-configs.py` now replaces:
  - `dl_carrierBandwidth` and `ul_carrierBandwidth` → 51 (10 MHz)
  - `initialDLBWPlocationAndBandwidth` and `initialULBWPlocationAndBandwidth` → 13053
  - `sdr_addrs` (with serial from du-cfg.yml)
  - `clock_src` (with value from du-cfg.yml)

#### 7. Added `.gitignore`
- Excludes build artifacts, downloaded sources, UHD build dir, logs

---

## Current Repo Structure

```
cu-du/
├── .gitignore
├── sib8.conf                          # PWS warning config
├── conf/
│   ├── cu-cfg.yml                     # CU parameters (IP, PLMN, AMF)
│   ├── du-cfg.yml                     # DU parameters (IP, USRP serial, band)
│   └── env.sh                         # Shared env vars (commit, UHD version)
├── source/
│   ├── openairinterface5g/            # OAI source (only CONF files stored here)
│   │   └── targets/PROJECTS/GENERIC-NR-5GC/CONF/
│   │       ├── cu_gnb.conf            # Reference CU config
│   │       └── du_gnb.conf            # Reference DU config
│   └── oai-cn5g/                      # Core Network (docker-compose)
│       ├── docker-compose.yaml
│       ├── conf/
│       └── database/
├── patches/
│   ├── oai-warning.patch               # SIB8/PWS patch
│   └── cross-cell.patch               # Not used in CU/DU split
├── roles/
│   ├── cu/                            # CU build + start scripts
│   ├── du/                            # DU build + start scripts
│   ├── all/                           # Monolithic (CU+DU on same host)
│   └── cn/                            # Core network only
├── scripts/
│   ├── generate-configs.py            # Generates gnb-cu.conf, gnb-du.conf from YAML
│   ├── deploy-cu.sh                   # SSH + deploy CU
│   ├── deploy-du.sh                   # SSH + deploy DU
│   └── check-health.sh                # Verify stack is running
├── INSTALL.md
├── RUN.md
├── SPLIT.md
└── PLAN-CU-DU.md
```

---

## Previous: F1 Setup Issue (RESOLVED earlier)

Bugs fixed before this session:
- PLMN values as strings with leading zeros (`"001"`/`"01"`)
- DU gNB name matching CU (`gNB-CU-FIRECELL`)
- Active_gNBs replacement in CU config
- USRP serial corrected to `8002816`
- DU template got `sdr_addrs` + `clock_src: "internal"`
- PRB reduced from 106 → 51 (10 MHz)

F1 Interface Status: OPERATIONAL (from earlier commits)

---

## Deployment Workflow

### Fresh Install on New Machine

```bash
# 1. Clone repo
git clone https://github.com/promaaa/cu-du.git ~/cu-du
cd ~/cu-du

# 2. Build OAI (downloads source, applies patch, compiles)
# For CU host (serber-firecell):
~/cu-du/roles/cu/build.sh

# For DU host (serber-minipc):
~/cu-du/roles/du/build.sh

# 3. Start (generates configs, starts binaries)
# On CU:
~/cu-du/roles/cu/start.sh

# On DU:
~/cu-du/roles/du/start.sh
```

### Config Generation

Configs are generated from YAML → OAI config via `generate-configs.py`:
- `source/openairinterface5g/targets/PROJECTS/GENERIC-NR-5GC/CONF/gnb-cu.conf`
- `source/openairinterface5g/targets/PROJECTS/GENERIC-NR-5GC/CONF/gnb-du.conf`

### Deployment Script

```bash
# Deploy CU to remote (SSH + clone + build)
~/cu-du/scripts/deploy-cu.sh

# Deploy DU to remote
~/cu-du/scripts/deploy-du.sh

# Check health
~/cu-du/scripts/check-health.sh
```

---

## Status: Ready for Push to GitHub

All fixes complete. Repo is self-contained and reproducible. Push to GitHub and update JOURNAL.