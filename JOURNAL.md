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
