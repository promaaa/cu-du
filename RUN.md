# Running the CU/DU Split Stack

This guide covers starting the CU/DU split stack from a fresh state.

## Prerequisites

- Repository cloned to `~/cu-du/` on both hosts
- Build already completed (`roles/*/build.sh` run once)
- UHD and OAI built on both hosts

---

## Step 1 — Clean Up Leftover Processes

On **serber-firecell**:
```bash
pkill -f nr-softmodem || true
```

On **serber-minipc**:
```bash
pkill -f nr-softmodem || true
```

---

## Step 2 — Scenario Selection

### Scenario A — Full CU/DU Split (production)

**serber-firecell** — Start CU + CN:
```bash
cd ~/cu-du
roles/cu/start.sh
```

**serber-minipc** — Start DU:
```bash
cd ~/cu-du
roles/du/start.sh
```

> Start the CU first. The DU will try to connect to the CU's F1-C at `10.76.170.38:2152`.

**To stop:**
```bash
# On serber-firecell
roles/cu/stop.sh

# On serber-minipc
roles/du/stop.sh
```

---

### Scenario B — CU-only (no DU, for testing)

**serber-firecell**:
```bash
cd ~/cu-du
roles/cu/start.sh
```

The CU will register with AMF and wait for a DU F1 connection.

---

### Scenario C — DU-only (no CU, for testing)

**serber-minipc**:
```bash
cd ~/cu-du
roles/du/start.sh
```

The DU will try to connect to the CU at `10.76.170.38:2152`. No CN involved.

---

### Scenario D — All-in-one (monolithic)

**serber-firecell**:
```bash
cd ~/cu-du
roles/all/start.sh
```

CU + CN start together. No separate DU host needed.

---

## Step 3 — Verify Operation

From your local machine:
```bash
~/cu-du/scripts/check-health.sh
```

Expected checks:
- CU process alive on serber-firecell
- DU process alive on serber-minipc
- CN containers healthy on serber-firecell
- F1 link established (`F1 Setup` in logs)
- AMF registered (`NGAP_REGISTER_GNB_CNF`)
- SIB8 transmitted (`write_replace_warning`)
- UE attached (`RRC_CONNECTED`)

---

## Quick Reference — Full Split Restart

```bash
# 1. Clean up (both hosts)
pkill -f nr-softmodem || true

# 2. Start CN + CU (serber-firecell)
ssh serber-firecell "cd ~/cu-du && roles/cu/start.sh"

# 3. Start DU (serber-minipc)
ssh serber-minipc "cd ~/cu-du && roles/du/start.sh"
```

---

## Troubleshooting

### No F1 connection
```bash
# Check DU is connecting to correct CU IP
ssh serber-minipc "grep 'F1\|connect\|2152' /tmp/du.log | tail -20"
```

### CU crashes immediately
```bash
# Run in foreground for debug output
ssh serber-firecell "cd ~/cu-du/source/openairinterface5g/cmake_targets/ran_build/build && sudo ./nr-softmodem -O ../targets/PROJECTS/GENERIC-NR-5GC/CONF/gnb-cu.conf --log_config.global_log_level debug"
```

### USRP not found (DU)
```bash
ssh serber-minipc "sudo uhd_find_devices"
# If not found, unplug and replug the USB cable
```

### PWS / SIB8 not transmitted
```bash
# Verify sib8.conf exists
ssh serber-minipc "cat ~/cu-du/source/openairinterface5g/sib8.conf"

# Check for SIB8 in logs
ssh serber-minipc "grep -i 'sib8\|write_replace' /tmp/du.log"
```
