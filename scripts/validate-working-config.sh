#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_BASE="$(cd "$SCRIPT_DIR/.." && pwd)"
CONF_DIR="$REPO_BASE/source/openairinterface5g/targets/PROJECTS/GENERIC-NR-5GC/CONF"
CU_CONF="$CONF_DIR/gnb-cu.conf"
PI_CONF="$CONF_DIR/gnb-pi.conf"

python3 "$SCRIPT_DIR/generate-configs.py" cu >/dev/null
python3 "$SCRIPT_DIR/generate-configs.py" pi >/dev/null

require() {
    local file="$1"
    local pattern="$2"
    local label="$3"
    if ! grep -Eq "$pattern" "$file"; then
        echo "FAIL: $label"
        echo "  file: $file"
        echo "  pattern: $pattern"
        exit 1
    fi
}

reject() {
    local file="$1"
    local pattern="$2"
    local label="$3"
    if grep -Eq "$pattern" "$file"; then
        echo "FAIL: $label"
        echo "  file: $file"
        echo "  forbidden pattern: $pattern"
        exit 1
    fi
}

require "$CU_CONF" 'local_s_portd\s*=\s*2152;' 'CU local F1 port must be 2152'
require "$CU_CONF" 'remote_s_portd\s*=\s*2152;' 'CU remote F1 port must be 2152'
require "$CU_CONF" 'GNB_IPV4_ADDRESS_FOR_NGU\s*=\s*"192\.168\.70\.129' 'CU NGU IP must be 192.168.70.129'

require "$PI_CONF" 'dl_carrierBandwidth\s*=\s*106;' 'PI DL bandwidth must be 106 PRB'
require "$PI_CONF" 'ul_carrierBandwidth\s*=\s*106;' 'PI UL bandwidth must be 106 PRB'
require "$PI_CONF" 'absoluteFrequencySSB\s*=\s*641280;' 'PI SSB ARFCN must be 641280'
require "$PI_CONF" 'dl_absoluteFrequencyPointA\s*=\s*640008;' 'PI PointA must be 640008'
require "$PI_CONF" 'initialDLBWPlocationAndBandwidth\s*=\s*28875;' 'PI initial DL BWP must match 106 PRB'
require "$PI_CONF" 'initialULBWPlocationAndBandwidth\s*=\s*28875;' 'PI initial UL BWP must match 106 PRB'
require "$PI_CONF" 'local_n_portd\s*=\s*2152;' 'PI local F1-U port must be 2152'
require "$PI_CONF" 'remote_n_portd\s*=\s*2152;' 'PI remote F1-U port must be 2152'
require "$PI_CONF" 'sdr_addrs\s*=\s*"serial=35F8ABA";' 'PI USRP serial must be 35F8ABA'
require "$PI_CONF" 'att_tx\s*=\s*3' 'PI att_tx must be 3'
require "$PI_CONF" 'att_rx\s*=\s*12;' 'PI att_rx must be 12'
require "$PI_CONF" 'ssb_perRACH_OccasionAndCB_PreamblesPerSSB\s*=\s*14;' 'PI RACH/SSB setting must be 14'

reject "$CU_CONF" '2777' 'CU config must not contain stale port 2777'
reject "$PI_CONF" '2777' 'PI config must not contain stale port 2777'

echo "OK: generated CU/PI configs match the working baseline"
