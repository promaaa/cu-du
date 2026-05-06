# CU/DU Split Repository Plan

## 1. Overview

Migrate from the current monolithic OAI 5G NR setup (single-host CU+DU+CN on `serber-firecell`) to a distributed CU/DU split topology across two servers:
- **serber-firecell** (`10.76.170.38`): CU + Core Network (CN)
- **serber-minipc** (`10.76.170.100`): DU + USRP B210 (serial 35F8ABA)

F1 transport uses the existing LAN (no new interfaces). SIB8/PWS warning transmission traverses F1 from CU to DU.

---

## 2. Repo Structure

```
~/cu-du/
├── README.md
├── RUN.md
├── SPLIT.md                    # 3GPP F1/E1 architecture docs
├── INSTALL.md                   # Dependencies, UHD build, OAI build, patches
│
├── source/                     # OAI source (cloned from gitlab.eurecom.fr)
│   ├── openairinterface5g/    # commit 102965a669b9444857c27843ec8ce62780bf9d37
│   │   ├── sib8.conf
│   │   └── targets/PROJECTS/GENERIC-NR-5GC/CONF/
│   │       ├── gnb-cu.conf    # rendered from conf/cu-cfg.yml
│   │       └── gnb-du.conf    # rendered from conf/du-cfg.yml
│   └── oai-cn5g/             # Core Network (docker-compose)
│
├── conf/
│   ├── cu-cfg.yml
│   ├── du-cfg.yml
│   └── env.sh
│
├── roles/
│   ├── cu/                   # CU binary + CN (docker compose)
│   │   ├── build.sh
│   │   ├── start.sh          # starts CU binary then CN
│   │   ├── stop.sh
│   │   └── config/
│   ├── du/                   # DU binary + USRP
│   │   ├── build.sh
│   │   ├── start.sh
│   │   ├── stop.sh
│   │   └── config/
│   ├── all/                  # CU+DU on same host (monolithic)
│   │   ├── build.sh
│   │   ├── start.sh
│   │   ├── stop.sh
│   │   └── config/
│   └── cn/                   # CN-only (for standalone CN restarts)
│       ├── start.sh
│       ├── stop.sh
│       └── health-check.sh
│
├── scripts/
│   ├── generate-configs.sh    # renders gnb-cu.conf / gnb-du.conf from YAML
│   ├── deploy-cu.sh            # SSH clone + build to serber-firecell
│   ├── deploy-du.sh            # SSH clone + build to serber-minipc
│   ├── deploy-all.sh
│   └── check-health.sh
│
└── patches/
    ├── oai-warning.patch      # SIB8/PWS patch
    └── cross-cell.patch       # NOT used in CU/DU split (UE-only)
```

---

## 3. Network Design

### 3.1 IP Assignments

| Interface | Role | Host | IP |
|---|---|---|---|
| F1-C (CU) | CU control plane listen | serber-firecell | `10.76.170.38:2152` |
| F1-C (DU) | DU control plane connect | serber-minipc | `10.76.170.100:2152` |
| F1-U (CU) | CU user plane (separate socket) | serber-firecell | `10.76.170.39` |
| F1-U (DU) | DU user plane (separate socket) | serber-minipc | `10.76.170.101` |
| NG (CU) | CU → AMF | serber-firecell | `192.168.70.129` |
| AMF | Core Network | serber-firecell (docker) | `192.168.70.132` |

> **F1-U decision**: F1-U uses a **separate socket/IP** from F1-C (`local_n_address` vs `local_s_address` in OAI config).

### 3.2 Cell / Radio Parameters

| Parameter | Value |
|---|---|
| PLMN | MCC 001, MNC 01 |
| Band | n78 (3300–3800 MHz, TDD) |
| BW | 106 PRB @ 30 kHz SCS |
| AbsoluteFrequencySSB | 641280 (3619.2 MHz) |
| physCellId | 0 |
| TAC | 1 |
| USRP (DU) | B210 serial `35F8ABA` |

### 3.3 USRP Assignments

| Role | Host | USRP | Serial |
|---|---|---|---|
| DU (RF) | serber-minipc | B210 | `35F8ABA` |
| (unused) | serber-firecell | B210 | `8002816` |

---

## 4. Config File Templates

### 4.1 `conf/cu-cfg.yml`

```yaml
host: serber-firecell
role: cu
plmn:
  mcc: 001
  mnc: 01
  mnc_length: 2
amf:
  ip: 192.168.70.132
  port: 38412
cu:
  f1c_ip: 10.76.170.38
  f1c_port: 2152
  f1u_ip: 10.76.170.39
  ng_ip: 192.168.70.129
  gnb_id: 0xe00
  gnb_name: gNB-CU-FIRECELL
  tac: 1
```

### 4.2 `conf/du-cfg.yml`

```yaml
host: serber-minipc
role: du
plmn:
  mcc: 001
  mnc: 01
  mnc_length: 2
cu:
  f1c_ip: 10.76.170.100
  f1c_port: 2152
  f1u_ip: 10.76.170.101
  remote_f1c_ip: 10.76.170.38
  remote_f1c_port: 2152
  gnb_id: 0xe00
  gnb_du_id: 0xe00          # shared with CU (same gNB), 3GPP allows this
  gnb_name: gNB-DU-MINIPC
  tac: 1
usrp:
  type: b200
  serial: 35F8ABA
  band: 78
  max_pdschReferenceSignalPower: -27
  max_rxgain: 114
  att_tx: 0
  att_rx: 0
```

### 4.3 `conf/env.sh`

```bash
#!/bin/bash
# Shared environment variables

export OAI_COMMIT=102965a669b9444857c27843ec8ce62780bf9d37
export UHD_VERSION=v4.8.0.0
export LOG_DIR=/tmp
export CU_DU_BASE=~/cu-du

# F1 subnet (existing LAN)
export F1_SUBNET=10.76.170.0/25

# CU host
export CU_IP=10.76.170.38
export CU_HOST=serber-firecell

# DU host
export DU_IP=10.76.170.100
export DU_HOST=serber-minipc

# NTP
export NTP_IP=10.76.170.1
```

---

## 5. Config Generation

`scripts/generate-configs.sh` reads `conf/cu-cfg.yml` / `conf/du-cfg.yml` using Python + ruamel.yaml and renders:

- `source/openairinterface5g/targets/PROJECTS/GENERIC-NR-5GC/CONF/gnb-cu.conf`
- `source/openairinterface5g/targets/PROJECTS/GENERIC-NR-5GC/CONF/gnb-du.conf`

These are libconfig files derived from the YAML vars. The script is called by role `start.sh` scripts before binary startup.

Key OAI config differences for CU vs DU:

| Parameter | CU | DU |
|---|---|---|
| `local_s_address` | `10.76.170.38` (F1-C) | `10.76.170.100` (F1-C) |
| `local_n_address` | `10.76.170.39` (F1-U) | `10.76.170.101` (F1-U) |
| `remote_s_address` | — | `10.76.170.38` (CU F1-C) |
| `ru_config` | absent (no USRP) | USRP + RF params |
| `tr_server` | AMF/NGAP config | absent |
| `F1AP.mode` | `cu` | `du` |

---

## 6. Role Scripts

### 6.1 `roles/cu/build.sh`

1. Clone OAI source to `$CU_DU_BASE/source/openairinterface5g` (if not present)
2. `git checkout 102965a669b9444857c27843ec8ce62780bf9d37`
3. `git apply patches/oai-warning.patch`
4. Build UHD from source (first time only, detect via `uhd_find_devices` check)
5. `./build_oai -I` (install deps)
6. `./build_oai -w USRP --ninja --gNB -C` (CU = RRC+PDCP+SDAP — lighter build, `$(nproc)` parallelism OK)
7. Copy `sib8.conf` to source tree

### 6.2 `roles/cu/start.sh`

1. `source ../../conf/env.sh`
2. `scripts/generate-configs.sh cu`
3. Start CN: `docker compose -f $CU_DU_BASE/source/oai-cn5g/docker-compose.yml up -d`
4. Wait for CN healthy (~20s)
5. Start CU binary:
   ```
   ./nr-softmodem -O gnb-cu.conf --log_config.global_log_level info
   ```
6. Log to `$LOG_DIR/cu.log`

### 6.3 `roles/du/build.sh`

1. Clone OAI source to `$CU_DU_BASE/source/openairinterface5g` (if not present)
2. `git checkout 102965a669b9444857c27843ec8ce62780bf9d37`
3. `git apply patches/oai-warning.patch`
4. Build UHD from source (first time only)
5. `./build_oai -I`
6. `./build_oai -w USRP --ninja --gNB -C -j4` (**capped at -j4** for minipc's 4 cores / 15 GB RAM)
7. Copy `sib8.conf` to source tree

### 6.4 `roles/du/start.sh`

1. `source ../../conf/env.sh`
2. `scripts/generate-configs.sh du`
3. Start DU binary:
   ```
   ./nr-softmodem -O gnb-du.conf --log_config.global_log_level info
   ```
4. Log to `$LOG_DIR/du.log`

### 6.5 `roles/all/start.sh`

Combines CU + DU startup on same host (monolithic mode for pre-split testing):
1. Generate both configs
2. Start CN
3. Start CU binary with CU config
4. Start DU binary with DU config (separate process)
5. Both log to same `$LOG_DIR/gnb.log`

### 6.6 `roles/cn/start.sh` / `stop.sh`

Pure CN control (for standalone CN restarts without CU binary):
```bash
docker compose -f $CU_DU_BASE/source/oai-cn5g/docker-compose.yml $1
```

---

## 7. Deployment Scripts

### 7.1 `scripts/deploy-cu.sh`

1. SSH to `serber-firecell`
2. Clone repo: `git clone https://github.com/promaaa/cu-du.git ~/cu-du`
3. Run `roles/cu/build.sh`
4. (First time only) Build UHD from source

### 7.2 `scripts/deploy-du.sh`

1. SSH to `serber-minipc`
2. Clone repo: `git clone https://github.com/promaaa/cu-du.git ~/cu-du`
3. Run `roles/du/build.sh`
4. Build UHD from source

### 7.3 `scripts/check-health.sh`

```bash
# CU process
ssh serber-firecell "ps aux | grep nr-softmodem | grep -v grep"

# DU process
ssh serber-minipc "ps aux | grep nr-softmodem | grep -v grep"

# CN containers
ssh serber-firecell "docker compose -f ~/cu-du/source/oai-cn5g/docker-compose.yml ps"

# F1 link
ssh serber-firecell "grep 'F1 Setup\|f1_setup_response' $LOG_DIR/cu.log"
ssh serber-minipc "grep 'F1 Setup\|f1_setup_response' $LOG_DIR/du.log"

# AMF registered
ssh serber-firecell "grep 'NGAP_REGISTER_GNB_CNF' $LOG_DIR/cu.log"

# SIB8 transmitted
ssh serber-firecell "grep 'SIB8\|write_replace_warning' $LOG_DIR/cu.log"
ssh serber-minipc "grep 'SIB8\|write_replace_warning' $LOG_DIR/du.log"

# UE attached
ssh serber-minipc "grep 'RRC_CONNECTED\|in-sync' $LOG_DIR/du.log"
```

---

## 8. Deployment Scenarios

| Scenario | serber-firecell | serber-minipc |
|---|---|---|
| **A — Full split (production)** | `roles/cu/start.sh` | `roles/du/start.sh` |
| **B — CU-only (no DU, testing)** | `roles/cu/start.sh` | — |
| **C — DU-only (no CU, testing)** | — | `roles/du/start.sh` |
| **D — All-in-one (monolithic)** | `roles/all/start.sh` | — |

---

## 9. SIB8 / PWS Flow in CU/DU Split

```
1. DU starts → connects to CU F1-C at 10.76.170.38:2152
2. F1 Setup exchange (CU ← DU)
3. CU registers with AMF at 192.168.70.132
4. CU sends Write Replace Warning Request to DU over F1-C
   (CU builds SIB8 segments in RRC, sends via F1AP Write-Replace-Warning-Request)
5. DU receives warning request → calls write_replace_warning_req()
   → nr_mac_configure_pws_si() → schedules SIB8 over the air via USRP B210
6. UE receives SIB8 and displays emergency alert
```

---

## 10. Key Decisions Summary

| Decision | Choice |
|---|---|
| F1-U socket | Separate from F1-C (`local_n_address` / `local_address`) |
| F1-C IPs | CU: `10.76.170.38`, DU: `10.76.170.100` |
| F1-U IPs | CU: `10.76.170.39`, DU: `10.76.170.101` |
| AMF reachability | Both PCs on same Ethernet hub — existing route confirmed |
| DU build parallelism | Cap at `-j4` (minipc: 4 cores / 15 GB RAM) |
| gnb_du_id | `0xe00` (same as CU, user confirmed) |
| CN orchestration | CN started automatically by `roles/cu/start.sh` |
| cross-cell.patch | NOT used in CU/DU split (UE-only feature) |
| Patch application | At build time, not at repo clone time |

---

## 11. Implementation Order

```
Step 1 — Create repo structure (all directories + README/RUN/INSTALL/SPLIT stubs)
Step 2 — Write conf/env.sh, conf/cu-cfg.yml, conf/du-cfg.yml
Step 3 — Write scripts/generate-configs.sh
Step 4 — Write roles/cu/{build,start,stop}.sh
Step 5 — Write roles/du/{build,start,stop}.sh
Step 6 — Write roles/all/{build,start,stop}.sh
Step 7 — Write roles/cn/{start,stop,health-check}.sh
Step 8 — Write scripts/deploy-cu.sh, deploy-du.sh, deploy-all.sh, check-health.sh
Step 9 — Write SPLIT.md (adapt from OAI doc/F1AP.md + 3GPP TS 38.470/38.473)
Step 10 — Push to GitHub
```

---

## 12. Verification

After deployment, `scripts/check-health.sh` verifies:

1. CU process alive: `ps aux | grep nr-softmodem | grep -v grep`
2. DU process alive: `ps aux | grep nr-softmodem | grep -v grep`
3. CN containers healthy: `docker compose ps`
4. F1 link established: `grep "F1 Setup" cu.log du.log`
5. AMF registered: `grep "NGAP_REGISTER_GNB_CNF" cu.log`
6. SIB8 transmitted: `grep "SIB8\|write_replace_warning" cu.log du.log`
7. UE attached: `grep "RRC_CONNECTED\|in-sync" du.log`
