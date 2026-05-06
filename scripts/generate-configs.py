#!/usr/bin/env python3
"""Generate gnb-cu.conf and gnb-du.conf by modifying OAI reference configs."""

import sys
import os
import shutil
import re
from ruamel.yaml import YAML

MONOLITHIC_OAI = '/home/serber/monolithic/openairinterface5g'
REF_CU = os.path.join(MONOLITHIC_OAI, 'targets/PROJECTS/GENERIC-NR-5GC/CONF/cu_gnb.conf')
REF_DU = os.path.join(MONOLITHIC_OAI, 'targets/PROJECTS/GENERIC-NR-5GC/CONF/du_gnb.conf')
OUT_CU = os.path.join(MONOLITHIC_OAI, 'targets/PROJECTS/GENERIC-NR-5GC/CONF/gnb-cu.conf')
OUT_DU = os.path.join(MONOLITHIC_OAI, 'targets/PROJECTS/GENERIC-NR-5GC/CONF/gnb-du.conf')
CONF_DIR = '/home/serber/cu-du/conf'
SIB8_SRC = os.path.join(MONOLITHIC_OAI, 'sib8.conf')
SIB8_DST = os.path.join(MONOLITHIC_OAI, 'sib8.conf')

yaml_inst = YAML()


def load_yaml(path):
    with open(path) as f:
        return yaml_inst.load(f)


def replace_key(text, key, value):
    """Replace all occurrences of key = value pattern in config text, preserving line endings."""
    pattern = re.compile(rf'^(\s*{re.escape(key)}\s*=\s*).*?(\s*;?\s*)$', re.MULTILINE)
    count = 0
    def repl(m):
        nonlocal count
        count += 1
        return m.group(1) + value + m.group(2)
    new_text = pattern.sub(repl, text)
    return count, new_text


def apply_cu_config(text, cfg):
    cu = cfg['cu']
    plmn = cfg['plmn']
    amf = cfg['amf']

    total = 0
    n, text = replace_key(text, 'gNB_ID', hex(cu['gnb_id'])); total += n
    n, text = replace_key(text, 'gNB_name', f'"{cu["gnb_name"]}"'); total += n
    n, text = replace_key(text, 'F1AP_MODE', '"cu"'); total += n
    n, text = replace_key(text, 'mcc', str(plmn['mcc'])); total += n
    n, text = replace_key(text, 'mnc', str(plmn['mnc'])); total += n
    n, text = replace_key(text, 'mnc_length', str(plmn['mnc_length'])); total += n
    n, text = replace_key(text, 'tracking_area_code', f'"{cu["tac"]}"'); total += n
    n, text = replace_key(text, 'local_s_address', f'"{cu["f1c_ip"]}"'); total += n
    n, text = replace_key(text, 'remote_s_address', f'"{cu["f1c_ip"]}"'); total += n
    n, text = replace_key(text, 'local_address', f'"{cu["f1u_ip"]}"'); total += n
    n, text = replace_key(text, 'local_address', f'"{cu["ng_ip"]}"'); total += n
    n, text = replace_key(text, 'remote_address', f'"{amf["ip"]}"'); total += n
    n, text = replace_key(text, 'remote_port', str(amf['port'])); total += n
    n, text = replace_key(text, 'amf_ip_address', f'("{amf["ip"]}/{amf["port"]}")'); total += n
    n, text = replace_key(text, 'sst', '1'); total += n
    n, text = replace_key(text, 'sd', '1'); total += n

    return total, text


def apply_du_config(text, cfg):
    cu = cfg['cu']
    plmn = cfg['plmn']
    usrp = cfg['usrp']

    total = 0
    n, text = replace_key(text, 'gNB_ID', hex(cu['gnb_id'])); total += n
    n, text = replace_key(text, 'gNB_DU_ID', hex(cu['gnb_du_id'])); total += n
    n, text = replace_key(text, 'gNB_name', f'"{cu["gnb_name"]}"'); total += n
    n, text = replace_key(text, 'F1AP_MODE', '"du"'); total += n
    n, text = replace_key(text, 'mcc', str(plmn['mcc'])); total += n
    n, text = replace_key(text, 'mnc', str(plmn['mnc'])); total += n
    n, text = replace_key(text, 'mnc_length', str(plmn['mnc_length'])); total += n
    n, text = replace_key(text, 'tracking_area_code', f'"{cu["tac"]}"'); total += n
    n, text = replace_key(text, 'local_s_address', f'"{cu["f1c_ip"]}"'); total += n
    n, text = replace_key(text, 'remote_s_address', f'"{cu["remote_f1c_ip"]}"'); total += n
    n, text = replace_key(text, 'local_port', str(cu['f1c_port'])); total += n
    n, text = replace_key(text, 'remote_port', str(cu['remote_f1c_port'])); total += n
    n, text = replace_key(text, 'local_address', f'"{cu["f1u_ip"]}"'); total += n
    n, text = replace_key(text, 'sdr_addrs', f'"serial={usrp["serial"]}"'); total += n
    n, text = replace_key(text, 'max_rxgain', str(usrp['max_rxgain'])); total += n
    n, text = replace_key(text, 'att_tx', str(usrp['att_tx'])); total += n
    n, text = replace_key(text, 'att_rx', str(usrp['att_rx'])); total += n
    if 'max_pdschReferenceSignalPower' in usrp:
        n, text = replace_key(text, 'max_pdschReferenceSignalPower', str(usrp['max_pdschReferenceSignalPower'])); total += n

    return total, text


def copy_sib8():
    if os.path.exists(SIB8_SRC) and SIB8_SRC != SIB8_DST:
        shutil.copy(SIB8_SRC, SIB8_DST)


def main():
    if len(sys.argv) < 2 or sys.argv[1] not in ('cu', 'du', 'all'):
        print("Usage: generate-configs.py cu|du|all")
        sys.exit(1)

    mode = sys.argv[1]

    if mode in ('cu', 'all'):
        if not os.path.exists(REF_CU):
            print(f"ERROR: Reference CU config not found at {REF_CU}")
            sys.exit(1)
        cfg = load_yaml(os.path.join(CONF_DIR, 'cu-cfg.yml'))
        with open(REF_CU) as f:
            text = f.read()
        count, text = apply_cu_config(text, cfg)
        os.makedirs(os.path.dirname(OUT_CU), exist_ok=True)
        with open(OUT_CU, 'w') as f:
            f.write(text)
        print(f"Generated {OUT_CU} ({count} substitutions)")

    if mode in ('du', 'all'):
        if not os.path.exists(REF_DU):
            print(f"ERROR: Reference DU config not found at {REF_DU}")
            sys.exit(1)
        cfg = load_yaml(os.path.join(CONF_DIR, 'du-cfg.yml'))
        with open(REF_DU) as f:
            text = f.read()
        count, text = apply_du_config(text, cfg)
        os.makedirs(os.path.dirname(OUT_DU), exist_ok=True)
        with open(OUT_DU, 'w') as f:
            f.write(text)
        print(f"Generated {OUT_DU} ({count} substitutions)")

    copy_sib8()


if __name__ == '__main__':
    main()