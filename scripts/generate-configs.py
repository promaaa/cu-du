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


def replace_key_line(text, key, value):
    """Replace key = value at start of line (with leading whitespace)."""
    pattern = re.compile(rf'^(\s*{re.escape(key)}\s*=\s*).*?(\s*;?\s*)$', re.MULTILINE)
    count = 0
    def repl(m):
        nonlocal count
        count += 1
        return m.group(1) + value + m.group(2)
    new_text = pattern.sub(repl, text)
    return count, new_text


def replace_key_inline(text, key, value):
    """Replace key = value anywhere in line (for inline configs like plmn_list)."""
    pattern = re.compile(rf'({re.escape(key)}\s*=\s*)[^;,\s]+')
    count = 0
    def repl(m):
        nonlocal count
        count += 1
        return m.group(1) + value
    new_text = pattern.sub(repl, text)
    return count, new_text


def replace_plmn_list(text, mcc, mnc, mnc_length):
    """Replace the plmn_list block, preserving inner structure (handles nested braces)."""
    def repl(m):
        inner = m.group(0)
        inner = re.sub(r'mcc\s*=\s*\d+', f'mcc = {mcc}', inner)
        inner = re.sub(r'mnc\s*=\s*\d+', f'mnc = {mnc}', inner)
        inner = re.sub(r'mnc_length\s*=\s*\d+', f'mnc_length = {mnc_length}', inner)
        return inner
    start = text.find('plmn_list = ({')
    if start == -1:
        return 0, text
    pos = start + len('plmn_list = ({')
    depth = 1
    while depth > 0 and pos < len(text):
        if text[pos] == '{' and text[pos-1] == '(':
            depth += 1
        elif text[pos] == '}' and text[pos-1] == ')':
            depth -= 1
            if depth == 0:
                end = pos + 1
                old_block = text[start:end]
                new_block = repl(old_block)
                if old_block != new_block:
                    return 1, text[:start] + new_block + text[end:]
                return 0, text
        pos += 1
    return 0, text


def replace_macvlan_addr(text, key, value):
    """Replace MACRLCs local_n_address / remote_n_address with proper format."""
    pattern = re.compile(rf'^(\s*{re.escape(key)}\s*=\s*).*$', re.MULTILINE)
    count = 0
    def repl(m):
        nonlocal count
        count += 1
        return m.group(1) + f'"{value}"'
    new_text = pattern.sub(repl, text)
    return count, new_text


def apply_cu_config(text, cfg):
    cu = cfg['cu']
    plmn = cfg['plmn']
    amf = cfg['amf']

    total = 0

    n, text = replace_key_line(text, 'gNB_ID', hex(cu['gnb_id'])); total += n
    n, text = replace_key_line(text, 'gNB_name', f'"{cu["gnb_name"]}"'); total += n

    n, text = replace_plmn_list(text, plmn['mcc'], plmn['mnc'], plmn['mnc_length']); total += n
    n, text = replace_key_line(text, 'tracking_area_code', str(cu['tac'])); total += n

    n, text = replace_key_line(text, 'tr_s_preference', '"f1"'); total += n

    n, text = replace_key_line(text, 'local_s_address', f'"{cu["f1c_ip"]}"'); total += n
    n, text = replace_key_line(text, 'remote_s_address', '"0.0.0.0"'); total += n
    n, text = replace_key_line(text, 'local_s_portd', str(cu['f1c_port'])); total += n
    n, text = replace_key_line(text, 'remote_s_portd', str(cu['f1c_port'])); total += n

    n, text = replace_key_line(text, 'amf_ip_address', f'({{ ipv4 = "{amf["ip"]}"; }})'); total += n

    n, text = replace_key_line(text, 'GNB_IPV4_ADDRESS_FOR_NG_AMF', f'"{cu["ng_ip"]}"'); total += n
    n, text = replace_key_line(text, 'GNB_IPV4_ADDRESS_FOR_NGU', f'"{cu["ng_ip"]}"'); total += n
    n, text = replace_key_line(text, 'GNB_PORT_FOR_S1U', '2152'); total += n

    n, text = replace_key_inline(text, 'sst', '1'); total += n

    return total, text


def apply_du_config(text, cfg):
    cu = cfg['cu']
    plmn = cfg['plmn']
    usrp = cfg['usrp']

    total = 0

    n, text = replace_key_line(text, 'gNB_ID', hex(cu['gnb_id'])); total += n
    n, text = replace_key_line(text, 'gNB_DU_ID', hex(cu['gnb_du_id'])); total += n
    n, text = replace_key_line(text, 'gNB_name', f'"{cu["gnb_name"]}"'); total += n
    n, text = replace_key_line(text, 'Active_gNBs', f'( "{cu["gnb_name"]}")'); total += n

    n, text = replace_plmn_list(text, plmn['mcc'], plmn['mnc'], plmn['mnc_length']); total += n
    n, text = replace_key_line(text, 'tracking_area_code', str(cu['tac'])); total += n

    n, text = replace_macvlan_addr(text, 'local_n_address', cu['f1c_ip']); total += n
    n, text = replace_macvlan_addr(text, 'remote_n_address', cu['remote_f1c_ip']); total += n

    n, text = replace_key_line(text, 'local_n_portd', '2153'); total += n
    n, text = replace_key_line(text, 'remote_n_portd', '2152'); total += n

    n, text = replace_key_line(text, 'sdr_addrs', f'"serial={usrp["serial"]}"'); total += n
    n, text = replace_key_line(text, 'max_rxgain', str(usrp['max_rxgain'])); total += n
    n, text = replace_key_line(text, 'att_tx', str(usrp['att_tx'])); total += n
    n, text = replace_key_line(text, 'att_rx', str(usrp['att_rx'])); total += n

    if 'max_pdschReferenceSignalPower' in usrp:
        n, text = replace_key_line(text, 'max_pdschReferenceSignalPower', str(usrp['max_pdschReferenceSignalPower'])); total += n

    n, text = replace_key_inline(text, 'sst', '1'); total += n

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