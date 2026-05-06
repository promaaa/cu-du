# CU/DU Split Architecture

## 1. Overview

The OpenAirInterface 5G NR stack supports a CU/DU split architecture defined in 3GPP TS 38.401 and TS 38.470. This allows the gNB to be distributed across two physical nodes:

- **CU (Central Unit)**: Runs RRC, PDCP, SDAP layers. Handles control plane via F1-C and user plane via F1-U. Connects to AMF via NG.
- **DU (Distributed Unit)**: Runs MAC, RLC, PHY layers. Connects to CU via F1. Drives the USRP RF front-end.

```
┌─────────────────────────────────────────────────────────────────────┐
│                           gNB                                      │
│  ┌───────────────────────┐          ┌──────────────────────────┐ │
│  │         CU            │          │           DU              │ │
│  │  (serber-firecell)    │ F1-C     │    (serber-minipc)        │ │
│  │                       │◄────────►│                           │ │
│  │  • RRC                │ F1-U     │  • MAC                   │ │
│  │  • PDCP               │◄────────►│  • RLC                    │ │
│  │  • SDAP               │          │  • PHY                    │ │
│  │  • NGAP (to AMF)      │          │  • USRP B210 (35F8ABA)    │ │
│  └───────────────────────┘          └──────────────────────────┘ │
└─────────────────────────────────────────────────────────────────────┘
```

## 2. 3GPP F1 Interface

The F1 interface (TS 38.470) separates the gNB into CU and DU:

### 2.1 F1-C (Control Plane)

 SCTP-based, carries F1AP messages (TS 38.473):
- `F1 Setup Request / Response` — DU registers with CU
- `GNB DU Configuration` — CU sends cell config to DU
- `GNB CU Configuration Update` — DU confirms config
- `Write Replace Warning Request` — SIB8/PWS carried over F1
- `UE Context Setup` — Bearer establishment
- `Initial UL RRC Message` — UE RACH → DU → CU

### 2.2 F1-U (User Plane)

 GTP-U-based, carries PDCP PDUs between CU and DU:
- DL user data: CU → F1-U → DU → PHY → RF
- UL user data: RF → PHY → DU → F1-U → CU → AMF

## 3. CU Responsibilities

| Function | Layer |
|---|---|
| RRC connection management | RRC |
| PDCP: ciphering, integrity | PDCP |
| SDAP: QoS flow mapping | SDAP |
| NGAP: AMF registration, UE context | NGAP |
| SIB8/PWS construction | RRC |
| F1AP control plane termination | F1AP |

## 4. DU Responsibilities

| Function | Layer |
|---|---|
| MAC: scheduling, HARQ | MAC |
| RLC: ARQ, segmentation | RLC |
| PHY: coding, modulation | PHY |
| RF: USRP B210 (35F8ABA) | PHY |
| F1AP control plane initiation | F1AP |
| F1-U user plane termination | F1-U |

## 5. SIB8 / PWS Flow in CU/DU Split

```
UE              DU              CU             AMF
 │               │               │              │
 │               │◄── F1 Setup ──►│              │
 │               │               │◄─ NG Setup ──►│
 │               │               │              │
 │◄── SIB1 ──────│               │              │
 │               │               │              │
 │               │◄─ Write Replace Warning Req ─│ (F1-C)
 │◄── SIB8 ──────│               │              │
 │  (Emergency   │               │              │
 │   Alert)      │               │              │
```

The SIB8 is built in the CU's RRC layer (`build_sib8_segments()` in `openair2/RRC/NR/MESSAGES/asn1_msg.c`) and sent to the DU via the F1AP `write_replace_warning_req` message. The DU's MAC layer decodes and schedules it (`nr_mac_configure_pws_si()` in `openair2/LAYER2/NR_MAC_gNB/config.c`).

## 6. IP Assignments

| Interface | Role | IP |
|---|---|---|
| F1-C (CU) | CU control plane listen | `10.76.170.38` |
| F1-C (DU) | DU control plane connect | `10.76.170.100` |
| F1-U (CU) | CU user plane | `10.76.170.39` |
| F1-U (DU) | DU user plane | `10.76.170.101` |
| NG (CU) | CU → AMF | `192.168.70.129` |
| AMF | Core Network | `192.168.70.132` |

## 7. OAI F1AP Modes

In `gnb-cu.conf` / `gnb-du.conf`, the `F1AP_MODE` field selects the role:

```
F1AP_MODE = "cu";  // CU: listens on F1-C, connects to AMF via NG
F1AP_MODE = "du";  // DU: connects to CU F1-C, has USRP/RF
F1AP_MODE = "monolithic"; // Combined (no split)
```

## 8. OAI Source Files Involved

| File | Purpose |
|---|---|
| `openair2/RRC/NR/MESSAGES/asn1_msg.c` | SIB8 construction |
| `openair2/RRC/NR/rrc_gNB_du.c` | `write_replace_warning_req_trigger()` |
| `openair2/LAYER2/NR_MAC_gNB/config.c` | `nr_mac_configure_pws_si()` |
| `openair2/LAYER2/NR_MAC_gNB/mac_rrc_dl_handler.c` | `write_replace_warning_req()` |
| `openair2/COMMON/f1ap_messages_types.h` | F1AP message types |
| `openair2/LAYER2/NR_MAC_gNB/gNB_scheduler_bch.c` | SIB scheduling |
