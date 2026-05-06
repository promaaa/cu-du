# CU/DU Split Repository

OAI 5G NR with CU/DU split deployment across `serber-firecell` (CU + CN) and `serber-minipc` (DU + USRP B210).

## Topology

```
┌─────────────────────────────────────────────────────────────────┐
│                      serber-firecell                            │
│                                                                 │
│   ┌──────────────┐      ┌──────────────────────┐               │
│   │  oai-cn5g    │      │   nr-softmodem (CU)  │               │
│   │  (docker)    │      │   RRC + PDCP + SDAP  │               │
│   └──────┬───────┘      └──────────┬───────────┘               │
│          │                        │                            │
│   192.168.70.132 (AMF)           │ F1-C (10.76.170.38)        │
│          │                        │ F1-U (10.76.170.39)        │
│          │◄────── NG ─────────────┘                            │
└──────────┼──────────────────────────────────────────────────────┘
           │
           │  LAN  (10.76.170.0/25)
           │
┌──────────┼──────────────────────────────────────────────────────┐
│          │              serber-minipc                            │
│   ┌──────▼──────────────────────────────────┐                  │
│   │        nr-softmodem (DU)                 │                  │
│   │   MAC + RLC + PHY + USRP B210           │                  │
│   └──────────────┬───────────────────────────┘                  │
│                  │ F1-C (10.76.170.100)                         │
│                  │ F1-U (10.76.170.101)                         │
│            ┌─────▼─────┐                                        │
│            │  USRP     │                                        │
│            │  B210     │ ─── RF (3619.2 MHz, band n78)          │
│            │ 35F8ABA   │                                        │
│            └───────────┘                                        │
└──────────────────────────────────────────────────────────────────┘
```

## Quick Start

### Scenario A — Full CU/DU Split (production)

**serber-firecell:**
```bash
cd ~/cu-du && roles/cu/start.sh
```

**serber-minipc:**
```bash
cd ~/cu-du && roles/du/start.sh
```

### Scenario D — All-in-one (monolithic, same as current)

**serber-firecell:**
```bash
cd ~/cu-du && roles/all/start.sh
```

## Which Script for Which Scenario?

| Scenario | serber-firecell | serber-minipc |
|---|---|---|
| **A — Full split** | `roles/cu/start.sh` | `roles/du/start.sh` |
| **B — CU-only (testing)** | `roles/cu/start.sh` | — |
| **C — DU-only (testing)** | — | `roles/du/start.sh` |
| **D — All-in-one** | `roles/all/start.sh` | — |

See [RUN.md](RUN.md) for detailed step-by-step operation instructions.

## SIB8 / Public Warning System

SIB8 warning messages are built in the CU's RRC layer, sent to the DU over F1 via the `write_replace_warning_req` message, and transmitted over the air by the DU's USRP.

The warning text is configured in `source/openairinterface5g/sib8.conf`.

## Deployment Scripts

| Script | Description |
|---|---|
| `scripts/deploy-cu.sh` | Clone + build CU on serber-firecell |
| `scripts/deploy-du.sh` | Clone + build DU on serber-minipc |
| `scripts/deploy-all.sh` | Clone + build all-in-one on single host |
| `scripts/check-health.sh` | Verify all components running |

## Documentation

- [RUN.md](RUN.md) — Full stack operation guide
- [SPLIT.md](SPLIT.md) — CU/DU architecture + 3GPP F1/E1 docs
- [INSTALL.md](INSTALL.md) — Dependencies, UHD build, OAI build

## Network Parameters

| Parameter | Value |
|---|---|
| PLMN | MCC 001, MNC 01 |
| Band | n78 (3300–3800 MHz) |
| BW | 106 PRB @ 30 kHz SCS |
| AbsoluteFrequencySSB | 641280 (3619.2 MHz) |
| TAC | 1 |
| USRP (DU) | B210 serial `35F8ABA` |
