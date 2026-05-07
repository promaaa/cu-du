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

## Previous: F1 Setup Issue - RESOLVED

Bugs fixed (documented in earlier commits):
- PLMN values as strings with leading zeros (`"001"`/`"01"`)
- DU gNB name matching CU (`gNB-CU-FIRECELL`)
- Active_gNBs replacement in CU config
- USRP serial corrected to `8002816`
- DU template got `sdr_addrs` + `clock_src: "internal"`
- PRB reduced from 106 → 51 (10 MHz)

### Verification Results

**CU Log:**
```
[NR_RRC] Accepting DU 3584 (gNB-CU-FIRECELL), sending F1 Setup Response
cell PLMN 001.01 Cell ID 12345678 is in service
```

**DU Log:**
```
[NR_MAC] Frame.Slot 0.0
[F1AP] DU_send_F1_SETUP_REQUEST
[MAC] received F1 Setup Response from CU gNB-CU-FIRECELL
```

### Status: F1 Interface Operational

Both CU and DU are running and F1 Setup succeeded.

### Commits Pushed
- `4a5b3f6` - Fix PLMN values in YAML
- `fa2d7a5` - Fix CU's Active_gNBs replacement
- `86b5d31` - Fix USRP serial: 8002816
- `9dd3860` - Add clock_src and prb to DU config for B210 compatibility

---

## Date: 2026-05-07 (afternoon)

## Issue: Sync repo with working remote config - COMPLETED

### Summary
Repo now accurately reflects the working remote state after manual modifications on DU.

### What was synced to repo:
- `conf/du-cfg.yml`: Added `clock_src: "internal"` and `prb: 51` under `usrp:`
- `scripts/generate-configs.py`: Added `clock_src` replacement in `apply_du_config()`
- `README.md`: Updated USRP serial from `35F8ABA` to `8002816`, BW from 106 PRB to 51 PRB

### Current Working Configuration

| Parameter | Value |
|---|---|
| PLMN | MCC 001, MNC 01 |
| Band | n78 (3300–3800 MHz) |
| BW | 51 PRB @ 30 kHz SCS (10 MHz, B210-compatible) |
| USRP | B210 serial `8002816` |
| clock_src | internal |
| CU gNB Name | gNB-CU-FIRECELL |
| DU gNB Name | gNB-CU-FIRECELL (both must match for F1) |

### Hosts
| Host | IP | Role |
|---|---|---|
| serber-firecell | 10.76.170.38 | CU + Core Network |
| serber-minipc | 10.76.170.100 | DU + USRP B210 |

### Deployment Workflow
1. Develop locally at `/Users/promaa/Documents/cu-du/`
2. Push to GitHub: `git push origin main`
3. Rsync to remotes: `rsync -avz --exclude='.git' -e "sshpass -e ssh" ./ serber@HOST:cu-du/`
4. On remotes: `cd ~/cu-du && python3 scripts/generate-configs.py cu|du`
5. Restart binaries

### Next Steps
- [ ] Implement F1AP_WRITE_REPLACE_WARNING_REQUEST in CU->DU F1 interface
- [ ] Test 5G registration with UE
- [ ] Document any issues in JOURNAL

---

## Date: 2026-05-07 (evening)

## Issue: PWS/SIB8 not transmitted over F1 - ANALYZED

### Summary
PWS is triggered in CU but F1AP doesn't forward it to DU. The `write_replace_warning_req_trigger()` is called in `rrc_gNB_du.c:496` after F1 setup, but the F1AP layer does not have an implementation to send `WRITE_REPLACE_WARNING_REQUEST` to the DU over F1.

### Current Behavior
1. CU monitors `sib8.conf` via timer (every 5 seconds)
2. On change, calls `write_replace_warning_req_trigger(assoc_id)` with DU's assoc_id
3. `write_replace_warning_req_trigger()` calls `rrc->mac_rrc.write_replace_warning_req(assoc_id, &wrw)`
4. BUT the CU's mac_rrc callback `write_replace_warning_req_direct()` just does `AssertFatal(assoc_id == -1)` - meaning it only works in **monolithic** mode (assoc_id -1), not in split mode with real DU association

### Root Cause
The PWS implementation was designed for monolithic mode where the MAC layer is local. In CU/DU split mode, the F1AP layer needs to encode and send `WRITE_REPLACE_WARNING_REQUEST` over F1, but this is not implemented.

### Missing Implementation
- `f1ap_cu.c` / CU task needs to handle PWS trigger
- Encode `WRITE_REPLACE_WARNING_REQUEST` F1AP message
- Send over SCTP assoc_id (not -1)
- DU side needs to decode and forward to MAC

### F1AP ASN1 definitions exist
The ASN1 definitions for `WriteReplaceWarningRequest/Response` are present in `F1AP-PDU-Contents.asn`. The F1AP encoding/decoding infrastructure exists. The missing piece is calling it from the PWS trigger path.

### Current Status
- F1 Interface: **WORKING** (PLMN match, DU registered to CU)
- PWS trigger in CU: **TRIGGERING** (but only in monolithic mode, assoc_id=-1)
- F1AP PWS forwarding: **NOT IMPLEMENTED**

### Commits Pushed
- `5584bd1` - Update JOURNAL: sync repo with working remote, document current config

---

## Current Working State (as of 2026-05-07 evening)

### System Status
- CU on serber-firecell: **Running** (F1AP listening, AMF registered)
- DU on serber-minipc: **Running** (NR_MAC frames, USRP B210 active)
- F1 interface: **Established** (assoc_id 355)
- Core Network (docker): **Running** (AMF, SMF, UPF, etc.)

### Verified Working
- F1 Setup completes successfully
- PLMN 001.01 matches between CU and DU
- Cell in service: `cell PLMN 001.01 Cell ID 12345678 is in service`
- NR_MAC running frames (0.0, 128.0, 256.0...)

### sib8.conf on CU
```
messageIdentifier=1112;
serialNumber=FF00;
dataCodingScheme=48;
text=Hello this is serber-firecell;
mode=0;
```

### Deployment Commands (for reference)
```bash
# Rsync to both hosts
export SSHPASS='root4SERBER'
rsync -avz --exclude='.git' -e "sshpass -e ssh -o StrictHostKeyChecking=no" /Users/promaa/Documents/cu-du/ serber@serber-minipc:cu-du/
rsync -avz --exclude='.git' -e "sshpass -e ssh -o StrictHostKeyChecking=no" /Users/promaa/Documents/cu-du/ serber@serber-firecell:cu-du/

# On serber-minipc (DU) - stop old, generate config, start new
sshpass -e ssh serber@serber-minipc
sudo killall nr-softmodem; sleep 2
cd ~/cu-du && python3 scripts/generate-configs.py du
cd ~/monolithic/openairinterface5g/cmake_targets/ran_build/build && nohup sudo ./nr-softmodem -O /home/serber/monolithic/openairinterface5g/targets/PROJECTS/GENERIC-NR-5GC/CONF/gnb-du.conf --log_config.global_log_level info > /tmp/du.log 2>&1 &

# On serber-firecell (CU) - stop old, generate config, start new (with CN)
sshpass -e ssh serber@serber-firecell
sudo killall nr-softmodem; sleep 2
cd ~/cu-du && python3 scripts/generate-configs.py cu
cd ~/monolithic/openairinterface5g/cmake_targets/ran_build/build && nohup sudo ./nr-softmodem -O /home/serber/monolithic/openairinterface5g/targets/PROJECTS/GENERIC-NR-5GC/CONF/gnb-cu.conf --log_config.global_log_level info > /tmp/cu.log 2>&1 &
```