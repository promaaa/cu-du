#!/usr/bin/env python3
"""Generate gnb-cu.conf and gnb-du.conf from YAML config files."""

import sys
import os
import copy
from ruamel.yaml import YAML

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
REPO_BASE = os.path.dirname(SCRIPT_DIR)
CONF_DIR = os.path.join(REPO_BASE, 'conf')
OUT_CU = os.path.join(REPO_BASE, 'source/openairinterface5g/targets/PROJECTS/GENERIC-NR-5GC/CONF/gnb-cu.conf')
OUT_DU = os.path.join(REPO_BASE, 'source/openairinterface5g/targets/PROJECTS/GENERIC-NR-5GC/CONF/gnb-du.conf')
SIB8_SRC = os.path.join(REPO_BASE, 'source/openairinterface5g/sib8.conf')
SIB8_DST_CU = os.path.join(REPO_BASE, 'source/openairinterface5g/sib8.conf')
SIB8_DST_DU = os.path.join(REPO_BASE, 'source/openairinterface5g/sib8.conf')

yaml = YAML()
yaml.default_flow_style = False


def load_yaml(path):
    with open(path) as f:
        return yaml.load(f)


def plmn_section(cfg):
    return f"""plmn_list = {{
  {{
    mcc = "{cfg['plmn']['mcc']}";
    mnc = "{cfg['plmn']['mnc']}";
    mnc_length = {cfg['plmn']['mnc_length']};
  }}
}};"""


def cu_config(cfg):
    return f"""Active_gNBs = ("{cfg['cu']['gnb_name']}");
gNBs = (
  {{
    gNB_ID = {cfg['cu']['gnb_id']};
    gNB_Name = "{cfg['cu']['gnb_name']}";
    F1AP_MODE = "cu";

    ////////// F1-C (control plane)
    f1ap:
    {{
      local_s_address = "{cfg['cu']['f1c_ip']}";
      local_port = {cfg['cu']['f1c_port']};
      remote_s_address = "{cfg['cu']['f1c_ip']}";
    }};

    ////////// F1-U (user plane) — separate socket
    f1u:
    {{
      local_address = "{cfg['cu']['f1u_ip']}";
    }};

    ////////// NGAP (to AMF)
    tr_s:
    {{
      local_address = "{cfg['cu']['ng_ip']}";
      remote_address = "{cfg['amf']['ip']}";
      remote_port = {cfg['amf']['port']};
      sctp_nodelay = 1;
    }};

    ////////// Cell configuration
    {plmn_section(cfg)}

    tracking_area_code = "{cfg['cu']['tac']}";
    ranac = 0;

    ////////// Slice config
    sst = (1);
    sd = (1);

    ////////// PHY parameters (CU has no RF — placeholder)
    do_CSIRS = 0;
    do_SRS = 0;

    servingCellConfigCommon = (
      {{
        absoluteFrequencySSB = 641280;
        dl_frequencyBand = 78;
        dl_absoluteFrequencyPointA = 640008;
        ul_frequencyBand = 78;
        ul_absoluteFrequencyPointA = 640008;
        nSSB_TimeAllocation = 1;
        nCSG = 0;
        dl_offstToCarrier = 0;
        subcarrierSpacing = 1;
        dl_carrierBandwidth = 106;
        ul_carrierBandwidth = 106;

        initialDLBWP:
        {{
          initialDLBWPsubcarrierSpacing = 1;
          initialDLBWPcontrolResourceSetZero = 12;
          initialDLBWPsearchSpaceZero = 2;
        }};

        initialULBWP:
        {{
          initialULBWPsubcarrierSpacing = 1;
          initialULBWPcontrolResourceSetZero = 12;
          initialULBWPsearchSpaceZero = 2;
        }};

        ////////// PDCCH config
        PDCCH:
        {{
          common:
          {{
            coreset0 = 1;
            searchSpace0 = 0;
          }};
        }};

        ////////// PDSCH config
        PDSCH:
        {{
          max_pdschReferenceSignalPower = -27;
          pdsch_AntennaPorts = 1;
        }};
      }}
    );

    ////////// Security
    security = {{
      ciphering_algorithms = ( "nea2" );
      integrity_algorithms = ( "nia2" );
    }};

    ////////// AMF config
    amf_ip_address = ("{cfg['amf']['ip']}/{cfg['amf']['port']}");
  }}
);"""


def du_config(cfg):
    return f"""Active_gNBs = ("{cfg['cu']['gnb_name']}");
gNBs = (
  {{
    gNB_ID = {cfg['cu']['gnb_id']};
    gNB_DU_ID = {cfg['cu']['gnb_du_id']};
    gNB_Name = "{cfg['cu']['gnb_name']}";
    F1AP_MODE = "du";

    ////////// F1-C (control plane)
    f1ap:
    {{
      local_s_address = "{cfg['cu']['f1c_ip']}";
      local_port = {cfg['cu']['f1c_port']};
      remote_s_address = "{cfg['cu']['remote_f1c_ip']}";
      remote_port = {cfg['cu']['remote_f1c_port']};
    }};

    ////////// F1-U (user plane) — separate socket
    f1u:
    {{
      local_address = "{cfg['cu']['f1u_ip']}";
    }};

    ////////// Cell / PLMN
    {plmn_section(cfg)}

    tracking_area_code = "{cfg['cu']['tac']}";
    ranac = 0;

    ////////// Slice config
    sst = (1);
    sd = (1);

    ////////// PHY parameters for DU (has USRP)
    do_CSIRS = 1;
    do_SRS = 1;

    servingCellConfigCommon = (
      {{
        absoluteFrequencySSB = 641280;
        dl_frequencyBand = 78;
        dl_absoluteFrequencyPointA = 640008;
        ul_frequencyBand = 78;
        ul_absoluteFrequencyPointA = 640008;
        nSSB_TimeAllocation = 1;
        nCSG = 0;
        dl_offstToCarrier = 0;
        subcarrierSpacing = 1;
        dl_carrierBandwidth = 106;
        ul_carrierBandwidth = 106;

        initialDLBWP:
        {{
          initialDLBWPsubcarrierSpacing = 1;
          initialDLBWPcontrolResourceSetZero = 12;
          initialDLBWPsearchSpaceZero = 2;
        }};

        initialULBWP:
        {{
          initialULBWPsubcarrierSpacing = 1;
          initialULBWPcontrolResourceSetZero = 12;
          initialULBWPsearchSpaceZero = 2;
        }};

        PDCCH:
        {{
          common:
          {{
            coreset0 = 1;
            searchSpace0 = 0;
          }};
        }};

        PDSCH:
        {{
          max_pdschReferenceSignalPower = {cfg['usrp']['max_pdschReferenceSignalPower']};
          pdsch_AntennaPorts = 1;
        }};
      }}
    );

    ////////// USRP RU config
    RUs = (
      {{
        local_rf = "yes";
        sdr_addrs = "serial={cfg['usrp']['serial']}";
        nb_tx = 1;
        nb_rx = 1;
        att_tx = {cfg['usrp']['att_tx']};
        att_rx = {cfg['usrp']['att_rx']};
        max_rxgain = {cfg['usrp']['max_rxgain']};
        eNB_feeder = 0;
        clock_source = "internal";
        time_source = "internal";
      }}
    );
  }}
);"""


def copy_sib8():
    src = os.path.join(REPO_BASE, 'patches/../monolithic/openairinterface5g/sib8.conf')
    sib8 = os.path.join(REPO_BASE, 'source/openairinterface5g/sib8.conf')
    # Try to find sib8.conf from the original monolithic repo
    alt_src = os.path.join(os.path.expanduser('~'), 'monolithic/openairinterface5g/sib8.conf')
    if os.path.exists(alt_src):
        import shutil
        os.makedirs(os.path.dirname(sib8), exist_ok=True)
        shutil.copy(alt_src, sib8)


def main():
    if len(sys.argv) < 2 or sys.argv[1] not in ('cu', 'du', 'all'):
        print("Usage: generate-configs.sh cu|du|all")
        sys.exit(1)

    mode = sys.argv[1]

    os.makedirs(os.path.dirname(OUT_CU), exist_ok=True)

    if mode in ('cu', 'all'):
        cfg = load_yaml(os.path.join(CONF_DIR, 'cu-cfg.yml'))
        with open(OUT_CU, 'w') as f:
            f.write(cu_config(cfg))
        print(f"Generated {OUT_CU}")

    if mode in ('du', 'all'):
        cfg = load_yaml(os.path.join(CONF_DIR, 'du-cfg.yml'))
        with open(OUT_DU, 'w') as f:
            f.write(du_config(cfg))
        print(f"Generated {OUT_DU}")

    copy_sib8()


if __name__ == '__main__':
    main()
