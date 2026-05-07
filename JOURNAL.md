# CU/DU Debug Journal

## Date: 2026-05-07

## Issue: F1 Setup PLMN Mismatch

### Symptom
- CU logs: `PLMN mismatch: CU 000.0, DU 00101`
- DU sends F1_SETUP_REQUEST with PLMN read as 00101 instead of 001.001
- F1-C SCTP connection establishes successfully, but F1 Setup fails

### Root Cause Analysis

**Three bugs found and fixed:**

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

### Verification Results (2026-05-07)

**F1 Setup SUCCEEDED!**
```
CU Log:  PLMN: MCC=001, MNC=01 | cell PLMN 001.01 is in service
DU Log:  gNB_DU_name gNB-CU-FIRECELL | received F1 Setup Response
```

### USRP B210 Configuration

**Issue:** USRP serial was incorrect (`35F8ABA` instead of `8002816`)

**Fix:** Updated `du-cfg.yml`:
```yaml
usrp:
  serial: 8002816  # Correct serial from uhd_find_devices
```

**Verification:**
```
$ uhd_find_devices
-- UHD Device 0
    serial: 8002816
    name: Zhixun-wireless
    product: B210
    type: b200
```

**Current Status:**
- USRP B210 found with correct serial
- F1 Setup succeeds
- USRP sampling rate error persists: `unknown sampling rate 61440000.000000`

The USRP B210 sampling rate issue is a separate RF configuration problem.

### Commits Pushed
- `4a5b3f6` - Fix PLMN values in YAML: use string format with leading zeros
- `fa2d7a5` - Fix CU's Active_gNBs replacement
- `ca176ad` - Update JOURNAL: F1 Setup succeeded
- `86b5d31` - Fix USRP serial: 35F8ABA -> 8002816
