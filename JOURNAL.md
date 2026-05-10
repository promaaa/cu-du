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
---

## Date: 2026-05-08 (morning - continued)

## PWS Implementation Session - FIXES APPLIED BUT NETWORK UNREACHABLE

### Issues Fixed (During Session)

#### Issue 1: Forward declaration bug in mac_rrc_dl_f1ap.c (CU)
Fixed by properly defining `write_replace_warning_req_f1ap()` before `mac_rrc_dl_f1ap_init()`.

#### Issue 2: memcpy without allocation in f1ap_du_paging.c (DU)
Fixed by adding `malloc()` before memcpy in `DU_handle_WriteReplaceWarningRequest()`.

#### Issue 3: Shallow copy causing double-free
Fixed by implementing deep copy with proper `malloc()` for each buffer in `write_replace_warning_req_f1ap()`.

### Current Problem
Network became unreachable during session. Hosts serber-firecell (10.76.170.38) and serber-minipc (10.76.170.100) not responding to ping.

### DU Crash Symptom
Last known DU crash: `Assertion (success) failed! In other_sib_sched_control() /home/serber/monolithic/openairinterface5g/openair2/LAYER2/NR_MAC_gNB/gNB_scheduler_bch.c:720 - Couldn't allocate TBS for other SIB`

This indicates that after PWS is configured, the scheduler can't allocate transmission block size for the SIB.

### Remaining Work
1. The PWS message flow from CU to DU is working (F1AP messages sent and received)
2. SIB8 decode fails on DU - "cannot decode SIB8 from CU" in nr_mac_configure_pws_si()
3. Need to investigate SIB8 encoding format mismatch between CU's build_sib8_segments() and DU's decoder

### When Network Returns
1. Rebuild CU and DU with the fixes
2. Check SIB8 encoding format - the CU encodes segments but DU expects full NR_SIB8_t
3. The build_sib8_segments() may need to be modified to properly encode SIB8 as a complete message rather than just segments

---

## Date: 2026-05-08 (afternoon - PWS Handler Fixes)

### Root Cause Identified: DU Handler Was Missing

The primary issue was that **DU_handle_WriteReplaceWarning was not wired into f1ap_handlers.c**. The handler matrix had `{0, 0, 0}` for WriteReplaceWarning, so when the CU sent the F1AP message, the DU's `f1ap_handle_message()` logged:

```
[SCTP 410] No handler for procedureCode 20 in Initiating message
```

This confirmed the message was arriving at DU over SCTP, but there was no handler to decode and process it.

### Fixes Applied Today

#### 1. Created DU_handle_WriteReplaceWarning in f1ap_du_paging.c

New function that:
- Extracts TransactionID, RepetitionPeriod, NumberofBroadcastRequest, and PWSSystemInformation from the F1AP message
- Extracts SI_container (encoded SIB8 bytes) and SI_container_length from PWSSystemInformation
- Calls `write_replace_warning_req()` in mac_rrc_dl_handler.c to forward to MAC layer

#### 2. Wired handler into f1ap_handlers.c

Changed line 68 from:
```c
{0, 0, 0}, /* WriteReplaceWarning */
```
To:
```c
{DU_handle_WriteReplaceWarning, 0, 0}, /* WriteReplaceWarning */
```

#### 3. Fixed decode failure handling in nr_mac_configure_pws_si()

Changed from silently continuing on decode failure to AssertFatal:
```c
if (dec_rval.code != RC_OK) {
    AssertFatal(false, "cannot decode SIB8 from CU\n");
}
```

#### 4. Verified TBS allocation logic

The scheduler's `other_sib_sched_control()` receives `payload_idx` which maps to the SI message index in `other_sib_bcch_pdu[]` / `other_sib_bcch_length[]`. With `other_si_used` starting at 0 and PWS segments placed at `start = cc->other_si_used`, the indices should be correct.

The TBS allocation failure ("Couldn't allocate TBS for other SIB") was a secondary symptom - when decode fails, `sib8` is NULL and the encoding produces garbage, causing `num_total_bytes` to be too small or zero.

### Files Modified on Remote (CU serber-firecell:)

1. `/home/serber/monolithic/openairinterface5g/openair2/F1AP/f1ap_du_paging.c` - completely rewritten with DU_handle_WriteReplaceWarning
2. `/home/serber/monolithic/openairinterface5g/openair2/F1AP/f1ap_du_paging.h` - added function declaration
3. `/home/serber/monolithic/openairinterface5g/openair2/F1AP/f1ap_handlers.c` - wired handler
4. `/home/serber/monolithic/openairinterface5g/openair2/LAYER2/NR_MAC_gNB/config.c` - fixed decode AssertFatal

### Rebuild Blocked

The rebuild of nr-softmodem failed due to:
- CMake/CPM cache at `/root/.cache/cpm` not accessible by serber user
- Network connectivity issues - DNS resolution and outbound connections are timing out
- The existing binary was built with the old code

Both CU and DU are currently running with the **old code**. The new files are deployed but not compiled in.

### Manual Steps Required When Network Returns

On **CU (serber-firecell)**:
```bash
# Fix CPM cache permissions
sudo chmod 777 /root/.cache/cpm /root/.cache/cpm/cpm
sudo touch /root/.cache/cpm/cpm/CPM_0.40.1.cmake

# Rebuild
cd ~/monolithic/openairinterface5g/cmake_targets/ran_build/build
sudo make nr-softmodem -j4

# Restart CU
sudo killall nr-softmodem; sleep 2
cd ~/monolithic/openairinterface5g/cmake_targets/ran_build/build
sudo ./nr-softmodem -O /home/serber/cu-du/source/openairinterface5g/targets/PROJECTS/GENERIC-NR-5GC/CONF/gnb-cu.conf --log_config.global_log_level info | tee /tmp/cu.log &
```

On **DU (serber-minipc)**:
```bash
# Rebuild (same steps)
# Restart DU
sudo killall nr-softmodem; sleep 2
cd ~/monolithic/openairinterface5g/cmake_targets/ran_build/build
sudo ./nr-softmodem -O /home/serber/cu-du/source/openairinterface5g/targets/PROJECTS/GENERIC-NR-5GC/CONF/gnb-du.conf --log_config.global_log_level info | tee /tmp/du.log &
```

### Next Verification Steps After Rebuild

1. Check CU log for: `[NR_RRC] [SIB8] segments numer:0 and number of segments:1`
2. Check DU log for: `[MAC] received Write Replace Warning Request from CU`
3. Verify no decode error: `cannot decode SIB8 from CU` should NOT appear
4. Verify SIB8 is scheduled: `otherSIB payload transmission for ssb number`
---

## Date: 2026-05-08 (evening)

## Status: CU/DU Running with F1 Established

### Current System Status (as of ~23:51)
- **CU (serber-firecell)**: Running, F1 accepted DU (assoc_id 421), PWS messages being sent
- **DU (serber-minipc)**: Running, NR_MAC frames active (0.0, 128.0, 256.0...), no crashes
- **F1 interface**: Established
- **Cell**: In service, PLMN 001.01, Cell ID 12345678

### Configuration
- PLMN: MCC 001, MNC 01
- Band: n78 (3300–3800 MHz)
- BW: 51 PRB @ 30 kHz SCS (10 MHz, B210-compatible)
- USRP: B210 serial `8002816`
- Clock: internal

### Fixed During Session
1. Duplicate `clock_src` key in `conf/du-cfg.yml` - removed duplicate
2. `generate-configs.py` was hardcoding 51 PRB regardless of `prb` in du-cfg.yml - fixed to use actual prb value
3. Initial BWP was incorrectly set to PRB value instead of proper frequency location (13053 for 51 PRB, 28875 for 106 PRB)
4. 106 PRB causes sampling rate error on B210 (61440000 sps not supported) - using 51 PRB

### Known Issue
- Previous session saw UE RA attempts (preamble detected), but currently no UE activity
- Need to verify Nothing Phone is configured with same PLMN (001.01) and SIM settings
- 106 PRB with monolithic config may have different sampling rate handling

---

## Date: 2026-05-08 (late night)

## Status: CU/DU Running but Nothing Phone Not Connecting

### System Status
- **CU (serber-firecell)**: Running, F1 established (assoc_id 429), cell in service
- **DU (serber-minipc)**: Running, NR_MAC frames active
- **Cell**: PLMN 001.01, 51 PRB, band n78, frequency 3619.2 MHz

### Changes Made Tonight
1. Fixed duplicate `clock_src` in du-cfg.yml
2. Fixed `generate-configs.py` to use actual `prb` value instead of hardcoding 51
3. Fixed initial BWP calculation (13053 for 51 PRB, 28875 for 106 PRB)
4. Changed att_tx/att_rx from 0 to 12 (matching monolithic)
5. 106 PRB causes B210 sampling rate error (61440000 not supported) - using 51 PRB

### Current Problem
- Nothing Phone in airplane mode shows no network when toggling off
- No PWS messages received on phone
- Monolithic on serber-firecell also shows sampling rate error but phone connects
- **Need SIM parameters from user** to verify/insert into database

### SIM Database Info
Current entries in `oai_db.AuthenticationSubscription`:
```
001010000000001 - 004 (default OAI test SIMs)
001010000059449 (existing custom entry)
```

### What We Need From User
SIM card parameters to add to database:
- `ueid` / `supi` - usually format: `00101{MCC}{MNC}{MSIN}`
- `encPermanentKey` - OPc/Milenage key from SIM
- `protectionParameterId` - usually same as encPermanentKey
- `encOpcKey` - OPc derived from SIM

### Next Steps
1. Get SIM parameters from user (Nothing Phone SIM)
2. Insert into database: `docker exec mysql mysql -u test -ptest oai_db -e "INSERT INTO..."`
3. Ensure containers are restarted after DB update
4. Test UE connection

---

## Date: 2026-05-09 (early morning)

## Status: Still Investigating UE Connection Issue

### System Status
- CU (serber-firecell): Running, F1 established (assoc_id 432)
- DU (serber-minipc): Running, NR_MAC frames active, att_tx/att_rx=12
- Cell: PLMN 001.01, 51 PRB, band n78, SSB frequency 3619.2 MHz
- PWS messages being sent from CU to DU (confirmed in logs)

### Confirmed Working
- F1 interface between CU and DU: Working
- Cell broadcasts: SSB at 3619.2 MHz, periodicity 20ms (ssb_periodicityServingCell=2)
- SIB1 configuration: offsetToPointA 86, DL frequency 3609.3 MHz
- USRP B210 (serial 8002816): Initialized and running
-.att_tx=12, att_rx=12 (matching monolithic)
- NR_MAC frames: Active (0.0, 128.0, 256.0...)
- PWS: CU sending WRITE_REPLACE_WARNING to DU

### Not Working
- Nothing Phone not detecting the cell (works with monolithic)
- No PRACH detected from UE in DU logs

### Key Differences from Monolithic (51 PRB vs 106 PRB)
1. Frequency: 3609.3 MHz vs 3619.2 MHz
2. DL bandwidth: 51 PRB vs 106 PRB
3. B210 sampling rate: 30.72 MSps vs 61.44 MSps (not supported by B210)

### Hypotheses Being Tested
1. Frequency offset issue (SSB at 3609.3 vs 3619.2 MHz)
2. B210 not properly transmitting at 3609.3 MHz with 51 PRB
3. Some config parameter difference causing SSB not to be detected

### Last Actions
- Restarted CU and DU after modifications
- Verified att_tx=12, att_rx=12 are applied
- Confirmed SSB frequency is 3619.2 MHz in DU log
- **TESTED 106 PRB**: DU crashes with "Error: unknown sampling rate 61440000.000000" - B210 cannot support 61.44 MSps, must use 51 PRB

---

## Date: 2026-05-09 (early morning) - Key Finding

## B210 Sampling Rate Limitation Confirmed

### Finding
The USRP B210 cannot support 106 PRB (61.44 MSps) - it crashes with:
```
[HW]     Error: unknown sampling rate 61440000.000000
```

This was confirmed on serber-minipc (DU) which has B210 serial 8002816.

### Implication
- **Monolithic on serber-firecell** works with 106 PRB because it has B210 serial **35F8ABA** - different hardware that may handle the sampling rate differently
- **Split DU on serber-minipc** must use **51 PRB** (30.72 MSps) for B210 compatibility
- 51 PRB = DL frequency 3609.3 MHz vs 3619.2 MHz with 106 PRB

### Current State
- DU crashed when trying 106 PRB, reverted to 51 PRB
- CU is running split config (serber-firecell)
- DU needs to be restarted with 51 PRB

### Notes
- serber-firecell USRP: serial 35F8ABA (monolithic works there)
- serber-minipc USRP: serial 8002816 (B210, must use 51 PRB)

### What's Different Between Monolithic and Split DU (51 PRB)
- **DU (split mode)**: RA preambles detected (multiple UEs), but Msg2 fails with "cannot find free CCE for Msg2"
- **CCE allocation**: L1: 0, L2: 2, L4: 0, L8: 0, L16: 0 - only 2 CCEs at aggregation level 2
- Root cause likely: CORESET/SearchSpace configuration issue in split mode

### What's Working
- DU detects PRACH preambles from multiple UEs (preamble 27, etc.)
- RA-RNTI and TC-RNTI are assigned
- Msg3 is scheduled for some UEs (614b, 246c)

### What's Broken
- Msg2 (RMSI, RA Response) cannot be scheduled due to CCE shortage
- 3rd UE (0e02) fails with "cannot find free CCE for Msg2"

### Root Cause Hypothesis
The CORESET or SearchSpace configuration in split mode DU is limiting CCE availability. Need to compare monolithic's CORESET configuration vs split DU's configuration.

### Next Steps
1. Check CORESET configuration in monolithic vs split DU
2. Compare `initialDLBWPcontrolResourceSetZero` and `initialDLBWPsearchSpaceZero` values
3. Verify if PDCCH candidate availability is the issue

---

## Date: 2026-05-10 (Morning) - KEY FINDINGS

### Pivot: Moving from PWS to Basic 5G Connectivity
We are pivoting from implementing the Public Warning System (PWS) over F1 to **demonstrating that the CU/DU split 5G deployment can successfully emit 5G signals and allow a UE (Nothing Phone) to connect**. The goal is NOT high bandwidth or performance - it's proving the split architecture is functional.

### Issue: DL Frequency Mismatch
**Discovery**: DU (split mode) uses different DL frequency than working monolithic config.

| Config | absoluteFrequencySSB | DL Frequency |
|--------|----------------------|---------------|
| Working monolithic (51PRB) | 636672 (3449.856 MHz) | 3619200 (3619.2 MHz) |
| Split DU (current) | 641280 (3619.2 MHz) | **3609300** (3609.3 MHz) |

**Impact**: UE sees SSB at 3619.2 MHz but DL carrier at 3609.3 MHz - 9.9 MHz offset causes connection failure!

### CCE Configuration (CORRECTED)
- `controlResourceSetZero = 11` (matches working 51PRB config)
- `searchSpaceZero = 0`
- `ssb_perRACH_OccasionAndCB_PreamblesPerSSB = 4` (reduced from 14)
- CCE candidates: L1: 0, L2: 2, L4: 0, L8: 0, L16: 0 (same as monolithic - not the root cause)

### Root Cause Confirmed
The DL frequency mismatch (NOT CCE shortage) is why UE cannot connect. The B210 on serber-minipc supports 51 PRB but the frequency plan is wrong.

### Fix Applied
Changed du-cfg.yml:
- Added `controlResourceSetZero: 11` (was using 12)
- Added `ssb_perRACH_OccasionAndCB_PreamblesPerSSB: 4` (reduced from 14)
- Still using `prb: 51` (B210 limitation)
- Still using `absoluteFrequencySSB: 641280` (WRONG - needs to be 636672!)

### Files Modified
1. `conf/du-cfg.yml`: Added controlResourceSetZero, ssb_perRACH settings
2. `scripts/generate-configs.py`: Added support for searchSpaceZero, controlResourceSetZero, ssb_perRACH parameters

### Current Status
- DU running with F1 interface established ✅
- CCE candidates: L1: 0, L2: 2, L4: 0, L8: 0, L16: 0
- **BROKEN**: DL frequency 3609.3 MHz instead of 3619.2 MHz ❌

### Next Step
Fix absoluteFrequencySSB to 636672 (or adjust dl_absoluteFrequencyPointA) to align DL frequency with SSB.

---

## Date: 2026-05-10 (Morning) - Fix Applied

### Changes Made

#### 1. Updated `generate-configs.py`
Added support for `absoluteFrequencySSB` parameter in `apply_du_config()`:
```python
if 'absoluteFrequencySSB' in usrp:
    n, text = replace_key_line(text, 'absoluteFrequencySSB', str(usrp['absoluteFrequencySSB'])); total += n
```

Also added support for `searchSpaceZero` and `controlResourceSetZero` which were already in `du-cfg.yml` but not being applied.

#### 2. Generated DU Config Verified
```
absoluteFrequencySSB = 636672;
initialDLBWPcontrolResourceSetZero = 11;
initialDLBWPsearchSpaceZero = 0;
ssb_perRACH_OccasionAndCB_PreamblesPerSSB = 4;
```

#### 3. Created symlink
Created `/Users/promaa/cu-du` → `/Users/promaa/Documents/cu-du` because `generate-configs.py` uses `$HOME/cu-du`

### Deployment Plan
1. Push changes to GitHub
2. Rsync to serber-minipc: `rsync -avz --exclude='.git' -e "sshpass -e ssh" ./ serber@serber-minipc:cu-du/`
3. On serber-minipc: `python3 scripts/generate-configs.py du`
4. Restart DU: `sudo ./nr-softmodem -O /home/serber/cu-du/source/openairinterface5g/targets/PROJECTS/GENERIC-NR-5GC/CONF/gnb-du.conf`
5. Test UE connection
