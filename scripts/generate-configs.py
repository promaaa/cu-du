#!/usr/bin/env python3
"""Generate gnb-cu.conf and gnb-du.conf by modifying OAI reference configs via sed."""

import sys
import os
import shutil
import re
from ruamel.yaml import YAML

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
REPO_BASE = os.path.dirname(SCRIPT_DIR)
CONF_DIR = os.path.join(REPO_BASE, 'conf')
MONOLITHIC_OAI = os.path.expanduser('~/monolithic/openairinterface5g')
REF_CU = os.path.join(MONOLITHIC_OAI, 'targets/PROJECTS/GENERIC-NR-5GC/CONF/cu_gnb.conf')
REF_DU = os.path.join(MONOLITHIC_OAI, 'targets/PROJECTS/GENERIC-NR-5GC/CONF/du_gnb.conf')
OUT_CU = os.path.join(MONOLITHIC_OAI, 'targets/PROJECTS/GENERIC-NR-5GC/CONF/gnb-cu.conf')
OUT_DU = os.path.join(MONOLITHIC_OAI, 'targets/PROJECTS/GENERIC-NR-5GC/CONF/gnb-du.conf')
SIB8_SRC = os.path.join(MONOLITHIC_OAI, 'sib8.conf')
SIB8_DST = os.path.join(MONOLITHIC_OAI, 'sib8.conf')

yaml = YAML()


def load_yaml(path):
    with open(path) as f:
        return yaml.load(f)


def replace_in_text(text, key, value):
    """Replace a key = value pair in libconfig text, preserving formatting."""
    escaped_key = re.escape(key)
    pattern = re.compile(rf'^(\s*{escaped_key}\s*=).*$', re.MULTILINE)
    replacement = rf'\1 {value}'
    count, new_text = pattern.subn(replacement, text)
    return count, new_text


def read_file(path):
    with open(path) as f:
        return f.read()


def write_file(path, content):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, 'w') as f:
        f.write(content)


def apply_cu_config(text, cfg):
    cu = cfg['cu']
    plmn = cfg['plmn']
    amf = cfg['amf']

    count = 0
    count_, text = replace_in_text(text, 'gNB_ID', hex(cu['gnb_id'])); count += count_
    count_, text = replace_in_text(text, 'gNB_Name', f'"{cu["gnb_name"]}"'); count += count_
    count_, text = replace_in_text(text, 'F1AP_MODE', '"cu"'); count += count_
    count_, text = replace_in_text(text, 'mcc', f'"{plmn["mcc"]}"'); count += count_
    count_, text = replace_in_text(text, 'mnc', f'"{plmn["mnc"]}"'); count += count_
    count_, text = replace_in_text(text, 'mnc_length', str(plmn['mnc_length'])); count += count_
    count_, text = replace_in_text(text, 'tracking_area_code', f'"{cu["tac"]}"'); count += count_

    count_, text = replace_in_text(text, 'local_s_address', f'"{cu["f1c_ip"]}"'); count += count_
    count_, text = replace_in_text(text, 'remote_s_address', f'"{cu["f1c_ip"]}"'); count += count_
    count_, text = replace_in_text(text, 'local_address', f'"{cu["f1u_ip"]}"'); count += count_

    count_, text = replace_in_text(text, 'local_address', f'"{cu["ng_ip"]}"'); count += count_
    count_, text = replace_in_text(text, 'remote_address', f'"{amf["ip"]}"'); count += count_
    count_, text = replace_in_text(text, 'remote_port', str(amf['port'])); count += count_
    count_, text = replace_in_text(text, 'amf_ip_address', f'("{amf["ip"]}/{amf["port"]}")'); count += count_

    count_, text = replace_in_text(text, 'sst', '(1)'); count += count_
    count_, text = replace_in_text(text, 'sd', '(1)'); count += count_

    return count, text


def apply_du_config(text, cfg):
    cu = cfg['cu']
    plmn = cfg['plmn']
    usrp = cfg['usrp']

    count = 0
    count_, text = replace_in_text(text, 'gNB_ID', hex(cu['gnb_id'])); count += count_
    count_, text = replace_in_text(text, 'gNB_DU_ID', hex(cu['gnb_du_id'])); count += count_
    count_, text = replace_in_text(text, 'gNB_Name', f'"{cu["gnb_name"]}"'); count += count_
    count_, text = replace_in_text(text, 'F1AP_MODE', '"du"'); count += count_
    count_, text = replace_in_text(text, 'mcc', f'"{plmn["mcc"]}"'); count += count_
    count_, text = replace_in_text(text, 'mnc', f'"{plmn["mnc"]}"'); count += count_
    count_, text = replace_in_text(text, 'mnc_length', str(plmn['mnc_length'])); count += count_
    count_, text = replace_in_text(text, 'tracking_area_code', f'"{cu["tac"]}"'); count += count_

    count_, text = replace_in_text(text, 'local_s_address', f'"{cu["f1c_ip"]}"'); count += count_
    count_, text = replace_in_text(text, 'remote_s_address', f'"{cu["remote_f1c_ip"]}"'); count += count_
    count_, text = replace_in_text(text, 'local_port', str(cu['f1c_port'])); count += count_
    count_, text = replace_in_text(text, 'remote_port', str(cu['remote_f1c_port'])); count += count_
    count_, text = replace_in_text(text, 'local_address', f'"{cu["f1u_ip"]}"'); count += count_

    count_, text = replace_in_text(text, 'sdr_addrs', f'"serial={usrp["serial"]}"'); count += count_
    count_, text = replace_in_text(text, 'max_rxgain', str(usrp['max_rxgain'])); count += count_
    count_, text = replace_in_text(text, 'att_tx', str(usrp['att_tx'])); count += count_
    count_, text = replace_in_text(text, 'att_rx', str(usrp['att_rx'])); count += count_

    if 'max_pdschReferenceSignalPower' in usrp:
        count_, text = replace_in_text(text, 'max_pdschReferenceSignalPower',
                                       str(usrp['max_pdschReferenceSignalPower'])); count += count_

    return count, text


def copy_sib8():
    if os.path.exists(SIB8_SRC):
        shutil.copy(SIB8_SRC, SIB8_DST)
        print(f"Copied sib8.conf to {SIB8_DST}")


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
        text = read_file(REF_CU)
        count, text = apply_cu_config(text, cfg)
        write_file(OUT_CU, text)
        print(f"Generated {OUT_CU} ({count} substitutions)")

    if mode in ('du', 'all'):
        if not os.path.exists(REF_DU):
            print(f"ERROR: Reference DU config not found at {REF_DU}")
            sys.exit(1)
        cfg = load_yaml(os.path.join(CONF_DIR, 'du-cfg.yml'))
        text = read_file(REF_DU)
        count, text = apply_du_config(text, cfg)
        write_file(OUT_DU, text)
        print(f"Generated {OUT_DU} ({count} substitutions)")

    copy_sib8()


if __name__ == '__main__':
    main()