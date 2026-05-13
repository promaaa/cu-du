# CODEX Journal

## 2026-05-13

### Goal

Restore stable 5G service for the Nothing Phone in the CU/DU split setup:

- CU + 5GC on `serber-firecell` / `10.76.170.38`
- DU on `serber-pi` / `10.76.170.94`
- UE should show 5G bars and get internet through UPF `tun0` as `10.0.0.2`

### What I Found From `PLAN.md`

The previous working notes identified several important pitfalls:

- CU must be started after the core is healthy.
- CU/DU should be launched detached with `setsid nohup`.
- Pi 5 USB current fix must be present: `usb_max_current_enable=1`.
- Host `enp6s0` must not hold `10.0.0.1/24`, because UPF owns that subnet on `tun0`.
- Stale CU/UPF GTP state can cause "registered but no internet"; restart SMF, UPF, and CU to clear it.
- The known good F1-U path in the previous successful run used port `2152`.

### Actions Taken

- Verified Pi hardware state:
  - `usb_max_current_enable=1`
  - `vcgencmd get_throttled` returned `0x0`
  - USRP B210 present as serial `35F8ABA`
- Clean-restarted SMF/UPF, CU, and DU.
- Fixed CU/DU socket drift:
  - CU F1-U restored to `10.76.170.38:2152`
  - DU F1-U restored to `10.76.170.94:2152`
- Fixed generated Pi config after it picked up the wrong USRP serial:
  - Wrong: `8002816`
  - Correct: `35F8ABA`
- Changed the DU radio profile back to the requested / working target:
  - Band 78
  - `106 PRB`
  - `absoluteFrequencySSB = 641280`
  - runtime line: `-C 3619200000 -r 106 --numerology 1 --band 78 --ssb 516 -E`

### What Worked

After switching to the 106 PRB profile and toggling airplane mode:

- DU saw RACH.
- RA completed successfully.
- UE reached RRC connected with RNTI `f2a4`.
- AMF showed IMSI `001010000059449` as `5GMM-REGISTERED`.
- CU created PDU Session 1 and DRB 1.
- UPF `tun0` showed real internet traffic to and from UE IP `10.0.0.2`.
- UPF and host NAT counters increased.
- User confirmed 5G bars appeared on the phone.

### What Still Fails

The 5G bars disappeared again after initially appearing.

The most suspicious live symptoms from the DU after successful attach were:

- DL BLER around `40-50%`
- repeated `Detected UL Failure on PUSCH after ... PUSCH DTX`
- UE flipping between `in-sync` and `out-of-sync`
- many RA attempts with `Received a MAC CE for C-RNTI with f2a4`, suggesting the phone was trying to recover an existing connection
- CU repeatedly logged `UE Context Modification Required: new CellGroupConfig ... triggering reconfiguration`

This means the remaining problem is likely not core/NAT. The data plane was proven to pass traffic. The current failure looks like radio/MAC/RRC instability after attach, or a DU/CU reconfiguration loop that destabilizes the UE.

### Next Investigation Steps

- Capture fresh CU and DU logs after the bars drop.
- Check whether the UE context still exists in CU/AMF or was released.
- Check whether DU continues seeing RACH attempts after bars disappear.
- Compare stable 51 PRB versus 106 PRB behavior:
  - 51 PRB previously did not produce RACH in the latest session.
  - 106 PRB produced RACH and data but unstable radio.
- Inspect DU/CU config for parameters that could trigger repeated CellGroupConfig updates.
- Consider radio tuning only after confirming no software reconfiguration loop:
  - TX attenuation / power
  - `ssPBCH_BlockPower`
  - `pucch0_dtx_threshold`
  - `prach_dtx_threshold`
  - `min_rxtxtime`
  - TDD pattern / timing

### Fresh Findings After Bars Disappeared

After the user reported that bars appeared and then disappeared again, I captured fresh logs.

Current state at capture time:

- CU process still running.
- DU process still running.
- AMF still listed IMSI `001010000059449` as `5GMM-REGISTERED` for a while.
- No active user traffic was visible on UPF `tun0` in a short sample after the bars dropped.

Important CU findings:

- UE had initially attached as RNTI `f2a4`.
- PDU Session 1 and DRB 1 were created successfully.
- CU then entered a repeated loop:
  - `UE Context Modification Required: new CellGroupConfig ... triggering reconfiguration`
  - `Received RRCReconfigurationComplete`
- Later, AMF sent `PDUSESSIONRelease` for PDU Session 1.
- CU deleted TEIDs `0xb710e3e6` and `0xbd87a1c2` and released DRB 1.
- UE attempted RRC reestablishment as new RNTI `7ffb`, but PDCP logged `cannot re-establish DRB 1, RB not found`, and CU removed the UE context.

Important DU findings:

- Repeated C-RNTI recovery RA attempts:
  - `Received a MAC CE for C-RNTI with f2a4`
  - `triggering RRC Reconfiguration`
- Repeated `Detected UL Failure on PUSCH after ... PUSCH DTX`.
- UE alternated `in-sync` and `out-of-sync`.
- DL BLER remained very high, around `0.42`.
- PUCCH DTX was very high.
- UL SNR was decent (`~22-23 dB`), so this looks more like the UE failing DL/control stability than total RF deafness.

Working hypothesis now:

- Core and data-plane are not the primary remaining problem.
- The UE reaches attach and data, then loses radio/control stability.
- The repeated DU-originated CellGroupConfig updates and RRC reconfiguration loop appear to be consequences of radio recovery attempts, not the initial cause.
- Next test: increase downlink transmit power moderately by reducing `att_tx` from `12` to `6`, keeping RX gain unchanged, then restart DU and retest attach.

### Test: Increase Downlink TX Power

Changed DU `att_tx` from `12` to `6`, which raised USRP TX gain from `77.75` to `83.75`.

Result after airplane-mode toggle:

- RACH succeeded quickly.
- UE attached as RNTI `3eb6`.
- Initial stats improved:
  - DL BLER around `0.09-0.14`
  - UL BLER low
  - UE stayed `in-sync`
  - PDU/user traffic appeared on LCID 4
- Under continued downlink traffic, DL BLER climbed sharply:
  - `0.72`, then `0.90+`, eventually around `0.99`
  - PUCCH DTX rose quickly
  - UL remained clean, with UL BLER near zero

Conclusion:

- Simply increasing TX power is not enough.
- The instability appears to be downlink/control under load on the 106 PRB carrier.
- Next test: use a narrower 51 PRB carrier but keep the same center frequency (`3619.2 MHz`) by moving `dl_absoluteFrequencyPointA` from `640008` to `640668`. The previous 51 PRB attempt kept PointA at `640008`, which moved the carrier center to `3609.3 MHz` and produced no RACH.

### Test: Centered 51 PRB Carrier

Tried to reduce downlink load by using 51 PRB while keeping the same RF center frequency (`3619.2 MHz`).

Changes:

- `prb: 51`
- `dl_absoluteFrequencyPointA: 640668`
- `absoluteFrequencySSB: 641280`
- fixed generator bug: `initialULBWPlocationAndBandWidth` typo corrected to `initialULBWPlocationAndBandwidth`

First attempt failed before radio start:

- OAI computed `--ssb 186`
- assertion: `Invalid CSET0 start PRB -1 SSB offset point A 15 RB offset 16`
- cause: `controlResourceSetZero=12` is invalid for this SSB placement

Second attempt:

- changed `controlResourceSetZero=11`, `searchSpaceZero=0`
- DU started successfully with `-C 3619200000 -r 51 --ssb 186`
- no RACH observed after waiting

Conclusion:

- Centered 51 PRB is valid enough for OAI to broadcast, but the Nothing Phone did not attempt RACH.
- 106 PRB remains the only profile that has made the phone camp and attach.

### Next Test: 106 PRB Full Gain From Project Docs

Found older project docs in `PLAN-CU-DU.md` showing B210 settings:

- `att_tx: 0`
- `att_rx: 0`

This differs from current generated config (`att_tx: 12`, `att_rx: 12`) and the intermediate test (`att_tx: 6`, `att_rx: 12`). Next test is to restore 106 PRB and use `att_tx=0`, `att_rx=0`.

### 2026-05-13 14:58 +03 - Rate Limit Did Not Recover Existing UE

Applied a UPF `tun0` qdisc to shape downlink toward the UE:

```bash
docker exec oai-upf tc qdisc replace dev tun0 root tbf rate 1500kbit burst 64kbit latency 400ms
```

Verification showed:

```text
qdisc tbf 8001: root refcnt 2 rate 1500Kbit burst 8Kb lat 400ms
```

The existing UE session did not recover by itself. AMF still showed IMSI `001010000059449` as `5GMM-REGISTERED`, but DU/CU remained in the same radio recovery loop:

- CU repeatedly logged `UE Context Modification Required: new CellGroupConfig ... triggering reconfiguration`.
- DU repeatedly logged `Detected UL Failure on PUSCH after ... PUSCH DTX`.
- DU repeatedly handled C-RNTI recovery RA for RNTI `f79e`.
- DU stats stayed bad: UE out-of-sync, DL BLER around `0.38-0.42`, `pucch0_DTX` over `61k`, CCE failures rising.

Conclusion:

- Shaping at `1500kbit` did not rescue an already-bad live RRC session.
- Next step is to restart RAN cleanly with stricter downlink shaping already active, then reattach the phone from a clean state.

### 2026-05-13 15:00 +03 - Clean RAN Restart With 512 kbit Shaping

Changed UPF `tun0` shaping to a stricter limit:

```bash
docker exec oai-upf tc qdisc replace dev tun0 root tbf rate 512kbit burst 32kbit latency 500ms
```

Then restarted DU and CU cleanly.

Result:

- Phone immediately attached as RNTI `0ade`.
- CU completed RRC setup, security, UE capability exchange, PDU Session 1, DRB 1, and N3 TEID setup.
- UPF `tun0` counters confirmed traffic and the TBF was active.
- DU then showed the same bad downlink pattern:
  - RNTI `0ade` stayed `in-sync` initially.
  - DL BLER climbed from about `0.55` to `0.99`.
  - `pucch0_DTX` rose steadily.
  - UL stayed mostly healthy, with SNR around `17-20 dB` and low UL BLER.
  - DU removed RNTI `0ade`.
  - Phone immediately retried and attached as RNTI `658a`, then DL BLER started rising again.

Conclusion:

- Downlink traffic shaping alone is not enough.
- Full TX gain (`att_tx=0`, USRP TX gain `89.75`) now looks suspicious. Earlier `att_tx=6` had much cleaner initial DL BLER before load. Full gain may be overdriving the B210 RF path or the UE receiver enough to make PDCCH/PDSCH decoding unstable.
- Next test: return to moderate TX gain (`att_tx=6`) and reduce RX gain back to the earlier cleaner value (`att_rx=12`), keeping the 106 PRB profile and 512 kbit shaper.

### 2026-05-13 15:05 +03 - Moderate Gain Is Better, But Still Cycles

Changed DU RF levels:

- `att_tx=6` (`USRP TX_GAIN 83.75`)
- `att_rx=12` (`RX gain 58`)

Kept 106 PRB and the 512 kbit UPF shaper.

Result:

- Initial attach was much cleaner than full gain.
- One RNTI (`b137`) stayed in-sync for a longer window.
- DL BLER improved dramatically at first, sometimes around `0.03-0.10`.
- The link still eventually cycled: DL BLER climbed, `pucch0_DTX` rose, and DU removed the RNTI.
- CU showed `PDUSESSIONRelease` for the unstable RNTI with `Cause type=1 value=1`.
- CU also logged repeated `HO LOG: Event A2 (Serving becomes worse than threshold)`.
- Reported RSRP stayed weak, around `-108/-109 dBm`.

Conclusion:

- Full TX gain was making things worse, but `att_tx=6` may now be too weak for this phone/location.
- Next test: try a midpoint, `att_tx=3`, keep `att_rx=12`, and relax UPF shaping back to `1500kbit`.

### 2026-05-13 - User-Confirmed Working State

The user confirmed the Nothing Phone now has 5G bars and internet.

Current deployed baseline to preserve:

- 106 PRB profile.
- `absoluteFrequencySSB = 641280`.
- `dl_absoluteFrequencyPointA = 640008`.
- `initialDLBWPlocationAndBandwidth = 28875`.
- `initialULBWPlocationAndBandwidth = 28875`.
- `controlResourceSetZero = 12`.
- `searchSpaceZero = 2`.
- `ssb_perRACH_OccasionAndCB_PreamblesPerSSB = 14`.
- F1/F1-U ports on `2152`.
- USRP serial `35F8ABA`.
- `att_tx = 3`.
- `att_rx = 12`.
- UPF `tun0` qdisc: `tbf rate 1500Kbit burst 8Kb latency 400ms`.
- Pi CPU governor: `performance`.
- Pi USB current: `usb_max_current_enable=1`.

The user also confirmed the 51 PRB profile produced no 5G bars and no internet on the Nothing Phone.

Wrote two local docs:

- `CURRENT_DEPLOYED_CONFIGURATION.md`
- `REPRODUCIBLE_REDEPLOY_PLAN.md`

### 2026-05-13 - Removed Live CU Dependency On `~/monolithic`

Verified the live CU was still running from:

```text
/home/serber/monolithic/openairinterface5g/targets/PROJECTS/GENERIC-NR-5GC/CONF/gnb-cu.conf
```

Copied the built OAI tree into:

```text
/home/serber/cu-du/source/openairinterface5g
```

Then copied the known-good CU config into the `cu-du` tree. The CU config SHA-256 matched before and after:

```text
9bafc06cf2cc862c69c0b227f6bfc0a7f5a913f6627218d8aae46a26be983e1f
```

Restarted CU from:

```text
/home/serber/cu-du/source/openairinterface5g/cmake_targets/ran_build/build/nr-softmodem
```

with config:

```text
/home/serber/cu-du/source/openairinterface5g/targets/PROJECTS/GENERIC-NR-5GC/CONF/gnb-cu.conf
```

Observed NG setup, AMF registration, F1 setup, and UE context/PDU setup after restart. This removes the live runtime dependency on `~/monolithic` for CU.

Follow-up repo hardening:

- Updated local `conf/pi-cfg.yml` to the working 106 PRB profile.
- Updated local `conf/cu-cfg.yml`/generator behavior so generated F1 ports stay on `2152`.
- Added `scripts/validate-working-config.sh`.
- Updated role start scripts to invoke the generator with `python3`, avoiding executable-bit assumptions.
- Updated CN scripts to use `~/cu-du/source/oai-cn5g` instead of `~/monolithic/configuration`.
- Synced the important script/config fixes to `serber-firecell` and `serber-pi`.
- Verified on `serber-firecell`: `cd /home/serber/cu-du && scripts/validate-working-config.sh` passes.
- Verified live CU process command line now points to `/home/serber/cu-du/source/openairinterface5g/...`.
- Verified on `serber-pi`: generated `gnb-pi.conf` contains 106 PRB, F1-U `2152`, `att_tx=3`, `att_rx=12`, and `serial=35F8ABA`.

### 2026-05-13 - Fresh Clone Reproducibility Run

Archived the old `/home/serber/cu-du` directories before replacing them:

- `serber-firecell`: `/home/serber/cu-du-archives/cu-du-firecell-20260513-151438.tgz`
- `serber-pi`: `/home/serber/cu-du-archives/cu-du-pi-20260513-141438.tgz`

Then moved the pre-clone directories aside and cloned `https://github.com/promaaa/cu-du.git` fresh on both hosts. Fresh-clone build results:

- `serber-firecell`: CU and core bootstrap/build completed.
- `serber-pi`: DU build completed with the pinned OAI commit and B210-enabled build.

First fresh runtime attempt reached NG setup, F1 setup, RACH, and RRC, but the phone returned Authentication Failure / MAC failure. Root cause: the repo had seeded the stock OAI test Ki/OPc for IMSI `001010000059449`, while the physical SIM uses the values from the old working monolithic config:

- Ki `5686e601f3a1942d4c5cd262ba6b4b20`
- OPc `aeb1cabd8ed7a09b48d17eb3d8af172c`

Updated the repo seed path and bundled OAI DB SQL so the fresh clone no longer depends on `~/monolithic/configuration/add-sim-card.sql` for this subscriber.

After pulling commit `40092c7` on both fresh clones, restarted from the repo scripts:

- CU/core from `/home/serber/cu-du/roles/cu/start.sh`
- DU from `/home/serber/cu-du/roles/pi/start.sh`

Verification after restart:

- CN containers healthy.
- MySQL subscriber row uses Ki `5686e601f3a1942d4c5cd262ba6b4b20` and OPc `aeb1cabd8ed7a09b48d17eb3d8af172c`.
- CU runs from `/home/serber/cu-du/source/openairinterface5g/.../gnb-cu.conf`.
- DU runs from `/home/serber/cu-du/source/openairinterface5g/.../gnb-pi.conf` with `-E`.
- AMF authentication succeeds; no MAC failure after correcting the SIM credentials.
- AMF reaches `5GMM-REGISTERED` for IMSI `001010000059449`.
- SMF establishes PDU sessions and marks them active.
- DU adds DRB 1 and DRB 2; LCID 5 user-plane byte counters increase.
- `tcpdump` on `serber-firecell` shows bidirectional GTP-U on F1-U (`10.76.170.94:2152` <-> `10.76.170.38:2152`) and N3 (`192.168.70.129:2152` <-> `192.168.70.134:2152`).
- `scripts/check-health.sh` passes when run locally with `SSHPASS=root4SERBER`.

Residual observation: radio quality is currently marginal compared with the earlier best working snapshot. DU reports the UE in-sync, but recent RSRP moved between about `-104` and `-126`/worse with high downlink BLER. The repo reproducibility issue is fixed; any remaining throughput instability is likely RF placement/gain/channel quality rather than missing clone-time configuration.
