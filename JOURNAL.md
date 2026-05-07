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
The remote's `cu-cfg.yml` and `du-cfg.yml` had:
```yaml
plmn:
  mcc: 1    # Integer, not string
  mnc: 1    # Integer, not string
```

When `replace_plmn_list()` does `f'mcc = {mcc}'` with integer `1`, it outputs `mcc = 1` instead of `mcc = 001` (3-digit MCC format expected by OAI).

**Fix:** Changed to quoted strings with leading zeros:
```yaml
plmn:
  mcc: "001"   # String with leading zeros
  mnc: "01"    # String with leading zeros
```

#### Bug 2: DU's gNB_Name mismatch
DU's `gnb_name` was `gNB-DU-MINIPC` instead of `gNB-CU-FIRECELL`. For F1 Setup to succeed, DU's `gNB_Name` must match CU's `Active_gNBs`.

**Fix:** Changed `du-cfg.yml` gnb_name to `gNB-CU-FIRECELL`.

#### Bug 3: CU's Active_gNBs not being replaced
The `apply_cu_config()` function was missing the `Active_gNBs` replacement, leaving it as template value `gNB-Eurecom-CU` while DU was using `gNB-CU-FIRECELL`.

**Fix:** Added `Active_gNBs` replacement in `apply_cu_config()`:
```python
n, text = replace_key_line(text, 'Active_gNBs', f'( "{cu["gnb_name"]}")'); total += n
```

### Verification

Both configs now show consistent values:
```
# CU config
Active_gNBs = ( "gNB-CU-FIRECELL");
gNB_name  =  "gNB-CU-FIRECELL";
plmn_list = ({ mcc = 001; mnc = 01; mnc_length = 2; snssaiList = ({ sst = 1 }) });

# DU config
Active_gNBs = ( "gNB-CU-FIRECELL");
gNB_name  =  "gNB-CU-FIRECELL";
plmn_list = ({ mcc = 001; mnc = 01; mnc_length = 2; snssaiList = ({ sst = 1 }) });
```

### Next Steps
1. Sync to serber-minipc when it becomes available
2. Restart CU binary on serber-firecell
3. Restart DU binary on serber-minipc
4. Verify F1 Setup succeeds

### Commits
- `4a5b3f6` - Fix PLMN values in YAML: use string format with leading zeros (001/01)
- `63878d2` - Fix CU's Active_gNBs replacement in apply_cu_config()
