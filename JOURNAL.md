# CU/DU Debug Journal

## Date: 2026-05-07

## Issue: F1 Setup PLMN Mismatch

### Symptom
- CU logs: `PLMN mismatch: CU 000.0, DU 00101`
- DU sends F1_SETUP_REQUEST with PLMN read as 00101 instead of 001.001
- F1-C SCTP connection establishes successfully, but F1 Setup fails

### Root Cause Analysis

The remote repository (origin/main) has a more sophisticated template-based `generate-configs.py` that:
1. Uses OAI reference configs (`cu_gnb.conf`, `du_gnb.conf`) as templates
2. Uses `replace_plmn_list()` to modify PLMN values in-place

**Problem 1:** The remote's `du-cfg.yml` and `cu-cfg.yml` had:
```yaml
plmn:
  mcc: 1    # Integer, not string
  mnc: 1    # Integer, not string
```

When `replace_plmn_list()` does `f'mcc = {mcc}'` with integer `1`, it outputs `mcc = 1` instead of `mcc = 001` (3-digit MCC format expected by OAI).

**Problem 2:** DU's `gnb_name` was `gNB-DU-MINIPC` instead of `gNB-CU-FIRECELL`. For F1 Setup to succeed, DU's `gNB_Name` must match CU's `Active_gNBs`.

### Fix Applied

#### 1. Fixed cu-cfg.yml - PLMN values as strings with leading zeros
```yaml
plmn:
  mcc: "001"   # String with leading zeros
  mnc: "01"    # String with leading zeros
  mnc_length: 2
```

#### 2. Fixed du-cfg.yml - PLMN values as strings with leading zeros + correct gNB name
```yaml
plmn:
  mcc: "001"
  mnc: "01"
  mnc_length: 2
cu:
  ...
  gnb_name: gNB-CU-FIRECELL   # Changed from gNB-DU-MINIPC
```

### How the Template-Based Replacement Works

The remote's `generate-configs.py` uses `replace_plmn_list()`:
```python
def replace_plmn_list(text, mcc, mnc, mnc_length):
    def do_replacements(inner):
        inner = re.sub(r'mcc\s*=\s*\d+', f'mcc = {mcc}', inner)
        inner = re.sub(r'mnc\s*=\s*\d+', f'mnc = {mnc}', inner)
        inner = re.sub(r'mnc_length\s*=\s*\d+', f'mnc_length = {mnc_length}', inner)
        return inner
```

With YAML values as strings `"001"` and `"01"`, the output becomes:
- `mcc = 001` (no quotes, 3 digits)
- `mnc = 01` (no quotes, 2 digits)

Which matches OAI's expected format in the reference configs.

### Testing Steps
1. Sync fixed configs to remote servers
2. Delete `__pycache__` on remotes
3. Run `generate-configs.sh cu` and `generate-configs.sh du`
4. Check generated configs for correct PLMN format
5. Restart CU and DU binaries
6. Verify F1 Setup succeeds

### Commit History
- `6d911a3` - Fix plmn_list replacement: check pos+1 for '(', ')'; rename inner func to do_replacements
- `6895622` - Fix plmn_list replacement: use manual brace-matching instead of regex
- `63c4037` - Rewrite generate-configs.py for proper F1 split (template-based approach)
