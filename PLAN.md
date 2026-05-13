# 5G CU/DU Split — Reproducible Fixes (debug session 2026-05-12)

This document is the **action list** for getting the OAI CU/DU split + 5GC stack
to reliably carry user-plane traffic from a Nothing Phone to the internet. Each
fix below is needed for reproducibility; skipping any one will reproduce the
"5G bars but no internet" symptom seen on 2026-05-12.

The session walked through six distinct failure modes, listed below in the order
they bite. **Apply all of them**.

---

## 0. Inventory & paths (the only ones that work)

| Component | Host | Binary | Config |
|---|---|---|---|
| 5G core (Docker) | firecell `10.76.170.38` | `~/monolithic/oai-cn5g/docker-compose.yaml` | `~/monolithic/oai-cn5g/conf/config.yaml` |
| CU | firecell `10.76.170.38` | `~/monolithic/openairinterface5g/cmake_targets/ran_build/build/nr-softmodem` | `~/monolithic/openairinterface5g/targets/PROJECTS/GENERIC-NR-5GC/CONF/gnb-cu.conf` |
| DU | pi `10.76.170.94` | `~/cu-du/source/openairinterface5g/cmake_targets/ran_build/build/nr-softmodem` | `~/cu-du/source/openairinterface5g/targets/PROJECTS/GENERIC-NR-5GC/CONF/gnb-pi.conf` |

Notes:

- The `cu-du` repo's `nr-softmodem` binary at `~/cu-du/source/openairinterface5g/cmake_targets/ran_build/build/nr-softmodem` **does not exist** on firecell. Only the `monolithic/` build is present. Don't reference the cu-du build path from firecell instructions.
- The `cu-du` repo's `gnb-cu.conf` has a libconfig syntax error (see fix #1 below) and cannot be loaded by `nr-softmodem`. Until that's fixed in-repo, you must use the `monolithic/` version on firecell.
- The pi's DU binary AND config live in the `cu-du` repo; the DU config (`gnb-pi.conf`) is valid and is the one in use.

---

## 1. Fix the cu-du `gnb-cu.conf` syntax error

`~/cu-du/source/openairinterface5g/targets/PROJECTS/GENERIC-NR-5GC/CONF/gnb-cu.conf` line 33 has:

```text
plmn_list = {
  {
    mcc = "1";          # ← STRING, libconfig wants integer
    mnc = "1";          # ← STRING, libconfig wants integer
    mnc_length = 2;
  }
};
```

OAI's libconfig parser rejects this with `line 33: syntax error → Getting configuration failed → exits immediately`. Fix:

```text
plmn_list = (
  {
    mcc = 1;
    mnc = 1;
    mnc_length = 2;
    snssaiList = ({ sst = 1 });
  }
);
```

Notes on the same file:

- It also configures F1-U on `10.76.170.39`, which is **not a real IP on enp6s0** (only `10.76.170.38` is assigned). After fixing the syntax, drop `f1u.local_address = "10.76.170.39"` or set it to `"10.76.170.38"`. The working `monolithic/` gnb-cu.conf binds F1-U to `10.76.170.38` (same IP as F1-C), which is what the DU is configured to talk to.
- Until this file is fixed in the repo, CU must be launched with `-O ~/monolithic/openairinterface5g/targets/PROJECTS/GENERIC-NR-5GC/CONF/gnb-cu.conf`. Once you fix the file in `cu-du`, both can be the same.

---

## 2. Launch the CU with `setsid nohup`, NEVER bare `sudo`

`sudo ./nr-softmodem ...` from an interactive shell dies on `SIGHUP` the moment
the ssh/tmux session closes — the CU completes F1 Setup, looks healthy for a
few seconds, then disappears with no log message. There is no crash.

Correct launch:

```sh
cd ~/monolithic/openairinterface5g/cmake_targets/ran_build/build
sudo setsid nohup ./nr-softmodem \
  -O ~/monolithic/openairinterface5g/targets/PROJECTS/GENERIC-NR-5GC/CONF/gnb-cu.conf \
  --log_config.global_log_level info \
  >/tmp/cu_mono.log 2>&1 < /dev/null &
disown
```

- `setsid` detaches from the controlling terminal — prevents SIGHUP propagation
- `nohup` is belt-and-suspenders
- `< /dev/null` closes stdin so the process doesn't block reading
- `disown` removes the bash job table entry so even `exit` doesn't notify it

A `systemd` unit is the long-term answer. Draft:

```ini
[Unit]
Description=OAI gNB-CU
After=docker.service network-online.target
Requires=docker.service

[Service]
Type=simple
User=root
WorkingDirectory=/home/serber/monolithic/openairinterface5g/cmake_targets/ran_build/build
ExecStartPre=/usr/bin/bash -c 'until docker ps --format "{{.Names}}\t{{.Status}}" | grep -q "oai-amf.*healthy"; do sleep 2; done'
ExecStart=/home/serber/monolithic/openairinterface5g/cmake_targets/ran_build/build/nr-softmodem \
  -O /home/serber/monolithic/openairinterface5g/targets/PROJECTS/GENERIC-NR-5GC/CONF/gnb-cu.conf \
  --log_config.global_log_level info
Restart=always
RestartSec=5
StandardOutput=append:/var/log/oai-cu.log
StandardError=append:/var/log/oai-cu.log

[Install]
WantedBy=multi-user.target
```

The `ExecStartPre` waits for the 5G core to be healthy — see fix #5.

---

## 3. Enable max USB current on the Raspberry Pi 5

This is the fix that resolved the **74 % downlink BLER** symptom. The Pi 5's
firmware caps total USB current at ~600 mA unless a 5 A PSU is detected OR the
user explicitly opts in. The USRP B210 draws ~800 mA peak during TX bursts, so
downlink transmissions get current-starved while RX is unaffected — exactly
the "uplink BLER 0 %, downlink BLER 74 %" signature seen here.

On `serber-pi` (`10.76.170.94`), add to `/boot/firmware/config.txt`:

```text
usb_max_current_enable=1
```

Then reboot the pi (`sudo reboot`). After the reboot, verify:

```sh
grep usb_max_current /boot/firmware/config.txt    # → usb_max_current_enable=1
vcgencmd get_throttled                            # → throttled=0x0
# After the DU is running and has loaded the USRP firmware:
lsusb | grep Ettus                                # → USRP B210
cat /sys/bus/usb/devices/4-1/speed                # → 5000   (USB 3.0)
```

Before the fix, with the DU running, DU stats for an attached UE showed:

```text
dlsch BLER 0.73909, dlsch_errors 57, pucch0_DTX 626, MCS (0) 0   ← bad
ulsch BLER 0.00000, ulsch_errors 0,  SNR 17 dB                    ← fine
```

After the fix, with the same UE:

```text
dlsch BLER 0.00424, dlsch_errors 0,  pucch0_DTX 0, MCS (0) 0      ← healthy
ulsch BLER 0.00001, ulsch_errors 0,  SNR 17–20 dB                 ← fine
```

The USRP also stays on USB 3.0 (5 Gbps) instead of dropping to USB 2.0 under
load. The phone hardware is **not** at fault; the symptom is purely host-side
USB current limiting.

---

## 4. Remove stale `10.0.0.1/24` from `enp6s0` on firecell

The host enp6s0 had been given `10.0.0.1/24`, which collides with the UPF's
`tun0` subnet. The UE's PDU subnet is `10.0.0.0/24` and the UPF's `tun0` is
`10.0.0.1/24`; the host having the same IP creates an ARP/route ambiguity.

The session already removed it (`sudo ip addr del 10.0.0.1/24 dev enp6s0`).
To keep it gone across reboots, ensure no netplan / NetworkManager profile
assigns `10.0.0.1` to `enp6s0`. Verify with:

```sh
ip -br a show enp6s0       # should NOT show 10.0.0.1
ip route get 10.0.0.2      # should go via the default gw, not "dev enp6s0 src 10.0.0.1"
```

---

## 5. Bring up the 5G core BEFORE the CU

If the CU starts before the AMF/SMF/UPF, it sends `NGSetupRequest` to a missing
AMF, the SCTP INIT gets ABORTed, and the CU enters retry loops. NGAP recovery
works in theory but in practice the CU log gets cluttered and F1AP races with
DU reconnects.

Order:

```sh
# 1. Core first
cd ~/monolithic/oai-cn5g
docker compose up -d
# wait until healthy
until docker ps --format '{{.Names}}\t{{.Status}}' | grep -q 'oai-amf.*healthy'; do sleep 2; done

# 2. Then CU (see fix #2 for the launch command)

# 3. Then (on the pi) the DU
ssh serber@10.76.170.94
cd ~/cu-du/source/openairinterface5g/cmake_targets/ran_build/build
sudo setsid nohup ./nr-softmodem \
  -O ~/cu-du/source/openairinterface5g/targets/PROJECTS/GENERIC-NR-5GC/CONF/gnb-pi.conf \
  --log_config.global_log_level info -E \
  >/tmp/pi.log 2>&1 < /dev/null &
disown
```

The pi's DU is also subject to fix #2 — interactive sudo without `nohup` will
die on shell exit.

---

## 6. Clean state when PDU sessions get stuck (TEID-mismatch symptom)

Symptom: UE registers, gets `5GMM-REGISTERED`, **but tcpdump on the UPF's tun0
shows the UE sending DNS queries to `1.1.1.1`, the responses come back to the
UPF, and the UE never receives them and never opens any TCP/QUIC connection**.
The user-visible result is "5G bars, no internet".

What's happening: after multiple PDU-session establish/release cycles caused
by the radio churn from fix #3 (74 % BLER → UE drops out of sync → AN release
→ re-attach), the CU accumulates GTP-U tunnel state for old PDU sessions that
were never properly removed. When the SMF then assigns the UE a new PDU
session via PFCP, the UPF's `create outer hdr` TEID for the new UE IP can end
up pointing at an *old* CU tunnel that maps to a different DRB (the IMS DRB,
not the internet DRB). Downlink GTP-U packets for the internet PDU then arrive
on the wrong DRB at the UE and are silently dropped (inner dst IP doesn't
match the receiving interface).

Concrete evidence from this session:

```text
UPF PFCP table:  UE IP 10.0.0.2 → DL TEID 0x2b6b7397 → 192.168.70.129
CU GTP-U state:  tunnel 0x2b6b7397 was created for PDU Session ID=2 (IMS)
                 tunnel 0x45a474aa is the CURRENT PDU 1 (internet)
```

Recovery procedure (when this state is observed):

```sh
# On firecell
docker compose -f ~/monolithic/oai-cn5g/docker-compose.yaml restart oai-smf oai-upf
# wait
until docker ps --format '{{.Names}}\t{{.Status}}' | grep -q 'oai-upf.*healthy'; do sleep 2; done
# Then restart the CU too — only this clears its stale tunnel registrations
sudo pkill -f nr-softmodem
sleep 3
# (re-launch using fix #2's command)
# Then toggle airplane mode on the phone to force a fresh PDU establishment.
```

A proper long-term fix is in OAI itself: the CU should delete GTP-U tunnels on
`UE Context Release`, not just on `PDU Session Release`. The
`try to get a gtp-u not existing output` and `GTP error indication TEID in
error 0x5/0xb/0xc` lines in the logs are the trace of this not happening
cleanly.

---

## 7. Fix Path MTU / GTP-U Fragmentation ("No Internet" symptom)

If the UE shows 5G bars, DNS works (e.g. `ping 8.8.8.8` works, `nslookup google.com` works), but web browsing fails with "No internet connection", the issue is **Path MTU Discovery failure**.

The internet sends a full 1500-byte packet back to the UE. The UPF encapsulates this packet into a GTP-U tunnel, adding 36 bytes of overhead (GTP + UDP + IP). The resulting 1536-byte packet exceeds the 1500 MTU of the host bridge (`oai-cn5g`), causing fragmentation. OAI's CU doesn't handle fragmented GTP-U packets, so they are dropped.

To fix this, clamp the TCP MSS in the UPF container so the internet servers send smaller packets:

```sh
# On firecell
docker exec oai-upf iptables -t mangle -A FORWARD -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --set-mss 1350
```

*(This must be run after the UPF starts up)*

---

## 8. Disable TX Checksum Offloading (UDP/DNS Drops)

If DNS queries are sent but no responses ever arrive, or if UDP packets silently fail to traverse the NAT, the issue is often host hardware checksum offloading. When the UPF forwards inner UE packets out to the host, the `veth` pair and the host's physical NIC (`enp6s0`) can calculate invalid checksums for MASQUERADEd packets. The upstream router drops them.

To fix this, disable TX checksumming on the host NIC and the UPF's virtual ethernet interface:

```sh
# On firecell
sudo ethtool -K enp6s0 tx off
docker exec oai-upf ethtool -K eth0 tx off
```

*(This must be run after the UPF starts up, and applied to the host physical interface).*

---

## Bring-up checklist (use this end-to-end)

After applying all eight fixes above:

1. **firecell**: `cd ~/monolithic/oai-cn5g && docker compose up -d` → wait for `oai-amf` healthy
2. **firecell**: launch CU via fix #2 command (using monolithic config, `setsid nohup`)
3. **pi**: launch DU via fix #5 command (`setsid nohup` style)
4. **phone**: toggle airplane mode; UE should attach and get IP `10.0.0.2`
5. Verify on firecell:
   ```sh
   # AMF sees UE as 5GMM-REGISTERED
   docker logs oai-amf 2>&1 | tail | grep -B 1 -A 6 "UEs' Information"
   # UPF has the active PDU session
   docker logs oai-upf 2>&1 | grep -A 6 'PFCP switch' | tail -10
   # iptables counters go up while phone is browsing
   docker exec oai-upf iptables -t nat -L POSTROUTING -n -v | grep '10.0.0.0/24'
   sudo iptables -t nat -L POSTROUTING -n -v | grep '192.168.70.128'
   ```
6. Verify on pi:
   ```sh
   tail -50 /tmp/pi.log | grep -E 'BLER|MCS|in-sync|RNTI'
   # Should show DL BLER < 0.05, UL BLER < 0.01, in-sync
   ```

If after all eight fixes the symptom is still "5G bars, no internet", capture
inside the UPF on tun0:

```sh
docker exec oai-upf apt-get install -y tcpdump iputils-ping >/dev/null
docker exec oai-upf timeout 30 tcpdump -i tun0 -nn -w /tmp/tun0.pcap
docker cp oai-upf:/tmp/tun0.pcap /tmp/
```

`tun0.pcap` shows the inner UE packets without GTP encap; if you see UE DNS
queries getting responses but no follow-up TCP/QUIC, you are back in fix #6
territory (TEID mismatch) and need to restart SMF, UPF, and the CU.

---

## What this session *did not* fix and is out of scope here

- **IMS / VoNR**: the UE establishes a PDU 2 to the `ims` DNN (UE IP `10.0.9.2`)
  and tries TCP to a SIP server at `192.168.70.139:5060`. The TCP handshake
  loops (SYN, SYN-ACK retransmitted, UE RSTs). This is independent of the
  internet PDU and needs P-CSCF / IMS deployment fixes (the `ims` container
  in docker-compose).
- **Higher MCS / throughput**: even with healthy BLER, the gNB's link
  adaptation stays at MCS 0 with this UE in the current RF environment. Once
  internet works, sustained traffic will let LA ramp up — but if it doesn't,
  re-check antenna / range / RF chain.
- **Test PLMN behaviour**: the UE registers with `MCC=001, MNC=01` (the
  IMSI is `001010000059449`). Some Android stacks treat 001/01 as a
  test-only PLMN with extra restrictions; if "no internet" persists with
  everything else healthy, a different IMSI under a non-test PLMN is the
  next thing to try.
