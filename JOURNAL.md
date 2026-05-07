# CU/DU Debug Journal

## Date: 2026-05-07

## Issue: F1 Setup PLMN Mismatch - RESOLVED

### Summary
Successfully fixed F1 PLMN mismatch and got CU/DU running with F1 interface established.

### Bugs Fixed

#### Bug 1: PLMN values as integers instead of strings with leading zeros
Changed `cu-cfg.yml` and `du-cfg.yml` from:
```yaml
plmn:
  mcc: 1    # Integer
  mnc: 1    # Integer
```
To:
```yaml
plmn:
  mcc: "001"   # String with leading zeros
  mnc: "01"    # String with leading zeros
```

#### Bug 2: DU's gNB_Name mismatch
Changed `du-cfg.yml` gnb_name from `gNB-DU-MINIPC` to `gNB-CU-FIRECELL`.

#### Bug 3: CU's Active_gNBs not being replaced
Added missing `Active_gNBs` replacement in `apply_cu_config()`:
```python
n, text = replace_key_line(text, 'Active_gNBs', f'( "{cu["gnb_name"]}")'); total += n
```

#### Bug 4: USRP serial incorrect
Changed `du-cfg.yml` USRP serial from `35F8ABA` to `8002816`.

#### Bug 5: DU template missing sdr_addrs and clock_src
Added to `du_gnb.conf` template:
```
sdr_addrs = "serial=8002816";
clock_src = "internal";
```

#### Bug 6: USRP B210 PRB configuration
Changed from 106 PRB to 51 PRB (10 MHz) because B210 only supports specific sample rates.

### Final Configuration
- **Band**: n78
- **PRB**: 51 (10 MHz bandwidth)
- **SCS**: 30 kHz
- **DU with USRP B210 serial 8002816**

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
- [ ] Verify PWS/SIB8 transmission works end-to-end
- [ ] Test 5G registration with UE
- [ ] Document any issues in JOURNAL
