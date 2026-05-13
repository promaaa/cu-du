# Current Deployed CU/DU Working Configuration

Last captured: 2026-05-13, after the Nothing Phone showed 5G bars and working internet.

## Hosts

| Host | Role | Address | Current active path |
|---|---|---:|---|
| `serber-firecell` | CU + 5G Core | `10.76.170.38` | `/home/serber/cu-du/source/openairinterface5g` for CU |
| `serber-pi` | DU on Raspberry Pi 5 + USRP B210 | `10.76.170.94` | `/home/serber/cu-du/source/openairinterface5g` |

SSH access used during debugging:

```bash
export SSHPASS='root4SERBER'
sshpass -e ssh -o StrictHostKeyChecking=no serber@10.76.170.38
sshpass -e ssh -o StrictHostKeyChecking=no serber@10.76.170.94
```

## Current Process Model

CU is running from the self-contained `cu-du` OAI tree on `serber-firecell`:

```bash
cd /home/serber/cu-du/source/openairinterface5g/cmake_targets/ran_build/build
sudo ./nr-softmodem \
  -O /home/serber/cu-du/source/openairinterface5g/targets/PROJECTS/GENERIC-NR-5GC/CONF/gnb-cu.conf \
  --log_config.global_log_level info
```

DU is running from the `cu-du` OAI tree on `serber-pi`:

```bash
cd /home/serber/cu-du/source/openairinterface5g/cmake_targets/ran_build/build
sudo ./nr-softmodem \
  -O /home/serber/cu-du/source/openairinterface5g/targets/PROJECTS/GENERIC-NR-5GC/CONF/gnb-pi.conf \
  --log_config.global_log_level info \
  -E
```

`-E` is part of the working DU launch command.

## Core And UPF

The 5G core is Docker-based on `serber-firecell`. The important healthy containers observed were:

- `oai-amf`
- `oai-smf`
- `oai-upf`
- `oai-nrf`
- `oai-udr`
- `oai-udm`
- `oai-ausf`
- `oai-ext-dn`
- `mysql`
- `ims`

UPF `tun0` has active traffic shaping:

```bash
docker exec oai-upf tc qdisc show dev tun0
```

Expected current output:

```text
qdisc tbf 8001: root refcnt 2 rate 1500Kbit burst 8Kb lat 400ms
```

This shaping was restored after testing lower limits. The current working user-confirmed setup uses `1500kbit`, not the temporary `512kbit` test.

## UE Subscriber

The Nothing Phone SIM is provisioned in the OAI core as:

```text
IMSI/SUPI = 001010000059449
DNN      = oai
S-NSSAI  = sst 1, sd FFFFFF
UE IPv4  = 10.0.0.6
AMF      = 8000
AKA      = 5G_AKA / milenage
Ki       = 5686e601f3a1942d4c5cd262ba6b4b20
OPc      = aeb1cabd8ed7a09b48d17eb3d8af172c
SQN      = 000000000000, NON_TIME_BASED
```

These credentials were recovered from the old working `~/monolithic/configuration/add-sim-card.sql` and are now stored directly in this repo's CN seed path so a fresh clone does not need `~/monolithic`.

## CU Configuration

Active CU config:

```text
/home/serber/cu-du/source/openairinterface5g/targets/PROJECTS/GENERIC-NR-5GC/CONF/gnb-cu.conf
```

Captured SHA-256:

```text
9bafc06cf2cc862c69c0b227f6bfc0a7f5a913f6627218d8aae46a26be983e1f
```

Important values:

```text
tracking_area_code = 1
PLMN = 001/01, mnc_length = 2
slice SST = 1

local_s_address  = 10.76.170.38
remote_s_address = 10.76.170.38
local_s_portd    = 2152
remote_s_portd   = 2152

amf_ip_address = 192.168.70.132
GNB_IPV4_ADDRESS_FOR_NG_AMF = 192.168.70.129/24
GNB_IPV4_ADDRESS_FOR_NGU    = 192.168.70.129/24
GNB_PORT_FOR_S1U            = 2152
```

The `2152` F1 user/control-side port values matter. A stale `2777` value broke the F1-U path earlier.

## DU Configuration

Active DU config:

```text
/home/serber/cu-du/source/openairinterface5g/targets/PROJECTS/GENERIC-NR-5GC/CONF/gnb-pi.conf
```

Captured SHA-256:

```text
b05f4bb20bd4ac9998e59bc4a3b276440d966dd0eaa64bbaeb3bdf3b11645ec1
```

Important values:

```text
tracking_area_code = 1
PLMN = 001/01, mnc_length = 2
physCellId = 0

absoluteFrequencySSB = 641280
dl_absoluteFrequencyPointA = 640008
dl_carrierBandwidth = 106
ul_carrierBandwidth = 106
initialDLBWPlocationAndBandwidth = 28875
initialULBWPlocationAndBandwidth = 28875
initialDLBWPcontrolResourceSetZero = 12
initialDLBWPsearchSpaceZero = 2

prach_ConfigurationIndex = 98
prach_msg1_FDM = 0
prach_msg1_FrequencyStart = 0
prach_RootSequenceIndex_PR = 2
prach_RootSequenceIndex = 1
ssb_periodicityServingCell = 2

local_n_address = 10.76.170.94
remote_n_address = 10.76.170.38
local_n_portd = 2152
remote_n_portd = 2152

prach_dtx_threshold = 120
att_tx = 3
att_rx = 12
sdr_addrs = serial=35F8ABA
```

Runtime RF values observed from DU startup:

```text
DL/UL frequency = 3619200000 Hz
Band = 78
N_RB = 106
USRP = B210
USRP serial = 35F8ABA
RX gain = 58
TX gain = 86.75
Master clock = 46.080 MHz
RX/TX sample rate = 46.080 MSps
RX/TX bandwidth = 40 MHz
```

## Working Remote YAML Inputs

On `serber-firecell`, the helper YAML that matches the working deployment is:

```text
/home/serber/cu-du/conf/cu-cfg.yml
/home/serber/cu-du/conf/pi-cfg.yml
```

The working `pi-cfg.yml` values are:

```yaml
host: serber-pi
role: pi
plmn:
  mcc: 1
  mnc: 1
  mnc_length: 2
cu:
  f1c_ip: 10.76.170.94
  f1u_ip: 10.76.170.94
  f1c_port: 2152
  remote_f1c_ip: 10.76.170.38
  remote_f1c_port: 2152
  gnb_id: 0xe00
  gnb_du_id: 0xe00
  gnb_name: gNB-CU-FIRECELL
  tac: 1
usrp:
  type: b200
  serial: 35F8ABA
  band: 78
  clock_src: internal
  max_pdschReferenceSignalPower: -27
  max_rxgain: 114
  att_tx: 3
  att_rx: 12
  prb: 106
  searchSpaceZero: 2
  controlResourceSetZero: 12
  ssb_perRACH_OccasionAndCB_PreamblesPerSSB: 14
  absoluteFrequencySSB: 641280
  dl_absoluteFrequencyPointA: 640008
  dl_offsetToCarrier: 0
  ssPBCH_BlockPower: -25
```

The working `cu-cfg.yml` values are:

```yaml
host: serber-firecell
role: cu
plmn:
  mcc: 1
  mnc: 1
  mnc_length: 2
amf:
  ip: 192.168.70.132
  port: 38412
cu:
  f1c_ip: 10.76.170.38
  f1c_port: 2152
  f1u_ip: 10.76.170.38
  ng_ip: 192.168.70.129
  gnb_id: 0xe00
  gnb_name: gNB-CU-FIRECELL
  tac: 1
```

## Raspberry Pi Host Requirements

The Pi host has these currently important system settings:

```text
usb_max_current_enable=1
vcgencmd get_throttled = throttled=0x0
CPU governor = performance on cpu0-cpu3
```

The USB current setting is in:

```text
/boot/firmware/config.txt
```

The B210 must be on USB3 and must enumerate as serial `35F8ABA`.

## What Did Not Work

The Nothing Phone did not camp/attach on the 51 PRB profile:

```text
prb = 51
dl_absoluteFrequencyPointA = 640668
absoluteFrequencySSB = 641280
controlResourceSetZero = 11
searchSpaceZero = 0
```

The phone showed no 5G bars and no internet on that profile.

Full gain was also worse:

```text
att_tx = 0
att_rx = 0
```

It attached, but downlink BLER and recovery loops were worse than the current `att_tx=3`, `att_rx=12` deployment.

## Current Known Caveat

Even while the phone has 5G bars and internet, DU logs can still show downlink BLER and C-RNTI recovery noise under load. This should be treated as a performance/stability issue, not as a core data-plane failure. The core, PDU session, F1-U, N3, NAT, and UE internet path are all proven functional in the current deployment.
